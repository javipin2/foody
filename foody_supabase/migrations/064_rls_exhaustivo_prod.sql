-- P0-08: RLS exhaustivo en tablas public restantes
-- Patron: REVOKE anon/authenticated + ENABLE + FORCE, sin CREATE POLICY = deny-all.
-- NestJS usa DATABASE_URL (postgres, bypass RLS). Cliente Flutter no usa postgres_changes.

-- A) Refuerzo tablas con RLS parcial (028/029/063)
REVOKE ALL ON TABLE ciudades, restaurantes, sucursales,
  ingredientes, productos, categorias, suscripciones_restaurante,
  producciones
  FROM anon, authenticated;

ALTER TABLE ciudades FORCE ROW LEVEL SECURITY;
ALTER TABLE restaurantes FORCE ROW LEVEL SECURITY;
ALTER TABLE sucursales FORCE ROW LEVEL SECURITY;
ALTER TABLE producciones FORCE ROW LEVEL SECURITY;

-- B) Dinero, PII, tokens, permisos
REVOKE ALL ON TABLE pagos_pedido FROM anon, authenticated;
ALTER TABLE pagos_pedido ENABLE ROW LEVEL SECURITY;
ALTER TABLE pagos_pedido FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE pago_pedido_items FROM anon, authenticated;
ALTER TABLE pago_pedido_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE pago_pedido_items FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE gastos FROM anon, authenticated;
ALTER TABLE gastos ENABLE ROW LEVEL SECURITY;
ALTER TABLE gastos FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE cuentas_por_cobrar FROM anon, authenticated;
ALTER TABLE cuentas_por_cobrar ENABLE ROW LEVEL SECURITY;
ALTER TABLE cuentas_por_cobrar FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE pagos_suscripcion FROM anon, authenticated;
ALTER TABLE pagos_suscripcion ENABLE ROW LEVEL SECURITY;
ALTER TABLE pagos_suscripcion FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE fuentes_pago FROM anon, authenticated;
ALTER TABLE fuentes_pago ENABLE ROW LEVEL SECURITY;
ALTER TABLE fuentes_pago FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE pedidos_idempotencia FROM anon, authenticated;
ALTER TABLE pedidos_idempotencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos_idempotencia FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE roles_permisos FROM anon, authenticated;
ALTER TABLE roles_permisos ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles_permisos FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE tokens_push_admin FROM anon, authenticated;
ALTER TABLE tokens_push_admin ENABLE ROW LEVEL SECURITY;
ALTER TABLE tokens_push_admin FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE tokens_push_domiciliario FROM anon, authenticated;
ALTER TABLE tokens_push_domiciliario ENABLE ROW LEVEL SECURITY;
ALTER TABLE tokens_push_domiciliario FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE dispositivos_cliente FROM anon, authenticated;
ALTER TABLE dispositivos_cliente ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispositivos_cliente FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE configuracion_global_foody FROM anon, authenticated;
ALTER TABLE configuracion_global_foody ENABLE ROW LEVEL SECURITY;
ALTER TABLE configuracion_global_foody FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE domiciliarios_independientes FROM anon, authenticated;
ALTER TABLE domiciliarios_independientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE domiciliarios_independientes FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE documentos_domiciliario FROM anon, authenticated;
ALTER TABLE documentos_domiciliario ENABLE ROW LEVEL SECURITY;
ALTER TABLE documentos_domiciliario FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE domiciliarios_planta FROM anon, authenticated;
ALTER TABLE domiciliarios_planta ENABLE ROW LEVEL SECURITY;
ALTER TABLE domiciliarios_planta FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE domiciliarios_sesiones FROM anon, authenticated;
ALTER TABLE domiciliarios_sesiones ENABLE ROW LEVEL SECURITY;
ALTER TABLE domiciliarios_sesiones FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE domiciliarios_ubicaciones_historial FROM anon, authenticated;
ALTER TABLE domiciliarios_ubicaciones_historial ENABLE ROW LEVEL SECURITY;
ALTER TABLE domiciliarios_ubicaciones_historial FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE ganancias_domiciliario FROM anon, authenticated;
ALTER TABLE ganancias_domiciliario ENABLE ROW LEVEL SECURITY;
ALTER TABLE ganancias_domiciliario FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE calificaciones_domiciliario FROM anon, authenticated;
ALTER TABLE calificaciones_domiciliario ENABLE ROW LEVEL SECURITY;
ALTER TABLE calificaciones_domiciliario FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE respuestas_oferta FROM anon, authenticated;
ALTER TABLE respuestas_oferta ENABLE ROW LEVEL SECURITY;
ALTER TABLE respuestas_oferta FORCE ROW LEVEL SECURITY;

