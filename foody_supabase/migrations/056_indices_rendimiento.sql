-- Foody — índices de rendimiento (multi-tenant por sucursal_id)
-- Ver docs/OPTIMIZACION_ESCALABILIDAD_FOODY.md

-- Catálogo y operación diaria
CREATE INDEX IF NOT EXISTS idx_productos_sucursal
  ON productos(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_productos_sucursal_categoria
  ON productos(sucursal_id, categoria_id);
CREATE INDEX IF NOT EXISTS idx_categorias_sucursal
  ON categorias(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_mesas_sucursal
  ON mesas(sucursal_id);

-- Staff y cadena
CREATE INDEX IF NOT EXISTS idx_usuarios_sucursal
  ON usuarios(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_restaurante
  ON usuarios(restaurante_id) WHERE restaurante_id IS NOT NULL;

-- Pedidos — ítems e historial (Kanban, KDS, reportes)
CREATE INDEX IF NOT EXISTS idx_pedido_items_pedido
  ON pedido_items(pedido_id);
CREATE INDEX IF NOT EXISTS idx_estados_pedido_historial_pedido
  ON estados_pedido_historial(pedido_id, fecha DESC);

-- Inventario (tablas reales del esquema Foody)
CREATE INDEX IF NOT EXISTS idx_ingredientes_sucursal
  ON ingredientes(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_ingrediente_sucursal_fecha
  ON movimientos_ingrediente(sucursal_id, created_at DESC);

-- Domicilio dispatch
CREATE INDEX IF NOT EXISTS idx_asignaciones_domicilio_pedido
  ON asignaciones_domicilio(pedido_id, asignado_at DESC);

-- Auditoría (consultas por sucursal en reportes)
CREATE INDEX IF NOT EXISTS idx_auditoria_logs_sucursal_fecha
  ON auditoria_logs(sucursal_id, created_at DESC);
