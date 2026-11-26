-- Immutable stock snapshots for normal order lines and their toppings/drinks.
-- Apply first to an isolated QA clone; do not migrate the daily database without coordination.
CREATE TABLE IF NOT EXISTS pedido_item_stock_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
  pedido_item_id uuid REFERENCES pedido_items(id) ON DELETE SET NULL
    DEFERRABLE INITIALLY DEFERRED,
  pedido_item_id_original uuid NOT NULL,
  sucursal_id uuid NOT NULL REFERENCES sucursales(id),
  lote_id uuid NOT NULL,
  tipo_componente text NOT NULL CHECK (
    tipo_componente IN ('producto', 'bebida', 'topping')
  ),
  componente_id uuid NOT NULL,
  ingrediente_id uuid NOT NULL REFERENCES ingredientes(id),
  evento text NOT NULL CHECK (evento IN ('consumo', 'devolucion', 'merma')),
  cantidad numeric(14,4) NOT NULL CHECK (cantidad > 0),
  unidades_linea numeric(12,3) NOT NULL CHECK (unidades_linea > 0),
  costo_unitario_snapshot numeric(14,4) NOT NULL DEFAULT 0,
  consumo_id uuid REFERENCES pedido_item_stock_ledger(id),
  operacion_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (evento = 'consumo' AND consumo_id IS NULL AND operacion_id IS NULL)
    OR (evento <> 'consumo' AND consumo_id IS NOT NULL AND operacion_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_pedido_item_stock_ledger_line_component
  ON pedido_item_stock_ledger (
    pedido_item_id_original, tipo_componente, componente_id, created_at
  );
CREATE INDEX IF NOT EXISTS idx_pedido_item_stock_ledger_order
  ON pedido_item_stock_ledger (pedido_id, sucursal_id, ingrediente_id, evento);
CREATE UNIQUE INDEX IF NOT EXISTS idx_pedido_item_stock_ledger_operation
  ON pedido_item_stock_ledger (operacion_id, consumo_id)
  WHERE operacion_id IS NOT NULL;

COMMENT ON TABLE pedido_item_stock_ledger IS
  'Consumo inmutable por componente de una línea normal; las devoluciones y mermas apuntan al consumo original para nunca reexpandir una receta vigente.';
