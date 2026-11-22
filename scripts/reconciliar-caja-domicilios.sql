-- Reconcilia ventas duplicadas/exceso en caja.
-- 1) Domicilio: quita venta al crear si ya hay cobro de entrega.
-- 2) General: elimina ventas más recientes mientras SUM(ventas) > total del pedido.

DELETE FROM movimientos_caja m
WHERE m.id IN (
  SELECT m2.id
  FROM movimientos_caja m2
  JOIN pedidos p ON p.id = m2.pedido_id
  WHERE m2.tipo = 'venta'
    AND m2.descripcion LIKE 'Venta %'
    AND EXISTS (
      SELECT 1 FROM movimientos_caja m3
      WHERE m3.pedido_id = m2.pedido_id
        AND m3.tipo = 'venta'
        AND m3.descripcion LIKE 'Domicilio entregado%'
    )
);

DO $$
DECLARE
  r RECORD;
  exceso numeric;
  mov RECORD;
BEGIN
  LOOP
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM pedidos p
      JOIN movimientos_caja m ON m.pedido_id = p.id AND m.tipo = 'venta'
      GROUP BY p.id, p.total
      HAVING SUM(m.monto) > p.total + 0.01
    );
    FOR r IN
      SELECT p.id AS pedido_id, p.total::numeric AS total_pedido,
             COALESCE(SUM(m.monto), 0) AS suma
      FROM pedidos p
      JOIN movimientos_caja m ON m.pedido_id = p.id AND m.tipo = 'venta'
      GROUP BY p.id, p.total
      HAVING COALESCE(SUM(m.monto), 0) > p.total + 0.01
    LOOP
      exceso := r.suma - r.total_pedido;
      FOR mov IN
        SELECT id, monto FROM movimientos_caja
        WHERE pedido_id = r.pedido_id AND tipo = 'venta'
        ORDER BY created_at DESC
      LOOP
        EXIT WHEN exceso <= 0.01;
        DELETE FROM movimientos_caja WHERE id = mov.id;
        exceso := exceso - mov.monto;
      END LOOP;
    END LOOP;
  END LOOP;
END $$;

UPDATE pedidos p
SET monto_pagado = LEAST(p.total, sub.suma)
FROM (
  SELECT pedido_id, COALESCE(SUM(monto), 0) AS suma
  FROM movimientos_caja
  WHERE tipo = 'venta' AND pedido_id IS NOT NULL
  GROUP BY pedido_id
) sub
WHERE p.id = sub.pedido_id
  AND p.estado IN ('entregado', 'pagado')
  AND ABS(COALESCE(p.monto_pagado, 0) - LEAST(sub.suma, p.total)) > 0.01;
