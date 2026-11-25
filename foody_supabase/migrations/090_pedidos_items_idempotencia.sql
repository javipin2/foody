-- Evita duplicar líneas/stock/cocina al reintentar un POST de agregar ítems.
-- La clave se acota al pedido y el resultado queda en la misma transacción.
CREATE TABLE IF NOT EXISTS pedidos_items_idempotencia (
  pedido_id uuid NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
  clave text NOT NULL,
  huella text NOT NULL,
  resultado jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pedido_id, clave)
);

REVOKE ALL ON TABLE pedidos_items_idempotencia FROM anon, authenticated;
ALTER TABLE pedidos_items_idempotencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos_items_idempotencia FORCE ROW LEVEL SECURITY;
