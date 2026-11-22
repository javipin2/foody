-- Foody — P2-12: producción en lote (subrecetas con usa_produccion_lote)

ALTER TABLE ingredientes
  ADD COLUMN IF NOT EXISTS es_subreceta bool DEFAULT false,
  ADD COLUMN IF NOT EXISTS receta_subreceta_id uuid REFERENCES recetas(id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ingredientes_receta_subreceta_sucursal
  ON ingredientes(sucursal_id, receta_subreceta_id)
  WHERE receta_subreceta_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS producciones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid NOT NULL REFERENCES sucursales(id),
  receta_id uuid NOT NULL REFERENCES recetas(id),
  cantidad_producida numeric(18,3) NOT NULL CHECK (cantidad_producida > 0),
  costo_real_produccion numeric(12,4) NOT NULL,
  costo_unitario_resultado numeric(12,4) NOT NULL,
  registrado_por uuid REFERENCES usuarios(id),
  observaciones text,
  fecha timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_producciones_sucursal_fecha
  ON producciones(sucursal_id, fecha DESC);

ALTER TABLE movimientos_ingrediente
  ADD COLUMN IF NOT EXISTS produccion_id uuid REFERENCES producciones(id);

ALTER TABLE movimientos_ingrediente ENABLE ROW LEVEL SECURITY;
ALTER TABLE producciones ENABLE ROW LEVEL SECURITY;
