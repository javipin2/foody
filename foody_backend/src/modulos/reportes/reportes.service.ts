import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import {
  SQL_DIA_LOCAL,
  SQL_FECHA_CAJA_COALESCED_P2_P3,
  SQL_FECHA_PEDIDOS_P2_P3,
  SQL_FECHA_PEDIDOS_P_P2_P3,
  SQL_NETO_MOVIMIENTO_CAJA,
  SQL_PEDIDOS_VALIDOS,
  SQL_PEDIDOS_VALIDOS_P,
  SQL_TIPOS_MOV_CAJA_VENTA,
  SQL_TZ_NEGOCIO,
} from '../../compartido/sql/ventas-metricas.sql';

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
         AND ${SQL_FECHA_PEDIDOS_P2_P3}
         AND ${SQL_PEDIDOS_VALIDOS}`,
      [sucursalId, rango.desde, rango.hasta],
    );

    const caja = await this.database.consultarUno<{
      ventas_caja: string;
      movimientos: string;
    }>(
      `SELECT COALESCE(SUM(${SQL_NETO_MOVIMIENTO_CAJA}), 0)::text AS ventas_caja,
              COUNT(*) FILTER (WHERE m.tipo = 'venta')::text AS movimientos
       FROM movimientos_caja m
       LEFT JOIN pedidos p ON p.id = m.pedido_id
       WHERE m.sucursal_id = $1
         AND ${SQL_TIPOS_MOV_CAJA_VENTA}
         AND ${SQL_FECHA_CAJA_COALESCED_P2_P3}`,
      [sucursalId, rango.desde, rango.hasta],
    );

    const ventasPedidos = Number(resumen?.ventas_total ?? 0);
    const ventasCaja = Number(caja?.ventas_caja ?? 0);

    const porMetodoCaja = await this.database.consultar<{
      metodo_pago: string;
      total: string;
    }>(
      `SELECT COALESCE(m.metodo_pago, 'sin_metodo') AS metodo_pago,
              COALESCE(SUM(${SQL_NETO_MOVIMIENTO_CAJA}), 0)::text AS total
       FROM movimientos_caja m
       LEFT JOIN pedidos p ON p.id = m.pedido_id
       WHERE m.sucursal_id = $1
         AND ${SQL_TIPOS_MOV_CAJA_VENTA}
         AND ${SQL_FECHA_CAJA_COALESCED_P2_P3}
       GROUP BY m.metodo_pago
       HAVING COALESCE(SUM(${SQL_NETO_MOVIMIENTO_CAJA}), 0) <> 0
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
         AND ${SQL_FECHA_PEDIDOS_P2_P3}
         AND ${SQL_PEDIDOS_VALIDOS}
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
        // CONS-REP-OPEN-01: universos distintos (tickets vs cobrado), no bug de suma.
        etiqueta_ventas_pedidos: 'Tickets (total pedidos)',
        etiqueta_ventas_caja: 'Movimientos netos de caja',
        nota_periodo_caja:
          'Para movimientos ligados a un pedido se usa la fecha de creación del pedido; para movimientos sin pedido, la fecha del movimiento.',
        nota_universos:
          'Tickets suma pedidos del período (incluye abiertos sin cobrar). ' +
          'Caja suma ventas menos devoluciones. En movimientos ligados a pedido usa la fecha de creación del pedido; sin pedido, la fecha del movimiento. ' +
          'Por eso no representa necesariamente el efectivo recibido en el rango. Diferencia esperable con mesas/domicilios pendientes.',
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
              COALESCE(
                SUM(
                  pi.cantidad * pi.precio_unitario
                  + COALESCE(pit_ag.sum_topping, 0) * pi.cantidad
                  + COALESCE(pib_ag.sum_bebida, 0)
                ),
                0
              )::text AS ventas
       FROM pedido_items pi
       JOIN pedidos p ON p.id = pi.pedido_id
       JOIN productos pr ON pr.id = pi.producto_id
       LEFT JOIN (
         SELECT pedido_item_id, SUM(precio_topping) AS sum_topping
         FROM pedido_item_toppings
         GROUP BY pedido_item_id
       ) pit_ag ON pit_ag.pedido_item_id = pi.id
       LEFT JOIN (
         SELECT pedido_item_id, SUM(precio_bebida * cantidad) AS sum_bebida
         FROM pedido_item_bebidas
         GROUP BY pedido_item_id
       ) pib_ag ON pib_ag.pedido_item_id = pi.id
       WHERE p.sucursal_id = $1
         AND ${SQL_FECHA_PEDIDOS_P_P2_P3}
         AND ${SQL_PEDIDOS_VALIDOS_P}
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
         AND ${SQL_FECHA_PEDIDOS_P2_P3}
       GROUP BY estado
       ORDER BY total DESC`,
      [sucursalId, rango.desde, rango.hasta],
    );

    const porDia = await this.database.consultar<{
      dia: string;
      pedidos: string;
      ventas: string;
    }>(
      `SELECT ${SQL_DIA_LOCAL}::text AS dia,
              COUNT(*)::text AS pedidos,
              COALESCE(SUM(total) FILTER (
                WHERE ${SQL_PEDIDOS_VALIDOS}
              ), 0)::text AS ventas
       FROM pedidos
       WHERE sucursal_id = $1
         AND ${SQL_FECHA_PEDIDOS_P2_P3}
       GROUP BY ${SQL_DIA_LOCAL}
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
    const hoy = new Intl.DateTimeFormat('en-CA', {
      timeZone: SQL_TZ_NEGOCIO,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(new Date());
    const hastaDate = hasta
      ? new Date(hasta)
      : new Date(`${hoy}T00:00:00.000Z`);
    const desdeDate = desde
      ? new Date(desde)
      : new Date(hastaDate.getTime() - 6 * 24 * 60 * 60 * 1000);

    return {
      desde: desdeDate.toISOString().slice(0, 10),
      hasta: hastaDate.toISOString().slice(0, 10),
    };
  }
}
