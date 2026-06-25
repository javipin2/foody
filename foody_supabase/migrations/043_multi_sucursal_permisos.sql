-- Foody — Fase 1 multi-sucursal: permiso lectura inventario entre sedes hermanas
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('admin', 'ver_inventario_otras_sucursales'),
  ('gerente', 'ver_inventario_otras_sucursales')
ON CONFLICT (rol, permiso) DO NOTHING;
