"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ReportesService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const ventas_metricas_sql_1 = require("../../compartido/sql/ventas-metricas.sql");
let ReportesService = class ReportesService {
    database;
    constructor(database) {
        this.database = database;
    }
    async financiero(sucursalId, rango) {
        const resumen = await this.database.consultarUno(`SELECT COALESCE(SUM(total), 0)::text AS ventas_total,
              COALESCE(SUM(subtotal), 0)::text AS subtotal,
              COALESCE(SUM(costo_domicilio), 0)::text AS costo_domicilio,
              COALESCE(SUM(descuento), 0)::text AS descuentos,
              COUNT(*)::text AS pedidos,
              COALESCE(AVG(total), 0)::text AS ticket_promedio
       FROM pedidos
       WHERE sucursal_id = $1
         AND ${ventas_metricas_sql_1.SQL_FECHA_PEDIDOS_P2_P3}
         AND ${ventas_metricas_sql_1.SQL_PEDIDOS_VALIDOS}`, [sucursalId, rango.desde, rango.hasta]);
        const caja = await this.database.consultarUno(`SELECT COALESCE(SUM(${ventas_metricas_sql_1.SQL_NETO_MOVIMIENTO_CAJA}), 0)::text AS ventas_caja,
              COUNT(*) FILTER (WHERE m.tipo = 'venta')::text AS movimientos
       FROM movimientos_caja m
       LEFT JOIN pedidos p ON p.id = m.pedido_id
       WHERE m.sucursal_id = $1
         AND ${ventas_metricas_sql_1.SQL_TIPOS_MOV_CAJA_VENTA}
         AND ${ventas_metricas_sql_1.SQL_FECHA_CAJA_COALESCED_P2_P3}`, [sucursalId, rango.desde, rango.hasta]);
        const ventasPedidos = Number(resumen?.ventas_total ?? 0);
        const ventasCaja = Number(caja?.ventas_caja ?? 0);
        const recaudoPeriodo = await this.database.consultarUno(`SELECT COALESCE(SUM(${ventas_metricas_sql_1.SQL_NETO_MOVIMIENTO_CAJA}), 0)::text AS total_neto,
              COUNT(*) FILTER (WHERE m.tipo = 'venta')::text AS movimientos_venta
       FROM movimientos_caja m
       WHERE m.sucursal_id = $1
         AND ${ventas_metricas_sql_1.SQL_TIPOS_MOV_CAJA_VENTA}
         AND ${ventas_metricas_sql_1.SQL_FECHA_MOVIMIENTOS_CAJA_P2_P3}`, [sucursalId, rango.desde, rango.hasta]);
        const porMetodoCaja = await this.database.consultar(`SELECT COALESCE(m.metodo_pago, 'sin_metodo') AS metodo_pago,
              COALESCE(SUM(${ventas_metricas_sql_1.SQL_NETO_MOVIMIENTO_CAJA}), 0)::text AS total
       FROM movimientos_caja m
       LEFT JOIN pedidos p ON p.id = m.pedido_id
       WHERE m.sucursal_id = $1
         AND ${ventas_metricas_sql_1.SQL_TIPOS_MOV_CAJA_VENTA}
         AND ${ventas_metricas_sql_1.SQL_FECHA_CAJA_COALESCED_P2_P3}
       GROUP BY m.metodo_pago
       HAVING COALESCE(SUM(${ventas_metricas_sql_1.SQL_NETO_MOVIMIENTO_CAJA}), 0) <> 0
       ORDER BY total DESC`, [sucursalId, rango.desde, rango.hasta]);
        const porTipo = await this.database.consultar(`SELECT tipo,
              COUNT(*)::text AS pedidos,
              COALESCE(SUM(total), 0)::text AS ventas,
              COALESCE(SUM(costo_domicilio), 0)::text AS costo_domicilio
       FROM pedidos
       WHERE sucursal_id = $1
         AND ${ventas_metricas_sql_1.SQL_FECHA_PEDIDOS_P2_P3}
         AND ${ventas_metricas_sql_1.SQL_PEDIDOS_VALIDOS}
       GROUP BY tipo
       ORDER BY ventas DESC`, [sucursalId, rango.desde, rango.hasta]);
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
                etiqueta_ventas_pedidos: 'Valor total de pedidos creados en el rango',
                etiqueta_ventas_caja: 'Cobros netos asociados a pedidos',
                nota_periodo_caja: 'Los movimientos ligados a pedidos se atribuyen por fecha de creación del pedido, aunque el cobro ocurra después del rango; los movimientos sin pedido usan su propia fecha.',
                nota_universos: 'El valor total suma pedidos válidos creados en el rango e incluye el cargo de domicilio; se muestra como valor de pedidos, no como ingreso reconocido del restaurante. El cargo de domicilio se desglosa aparte y no debe sumarse dos veces. Puede incluir pedidos sin cobrar. Cobros netos resta devoluciones asociados a esos pedidos; usa la fecha del pedido, aunque el cobro ocurra después del rango. No representa el efectivo recibido en el rango ni el descuadre físico de un turno.',
                por_metodo_caja: porMetodoCaja.map((f) => ({
                    metodo_pago: f.metodo_pago,
                    total: Number(f.total),
                })),
            },
            recaudo_periodo: {
                total_neto: Number(recaudoPeriodo?.total_neto ?? 0),
                movimientos_venta: Number(recaudoPeriodo?.movimientos_venta ?? 0),
                etiqueta: 'Recaudo neto por fecha de movimiento',
                nota: 'Suma ventas menos devoluciones registradas en el rango por fecha del movimiento. Puede incluir pedidos creados antes del rango. Las propinas voluntarias no se incluyen en ventas ni en este recaudo.',
            },
            por_tipo: porTipo.map((f) => ({
                tipo: f.tipo,
                pedidos: Number(f.pedidos),
                ventas: Number(f.ventas),
                costo_domicilio: Number(f.costo_domicilio),
            })),
        };
    }
    async productos(sucursalId, rango) {
        const ranking = await this.database.consultar(`SELECT pr.id AS producto_id,
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
         AND ${ventas_metricas_sql_1.SQL_FECHA_PEDIDOS_P_P2_P3}
         AND ${ventas_metricas_sql_1.SQL_PEDIDOS_VALIDOS_P}
       GROUP BY pr.id, pr.nombre
       ORDER BY cantidad DESC
       LIMIT 25`, [sucursalId, rango.desde, rango.hasta]);
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
    async pedidos(sucursalId, rango) {
        const porEstado = await this.database.consultar(`SELECT estado, COUNT(*)::text AS total
       FROM pedidos
       WHERE sucursal_id = $1
         AND ${ventas_metricas_sql_1.SQL_FECHA_PEDIDOS_P2_P3}
       GROUP BY estado
       ORDER BY total DESC`, [sucursalId, rango.desde, rango.hasta]);
        const porDia = await this.database.consultar(`SELECT ${ventas_metricas_sql_1.SQL_DIA_LOCAL}::text AS dia,
              COUNT(*)::text AS pedidos,
              COALESCE(SUM(total) FILTER (
                WHERE ${ventas_metricas_sql_1.SQL_PEDIDOS_VALIDOS}
              ), 0)::text AS ventas,
              COALESCE(SUM(costo_domicilio) FILTER (
                WHERE ${ventas_metricas_sql_1.SQL_PEDIDOS_VALIDOS}
              ), 0)::text AS costo_domicilio
       FROM pedidos
       WHERE sucursal_id = $1
         AND ${ventas_metricas_sql_1.SQL_FECHA_PEDIDOS_P2_P3}
       GROUP BY ${ventas_metricas_sql_1.SQL_DIA_LOCAL}
       ORDER BY dia ASC`, [sucursalId, rango.desde, rango.hasta]);
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
                costo_domicilio: Number(f.costo_domicilio),
            })),
        };
    }
    resolverRango(desde, hasta) {
        const hoy = new Intl.DateTimeFormat('en-CA', {
            timeZone: ventas_metricas_sql_1.SQL_TZ_NEGOCIO,
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
};
exports.ReportesService = ReportesService;
exports.ReportesService = ReportesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], ReportesService);
//# sourceMappingURL=reportes.service.js.map