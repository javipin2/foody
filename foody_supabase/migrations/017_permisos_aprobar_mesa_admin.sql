-- Admin y gerente pueden aprobar pedidos QR (mesero ya lo tenía)
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('admin', 'aprobar_pedido_mesa'),
  ('gerente', 'aprobar_pedido_mesa')
ON CONFLICT (rol, permiso) DO NOTHING;
