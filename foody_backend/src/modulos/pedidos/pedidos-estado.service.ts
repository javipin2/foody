import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import {
  AlertasRiesgoService,
  UMBRALES_ALERTA,
} from '../alertas/alertas-riesgo.service';
import { CosteoService } from '../costeo/costeo.service';
import {
  PedidosCajaAuditoriaService,
  METODOS_CON_CAJA,
} from './pedidos-caja-auditoria.service';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
import { PedidosInventarioService } from './pedidos-inventario.service';
import {
  puedeMarcarPagando,
  estadoActivaCocina,
  transicionEstadoPermitida,
} from './pedido-estados';
import { AuditoriaService } from '../auditoria/auditoria.service';
import { PedidosSoporteService } from './pedidos-soporte.service';
import { PedidosEstadoCommandService } from './pedidos-estado-command.service';
import { PedidosDispatchHooksService } from './pedidos-dispatch-hooks.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
import { montoVentaCajaEntregaDomicilio } from '../domiciliarios/cobro-domicilio.util';

const ESTADOS_KANBAN = [
  'pendiente',
  'confirmado',
  'en_cocina',
  'listo',
  'pagando',
  'asignado',
  'en_camino',
  'entregado',
] as const;

/** RBAC-MESERO-03: mesero solo presenta cuenta o cancela (no Kanban cocina). */
const ESTADOS_PERMITIDOS_MESERO = new Set(['pagando', 'cancelado']);

/** Subdominio: transiciones de estado, aprobación y rechazo de pedidos mesa. */
@Injectable()
export class PedidosEstadoService {
  constructor(
    private readonly database: DatabaseService,
    private readonly dispatchHooks: PedidosDispatchHooksService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly costeo: CosteoService,
    private readonly cajaAuditoria: PedidosCajaAuditoriaService,
    private readonly cuentaMesa: PedidosCuentaMesaService,
    private readonly soporte: PedidosSoporteService,
    private readonly estadoCommand: PedidosEstadoCommandService,
    private readonly inventario: PedidosInventarioService,
    private readonly auditoria: AuditoriaService,
    private readonly notificaciones: NotificacionesService,
  ) {}

