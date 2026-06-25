-- Bloque 4: RLS en tablas de negocio + QR token con entropía mínima
-- El cliente Flutter ya no lee tablas vía anon (broadcast desde NestJS).
-- NestJS usa DATABASE_URL (rol postgres / bypass RLS).

-- QR: nuevas mesas deben tener token aleatorio (backend usa randomBytes).
-- Demo conserva demo-mesa-1 para pruebas documentadas.
ALTER TABLE mesas
  DROP CONSTRAINT IF EXISTS mesas_qr_token_min_len;
ALTER TABLE mesas
  ADD CONSTRAINT mesas_qr_token_min_len CHECK (char_length(qr_token) >= 8);

-- Revocar acceso directo anon/authenticated a tablas sensibles (defensa en profundidad)
REVOKE ALL ON TABLE pedidos FROM anon, authenticated;
REVOKE ALL ON TABLE estados_pedido_historial FROM anon, authenticated;
REVOKE ALL ON TABLE pedido_items FROM anon, authenticated;
REVOKE ALL ON TABLE mesas FROM anon, authenticated;
REVOKE ALL ON TABLE usuarios FROM anon, authenticated;
REVOKE ALL ON TABLE movimientos_caja FROM anon, authenticated;
REVOKE ALL ON TABLE cajas FROM anon, authenticated;
REVOKE ALL ON TABLE auditoria_logs FROM anon, authenticated;
REVOKE ALL ON TABLE alertas_riesgo FROM anon, authenticated;
REVOKE ALL ON TABLE facturas FROM anon, authenticated;
REVOKE ALL ON TABLE configuracion_fiscal_sucursal FROM anon, authenticated;
REVOKE ALL ON TABLE asignaciones_domicilio FROM anon, authenticated;
REVOKE ALL ON TABLE ofertas_pedido FROM anon, authenticated;

-- Habilitar RLS (sin políticas para anon = denegar todo)
ALTER TABLE pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos FORCE ROW LEVEL SECURITY;
ALTER TABLE estados_pedido_historial ENABLE ROW LEVEL SECURITY;
ALTER TABLE estados_pedido_historial FORCE ROW LEVEL SECURITY;
ALTER TABLE pedido_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedido_items FORCE ROW LEVEL SECURITY;
ALTER TABLE mesas ENABLE ROW LEVEL SECURITY;
ALTER TABLE mesas FORCE ROW LEVEL SECURITY;
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios FORCE ROW LEVEL SECURITY;
ALTER TABLE movimientos_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimientos_caja FORCE ROW LEVEL SECURITY;
ALTER TABLE cajas ENABLE ROW LEVEL SECURITY;
ALTER TABLE cajas FORCE ROW LEVEL SECURITY;
ALTER TABLE auditoria_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE auditoria_logs FORCE ROW LEVEL SECURITY;
ALTER TABLE alertas_riesgo ENABLE ROW LEVEL SECURITY;
ALTER TABLE alertas_riesgo FORCE ROW LEVEL SECURITY;
ALTER TABLE facturas ENABLE ROW LEVEL SECURITY;
ALTER TABLE facturas FORCE ROW LEVEL SECURITY;
ALTER TABLE configuracion_fiscal_sucursal ENABLE ROW LEVEL SECURITY;
ALTER TABLE configuracion_fiscal_sucursal FORCE ROW LEVEL SECURITY;
ALTER TABLE asignaciones_domicilio ENABLE ROW LEVEL SECURITY;
ALTER TABLE asignaciones_domicilio FORCE ROW LEVEL SECURITY;
ALTER TABLE ofertas_pedido ENABLE ROW LEVEL SECURITY;
ALTER TABLE ofertas_pedido FORCE ROW LEVEL SECURITY;
ALTER TABLE ingredientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredientes FORCE ROW LEVEL SECURITY;
ALTER TABLE movimientos_ingrediente ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimientos_ingrediente FORCE ROW LEVEL SECURITY;
ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos FORCE ROW LEVEL SECURITY;
ALTER TABLE categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE categorias FORCE ROW LEVEL SECURITY;
ALTER TABLE suscripciones_restaurante ENABLE ROW LEVEL SECURITY;
ALTER TABLE suscripciones_restaurante FORCE ROW LEVEL SECURITY;

-- Catálogo público (solo lectura vía API NestJS; bloquear acceso directo anon)
ALTER TABLE ciudades ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE sucursales ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE pedidos IS 'RLS activo — Realtime vía broadcast NestJS, no postgres_changes anon';
