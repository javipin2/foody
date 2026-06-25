-- Foody — repartidor demo activo + horarios duplicados limpiados
UPDATE domiciliarios_independientes
SET estado_cuenta = 'activo',
    hash_contrasena = COALESCE(
      hash_contrasena,
      '$2b$10$w22qWYXW6xIIyhxS5XTjX.LzPEXiezmOu03cocn6OgJmxnghqIe2.'
    )
WHERE LOWER(email) = 'repartidor@foody.demo';

-- Eliminar filas duplicadas (mismo sucursal + día); conservar la más antigua
DELETE FROM horarios_sucursal h1
USING horarios_sucursal h2
WHERE h1.sucursal_id = h2.sucursal_id
  AND h1.dia_semana = h2.dia_semana
  AND h1.id > h2.id;
