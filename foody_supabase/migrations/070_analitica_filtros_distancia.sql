-- Foody 070 — Analítica: distancia en domicilio + índices para filtros combinables

ALTER TABLE asignaciones_domicilio
  ADD COLUMN IF NOT EXISTS distancia_km numeric(10, 3);

COMMENT ON COLUMN asignaciones_domicilio.distancia_km IS
  'Km sucursal→entrega al asignar (NULL en histórico pre-070)';

CREATE INDEX IF NOT EXISTS idx_pedidos_sucursal_mesera_created
  ON pedidos (sucursal_id, mesera_id, created_at DESC)
  WHERE mesera_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pedido_items_cocina
  ON pedido_items (cocina_id)
  WHERE cocina_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pedido_items_producto
  ON pedido_items (producto_id);

CREATE INDEX IF NOT EXISTS idx_alertas_riesgo_abiertas
  ON alertas_riesgo (sucursal_id, created_at DESC)
  WHERE revisada = false;
