import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { DispatchService } from '../domiciliarios/dispatch.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { CosteoService } from '../costeo/costeo.service';
import { PedidosCajaAuditoriaService } from './pedidos-caja-auditoria.service';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
import { PedidosInventarioService } from './pedidos-inventario.service';
import {
  puedeMarcarPagando,
  estadoActivaCocina,
  transicionEstadoPermitida,
} from './pedido-estados';
import { PedidosSoporteService } from './pedidos-soporte.service';

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

/** Subdominio: transiciones de estado, aprobación y rechazo de pedidos mesa. */
@Injectable()
export class PedidosEstadoService {
  private readonly inventario: PedidosInventarioService;

  constructor(
    private readonly database: DatabaseService,
    private readonly dispatch: DispatchService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly costeo: CosteoService,
    private readonly cajaAuditoria: PedidosCajaAuditoriaService,
    private readonly cuentaMesa: PedidosCuentaMesaService,
    private readonly soporte: PedidosSoporteService,
  ) {
    this.inventario = new PedidosInventarioService(
      this.costeo,
      this.alertasRiesgo,
    );
  }

  async cambiarEstado(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    nuevoEstado: string,
    motivo?: string,
    contexto?: { rol: string; permisos: string[] },
  ) {
    if (
      !ESTADOS_KANBAN.includes(nuevoEstado as (typeof ESTADOS_KANBAN)[number]) &&
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
      }>(
        client,
        `SELECT id, estado, tipo, mesa_id, stock_descontado, created_at FROM pedidos
         WHERE id = $1 AND sucursal_id = $2
         FOR UPDATE`,
        [pedidoId, sucursalId],
      );

      if (!pedido) {
        throw new NotFoundException('Pedido no encontrado');
      }

      if (nuevoEstado === 'cancelado' && contexto) {
        this.soporte.validarCancelacion(
          pedido,
          contexto.rol,
          contexto.permisos,
          motivo,
        );
      }

      const anterior = pedido.estado;
      if (anterior === nuevoEstado) {
        return {
          id: pedidoId,
          estado: nuevoEstado,
          tipo: pedido.tipo,
          mesa_id: pedido.mesa_id,
        };
      }

      if (!transicionEstadoPermitida(anterior, nuevoEstado, pedido.tipo, pedido.mesa_id)) {
        throw new BadRequestException({
          error: 'TRANSICION_ESTADO_INVALIDA',
          message: `No se puede pasar de «${anterior}» a «${nuevoEstado}»`,
        });
      }

      if (
        nuevoEstado === 'pagando' &&
        !puedeMarcarPagando(pedido.tipo, pedido.mesa_id)
      ) {
        throw new BadRequestException({
          error: 'PAGANDO_NO_APLICA',
          message: 'Solo pedidos de mesa o para llevar pueden marcarse como pagando',
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
      }

      if (nuevoEstado === 'cancelado' && pedido.stock_descontado) {
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

      await client.query(`UPDATE pedidos SET estado = $1 WHERE id = $2`, [
        nuevoEstado,
        pedidoId,
      ]);

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

      await client.query(
        `INSERT INTO estados_pedido_historial
           (pedido_id, estado_anterior, estado_nuevo, usuario_id, motivo)
         VALUES ($1, $2, $3, $4, $5)`,
        [pedidoId, anterior, nuevoEstado, usuarioId, motivo ?? null],
      );

      if (nuevoEstado === 'cancelado') {
        await client.query(
          `UPDATE asignaciones_domicilio SET estado = 'entregado', entregado_at = COALESCE(entregado_at, now())
           WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')`,
          [pedidoId],
        );
        await this.alertasRiesgo.evaluarCancelacionesFrecuentes(
          client,
          sucursalId,
          usuarioId,
          pedidoId,
        );
      }

      return {
        id: pedidoId,
        estado: nuevoEstado,
        estado_anterior: anterior,
        tipo: pedido.tipo,
        mesa_id: pedido.mesa_id,
      };
    });

    if (nuevoEstado === 'listo' && result.tipo === 'domicilio') {
      try {
        await this.dispatch.intentarDispatchAutomatico(pedidoId, sucursalId);
      } catch {
        // Dispatch no debe bloquear el cambio de estado del pedido
      }
      void this.alertasRiesgo.registrar({
        sucursalId,
        tipo: 'domicilio_listo_sin_asignar',
        nivel: 'medio',
        descripcion: `Pedido listo — asignar domiciliario (${pedidoId})`,
        referenciaId: pedidoId,
        referenciaTipo: 'pedido',
        deduplicar: true,
      });
    }

    if (nuevoEstado === 'en_cocina' && result.estado_anterior !== 'en_cocina') {
      void this.soporte.notificarCocinasPorPedido(pedidoId, sucursalId);
    }

    const { tipo: _tipo, ...respuesta } = result;
    this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, nuevoEstado);
    this.soporte.notificarCatalogoDisponibilidad(sucursalId, catalogoCambios);
    return respuesta;
  }

