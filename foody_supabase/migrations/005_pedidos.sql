-- Foody — pedidos
CREATE TABLE mesas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  qr_token text UNIQUE NOT NULL DEFAULT gen_random_uuid()::text,
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE pedidos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  mesa_id uuid REFERENCES mesas(id),
  device_id text REFERENCES dispositivos_cliente(device_id),
  cajero_id uuid REFERENCES usuarios(id),
  numero_pedido text NOT NULL,
  tipo text NOT NULL CHECK (tipo IN ('mesa', 'para_llevar', 'domicilio', 'encargo')),
  estado text NOT NULL DEFAULT 'pendiente',
  cliente_nombre text,
  cliente_telefono text,
  direccion_entrega text,
  lat numeric(10,7),
  lng numeric(10,7),
  metodo_pago text CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'transferencia', 'nequi', 'pendiente')),
  subtotal numeric(12,2) NOT NULL DEFAULT 0,
  costo_domicilio numeric(12,2) DEFAULT 0,
  descuento numeric(12,2) DEFAULT 0,
  motivo_descuento text,
  total numeric(12,2) NOT NULL DEFAULT 0,
  requiere_factura bool DEFAULT false,
  observaciones text,
  tiempo_estimado_minutos int,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_pedidos_sucursal_estado ON pedidos(sucursal_id, estado);
CREATE INDEX idx_pedidos_sucursal_created ON pedidos(sucursal_id, created_at DESC);

CREATE TABLE estados_pedido_historial (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid REFERENCES pedidos(id),
  estado_anterior text,
  estado_nuevo text NOT NULL,
  usuario_id uuid REFERENCES usuarios(id),
  motivo text,
  duracion_estado_anterior_seg int,
  fecha timestamptz DEFAULT now()
);

CREATE TABLE pedido_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid REFERENCES pedidos(id),
  producto_id uuid REFERENCES productos(id),
  cocina_id uuid REFERENCES cocinas(id),
  cantidad int NOT NULL,
  precio_unitario numeric(12,2) NOT NULL,
  costo_unitario numeric(12,2),
  observaciones text,
  estado_cocina text DEFAULT 'pendiente' CHECK (estado_cocina IN ('pendiente', 'preparando', 'listo')),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE pedido_item_toppings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_item_id uuid REFERENCES pedido_items(id),
  topping_id uuid REFERENCES toppings(id),
  nombre_topping text NOT NULL,
  precio_topping numeric(12,2) NOT NULL
);

CREATE TABLE pedido_item_bebidas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_item_id uuid REFERENCES pedido_items(id),
  bebida_id uuid REFERENCES bebidas(id),
  nombre_bebida text NOT NULL,
  precio_bebida numeric(12,2) NOT NULL,
  cantidad int DEFAULT 1
);

CREATE TABLE pedido_combo_selecciones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_item_id uuid REFERENCES pedido_items(id),
  combo_id uuid REFERENCES combos(id),
  nombre_combo text NOT NULL,
  precio_combo numeric(12,2) NOT NULL
);

CREATE TABLE transferencias_mesa (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid REFERENCES pedidos(id),
  mesa_origen_id uuid REFERENCES mesas(id),
  mesa_destino_id uuid REFERENCES mesas(id),
  usuario_id uuid REFERENCES usuarios(id),
  motivo text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE margenes_venta (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid REFERENCES pedidos(id),
  pedido_item_id uuid REFERENCES pedido_items(id),
  sucursal_id uuid REFERENCES sucursales(id),
  precio_venta numeric(12,2) NOT NULL,
  costo_al_momento numeric(12,2) NOT NULL,
  margen_porcentaje numeric(5,2),
  created_at timestamptz DEFAULT now()
);
