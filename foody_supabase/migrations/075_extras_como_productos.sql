-- Espejo toppings/bebidas → productos vendibles (menú cliente).
-- El cliente pide extras como productos normales (producto_id), no como adicionales.

ALTER TABLE productos
  ADD COLUMN IF NOT EXISTS topping_origen_id UUID REFERENCES toppings(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS bebida_origen_id UUID REFERENCES bebidas(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS productos_sucursal_topping_origen_uidx
  ON productos (sucursal_id, topping_origen_id)
  WHERE topping_origen_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS productos_sucursal_bebida_origen_uidx
  ON productos (sucursal_id, bebida_origen_id)
  WHERE bebida_origen_id IS NOT NULL;

-- Categoría Extras (toppings) por sucursal que aún no la tenga
INSERT INTO categorias (id, sucursal_id, nombre, orden, activa)
SELECT gen_random_uuid(), s.id, 'Extras', 90, true
FROM sucursales s
WHERE s.activa = true
  AND NOT EXISTS (
    SELECT 1 FROM categorias c
    WHERE c.sucursal_id = s.id
      AND LOWER(TRIM(c.nombre)) IN ('extras', 'toppings', 'adicionales', 'extra')
  );

-- Categoría Bebidas si falta
INSERT INTO categorias (id, sucursal_id, nombre, orden, activa)
SELECT gen_random_uuid(), s.id, 'Bebidas', 80, true
FROM sucursales s
WHERE s.activa = true
  AND NOT EXISTS (
    SELECT 1 FROM categorias c
    WHERE c.sucursal_id = s.id
      AND LOWER(TRIM(c.nombre)) ~ '(bebida|jugo)'
  );

-- Productos desde toppings
INSERT INTO productos (
  id, sucursal_id, categoria_id, cocina_id, nombre, descripcion, precio,
  disponible, orden, topping_origen_id
)
SELECT
  gen_random_uuid(),
  t.sucursal_id,
  cat.id,
  coc.id,
  t.nombre,
  'Extra vendible',
  t.precio,
  t.disponible,
  0,
  t.id
FROM toppings t
INNER JOIN LATERAL (
  SELECT c.id FROM categorias c
  WHERE c.sucursal_id = t.sucursal_id AND c.activa = true
    AND LOWER(TRIM(c.nombre)) IN ('extras', 'toppings', 'adicionales', 'extra')
  ORDER BY c.orden ASC
  LIMIT 1
) cat ON true
LEFT JOIN LATERAL (
  SELECT co.id FROM cocinas co
  WHERE co.sucursal_id = t.sucursal_id AND co.activa = true
  ORDER BY co.nombre ASC
  LIMIT 1
) coc ON true
WHERE NOT EXISTS (
  SELECT 1 FROM productos p
  WHERE p.sucursal_id = t.sucursal_id AND p.topping_origen_id = t.id
);

-- Productos desde bebidas
INSERT INTO productos (
  id, sucursal_id, categoria_id, cocina_id, nombre, descripcion, precio,
  disponible, orden, bebida_origen_id
)
SELECT
  gen_random_uuid(),
  b.sucursal_id,
  cat.id,
  coc.id,
  b.nombre,
  'Bebida vendible',
  b.precio,
  b.disponible,
  0,
  b.id
FROM bebidas b
INNER JOIN LATERAL (
  SELECT c.id FROM categorias c
  WHERE c.sucursal_id = b.sucursal_id AND c.activa = true
    AND LOWER(TRIM(c.nombre)) ~ '(bebida|jugo)'
  ORDER BY c.orden ASC
  LIMIT 1
) cat ON true
LEFT JOIN LATERAL (
  SELECT co.id FROM cocinas co
  WHERE co.sucursal_id = b.sucursal_id AND co.activa = true
  ORDER BY co.nombre ASC
  LIMIT 1
) coc ON true
WHERE NOT EXISTS (
  SELECT 1 FROM productos p
  WHERE p.sucursal_id = b.sucursal_id AND p.bebida_origen_id = b.id
);
