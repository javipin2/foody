-- Insumos que solo aportan costo (mano de obra, gas fijo, etc.) sin descontar inventario.
ALTER TABLE ingredientes
  ADD COLUMN IF NOT EXISTS descontar_stock boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN ingredientes.descontar_stock IS
  'false = solo costeo en receta; no valida ni descuenta stock al vender';
