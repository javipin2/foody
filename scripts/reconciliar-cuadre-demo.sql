-- Reconcilia demo: ventas huérfanas en pedidos cancelados/rechazados y exceso por pedido.
-- Ejecutar antes de verificar-cuadre-caja en entornos de QA con data histórica.

-- 1) Ventas en pedidos cancelados/rechazados (deben haberse revertido al cancelar)
DELETE FROM movimientos_caja m
WHERE m.tipo = 'venta'
  AND m.pedido_id IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM pedidos p
    WHERE p.id = m.pedido_id
      AND p.estado IN ('cancelado', 'rechazado')
  );

-- 2) Exceso SUM(ventas) > total (mismo bloque que domicilios)
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

-- 3) Alinear monto_pagado con ventas registradas (entregado/pagado)
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
