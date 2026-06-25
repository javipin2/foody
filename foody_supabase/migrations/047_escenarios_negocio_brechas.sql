-- Foody 047 — Brechas escenarios negocio (split bill, cocina rechaza, reservas, etc.)

-- Cocina: rechazar ítem / no disponible
ALTER TABLE pedido_items DROP CONSTRAINT IF EXISTS pedido_items_estado_cocina_check;
ALTER TABLE pedido_items ADD CONSTRAINT pedido_items_estado_cocina_check
  CHECK (estado_cocina IN ('pendiente', 'preparando', 'listo', 'no_disponible'));

-- Cobro por ítem / comensal
ALTER TABLE pedido_items
  ADD COLUMN IF NOT EXISTS estado_cobro text NOT NULL DEFAULT 'pendiente'
    CHECK (estado_cobro IN ('pendiente', 'cobrado'));
ALTER TABLE pedido_items
  ADD COLUMN IF NOT EXISTS comensal_etiqueta text;

ALTER TABLE pedidos
  ADD COLUMN IF NOT EXISTS monto_pagado numeric(12,2) NOT NULL DEFAULT 0;
ALTER TABLE pedidos
  ADD COLUMN IF NOT EXISTS propina_acumulada numeric(12,2) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS pagos_pedido (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid NOT NULL REFERENCES sucursales(id),
  pedido_id uuid REFERENCES pedidos(id),
  mesa_id uuid REFERENCES mesas(id),
  monto numeric(12,2) NOT NULL CHECK (monto > 0),
  propina numeric(12,2) NOT NULL DEFAULT 0,
  metodo_pago text NOT NULL
    CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'transferencia', 'nequi')),
  usuario_id uuid REFERENCES usuarios(id),
  referencia text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pago_pedido_items (
  pago_id uuid NOT NULL REFERENCES pagos_pedido(id) ON DELETE CASCADE,
  pedido_item_id uuid NOT NULL REFERENCES pedido_items(id),
  PRIMARY KEY (pago_id, pedido_item_id)
);

CREATE INDEX IF NOT EXISTS idx_pagos_pedido_mesa ON pagos_pedido(mesa_id);
CREATE INDEX IF NOT EXISTS idx_pagos_pedido_pedido ON pagos_pedido(pedido_id);

-- Mesas: reserva y unión (grupo)
ALTER TABLE mesas
  ADD COLUMN IF NOT EXISTS estado_operativo text NOT NULL DEFAULT 'libre'
    CHECK (estado_operativo IN ('libre', 'ocupada', 'reservada'));
ALTER TABLE mesas
  ADD COLUMN IF NOT EXISTS reserva_hasta timestamptz;
ALTER TABLE mesas
  ADD COLUMN IF NOT EXISTS reserva_cliente_nombre text;
ALTER TABLE mesas
  ADD COLUMN IF NOT EXISTS reserva_cliente_telefono text;
ALTER TABLE mesas
  ADD COLUMN IF NOT EXISTS mesa_grupo_id uuid REFERENCES mesas(id);

-- Idempotencia crear pedido
CREATE TABLE IF NOT EXISTS pedidos_idempotencia (
  clave text PRIMARY KEY,
  pedido_id uuid NOT NULL REFERENCES pedidos(id),
  created_at timestamptz DEFAULT now()
);

-- Caja: devoluciones y arqueo ciego
ALTER TABLE movimientos_caja DROP CONSTRAINT IF EXISTS movimientos_caja_tipo_check;
ALTER TABLE movimientos_caja ADD CONSTRAINT movimientos_caja_tipo_check
  CHECK (tipo IN ('venta', 'retiro', 'gasto', 'ingreso_extra', 'apertura', 'devolucion'));

ALTER TABLE cajas
  ADD COLUMN IF NOT EXISTS arqueo_ciego bool NOT NULL DEFAULT false;

-- Traslados inventario entre sedes (mismo restaurante)
CREATE TABLE IF NOT EXISTS traslados_inventario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurante_id uuid NOT NULL REFERENCES restaurantes(id),
  sucursal_origen_id uuid NOT NULL REFERENCES sucursales(id),
  sucursal_destino_id uuid NOT NULL REFERENCES sucursales(id),
  ingrediente_id uuid NOT NULL REFERENCES ingredientes(id),
  cantidad numeric(12,4) NOT NULL CHECK (cantidad > 0),
  estado text NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'recibido', 'cancelado')),
  usuario_id uuid REFERENCES usuarios(id),
  motivo text,
  created_at timestamptz DEFAULT now(),
  recibido_at timestamptz
);

-- Cola notificaciones (FCM / push futuro)
CREATE TABLE IF NOT EXISTS notificaciones_pendientes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  tipo text NOT NULL,
  destinatario_rol text,
  destinatario_usuario_id uuid REFERENCES usuarios(id),
  payload jsonb NOT NULL DEFAULT '{}',
  enviada bool NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Cola impresión cocina (Python WebSocket futuro)
CREATE TABLE IF NOT EXISTS impresion_cocina_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid NOT NULL REFERENCES sucursales(id),
  cocina_id uuid REFERENCES cocinas(id),
  pedido_id uuid REFERENCES pedidos(id),
  payload jsonb NOT NULL DEFAULT '{}',
  estado text NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'enviado', 'error')),
  created_at timestamptz DEFAULT now()
);

-- Anonimización device (GDPR)
ALTER TABLE dispositivos_cliente
  ADD COLUMN IF NOT EXISTS anonimizado bool NOT NULL DEFAULT false;
ALTER TABLE dispositivos_cliente
  ADD COLUMN IF NOT EXISTS anonimizado_at timestamptz;
