import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient, QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { SQL_WHERE_PEDIDO_BLOQUEA_MESA } from './pedido-estados';

/** Subdominio: pedidos activos por mesa y liberación de mesa. */
@Injectable()
export class PedidosCuentaMesaService {
  constructor(private readonly database: DatabaseService) {}

  async listarActivosPorMesa(sucursalId: string, mesaId: string) {
    const mesa = await this.database.consultarUno<{ id: string; nombre: string }>(
      `SELECT id, nombre FROM mesas
       WHERE id = $1 AND sucursal_id = $2 AND activa = true`,
      [mesaId, sucursalId],
    );
    if (!mesa) {
      throw new NotFoundException('Mesa no encontrada');
    }

    const pedidos = await this.database.consultar<{
      id: string;
      numero_pedido: string;
      tipo: string;
      estado: string;
      total: string;
      monto_pagado: string;
      created_at: Date;
      items: unknown;
    }>(
      `SELECT p.id, p.numero_pedido, p.tipo, p.estado, p.total,
              COALESCE(p.monto_pagado, 0) AS monto_pagado,
              p.created_at,
              COALESCE(
                json_agg(
                  json_build_object(
                    'id', pi.id,
                    'producto', pr.nombre,
                    'cantidad', pi.cantidad,
                    'precio_unitario', pi.precio_unitario,
                    'subtotal_linea', pi.cantidad * pi.precio_unitario,
                    'estado_cocina', pi.estado_cocina,
                    'estado_cobro', COALESCE(pi.estado_cobro, 'pendiente'),
                    'comensal_etiqueta', pi.comensal_etiqueta,
                    'cocina_nombre', c.nombre,
                    'observaciones', pi.observaciones
                  ) ORDER BY pi.created_at
                ) FILTER (WHERE pi.id IS NOT NULL),
                '[]'::json
              ) AS items
       FROM pedidos p
       LEFT JOIN pedido_items pi ON pi.pedido_id = p.id
       LEFT JOIN productos pr ON pr.id = pi.producto_id
       LEFT JOIN cocinas c ON c.id = pi.cocina_id
       WHERE p.sucursal_id = $1
         AND p.mesa_id = $2
         AND (${SQL_WHERE_PEDIDO_BLOQUEA_MESA})
       GROUP BY p.id
       ORDER BY p.created_at ASC`,
      [sucursalId, mesaId],
    );

    const totalAcumulado = pedidos.reduce((sum, p) => {
      const saldo = Number(p.total) - Number(p.monto_pagado ?? 0);
      return sum + Math.max(0, saldo);
    }, 0);

    const pagosAbonos = await this.database.consultar<{
      id: string;
      monto: string;
      propina: string;
      metodo_pago: string;
      created_at: Date;
      referencia: string | null;
    }>(
      `SELECT id, monto, propina, metodo_pago, created_at, referencia
       FROM pagos_pedido
       WHERE mesa_id = $1 AND sucursal_id = $2
       ORDER BY created_at DESC
       LIMIT 30`,
      [mesaId, sucursalId],
    );

    return {
      mesa_id: mesa.id,
      mesa_nombre: mesa.nombre,
      total_acumulado: totalAcumulado,
      pagos_abonos: pagosAbonos.map((p) => ({
        id: p.id,
        monto: Number(p.monto),
        propina: Number(p.propina),
        metodo_pago: p.metodo_pago,
        created_at: p.created_at,
        referencia: p.referencia,
      })),
      pedidos: pedidos.map((p) => {
        const montoPagado = Number(p.monto_pagado ?? 0);
        const total = Number(p.total);
        return {
          id: p.id,
          numero_pedido: p.numero_pedido,
          tipo: p.tipo,
          estado: p.estado,
          total,
          monto_pagado: montoPagado,
          saldo_pendiente: Math.max(0, total - montoPagado),
          created_at: p.created_at,
          items: Array.isArray(p.items) ? p.items : [],
        };
      }),
    };
  }

  async marcarEstadoOperativoMesa(
    client: PoolClient,
    mesaId: string,
    sucursalId: string,
    estado: 'ocupada' | 'pagando' | 'libre',
  ) {
    await client.query(
      `UPDATE mesas SET estado_operativo = $3
       WHERE id = $1 AND sucursal_id = $2`,
      [mesaId, sucursalId, estado],
    );
  }

  async liberarMesaSiSinPedidosActivos(
    client: PoolClient,
    mesaId: string,
    sucursalId: string,
  ) {
    const activo = await this.consultarUnoCliente<{ n: number }>(
      client,
      `SELECT COUNT(*)::int AS n FROM pedidos
       WHERE mesa_id = $1 AND sucursal_id = $2
         AND (${SQL_WHERE_PEDIDO_BLOQUEA_MESA})`,
      [mesaId, sucursalId],
    );
    if ((activo?.n ?? 0) === 0) {
      await client.query(
        `UPDATE mesas
         SET mesera_asignada_id = NULL, mesera_asignada_at = NULL,
             estado_operativo = 'libre', mesa_grupo_id = NULL
         WHERE id = $1 AND sucursal_id = $2`,
        [mesaId, sucursalId],
      );
    }
  }

  private async consultarUnoCliente<T extends QueryResultRow>(
    client: PoolClient,
    sql: string,
    parametros: unknown[],
  ): Promise<T | null> {
    const res = await client.query<T>(sql, parametros);
    return res.rows[0] ?? null;
  }
}
