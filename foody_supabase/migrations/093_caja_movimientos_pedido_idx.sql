-- Caja: historial por pedido para trazabilidad sin escanear todos los turnos.
CREATE INDEX IF NOT EXISTS idx_movimientos_caja_sucursal_pedido_fecha
  ON movimientos_caja (sucursal_id, pedido_id, created_at DESC)
  WHERE pedido_id IS NOT NULL;
