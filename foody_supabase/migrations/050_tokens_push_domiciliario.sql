-- Tokens FCM para domiciliarios independientes (JWT sub = domiciliarios_independientes.id)
CREATE TABLE IF NOT EXISTS tokens_push_domiciliario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domiciliario_id uuid NOT NULL REFERENCES domiciliarios_independientes(id) ON DELETE CASCADE,
  fcm_token text NOT NULL,
  plataforma text,
  activo bool NOT NULL DEFAULT true,
  updated_at timestamptz DEFAULT now(),
  UNIQUE (domiciliario_id, fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_tokens_push_domiciliario_activo
  ON tokens_push_domiciliario (domiciliario_id) WHERE activo = true;
