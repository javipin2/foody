-- Foody — datos demo para desarrollo
INSERT INTO ciudades (id, nombre, slug, activa) VALUES
  ('a0000000-0000-4000-8000-000000000001', 'Valledupar', 'valledupar', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO restaurantes (id, ciudad_id, nombre, descripcion, activo) VALUES
  (
    'b0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    'Foody Demo Restaurante',
    'Restaurante de prueba para desarrollo',
    true
  )
ON CONFLICT DO NOTHING;

INSERT INTO sucursales (id, restaurante_id, ciudad_id, nombre, direccion, activa) VALUES
  (
    'c0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    'Sede Centro',
    'Calle 19 #5-20, Valledupar',
    true
  )
ON CONFLICT DO NOTHING;

INSERT INTO horarios_sucursal (sucursal_id, dia_semana, hora_apertura, hora_cierre, activo)
SELECT 'c0000000-0000-4000-8000-000000000001', d, '08:00', '22:00', true
FROM generate_series(0, 6) AS d
ON CONFLICT DO NOTHING;

INSERT INTO cocinas (id, sucursal_id, nombre) VALUES
  ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'Cocina principal')
ON CONFLICT DO NOTHING;

INSERT INTO categorias (id, sucursal_id, nombre, orden, activa) VALUES
  ('e0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'Platos fuertes', 1, true),
  ('e0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', 'Bebidas', 2, true)
ON CONFLICT DO NOTHING;

INSERT INTO productos (id, sucursal_id, categoria_id, cocina_id, nombre, descripcion, precio, disponible, orden) VALUES
  (
    'f0000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000001',
    'Hamburguesa clásica',
    'Carne, queso, lechuga y salsa especial',
    18000,
    true,
    1
  ),
  (
    'f0000000-0000-4000-8000-000000000002',
    'c0000000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000001',
    'Papas medianas',
    'Porción mediana crujiente',
    8000,
    true,
    2
  )
ON CONFLICT DO NOTHING;

INSERT INTO bebidas (id, sucursal_id, nombre, precio, disponible) VALUES
  ('10000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'Gaseosa 400ml', 4000, true)
ON CONFLICT DO NOTHING;

INSERT INTO toppings (id, sucursal_id, nombre, precio, disponible) VALUES
  ('20000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'Queso extra', 2500, true)
ON CONFLICT DO NOTHING;

INSERT INTO producto_toppings (producto_id, topping_id) VALUES
  ('f0000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO producto_bebidas (producto_id, bebida_id) VALUES
  ('f0000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO suscripciones_restaurante (restaurante_id, estado, plan, fecha_vencimiento) VALUES
  (
    'b0000000-0000-4000-8000-000000000001',
    'activa',
    'basico',
    now() + interval '365 days'
  )
ON CONFLICT (restaurante_id) DO NOTHING;

INSERT INTO mesas (id, sucursal_id, nombre, qr_token) VALUES
  ('30000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'Mesa 1', 'demo-mesa-1')
ON CONFLICT DO NOTHING;
