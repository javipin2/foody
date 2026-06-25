-- Demo sucursal: alinear movimientos_caja con pedidos (cuadre reportes I7).
-- Elimina ventas de pedidos cancelados/rechazados (legacy pre-fix C2),
-- corrige montos y backfill para entregado/pagado sin movimiento.

-- 1) Ventas ligadas a pedidos cancelados o rechazados
DELETE FROM movimientos_caja m
USING pedidos p
WHERE m.pedido_id = p.id
  AND m.tipo = 'venta'
  AND p.estado IN ('cancelado', 'rechazado')
  AND m.sucursal_id = 'c0000000-0000-4000-8000-000000000001';

-- 2) Ventas sin pedido (huérfanas)
DELETE FROM movimientos_caja
WHERE tipo = 'venta'
  AND pedido_id IS NULL
  AND sucursal_id = 'c0000000-0000-4000-8000-000000000001';

-- 3) Monto distinto al total del pedido
UPDATE movimientos_caja m
SET monto = p.total
FROM pedidos p
WHERE m.pedido_id = p.id
  AND m.tipo = 'venta'
  AND m.monto IS DISTINCT FROM p.total
  AND m.sucursal_id = 'c0000000-0000-4000-8000-000000000001';

-- 4) Backfill: entregado/pagado sin movimiento de venta
INSERT INTO movimientos_caja (
  caja_id, sucursal_id, pedido_id, tipo, monto, metodo_pago, descripcion
)
SELECT
  c.id,
  p.sucursal_id,
  p.id,
  'venta',
  p.total,
  CASE
    WHEN p.metodo_pago IN ('efectivo', 'tarjeta', 'transferencia', 'nequi')
      THEN p.metodo_pago
    ELSE 'efectivo'
  END,
  'Backfill demo cuadre caja (migración 046)'
FROM pedidos p
CROSS JOIN LATERAL (
  SELECT id FROM cajas
  WHERE sucursal_id = p.sucursal_id
  ORDER BY CASE WHEN estado = 'abierta' THEN 0 ELSE 1 END, apertura_at DESC
  LIMIT 1
) c
WHERE p.sucursal_id = 'c0000000-0000-4000-8000-000000000001'
  AND p.estado IN ('entregado', 'pagado')
  AND NOT EXISTS (
    SELECT 1 FROM movimientos_caja m
    WHERE m.pedido_id = p.id AND m.tipo = 'venta'
  );

-- 5) Backfill: alinear fecha del movimiento con el pedido (cuadre por período)
UPDATE movimientos_caja m
SET created_at = p.created_at
FROM pedidos p
WHERE m.pedido_id = p.id
  AND m.tipo = 'venta'
  AND m.sucursal_id = 'c0000000-0000-4000-8000-000000000001'
  AND m.created_at::date <> p.created_at::date;
