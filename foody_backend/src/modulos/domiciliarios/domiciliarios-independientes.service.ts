import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient, QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { PedidosCajaAuditoriaService } from '../pedidos/pedidos-caja-auditoria.service';
import { PedidosEstadoCommandService } from '../pedidos/pedidos-estado-command.service';
import { PedidosSoporteService } from '../pedidos/pedidos-soporte.service';
import { ConfirmarEntregaDto } from './dto/confirmar-entrega.dto';
import { DispatchService } from './dispatch.service';
import { repartirCobroDomicilio } from './cobro-domicilio.util';
import {
  IniciarSesionDto,
  ResponderOfertaDto,
  UbicacionEntregaDto,
} from './dto/independiente.dto';

@Injectable()
export class DomiciliariosIndependientesService {
  constructor(
    private readonly database: DatabaseService,
    private readonly dispatch: DispatchService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly realtime: RealtimeBroadcastService,
    private readonly cajaAuditoria: PedidosCajaAuditoriaService,
    private readonly pedidosEstadoCommand: PedidosEstadoCommandService,
    private readonly pedidosSoporte: PedidosSoporteService,
  ) {}

  async iniciarSesion(domiciliarioId: string, dto: IniciarSesionDto) {
    const dom = await this.obtenerActivo(domiciliarioId);

    await this.database.consultar(
      `UPDATE domiciliarios_sesiones
       SET activa = false, cerrada_at = now(), disponible = false
       WHERE domiciliario_id = $1 AND activa = true`,
      [domiciliarioId],
    );

    const ciudadId = dto.ciudad_id ?? dom.ciudad_id;
    const insert = await this.database.consultarUno<{ id: string }>(
      `INSERT INTO domiciliarios_sesiones (
         domiciliario_id, lat_actual, lng_actual, ciudad_id, disponible, activa
       ) VALUES ($1,$2,$3,$4,true,true)
       RETURNING id`,
      [domiciliarioId, dto.lat, dto.lng, ciudadId],
    );

    return { sesion_id: insert?.id, disponible: true };
  }

  async actualizarUbicacion(domiciliarioId: string, dto: UbicacionEntregaDto) {
    const sesion = await this.obtenerSesionActiva(domiciliarioId);
    await this.database.consultar(
      `UPDATE domiciliarios_sesiones
       SET lat_actual = $1, lng_actual = $2
       WHERE id = $3`,
      [dto.lat, dto.lng, sesion.id],
    );

    const params: unknown[] = [domiciliarioId];
    let filtroPedido = '';
    if (dto.pedido_id) {
      filtroPedido = ' AND ad.pedido_id = $2';
      params.push(dto.pedido_id);
    }

    const asignacion = await this.database.consultarUno<{
      id: string;
      pedido_id: string;
    }>(
      `SELECT ad.id, ad.pedido_id
       FROM asignaciones_domicilio ad
       WHERE ad.domiciliario_independiente_id = $1
         AND ad.estado = 'en_camino'${filtroPedido}
       ORDER BY ad.asignado_at DESC
       LIMIT 1`,
      params,
    );

    if (asignacion) {
      await this.database.consultar(
        `INSERT INTO domiciliarios_ubicaciones_historial (asignacion_id, lat, lng)
         VALUES ($1, $2, $3)`,
        [asignacion.id, dto.lat, dto.lng],
      );
      this.pedidosSoporte.emitirUbicacionRepartidor(asignacion.pedido_id, {
        repartidor_lat: dto.lat,
        repartidor_lng: dto.lng,
      });
    }

    return { ok: true, registrado: !!asignacion };
  }

  async cerrarSesion(domiciliarioId: string) {
    await this.database.consultar(
      `UPDATE domiciliarios_sesiones
       SET activa = false, disponible = false, cerrada_at = now()
       WHERE domiciliario_id = $1 AND activa = true`,
      [domiciliarioId],
    );
    return { ok: true };
  }

  async estadoSesion(domiciliarioId: string) {
    const sesion = await this.database.consultarUno<{
      activa: boolean;
      disponible: boolean;
    }>(
      `SELECT activa, disponible FROM domiciliarios_sesiones
       WHERE domiciliario_id = $1 AND activa = true
       ORDER BY iniciada_at DESC LIMIT 1`,
      [domiciliarioId],
    );
    return {
      activa: !!sesion,
      disponible: sesion?.disponible ?? false,
    };
  }

