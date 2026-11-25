-- Secreto independiente del identificador público para autorizar al cliente invitado.
-- El valor original solo vive en el dispositivo; la BD conserva SHA-256.
ALTER TABLE dispositivos_cliente
  ADD COLUMN IF NOT EXISTS capability_hash char(64);

COMMENT ON COLUMN dispositivos_cliente.capability_hash IS
  'SHA-256 de la capability secreta del cliente. Nunca almacenar el secreto original.';
