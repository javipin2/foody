-- Foody — catálogo y menú
CREATE TABLE cocinas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE impresoras (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  cocina_id uuid REFERENCES cocinas(id),
  nombre text NOT NULL,
  ip_local text,
  tipo text DEFAULT 'termica',
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE categorias (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  imagen_url text,
  orden int DEFAULT 0,
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE productos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  categoria_id uuid REFERENCES categorias(id),
  cocina_id uuid REFERENCES cocinas(id),
  nombre text NOT NULL,
  descripcion text,
  precio numeric(12,2) NOT NULL,
  precio_sugerido numeric(12,2),
  costo_calculado numeric(12,2),
  imagen_url text,
  disponible bool DEFAULT true,
  es_encargo bool DEFAULT false,
  orden int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE toppings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  precio numeric(12,2) DEFAULT 0,
  disponible bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE producto_toppings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id uuid REFERENCES productos(id),
  topping_id uuid REFERENCES toppings(id),
  UNIQUE(producto_id, topping_id)
);

CREATE TABLE bebidas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  precio numeric(12,2) NOT NULL,
  disponible bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE producto_bebidas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id uuid REFERENCES productos(id),
  bebida_id uuid REFERENCES bebidas(id),
  UNIQUE(producto_id, bebida_id)
);

CREATE TABLE combos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  descripcion text,
  precio_fijo numeric(12,2) NOT NULL,
  imagen_url text,
  disponible bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE combo_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  combo_id uuid REFERENCES combos(id),
  tipo_item text NOT NULL CHECK (tipo_item IN ('producto', 'bebida', 'topping')),
  item_id uuid NOT NULL,
  cantidad int DEFAULT 1
);
