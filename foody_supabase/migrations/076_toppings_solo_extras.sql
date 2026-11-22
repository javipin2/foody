-- Toppings vuelven a ser solo extras (no productos). Bebidas siguen como producto.
DELETE FROM productos WHERE topping_origen_id IS NOT NULL;

-- Limpia categorías Extras vacías creadas solo para el espejo de toppings
DELETE FROM categorias c
WHERE LOWER(TRIM(c.nombre)) IN ('extras', 'toppings', 'adicionales', 'extra')
  AND NOT EXISTS (
    SELECT 1 FROM productos p WHERE p.categoria_id = c.id
  );
