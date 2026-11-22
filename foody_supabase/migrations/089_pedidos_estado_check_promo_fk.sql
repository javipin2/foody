-- PED-CHECK-01: estados de pedido acotados en Postgres.
-- PROMO-DEL-01: borrar promo no rompe pedidos (SET NULL).

ALTER TABLE pedidos DROP CONSTRAINT IF EXISTS pedidos_estado_check;
ALTER TABLE pedidos
  ADD CONSTRAINT pedidos_estado_check CHECK (estado IN (
    'pendiente_aprobacion',
    'pendiente',
    'confirmado',
    'en_cocina',
    'listo',
    'pagando',
    'asignado',
    'en_camino',
    'entregado',
    'pagado',
    'cancelado',
    'rechazado'
  ));

DO $$
DECLARE
  fk_pedidos text;
BEGIN
  SELECT conname INTO fk_pedidos
  FROM pg_constraint
  WHERE conrelid = 'pedidos'::regclass
    AND contype = 'f'
    AND pg_get_constraintdef(oid) ILIKE '%promocion_id%';
  IF fk_pedidos IS NOT NULL THEN
    EXECUTE format('ALTER TABLE pedidos DROP CONSTRAINT %I', fk_pedidos);
  END IF;
END $$;

ALTER TABLE pedidos
  ADD CONSTRAINT pedidos_promocion_id_fkey
  FOREIGN KEY (promocion_id) REFERENCES estados_promociones(id) ON DELETE SET NULL;
