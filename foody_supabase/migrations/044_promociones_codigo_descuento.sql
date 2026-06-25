-- Foody — códigos promocionales aplicables en checkout (C5 auditoría)
ALTER TABLE estados_promociones
  ADD COLUMN IF NOT EXISTS codigo text,
  ADD COLUMN IF NOT EXISTS descuento_porcentaje numeric(5,2),
  ADD COLUMN IF NOT EXISTS descuento_monto numeric(12,2);

CREATE UNIQUE INDEX IF NOT EXISTS idx_promociones_codigo_sucursal
  ON estados_promociones (sucursal_id, lower(trim(codigo)))
  WHERE codigo IS NOT NULL AND trim(codigo) <> '' AND activa = true;

ALTER TABLE pedidos
  ADD COLUMN IF NOT EXISTS promocion_id uuid REFERENCES estados_promociones(id);
