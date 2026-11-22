"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ANALITICA_LIMITE_RANKING = exports.ANALITICA_FECHA_MOV_INV = exports.ANALITICA_COCINA_ITEM = exports.SQL_TZ_NEGOCIO = exports.SQL_DIA_LOCAL = exports.SQL_TIPOS_MOV_CAJA_VENTA = exports.SQL_NETO_MOVIMIENTO_CAJA = exports.ANALITICA_FECHA_CAJA = exports.ANALITICA_FECHA_PEDIDOS = exports.ANALITICA_PEDIDOS_VALIDOS = void 0;
var ventas_metricas_sql_1 = require("../../compartido/sql/ventas-metricas.sql");
Object.defineProperty(exports, "ANALITICA_PEDIDOS_VALIDOS", { enumerable: true, get: function () { return ventas_metricas_sql_1.SQL_PEDIDOS_VALIDOS; } });
Object.defineProperty(exports, "ANALITICA_FECHA_PEDIDOS", { enumerable: true, get: function () { return ventas_metricas_sql_1.SQL_FECHA_PEDIDOS_P2_P3; } });
Object.defineProperty(exports, "ANALITICA_FECHA_CAJA", { enumerable: true, get: function () { return ventas_metricas_sql_1.SQL_FECHA_CAJA_COALESCED_P2_P3; } });
Object.defineProperty(exports, "SQL_NETO_MOVIMIENTO_CAJA", { enumerable: true, get: function () { return ventas_metricas_sql_1.SQL_NETO_MOVIMIENTO_CAJA; } });
Object.defineProperty(exports, "SQL_TIPOS_MOV_CAJA_VENTA", { enumerable: true, get: function () { return ventas_metricas_sql_1.SQL_TIPOS_MOV_CAJA_VENTA; } });
Object.defineProperty(exports, "SQL_DIA_LOCAL", { enumerable: true, get: function () { return ventas_metricas_sql_1.SQL_DIA_LOCAL; } });
Object.defineProperty(exports, "SQL_TZ_NEGOCIO", { enumerable: true, get: function () { return ventas_metricas_sql_1.SQL_TZ_NEGOCIO; } });
exports.ANALITICA_COCINA_ITEM = `COALESCE(pi.cocina_id, pr.cocina_id)`;
exports.ANALITICA_FECHA_MOV_INV = `m.created_at >= $2::timestamptz AND m.created_at < ($3::date + interval '1 day')`;
exports.ANALITICA_LIMITE_RANKING = 25;
//# sourceMappingURL=analitica-sql.const.js.map