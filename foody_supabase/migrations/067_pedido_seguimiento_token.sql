-- RT-9: canal pedido_{id}_{token} — solo quien creó el pedido o tiene el token puede seguir RT
ALTER TABLE pedidos
  ADD COLUMN IF NOT EXISTS seguimiento_token uuid NOT NULL DEFAULT gen_random_uuid();

CREATE UNIQUE INDEX IF NOT EXISTS pedidos_seguimiento_token_idx
  ON pedidos (seguimiento_token);
