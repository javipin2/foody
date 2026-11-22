-- P1-08 QA analítica: segunda sede + gerente de sede (sin alcance corporativo).

INSERT INTO sucursales (id, restaurante_id, ciudad_id, nombre, direccion, activa) VALUES
  (
    'c0000000-0000-4000-8000-000000000002',
    'b0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    'Sede Norte',
    'Av. Fundación #12-34, Valledupar',
    true
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO horarios_sucursal (sucursal_id, dia_semana, hora_apertura, hora_cierre, activo)
SELECT 'c0000000-0000-4000-8000-000000000002', d, '08:00', '22:00', true
FROM generate_series(0, 6) AS d
ON CONFLICT DO NOTHING;

INSERT INTO usuarios (
  id, sucursal_id, restaurante_id, nombre, email, rol, activo, hash_contrasena
) VALUES (
  '90000000-0000-4000-8000-000000000002',
  'c0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  'Gerente Sede Demo',
  'gerente@foody.demo',
  'gerente',
  true,
  '$2b$10$w22qWYXW6xIIyhxS5XTjX.LzPEXiezmOu03cocn6OgJmxnghqIe2.'
)
ON CONFLICT (email) DO UPDATE SET
  rol = 'gerente',
  sucursal_id = EXCLUDED.sucursal_id,
  hash_contrasena = EXCLUDED.hash_contrasena,
  activo = true;
