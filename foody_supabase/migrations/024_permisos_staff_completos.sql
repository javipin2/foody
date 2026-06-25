-- Asegura permisos críticos de pedidos/mesas para staff demo (idempotente)
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('admin', 'aprobar_pedido_mesa'),
  ('gerente', 'aprobar_pedido_mesa'),
  ('admin', 'ver_facturacion'),
  ('admin', 'gestionar_facturacion'),
  ('gerente', 'ver_facturacion')
ON CONFLICT (rol, permiso) DO NOTHING;
