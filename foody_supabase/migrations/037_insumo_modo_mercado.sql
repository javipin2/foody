-- Fase A costeo KYG: campos crudos de «Lista de mercado» por insumo.
ALTER TABLE ingredientes
  ADD COLUMN IF NOT EXISTS proveedor text,
  ADD COLUMN IF NOT EXISTS precio_compra numeric(12,2),
  ADD COLUMN IF NOT EXISTS peso_bruto numeric(12,3),
  ADD COLUMN IF NOT EXISTS peso_neto numeric(12,3),
  ADD COLUMN IF NOT EXISTS categoria_insumo text
    CHECK (categoria_insumo IN ('alimento','empaque','mano_obra','servicio'))
    DEFAULT 'alimento';

COMMENT ON COLUMN ingredientes.precio_compra IS 'Precio pagado por la presentación (peso bruto)';
COMMENT ON COLUMN ingredientes.peso_bruto IS 'Cantidad total comprada (con merma)';
COMMENT ON COLUMN ingredientes.peso_neto IS 'Cantidad aprovechable; deriva costo_unitario_actual y rendimiento';
