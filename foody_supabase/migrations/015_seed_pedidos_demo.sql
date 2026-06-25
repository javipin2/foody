-- Pedidos demo para probar kanban admin
INSERT INTO pedidos (
  id, sucursal_id, numero_pedido, tipo, estado, cliente_nombre,
  cliente_telefono, metodo_pago, subtotal, total
) VALUES
  (
    'a1000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'FDY-2026-0001',
    'para_llevar',
    'pendiente',
    'Cliente Demo 1',
    '3001111111',
    'efectivo',
    18000,
    18000
  ),
  (
    'a1000000-0000-4000-8000-000000000002',
    'c0000000-0000-4000-8000-000000000001',
    'FDY-2026-0002',
    'domicilio',
    'confirmado',
    'Cliente Demo 2',
    '3002222222',
    'nequi',
    26000,
    26000
  ),
  (
    'a1000000-0000-4000-8000-000000000003',
    'c0000000-0000-4000-8000-000000000001',
    'FDY-2026-0003',
    'mesa',
    'en_cocina',
    'Mesa 1',
    NULL,
    'pendiente',
    8000,
    8000
  )
ON CONFLICT (id) DO NOTHING;
