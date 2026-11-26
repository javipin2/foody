-- Link stock movements produced by an order line to that stable line ID.
-- The FK is deferred because order creation may write stock before inserting
-- pedido_items, while both operations still commit in one transaction.
ALTER TABLE movimientos_ingrediente
  ADD COLUMN IF NOT EXISTS pedido_item_id uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'movimientos_ingrediente_pedido_item_id_fkey'
      AND conrelid = 'public.movimientos_ingrediente'::regclass
  ) THEN
    ALTER TABLE movimientos_ingrediente
      ADD CONSTRAINT movimientos_ingrediente_pedido_item_id_fkey
      FOREIGN KEY (pedido_item_id) REFERENCES pedido_items(id)
      DEFERRABLE INITIALLY DEFERRED;
  END IF;
END $$;

ALTER TABLE movimientos_ingrediente
  DROP CONSTRAINT IF EXISTS movimientos_ingrediente_tipo_check;

ALTER TABLE movimientos_ingrediente
  ADD CONSTRAINT movimientos_ingrediente_tipo_check
  CHECK (tipo IN ('compra', 'venta', 'ajuste', 'merma', 'produccion', 'conteo', 'devolucion'));

CREATE INDEX IF NOT EXISTS idx_movimientos_ingrediente_pedido_item
  ON movimientos_ingrediente (sucursal_id, pedido_id, pedido_item_id, ingrediente_id, tipo)
  WHERE pedido_item_id IS NOT NULL;

COMMENT ON COLUMN movimientos_ingrediente.pedido_item_id IS
  'Order line responsible for this stock movement; NULL for historical movements and non-line stock operations.';
