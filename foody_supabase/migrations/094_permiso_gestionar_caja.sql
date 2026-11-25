-- Separar visibilidad de Caja de las escrituras monetarias operativas.
-- Conserva el acceso que hoy tienen los roles de operación conocidos.
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('admin', 'gestionar_caja'),
  ('gerente', 'gestionar_caja'),
  ('gerente_cadena', 'gestionar_caja'),
  ('cajero', 'gestionar_caja')
ON CONFLICT (rol, permiso) DO NOTHING;
