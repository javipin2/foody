-- Foody — caja
CREATE TABLE cajas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  usuario_apertura_id uuid REFERENCES usuarios(id),
  usuario_cierre_id uuid REFERENCES usuarios(id),
  monto_inicial numeric(12,2) NOT NULL,
  monto_final_contado numeric(12,2),
  monto_final_sistema numeric(12,2),
  diferencia numeric(12,2),
  estado text DEFAULT 'abierta' CHECK (estado IN ('abierta', 'cerrada')),
  apertura_at timestamptz DEFAULT now(),
  cierre_at timestamptz,
  observaciones_cierre text
);

CREATE TABLE movimientos_caja (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  caja_id uuid REFERENCES cajas(id),
  sucursal_id uuid REFERENCES sucursales(id),
  pedido_id uuid REFERENCES pedidos(id),
  tipo text NOT NULL CHECK (tipo IN ('venta', 'retiro', 'gasto', 'ingreso_extra', 'apertura')),
  monto numeric(12,2) NOT NULL,
  metodo_pago text,
  descripcion text,
  usuario_id uuid REFERENCES usuarios(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE gastos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  caja_id uuid REFERENCES cajas(id),
  concepto text NOT NULL,
  monto numeric(12,2) NOT NULL,
  categoria text,
  usuario_id uuid REFERENCES usuarios(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE cuentas_por_cobrar (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  pedido_id uuid REFERENCES pedidos(id),
  cliente_nombre text NOT NULL,
  cliente_telefono text,
  monto numeric(12,2) NOT NULL,
  estado text DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'pagada')),
  pagada_at timestamptz,
  usuario_id uuid REFERENCES usuarios(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE costos_operativos_fijos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  concepto text NOT NULL,
  monto_mensual numeric(12,2) NOT NULL,
  activo bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);
