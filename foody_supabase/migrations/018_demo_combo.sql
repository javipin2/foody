-- Demo combo para desarrollo
INSERT INTO combos (id, sucursal_id, nombre, descripcion, precio_fijo, disponible) VALUES
  (
    '30000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'Combo clásico',
    'Hamburguesa + papas + gaseosa',
    25000,
    true
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO combo_items (combo_id, tipo_item, item_id, cantidad) VALUES
  ('30000000-0000-4000-8000-000000000001', 'producto', 'f0000000-0000-4000-8000-000000000001', 1),
  ('30000000-0000-4000-8000-000000000001', 'producto', 'f0000000-0000-4000-8000-000000000002', 1),
  ('30000000-0000-4000-8000-000000000001', 'bebida', '10000000-0000-4000-8000-000000000001', 1)
ON CONFLICT DO NOTHING;
