-- F1: API-IDEM-03 (una caja abierta por sucursal) + API-IDEM-02 (idempotencia cobro)

CREATE UNIQUE INDEX IF NOT EXISTS uq_caja_abierta_sucursal
  ON cajas (sucursal_id)
  WHERE estado = 'abierta';

CREATE TABLE IF NOT EXISTS cobros_idempotencia (
  clave text PRIMARY KEY,
  sucursal_id uuid NOT NULL REFERENCES sucursales(id),
  resultado jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cobros_idempotencia_created
  ON cobros_idempotencia (created_at);
