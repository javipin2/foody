-- Foody — recetas y costeo en bebidas y toppings (mismo motor que productos)
-- Spec: docs/ESPEC_COSTEO_MERCADO_KYG.md § bebidas; docs/MODULO_COSTEO.md

ALTER TABLE bebidas
  ADD COLUMN IF NOT EXISTS receta_id uuid REFERENCES recetas(id),
  ADD COLUMN IF NOT EXISTS costo_calculado numeric(12,2),
  ADD COLUMN IF NOT EXISTS precio_sugerido numeric(12,2),
  ADD COLUMN IF NOT EXISTS margen_objetivo numeric(5,2);

ALTER TABLE toppings
  ADD COLUMN IF NOT EXISTS receta_id uuid REFERENCES recetas(id),
  ADD COLUMN IF NOT EXISTS costo_calculado numeric(12,2),
  ADD COLUMN IF NOT EXISTS precio_sugerido numeric(12,2),
  ADD COLUMN IF NOT EXISTS margen_objetivo numeric(5,2);

CREATE INDEX IF NOT EXISTS idx_bebidas_receta ON bebidas(receta_id)
  WHERE receta_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_toppings_receta ON toppings(receta_id)
  WHERE receta_id IS NOT NULL;
