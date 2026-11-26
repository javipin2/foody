-- Preserve the exact combo composition sold on each order item.
-- This snapshot is used for KDS/printing and stock restoration if catalog data changes.
ALTER TABLE pedido_combo_selecciones
  ADD COLUMN IF NOT EXISTS componentes_snapshot jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN pedido_combo_selecciones.componentes_snapshot IS
  'Immutable-at-sale snapshot: type, item id, display name, quantity and unit cost for each base and selected combo component.';
