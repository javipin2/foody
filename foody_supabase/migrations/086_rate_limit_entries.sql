-- Rate limit multi-réplica (AQ-SCALE-02/05)
-- Guarda contadores por clave (IP+method+path) con ventana móvil por endpoint.

CREATE TABLE IF NOT EXISTS rate_limit_entries (
  clave text PRIMARY KEY,
  ventana_ms integer NOT NULL,
  reinicio_at timestamptz NOT NULL,
  cuenta integer NOT NULL,
  actualizado_at timestamptz NOT NULL DEFAULT now()
);

