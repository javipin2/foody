"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SQL_PEDIDO_DESDE_7D_P = exports.SQL_PEDIDO_DESDE_7D = exports.SQL_FIN_7D_LOCAL = exports.SQL_INICIO_7D_LOCAL = exports.SQL_PEDIDO_ES_HOY = exports.SQL_INICIO_HOY_LOCAL = exports.SQL_HOY_LOCAL = exports.SQL_DIA_LOCAL_P = exports.SQL_DIA_LOCAL = exports.SQL_TIPOS_MOV_CAJA_VENTA = exports.SQL_NETO_MOVIMIENTO_CAJA = exports.SQL_FECHA_CAJA_COALESCED_P2_P3 = exports.SQL_FECHA_MOVIMIENTOS_CAJA_P2_P3 = exports.SQL_FECHA_PEDIDOS_P_P2_P3 = exports.SQL_FECHA_PEDIDOS_P2_P3 = exports.SQL_PEDIDOS_VALIDOS_P = exports.SQL_PEDIDOS_VALIDOS = exports.SQL_TZ_NEGOCIO = void 0;
exports.sqlPedidosValidos = sqlPedidosValidos;
exports.sqlFechaRango = sqlFechaRango;
exports.SQL_TZ_NEGOCIO = 'America/Bogota';
function sqlPedidosValidos(prefijoColumna = '') {
    return `${prefijoColumna}estado NOT IN ('cancelado', 'rechazado')`;
}
exports.SQL_PEDIDOS_VALIDOS = sqlPedidosValidos();
exports.SQL_PEDIDOS_VALIDOS_P = sqlPedidosValidos('p.');
function sqlFechaRango(col, pDesde, pHasta) {
    return `${col} >= (${pDesde}::date::timestamp AT TIME ZONE '${exports.SQL_TZ_NEGOCIO}') AND ${col} < ((${pHasta}::date + interval '1 day')::timestamp AT TIME ZONE '${exports.SQL_TZ_NEGOCIO}')`;
}
exports.SQL_FECHA_PEDIDOS_P2_P3 = sqlFechaRango('created_at', '$2', '$3');
exports.SQL_FECHA_PEDIDOS_P_P2_P3 = sqlFechaRango('p.created_at', '$2', '$3');
exports.SQL_FECHA_MOVIMIENTOS_CAJA_P2_P3 = sqlFechaRango('m.created_at', '$2', '$3');
exports.SQL_FECHA_CAJA_COALESCED_P2_P3 = `( (p.created_at IS NOT NULL AND p.created_at >= ($2::date::timestamp AT TIME ZONE '${exports.SQL_TZ_NEGOCIO}') AND p.created_at < (($3::date + interval '1 day')::timestamp AT TIME ZONE '${exports.SQL_TZ_NEGOCIO}'))` +
    ` OR (p.created_at IS NULL AND m.created_at >= ($2::date::timestamp AT TIME ZONE '${exports.SQL_TZ_NEGOCIO}') AND m.created_at < (($3::date + interval '1 day')::timestamp AT TIME ZONE '${exports.SQL_TZ_NEGOCIO}')) )`;
exports.SQL_NETO_MOVIMIENTO_CAJA = `CASE WHEN m.tipo = 'venta' THEN m.monto ELSE -m.monto END`;
exports.SQL_TIPOS_MOV_CAJA_VENTA = `m.tipo IN ('venta', 'devolucion')`;
exports.SQL_DIA_LOCAL = `(created_at AT TIME ZONE '${exports.SQL_TZ_NEGOCIO}')::date`;
exports.SQL_DIA_LOCAL_P = `(p.created_at AT TIME ZONE '${exports.SQL_TZ_NEGOCIO}')::date`;
exports.SQL_HOY_LOCAL = `(NOW() AT TIME ZONE '${exports.SQL_TZ_NEGOCIO}')::date`;
exports.SQL_INICIO_HOY_LOCAL = `((${exports.SQL_HOY_LOCAL})::timestamp AT TIME ZONE '${exports.SQL_TZ_NEGOCIO}')`;
exports.SQL_PEDIDO_ES_HOY = `created_at >= ${exports.SQL_INICIO_HOY_LOCAL} AND created_at < (${exports.SQL_INICIO_HOY_LOCAL} + interval '1 day')`;
exports.SQL_INICIO_7D_LOCAL = `(((${exports.SQL_HOY_LOCAL}) - 6)::timestamp AT TIME ZONE '${exports.SQL_TZ_NEGOCIO}')`;
exports.SQL_FIN_7D_LOCAL = `(((${exports.SQL_HOY_LOCAL}) + 1)::timestamp AT TIME ZONE '${exports.SQL_TZ_NEGOCIO}')`;
exports.SQL_PEDIDO_DESDE_7D = `created_at >= ${exports.SQL_INICIO_7D_LOCAL} AND created_at < ${exports.SQL_FIN_7D_LOCAL}`;
exports.SQL_PEDIDO_DESDE_7D_P = `p.created_at >= ${exports.SQL_INICIO_7D_LOCAL} AND p.created_at < ${exports.SQL_FIN_7D_LOCAL}`;
//# sourceMappingURL=ventas-metricas.sql.js.map