-- Mesera asignada a mesa + stock descontado al confirmar (no al crear QR/pendiente)

ALTER TABLE pedidos
  ADD COLUMN IF NOT EXISTS stock_descontado bool NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS mesera_id uuid REFERENCES usuarios(id),
  ADD COLUMN IF NOT EXISTS aprobado_at timestamptz;

ALTER TABLE mesas
  ADD COLUMN IF NOT EXISTS mesera_asignada_id uuid REFERENCES usuarios(id),
  ADD COLUMN IF NOT EXISTS mesera_asignada_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_mesas_mesera_asignada
  ON mesas (sucursal_id, mesera_asignada_id)
  WHERE mesera_asignada_id IS NOT NULL;

COMMENT ON COLUMN pedidos.stock_descontado IS 'true tras descontar inventario al confirmar/aprobar';
COMMENT ON COLUMN mesas.mesera_asignada_id IS 'Mesera que atiende la mesa hasta cierre de cuenta';
