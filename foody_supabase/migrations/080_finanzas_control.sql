-- Foody — control financiero: gastos como libro único, costos fijos, nómina simple.
-- Extiende costos_operativos_fijos (007) y gastos; crea empleados.
-- Punto de equilibrio / P&L usan pedido_items.costo_unitario (COGS), no compras.

-- 1) Costos fijos: categoría y metadatos de pago
ALTER TABLE costos_operativos_fijos
  ADD COLUMN IF NOT EXISTS categoria text DEFAULT 'otros',
  ADD COLUMN IF NOT EXISTS dia_pago int,
  ADD COLUMN IF NOT EXISTS notas text;

UPDATE costos_operativos_fijos
SET categoria = COALESCE(NULLIF(TRIM(categoria), ''), 'otros')
WHERE categoria IS NULL OR TRIM(categoria) = '';

-- 2) Empleados (nómina simple: sueldo base + frecuencia)
CREATE TABLE IF NOT EXISTS empleados (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid NOT NULL REFERENCES sucursales(id),
  nombre text NOT NULL,
  cargo text,
  sueldo_base numeric(12,2) NOT NULL CHECK (sueldo_base >= 0),
  frecuencia_pago text NOT NULL DEFAULT 'mensual'
    CHECK (frecuencia_pago IN ('diario', 'semanal', 'quincenal', 'mensual')),
  usuario_id uuid REFERENCES usuarios(id),
  activo bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_empleados_sucursal
  ON empleados (sucursal_id) WHERE activo = true;

-- 3) Gastos = libro único de egresos
ALTER TABLE gastos
  ADD COLUMN IF NOT EXISTS origen text NOT NULL DEFAULT 'caja',
  ADD COLUMN IF NOT EXISTS fecha date NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS empleado_id uuid REFERENCES empleados(id),
  ADD COLUMN IF NOT EXISTS costo_fijo_id uuid REFERENCES costos_operativos_fijos(id),
  ADD COLUMN IF NOT EXISTS periodo_desde date,
  ADD COLUMN IF NOT EXISTS periodo_hasta date,
  ADD COLUMN IF NOT EXISTS registrado_por uuid REFERENCES usuarios(id),
  ADD COLUMN IF NOT EXISTS comprobante_url text;

-- caja_id ya era nullable en 007; asegurar por si algún entorno lo forzó
ALTER TABLE gastos ALTER COLUMN caja_id DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'gastos_origen_check'
  ) THEN
    ALTER TABLE gastos
      ADD CONSTRAINT gastos_origen_check
      CHECK (origen IN ('caja', 'manual', 'fijo', 'nomina'));
  END IF;
END $$;

-- Backfill fecha desde created_at (el DEFAULT CURRENT_DATE deja mal las filas viejas)
UPDATE gastos
SET fecha = created_at::date
WHERE created_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_gastos_sucursal_fecha
  ON gastos (sucursal_id, fecha DESC);

CREATE INDEX IF NOT EXISTS idx_gastos_origen
  ON gastos (sucursal_id, origen);

-- 4) RLS empleados (mismo patrón 064: solo NestJS vía service role / postgres)
REVOKE ALL ON TABLE empleados FROM anon, authenticated;
ALTER TABLE empleados ENABLE ROW LEVEL SECURITY;
ALTER TABLE empleados FORCE ROW LEVEL SECURITY;

-- 5) Permiso ver_finanzas (sueldos sensibles: sin cajero)
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('admin', 'ver_finanzas'),
  ('gerente', 'ver_finanzas'),
  ('gerente_cadena', 'ver_finanzas')
ON CONFLICT (rol, permiso) DO NOTHING;
