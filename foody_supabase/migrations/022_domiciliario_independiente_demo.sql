-- Foody — domiciliario independiente demo + coords sucursal
ALTER TABLE domiciliarios_independientes
  ADD COLUMN IF NOT EXISTS hash_contrasena text;

UPDATE sucursales
SET lat = 10.463310, lng = -73.253220
WHERE id = 'c0000000-0000-4000-8000-000000000001'
  AND (lat IS NULL OR lng IS NULL);

INSERT INTO domiciliarios_independientes (
  id, nombre, email, telefono, tipo_vehiculo, placa,
  ciudad_id, estado_cuenta, hash_contrasena, calificacion_promedio, total_entregas
) VALUES (
  'a1000000-0000-4000-8000-000000000001',
  'Carlos Repartidor Demo',
  'repartidor@foody.demo',
  '3007654321',
  'moto',
  'ABC123',
  'a0000000-0000-4000-8000-000000000001',
  'activo',
  '$2b$10$w22qWYXW6xIIyhxS5XTjX.LzPEXiezmOu03cocn6OgJmxnghqIe2.',
  4.80,
  25
) ON CONFLICT (email) DO UPDATE SET
  hash_contrasena = EXCLUDED.hash_contrasena,
  estado_cuenta = 'activo',
  ciudad_id = EXCLUDED.ciudad_id;

-- Sesión activa cerca de la sucursal demo (para pruebas de dispatch)
UPDATE domiciliarios_sesiones SET activa = false, cerrada_at = now()
WHERE domiciliario_id = 'a1000000-0000-4000-8000-000000000001' AND activa = true;

INSERT INTO domiciliarios_sesiones (
  domiciliario_id, lat_actual, lng_actual, ciudad_id, disponible, activa
) VALUES (
  'a1000000-0000-4000-8000-000000000001',
  10.464100,
  -73.252500,
  'a0000000-0000-4000-8000-000000000001',
  true,
  true
);
