-- Gaseosa vendible en categoría Bebidas (POS mostraba chip vacío: solo existía como extra).
INSERT INTO productos (id, sucursal_id, categoria_id, cocina_id, nombre, descripcion, precio, disponible, orden)
VALUES (
  'f0000000-0000-4000-8000-000000000003',
  'c0000000-0000-4000-8000-000000000001',
  'e0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000001',
  'Gaseosa 400ml',
  'Bebida lista para vender sola o en combo',
  4000,
  true,
  1
)
ON CONFLICT (id) DO NOTHING;
