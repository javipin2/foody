-- Foody — dispositivos cliente y push staff
CREATE TABLE dispositivos_cliente (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id text UNIQUE NOT NULL,
  fcm_token text,
  ciudad_id uuid REFERENCES ciudades(id),
  nombre_opcional text,
  telefono_opcional text,
  plataforma text CHECK (plataforma IN ('android', 'ios', 'web')),
  ultimo_acceso timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE tokens_push_admin (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid REFERENCES usuarios(id),
  fcm_token text NOT NULL,
  plataforma text,
  activo bool DEFAULT true,
  updated_at timestamptz DEFAULT now()
);
