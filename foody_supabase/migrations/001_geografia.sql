-- Foody — geografía y acceso
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE ciudades (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre text NOT NULL,
  slug text UNIQUE NOT NULL,
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE restaurantes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ciudad_id uuid REFERENCES ciudades(id),
  nombre text NOT NULL,
  descripcion text,
  logo_url text,
  banner_url text,
  telefono text,
  activo bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE sucursales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurante_id uuid REFERENCES restaurantes(id),
  ciudad_id uuid REFERENCES ciudades(id),
  nombre text NOT NULL,
  direccion text,
  telefono text,
  lat numeric(10,7),
  lng numeric(10,7),
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE zonas_cobertura (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text,
  costo_domicilio numeric(12,2) NOT NULL,
  distancia_max_km numeric NOT NULL,
  poligono jsonb,
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE horarios_sucursal (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  dia_semana int NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
  hora_apertura time NOT NULL,
  hora_cierre time NOT NULL,
  activo bool DEFAULT true
);
