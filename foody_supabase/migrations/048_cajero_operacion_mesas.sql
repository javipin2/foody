-- Cajero: operación POS (ver mesas, cobrar, retiro en turno propio)
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('cajero', 'ver_mesas'),
  ('cajero', 'hacer_retiro_parcial')
ON CONFLICT (rol, permiso) DO NOTHING;
