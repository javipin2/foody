import {
  BadRequestException,
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
import { AsignarDomiciliarioDto } from './dto/asignar-domiciliario.dto';
import { ConfirmarEntregaDto } from './dto/confirmar-entrega.dto';
import { UbicacionEntregaDto } from './dto/independiente.dto';
import { repartirCobroDomicilio } from './cobro-domicilio.util';
import { DispatchService } from './dispatch.service';

@Injectable()
export class DomiciliariosService {
  constructor(
    private readonly database: DatabaseService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly realtime: RealtimeBroadcastService,
    private readonly cajaAuditoria: PedidosCajaAuditoriaService,
    private readonly pedidosEstadoCommand: PedidosEstadoCommandService,
    private readonly pedidosSoporte: PedidosSoporteService,
    private readonly dispatch: DispatchService,
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
      const validacion = await this.dispatch.validarPedidoParaDespacho(
        dto.pedido_id,
        dto.sucursal_id,
        client,
      );
      if (!validacion.valido) {
        if (validacion.motivo === 'PEDIDO_NO_ENCONTRADO') {
          throw new NotFoundException(validacion.mensaje);
        }
        throw new BadRequestException({
          error: validacion.motivo,
          message: validacion.mensaje,
        });
      }
      const pedido = validacion.pedido;

      const domiciliario = await this.consultarUno<{
        id: string;
        sucursal_id: string;
        usuario_id: string;
      }>(
        client,
        `SELECT dp.id, dp.sucursal_id, dp.usuario_id FROM domiciliarios_planta dp
         WHERE dp.id = $1 AND dp.activo = true
         FOR UPDATE`,
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
           (pedido_id, sucursal_id, domiciliario_planta_id, tipo_domiciliario, estado, distancia_km)
         SELECT $1, $2, $3::uuid, 'planta', 'asignado',
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
         WHERE p.id = $1 AND p.sucursal_id = $2`,
        [dto.pedido_id, dto.sucursal_id, dto.domiciliario_planta_id],
      );

      await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
        pedidoId: dto.pedido_id,
        sucursalId: dto.sucursal_id,
        nuevoEstado: 'asignado',
        origen: 'domiciliario',
        usuarioId: usuarioAdminId,
        motivo: 'Domiciliario de planta asignado',
        estadoAnterior: 'listo',
        tipo: 'domicilio',
      });

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

  /** Cambia el domiciliario de un pedido ya asignado / en camino. */
  async reasignarPlanta(dto: AsignarDomiciliarioDto, usuarioAdminId: string) {
    const result = await this.database.enTransaccion(async (client) => {
      const pedido = await this.consultarUno<{
        id: string;
        tipo: string;
        estado: string;
      }>(
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
        throw new BadRequestException(
          'Solo pedidos de domicilio admiten reasignación',
        );
      }
      if (!['asignado', 'en_camino'].includes(pedido.estado)) {
        throw new BadRequestException(
          'Solo se puede cambiar domiciliario en asignado o en camino',
        );
      }

      const domiciliario = await this.consultarUno<{
        id: string;
        sucursal_id: string;
        usuario_id: string;
      }>(
        client,
        `SELECT dp.id, dp.sucursal_id, dp.usuario_id FROM domiciliarios_planta dp
         WHERE dp.id = $1 AND dp.activo = true
         FOR UPDATE`,
        [dto.domiciliario_planta_id],
      );
      if (!domiciliario || domiciliario.sucursal_id !== dto.sucursal_id) {
        throw new BadRequestException('Domiciliario no válido para esta sucursal');
      }

      const asignacionActiva = await this.consultarUno<{
        id: string;
        domiciliario_planta_id: string;
      }>(
        client,
        `SELECT id, domiciliario_planta_id::text AS domiciliario_planta_id
         FROM asignaciones_domicilio
         WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')
         ORDER BY asignado_at DESC
         LIMIT 1
         FOR UPDATE`,
        [dto.pedido_id],
      );
      if (!asignacionActiva) {
        throw new BadRequestException('El pedido no tiene domiciliario activo');
      }
      if (asignacionActiva.domiciliario_planta_id === dto.domiciliario_planta_id) {
        throw new BadRequestException('Ya está asignado a ese domiciliario');
      }

      const ocupado = await this.consultarUno<{ id: string }>(
        client,
        `SELECT ad.id FROM asignaciones_domicilio ad
         INNER JOIN pedidos p ON p.id = ad.pedido_id
         WHERE ad.domiciliario_planta_id = $1
           AND ad.estado IN ('asignado', 'en_camino')
           AND p.estado NOT IN ('cancelado', 'rechazado', 'entregado', 'pagado')
           AND ad.pedido_id <> $2
         LIMIT 1`,
        [dto.domiciliario_planta_id, dto.pedido_id],
      );
      if (ocupado) {
        throw new BadRequestException(
          'El domiciliario ya tiene un pedido activo',
        );
      }

      await client.query(
        `UPDATE asignaciones_domicilio
         SET estado = 'cancelado'
         WHERE id = $1`,
        [asignacionActiva.id],
      );

      await client.query(
        `INSERT INTO asignaciones_domicilio
           (pedido_id, sucursal_id, domiciliario_planta_id, tipo_domiciliario, estado, distancia_km)
         SELECT $1, $2, $3::uuid, 'planta', $4,
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
         WHERE p.id = $1 AND p.sucursal_id = $2`,
        [
          dto.pedido_id,
          dto.sucursal_id,
          dto.domiciliario_planta_id,
          pedido.estado === 'en_camino' ? 'en_camino' : 'asignado',
        ],
      );

      await client.query(
        `INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_despues
         ) VALUES ($1,$2,'REASIGNAR_DOMICILIARIO','asignaciones_domicilio',$3,$4::jsonb)`,
        [
          dto.sucursal_id,
          usuarioAdminId,
          dto.pedido_id,
          JSON.stringify({
            anterior: asignacionActiva.domiciliario_planta_id,
            nuevo: dto.domiciliario_planta_id,
            estado_pedido: pedido.estado,
          }),
        ],
      );

      return {
        pedido_id: dto.pedido_id,
        estado: pedido.estado,
        sucursal_id: dto.sucursal_id,
        domiciliario_usuario_id: domiciliario.usuario_id,
        anterior_planta_id: asignacionActiva.domiciliario_planta_id,
      };
    });

    void this.realtime.domiciliarioPlantaActualizado(
      result.domiciliario_usuario_id,
      {
        pedido_id: result.pedido_id,
        sucursal_id: result.sucursal_id,
        accion: 'reasignado',
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
      reasignado: true,
    };
  }

  async historialEntregas(
    usuarioId: string,
    opts?: { desde?: string; hasta?: string; limite?: number },
  ) {
    const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
    if (!domiciliario) {
      throw new NotFoundException('No eres domiciliario de planta registrado');
    }

    const limite = opts?.limite ?? 50;
    const params: unknown[] = [domiciliario.id];
    let filtroFecha = '';
    if (opts?.desde) {
      params.push(opts.desde);
      filtroFecha += ` AND ad.entregado_at >= $${params.length}::timestamptz`;
    }
    if (opts?.hasta) {
      params.push(opts.hasta);
      filtroFecha += ` AND ad.entregado_at < ($${params.length}::date + interval '1 day')`;
    }
    params.push(limite);

    return this.database.consultar(
      `SELECT p.id,
              p.numero_pedido,
              p.cliente_nombre,
              p.cliente_telefono,
              p.direccion_entrega,
              p.subtotal,
              p.costo_domicilio,
              p.total,
              p.metodo_pago,
              COALESCE(pagos.resumen, '[]'::jsonb) AS pagos_resumen,
              p.estado,
              ad.entregado_at,
              ad.asignado_at
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id AND p.sucursal_id = ad.sucursal_id
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
       WHERE ad.domiciliario_planta_id = $1
         AND ad.estado = 'entregado'${filtroFecha}
       ORDER BY ad.entregado_at DESC NULLS LAST
       LIMIT $${params.length}`,
      params,
    );
  }

  async estadisticasPlanta(
    usuarioId: string,
    opts?: { desde?: string; hasta?: string },
  ) {
    const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
    if (!domiciliario) {
      throw new NotFoundException('No eres domiciliario de planta registrado');
    }

    const params: unknown[] = [domiciliario.id];
    let filtroRango = '';
    if (opts?.desde) {
      params.push(opts.desde);
      filtroRango += ` AND ad.entregado_at >= $${params.length}::timestamptz`;
    }
    if (opts?.hasta) {
      params.push(opts.hasta);
      filtroRango += ` AND ad.entregado_at < ($${params.length}::date + interval '1 day')`;
    }

    const fila = await this.database.consultarUno<{
      hoy: string;
      semana: string;
      mes: string;
      rango: string;
      cobrado_rango: string;
      promedio_min: string | null;
      saldo_liquidar: string;
    }>(
      `SELECT
         COUNT(*) FILTER (WHERE ad.entregado_at >= date_trunc('day', now()))::text AS hoy,
         COUNT(*) FILTER (WHERE ad.entregado_at >= date_trunc('week', now()))::text AS semana,
         COUNT(*) FILTER (WHERE ad.entregado_at >= date_trunc('month', now()))::text AS mes,
         COUNT(*)::text AS rango,
         COALESCE(SUM(p.total), 0)::text AS cobrado_rango,
         AVG(
           EXTRACT(EPOCH FROM (ad.entregado_at - ad.asignado_at)) / 60
         ) FILTER (WHERE ad.entregado_at IS NOT NULL)::text AS promedio_min,
         (
           SELECT COALESCE(SUM(cxc.monto), 0)::text
           FROM cuentas_por_cobrar cxc
           WHERE cxc.domiciliario_planta_id = $1
             AND cxc.estado = 'pendiente'
         ) AS saldo_liquidar
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id
       WHERE ad.domiciliario_planta_id = $1
         AND ad.estado = 'entregado'${filtroRango}`,
      params,
    );

    return {
      entregas_hoy: Number(fila?.hoy ?? 0),
      entregas_semana: Number(fila?.semana ?? 0),
      entregas_mes: Number(fila?.mes ?? 0),
      entregas_rango: Number(fila?.rango ?? 0),
      total_cobrado_rango: Number(fila?.cobrado_rango ?? 0),
      tiempo_promedio_min: fila?.promedio_min != null
        ? Math.round(Number(fila.promedio_min))
        : null,
      // NAV-DP-07: deuda fiado propia (UI planta solo informa).
      saldo_por_liquidar: Number(fila?.saldo_liquidar ?? 0),
    };
  }

  async pedidosAsignados(usuarioId: string) {
    const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
    if (!domiciliario) {
      throw new NotFoundException('No eres domiciliario de planta registrado');
    }

    const pedidos = await this.database.consultar<{
      id: string;
      numero_pedido: string;
      tipo: string;
      estado: string;
      cliente_nombre: string | null;
      cliente_telefono: string | null;
      direccion_entrega: string | null;
      lat: string | null;
      lng: string | null;
      subtotal: string;
      costo_domicilio: string;
      total: string;
      monto_pagado: string;
      metodo_pago: string | null;
      pagos_resumen: Array<{ metodo_pago: string; monto: string | number }>;
      created_at: string;
      estado_asignacion: string;
      asignado_at: string;
      permite_fiado_domiciliario: boolean;
      domicilio_ingresa_a_caja: boolean;
    }>(
      `SELECT p.id,
              p.numero_pedido,
              p.tipo,
              p.estado,
              p.cliente_nombre,
              p.cliente_telefono,
              p.direccion_entrega,
              p.lat,
              p.lng,
              p.subtotal,
              p.costo_domicilio,
              p.total,
              COALESCE(p.monto_pagado, 0) AS monto_pagado,
              p.metodo_pago,
              COALESCE(pagos.resumen, '[]'::jsonb) AS pagos_resumen,
              p.created_at,
              ad.estado AS estado_asignacion,
              ad.asignado_at,
              COALESCE(s.permite_fiado_domiciliario, false) AS permite_fiado_domiciliario,
              COALESCE(s.domicilio_ingresa_a_caja, false) AS domicilio_ingresa_a_caja
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id AND p.sucursal_id = ad.sucursal_id
       JOIN sucursales s ON s.id = p.sucursal_id
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
       WHERE ad.domiciliario_planta_id = $1
         AND ad.estado IN ('asignado', 'en_camino')
         AND p.estado IN ('asignado', 'en_camino')
       ORDER BY ad.asignado_at ASC`,
      [domiciliario.id],
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

  /** Cuentas de domicilios entregados a cuenta del domiciliario, por liquidar. */
  async resumenLiquidacion(sucursalId: string) {
    const sucursal = await this.database.consultarUno<{
      permite_fiado_domiciliario: boolean;
    }>(
      `SELECT COALESCE(permite_fiado_domiciliario, false) AS permite_fiado_domiciliario
       FROM sucursales WHERE id = $1`,
      [sucursalId],
    );
    const filas = await this.database.consultar<{
      domiciliario_planta_id: string;
      nombre: string;
      pedidos: string;
      total_pendiente: string;
    }>(
      `SELECT cxc.domiciliario_planta_id,
              u.nombre,
              COUNT(*)::text AS pedidos,
              COALESCE(SUM(cxc.monto), 0)::text AS total_pendiente
       FROM cuentas_por_cobrar cxc
       JOIN domiciliarios_planta dp ON dp.id = cxc.domiciliario_planta_id
       JOIN usuarios u ON u.id = dp.usuario_id
       WHERE cxc.sucursal_id = $1
         AND cxc.estado = 'pendiente'
         AND cxc.domiciliario_planta_id IS NOT NULL
       GROUP BY cxc.domiciliario_planta_id, u.nombre
       ORDER BY total_pendiente DESC`,
      [sucursalId],
    );
    return {
      permite_fiado_domiciliario: sucursal?.permite_fiado_domiciliario ?? false,
      domiciliarios: filas.map((f) => ({
        domiciliario_planta_id: f.domiciliario_planta_id,
        nombre: f.nombre,
        pedidos: Number(f.pedidos),
        total_pendiente: Number(f.total_pendiente),
      })),
    };
  }

  /**
   * Registro de domicilios por domiciliario de planta: cuántos pedidos entregó
   * y cuánto acumula en domicilios (aunque no entren a caja). Rango opcional.
   */
  async resumenDomicilios(sucursalId: string, desde?: string, hasta?: string) {
    const sucursal = await this.database.consultarUno<{
      domicilio_ingresa_a_caja: boolean;
    }>(
      `SELECT COALESCE(domicilio_ingresa_a_caja, false) AS domicilio_ingresa_a_caja
       FROM sucursales WHERE id = $1`,
      [sucursalId],
    );
    const filas = await this.database.consultar<{
      domiciliario_planta_id: string;
      nombre: string;
      pedidos_entregados: string;
      total_domicilios: string;
    }>(
      `SELECT ad.domiciliario_planta_id,
              u.nombre,
              COUNT(*)::text AS pedidos_entregados,
              COALESCE(SUM(p.costo_domicilio), 0)::text AS total_domicilios
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id
       JOIN domiciliarios_planta dp ON dp.id = ad.domiciliario_planta_id
       JOIN usuarios u ON u.id = dp.usuario_id
       WHERE ad.sucursal_id = $1
         AND ad.estado = 'entregado'
         AND ad.domiciliario_planta_id IS NOT NULL
         AND ($2::timestamptz IS NULL OR ad.entregado_at >= $2::timestamptz)
         AND ($3::timestamptz IS NULL OR ad.entregado_at <= $3::timestamptz)
       GROUP BY ad.domiciliario_planta_id, u.nombre
       ORDER BY total_domicilios DESC`,
      [sucursalId, desde ?? null, hasta ?? null],
    );
    return {
      domicilio_ingresa_a_caja: sucursal?.domicilio_ingresa_a_caja ?? false,
      domiciliarios: filas.map((f) => ({
        domiciliario_planta_id: f.domiciliario_planta_id,
        nombre: f.nombre,
        pedidos_entregados: Number(f.pedidos_entregados),
        total_domicilios: Number(f.total_domicilios),
      })),
    };
  }

  /** Liquida (cobra en caja, efectivo) todos los domicilios a cuenta del domi. */
  async liquidarDomiciliario(
    sucursalId: string,
    domiciliarioPlantaId: string,
    usuarioId: string,
  ) {
    return this.database.enTransaccion(async (client) => {
      const cuentas = await client.query<{
        id: string;
        pedido_id: string | null;
        monto: string;
      }>(
        `SELECT id, pedido_id, monto FROM cuentas_por_cobrar
         WHERE sucursal_id = $1
           AND domiciliario_planta_id = $2
           AND estado = 'pendiente'
         FOR UPDATE`,
        [sucursalId, domiciliarioPlantaId],
      );
      if (cuentas.rows.length === 0) {
        throw new BadRequestException({
          error: 'SIN_CUENTAS_PENDIENTES',
          message: 'Este domiciliario no tiene domicilios por liquidar',
        });
      }

      let total = 0;
      for (const cuenta of cuentas.rows) {
        const monto = Number(cuenta.monto);
        total += monto;

        await client.query(
          `UPDATE cuentas_por_cobrar
           SET estado = 'pagada', pagada_at = now()
           WHERE id = $1`,
          [cuenta.id],
        );

        if (cuenta.pedido_id) {
          await client.query(
            `INSERT INTO pagos_pedido (
               sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
             ) VALUES ($1,$2,$3,0,'efectivo',$4,$5)`,
            [
              sucursalId,
              cuenta.pedido_id,
              monto,
              usuarioId,
              'Liquidación domiciliario',
            ],
          );
          await this.cajaAuditoria.registrarVentaEnCaja(
            client,
            sucursalId,
            cuenta.pedido_id,
            monto,
            'efectivo',
            {
              exigirCaja: true,
              descripcion: 'Liquidación domicilio a cuenta',
              usuarioId,
            },
          );
          await client.query(
            `UPDATE pedidos
             SET monto_pagado = pedidos.total,
                 metodo_pago = COALESCE(
                   (
                     SELECT pp.metodo_pago
                     FROM pagos_pedido pp
                     WHERE pp.pedido_id = pedidos.id
                       AND pp.sucursal_id = pedidos.sucursal_id
                     ORDER BY pp.created_at ASC, pp.id ASC
                     LIMIT 1
                   ),
                   'efectivo'
                 )
             WHERE pedidos.id = $1 AND pedidos.sucursal_id = $2`,
            [cuenta.pedido_id, sucursalId],
          );
        }
      }

      await client.query(
        `INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_despues
         ) VALUES ($1,$2,'LIQUIDAR_DOMICILIARIO','cuentas_por_cobrar',$3,$4::jsonb)`,
        [
          sucursalId,
          usuarioId,
          domiciliarioPlantaId,
          JSON.stringify({ liquidados: cuentas.rows.length, total }),
        ],
      );

      return {
        domiciliario_planta_id: domiciliarioPlantaId,
        liquidados: cuentas.rows.length,
        total,
      };
    });
  }

  /** Activa/desactiva el fiado a domiciliarios en la sucursal. */
  async configurarFiadoDomiciliario(sucursalId: string, permitir: boolean) {
    await this.database.consultar(
      `UPDATE sucursales SET permite_fiado_domiciliario = $2 WHERE id = $1`,
      [sucursalId, permitir],
    );
    return { sucursal_id: sucursalId, permite_fiado_domiciliario: permitir };
  }

  /**
   * Define si el costo del domicilio entra a caja (true) o queda como ingreso
   * fuera de caja rastreado por domiciliario (false, por defecto).
   */
  async configurarDomicilioEnCaja(sucursalId: string, ingresa: boolean) {
    await this.database.consultar(
      `UPDATE sucursales SET domicilio_ingresa_a_caja = $2 WHERE id = $1`,
      [sucursalId, ingresa],
    );
    return { sucursal_id: sucursalId, domicilio_ingresa_a_caja: ingresa };
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

      const pedido = await this.consultarUno<{ sucursal_id: string }>(
        client,
        `SELECT sucursal_id FROM pedidos WHERE id = $1`,
        [pedidoId],
      );
      if (!pedido) throw new NotFoundException('Pedido no encontrado');

      await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
        pedidoId,
        sucursalId: pedido.sucursal_id,
        nuevoEstado: 'en_camino',
        origen: 'domiciliario',
        usuarioId,
        estadoAnterior: 'asignado',
        tipo: 'domicilio',
      });

      return {
        pedido_id: pedidoId,
        estado: 'en_camino',
        sucursal_id: pedido.sucursal_id,
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

  /** GPS durante entrega — historial + broadcast al cliente (seguimiento). */
  async registrarUbicacionEntrega(
    usuarioId: string,
    dto: UbicacionEntregaDto,
  ) {
    const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
    if (!domiciliario) {
      throw new NotFoundException('No eres domiciliario de planta registrado');
    }

    const params: unknown[] = [domiciliario.id];
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
       WHERE ad.domiciliario_planta_id = $1
         AND ad.estado = 'en_camino'${filtroPedido}
       ORDER BY ad.asignado_at DESC
       LIMIT 1`,
      params,
    );

    if (!asignacion) {
      return { ok: true, registrado: false };
    }

    await this.database.consultar(
      `INSERT INTO domiciliarios_ubicaciones_historial (asignacion_id, lat, lng)
       VALUES ($1, $2, $3)`,
      [asignacion.id, dto.lat, dto.lng],
    );

    this.pedidosSoporte.emitirUbicacionRepartidor(asignacion.pedido_id, {
      repartidor_lat: dto.lat,
      repartidor_lng: dto.lng,
    });

    return { ok: true, registrado: true, pedido_id: asignacion.pedido_id };
  }

  /**
   * Registra el cobro contra entrega separando producto y domicilio.
   * El producto siempre entra a caja; el domicilio solo entra a caja si la
   * sucursal lo cobra para sí (`domicilio_ingresa_a_caja`). En ambos casos se
   * deja huella en `pagos_pedido` para reconciliar lo que pagó el cliente.
   */
  private async registrarCobroEntrega(
    client: PoolClient,
    p: {
      sucursalId: string;
      pedidoId: string;
      numeroPedido: string;
      usuarioId: string | null;
      productoPendiente: number;
      domicilioPendiente: number;
      metodoProducto: string;
      metodoDomicilio: string;
      domicilioEnCaja: boolean;
    },
  ): Promise<void> {
    if (p.productoPendiente > 0.01) {
      await client.query(
        `INSERT INTO pagos_pedido (
           sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
         ) VALUES ($1,$2,$3,0,$4,$5,$6)`,
        [
          p.sucursalId,
          p.pedidoId,
          p.productoPendiente,
          p.metodoProducto,
          p.usuarioId,
          'Cobro producto contra entrega',
        ],
      );
      await this.cajaAuditoria.registrarVentaEnCaja(
        client,
        p.sucursalId,
        p.pedidoId,
        p.productoPendiente,
        p.metodoProducto,
        {
          exigirCaja: true,
          descripcion: `Domicilio entregado ${p.numeroPedido}`,
          usuarioId: p.usuarioId ?? undefined,
        },
      );
    }

    if (p.domicilioPendiente > 0.01) {
      await client.query(
        `INSERT INTO pagos_pedido (
           sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
         ) VALUES ($1,$2,$3,0,$4,$5,$6)`,
        [
          p.sucursalId,
          p.pedidoId,
          p.domicilioPendiente,
          p.metodoDomicilio,
          p.usuarioId,
          p.domicilioEnCaja
            ? 'Cobro domicilio contra entrega'
            : 'Domicilio (fuera de caja)',
        ],
      );
      if (p.domicilioEnCaja) {
        await this.cajaAuditoria.registrarVentaEnCaja(
          client,
          p.sucursalId,
          p.pedidoId,
          p.domicilioPendiente,
          p.metodoDomicilio,
          {
            exigirCaja: true,
            descripcion: `Domicilio (cobro) ${p.numeroPedido}`,
            usuarioId: p.usuarioId ?? undefined,
          },
        );
      }
    }
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

      const sucursalCfg = await this.consultarUno<{
        permite_fiado_domiciliario: boolean;
        domicilio_ingresa_a_caja: boolean;
      }>(
        client,
        `SELECT COALESCE(permite_fiado_domiciliario, false) AS permite_fiado_domiciliario,
                COALESCE(domicilio_ingresa_a_caja, false) AS domicilio_ingresa_a_caja
         FROM sucursales WHERE id = $1`,
        [pedidoRow.sucursal_id],
      );
      const domicilioEnCaja = sucursalCfg?.domicilio_ingresa_a_caja ?? false;

      const { saldo, productoPendiente, domicilioPendiente } =
        repartirCobroDomicilio(
          Number(pedidoRow.total),
          Number(pedidoRow.costo_domicilio),
          Number(pedidoRow.monto_pagado ?? 0),
        );
      const metodoEntrega = dto.metodo_pago?.trim();
      const metodoDomicilio =
        dto.metodo_pago_domicilio?.trim() || metodoEntrega;

      if (saldo > 0.01 && metodoEntrega === 'pendiente_liquidacion') {
        if (!sucursalCfg?.permite_fiado_domiciliario) {
          throw new BadRequestException({
            error: 'FIADO_DOMICILIARIO_NO_PERMITIDO',
            message:
              'Esta sucursal no permite dejar domicilios a cuenta del domiciliario. Cobra al entregar.',
          });
        }
        const domiUsuario = await this.consultarUno<{ nombre: string }>(
          client,
          `SELECT u.nombre FROM domiciliarios_planta dp
           JOIN usuarios u ON u.id = dp.usuario_id
           WHERE dp.id = $1`,
          [domiciliario.id],
        );
        // El domiciliario solo debe a caja el producto; el domicilio es ingreso
        // fuera de caja (salvo que la sucursal lo cobre para sí).
        const montoCxc = domicilioEnCaja ? saldo : productoPendiente;
        if (montoCxc > 0.01) {
          await client.query(
            `INSERT INTO cuentas_por_cobrar (
               sucursal_id, pedido_id, domiciliario_planta_id,
               cliente_nombre, cliente_telefono, monto, usuario_id
             ) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
            [
              pedidoRow.sucursal_id,
              pedidoId,
              domiciliario.id,
              `Domiciliario: ${domiUsuario?.nombre ?? 'planta'}`,
              null,
              montoCxc,
              usuarioId,
            ],
          );
        }
        // El pedido queda entregado pero sin cobrar; la caja recibe el dinero al liquidar.
      } else if (saldo > 0.01) {
        if (!metodoEntrega || metodoEntrega === 'pendiente') {
          throw new BadRequestException({
            error: 'COBRO_REQUERIDO',
            message:
              'Indica método de pago al entregar (efectivo, tarjeta, transferencia o nequi)',
          });
        }
        await this.registrarCobroEntrega(client, {
          sucursalId: pedidoRow.sucursal_id,
          pedidoId,
          numeroPedido: pedidoRow.numero_pedido,
          usuarioId,
          productoPendiente,
          domicilioPendiente,
          metodoProducto: metodoEntrega,
          metodoDomicilio: metodoDomicilio ?? metodoEntrega,
          domicilioEnCaja,
        });
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
      await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
        pedidoId,
        sucursalId: pedidoRow.sucursal_id,
        nuevoEstado: 'entregado',
        origen: 'domiciliario',
        usuarioId,
        motivo: 'Entrega confirmada por domiciliario de planta',
        estadoAnterior: 'en_camino',
        tipo: 'domicilio',
      });

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

  /** DOM-009: resumen comisiones independientes por sucursal (admin). */
  async resumenComisionesIndependientes(sucursalId: string) {
    return this.database.consultar(
      `SELECT di.id,
              di.nombre,
              COUNT(gd.id)::int AS entregas,
              COALESCE(SUM(gd.valor_domicilio), 0) AS total_domicilios,
              COALESCE(SUM(gd.comision_foody), 0) AS comision_foody,
              COALESCE(SUM(gd.ganancia_domiciliario), 0) AS ganancia_total,
              COALESCE(
                SUM(gd.ganancia_domiciliario) FILTER (
                  WHERE gd.pagado = false
                    AND ad.estado IS DISTINCT FROM 'cancelado'
                ),
                0
              ) AS por_pagar
       FROM ganancias_domiciliario gd
       JOIN asignaciones_domicilio ad ON ad.id = gd.asignacion_id
       JOIN domiciliarios_independientes di ON di.id = gd.domiciliario_id
       WHERE ad.sucursal_id = $1
       GROUP BY di.id, di.nombre
       ORDER BY por_pagar DESC, ganancia_total DESC`,
      [sucursalId],
    );
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
