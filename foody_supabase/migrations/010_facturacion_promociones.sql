-- Foody — facturación y promociones
CREATE TABLE configuracion_fiscal_sucursal (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id) UNIQUE,
  nit text,
  razon_social text,
  regimen text CHECK (regimen IN ('simplificado', 'comun')),
  aplica_iva bool DEFAULT false,
  porcentaje_iva numeric(5,2) DEFAULT 19,
  resolucion_dian text,
  prefijo_factura text,
  consecutivo_actual int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE facturas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  pedido_id uuid REFERENCES pedidos(id),
  numero_factura text,
  nit_cliente text,
  nombre_fiscal_cliente text,
  email_cliente text,
  subtotal numeric(12,2),
  iva numeric(12,2),
  total numeric(12,2),
  estado text DEFAULT 'borrador' CHECK (estado IN ('borrador', 'emitida', 'anulada')),
  pdf_url text,
  emitida_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE estados_promociones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  titulo text,
  imagen_url text NOT NULL,
  descripcion text,
  activa bool DEFAULT true,
  expira_at timestamptz,
  vistas int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE promocion_vistas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  promocion_id uuid REFERENCES estados_promociones(id),
  device_id text REFERENCES dispositivos_cliente(device_id),
  visto_at timestamptz DEFAULT now()
);