  async cambiarEstado(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    nuevoEstado: string,
    motivo?: string,
    contexto?: { rol: string; permisos: string[] },
  ) {
    if (
      !ESTADOS_KANBAN.includes(
        nuevoEstado as (typeof ESTADOS_KANBAN)[number],
      ) &&
      nuevoEstado !== 'pendiente_aprobacion' &&
      nuevoEstado !== 'cancelado' &&
      nuevoEstado !== 'rechazado'
    ) {
      throw new BadRequestException('Estado no válido');
    }

    let catalogoCambios: { producto_id: string; disponible: boolean }[] = [];
    const result = await this.database.enTransaccion(async (client) => {
      const pedido = await this.soporte.consultarUnoCliente<{
        id: string;
        estado: string;
        tipo: string;
        mesa_id: string | null;
        stock_descontado: boolean;
        created_at: Date;
        total: string;
        costo_domicilio: string;
        monto_pagado: string | null;
        metodo_pago: string | null;
        numero_pedido: string;
        mesera_id: string | null;
      }>(
        client,
        `SELECT id, estado, tipo, mesa_id, stock_descontado, created_at, total,
                COALESCE(costo_domicilio, 0) AS costo_domicilio,
                COALESCE(monto_pagado, 0) AS monto_pagado, metodo_pago, numero_pedido,
                mesera_id
         FROM pedidos
         WHERE id = $1 AND sucursal_id = $2
         FOR UPDATE`,
        [pedidoId, sucursalId],
      );

      if (!pedido) {
        throw new NotFoundException('Pedido no encontrado');
      }

      if (
        contexto?.rol === 'mesero' &&
        !ESTADOS_PERMITIDOS_MESERO.has(nuevoEstado)
      ) {
        throw new ForbiddenException({
          error: 'ESTADO_ROL_NO_PERMITIDO',
          message:
            'El mesero solo puede presentar cuenta (pagando) o cancelar el pedido',
        });
      }

      if (nuevoEstado === 'cancelado' && contexto) {
        if (contexto.rol === 'cliente') {
          this.soporte.validarCancelacionCliente(pedido, motivo);
        } else {
          this.soporte.validarCancelacion(
            pedido,
            contexto.rol,
            contexto.permisos,
            motivo,
          );
        }
      }

      const anterior = pedido.estado;
      if (anterior === nuevoEstado) {
        return {
          id: pedidoId,
          estado: nuevoEstado,
          estado_anterior: anterior,
          tipo: pedido.tipo,
          mesa_id: pedido.mesa_id,
          mesera_id: pedido.mesera_id,
          numero_pedido: pedido.numero_pedido,
        };
      }

      if (
        !transicionEstadoPermitida(
          anterior,
          nuevoEstado,
          pedido.tipo,
          pedido.mesa_id,
        )
      ) {
        throw new BadRequestException({
          error: 'TRANSICION_ESTADO_INVALIDA',
          message: `No se puede pasar de «${anterior}» a «${nuevoEstado}»`,
        });
      }

      if (nuevoEstado === 'entregado' && pedido.tipo !== 'domicilio') {
        throw new BadRequestException({
          error: 'ENTREGADO_SOLO_DOMICILIO',
          message:
            'Los pedidos de mesa o para llevar se cierran con cobro en caja (estado pagado), no como entregado.',
        });
      }

      if (
        nuevoEstado === 'pagando' &&
        !puedeMarcarPagando(pedido.tipo, pedido.mesa_id)
      ) {
        throw new BadRequestException({
          error: 'PAGANDO_NO_APLICA',
          message:
            'Solo pedidos de mesa o para llevar pueden marcarse como pagando',
        });
      }

      if (estadoActivaCocina(nuevoEstado) && !pedido.stock_descontado) {
        const lineas = await this.inventario.lineasDesdePedido(
          client,
          pedidoId,
          sucursalId,
        );
        const stock = await this.inventario.descontarStockPedido(
          client,
          sucursalId,
          pedidoId,
          lineas,
          { incluirEmpaques: pedido.tipo === 'domicilio' },
        );
        catalogoCambios.push(...stock.catalogo);
        await client.query(
          `UPDATE pedidos SET stock_descontado = true WHERE id = $1`,
          [pedidoId],
        );
        await client.query(
          `UPDATE pedido_items SET stock_snapshot_version = 1 WHERE pedido_id = $1`,
          [pedidoId],
        );
      }

      if (nuevoEstado === 'cancelado' && pedido.stock_descontado) {
        const requiereMerma =
          await this.inventario.pedidoRequiereMermaAlCancelar(
            client,
            pedidoId,
            anterior,
          );
        if (requiereMerma) {
          await this.inventario.registrarMermaPedidoCompleto(
            client,
            sucursalId,
            pedidoId,
            motivo ?? 'Cancelación de pedido ya en cocina o listo',
          );
          await this.alertasRiesgo.registrarEnTransaccion(client, {
            sucursalId,
            tipo: 'merma_cancelacion_pedido',
            nivel: 'medio',
            descripcion: `Merma por cancelación de pedido en estado ${anterior}`,
            referenciaId: pedidoId,
            referenciaTipo: 'pedido',
            deduplicar: false,
          });
        } else {
          const restaurado = await this.inventario.restaurarStockPedido(
            client,
            sucursalId,
            pedidoId,
          );
          catalogoCambios.push(...restaurado);
          await client.query(
            `UPDATE pedidos SET stock_descontado = false WHERE id = $1`,
            [pedidoId],
          );
        }
      }

      await this.estadoCommand.aplicarEstadoEnTransaccion(client, {
        pedidoId,
        sucursalId,
        nuevoEstado,
        origen: 'kanban',
        usuarioId,
        motivo: motivo ?? null,
        estadoAnterior: anterior,
        tipo: pedido.tipo,
      });

      // Domicilio marcado entregado sin app domiciliario: cobrar saldo pendiente en caja.
      if (nuevoEstado === 'entregado' && pedido.tipo === 'domicilio') {
        const totalPedido = Number(pedido.total);
        const pagado = Number(pedido.monto_pagado ?? 0);
        const metodo =
          pedido.metodo_pago?.trim() && pedido.metodo_pago !== 'pendiente'
            ? pedido.metodo_pago.trim()
            : 'efectivo';
        const sucursalCfg = await this.soporte.consultarUnoCliente<{
          domicilio_ingresa_a_caja: boolean;
        }>(
          client,
          `SELECT COALESCE(domicilio_ingresa_a_caja, false) AS domicilio_ingresa_a_caja
           FROM sucursales WHERE id = $1`,
          [sucursalId],
        );
        const domicilioEnCaja = sucursalCfg?.domicilio_ingresa_a_caja ?? false;
        const montoCaja = montoVentaCajaEntregaDomicilio(
          totalPedido,
          Number(pedido.costo_domicilio),
          pagado,
          domicilioEnCaja,
        );
        if (
          montoCaja > 0.01 &&
          METODOS_CON_CAJA.includes(metodo as (typeof METODOS_CON_CAJA)[number])
        ) {
          await client.query(
            `INSERT INTO pagos_pedido (
               sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
             ) VALUES ($1,$2,$3,0,$4,$5,$6)`,
            [
              sucursalId,
              pedidoId,
              montoCaja,
              metodo,
              usuarioId,
              `Cobro producto domicilio ${pedido.numero_pedido}`,
            ],
          );
          await this.cajaAuditoria.registrarVentaEnCaja(
            client,
            sucursalId,
            pedidoId,
            montoCaja,
            metodo,
            {
              exigirCaja: true,
              descripcion: `Domicilio entregado ${pedido.numero_pedido}`,
              usuarioId,
            },
          );
          await client.query(
            `UPDATE pedidos SET monto_pagado = $2, metodo_pago = $3 WHERE id = $1`,
            [pedidoId, totalPedido, metodo],
          );
        }
      }

      if (
        nuevoEstado === 'en_cocina' &&
        pedido.mesa_id &&
        usuarioId &&
        ['pendiente_aprobacion', 'pendiente', 'confirmado'].includes(anterior)
      ) {
        await this.soporte.assertMeseraPuedeTomarMesa(
          client,
          sucursalId,
          pedido.mesa_id,
          usuarioId,
        );
        await client.query(
          `UPDATE pedidos SET mesera_id = COALESCE(mesera_id, $1), aprobado_at = COALESCE(aprobado_at, now())
           WHERE id = $2`,
          [usuarioId, pedidoId],
        );
        await this.soporte.asignarMeseraAMesa(
          client,
          sucursalId,
          pedido.mesa_id,
          usuarioId,
        );
      }

      if (nuevoEstado === 'pagando' && pedido.mesa_id) {
        await this.cuentaMesa.marcarEstadoOperativoMesa(
          client,
          pedido.mesa_id,
          sucursalId,
          'pagando',
        );
      }

      if (
        ['pagado', 'cancelado', 'rechazado'].includes(nuevoEstado) &&
        pedido.mesa_id
      ) {
        await this.cuentaMesa.liberarMesaSiSinPedidosActivos(
          client,
          pedido.mesa_id,
          sucursalId,
        );
      }

      if (nuevoEstado === 'cancelado') {
        const reversa = await this.cajaAuditoria.revertirVentasPedido(
          client,
          pedidoId,
          sucursalId,
          usuarioId,
          motivo ?? 'Pedido cancelado',
        );
        await client.query(
          `UPDATE pedidos SET monto_pagado = 0 WHERE id = $1`,
          [pedidoId],
        );
        const domiciliariosDesasignados = await client.query<{
          usuario_id: string | null;
          independiente_id: string | null;
        }>(
          `SELECT DISTINCT dp.usuario_id,
                  ad.domiciliario_independiente_id AS independiente_id
           FROM asignaciones_domicilio ad
           LEFT JOIN domiciliarios_planta dp ON dp.id = ad.domiciliario_planta_id
           WHERE ad.pedido_id = $1
             AND ad.estado IN ('asignado', 'en_camino')`,
          [pedidoId],
        );
        await client.query(
          `UPDATE asignaciones_domicilio SET estado = 'cancelado'
           WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')`,
          [pedidoId],
        );
        await client.query(
          `UPDATE ofertas_pedido SET estado = 'cancelada'
           WHERE pedido_id = $1 AND estado = 'activa'`,
          [pedidoId],
        );
        await client.query(
          `UPDATE domiciliarios_sesiones ds
           SET disponible = NOT EXISTS (
             SELECT 1 FROM asignaciones_domicilio activas
             WHERE activas.domiciliario_independiente_id = ad.domiciliario_independiente_id
               AND activas.estado IN ('asignado', 'en_camino')
               AND activas.pedido_id <> $1
           )
           FROM asignaciones_domicilio ad
           WHERE ad.pedido_id = $1
             AND ad.tipo_domiciliario = 'independiente'
             AND ad.domiciliario_independiente_id = ds.domiciliario_id
             AND ds.activa = true`,
          [pedidoId],
        );
        await this.alertasRiesgo.evaluarCancelacionesFrecuentes(
          client,
          sucursalId,
          usuarioId,
          pedidoId,
        );
        return {
          id: pedidoId,
          estado: nuevoEstado,
          estado_anterior: anterior,
          tipo: pedido.tipo,
          mesa_id: pedido.mesa_id,
          caja: {
            devolucion_automatica: reversa.monto_total,
            ventas_revertidas: reversa.movimientos,
          },
          domiciliarios_desasignados: domiciliariosDesasignados.rows
            .map((r) => r.usuario_id)
            .filter((id): id is string => Boolean(id)),
          domiciliarios_independientes_desasignados:
            domiciliariosDesasignados.rows
              .map((r) => r.independiente_id)
              .filter((id): id is string => Boolean(id)),
        };
      }

      return {
        id: pedidoId,
        estado: nuevoEstado,
        estado_anterior: anterior,
        tipo: pedido.tipo,
        mesa_id: pedido.mesa_id,
        mesera_id: pedido.mesera_id,
        numero_pedido: pedido.numero_pedido,
      };
    });

    if (nuevoEstado === 'listo' && result.tipo === 'domicilio') {
      try {
        const dispatchResult =
          await this.dispatchHooks.intentarDispatchAutomatico(
            pedidoId,
            sucursalId,
          );
        const asignado =
          dispatchResult.iniciado &&
          (dispatchResult.motivo === 'planta_asignada_auto' ||
            dispatchResult.motivo === 'ya_asignado');
        if (!asignado) {
          const detalle =
            dispatchResult.mensaje ??
            'No hubo asignación automática. Revisa el panel de domiciliarios.';
          void this.alertasRiesgo.registrar({
            sucursalId,
            tipo: 'domicilio_listo_sin_asignar',
            nivel: 'medio',
            descripcion: `Pedido ${pedidoId}: ${detalle}`,
            referenciaId: pedidoId,
            referenciaTipo: 'pedido',
            deduplicar: true,
          });
          void this.notificaciones.enviar({
            sucursal_id: sucursalId,
            tipo: 'domicilio_requiere_asignacion',
            titulo: 'Domicilio listo — asignar repartidor',
            cuerpo: detalle,
            roles: ['admin', 'gerente', 'domiciliario_planta'],
            datos: {
              pedido_id: pedidoId,
              ruta: '/admin/domiciliarios',
            },
          });
        }
      } catch {
        // Dispatch no debe bloquear el cambio de estado del pedido
      }
    }

    if (nuevoEstado === 'en_cocina' && result.estado_anterior !== 'en_cocina') {
      void this.soporte.notificarCocinasPorPedido(pedidoId, sucursalId);
    }

    if (
      nuevoEstado === 'pagando' &&
      (result as { mesera_id?: string | null }).mesera_id
    ) {
      const meseraId = (result as { mesera_id: string }).mesera_id;
      const num = (result as { numero_pedido?: string }).numero_pedido;
      const mesaId = (result as { mesa_id?: string | null }).mesa_id;
      void this.notificaciones.enviar({
        sucursal_id: sucursalId,
        tipo: 'pedido_a_cobrar',
        titulo: 'Pedido listo para entregar / cobrar',
        cuerpo: `Pedido ${num ? `#${num}` : ''} listo: llévalo a la mesa y gestiona el cobro.`,
        destinatario_usuario_id: meseraId,
        datos: {
          pedido_id: pedidoId,
          sucursal_id: sucursalId,
          mesa_id: mesaId ?? '',
          ruta: mesaId
            ? `/admin/mesero?mesa_id=${mesaId}&pedido_id=${pedidoId}&tab=pedidos`
            : `/admin/mesero?pedido_id=${pedidoId}&tab=pedidos`,
        },
      });
    }

    const {
      tipo: _tipo,
      domiciliarios_desasignados: _domiOff,
      domiciliarios_independientes_desasignados: _domiIndepOff,
      mesera_id: _mesera,
      numero_pedido: _num,
      ...respuesta
    } = result as typeof result & {
      domiciliarios_desasignados?: string[];
      domiciliarios_independientes_desasignados?: string[];
      mesera_id?: string | null;
      numero_pedido?: string;
    };
    this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, nuevoEstado);
    this.soporte.notificarCatalogoDisponibilidad(sucursalId, catalogoCambios);
    if (
      nuevoEstado === 'cancelado' &&
      (_domiOff?.length || _domiIndepOff?.length)
    ) {
      this.soporte.notificarDesasignacionesDomicilio(
        _domiOff ?? [],
        pedidoId,
        _domiIndepOff ?? [],
      );
    }
    return respuesta;
  }

  async aprobarMesa(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    opciones?: { meseraId?: string; rolLlamador?: string },
  ) {
    const esMesero = opciones?.rolLlamador === 'mesero';
    const meseraBody = opciones?.meseraId?.trim() || undefined;
    if (!esMesero && !meseraBody) {
      throw new BadRequestException('Debes asignar un mesero');
    }
    const meseraEfectiva = meseraBody ?? usuarioId;

    let catalogoCambios: { producto_id: string; disponible: boolean }[] = [];
    let numeroPedido: string | undefined;
    let mesaId: string | null = null;

    const result = await this.database.enTransaccion(async (client) => {
      const pedido = await this.soporte.consultarUnoCliente<{
        id: string;
        estado: string;
        mesa_id: string | null;
        tipo: string;
        stock_descontado: boolean;
        numero_pedido: string;
      }>(
        client,
        `SELECT id, estado, mesa_id, tipo, stock_descontado, numero_pedido
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [pedidoId, sucursalId],
      );
      if (!pedido) throw new NotFoundException('Pedido no encontrado');
      if (pedido.estado !== 'pendiente_aprobacion') {
        throw new BadRequestException(
          'El pedido no está pendiente de aprobación',
        );
      }

      const meseraOk = await this.soporte.consultarUnoCliente<{
        id: string;
        rol: string;
        activo: boolean;
      }>(
        client,
        `SELECT id, rol, activo FROM usuarios
         WHERE id = $1 AND sucursal_id = $2`,
        [meseraEfectiva, sucursalId],
      );
      if (!meseraOk || !meseraOk.activo || meseraOk.rol !== 'mesero') {
        throw new BadRequestException(
          'El mesero indicado no es válido o no está activo en esta sucursal',
        );
      }

      // Si el admin elige mesero explícito, se reasigna la mesa.
      // Si es auto-asignación del mesero, respetar turno de otra mesera.
      if (pedido.mesa_id && !meseraBody) {
        await this.soporte.assertMeseraPuedeTomarMesa(
          client,
          sucursalId,
          pedido.mesa_id,
          meseraEfectiva,
        );
      }

      if (!pedido.stock_descontado) {
        const lineas = await this.inventario.lineasDesdePedido(
          client,
          pedidoId,
          sucursalId,
        );
        await this.inventario.validarStockDisponible(
          client,
          sucursalId,
          lineas,
          {
            incluirEmpaques: pedido.tipo === 'domicilio',
            excluirPedidoIdReservaQr: pedidoId,
          },
        );
        const stock = await this.inventario.descontarStockPedido(
          client,
          sucursalId,
          pedidoId,
          lineas,
          { incluirEmpaques: pedido.tipo === 'domicilio' },
        );
        catalogoCambios.push(...stock.catalogo);
        await client.query(
          `UPDATE pedidos SET stock_descontado = true WHERE id = $1`,
          [pedidoId],
        );
        await client.query(
          `UPDATE pedido_items SET stock_snapshot_version = 1 WHERE pedido_id = $1`,
          [pedidoId],
        );
      }

      await this.estadoCommand.aplicarEstadoEnTransaccion(client, {
        pedidoId,
        sucursalId,
        nuevoEstado: 'en_cocina',
        origen: 'aprobacion_qr',
        usuarioId,
        estadoAnterior: 'pendiente_aprobacion',
        tipo: pedido.tipo,
      });

      if (pedido.mesa_id) {
        await this.soporte.asignarMeseraAMesa(
          client,
          sucursalId,
          pedido.mesa_id,
          meseraEfectiva,
        );
      }

      await client.query(
        `UPDATE pedidos SET mesera_id = $1, aprobado_at = now() WHERE id = $2`,
        [meseraEfectiva, pedidoId],
      );

      numeroPedido = pedido.numero_pedido;
      mesaId = pedido.mesa_id;
      return {
        id: pedidoId,
        estado: 'en_cocina',
        mesera_id: meseraEfectiva,
      };
    });

    this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, 'en_cocina');
    this.soporte.notificarCatalogoDisponibilidad(sucursalId, catalogoCambios);
    void this.soporte.notificarCocinasPorPedido(pedidoId, sucursalId);

    const num = numeroPedido ? `#${numeroPedido}` : '';
    void this.notificaciones.enviar({
      sucursal_id: sucursalId,
      tipo: 'pedido_asignado_mesero',
      titulo: 'Pedido asignado a tu mesa',
      cuerpo: `Quedaste a cargo del pedido ${num}. Prepárate para atender y cobrar.`,
      destinatario_usuario_id: meseraEfectiva,
      datos: {
        pedido_id: pedidoId,
        sucursal_id: sucursalId,
        mesa_id: mesaId ?? '',
        ruta: mesaId
          ? `/admin/mesero?mesa_id=${mesaId}&pedido_id=${pedidoId}`
          : `/admin/mesero?pedido_id=${pedidoId}`,
      },
    });

    return result;
  }

  async rechazarMesa(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    motivo: string,
  ) {
    return this.cambiarEstadoDesde(
      pedidoId,
      sucursalId,
      usuarioId,
      'pendiente_aprobacion',
      'rechazado',
      motivo,
    );
  }

  private async cambiarEstadoDesde(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    estadoEsperado: string,
    nuevoEstado: string,
    motivo?: string,
  ) {
    let catalogoCambios: { producto_id: string; disponible: boolean }[] = [];
    const result = await this.database.enTransaccion(async (client) => {
      const pedido = await this.soporte.consultarUnoCliente<{
        id: string;
        estado: string;
        mesa_id: string | null;
        stock_descontado: boolean;
        tipo: string;
      }>(
        client,
        `SELECT id, estado, mesa_id, stock_descontado, tipo
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [pedidoId, sucursalId],
      );
      if (!pedido) throw new NotFoundException('Pedido no encontrado');
      if (pedido.estado !== estadoEsperado) {
        throw new BadRequestException(
          'El pedido no está pendiente de aprobación',
        );
      }

      if (nuevoEstado === 'rechazado' && pedido.stock_descontado) {
        const restaurado = await this.inventario.restaurarStockPedido(
          client,
          sucursalId,
          pedidoId,
        );
        catalogoCambios.push(...restaurado);
        await client.query(
          `UPDATE pedidos SET stock_descontado = false WHERE id = $1`,
          [pedidoId],
        );
      }

      if (nuevoEstado === 'rechazado') {
        const reversa = await this.cajaAuditoria.revertirVentasPedido(
          client,
          pedidoId,
          sucursalId,
          usuarioId,
          motivo ?? 'Pedido rechazado',
        );
        await client.query(
          `UPDATE pedidos SET monto_pagado = 0 WHERE id = $1`,
          [pedidoId],
        );
        await this.estadoCommand.aplicarEstadoEnTransaccion(client, {
          pedidoId,
          sucursalId,
          nuevoEstado,
          origen: 'kanban',
          usuarioId,
          motivo: motivo ?? null,
          estadoAnterior: estadoEsperado,
          tipo: pedido.tipo,
        });

        if (pedido.mesa_id) {
          await this.cuentaMesa.liberarMesaSiSinPedidosActivos(
            client,
            pedido.mesa_id,
            sucursalId,
          );
        }

        return {
          id: pedidoId,
          estado: nuevoEstado,
          caja: {
            devolucion_automatica: reversa.monto_total,
            ventas_revertidas: reversa.movimientos,
          },
        };
      }

      await this.estadoCommand.aplicarEstadoEnTransaccion(client, {
        pedidoId,
        sucursalId,
        nuevoEstado,
        origen: 'kanban',
        usuarioId,
        motivo: motivo ?? null,
        estadoAnterior: estadoEsperado,
        tipo: pedido.tipo,
      });

      return { id: pedidoId, estado: nuevoEstado };
    });
    this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, nuevoEstado);
    this.soporte.notificarCatalogoDisponibilidad(sucursalId, catalogoCambios);
    return result;
  }

  /**
   * F-09: pedidos QR sin aprobar tras N minutos → rechazados al cerrar caja
   * (cliente se fue sin que mesero apruebe/rechace).
   */
  async expirarQrPendientesAlCierreEnTransaccion(
    client: PoolClient,
    sucursalId: string,
    usuarioId: string | null,
  ): Promise<number> {
    const minutos = UMBRALES_ALERTA.qrPendienteAprobacionMinutos;
    const expirados = await client.query<{
      id: string;
      mesa_id: string | null;
      numero_pedido: string;
      stock_descontado: boolean;
    }>(
      `SELECT id, mesa_id, numero_pedido, stock_descontado FROM pedidos
       WHERE sucursal_id = $1
         AND estado = 'pendiente_aprobacion'
         AND created_at < now() - ($2::text || ' minutes')::interval
       FOR UPDATE`,
      [sucursalId, String(minutos)],
    );

    for (const p of expirados.rows) {
      if (p.stock_descontado) {
        const restaurado = await this.inventario.restaurarStockPedido(
          client,
          sucursalId,
          p.id,
        );
        await client.query(
          `UPDATE pedidos SET stock_descontado = false WHERE id = $1`,
          [p.id],
        );
        void restaurado;
      }

      await this.estadoCommand.aplicarEstadoEnTransaccion(client, {
        pedidoId: p.id,
        sucursalId,
        nuevoEstado: 'rechazado',
        origen: 'sistema',
        usuarioId,
        motivo: `QR expirado (>${minutos} min sin aprobación) al cierre de caja`,
        estadoAnterior: 'pendiente_aprobacion',
      });

      if (p.mesa_id) {
        await this.cuentaMesa.liberarMesaSiSinPedidosActivos(
          client,
          p.mesa_id,
          sucursalId,
        );
      }
    }

    if (expirados.rows.length > 0) {
      await this.alertasRiesgo.registrarEnTransaccion(client, {
        sucursalId,
        tipo: 'qr_pendiente_expirado_cierre',
        nivel: 'medio',
        descripcion: `${expirados.rows.length} pedido(s) QR rechazados por expiración al cierre de caja (>${minutos} min)`,
        referenciaTipo: 'sucursal',
        deduplicar: false,
      });
    }

    return expirados.rows.length;
  }

  /** Cancelación por el cliente (device_id + reglas de tiempo). */
  async cancelarPorCliente(pedidoId: string, deviceId: string, motivo: string) {
    const pedido = await this.database.consultarUno<{
      id: string;
      sucursal_id: string;
      estado: string;
      created_at: Date;
    }>(
      `SELECT id, sucursal_id, estado, created_at
       FROM pedidos
       WHERE id = $1 AND device_id = $2`,
      [pedidoId, deviceId],
    );
    if (!pedido) {
      throw new NotFoundException('Pedido no encontrado');
    }
    this.soporte.validarCancelacionCliente(pedido, motivo);
    return this.cambiarEstado(
      pedidoId,
      pedido.sucursal_id,
      'cliente',
      'cancelado',
      motivo.trim(),
      { rol: 'cliente', permisos: [] },
    );
  }

  /** Cliente en mesa solicita atención de mesera (FCM + cooldown 90 s). */
  async llamarMesera(pedidoId: string, deviceId: string, mensaje?: string) {
    const pedido = await this.database.consultarUno<{
      id: string;
      sucursal_id: string;
      mesa_id: string | null;
      estado: string;
      numero_pedido: string;
    }>(
      `SELECT id, sucursal_id, mesa_id, estado, numero_pedido
       FROM pedidos
       WHERE id = $1 AND device_id = $2`,
      [pedidoId, deviceId],
    );
    if (!pedido) {
      throw new NotFoundException('Pedido no encontrado');
    }
    this.soporte.validarLlamadaMesera(pedido);

    const ultima = await this.database.consultarUno<{ created_at: Date }>(
      `SELECT created_at FROM auditoria_logs
       WHERE accion = 'LLAMAR_MESERA' AND registro_id = $1
       ORDER BY created_at DESC
       LIMIT 1`,
      [pedidoId],
    );
    if (ultima) {
      const segundos =
        (Date.now() - new Date(ultima.created_at).getTime()) / 1000;
      if (segundos < 90) {
        throw new BadRequestException({
          error: 'LLAMADA_MESERA_COOLDOWN',
          message: `Espera ${Math.ceil(90 - segundos)} s antes de volver a llamar`,
        });
      }
    }

    const mesa = pedido.mesa_id
      ? await this.database.consultarUno<{ nombre: string }>(
          `SELECT nombre FROM mesas WHERE id = $1`,
          [pedido.mesa_id],
        )
      : null;

    await this.auditoria.registrar({
      sucursalId: pedido.sucursal_id,
      accion: 'LLAMAR_MESERA',
      tablaAfectada: 'pedidos',
      registroId: pedidoId,
      datosDespues: {
        mesa_id: pedido.mesa_id,
        mensaje: mensaje?.trim() || null,
      },
    });

    this.soporte.notificarLlamadaMesera(
      pedido.sucursal_id,
      pedidoId,
      pedido.numero_pedido,
      pedido.mesa_id,
      mesa?.nombre,
      mensaje,
    );

    return {
      pedido_id: pedidoId,
      mesa_id: pedido.mesa_id,
      mensaje: 'Avisamos a la mesera. Te atenderán en breve.',
    };
  }

  /** DOM-008: calificación post-entrega domicilio. */
  async calificarDomicilio(
    pedidoId: string,
    deviceId: string,
    calificacion: number,
    comentario?: string,
  ) {
    const pedido = await this.database.consultarUno<{
      id: string;
      tipo: string;
      estado: string;
    }>(
      `SELECT id, tipo, estado FROM pedidos
       WHERE id = $1 AND device_id = $2`,
      [pedidoId, deviceId],
    );
    if (!pedido) {
      throw new NotFoundException('Pedido no encontrado');
    }
    if (pedido.tipo !== 'domicilio') {
      throw new BadRequestException({
        error: 'TIPO_PEDIDO_INVALIDO',
        message: 'Solo puedes calificar pedidos a domicilio',
      });
    }
    if (pedido.estado !== 'entregado' && pedido.estado !== 'pagado') {
      throw new BadRequestException({
        error: 'PEDIDO_NO_ENTREGADO',
        message: 'Califica cuando el pedido esté entregado',
      });
    }

    const asignacion = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM asignaciones_domicilio
       WHERE pedido_id = $1 AND estado = 'entregado'
       ORDER BY entregado_at DESC NULLS LAST
       LIMIT 1`,
      [pedidoId],
    );
    if (!asignacion) {
      throw new BadRequestException('Sin asignación de domicilio entregada');
    }

    const ya = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM calificaciones_domiciliario
       WHERE asignacion_id = $1 AND device_id = $2`,
      [asignacion.id, deviceId],
    );
    if (ya) {
      throw new BadRequestException({
        error: 'CALIFICACION_YA_REGISTRADA',
        message: 'Ya calificaste este pedido',
      });
    }

    await this.database.consultar(
      `INSERT INTO calificaciones_domiciliario
         (asignacion_id, device_id, calificacion, comentario)
       VALUES ($1, $2, $3, $4)`,
      [asignacion.id, deviceId, calificacion, comentario?.trim() || null],
    );

    return {
      pedido_id: pedidoId,
      calificacion,
      mensaje: 'Gracias por tu calificación',
    };
  }
}
