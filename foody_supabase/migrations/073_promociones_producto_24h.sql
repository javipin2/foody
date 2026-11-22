-- Foody — promociones estilo estado WhatsApp (24h + producto opcional)
ALTER TABLE estados_promociones
  ADD COLUMN IF NOT EXISTS producto_id uuid REFERENCES productos(id) ON DELETE SET NULL;

COMMENT ON COLUMN estados_promociones.producto_id IS
  'Producto opcional vinculado al estado/promo (CTA Ir al producto en cliente)';

-- Caducar estados antiguos sin fecha (regla producto: 24h)
UPDATE estados_promociones
SET expira_at = created_at + interval '24 hours'
WHERE expira_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_estados_promociones_producto
  ON estados_promociones(producto_id)
  WHERE producto_id IS NOT NULL;
