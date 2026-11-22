-- Detalle de jobs de impresión cocina (reintentos, simulado sin hardware)
ALTER TABLE impresion_cocina_jobs
  ADD COLUMN IF NOT EXISTS intentos int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ultimo_error text,
  ADD COLUMN IF NOT EXISTS simulado bool NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS procesado_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_impresion_jobs_pendiente
  ON impresion_cocina_jobs (created_at)
  WHERE estado = 'pendiente';
