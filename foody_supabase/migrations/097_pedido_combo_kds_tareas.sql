-- Separate kitchen preparation tasks from the single billable combo line.
-- This migration is for isolated QA first; do not apply to the daily database
-- until the API and Flutter flows are validated together.

CREATE TABLE IF NOT EXISTS pedido_combo_tareas_cocina (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
  pedido_item_id uuid REFERENCES pedido_items(id) ON DELETE SET NULL,
  pedido_item_id_original uuid NOT NULL,
  sucursal_id uuid NOT NULL REFERENCES sucursales(id),
  cocina_id uuid NOT NULL REFERENCES cocinas(id),
  componente_indice integer NOT NULL CHECK (componente_indice >= 0),
  tipo_item text NOT NULL CHECK (tipo_item IN ('producto', 'bebida', 'topping')),
  componente_id uuid NOT NULL,
  nombre_snapshot text NOT NULL,
  cantidad numeric(12,3) NOT NULL CHECK (cantidad > 0),
  precio_unitario_snapshot numeric(12,2),
  costo_unitario_snapshot numeric(12,2) NOT NULL DEFAULT 0,
  producto_padre_id uuid,
  producto_padre_nombre_snapshot text,
  estado text NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN (
      'pendiente', 'preparando', 'listo', 'no_disponible',
      'pausada_decision_cliente', 'cancelada'
    )),
  estado_antes_pausa text CHECK (
    estado_antes_pausa IS NULL OR estado_antes_pausa IN ('pendiente', 'preparando')
  ),
  motivo_no_disponible text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pedido_item_id, componente_indice)
);

CREATE INDEX IF NOT EXISTS idx_combo_tareas_cocina_estado
  ON pedido_combo_tareas_cocina (sucursal_id, cocina_id, estado, created_at);
CREATE INDEX IF NOT EXISTS idx_combo_tareas_pedido_item
  ON pedido_combo_tareas_cocina (pedido_item_id);

COMMENT ON TABLE pedido_combo_tareas_cocina IS
  'Tareas por componente/estación subordinadas a una única línea cobrable pedido_items; cantidades y precios son snapshots de venta.';

CREATE TABLE IF NOT EXISTS pedido_combo_decisiones_cliente (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
  pedido_item_id uuid REFERENCES pedido_items(id) ON DELETE SET NULL,
  pedido_item_id_original uuid NOT NULL,
  tarea_no_disponible_id uuid REFERENCES pedido_combo_tareas_cocina(id) ON DELETE SET NULL,
  tarea_id_original uuid NOT NULL,
  sucursal_id uuid NOT NULL REFERENCES sucursales(id),
  estado text NOT NULL DEFAULT 'pendiente_cliente'
    CHECK (estado IN ('pendiente_cliente', 'aceptada', 'rechazada', 'aplicada')),
  componente_anterior_snapshot jsonb NOT NULL,
  componente_reemplazo_snapshot jsonb,
  diferencia_propuesta numeric(12,2),
  total_propuesto numeric(12,2),
  total_aceptado numeric(12,2),
  usuario_id uuid REFERENCES usuarios(id),
  respuesta_at timestamptz,
  aplicada_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_combo_decision_pendiente_tarea
  ON pedido_combo_decisiones_cliente (tarea_no_disponible_id)
  WHERE estado = 'pendiente_cliente';
CREATE UNIQUE INDEX IF NOT EXISTS idx_combo_decision_pendiente_linea
  ON pedido_combo_decisiones_cliente (pedido_item_id)
  WHERE estado = 'pendiente_cliente';
CREATE INDEX IF NOT EXISTS idx_combo_decisiones_sucursal_pendiente
  ON pedido_combo_decisiones_cliente (sucursal_id, created_at)
  WHERE estado = 'pendiente_cliente';

ALTER TABLE pedido_combo_decisiones_cliente
  ADD COLUMN IF NOT EXISTS cotizacion_version integer NOT NULL DEFAULT 0
    CHECK (cotizacion_version >= 0),
  ADD COLUMN IF NOT EXISTS respuesta_usuario_id uuid REFERENCES usuarios(id);

COMMENT ON TABLE pedido_combo_decisiones_cliente IS
  'Bitácora auditable de decisiones del cliente ante componente de combo no disponible; creación de esta tabla no autoriza modificar importes de pedido/Caja.';

-- Immutable ingredient consumption per combo component, captured at sale time.
-- Later adjustments must never reconstruct historical stock from the live recipe.
CREATE TABLE IF NOT EXISTS pedido_combo_stock_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
  pedido_item_id uuid REFERENCES pedido_items(id) ON DELETE SET NULL
    DEFERRABLE INITIALLY DEFERRED,
  pedido_item_id_original uuid NOT NULL,
  componente_indice integer NOT NULL CHECK (componente_indice >= 0),
  componente_id uuid NOT NULL,
  ingrediente_id uuid NOT NULL REFERENCES ingredientes(id),
  evento text NOT NULL CHECK (evento IN ('consumo', 'devolucion', 'merma')),
  cantidad numeric(14,4) NOT NULL CHECK (cantidad > 0),
  costo_unitario_snapshot numeric(14,4) NOT NULL DEFAULT 0,
  decision_id uuid REFERENCES pedido_combo_decisiones_cliente(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pedido_combo_stock_ledger_item_component
  ON pedido_combo_stock_ledger (pedido_item_id, componente_indice, created_at);
CREATE INDEX IF NOT EXISTS idx_pedido_combo_stock_ledger_pedido
  ON pedido_combo_stock_ledger (pedido_id, ingrediente_id, evento);

COMMENT ON TABLE pedido_combo_stock_ledger IS
  'Trazabilidad inmutable de ingredientes por componente de combo; sirve para compensar inventario/COGS sin depender de recetas editadas después de la venta.';
