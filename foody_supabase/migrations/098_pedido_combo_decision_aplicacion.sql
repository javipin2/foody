-- Persist the accepted quote baseline and the financial snapshot when a combo
-- line is canceled. Additive schema for the response-application transaction.

ALTER TABLE pedido_combo_decisiones_cliente
  ADD COLUMN IF NOT EXISTS total_base_cotizacion numeric(12,2),
  ADD COLUMN IF NOT EXISTS respuesta_accion text
    CHECK (respuesta_accion IS NULL OR respuesta_accion IN (
      'aceptar_sustitucion', 'cancelar_combo'
    )),
  ADD COLUMN IF NOT EXISTS linea_cancelada_snapshot jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS idx_combo_stock_ledger_decision_evento
  ON pedido_combo_stock_ledger (
    decision_id, componente_indice, componente_id, ingrediente_id, evento
  )
  WHERE decision_id IS NOT NULL;

COMMENT ON COLUMN pedido_combo_decisiones_cliente.total_base_cotizacion IS
  'Total del pedido al emitir la cotización; impide aceptar un total obsoleto tras cambios concurrentes.';
COMMENT ON COLUMN pedido_combo_decisiones_cliente.linea_cancelada_snapshot IS
  'Snapshot financiero y vínculos de pago de la única línea cobrable eliminada al cancelar un combo.';
