-- Umbral de alerta food cost / margen alineado con guía KYG (35% ejecutivos).
ALTER TABLE sucursales
  ALTER COLUMN umbral_alerta_margen SET DEFAULT 35;

UPDATE sucursales
SET umbral_alerta_margen = 35
WHERE umbral_alerta_margen IS NULL OR umbral_alerta_margen = 25;