  async ofertasActivas(domiciliarioId: string) {
    const filas = await this.database.consultar<{
      oferta_id: string;
      pedido_id: string;
      radio_busqueda_km: string;
      intento_numero: number;
      expira_at: Date;
      numero_pedido: string;
      direccion_entrega: string | null;
      costo_domicilio: string;
      cliente_nombre: string | null;
      lat: string | null;
      lng: string | null;
      sucursal_nombre: string;
      sucursal_direccion: string | null;
      sucursal_lat: string | null;
      sucursal_lng: string | null;
      respuesta_id: string;
    }>(
      `SELECT o.id AS oferta_id,
              o.pedido_id,
              o.radio_busqueda_km,
              o.intento_numero,
              o.expira_at,
              p.numero_pedido,
              p.direccion_entrega,
              p.costo_domicilio,
              p.cliente_nombre,
              p.lat,
              p.lng,
              s.nombre AS sucursal_nombre,
              s.direccion AS sucursal_direccion,
              s.lat AS sucursal_lat,
              s.lng AS sucursal_lng,
              r.id AS respuesta_id
       FROM respuestas_oferta r
       JOIN ofertas_pedido o ON o.id = r.oferta_id
       JOIN pedidos p ON p.id = o.pedido_id
       JOIN sucursales s ON s.id = o.sucursal_id
       WHERE r.domiciliario_id = $1
         AND o.estado = 'activa'
         AND o.expira_at > now()
         AND p.estado = 'listo'
         AND NOT EXISTS (
           SELECT 1 FROM asignaciones_domicilio ad
           WHERE ad.pedido_id = p.id
             AND ad.estado IN ('asignado', 'en_camino')
         )
         AND r.respuesta = 'no_vio'
       ORDER BY o.created_at DESC`,
      [domiciliarioId],
    );

    return filas.map((f) => {
      const costo = Number(f.costo_domicilio ?? 0);
      const { comision, ganancia } = this.dispatch.calcularGanancias(costo);
      return {
        ...f,
        comision_foody_pct:
          costo > 0 ? Math.round((comision / costo) * 100) : 15,
        comision_foody: comision,
        ganancia_estimada: ganancia,
        valor_domicilio: costo,
      };
    });
  }