-- C) Operacion: pedidos hijos, inventario, costeo, ops
REVOKE ALL ON TABLE pedido_item_toppings FROM anon, authenticated;
ALTER TABLE pedido_item_toppings ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedido_item_toppings FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE pedido_item_bebidas FROM anon, authenticated;
ALTER TABLE pedido_item_bebidas ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedido_item_bebidas FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE pedido_combo_selecciones FROM anon, authenticated;
ALTER TABLE pedido_combo_selecciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedido_combo_selecciones FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE transferencias_mesa FROM anon, authenticated;
ALTER TABLE transferencias_mesa ENABLE ROW LEVEL SECURITY;
ALTER TABLE transferencias_mesa FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE compras_inventario FROM anon, authenticated;
ALTER TABLE compras_inventario ENABLE ROW LEVEL SECURITY;
ALTER TABLE compras_inventario FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE compra_items FROM anon, authenticated;
ALTER TABLE compra_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE compra_items FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE ajustes_stock FROM anon, authenticated;
ALTER TABLE ajustes_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE ajustes_stock FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE conteos_inventario FROM anon, authenticated;
ALTER TABLE conteos_inventario ENABLE ROW LEVEL SECURITY;
ALTER TABLE conteos_inventario FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE conteo_items FROM anon, authenticated;
ALTER TABLE conteo_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE conteo_items FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE traslados_inventario FROM anon, authenticated;
ALTER TABLE traslados_inventario ENABLE ROW LEVEL SECURITY;
ALTER TABLE traslados_inventario FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE recetas FROM anon, authenticated;
ALTER TABLE recetas ENABLE ROW LEVEL SECURITY;
ALTER TABLE recetas FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE receta_items FROM anon, authenticated;
ALTER TABLE receta_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE receta_items FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE costos_receta FROM anon, authenticated;
ALTER TABLE costos_receta ENABLE ROW LEVEL SECURITY;
ALTER TABLE costos_receta FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE presentaciones_compra FROM anon, authenticated;
ALTER TABLE presentaciones_compra ENABLE ROW LEVEL SECURITY;
ALTER TABLE presentaciones_compra FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE margenes_venta FROM anon, authenticated;
ALTER TABLE margenes_venta ENABLE ROW LEVEL SECURITY;
ALTER TABLE margenes_venta FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE costos_operativos_fijos FROM anon, authenticated;
ALTER TABLE costos_operativos_fijos ENABLE ROW LEVEL SECURITY;
ALTER TABLE costos_operativos_fijos FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE estados_promociones FROM anon, authenticated;
ALTER TABLE estados_promociones ENABLE ROW LEVEL SECURITY;
ALTER TABLE estados_promociones FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE promocion_vistas FROM anon, authenticated;
ALTER TABLE promocion_vistas ENABLE ROW LEVEL SECURITY;
ALTER TABLE promocion_vistas FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE notificaciones_pendientes FROM anon, authenticated;
ALTER TABLE notificaciones_pendientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE notificaciones_pendientes FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE impresion_cocina_jobs FROM anon, authenticated;
ALTER TABLE impresion_cocina_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE impresion_cocina_jobs FORCE ROW LEVEL SECURITY;

-- D) Catalogo y geo (lectura solo via API NestJS)
REVOKE ALL ON TABLE cocinas FROM anon, authenticated;
ALTER TABLE cocinas ENABLE ROW LEVEL SECURITY;
ALTER TABLE cocinas FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE impresoras FROM anon, authenticated;
ALTER TABLE impresoras ENABLE ROW LEVEL SECURITY;
ALTER TABLE impresoras FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE toppings FROM anon, authenticated;
ALTER TABLE toppings ENABLE ROW LEVEL SECURITY;
ALTER TABLE toppings FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE bebidas FROM anon, authenticated;
ALTER TABLE bebidas ENABLE ROW LEVEL SECURITY;
ALTER TABLE bebidas FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE combos FROM anon, authenticated;
ALTER TABLE combos ENABLE ROW LEVEL SECURITY;
ALTER TABLE combos FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE combo_items FROM anon, authenticated;
ALTER TABLE combo_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE combo_items FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE producto_toppings FROM anon, authenticated;
ALTER TABLE producto_toppings ENABLE ROW LEVEL SECURITY;
ALTER TABLE producto_toppings FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE producto_bebidas FROM anon, authenticated;
ALTER TABLE producto_bebidas ENABLE ROW LEVEL SECURITY;
ALTER TABLE producto_bebidas FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE producto_items_incluidos FROM anon, authenticated;
ALTER TABLE producto_items_incluidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE producto_items_incluidos FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE zonas_cobertura FROM anon, authenticated;
ALTER TABLE zonas_cobertura ENABLE ROW LEVEL SECURITY;
ALTER TABLE zonas_cobertura FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE horarios_sucursal FROM anon, authenticated;
ALTER TABLE horarios_sucursal ENABLE ROW LEVEL SECURITY;
ALTER TABLE horarios_sucursal FORCE ROW LEVEL SECURITY;

COMMENT ON SCHEMA public IS 'P0-08 migr.064: RLS+FORCE en tablas de negocio; acceso directo anon bloqueado';
