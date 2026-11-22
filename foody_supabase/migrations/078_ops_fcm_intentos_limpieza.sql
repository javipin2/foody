-- OPS: tope reintentos FCM + índice limpieza estados expirados (STOR-01).

ALTER TABLE notificaciones_pendientes
  ADD COLUMN IF NOT EXISTS intentos int NOT NULL DEFAULT 0;

ALTER TABLE notificaciones_pendientes
  ADD COLUMN IF NOT EXISTS abandonada bool NOT NULL DEFAULT false;

COMMENT ON COLUMN notificaciones_pendientes.intentos IS
  'Intentos de envío FCM fallidos; al alcanzar el tope se marca abandonada.';
COMMENT ON COLUMN notificaciones_pendientes.abandonada IS
  'true = dejar de reintentar (tokens inválidos / Admin caído demasiado tiempo).';

CREATE INDEX IF NOT EXISTS idx_notificaciones_pendientes_cola
  ON notificaciones_pendientes (created_at)
  WHERE enviada = false AND abandonada = false;

CREATE INDEX IF NOT EXISTS idx_estados_promociones_expira
  ON estados_promociones (expira_at)
  WHERE expira_at IS NOT NULL;
