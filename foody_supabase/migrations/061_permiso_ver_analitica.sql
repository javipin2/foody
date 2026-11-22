-- P1-03: permiso Centro de Análisis (mismos roles que ver_reportes + gerente_cadena).
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('admin', 'ver_analitica'),
  ('gerente', 'ver_analitica'),
  ('gerente_cadena', 'ver_analitica'),
  ('cajero', 'ver_analitica')
ON CONFLICT (rol, permiso) DO NOTHING;
