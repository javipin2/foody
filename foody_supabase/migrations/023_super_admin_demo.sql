-- Super admin demo + permisos rol
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('super_admin', 'ver_dashboard'),
  ('super_admin', 'ver_pedidos'),
  ('super_admin', 'gestionar_sucursales'),
  ('super_admin', 'gestionar_usuarios')
ON CONFLICT (rol, permiso) DO NOTHING;

INSERT INTO usuarios (
  id, nombre, email, rol, activo, hash_contrasena
) VALUES (
  '91300000-0000-4000-8000-000000000001',
  'Super Admin Foody',
  'super@foody.demo',
  'super_admin',
  true,
  '$2b$10$w22qWYXW6xIIyhxS5XTjX.LzPEXiezmOu03cocn6OgJmxnghqIe2.'
) ON CONFLICT (email) DO UPDATE SET
  rol = 'super_admin',
  hash_contrasena = EXCLUDED.hash_contrasena,
  activo = true;
