-- Foody — avisos de vencimiento de suscripción (F4 self-service)

ALTER TABLE suscripciones_restaurante
  ADD COLUMN IF NOT EXISTS aviso_3d_enviado_at timestamptz;

ALTER TABLE suscripciones_restaurante
  ADD COLUMN IF NOT EXISTS aviso_vence_hoy_enviado_at timestamptz;
