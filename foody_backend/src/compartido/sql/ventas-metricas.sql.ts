/**
 * Fragmentos SQL de métricas de ventas — fuente única (BN-MOD-05).
 * Usar desde reportes, analítica y dashboard para no divergir filtros/fechas/caja.
 */

export const SQL_TZ_NEGOCIO = 'America/Bogota';

/** Prefijo de columna: `''` | `'p.'` | `'pedidos.'` */
export function sqlPedidosValidos(prefijoColumna = ''): string {
  return `${prefijoColumna}estado NOT IN ('cancelado', 'rechazado')`;
}

export const SQL_PEDIDOS_VALIDOS = sqlPedidosValidos();
export const SQL_PEDIDOS_VALIDOS_P = sqlPedidosValidos('p.');

/** Rango [desde, hasta] inclusive por día (placeholders ya numerados, ej. `$2`). */
export function sqlFechaRango(
  col: string,
  pDesde: string,
  pHasta: string,
): string {
  return `${col} >= ${pDesde}::timestamptz AND ${col} < (${pHasta}::date + interval '1 day')`;
}

/** Reportes clásico: $1=sucursal, $2=desde, $3=hasta */
export const SQL_FECHA_PEDIDOS_P2_P3 = sqlFechaRango('created_at', '$2', '$3');
export const SQL_FECHA_PEDIDOS_P_P2_P3 = sqlFechaRango(
  'p.created_at',
  '$2',
  '$3',
);

export const SQL_FECHA_CAJA_COALESCED_P2_P3 =
  `( (p.created_at IS NOT NULL AND p.created_at >= $2::timestamptz AND p.created_at < ($3::date + interval '1 day'))` +
  ` OR (p.created_at IS NULL AND m.created_at >= $2::timestamptz AND m.created_at < ($3::date + interval '1 day')) )`;

/** Neto venta − devolución en movimientos_caja. */
export const SQL_NETO_MOVIMIENTO_CAJA =
  `CASE WHEN m.tipo = 'venta' THEN m.monto ELSE -m.monto END`;

export const SQL_TIPOS_MOV_CAJA_VENTA = `m.tipo IN ('venta', 'devolucion')`;

export const SQL_DIA_LOCAL = `(created_at AT TIME ZONE '${SQL_TZ_NEGOCIO}')::date`;
export const SQL_DIA_LOCAL_P = `(p.created_at AT TIME ZONE '${SQL_TZ_NEGOCIO}')::date`;
export const SQL_HOY_LOCAL = `(NOW() AT TIME ZONE '${SQL_TZ_NEGOCIO}')::date`;
// PERF-SQL-01: evitar `created_at::date` en condiciones (fuerza Seq Scan).
// Usamos rango half-open calculado en TZ de negocio:
//   inicio_hoy_local <= created_at < inicio_hoy_local + 1 día
export const SQL_INICIO_HOY_LOCAL = `((${SQL_HOY_LOCAL})::timestamp AT TIME ZONE '${SQL_TZ_NEGOCIO}')`;
export const SQL_PEDIDO_ES_HOY = `created_at >= ${SQL_INICIO_HOY_LOCAL} AND created_at < (${SQL_INICIO_HOY_LOCAL} + interval '1 day')`;
export const SQL_PEDIDO_DESDE_7D = `created_at >= ${SQL_HOY_LOCAL} - interval '6 days'`;
export const SQL_PEDIDO_DESDE_7D_P = `p.created_at >= ${SQL_HOY_LOCAL} - interval '6 days'`;
