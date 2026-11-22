-- Demo QA: sin IP de red el agente Python usa modo archivo al instante (sin timeout red).
UPDATE impresoras
SET ip_local = NULL, tipo = 'archivo'
WHERE id = '40000000-0000-4000-8000-000000000001'
  AND sucursal_id = 'c0000000-0000-4000-8000-000000000001';
