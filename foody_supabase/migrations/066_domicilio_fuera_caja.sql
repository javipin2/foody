-- Foody — Contabilidad del domicilio separada del producto
-- Por defecto la caja registra SOLO el producto (total - costo_domicilio).
-- El costo del domicilio no suma a los ingresos del restaurante: se rastrea por
-- domiciliario (cuántos pedidos entregó y cuánto lleva en domicilios).
-- Restaurantes que sí cobran/retienen el domicilio activan esta opción y el
-- domicilio vuelve a entrar a caja (comportamiento anterior).

ALTER TABLE sucursales
  ADD COLUMN IF NOT EXISTS domicilio_ingresa_a_caja boolean DEFAULT false;
