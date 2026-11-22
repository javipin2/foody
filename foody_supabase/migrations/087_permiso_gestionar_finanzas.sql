-- SEC-BAC-06: mutaciones finanzas ≠ permiso write dedicado (lectura sigue con ver_finanzas).
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('admin', 'gestionar_finanzas'),
  ('gerente', 'gestionar_finanzas'),
  ('gerente_cadena', 'gestionar_finanzas')
ON CONFLICT (rol, permiso) DO NOTHING;
