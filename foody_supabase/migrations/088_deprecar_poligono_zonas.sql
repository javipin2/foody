-- CFG-POLIGONO-03 / HUER-DB-04: cobertura real = anillos distancia_max_km (Haversine).
-- La columna poligono nunca se leyó/escriió en Nest ni Flutter.
COMMENT ON COLUMN public.zonas_cobertura.poligono IS
  'DEPRECATED Foody: no usar. Cobertura = distancia_max_km + Haversine. Upgrade: PostGIS si se necesita polígono real.';
