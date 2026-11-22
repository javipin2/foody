-- F-16: estado cancelado en asignaciones domicilio (al cancelar pedido)
ALTER TABLE asignaciones_domicilio
  DROP CONSTRAINT IF EXISTS asignaciones_domicilio_estado_check;

ALTER TABLE asignaciones_domicilio
  ADD CONSTRAINT asignaciones_domicilio_estado_check
  CHECK (estado IN ('asignado', 'en_camino', 'entregado', 'cancelado'));
