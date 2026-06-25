-- Foody — Paso 3: extensiones costeo industrial (Fase 1)

ALTER TABLE productos
  ADD COLUMN IF NOT EXISTS costo_domicilio numeric(12,2),
  ADD COLUMN IF NOT EXISTS incluye_bebida_en_receta bool DEFAULT false,
  ADD COLUMN IF NOT EXISTS margen_objetivo numeric(5,2);

ALTER TABLE recetas
  ADD COLUMN IF NOT EXISTS tipo text DEFAULT 'producto',
  ADD COLUMN IF NOT EXISTS margen_error numeric(5,4) DEFAULT 0.05,
  ADD COLUMN IF NOT EXISTS cantidad_resultado numeric(18,3),
  ADD COLUMN IF NOT EXISTS unidad_resultado text,
  ADD COLUMN IF NOT EXISTS usa_produccion_lote bool DEFAULT false,
  ADD COLUMN IF NOT EXISTS canal text DEFAULT 'ambos';

ALTER TABLE combos
  ADD COLUMN IF NOT EXISTS costo_calculado numeric(12,2),
  ADD COLUMN IF NOT EXISTS margen_error numeric(5,4) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS costo_empaque_extra numeric(12,2) DEFAULT 0;

ALTER TABLE sucursales
  ADD COLUMN IF NOT EXISTS margen_objetivo_default numeric(5,2) DEFAULT 35,
  ADD COLUMN IF NOT EXISTS umbral_alerta_margen numeric(5,2) DEFAULT 25;

ALTER TABLE costos_receta
  ADD COLUMN IF NOT EXISTS sucursal_id uuid REFERENCES sucursales(id),
  ADD COLUMN IF NOT EXISTS costo_ingredientes numeric(12,4),
  ADD COLUMN IF NOT EXISTS costo_subrecetas numeric(12,4),
  ADD COLUMN IF NOT EXISTS costo_empaques numeric(12,4),
  ADD COLUMN IF NOT EXISTS costo_merma numeric(12,4),
  ADD COLUMN IF NOT EXISTS food_cost_porcentaje numeric(5,2);

-- Recetas demo existentes → tipo producto
UPDATE recetas SET tipo = 'producto' WHERE tipo IS NULL;

UPDATE sucursales
SET margen_objetivo_default = COALESCE(margen_objetivo_default, 35),
    umbral_alerta_margen = COALESCE(umbral_alerta_margen, 25)
WHERE id = 'c0000000-0000-4000-8000-000000000001';
