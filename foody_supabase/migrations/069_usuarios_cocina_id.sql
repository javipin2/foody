-- Staff de cocina: usuario ligado a una estación (KDS solo ve esa cocina).
ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS cocina_id uuid REFERENCES cocinas(id);

CREATE INDEX IF NOT EXISTS idx_usuarios_cocina_id
  ON usuarios (cocina_id)
  WHERE cocina_id IS NOT NULL;

INSERT INTO roles_permisos (rol, permiso) VALUES
  ('cocina', 'ver_cocina')
ON CONFLICT (rol, permiso) DO NOTHING;

-- Demo: unificar rol genérico `cocina` + estación principal.
UPDATE usuarios SET
  rol = 'cocina',
  cocina_id = 'd0000000-0000-4000-8000-000000000001'
WHERE LOWER(email) = 'cocina@foody.demo';
