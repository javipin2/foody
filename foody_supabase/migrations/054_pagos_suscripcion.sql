-- Foody — pagos de suscripción (Wompi F5)

CREATE TABLE pagos_suscripcion (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurante_id uuid NOT NULL REFERENCES restaurantes(id),
  usuario_id uuid REFERENCES usuarios(id),
  plan text NOT NULL CHECK (plan IN ('basico', 'pro', 'enterprise')),
  monto_centavos integer NOT NULL,
  moneda text NOT NULL DEFAULT 'COP',
  estado text NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'aprobado', 'rechazado', 'error')),
  metodo text,
  referencia_interna text NOT NULL UNIQUE,
  payment_link_id text,
  transaccion_wompi_id text UNIQUE,
  referencia_wompi text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX pagos_suscripcion_restaurante_idx
  ON pagos_suscripcion (restaurante_id, created_at DESC);

CREATE INDEX pagos_suscripcion_payment_link_idx
  ON pagos_suscripcion (payment_link_id)
  WHERE payment_link_id IS NOT NULL;
