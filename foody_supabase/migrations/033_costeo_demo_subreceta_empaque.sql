-- Foody — Paso 3 Fase 1: demo subreceta, empaques domicilio y costo combo
-- Sucursal demo: c0000000-0000-4000-8000-000000000001

INSERT INTO ingredientes (
  id, sucursal_id, nombre, unidad_base, tipo_costeo,
  stock_actual, stock_minimo, costo_unitario_actual, activo, categoria_insumo
) VALUES
  (
    '40000000-0000-4000-8000-000000000004',
    'c0000000-0000-4000-8000-000000000001',
    'Caja domicilio (demo)',
    'und',
    'pieza',
    500,
    50,
    350,
    true,
    'empaque'
  ),
  (
    '40000000-0000-4000-8000-000000000005',
    'c0000000-0000-4000-8000-000000000001',
    'Bolsa térmica (demo)',
    'und',
    'pieza',
    500,
    50,
    150,
    true,
    'empaque'
  )
ON CONFLICT (id) DO UPDATE SET
  stock_actual = EXCLUDED.stock_actual,
  costo_unitario_actual = EXCLUDED.costo_unitario_actual,
  categoria_insumo = EXCLUDED.categoria_insumo,
  activo = true;

INSERT INTO recetas (
  id, sucursal_id, nombre, tipo, margen_error,
  cantidad_resultado, unidad_resultado, rendimiento_porciones
) VALUES (
  '41000000-0000-4000-8000-000000000010',
  'c0000000-0000-4000-8000-000000000001',
  'Preparación carne demo',
  'subreceta',
  0.05,
  150,
  'g',
  1
)
ON CONFLICT (id) DO UPDATE SET
  tipo = 'subreceta',
  cantidad_resultado = EXCLUDED.cantidad_resultado,
  unidad_resultado = EXCLUDED.unidad_resultado;

DELETE FROM receta_items
WHERE receta_id = '41000000-0000-4000-8000-000000000010';

INSERT INTO receta_items (receta_id, tipo_item, ingrediente_id, cantidad, unidad, orden)
VALUES (
  '41000000-0000-4000-8000-000000000010',
  'ingrediente',
  '40000000-0000-4000-8000-000000000001',
  160,
  'g',
  1
);

UPDATE recetas SET tipo = 'producto' WHERE id IN (
  '41000000-0000-4000-8000-000000000001',
  '41000000-0000-4000-8000-000000000002'
);

DELETE FROM receta_items
WHERE receta_id = '41000000-0000-4000-8000-000000000001';

INSERT INTO receta_items (receta_id, tipo_item, ingrediente_id, subreceta_id, cantidad, unidad, orden)
VALUES
  (
    '41000000-0000-4000-8000-000000000001',
    'subreceta',
    NULL,
    '41000000-0000-4000-8000-000000000010',
    150,
    'g',
    1
  ),
  (
    '41000000-0000-4000-8000-000000000001',
    'ingrediente',
    '40000000-0000-4000-8000-000000000002',
    NULL,
    1,
    'und',
    2
  ),
  (
    '41000000-0000-4000-8000-000000000001',
    'empaque',
    '40000000-0000-4000-8000-000000000004',
    NULL,
    1,
    'und',
    3
  ),
  (
    '41000000-0000-4000-8000-000000000001',
    'empaque',
    '40000000-0000-4000-8000-000000000005',
    NULL,
    1,
    'und',
    4
  );

UPDATE combos
SET costo_empaque_extra = 0
WHERE id = '30000000-0000-4000-8000-000000000001';
