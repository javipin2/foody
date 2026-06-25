import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';

export interface RangoFechas {
  desde: string;
  hasta: string;
}

@Injectable()
export class ReportesService {
  constructor(private readonly database: DatabaseService) {}

  async financiero(sucursalId: string, rango: RangoFechas) {
    const resumen = await this.database.consultarUno<{
      ventas_total: string;
      subtotal: string;
      costo_domicilio: string;
      descuentos: string;
      pedidos: string;
      ticket_promedio: string;
    }>(
      `SELECT COALESCE(SUM(total), 0)::text AS ventas_total,
              COALESCE(SUM(subtotal), 0)::text AS subtotal,
              COALESCE(SUM(costo_domicilio), 0)::text AS costo_domicilio,
              COALESCE(SUM(descuento), 0)::text AS descuentos,
              COUNT(*)::text AS pedidos,
              COALESCE(AVG(total), 0)::text AS ticket_promedio
       FROM pedidos
       WHERE sucursal_id = $1
         AND created_at >= $2::timestamptz
         AND created_at < ($3::date + interval '1 day')
         AND estado NOT IN ('cancelado', 'rechazado')`,
      [sucursalId, rango.desde, rango.hasta],
    );

    const filtroFechaCaja = `COALESCE(p.created_at, m.created_at)`;

    const caja = await this.database.consultarUno<{
      ventas_caja: string;
      movimientos: string;
    }>(
      `SELECT COALESCE(SUM(m.monto), 0)::text AS ventas_caja,
              COUNT(*)::text AS movimientos
       FROM movimientos_caja m
       LEFT JOIN pedidos p ON p.id = m.pedido_id
       WHERE m.sucursal_id = $1
         AND m.tipo = 'venta'
         AND ${filtroFechaCaja} >= $2::timestamptz
         AND ${filtroFechaCaja} < ($3::date + interval '1 day')`,
      [sucursalId, rango.desde, rango.hasta],
    );

    const ventasPedidos = Number(resumen?.ventas_total ?? 0);
    const ventasCaja = Number(caja?.ventas_caja ?? 0);

    const porMetodoCaja = await this.database.consultar<{
      metodo_pago: string;
      total: string;
    }>(
      `SELECT COALESCE(m.metodo_pago, 'sin_metodo') AS metodo_pago,
              COALESCE(SUM(m.monto), 0)::text AS total
       FROM movimientos_caja m
       LEFT JOIN pedidos p ON p.id = m.pedido_id
       WHERE m.sucursal_id = $1
         AND m.tipo = 'venta'
         AND COALESCE(p.created_at, m.created_at) >= $2::timestamptz
         AND COALESCE(p.created_at, m.created_at) < ($3::date + interval '1 day')
       GROUP BY m.metodo_pago
       ORDER BY total DESC`,
      [sucursalId, rango.desde, rango.hasta],
    );

    const porTipo = await this.database.consultar<{
      tipo: string;
      pedidos: string;
      ventas: string;
    }>(
      `SELECT tipo,
              COUNT(*)::text AS pedidos,
              COALESCE(SUM(total), 0)::text AS ventas
       FROM pedidos
       WHERE sucursal_id = $1
         AND created_at >= $2::timestamptz
         AND created_at < ($3::date + interval '1 day')
         AND estado NOT IN ('cancelado', 'rechazado')
       GROUP BY tipo
       ORDER BY ventas DESC`,
      [sucursalId, rango.desde, rango.hasta],
    );

    return {
      periodo: rango,
      resumen: {
        ventas_total: ventasPedidos,
        subtotal: Number(resumen?.subtotal ?? 0),
        costo_domicilio: Number(resumen?.costo_domicilio ?? 0),
        descuentos: Number(resumen?.descuentos ?? 0),
        pedidos: Number(resumen?.pedidos ?? 0),
        ticket_promedio: Number(resumen?.ticket_promedio ?? 0),
      },
      cuadre_caja: {
        ventas_pedidos: ventasPedidos,
        ventas_movimientos_caja: ventasCaja,
        diferencia: Math.round((ventasPedidos - ventasCaja) * 100) / 100,
        movimientos_venta: Number(caja?.movimientos ?? 0),
        por_metodo_caja: porMetodoCaja.map((f) => ({
          metodo_pago: f.metodo_pago,
          total: Number(f.total),
        })),
      },
      por_tipo: porTipo.map((f) => ({
        tipo: f.tipo,
        pedidos: Number(f.pedidos),
        ventas: Number(f.ventas),
      })),
    };
  }

