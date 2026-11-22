-- Foody — fuentes de pago Wompi para renovación automática (P1-10)

CREATE TABLE fuentes_pago (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurante_id uuid NOT NULL REFERENCES restaurantes(id) ON DELETE CASCADE,
  wompi_payment_source_id text NOT NULL,
  tipo text NOT NULL DEFAULT 'CARD'
    CHECK (tipo IN ('CARD', 'NEQUI', 'BANCOLOMBIA_TRANSFER', 'OTRO')),
  estado_wompi text,
  ultimos_cuatro text,
  marca text,
  customer_email text,
  activa boolean NOT NULL DEFAULT true,
  ultimo_cobro_at timestamptz,
  ultimo_intento_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (restaurante_id, wompi_payment_source_id)
);

CREATE UNIQUE INDEX fuentes_pago_restaurante_activa_idx
  ON fuentes_pago (restaurante_id)
  WHERE activa = true;

CREATE INDEX fuentes_pago_wompi_id_idx
  ON fuentes_pago (wompi_payment_source_id);
