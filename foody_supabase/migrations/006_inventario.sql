-- Foody — inventario y recetas
CREATE TABLE ingredientes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  unidad_base text NOT NULL,
  tipo_costeo text NOT NULL CHECK (tipo_costeo IN ('peso', 'pieza', 'rendimiento', 'produccion')),
  rendimiento_porcentaje numeric(5,2) DEFAULT 100,
  stock_actual numeric(12,3) DEFAULT 0,
  stock_minimo numeric(12,3) DEFAULT 0,
  costo_unitario_actual numeric(12,4) DEFAULT 0,
  activo bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE presentaciones_compra (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ingrediente_id uuid REFERENCES ingredientes(id),
  nombre text NOT NULL,
  cantidad_unidades_base numeric(12,3) NOT NULL,
  activa bool DEFAULT true
);

CREATE TABLE compras_inventario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  usuario_id uuid REFERENCES usuarios(id),
  proveedor text,
  total_compra numeric(12,2) NOT NULL,
  fecha_compra timestamptz DEFAULT now(),
  observaciones text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE compra_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  compra_id uuid REFERENCES compras_inventario(id),
  ingrediente_id uuid REFERENCES ingredientes(id),
  presentacion_id uuid REFERENCES presentaciones_compra(id),
  cantidad_presentaciones numeric(12,3) NOT NULL,
  precio_presentacion numeric(12,2) NOT NULL,
  cantidad_unidades_base numeric(12,3) NOT NULL,
  costo_unitario_base numeric(12,4) NOT NULL
);

CREATE TABLE movimientos_ingrediente (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  ingrediente_id uuid REFERENCES ingredientes(id),
  pedido_id uuid REFERENCES pedidos(id),
  tipo text NOT NULL CHECK (tipo IN ('compra', 'venta', 'ajuste', 'merma', 'produccion', 'conteo')),
  cantidad numeric(12,3) NOT NULL,
  stock_anterior numeric(12,3) NOT NULL,
  stock_posterior numeric(12,3) NOT NULL,
  motivo text,
  usuario_id uuid REFERENCES usuarios(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE recetas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  descripcion text,
  rendimiento_porciones int DEFAULT 1,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE receta_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receta_id uuid REFERENCES recetas(id),
  tipo_item text NOT NULL CHECK (tipo_item IN ('ingrediente', 'subreceta', 'empaque')),
  ingrediente_id uuid REFERENCES ingredientes(id),
  subreceta_id uuid REFERENCES recetas(id),
  cantidad numeric(12,3) NOT NULL,
  unidad text NOT NULL,
  orden int DEFAULT 0
);

CREATE TABLE costos_receta (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receta_id uuid REFERENCES recetas(id),
  costo_total numeric(12,4) NOT NULL,
  costo_por_porcion numeric(12,4) NOT NULL,
  calculado_at timestamptz DEFAULT now()
);

ALTER TABLE productos ADD COLUMN receta_id uuid REFERENCES recetas(id);

CREATE TABLE ajustes_stock (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  ingrediente_id uuid REFERENCES ingredientes(id),
  cantidad_ajuste numeric(12,3) NOT NULL,
  motivo text NOT NULL,
  usuario_id uuid REFERENCES usuarios(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE conteos_inventario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  usuario_id uuid REFERENCES usuarios(id),
  estado text DEFAULT 'en_proceso',
  created_at timestamptz DEFAULT now(),
  cerrado_at timestamptz
);

CREATE TABLE conteo_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conteo_id uuid REFERENCES conteos_inventario(id),
  ingrediente_id uuid REFERENCES ingredientes(id),
  cantidad_teorica numeric(12,3) NOT NULL,
  cantidad_real numeric(12,3) NOT NULL,
  diferencia numeric(12,3) GENERATED ALWAYS AS (cantidad_real - cantidad_teorica) STORED
);
