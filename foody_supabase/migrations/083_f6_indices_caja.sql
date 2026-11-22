-- F6: índices caja / movimientos (BD-IDX-01/02 · PERF-IDX-01 · A-10)
-- uq_caja_abierta_sucursal (081) ya cubre lookup abierta; este índice ayuda listados generales.

CREATE INDEX IF NOT EXISTS idx_cajas_sucursal_estado
  ON cajas (sucursal_id, estado);

CREATE INDEX IF NOT EXISTS idx_movimientos_caja_caja_id
  ON movimientos_caja (caja_id);

CREATE INDEX IF NOT EXISTS idx_movimientos_caja_sucursal_created
  ON movimientos_caja (sucursal_id, created_at DESC);
