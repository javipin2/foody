-- Bloque 2: IVA en pedidos, zonas de cobertura demo, config fiscal demo

ALTER TABLE pedidos
  ADD COLUMN IF NOT EXISTS iva_porcentaje numeric(5,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS iva_valor numeric(12,2) DEFAULT 0;

-- Coordenadas demo (Valledupar) para cálculo de distancia de domicilio
UPDATE sucursales
SET lat = 10.4637140, lng = -73.2532220
WHERE id = 'c0000000-0000-4000-8000-000000000001'
  AND lat IS NULL;

INSERT INTO zonas_cobertura (id, sucursal_id, nombre, costo_domicilio, distancia_max_km, activa) VALUES
  (
    '50000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'Zona centro (hasta 3 km)',
    4000,
    3,
    true
  ),
  (
    '50000000-0000-4000-8000-000000000002',
    'c0000000-0000-4000-8000-000000000001',
    'Zona ampliada (hasta 8 km)',
    7000,
    8,
    true
  )
ON CONFLICT (id) DO NOTHING;

-- Config fiscal régimen común con IVA (para probar desglose en factura)
INSERT INTO configuracion_fiscal_sucursal (
  sucursal_id, nit, razon_social, regimen, aplica_iva, porcentaje_iva,
  resolucion_dian, prefijo_factura
) VALUES (
  'c0000000-0000-4000-8000-000000000001',
  '900123456',
  'Foody Demo Restaurante SAS',
  'comun',
  true,
  19,
  '18764000001234',
  'FE'
)
ON CONFLICT (sucursal_id) DO UPDATE SET
  aplica_iva = EXCLUDED.aplica_iva,
  porcentaje_iva = EXCLUDED.porcentaje_iva,
  regimen = EXCLUDED.regimen;