  async aprobarMesa(pedidoId: string, sucursalId: string, usuarioId: string) {
    let catalogoCambios: { producto_id: string; disponible: boolean }[] = [];
    const result = await this.database.enTransaccion(async (client) => {
      const pedido = await this.soporte.consultarUnoCliente<{
        id: string;
        estado: string;
        mesa_id: string | null;
        tipo: string;
        stock_descontado: boolean;
      }>(
        client,
        `SELECT id, estado, mesa_id, tipo, stock_descontado
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [pedidoId, sucursalId],
      );
      if (!pedido) throw new NotFoundException('Pedido no encontrado');
      if (pedido.estado !== 'pendiente_aprobacion') {
        throw new BadRequestException('El pedido no está pendiente de aprobación');
      }
      if (pedido.mesa_id) {
        await this.soporte.assertMeseraPuedeTomarMesa(
          client,
          sucursalId,
          pedido.mesa_id,
          usuarioId,
        );
      }

      if (!pedido.stock_descontado) {
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
      }

      await client.query(
        `UPDATE pedidos
         SET estado = 'en_cocina', mesera_id = $1, aprobado_at = now()
         WHERE id = $2`,
        [usuarioId, pedidoId],
      );

      if (pedido.mesa_id) {
        await this.soporte.asignarMeseraAMesa(
          client,
          sucursalId,
          pedido.mesa_id,
          usuarioId,
        );
      }

      await client.query(
        `INSERT INTO estados_pedido_historial
           (pedido_id, estado_anterior, estado_nuevo, usuario_id)
         VALUES ($1, 'pendiente_aprobacion', 'en_cocina', $2)`,
        [pedidoId, usuarioId],
      );

      return { id: pedidoId, estado: 'en_cocina' };
    });

    this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, 'en_cocina');
    this.soporte.notificarCatalogoDisponibilidad(sucursalId, catalogoCambios);
    void this.soporte.notificarCocinasPorPedido(pedidoId, sucursalId);
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
      }>(
        client,
        `SELECT id, estado, mesa_id, stock_descontado
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [pedidoId, sucursalId],
      );
      if (!pedido) throw new NotFoundException('Pedido no encontrado');
      if (pedido.estado !== estadoEsperado) {
        throw new BadRequestException('El pedido no está pendiente de aprobación');
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
        await this.cajaAuditoria.revertirVentasPedido(
          client,
          pedidoId,
          sucursalId,
          usuarioId,
          motivo ?? 'Pedido rechazado',
        );
      }

      await client.query(`UPDATE pedidos SET estado = $1 WHERE id = $2`, [
        nuevoEstado,
        pedidoId,
      ]);
      await client.query(
        `INSERT INTO estados_pedido_historial
           (pedido_id, estado_anterior, estado_nuevo, usuario_id, motivo)
         VALUES ($1,$2,$3,$4,$5)`,
        [pedidoId, estadoEsperado, nuevoEstado, usuarioId, motivo ?? null],
      );

      if (nuevoEstado === 'rechazado' && pedido.mesa_id) {
        await this.cuentaMesa.liberarMesaSiSinPedidosActivos(
          client,
          pedido.mesa_id,
          sucursalId,
        );
      }

      return { id: pedidoId, estado: nuevoEstado };
    });
    this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, nuevoEstado);
    this.soporte.notificarCatalogoDisponibilidad(sucursalId, catalogoCambios);
    return result;
  }
}
