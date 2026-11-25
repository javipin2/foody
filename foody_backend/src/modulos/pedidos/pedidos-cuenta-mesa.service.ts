import { Injectable, NotFoundException } from '@nestjs/common';
import { PoolClient, QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { SQL_WHERE_PEDIDO_BLOQUEA_MESA } from './pedido-estados';
import { SQL_VENTA_LINEA_ITEM } from './sql-venta-linea-item';

/** Subdominio: pedidos activos por mesa y liberación de mesa. */
@Injectable()
export class PedidosCuentaMesaService {
  constructor(private readonly database: DatabaseService) {}

  async listarActivosPorMesa(sucursalId: string, mesaId: string) {
    const mesa = await this.database.consultarUno<{
      id: string;
      nombre: string;
      mesa_grupo_id: string | null;
    }>(
      `SELECT id, nombre, mesa_grupo_id FROM mesas
       WHERE id = $1 AND sucursal_id = $2 AND activa = true`,
      [mesaId, sucursalId],
    );
    if (!mesa) {
      throw new NotFoundException('Mesa no encontrada');
    }

    const grupoId = mesa.mesa_grupo_id ?? mesa.id;
    const mesasGrupo = await this.database.consultar<{
      id: string;
      nombre: string;
    }>(
      `SELECT id, nombre FROM mesas
       WHERE sucursal_id = $1 AND activa = true
         AND (id = $2 OR mesa_grupo_id = $2)
       ORDER BY nombre ASC`,
      [sucursalId, grupoId],
    );

    const pedidos = await this.database.consultar<{
      id: string;
      numero_pedido: string;
      tipo: string;
      estado: string;
      total: string;
      monto_pagado: string;
      created_at: Date;
      cliente_nombre: string | null;
      observaciones: string | null;
      mesera_id: string | null;
      mesera_nombre: string | null;
      items: unknown;
    }>(
      `SELECT p.id, p.numero_pedido, p.tipo, p.estado, p.total,
              COALESCE(p.monto_pagado, 0) AS monto_pagado,
              p.created_at, p.cliente_nombre, p.observaciones,
              p.mesera_id, u_m.nombre AS mesera_nombre,
              COALESCE(
                json_agg(
                  json_build_object(
                    'id', pi.id,
                    'producto', pr.nombre,
                    'cantidad', pi.cantidad,
                    'precio_unitario', pi.precio_unitario,
                    'subtotal_linea', ${SQL_VENTA_LINEA_ITEM},
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
       LEFT JOIN usuarios u_m ON u_m.id = p.mesera_id
       LEFT JOIN pedido_items pi ON pi.pedido_id = p.id
       LEFT JOIN productos pr ON pr.id = pi.producto_id
       LEFT JOIN cocinas c ON c.id = pi.cocina_id
       WHERE p.sucursal_id = $1
         AND p.mesa_id = ANY($2::uuid[])
         AND (${SQL_WHERE_PEDIDO_BLOQUEA_MESA})
       GROUP BY p.id, u_m.nombre
       ORDER BY p.created_at ASC`,
      [sucursalId, mesasGrupo.map((m) => m.id)],
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
      numero_pedido: string | null;
      created_at: Date;
      referencia: string | null;
      responsable_nombre: string | null;
    }>(
      `SELECT pp.id, pp.monto, pp.propina, pp.metodo_pago, pp.created_at, pp.referencia,
              p.numero_pedido,
              u.nombre AS responsable_nombre
       FROM pagos_pedido pp
       LEFT JOIN pedidos p ON p.id = pp.pedido_id AND p.sucursal_id = pp.sucursal_id
       LEFT JOIN usuarios u ON u.id = pp.usuario_id
       WHERE pp.mesa_id = ANY($1::uuid[]) AND pp.sucursal_id = $2
       ORDER BY pp.created_at DESC
       LIMIT 30`,
      [mesasGrupo.map((m) => m.id), sucursalId],
    );

    return {
      mesa_id: mesa.id,
      mesa_nombre: mesa.nombre,
      total_acumulado: totalAcumulado,
      cuenta: {
        modo: 'unificada',
        cantidad_tickets: pedidos.length,
        mesa_grupo:
          mesasGrupo.length > 1
            ? {
                mesas: mesasGrupo.map((m) => ({
                  id: m.id,
                  nombre: m.nombre,
                  es_actual: m.id === mesa.id,
                })),
              }
            : null,
      },
      pagos_abonos: pagosAbonos.map((p) => ({
        id: p.id,
        monto: Number(p.monto),
        propina: Number(p.propina),
        metodo_pago: p.metodo_pago,
        numero_pedido: p.numero_pedido,
        created_at: p.created_at,
        referencia: p.referencia,
        responsable_nombre: p.responsable_nombre,
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
          cliente_nombre: p.cliente_nombre,
          mesera_nombre: p.mesera_nombre,
          observaciones: p.observaciones,
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
    const mesa = await this.consultarUnoCliente<{
      mesa_grupo_id: string | null;
    }>(
      client,
      `SELECT mesa_grupo_id FROM mesas WHERE id = $1 AND sucursal_id = $2`,
      [mesaId, sucursalId],
    );
    if (!mesa) return;
    const raizId = mesa.mesa_grupo_id ?? mesaId;
    const grupo = await client.query<{ id: string }>(
      `SELECT id FROM mesas
       WHERE sucursal_id = $1 AND (id = $2 OR mesa_grupo_id = $2)
       ORDER BY id FOR UPDATE`,
      [sucursalId, raizId],
    );
    const mesaIds = grupo.rows.map((fila) => fila.id);
    if (!mesaIds.length) return;

    const activo = await this.consultarUnoCliente<{ n: number }>(
      client,
      `SELECT COUNT(*)::int AS n FROM pedidos
       WHERE mesa_id = ANY($1::uuid[]) AND sucursal_id = $2
         AND (${SQL_WHERE_PEDIDO_BLOQUEA_MESA})`,
      [mesaIds, sucursalId],
    );
    if ((activo?.n ?? 0) === 0) {
      await client.query(
        `UPDATE mesas
         SET mesera_asignada_id = NULL, mesera_asignada_at = NULL,
             estado_operativo = 'libre', mesa_grupo_id = NULL
         WHERE id = ANY($1::uuid[]) AND sucursal_id = $2
           AND estado_operativo IN ('ocupada', 'pagando')`,
        [mesaIds, sucursalId],
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
