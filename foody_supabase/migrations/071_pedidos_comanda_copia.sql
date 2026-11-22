-- Contador de comandas de cocina impresas (Copia 1, Copia 2, …).
ALTER TABLE pedidos
  ADD COLUMN IF NOT EXISTS comanda_copia INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN pedidos.comanda_copia IS
  'Número de la última comanda encolada a cocina; se incrementa en cada impresión.';
