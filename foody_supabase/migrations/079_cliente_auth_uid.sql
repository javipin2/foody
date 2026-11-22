-- Cliente consumidor: vincular device_id ↔ auth.users (Google) para historial en la nube.
-- No es staff (usuarios); solo Supabase Auth UID del comensal.

ALTER TABLE dispositivos_cliente
  ADD COLUMN IF NOT EXISTS auth_uid uuid;

COMMENT ON COLUMN dispositivos_cliente.auth_uid IS
  'auth.users.id de Supabase cuando el cliente inicia sesión (Google). Null = anónimo por device.';

CREATE INDEX IF NOT EXISTS idx_dispositivos_cliente_auth_uid
  ON dispositivos_cliente (auth_uid)
  WHERE auth_uid IS NOT NULL;

ALTER TABLE pedidos
  ADD COLUMN IF NOT EXISTS cliente_auth_uid uuid;

COMMENT ON COLUMN pedidos.cliente_auth_uid IS
  'UID Supabase del comensal (opcional). Permite listar pedidos tras cambiar de dispositivo.';

CREATE INDEX IF NOT EXISTS idx_pedidos_cliente_auth_uid
  ON pedidos (cliente_auth_uid)
  WHERE cliente_auth_uid IS NOT NULL;
