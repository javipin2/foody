import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
  forwardRef,
} from '@nestjs/common';
import { PoolClient, QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { PedidosCajaAuditoriaService } from '../pedidos/pedidos-caja-auditoria.service';
import { AsignarDomiciliarioDto } from './dto/asignar-domiciliario.dto';
import { ConfirmarEntregaDto } from './dto/confirmar-entrega.dto';

@Injectable()
export class DomiciliariosService {
  constructor(
    private readonly database: DatabaseService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly realtime: RealtimeBroadcastService,
    @Inject(forwardRef(() => PedidosCajaAuditoriaService))
    private readonly cajaAuditoria: PedidosCajaAuditoriaService,
  ) {}

  async listarPlantaDisponibles(sucursalId: string) {
    return this.database.consultar(
      `SELECT dp.id,
              dp.usuario_id,
              u.nombre,
              u.telefono,
              u.foto_url,
              EXISTS (
                SELECT 1 FROM asignaciones_domicilio ad
                INNER JOIN pedidos p ON p.id = ad.pedido_id
                WHERE ad.domiciliario_planta_id = dp.id
                  AND ad.estado IN ('asignado', 'en_camino')
                  AND p.estado NOT IN ('cancelado', 'rechazado', 'entregado', 'pagado')
              ) AS ocupado
       FROM domiciliarios_planta dp
       JOIN usuarios u ON u.id = dp.usuario_id
       WHERE dp.sucursal_id = $1
         AND dp.activo = true
         AND u.activo = true
       ORDER BY u.nombre`,
      [sucursalId],
    );
  }

  async asignarPlanta(dto: AsignarDomiciliarioDto, usuarioAdminId: string) {
    const result = await this.database.enTransaccion(async (client) => {
      const pedido = await this.consultarUno<{ id: string; tipo: string; estado: string }>(
        client,
        `SELECT id, tipo, estado FROM pedidos
         WHERE id = $1 AND sucursal_id = $2
         FOR UPDATE`,
        [dto.pedido_id, dto.sucursal_id],
      );

      if (!pedido) {
        throw new NotFoundException('Pedido no encontrado');
      }
      if (pedido.tipo !== 'domicilio') {
        throw new BadRequestException('Solo pedidos de domicilio admiten asignación');
      }
      if (pedido.estado !== 'listo') {
        throw new BadRequestException(
          'El pedido debe estar en estado listo para asignar domiciliario',
        );
      }

      const domiciliario = await this.consultarUno<{
        id: string;
        sucursal_id: string;
        usuario_id: string;
      }>(
        client,
        `SELECT dp.id, dp.sucursal_id, dp.usuario_id FROM domiciliarios_planta dp
         WHERE dp.id = $1 AND dp.activo = true`,
        [dto.domiciliario_planta_id],
      );
      if (!domiciliario || domiciliario.sucursal_id !== dto.sucursal_id) {
        throw new BadRequestException('Domiciliario no válido para esta sucursal');
      }

      const ocupado = await this.consultarUno<{ id: string }>(
        client,
        `SELECT ad.id FROM asignaciones_domicilio ad
         INNER JOIN pedidos p ON p.id = ad.pedido_id
         WHERE ad.domiciliario_planta_id = $1
           AND ad.estado IN ('asignado', 'en_camino')
           AND p.estado NOT IN ('cancelado', 'rechazado', 'entregado', 'pagado')
         LIMIT 1`,
        [dto.domiciliario_planta_id],
      );
      if (ocupado) {
        throw new BadRequestException(
          'El domiciliario ya tiene un pedido activo',
        );
      }

      const previa = await this.consultarUno<{ id: string }>(
        client,
        `SELECT id FROM asignaciones_domicilio
         WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')
         LIMIT 1`,
        [dto.pedido_id],
      );
      if (previa) {
        throw new BadRequestException('El pedido ya tiene domiciliario asignado');
      }

      await client.query(
        `INSERT INTO asignaciones_domicilio
           (pedido_id, sucursal_id, domiciliario_planta_id, tipo_domiciliario, estado)
         VALUES ($1, $2, $3, 'planta', 'asignado')`,
        [dto.pedido_id, dto.sucursal_id, dto.domiciliario_planta_id],
      );

      await client.query(`UPDATE pedidos SET estado = 'asignado' WHERE id = $1`, [
        dto.pedido_id,
      ]);

      await client.query(
        `INSERT INTO estados_pedido_historial
           (pedido_id, estado_anterior, estado_nuevo, usuario_id, motivo)
         VALUES ($1, 'listo', 'asignado', $2, 'Domiciliario de planta asignado')`,
        [dto.pedido_id, usuarioAdminId],
      );

      return {
        pedido_id: dto.pedido_id,
        estado: 'asignado',
        sucursal_id: dto.sucursal_id,
        domiciliario_usuario_id: domiciliario.usuario_id,
      };
    });

    void this.realtime.domiciliarioPlantaActualizado(
      result.domiciliario_usuario_id,
      {
        pedido_id: result.pedido_id,
        sucursal_id: result.sucursal_id,
        accion: 'asignado',
      },
    );
    void this.realtime.pedidoActualizado({
      pedido_id: result.pedido_id,
      sucursal_id: result.sucursal_id,
      estado: result.estado,
    });

    return {
      pedido_id: result.pedido_id,
      estado: result.estado,
    };
  }

  async historialEntregas(usuarioId: string, limite = 50) {
    const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
    if (!domiciliario) {
      throw new NotFoundException('No eres domiciliario de planta registrado');
    }

    return this.database.consultar(
      `SELECT p.id,
              p.numero_pedido,
              p.cliente_nombre,
              p.direccion_entrega,
              p.total,
              p.metodo_pago,
              p.estado,
              ad.entregado_at,
              ad.asignado_at
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id
       WHERE ad.domiciliario_planta_id = $1
         AND ad.estado = 'entregado'
       ORDER BY ad.entregado_at DESC NULLS LAST
       LIMIT $2`,
      [domiciliario.id, limite],
    );
  }

  async estadisticasPlanta(usuarioId: string) {
    const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
    if (!domiciliario) {
      throw new NotFoundException('No eres domiciliario de planta registrado');
    }

    const fila = await this.database.consultarUno<{
      hoy: string;
      semana: string;
      mes: string;
      promedio_min: string | null;
    }>(
      `SELECT
         COUNT(*) FILTER (WHERE ad.entregado_at >= date_trunc('day', now()))::text AS hoy,
         COUNT(*) FILTER (WHERE ad.entregado_at >= date_trunc('week', now()))::text AS semana,
         COUNT(*) FILTER (WHERE ad.entregado_at >= date_trunc('month', now()))::text AS mes,
         AVG(
           EXTRACT(EPOCH FROM (ad.entregado_at - ad.asignado_at)) / 60
         ) FILTER (WHERE ad.entregado_at IS NOT NULL)::text AS promedio_min
       FROM asignaciones_domicilio ad
       WHERE ad.domiciliario_planta_id = $1
         AND ad.estado = 'entregado'`,
      [domiciliario.id],
    );

    return {
      entregas_hoy: Number(fila?.hoy ?? 0),
      entregas_semana: Number(fila?.semana ?? 0),
      entregas_mes: Number(fila?.mes ?? 0),
      tiempo_promedio_min: fila?.promedio_min != null
        ? Math.round(Number(fila.promedio_min))
        : null,
    };
  }

  async pedidosAsignados(usuarioId: string) {
    const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
    if (!domiciliario) {
      throw new NotFoundException('No eres domiciliario de planta registrado');
    }

    return this.database.consultar(
      `SELECT p.id,
              p.numero_pedido,
              p.tipo,
              p.estado,
              p.cliente_nombre,
              p.cliente_telefono,
              p.direccion_entrega,
              p.lat,
              p.lng,
              p.total,
              p.metodo_pago,
              p.created_at,
              ad.estado AS estado_asignacion,
              ad.asignado_at
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id
       WHERE ad.domiciliario_planta_id = $1
         AND ad.estado IN ('asignado', 'en_camino')
         AND p.estado IN ('asignado', 'en_camino')
       ORDER BY ad.asignado_at ASC`,
      [domiciliario.id],
    );
  }

  async marcarEnCamino(pedidoId: string, usuarioId: string) {
    const result = await this.database.enTransaccion(async (client) => {
      const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
      if (!domiciliario) {
        throw new NotFoundException('No eres domiciliario de planta registrado');
      }

      const asignacion = await this.consultarUno<{
        id: string;
        pedido_id: string;
        estado: string;
      }>(
        client,
        `SELECT id, pedido_id, estado FROM asignaciones_domicilio
         WHERE pedido_id = $1
           AND domiciliario_planta_id = $2
           AND estado = 'asignado'
         FOR UPDATE`,
        [pedidoId, domiciliario.id],
      );

      if (!asignacion) {
        throw new BadRequestException('Pedido no asignado a ti o ya en camino');
      }

      await client.query(
        `UPDATE asignaciones_domicilio SET estado = 'en_camino' WHERE id = $1`,
        [asignacion.id],
      );
      await client.query(`UPDATE pedidos SET estado = 'en_camino' WHERE id = $1`, [
        pedidoId,
      ]);
      await client.query(
        `INSERT INTO estados_pedido_historial
           (pedido_id, estado_anterior, estado_nuevo, usuario_id)
         VALUES ($1, 'asignado', 'en_camino', $2)`,
        [pedidoId, usuarioId],
      );

      const pedido = await this.consultarUno<{ sucursal_id: string }>(
        client,
        `SELECT sucursal_id FROM pedidos WHERE id = $1`,
        [pedidoId],
      );

      return {
        pedido_id: pedidoId,
        estado: 'en_camino',
        sucursal_id: pedido?.sucursal_id,
      };
    });

    void this.realtime.domiciliarioPlantaActualizado(usuarioId, {
      pedido_id: result.pedido_id,
      accion: 'en_camino',
    });
    if (result.sucursal_id) {
      void this.realtime.pedidoActualizado({
        pedido_id: result.pedido_id,
        sucursal_id: result.sucursal_id,
        estado: result.estado,
      });
    }
    return { pedido_id: result.pedido_id, estado: result.estado };
  }

  async confirmarEntrega(
    pedidoId: string,
    usuarioId: string,
    dto: ConfirmarEntregaDto,
  ) {
    const result = await this.database.enTransaccion(async (client) => {
      const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
      if (!domiciliario) {
        throw new NotFoundException('No eres domiciliario de planta registrado');
      }

      const asignacion = await this.consultarUno<{ id: string; estado: string }>(
        client,
        `SELECT id, estado FROM asignaciones_domicilio
         WHERE pedido_id = $1
           AND domiciliario_planta_id = $2
           AND estado = 'en_camino'
         FOR UPDATE`,
        [pedidoId, domiciliario.id],
      );

      if (!asignacion) {
        throw new BadRequestException(
          'El pedido debe estar en camino y asignado a ti',
        );
      }

      const pedidoRow = await this.consultarUno<{
        sucursal_id: string;
        numero_pedido: string;
        total: string;
        monto_pagado: string;
        metodo_pago: string | null;
      }>(
        client,
        `SELECT sucursal_id, numero_pedido, total,
                COALESCE(monto_pagado, 0) AS monto_pagado, metodo_pago
         FROM pedidos WHERE id = $1 FOR UPDATE`,
        [pedidoId],
      );
      if (!pedidoRow) {
        throw new NotFoundException('Pedido no encontrado');
      }

      const saldo =
        Number(pedidoRow.total) - Number(pedidoRow.monto_pagado ?? 0);
      const metodoEntrega = dto.metodo_pago?.trim();

      if (saldo > 0.01) {
        if (!metodoEntrega || metodoEntrega === 'pendiente') {
          throw new BadRequestException({
            error: 'COBRO_REQUERIDO',
            message:
              'Indica método de pago al entregar (efectivo, tarjeta, transferencia o nequi)',
          });
        }
        await client.query(
          `INSERT INTO pagos_pedido (
             sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
           ) VALUES ($1,$2,$3,0,$4,$5,$6)`,
          [
            pedidoRow.sucursal_id,
            pedidoId,
            saldo,
            metodoEntrega,
            usuarioId,
            'Cobro contra entrega domicilio',
          ],
        );
        await this.cajaAuditoria.registrarVentaEnCaja(
          client,
          pedidoRow.sucursal_id,
          pedidoId,
          saldo,
          metodoEntrega,
          {
            exigirCaja: true,
            descripcion: `Domicilio entregado ${pedidoRow.numero_pedido}`,
          },
        );
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
      await client.query(`UPDATE pedidos SET estado = 'entregado' WHERE id = $1`, [
        pedidoId,
      ]);
      await client.query(
        `INSERT INTO estados_pedido_historial
           (pedido_id, estado_anterior, estado_nuevo, usuario_id)
         VALUES ($1, 'en_camino', 'entregado', $2)`,
        [pedidoId, usuarioId],
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
      };
    });

    void this.realtime.domiciliarioPlantaActualizado(usuarioId, {
      pedido_id: result.pedido_id,
      accion: 'entregado',
    });
    if (result.sucursal_id) {
      void this.realtime.pedidoActualizado({
        pedido_id: result.pedido_id,
        sucursal_id: result.sucursal_id,
        estado: result.estado,
      });
    }
    return { pedido_id: result.pedido_id, estado: result.estado };
  }

  private async obtenerPlantaPorUsuario(usuarioId: string) {
    return this.database.consultarUno<{ id: string; sucursal_id: string }>(
      `SELECT id, sucursal_id FROM domiciliarios_planta
       WHERE usuario_id = $1 AND activo = true
       LIMIT 1`,
      [usuarioId],
    );
  }

  private async consultarUno<T extends QueryResultRow>(
    client: PoolClient,
    sql: string,
    params: unknown[],
  ): Promise<T | null> {
    const r = await client.query<T>(sql, params);
    return r.rows[0] ?? null;
  }
}
