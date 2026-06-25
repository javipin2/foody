-- Permite estado_operativo 'pagando' (cuenta presentada en mesa)
ALTER TABLE mesas DROP CONSTRAINT IF EXISTS mesas_estado_operativo_check;
ALTER TABLE mesas ADD CONSTRAINT mesas_estado_operativo_check
  CHECK (estado_operativo IN ('libre', 'ocupada', 'reservada', 'pagando'));
