-- Pedido mesa pendiente de aprobación (demo mesero)
INSERT INTO pedidos (
  id, sucursal_id, mesa_id, numero_pedido, tipo, estado,
  cliente_nombre, metodo_pago, subtotal, total
) VALUES (
  'a1000000-0000-4000-8000-000000000004',
  'c0000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  'FDY-2026-0004',
  'mesa',
  'pendiente_aprobacion',
  'Cliente QR Mesa 1',
  'pendiente',
  18000,
  18000
)
ON CONFLICT (id) DO NOTHING;
