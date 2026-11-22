-- F2: RBAC-MESERO — cobro solo cajero/admin/gerente (no mesero)
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('admin', 'cobrar_pedido'),
  ('gerente', 'cobrar_pedido'),
  ('cajero', 'cobrar_pedido')
ON CONFLICT (rol, permiso) DO NOTHING;
