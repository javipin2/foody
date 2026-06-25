-- Foody — Bloque 1: cocinas, impresoras y KDS
-- Permiso ver_cocina para que admin/gerente puedan abrir el panel de cocina (KDS).
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('admin', 'ver_cocina'),
  ('gerente', 'ver_cocina')
ON CONFLICT (rol, permiso) DO NOTHING;

-- Impresora demo asignada a la cocina principal (seed 012).
INSERT INTO impresoras (id, sucursal_id, cocina_id, nombre, ip_local, tipo, activa) VALUES
  (
    '40000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000001',
    'Impresora cocina principal',
    '192.168.1.50',
    'termica_red',
    true
  )
ON CONFLICT (id) DO NOTHING;

-- Usuario de cocina demo (contraseña: 123456). Rol cocina_principal → dashboard 'cocina'.
INSERT INTO usuarios (
  id, sucursal_id, restaurante_id, nombre, email, rol, activo, hash_contrasena
) VALUES (
  '90000000-0000-4000-8000-0000000000c1',
  'c0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  'Cocina Demo',
  'cocina@foody.demo',
  'cocina_principal',
  true,
  '$2b$10$w22qWYXW6xIIyhxS5XTjX.LzPEXiezmOu03cocn6OgJmxnghqIe2.'
)
ON CONFLICT (email) DO UPDATE SET
  hash_contrasena = EXCLUDED.hash_contrasena,
  activo = true,
  rol = 'cocina_principal';
