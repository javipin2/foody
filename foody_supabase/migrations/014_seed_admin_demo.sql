-- Usuario admin demo (contraseña: 123456)
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
  '90000000-0000-4000-8000-000000000001',
  'c0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  'Admin Demo',
  'admin@foody.demo',
  'admin',
  true,
  '$2b$10$w22qWYXW6xIIyhxS5XTjX.LzPEXiezmOu03cocn6OgJmxnghqIe2.'
)
ON CONFLICT (email) DO UPDATE SET
  hash_contrasena = EXCLUDED.hash_contrasena,
  activo = true,
  rol = 'admin';
