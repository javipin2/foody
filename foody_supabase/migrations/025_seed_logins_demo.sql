-- Usuarios demo login (contraseña: 123456) — idempotente
-- Hash: bcrypt 123456

INSERT INTO usuarios (
  id, sucursal_id, restaurante_id, nombre, email, rol, activo, hash_contrasena
) VALUES (
  '91300000-0000-4000-8000-000000000001',
  NULL,
  NULL,
  'Super Admin Foody',
  'super@foody.demo',
  'super_admin',
  true,
  '$2b$10$w22qWYXW6xIIyhxS5XTjX.LzPEXiezmOu03cocn6OgJmxnghqIe2.'
) ON CONFLICT (email) DO UPDATE SET
  rol = 'super_admin',
  hash_contrasena = EXCLUDED.hash_contrasena,
  activo = true;

INSERT INTO roles_permisos (rol, permiso) VALUES
  ('super_admin', 'ver_dashboard'),
  ('super_admin', 'ver_pedidos'),
  ('super_admin', 'gestionar_sucursales'),
  ('super_admin', 'gestionar_usuarios')
ON CONFLICT (rol, permiso) DO NOTHING;

ALTER TABLE domiciliarios_independientes
  ADD COLUMN IF NOT EXISTS hash_contrasena text;

INSERT INTO domiciliarios_independientes (
  id, nombre, email, telefono, tipo_vehiculo, placa,
  ciudad_id, estado_cuenta, hash_contrasena, calificacion_promedio, total_entregas
) VALUES (
  'a1000000-0000-4000-8000-000000000001',
  'Carlos Repartidor Demo',
  'repartidor@foody.demo',
  '3007654321',
  'moto',
  'ABC123',
  'a0000000-0000-4000-8000-000000000001',
  'activo',
  '$2b$10$w22qWYXW6xIIyhxS5XTjX.LzPEXiezmOu03cocn6OgJmxnghqIe2.',
  4.80,
  25
) ON CONFLICT (email) DO UPDATE SET
  hash_contrasena = EXCLUDED.hash_contrasena,
  estado_cuenta = 'activo',
  ciudad_id = EXCLUDED.ciudad_id;

-- domi@foody.demo: ver migración 019 (no duplicar id con super)
