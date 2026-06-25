-- Foody — Paso 1: recetas demo para descuento de inventario (hamburguesa + papas)
-- Sucursal demo: c0000000-0000-4000-8000-000000000001

INSERT INTO ingredientes (
  id, sucursal_id, nombre, unidad_base, tipo_costeo,
  stock_actual, stock_minimo, costo_unitario_actual, activo
) VALUES
  (
    '40000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'Carne molida (demo)',
    'g',
    'peso',
    5000,
    500,
    0.025,
    true
  ),
  (
    '40000000-0000-4000-8000-000000000002',
    'c0000000-0000-4000-8000-000000000001',
    'Pan hamburguesa (demo)',
    'und',
    'pieza',
    200,
    20,
    800,
    true
  ),
  (
    '40000000-0000-4000-8000-000000000003',
    'c0000000-0000-4000-8000-000000000001',
    'Papa congelada (demo)',
    'g',
    'peso',
    10000,
    1000,
    0.008,
    true
  )
ON CONFLICT (id) DO UPDATE SET
  stock_actual = EXCLUDED.stock_actual,
  costo_unitario_actual = EXCLUDED.costo_unitario_actual,
  activo = true;

INSERT INTO recetas (id, sucursal_id, nombre, rendimiento_porciones)
VALUES
  (
    '41000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'Receta hamburguesa clásica demo',
    1
  ),
  (
    '41000000-0000-4000-8000-000000000002',
    'c0000000-0000-4000-8000-000000000001',
    'Receta papas medianas demo',
    1
  )
ON CONFLICT (id) DO NOTHING;

DELETE FROM receta_items
WHERE receta_id IN (
  '41000000-0000-4000-8000-000000000001',
  '41000000-0000-4000-8000-000000000002'
);

INSERT INTO receta_items (receta_id, tipo_item, ingrediente_id, cantidad, unidad, orden)
VALUES
  (
    '41000000-0000-4000-8000-000000000001',
    'ingrediente',
    '40000000-0000-4000-8000-000000000001',
    150,
    'g',
    1
  ),
  (
    '41000000-0000-4000-8000-000000000001',
    'ingrediente',
    '40000000-0000-4000-8000-000000000002',
    1,
    'und',
    2
  ),
  (
    '41000000-0000-4000-8000-000000000002',
    'ingrediente',
    '40000000-0000-4000-8000-000000000003',
    200,
    'g',
    1
  );

UPDATE productos
SET
  receta_id = '41000000-0000-4000-8000-000000000001',
  costo_calculado = 803.75
WHERE id = 'f0000000-0000-4000-8000-000000000001';

UPDATE productos
SET
  receta_id = '41000000-0000-4000-8000-000000000002',
  costo_calculado = 1.6
WHERE id = 'f0000000-0000-4000-8000-000000000002';

INSERT INTO costos_receta (receta_id, costo_total, costo_por_porcion)
SELECT '41000000-0000-4000-8000-000000000001', 803.75, 803.75
WHERE NOT EXISTS (
  SELECT 1 FROM costos_receta WHERE receta_id = '41000000-0000-4000-8000-000000000001'
);

INSERT INTO costos_receta (receta_id, costo_total, costo_por_porcion)
SELECT '41000000-0000-4000-8000-000000000002', 1.6, 1.6
WHERE NOT EXISTS (
  SELECT 1 FROM costos_receta WHERE receta_id = '41000000-0000-4000-8000-000000000002'
);