  async responderOferta(
    ofertaId: string,
    domiciliarioId: string,
    dto: ResponderOfertaDto,
  ) {
    return this.database.enTransaccion(async (client) => {
      const referenciaOferta = await this.consultarUnoCliente<{
        id: string;
        pedido_id: string;
        sucursal_id: string;
      }>(
        client,
        `SELECT id, pedido_id, sucursal_id
         FROM ofertas_pedido WHERE id = $1`,
        [ofertaId],
      );

      if (!referenciaOferta) {
        throw new NotFoundException('Oferta no encontrada');
      }

      if (dto.respuesta === 'rechazada') {
        const oferta = await this.consultarUnoCliente<{
          id: string;
          estado: string;
          expira_at: Date;
        }>(
          client,
          `SELECT id, estado, expira_at FROM ofertas_pedido
           WHERE id = $1 AND pedido_id = $2 AND sucursal_id = $3 FOR UPDATE`,
          [ofertaId, referenciaOferta.pedido_id, referenciaOferta.sucursal_id],
        );
        if (
          !oferta ||
          oferta.estado !== 'activa' ||
          new Date(oferta.expira_at) <= new Date()
        ) {
          throw new BadRequestException('La oferta expiró o ya no está activa');
        }
        const respuesta = await this.consultarUnoCliente<{
          id: string;
          respuesta: string;
        }>(
          client,
          `SELECT id, respuesta FROM respuestas_oferta
           WHERE oferta_id = $1 AND domiciliario_id = $2 FOR UPDATE`,
          [ofertaId, domiciliarioId],
        );
        if (!respuesta) {
          throw new BadRequestException(
            'No fuiste notificado para esta oferta',
          );
        }
        if (respuesta.respuesta !== 'no_vio') {
          throw new BadRequestException('Ya respondiste esta oferta');
        }
        await client.query(
          `UPDATE respuestas_oferta SET respuesta = 'rechazada', respondido_at = now()
           WHERE id = $1`,
          [respuesta.id],
        );
        return { oferta_id: ofertaId, respuesta: 'rechazada' };
      }

      const pedido = await this.consultarUnoCliente<{
        id: string;
        estado: string;
        costo_domicilio: string;
      }>(
        client,
        `SELECT id, estado, costo_domicilio FROM pedidos
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [referenciaOferta.pedido_id, referenciaOferta.sucursal_id],
      );
      if (!pedido || pedido.estado !== 'listo') {
        throw new BadRequestException('El pedido ya no está disponible');
      }

      // Lock order first, then offer: cancellation uses the same order and
      // avoids a pedido↔oferta deadlock while closing active offers.
      const oferta = await this.consultarUnoCliente<{
        id: string;
        estado: string;
        expira_at: Date;
      }>(
        client,
        `SELECT id, estado, expira_at FROM ofertas_pedido
         WHERE id = $1 AND pedido_id = $2 AND sucursal_id = $3 FOR UPDATE`,
        [ofertaId, referenciaOferta.pedido_id, referenciaOferta.sucursal_id],
      );
      if (
        !oferta ||
        oferta.estado !== 'activa' ||
        new Date(oferta.expira_at) <= new Date()
      ) {
        throw new BadRequestException('La oferta expiró o ya no está activa');
      }

      const respuesta = await this.consultarUnoCliente<{
        id: string;
        respuesta: string;
      }>(
        client,
        `SELECT id, respuesta FROM respuestas_oferta
         WHERE oferta_id = $1 AND domiciliario_id = $2 FOR UPDATE`,
        [ofertaId, domiciliarioId],
      );
      if (!respuesta) {
        throw new BadRequestException('No fuiste notificado para esta oferta');
      }
      if (respuesta.respuesta !== 'no_vio') {
        throw new BadRequestException('Ya respondiste esta oferta');
      }

      const domiciliario = await this.consultarUnoCliente<{ id: string }>(
        client,
        `SELECT id FROM domiciliarios_independientes
         WHERE id = $1 FOR UPDATE`,
        [domiciliarioId],
      );
      if (!domiciliario) {
        throw new NotFoundException('Domiciliario no encontrado');
      }
      const sesionDisponible = await this.consultarUnoCliente<{ id: string }>(
        client,
        `SELECT id FROM domiciliarios_sesiones
         WHERE domiciliario_id = $1 AND activa = true AND disponible = true
         ORDER BY iniciada_at DESC LIMIT 1 FOR UPDATE`,
        [domiciliarioId],
      );
      if (!sesionDisponible) {
        throw new BadRequestException(
          'Activa tu disponibilidad antes de aceptar otro pedido',
        );
      }

      const ocupado = await this.consultarUnoCliente<{ id: string }>(
        client,
        `SELECT id FROM asignaciones_domicilio
         WHERE domiciliario_independiente_id = $1
           AND estado IN ('asignado', 'en_camino')`,
        [domiciliarioId],
      );
      if (ocupado) {
        throw new BadRequestException('Ya tienes un pedido activo');
      }

      const despacho = await this.dispatch.validarPedidoParaDespacho(
        referenciaOferta.pedido_id,
        referenciaOferta.sucursal_id,
        client,
      );
      if (!despacho.valido) {
        throw new BadRequestException(despacho.mensaje);
      }

      const yaAsignado = await this.consultarUnoCliente<{ id: string }>(
        client,
        `SELECT id FROM asignaciones_domicilio
         WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')`,
        [referenciaOferta.pedido_id],
      );
      if (yaAsignado) {
        await client.query(
          `UPDATE ofertas_pedido SET estado = 'cancelada' WHERE id = $1`,
          [ofertaId],
        );
        throw new BadRequestException('Otro domiciliario ya tomó el pedido');
      }

      await client.query(
        `UPDATE ofertas_pedido SET estado = 'aceptada' WHERE id = $1`,
        [ofertaId],
      );
      await client.query(
        `UPDATE respuestas_oferta SET respuesta = 'aceptada', respondido_at = now()
         WHERE oferta_id = $1 AND domiciliario_id = $2`,
        [ofertaId, domiciliarioId],
      );
      await client.query(
        `UPDATE respuestas_oferta SET respuesta = 'rechazada', respondido_at = now()
         WHERE oferta_id = $1 AND domiciliario_id != $2 AND respuesta = 'no_vio'`,
        [ofertaId, domiciliarioId],
      );
      await client.query(
        `WITH canceladas AS (
           UPDATE ofertas_pedido
           SET estado = 'cancelada'
           WHERE pedido_id = $1 AND id <> $2 AND estado = 'activa'
           RETURNING id
         )
         UPDATE respuestas_oferta
         SET respuesta = 'rechazada', respondido_at = now()
         WHERE oferta_id IN (SELECT id FROM canceladas)
           AND respuesta = 'no_vio'`,
        [referenciaOferta.pedido_id, ofertaId],
      );

      const asignacion = await client.query<{ id: string }>(
        `INSERT INTO asignaciones_domicilio (
           pedido_id, sucursal_id, domiciliario_independiente_id,
           tipo_domiciliario, estado, distancia_km
         )
         SELECT $1, $2, $3::uuid, 'independiente', 'asignado',
           CASE
             WHEN s.lat IS NOT NULL AND s.lng IS NOT NULL
              AND p.lat IS NOT NULL AND p.lng IS NOT NULL
             THEN ROUND((
               6371 * acos(LEAST(1::float8, GREATEST(-1::float8,
                 cos(radians(s.lat::float8)) * cos(radians(p.lat::float8))
                 * cos(radians(p.lng::float8) - radians(s.lng::float8))
                 + sin(radians(s.lat::float8)) * sin(radians(p.lat::float8))
               )))
             )::numeric, 3)
             ELSE NULL
           END
         FROM pedidos p
         JOIN sucursales s ON s.id = p.sucursal_id
         WHERE p.id = $1 AND p.sucursal_id = $2
         RETURNING id`,
        [
          referenciaOferta.pedido_id,
          referenciaOferta.sucursal_id,
          domiciliarioId,
        ],
      );
      const asignacionId = asignacion.rows[0].id;

      await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
        pedidoId: referenciaOferta.pedido_id,
        sucursalId: referenciaOferta.sucursal_id,
        nuevoEstado: 'asignado',
        origen: 'domiciliario',
        motivo: 'Domiciliario independiente aceptó oferta',
        estadoAnterior: 'listo',
        tipo: 'domicilio',
      });

      await client.query(
        `UPDATE domiciliarios_sesiones SET disponible = false
         WHERE domiciliario_id = $1 AND activa = true`,
        [domiciliarioId],
      );

      const costo = Number(pedido.costo_domicilio ?? 0);
      const { comision, ganancia } = this.dispatch.calcularGanancias(costo);
      if (costo > 0) {
        await client.query(
          `INSERT INTO ganancias_domiciliario (
             domiciliario_id, asignacion_id, valor_domicilio,
             comision_foody, ganancia_domiciliario
           ) VALUES ($1,$2,$3,$4,$5)`,
          [domiciliarioId, asignacionId, costo, comision, ganancia],
        );
      }

      return {
        oferta_id: ofertaId,
        respuesta: 'aceptada',
        pedido_id: referenciaOferta.pedido_id,
        asignacion_id: asignacionId,
        estado: 'asignado',
      };
    });
  }

  async pedidosActivos(domiciliarioId: string) {
    const pedidos = await this.database.consultar<{
      id: string;
      numero_pedido: string;
      estado: string;
      cliente_nombre: string | null;
      cliente_telefono: string | null;
      direccion_entrega: string | null;
      subtotal: string;
      total: string;
      monto_pagado: string;
      metodo_pago: string | null;
      pagos_resumen: Array<{ metodo_pago: string; monto: string | number }>;
      costo_domicilio: string;
      lat: string | null;
      lng: string | null;
      estado_asignacion: string;
      asignado_at: string;
      sucursal_nombre: string;
      sucursal_direccion: string | null;
      sucursal_lat: string | null;
      sucursal_lng: string | null;
    }>(
      `SELECT p.id,
              p.numero_pedido,
              p.estado,
              p.cliente_nombre,
              p.cliente_telefono,
              p.direccion_entrega,
              p.subtotal,
              p.total,
              COALESCE(p.monto_pagado, 0) AS monto_pagado,
              p.metodo_pago,
              COALESCE(pagos.resumen, '[]'::jsonb) AS pagos_resumen,
              p.costo_domicilio,
              p.lat,
              p.lng,
              ad.estado AS estado_asignacion,
              ad.asignado_at,
              s.nombre AS sucursal_nombre,
              s.direccion AS sucursal_direccion,
              s.lat AS sucursal_lat,
              s.lng AS sucursal_lng
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id AND p.sucursal_id = ad.sucursal_id
       JOIN sucursales s ON s.id = ad.sucursal_id
       LEFT JOIN LATERAL (
         SELECT jsonb_agg(jsonb_build_object(
           'metodo_pago', pagos.metodo_pago,
           'monto', pagos.monto
         ) ORDER BY pagos.metodo_pago) AS resumen
         FROM (
           SELECT pp.metodo_pago, SUM(pp.monto) AS monto
           FROM pagos_pedido pp
           WHERE pp.pedido_id = p.id AND pp.sucursal_id = p.sucursal_id
           GROUP BY pp.metodo_pago
         ) pagos
       ) pagos ON true
       WHERE ad.domiciliario_independiente_id = $1
         AND ad.estado IN ('asignado', 'en_camino')
       ORDER BY ad.asignado_at ASC`,
      [domiciliarioId],
    );

    return pedidos.map((pedido) => {
      const cobro = repartirCobroDomicilio(
        Number(pedido.total),
        Number(pedido.costo_domicilio ?? 0),
        Number(pedido.monto_pagado ?? 0),
      );
      return {
        ...pedido,
        saldo_pendiente: cobro.saldo,
        requiere_cobro: cobro.saldo > 0.01,
        producto_total: cobro.productoTotal,
        producto_pendiente: cobro.productoPendiente,
        domicilio_pendiente: cobro.domicilioPendiente,
      };
    });
  }

  async marcarEnCamino(pedidoId: string, domiciliarioId: string) {
    return this.database.enTransaccion(async (client) => {
      const asignacion = await this.consultarUnoCliente<{
        id: string;
        sucursal_id: string;
      }>(
        client,
        `SELECT id, sucursal_id FROM asignaciones_domicilio
         WHERE pedido_id = $1
           AND domiciliario_independiente_id = $2
           AND estado = 'asignado' FOR UPDATE`,
        [pedidoId, domiciliarioId],
      );
      if (!asignacion) {
        throw new BadRequestException('Pedido no asignado a ti');
      }

      await client.query(
        `UPDATE asignaciones_domicilio SET estado = 'en_camino' WHERE id = $1`,
        [asignacion.id],
      );
      await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
        pedidoId,
        sucursalId: asignacion.sucursal_id,
        nuevoEstado: 'en_camino',
        origen: 'domiciliario',
        motivo: 'Domiciliario independiente en camino',
        estadoAnterior: 'asignado',
        tipo: 'domicilio',
      });

      return { pedido_id: pedidoId, estado: 'en_camino' };
    });
  }

  async confirmarEntrega(
    pedidoId: string,
    domiciliarioId: string,
    dto: ConfirmarEntregaDto = {},
  ) {
    const result = await this.database.enTransaccion(async (client) => {
      const asignacion = await this.consultarUnoCliente<{ id: string }>(
        client,
        `SELECT id FROM asignaciones_domicilio
         WHERE pedido_id = $1
           AND domiciliario_independiente_id = $2
           AND estado = 'en_camino' FOR UPDATE`,
        [pedidoId, domiciliarioId],
      );
      if (!asignacion) {
        throw new BadRequestException('El pedido debe estar en camino');
      }

      const pedidoRow = await this.consultarUnoCliente<{
        sucursal_id: string;
        numero_pedido: string;
        total: string;
        costo_domicilio: string;
        monto_pagado: string;
        metodo_pago: string | null;
      }>(
        client,
        `SELECT sucursal_id, numero_pedido, total,
                COALESCE(costo_domicilio, 0) AS costo_domicilio,
                COALESCE(monto_pagado, 0) AS monto_pagado, metodo_pago
         FROM pedidos WHERE id = $1 FOR UPDATE`,
        [pedidoId],
      );
      if (!pedidoRow) {
        throw new NotFoundException('Pedido no encontrado');
      }

      const cfg = await this.consultarUnoCliente<{
        domicilio_ingresa_a_caja: boolean;
      }>(
        client,
        `SELECT COALESCE(domicilio_ingresa_a_caja, false) AS domicilio_ingresa_a_caja
         FROM sucursales WHERE id = $1`,
        [pedidoRow.sucursal_id],
      );
      const domicilioEnCaja = cfg?.domicilio_ingresa_a_caja ?? false;

      const { saldo, productoPendiente, domicilioPendiente } =
        repartirCobroDomicilio(
          Number(pedidoRow.total),
          Number(pedidoRow.costo_domicilio),
          Number(pedidoRow.monto_pagado ?? 0),
        );
      const metodoEntrega = dto.metodo_pago?.trim();
      const metodoDomicilio =
        dto.metodo_pago_domicilio?.trim() || metodoEntrega;

      if (saldo > 0.01) {
        if (!metodoEntrega || metodoEntrega === 'pendiente') {
          throw new BadRequestException({
            error: 'COBRO_REQUERIDO',
            message:
              'Indica método de pago al entregar (efectivo, tarjeta, transferencia o nequi)',
          });
        }
        // El producto siempre entra a caja; el domicilio (ingreso del
        // independiente) solo si la sucursal lo cobra para sí.
        if (productoPendiente > 0.01) {
          await client.query(
            `INSERT INTO pagos_pedido (
               sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
             ) VALUES ($1,$2,$3,0,$4,NULL,$5)`,
            [
              pedidoRow.sucursal_id,
              pedidoId,
              productoPendiente,
              metodoEntrega,
              'Cobro producto contra entrega (independiente)',
            ],
          );
          await this.cajaAuditoria.registrarVentaEnCaja(
            client,
            pedidoRow.sucursal_id,
            pedidoId,
            productoPendiente,
            metodoEntrega,
            {
              exigirCaja: true,
              descripcion: `Domicilio independiente entregado ${pedidoRow.numero_pedido}`,
            },
          );
        }
        if (domicilioPendiente > 0.01) {
          await client.query(
            `INSERT INTO pagos_pedido (
               sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
             ) VALUES ($1,$2,$3,0,$4,NULL,$5)`,
            [
              pedidoRow.sucursal_id,
              pedidoId,
              domicilioPendiente,
              metodoDomicilio,
              domicilioEnCaja
                ? 'Cobro domicilio contra entrega (independiente)'
                : 'Domicilio independiente (fuera de caja)',
            ],
          );
          if (domicilioEnCaja) {
            await this.cajaAuditoria.registrarVentaEnCaja(
              client,
              pedidoRow.sucursal_id,
              pedidoId,
              domicilioPendiente,
              metodoDomicilio ?? metodoEntrega,
              {
                exigirCaja: true,
                descripcion: `Domicilio (cobro) ${pedidoRow.numero_pedido}`,
              },
            );
          }
        }
        await client.query(
          `UPDATE pedidos
           SET monto_pagado = $2, metodo_pago = $3
           WHERE id = $1`,
          [pedidoId, Number(pedidoRow.total), metodoEntrega],
        );
      } else if (metodoEntrega && metodoEntrega !== 'pendiente') {
        await client.query(
          `UPDATE pedidos SET metodo_pago = $1 WHERE id = $2`,
          [metodoEntrega, pedidoId],
        );
      }

      await client.query(
        `UPDATE asignaciones_domicilio
         SET estado = 'entregado', entregado_at = now()
         WHERE id = $1`,
        [asignacion.id],
      );
      await client.query(
        `UPDATE domiciliarios_independientes
         SET total_entregas = total_entregas + 1
         WHERE id = $1`,
        [domiciliarioId],
      );
      await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
        pedidoId,
        sucursalId: pedidoRow.sucursal_id,
        nuevoEstado: 'entregado',
        origen: 'domiciliario',
        motivo: 'Entrega confirmada por independiente',
        estadoAnterior: 'en_camino',
        tipo: 'domicilio',
      });
      await client.query(
        `UPDATE domiciliarios_sesiones SET disponible = true
         WHERE domiciliario_id = $1 AND activa = true`,
        [domiciliarioId],
      );

      await this.alertasRiesgo.evaluarDemoraEntrega(
        client,
        pedidoId,
        pedidoRow.sucursal_id,
      );

      return {
        pedido_id: pedidoId,
        estado: 'entregado',
        sucursal_id: pedidoRow.sucursal_id,
        numero_pedido: pedidoRow.numero_pedido,
      };
    });

    void this.realtime.pedidoActualizado({
      pedido_id: result.pedido_id,
      sucursal_id: result.sucursal_id,
      estado: result.estado,
      numero_pedido: result.numero_pedido,
    });
    void this.realtime.cajaMovimiento(result.sucursal_id, {
      pedido_id: result.pedido_id,
    });

    return { pedido_id: result.pedido_id, estado: result.estado };
  }

  async ganancias(
    domiciliarioId: string,
    opts?: { desde?: string; hasta?: string },
  ) {
    const params: unknown[] = [domiciliarioId];
    let filtroFecha = '';
    if (opts?.desde) {
      params.push(opts.desde);
      filtroFecha += ` AND g.created_at >= $${params.length}::timestamptz`;
    }
    if (opts?.hasta) {
      params.push(opts.hasta);
      filtroFecha += ` AND g.created_at < ($${params.length}::date + interval '1 day')`;
    }

    const filas = await this.database.consultar<{
      id: string;
      valor_domicilio: string;
      comision_foody: string;
      ganancia_domiciliario: string;
      pagado: boolean;
      created_at: Date;
      pedido_id: string | null;
      numero_pedido: string | null;
    }>(
      `SELECT g.id, g.valor_domicilio, g.comision_foody, g.ganancia_domiciliario,
              g.pagado, g.created_at, ad.pedido_id, ad.estado AS estado_asignacion,
              p.numero_pedido
       FROM ganancias_domiciliario g
       LEFT JOIN asignaciones_domicilio ad ON ad.id = g.asignacion_id
       LEFT JOIN pedidos p ON p.id = ad.pedido_id
       WHERE g.domiciliario_id = $1${filtroFecha}
       ORDER BY g.created_at DESC
       LIMIT 100`,
      params,
    );

    const totalGanancia = filas.reduce(
      (s, f) => s + Number(f.ganancia_domiciliario ?? 0),
      0,
    );
    const totalComision = filas.reduce(
      (s, f) => s + Number(f.comision_foody ?? 0),
      0,
    );

    return {
      items: filas,
      resumen: {
        entregas: filas.length,
        total_ganancia: totalGanancia,
        total_comision: totalComision,
      },
    };
  }

  private async obtenerActivo(domiciliarioId: string) {
    const dom = await this.database.consultarUno<{
      id: string;
      ciudad_id: string;
      estado_cuenta: string;
    }>(
      `SELECT id, ciudad_id, estado_cuenta
       FROM domiciliarios_independientes WHERE id = $1`,
      [domiciliarioId],
    );
    if (!dom || dom.estado_cuenta !== 'activo') {
      throw new ForbiddenException('Cuenta no activa');
    }
    return dom;
  }

  private async obtenerSesionActiva(domiciliarioId: string) {
    const sesion = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM domiciliarios_sesiones
       WHERE domiciliario_id = $1 AND activa = true
       ORDER BY iniciada_at DESC LIMIT 1`,
      [domiciliarioId],
    );
    if (!sesion) {
      throw new BadRequestException(
        'Inicia tu turno antes de actualizar ubicación',
      );
    }
    return sesion;
  }

  private async consultarUnoCliente<T extends QueryResultRow>(
    client: PoolClient,
    sql: string,
    params: unknown[],
  ): Promise<T | null> {
    const r = await client.query<T>(sql, params);
    return r.rows[0] ?? null;
  }
}
