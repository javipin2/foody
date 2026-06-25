-- Completa RLS bloque 4 (028 falló a mitad por nombre de tabla inventario)
REVOKE ALL ON TABLE movimientos_ingrediente FROM anon, authenticated;
ALTER TABLE movimientos_ingrediente ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimientos_ingrediente FORCE ROW LEVEL SECURITY;
ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos FORCE ROW LEVEL SECURITY;
ALTER TABLE categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE categorias FORCE ROW LEVEL SECURITY;
ALTER TABLE suscripciones_restaurante ENABLE ROW LEVEL SECURITY;
ALTER TABLE suscripciones_restaurante FORCE ROW LEVEL SECURITY;
ALTER TABLE ciudades ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE sucursales ENABLE ROW LEVEL SECURITY;
