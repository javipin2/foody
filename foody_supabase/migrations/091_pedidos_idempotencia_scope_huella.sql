BEGIN;

ALTER TABLE pedidos_idempotencia
  ADD COLUMN IF NOT EXISTS sucursal_id uuid REFERENCES sucursales(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS huella text;

UPDATE pedidos_idempotencia i
SET sucursal_id = p.sucursal_id
FROM pedidos p
WHERE p.id = i.pedido_id
  AND i.sucursal_id IS NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pedidos_idempotencia WHERE sucursal_id IS NULL
  ) THEN
    RAISE EXCEPTION 'No se pudo asignar sucursal a todas las claves idempotentes';
  END IF;
END $$;

ALTER TABLE pedidos_idempotencia
  ALTER COLUMN sucursal_id SET NOT NULL;
ALTER TABLE pedidos_idempotencia
  DROP CONSTRAINT IF EXISTS pedidos_idempotencia_pkey;
ALTER TABLE pedidos_idempotencia
  ADD CONSTRAINT pedidos_idempotencia_pkey PRIMARY KEY (sucursal_id, clave);
REVOKE ALL ON TABLE pedidos_idempotencia FROM anon, authenticated;
ALTER TABLE pedidos_idempotencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos_idempotencia FORCE ROW LEVEL SECURITY;

COMMIT;
