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
         AND created_at >= $2::timestamptz
         AND created_at < ($3::date + interval '1 day')
         AND estado NOT IN ('cancelado', 'rechazado')`, [sucursalId, rango.desde, rango.hasta]);
        const filtroFechaCaja = `COALESCE(p.created_at, m.created_at)`;
        const caja = await this.database.consultarUno(`SELECT COALESCE(SUM(m.monto), 0)::text AS ventas_caja,
              COUNT(*)::text AS movimientos
       FROM movimientos_caja m
       LEFT JOIN pedidos p ON p.id = m.pedido_id
       WHERE m.sucursal_id = $1
         AND m.tipo = 'venta'
         AND ${filtroFechaCaja} >= $2::timestamptz
         AND ${filtroFechaCaja} < ($3::date + interval '1 day')`, [sucursalId, rango.desde, rango.hasta]);
        const ventasPedidos = Number(resumen?.ventas_total ?? 0);
        const ventasCaja = Number(caja?.ventas_caja ?? 0);
        const porMetodoCaja = await this.database.consultar(`SELECT COALESCE(m.metodo_pago, 'sin_metodo') AS metodo_pago,
              COALESCE(SUM(m.monto), 0)::text AS total
       FROM movimientos_caja m
       LEFT JOIN pedidos p ON p.id = m.pedido_id
       WHERE m.sucursal_id = $1
         AND m.tipo = 'venta'
         AND COALESCE(p.created_at, m.created_at) >= $2::timestamptz
         AND COALESCE(p.created_at, m.created_at) < ($3::date + interval '1 day')
       GROUP BY m.metodo_pago
       ORDER BY total DESC`, [sucursalId, rango.desde, rango.hasta]);
        const porTipo = await this.database.consultar(`SELECT tipo,
              COUNT(*)::text AS pedidos,
              COALESCE(SUM(total), 0)::text AS ventas
       FROM pedidos
       WHERE sucursal_id = $1
         AND created_at >= $2::timestamptz
         AND created_at < ($3::date + interval '1 day')
         AND estado NOT IN ('cancelado', 'rechazado')
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
    async productos(sucursalId, rango) {
        const ranking = await this.database.consultar(`SELECT pr.id AS producto_id,
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
         AND created_at >= $2::timestamptz
         AND created_at < ($3::date + interval '1 day')
       GROUP BY estado
       ORDER BY total DESC`, [sucursalId, rango.desde, rango.hasta]);
        const porDia = await this.database.consultar(`SELECT (created_at AT TIME ZONE 'America/Bogota')::date::text AS dia,
              COUNT(*)::text AS pedidos,
              COALESCE(SUM(total) FILTER (
                WHERE estado NOT IN ('cancelado', 'rechazado')
              ), 0)::text AS ventas
       FROM pedidos
       WHERE sucursal_id = $1
         AND created_at >= $2::timestamptz
         AND created_at < ($3::date + interval '1 day')
       GROUP BY (created_at AT TIME ZONE 'America/Bogota')::date
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
            })),
        };
    }
    resolverRango(desde, hasta) {
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
};
exports.ReportesService = ReportesService;
exports.ReportesService = ReportesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], ReportesService);
//# sourceMappingURL=reportes.service.js.map