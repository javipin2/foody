-- Mesero puede crear pedidos en mesa (POS mesero / tap mesa libre)
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('mesero', 'crear_pedido')
ON CONFLICT (rol, permiso) DO NOTHING;
