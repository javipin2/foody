-- Permisos personalizados por usuario (override del rol).
-- Si el usuario NO tiene filas aquí → se usan roles_permisos del rol.
-- Si tiene ≥1 fila → esa lista es la efectiva (JWT / RolGuard).

CREATE TABLE IF NOT EXISTS usuario_permisos (
  usuario_id uuid NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  permiso text NOT NULL,
  PRIMARY KEY (usuario_id, permiso)
);

CREATE INDEX IF NOT EXISTS idx_usuario_permisos_usuario
  ON usuario_permisos (usuario_id);
