-- Foody — alertas y auditoría
CREATE TABLE alertas_riesgo (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  tipo text NOT NULL,
  nivel text NOT NULL CHECK (nivel IN ('bajo', 'medio', 'alto', 'critico')),
  descripcion text NOT NULL,
  referencia_id uuid,
  referencia_tipo text,
  revisada bool DEFAULT false,
  revisada_por uuid REFERENCES usuarios(id),
  revisada_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE auditoria_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  usuario_id uuid REFERENCES usuarios(id),
  accion text NOT NULL,
  tabla_afectada text,
  registro_id uuid,
  datos_antes jsonb,
  datos_despues jsonb,
  ip text,
  created_at timestamptz DEFAULT now()
);

REVOKE UPDATE, DELETE ON auditoria_logs FROM PUBLIC;
