-- Foody — Fiado / liquidación de domiciliario de planta
-- Escenario: restaurante saturado; el domiciliario se lleva el pedido sin cobrar
-- en caja. El efectivo que recoge queda "en la calle" a su nombre y se liquida
-- (entra a caja) cuando regresa. Reutiliza cuentas_por_cobrar como cuenta del domi.

-- Flag por sucursal: permitir dejar domicilios "a cuenta" del domiciliario.
ALTER TABLE sucursales
  ADD COLUMN IF NOT EXISTS permite_fiado_domiciliario boolean DEFAULT false;

-- Cuenta por cobrar puede pertenecer a un domiciliario de planta (dinero en tránsito).
ALTER TABLE cuentas_por_cobrar
  ADD COLUMN IF NOT EXISTS domiciliario_planta_id uuid REFERENCES domiciliarios_planta(id);

CREATE INDEX IF NOT EXISTS idx_cxc_domiciliario_pendiente
  ON cuentas_por_cobrar (domiciliario_planta_id, sucursal_id)
  WHERE estado = 'pendiente' AND domiciliario_planta_id IS NOT NULL;
