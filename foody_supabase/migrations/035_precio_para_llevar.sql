-- Foody S6 — precio local vs para llevar / domicilio
-- NULL en precio_para_llevar = mismo precio que precio (local)

ALTER TABLE productos
  ADD COLUMN IF NOT EXISTS precio_para_llevar numeric(12,2);

COMMENT ON COLUMN productos.precio_para_llevar IS
  'Precio para pedidos para_llevar y domicilio. NULL = usar precio (local/mesa).';

-- Demo: hamburguesa más cara para llevar (empaque)
UPDATE productos
SET precio_para_llevar = 19500
WHERE id = 'f0000000-0000-4000-8000-000000000001'
  AND precio_para_llevar IS NULL;