  async productos(sucursalId: string, rango: RangoFechas) {
    const ranking = await this.database.consultar<{
      producto_id: string;
      nombre: string;
      cantidad: string;
      ventas: string;
    }>(
      `SELECT pr.id AS producto_id,
              pr.nombre,
              COALESCE(SUM(pi.cantidad), 0)::text AS cantidad,
              COALESCE(SUM(pi.cantidad * pi.precio_unitario), 0)::text AS ventas
       FROM pedido_items pi
       JOIN pedidos p ON p.id = pi.pedido_id
       JOIN productos pr ON pr.id = pi.producto_id
       WHERE p.sucursal_id = $1
         AND p.created_at >= $2::timestamptz
         AND p.created_at < ($3::date + interval '1 day')
         AND p.estado NOT IN ('cancelado', 'rechazado')
       GROUP BY pr.id, pr.nombre
       ORDER BY cantidad DESC
       LIMIT 25`,
      [sucursalId, rango.desde, rango.hasta],
    );

    return {
      periodo: rango,
      ranking: ranking.map((f) => ({
        producto_id: f.producto_id,
        nombre: f.nombre,
        cantidad: Number(f.cantidad),
        ventas: Number(f.ventas),
      })),
    };
  }

  async pedidos(sucursalId: string, rango: RangoFechas) {
    const porEstado = await this.database.consultar<{
      estado: string;
      total: string;
    }>(
      `SELECT estado, COUNT(*)::text AS total
       FROM pedidos
       WHERE sucursal_id = $1
         AND created_at >= $2::timestamptz
         AND created_at < ($3::date + interval '1 day')
       GROUP BY estado
       ORDER BY total DESC`,
      [sucursalId, rango.desde, rango.hasta],
    );

    const porDia = await this.database.consultar<{
      dia: string;
      pedidos: string;
      ventas: string;
    }>(
      `SELECT (created_at AT TIME ZONE 'America/Bogota')::date::text AS dia,
              COUNT(*)::text AS pedidos,
              COALESCE(SUM(total) FILTER (
                WHERE estado NOT IN ('cancelado', 'rechazado')
              ), 0)::text AS ventas
       FROM pedidos
       WHERE sucursal_id = $1
         AND created_at >= $2::timestamptz
         AND created_at < ($3::date + interval '1 day')
       GROUP BY (created_at AT TIME ZONE 'America/Bogota')::date
       ORDER BY dia ASC`,
      [sucursalId, rango.desde, rango.hasta],
    );

    return {
      periodo: rango,
      por_estado: porEstado.map((f) => ({
        estado: f.estado,
        total: Number(f.total),
      })),
      por_dia: porDia.map((f) => ({
        dia: f.dia,
        pedidos: Number(f.pedidos),
        ventas: Number(f.ventas),
      })),
    };
  }

  resolverRango(desde?: string, hasta?: string): RangoFechas {
    const hoy = new Date();
    const hastaDate = hasta ? new Date(hasta) : hoy;
    const desdeDate = desde
      ? new Date(desde)
      : new Date(hastaDate.getTime() - 6 * 24 * 60 * 60 * 1000);

    return {
      desde: desdeDate.toISOString().slice(0, 10),
      hasta: hastaDate.toISOString().slice(0, 10),
    };
  }
}
