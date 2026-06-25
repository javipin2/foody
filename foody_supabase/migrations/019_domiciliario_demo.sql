-- Domiciliario de planta demo (contraseña: 123456) + permisos rol
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('domiciliario_planta', 'ver_pedidos')
ON CONFLICT (rol, permiso) DO NOTHING;

INSERT INTO usuarios (
  id,
  sucursal_id,
  restaurante_id,
  nombre,
  email,
  rol,
  activo,
  hash_contrasena
) VALUES (
  '91000000-0000-4000-8000-000000000001',
  'c0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  'Domi Demo',
  'domi@foody.demo',
  'domiciliario_planta',
  true,
  '$2b$10$w22qWYXW6xIIyhxS5XTjX.LzPEXiezmOu03cocn6OgJmxnghqIe2.'
)
ON CONFLICT (email) DO UPDATE SET
  hash_contrasena = EXCLUDED.hash_contrasena,
  activo = true,
  rol = 'domiciliario_planta',
  sucursal_id = EXCLUDED.sucursal_id;

INSERT INTO domiciliarios_planta (id, usuario_id, sucursal_id, activo)
VALUES (
  '92000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000001',
  'c0000000-0000-4000-8000-000000000001',
  true
)
ON CONFLICT (id) DO UPDATE SET activo = true;
