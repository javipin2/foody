-- AUTH-FLOW / AUTH-REV: invalidar JWT al logout o cambio de contraseña.
-- Claim JWT `tv` debe coincidir con esta columna (UsuarioActivoGuard).

ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS token_version integer NOT NULL DEFAULT 1;

ALTER TABLE domiciliarios_independientes
  ADD COLUMN IF NOT EXISTS token_version integer NOT NULL DEFAULT 1;

COMMENT ON COLUMN usuarios.token_version IS
  'AUTH: incrementa en logout / cambio password; JWT claim tv debe coincidir';
COMMENT ON COLUMN domiciliarios_independientes.token_version IS
  'AUTH: incrementa en logout; JWT claim tv debe coincidir';
