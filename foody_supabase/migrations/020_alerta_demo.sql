-- Alerta demo para probar pantalla admin
INSERT INTO alertas_riesgo (
  id,
  sucursal_id,
  tipo,
  nivel,
  descripcion,
  referencia_tipo
) VALUES (
  'a1000000-0000-4000-8000-000000000001',
  'c0000000-0000-4000-8000-000000000001',
  'stock_minimo_alcanzado',
  'medio',
  'Demo: revisa el inventar de ingredientes esta semana',
  'ingrediente'
)
ON CONFLICT (id) DO NOTHING;
