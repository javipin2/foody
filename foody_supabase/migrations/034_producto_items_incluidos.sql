-- Foody S5 — productos con ítems de menú incluidos (caso rosquetes)
-- Spec: docs/ADMIN_MENU_COSTEO.md §3

CREATE TABLE IF NOT EXISTS producto_items_incluidos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid NOT NULL REFERENCES sucursales(id) ON DELETE CASCADE,
  producto_id uuid NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
  producto_incluido_id uuid NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
  cantidad numeric(12,3) NOT NULL DEFAULT 1 CHECK (cantidad > 0),
  created_at timestamptz DEFAULT now(),
  UNIQUE (producto_id, producto_incluido_id),
  CHECK (producto_id <> producto_incluido_id)
);

CREATE INDEX IF NOT EXISTS idx_pii_producto
  ON producto_items_incluidos (producto_id);
CREATE INDEX IF NOT EXISTS idx_pii_incluido
  ON producto_items_incluidos (producto_incluido_id);

-- Demo rosquetes — sucursal c0000000-0000-4000-8000-000000000001
INSERT INTO categorias (id, sucursal_id, nombre, orden, activa) VALUES
  (
    'e0000000-0000-4000-8000-000000000003',
    'c0000000-0000-4000-8000-000000000001',
    'Rosquetes',
    0,
    true
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO ingredientes (
  id, sucursal_id, nombre, unidad_base, tipo_costeo,
  stock_actual, stock_minimo, costo_unitario_actual, activo
) VALUES
  (
    '40000000-0000-4000-8000-000000000010',
    'c0000000-0000-4000-8000-000000000001',
    'Harina (demo rosquete)',
    'g',
    'peso',
    10000,
    1000,
    0.004,
    true
  ),
  (
    '40000000-0000-4000-8000-000000000011',
    'c0000000-0000-4000-8000-000000000001',
    'Huevo crudo (demo)',
    'und',
    'pieza',
    500,
    50,
    600,
    true
  ),
  (
    '40000000-0000-4000-8000-000000000012',
    'c0000000-0000-4000-8000-000000000001',
    'Aceite (demo)',
    'ml',
    'peso',
    5000,
    500,
    0.012,
    true
  )
ON CONFLICT (id) DO UPDATE SET
  stock_actual = EXCLUDED.stock_actual,
  costo_unitario_actual = EXCLUDED.costo_unitario_actual,
  activo = true;

INSERT INTO recetas (id, sucursal_id, nombre, rendimiento_porciones, tipo)
VALUES
  (
    '41000000-0000-4000-8000-000000000010',
    'c0000000-0000-4000-8000-000000000001',
    'Receta rosquete sencillo demo',
    1,
    'producto'
  ),
  (
    '41000000-0000-4000-8000-000000000011',
    'c0000000-0000-4000-8000-000000000001',
    'Receta huevo frito demo',
    1,
    'producto'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO receta_items (receta_id, tipo_item, ingrediente_id, cantidad, unidad, orden)
VALUES
  (
    '41000000-0000-4000-8000-000000000010',
    'ingrediente',
    '40000000-0000-4000-8000-000000000010',
    80,
    'g',
    1
  ),
  (
    '41000000-0000-4000-8000-000000000011',
    'ingrediente',
    '40000000-0000-4000-8000-000000000011',
    1,
    'und',
    1
  ),
  (
    '41000000-0000-4000-8000-000000000011',
    'ingrediente',
    '40000000-0000-4000-8000-000000000012',
    15,
    'ml',
    2
  );

INSERT INTO productos (
  id, sucursal_id, categoria_id, cocina_id, nombre, descripcion,
  precio, disponible, orden, receta_id
) VALUES
  (
    'f0000000-0000-4000-8000-000000000010',
    'c0000000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000003',
    'd0000000-0000-4000-8000-000000000001',
    'Rosquete sencillo',
    'Vendido por unidad',
    2500,
    true,
    1,
    '41000000-0000-4000-8000-000000000010'
  ),
  (
    'f0000000-0000-4000-8000-000000000011',
    'c0000000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000001',
    'Huevo frito',
    'Incluye 1 rosquete',
    8000,
    true,
    10,
    '41000000-0000-4000-8000-000000000011'
  )
ON CONFLICT (id) DO UPDATE SET
  receta_id = EXCLUDED.receta_id,
  nombre = EXCLUDED.nombre,
  precio = EXCLUDED.precio;

INSERT INTO producto_items_incluidos (
  sucursal_id, producto_id, producto_incluido_id, cantidad
) VALUES
  (
    'c0000000-0000-4000-8000-000000000001',
    'f0000000-0000-4000-8000-000000000011',
    'f0000000-0000-4000-8000-000000000010',
    1
  )
ON CONFLICT (producto_id, producto_incluido_id) DO UPDATE SET
  cantidad = EXCLUDED.cantidad;
