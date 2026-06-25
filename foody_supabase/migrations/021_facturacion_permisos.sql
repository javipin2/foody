-- Foody — facturación: vínculo pedido ↔ factura, permisos y config demo
ALTER TABLE pedidos
  ADD COLUMN IF NOT EXISTS factura_id uuid REFERENCES facturas(id);

INSERT INTO roles_permisos (rol, permiso) VALUES
  ('admin', 'gestionar_facturacion'),
  ('admin', 'ver_facturacion'),
  ('gerente', 'gestionar_facturacion'),
  ('gerente', 'ver_facturacion'),
  ('cajero', 'ver_facturacion')
ON CONFLICT (rol, permiso) DO NOTHING;

INSERT INTO configuracion_fiscal_sucursal (
  sucursal_id, nit, razon_social, regimen, aplica_iva,
  porcentaje_iva, resolucion_dian, prefijo_factura, consecutivo_actual
) VALUES (
  'c0000000-0000-4000-8000-000000000001',
  '900123456',
  'Foody Demo Centro SAS',
  'comun',
  true,
  19,
  '18764000001234',
  'FE',
  0
) ON CONFLICT (sucursal_id) DO NOTHING;
