-- Foody — domiciliarios
CREATE TABLE domiciliarios_independientes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre text NOT NULL,
  email text UNIQUE NOT NULL,
  telefono text,
  foto_url text,
  tipo_vehiculo text,
  placa text,
  ciudad_id uuid REFERENCES ciudades(id),
  estado_cuenta text DEFAULT 'pendiente_verificacion'
    CHECK (estado_cuenta IN ('pendiente_verificacion', 'activo', 'suspendido', 'bloqueado')),
  calificacion_promedio numeric(3,2) DEFAULT 0,
  total_entregas int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE documentos_domiciliario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domiciliario_id uuid REFERENCES domiciliarios_independientes(id),
  tipo text NOT NULL,
  url text NOT NULL,
  estado text DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'aprobado', 'rechazado')),
  motivo_rechazo text,
  revisado_por uuid REFERENCES usuarios(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE domiciliarios_planta (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid REFERENCES usuarios(id),
  sucursal_id uuid REFERENCES sucursales(id),
  activo bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE domiciliarios_sesiones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domiciliario_id uuid REFERENCES domiciliarios_independientes(id),
  lat_actual numeric(10,7),
  lng_actual numeric(10,7),
  ciudad_id uuid REFERENCES ciudades(id),
  disponible bool DEFAULT true,
  activa bool DEFAULT true,
  iniciada_at timestamptz DEFAULT now(),
  cerrada_at timestamptz
);

CREATE TABLE ofertas_pedido (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid REFERENCES pedidos(id),
  sucursal_id uuid REFERENCES sucursales(id),
  radio_busqueda_km numeric NOT NULL,
  intento_numero int DEFAULT 1,
  estado text DEFAULT 'activa' CHECK (estado IN ('activa', 'aceptada', 'expirada', 'cancelada')),
  expira_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE respuestas_oferta (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oferta_id uuid REFERENCES ofertas_pedido(id),
  domiciliario_id uuid REFERENCES domiciliarios_independientes(id),
  respuesta text CHECK (respuesta IN ('aceptada', 'rechazada', 'no_vio')),
  respondido_at timestamptz DEFAULT now()
);

CREATE TABLE asignaciones_domicilio (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid REFERENCES pedidos(id),
  sucursal_id uuid REFERENCES sucursales(id),
  domiciliario_independiente_id uuid REFERENCES domiciliarios_independientes(id),
  domiciliario_planta_id uuid REFERENCES domiciliarios_planta(id),
  tipo_domiciliario text NOT NULL CHECK (tipo_domiciliario IN ('planta', 'independiente')),
  estado text DEFAULT 'asignado' CHECK (estado IN ('asignado', 'en_camino', 'entregado')),
  asignado_at timestamptz DEFAULT now(),
  entregado_at timestamptz
);

CREATE TABLE domiciliarios_ubicaciones_historial (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asignacion_id uuid REFERENCES asignaciones_domicilio(id),
  lat numeric(10,7) NOT NULL,
  lng numeric(10,7) NOT NULL,
  registrado_at timestamptz DEFAULT now()
);

CREATE TABLE ganancias_domiciliario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domiciliario_id uuid REFERENCES domiciliarios_independientes(id),
  asignacion_id uuid REFERENCES asignaciones_domicilio(id),
  valor_domicilio numeric(12,2) NOT NULL,
  comision_foody numeric(12,2) NOT NULL,
  ganancia_domiciliario numeric(12,2) NOT NULL,
  pagado bool DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE calificaciones_domiciliario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asignacion_id uuid REFERENCES asignaciones_domicilio(id),
  device_id text REFERENCES dispositivos_cliente(device_id),
  calificacion int CHECK (calificacion BETWEEN 1 AND 5),
  comentario text,
  created_at timestamptz DEFAULT now()
);
