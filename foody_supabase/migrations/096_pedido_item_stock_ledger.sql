-- Link stock movements produced by an order line to that stable line ID.
-- The FK is deferred because order creation may write stock before inserting
-- pedido_items, while both operations still commit in one transaction. Removing
-- an editable order line preserves the movement ledger and clears only its link.
ALTER TABLE movimientos_ingrediente
  ADD COLUMN IF NOT EXISTS pedido_item_id uuid;

ALTER TABLE pedido_items
  ADD COLUMN IF NOT EXISTS stock_snapshot_version smallint;

ALTER TABLE pedido_items
  DROP CONSTRAINT IF EXISTS pedido_items_stock_snapshot_version_check;

ALTER TABLE pedido_items
  ADD CONSTRAINT pedido_items_stock_snapshot_version_check
  CHECK (stock_snapshot_version IS NULL OR stock_snapshot_version > 0);

ALTER TABLE movimientos_ingrediente
  DROP CONSTRAINT IF EXISTS movimientos_ingrediente_pedido_item_id_fkey;

ALTER TABLE movimientos_ingrediente
  ADD CONSTRAINT movimientos_ingrediente_pedido_item_id_fkey
  FOREIGN KEY (pedido_item_id) REFERENCES pedido_items(id) ON DELETE SET NULL
  DEFERRABLE INITIALLY DEFERRED;

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

COMMENT ON COLUMN pedido_items.stock_snapshot_version IS
  'Non-NULL when the order line was included in a stock deduction using line-linked inventory movements; NULL for historical or not-yet-deducted lines.';
