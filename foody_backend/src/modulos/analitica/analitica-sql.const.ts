/**
 * Constantes SQL del módulo analítica.
 * Filtros de venta/fecha/caja → compartido (BN-MOD-05).
 */
export {
  SQL_PEDIDOS_VALIDOS as ANALITICA_PEDIDOS_VALIDOS,
  SQL_FECHA_PEDIDOS_P2_P3 as ANALITICA_FECHA_PEDIDOS,
  SQL_FECHA_CAJA_COALESCED_P2_P3 as ANALITICA_FECHA_CAJA,
  SQL_NETO_MOVIMIENTO_CAJA,
  SQL_TIPOS_MOV_CAJA_VENTA,
  SQL_DIA_LOCAL,
  SQL_TZ_NEGOCIO,
} from '../../compartido/sql/ventas-metricas.sql';

export const ANALITICA_COCINA_ITEM = `COALESCE(pi.cocina_id, pr.cocina_id)`;

export const ANALITICA_FECHA_MOV_INV = `m.created_at >= $2::timestamptz AND m.created_at < ($3::date + interval '1 day')`;

export const ANALITICA_LIMITE_RANKING = 25;
