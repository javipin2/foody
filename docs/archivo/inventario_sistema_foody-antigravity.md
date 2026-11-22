# Inventario del sistema Foody (backend + referencia Flutter)

> **Verificado contra código:** 2026-06-24 — revisión post-Antigravity (diff con versión original documentado en §12).
> Fuente de registro de módulos raíz: `foody_backend/src/app.module.ts`.

---

## 1. MÓDULOS BACKEND

### 1.1 Registrados en `app.module.ts` (31 imports)

| # | Módulo | Archivo | Responsabilidad |
|---|--------|---------|-----------------|
| 1 | **Database** | `src/core/database/database.module.ts` | Pool PostgreSQL (`@Global`) |
| 2 | **Realtime** | `src/core/realtime/realtime.module.ts` | Supabase Broadcast |
| 3 | **Auth** | `src/core/auth/auth.module.ts` | JWT, guards, planes, Supabase OAuth |
| 4 | **Salud** | `src/modulos/salud/salud.module.ts` | `GET /salud`, `GET /health/realtime` |
| 5 | **Ciudades** | `src/modulos/ciudades/ciudades.module.ts` | Listado público ciudades/restaurantes |
| 6 | **Restaurantes** | `src/modulos/restaurantes/restaurantes.module.ts` | `GET /restaurantes/:id/sucursales`, staff `/sucursales/*` |
| 7 | **Menu** | `src/modulos/menu/menu.module.ts` | Menú público cliente QR |
| 8 | **Dashboard** | `src/modulos/dashboard/dashboard.module.ts` | `GET /dashboard/resumen` |
| 9 | **Pedidos** | `src/modulos/pedidos/pedidos.module.ts` | Núcleo transaccional |
| 10 | **Dispositivos** | `src/modulos/dispositivos/dispositivos.module.ts` | `device_id` clientes |
| 11 | **Mesas** | `src/modulos/mesas/mesas.module.ts` | CRUD, QR, transferencia, reservas |
| 12 | **SuperAdmin** | `src/modulos/super-admin/super-admin.module.ts` | Panel global `/super/*` |
| 13 | **Caja** | `src/modulos/caja/caja.module.ts` | Turnos y movimientos |
| 14 | **Catalogo** | `src/modulos/catalogo/catalogo.module.ts` | Productos, categorías, combos, toppings, bebidas |
| 15 | **Cocinas** | `src/modulos/cocinas/cocinas.module.ts` | Estaciones, impresoras, KDS (`/cocina/*`) |
| 16 | **Inventario** | `src/modulos/inventario/inventario.module.ts` | Ingredientes, compras, conteos, traslados |
| 17 | **Domiciliarios** | `src/modulos/domiciliarios/domiciliarios.module.ts` | Planta, independientes, dispatch |
| 18 | **Reportes** | `src/modulos/reportes/reportes.module.ts` | Financiero, productos, pedidos |
| 19 | **Alertas** | `src/modulos/alertas/alertas.module.ts` | `alertas_riesgo` operativas |
| 20 | **Usuarios** | `src/modulos/usuarios/usuarios.module.ts` | CRUD staff por restaurante |
| 21 | **Facturacion** | `src/modulos/facturacion/facturacion.module.ts` | Config fiscal, borradores (enterprise) |
| 22 | **Zonas** | `src/modulos/zonas/zonas.module.ts` | Polígonos cobertura, cotización domicilio |
| 23 | **Promociones** | `src/modulos/promociones/promociones.module.ts` | Banners, códigos, stories |
| 24 | **Costeo** | `src/modulos/costeo/costeo.module.ts` | Subrecetas, recálculo, impacto stock |
| 25 | **Geografia** | `src/modulos/geografia/geografia.module.ts` | **Solo** geocoding Photon (`GET /geografia/buscar`) |
| 26 | **Notificaciones** | `src/modulos/notificaciones/notificaciones.module.ts` | FCM + cola (`@Global`) |
| 27 | **Auditoria** | `src/modulos/auditoria/auditoria.module.ts` | Timeline lectura (`GET /auditoria/timeline`) |
| 28 | **SuscripcionesCron** | `src/core/suscripciones/suscripciones-cron.module.ts` | Vencimiento planes (cron interno) |
| 29 | **Pagos** | `src/modulos/pagos/pagos.module.ts` | Wompi suscripciones |

### 1.2 Submódulos `core/` (no en `app.module.ts`; importados por otros)

| Módulo | Archivo | Importado por |
|--------|---------|---------------|
| **Onboarding** | `src/core/onboarding/onboarding.module.ts` | `AuthModule` → `OnboardingRestauranteService` |
| **Impresion** | `src/core/impresion/impresion.module.ts` | `PedidosModule` → `ImpresionService` (cola `impresion_cocina_jobs`) |

### 1.3 Módulo planificado ausente en código

| Spec | Estado |
|------|--------|
| `analitica` / Centro de Análisis (`docs/MODULO_ANALITICA_BI.md`) | **No existe** en `foody_backend/src/`; parcialmente cubierto por `ReportesModule` |

---

## 2. PANTALLAS FLUTTER (`lib/features/`) — referencia

> Inventario original Antigravity: **parcial**. Rutas legacy en `lib/screens/` siguen coexistiendo.

### Auth
| Pantalla | Archivo |
|----------|---------|
| Login staff | `lib/features/auth/presentation/staff_login_screen.dart` |
| Registro restaurante | `lib/features/auth/presentation/restaurante_registro_screen.dart` |

### Admin / paneles
| Pantalla | Archivo |
|----------|---------|
| Foody Control (super) | `lib/features/admin/presentation/panel_foody_control_screen.dart` |
| Panel restaurante | `lib/features/admin/presentation/panel_restaurante_screen.dart` |
| Panel cajero | `lib/features/admin/presentation/panel_cajero_screen.dart` |
| Panel mesero | `lib/features/admin/presentation/panel_mesero_screen.dart` |
| Mejorar plan (Wompi) | `lib/features/pagos/presentation/mejorar_plan_screen.dart` |

### Operación (faltaban en inventario original)
| Pantalla | Archivo |
|----------|---------|
| Alertas admin | `lib/features/alertas/presentation/alertas_admin_screen.dart` |
| Usuarios staff | `lib/features/usuarios/presentation/usuarios_admin_screen.dart` |
| Zonas domicilio | `lib/features/zonas/presentation/zonas_admin_screen.dart` |
| Facturación admin | `lib/features/facturacion/presentation/facturacion_admin_screen.dart` |
| Restaurantes ciudad (cliente) | `lib/features/restaurantes/presentation/restaurantes_screen_foody.dart` |
| Splash Foody | `lib/features/splash/presentation/foody_splash_screen.dart` |

### Pedidos, mesa, menú, caja, cocina, inventario, costeo, domi, reportes
*(Sin cambios de ruta respecto al inventario original; archivos verificados en repo.)*

| Área | Archivo principal |
|------|-------------------|
| Kanban cajero | `lib/features/pedidos/presentation/pedido_cajero_screen.dart` |
| KDS | `lib/features/cocinas/presentation/kds_screen.dart` |
| Menú cliente | `lib/features/menu/presentation/menu_screen_foody.dart` |
| Caja | `lib/features/caja/presentation/caja_admin_screen.dart` |
| Inventario | `lib/features/inventario/presentation/inventario_admin_screen.dart` |
| Costeo | `lib/features/costeo/presentation/costos_margenes_screen.dart` |
| Domiciliarios admin | `lib/features/domiciliarios/presentation/domiciliarios_admin_screen.dart` |
| Reportes | `lib/features/reportes/presentation/reportes_admin_screen.dart` |

---

## 3. ROLES

Fuente: `foody_supabase/migrations/002_usuarios.sql`, `026_cocinas_kds.sql`, `008_domiciliarios.sql`

| Rol | Tabla / guard | Notas |
|-----|---------------|-------|
| `admin` | `usuarios.rol` | Todos los permisos en `roles_permisos` |
| `gerente` | `usuarios.rol` | Sin `gestionar_usuarios`, `gestionar_sucursales`, `hacer_retiro_parcial` |
| `cajero` | `usuarios.rol` | Caja + pedidos + reportes |
| `mesero` | `usuarios.rol` | Mesas + aprobar QR |
| `cocina_principal` | `usuarios.rol` | KDS; seed en `026_cocinas_kds.sql` |
| `domiciliario_independiente` | `domiciliarios_independientes` | `DomiciliarioIndependienteGuard` — no fila en `usuarios` staff |
| `super_admin` | `usuarios` + `SuperAdminGuard` | Rutas `/super/*` |
| Cliente QR | `dispositivos_cliente.device_id` | Sin JWT; pedidos vía `PedidosPublicController` |

---

## 4. ENDPOINTS (por prefijo HTTP)

### Auth — `AuthController` → `/auth`

| Método | Ruta | Función |
|--------|------|---------|
| `POST` | `/auth/login` | `login` |
| `POST` | `/auth/login-domiciliario` | `loginDomiciliario` |
| `POST` | `/auth/registro-domiciliario` | `registroDomiciliario` |
| `POST` | `/auth/registro-restaurante` | `registroRestaurante` |
| `POST` | `/auth/login-google` | `loginGoogle` |
| `GET` | `/auth/perfil` | `perfil` (JWT; puede devolver token renovado) |
| `POST` | `/auth/registrar-fcm` | `registrarFcm` |
| `POST` | `/auth/desactivar-fcm` | `desactivarFcm` |

> **Corrección:** no existen `POST /auth/refresh` ni `POST /auth/logout` en `auth.controller.ts`.

### Salud — `SaludModule`

| Método | Ruta | Controlador |
|--------|------|-------------|
| `GET` | `/salud` | `SaludController` |
| `GET` | `/health/realtime` | `HealthController` |

### Ciudades — `CiudadesController` (sin prefijo)

| Método | Ruta | Función |
|--------|------|---------|
| `GET` | `/ciudades` | listar ciudades |
| `GET` | `/ciudades/:slug/restaurantes` | restaurantes por ciudad |

### Geografía — `GeografiaController` → `/geografia`

| Método | Ruta | Función |
|--------|------|---------|
| `GET` | `/geografia/buscar` | `buscar` → Photon/OSM |

### Menú público — `MenuController` → `/menu`

| Método | Ruta | Función |
|--------|------|---------|
| `GET` | `/menu/mesa/:qr_token` | menú por QR mesa |
| `GET` | `/menu/:sucursal_id` | menú por sucursal |

### Pedidos staff — `PedidosController` → `/pedidos` (JWT + guards)

| Método | Ruta | Función |
|--------|------|---------|
| `GET` | `/pedidos` | `listarPorSucursal` |
| `GET` | `/pedidos/mesa/:mesaId` | `listarActivosPorMesa` |
| `POST` | `/pedidos/staff` | `crear` |
| `POST` | `/pedidos/:id/items` | `agregarItems` |
| `DELETE` | `/pedidos/:id/items/:itemId` | `eliminarItemPedido` |
| `PATCH` | `/pedidos/:id/estado` | `cambiarEstado` |
| `POST` | `/pedidos/:id/descuento` | `aplicarDescuento` |
| `POST` | `/pedidos/:id/cobrar` | `cobrarPedidoCaja` |
| `POST` | `/pedidos/mesa/:mesaId/cobrar` | `cobrarCuentaMesa` |
| `PATCH` | `/pedidos/:id/items/:itemId/comensal` | `actualizarComensalItem` |
| `PATCH` | `/pedidos/:id/aprobar` | `aprobarMesa` |
| `PATCH` | `/pedidos/:id/rechazar` | `rechazarMesa` |

### Pedidos público — `PedidosPublicController` → `/pedidos` (sin JWT)

| Método | Ruta | Función |
|--------|------|---------|
| `POST` | `/pedidos` | `crear` (cliente QR / domicilio) |
| `GET` | `/pedidos/mios` | `listarMios` (`device_id`) |
| `GET` | `/pedidos/:id/estado` | `estado` |

### Mesas — `MesasController` → `/mesas`

| Método | Ruta | Permisos | Función |
|--------|------|----------|---------|
| `GET` | `/mesas/:sucursal_id` | `gestionar_mesas`, `ver_mesas`, `ver_pedidos`, `crear_pedido` | `listar` |
| `POST` | `/mesas` | `gestionar_mesas` | `crear` |
| `PATCH` | `/mesas/:id` | `gestionar_mesas` | `actualizar` |
| `DELETE` | `/mesas/:id` | `gestionar_mesas` | `desactivar` |
| `GET` | `/mesas/:id/qr` | `gestionar_mesas` | `qr` |
| `POST` | `/mesas/asignar-turno` | `gestionar_mesas` | `asignarTurno` |
| `POST` | `/mesas/transferir` | `gestionar_mesas` | `transferir` |
| `POST` | `/mesas/:id/reservar` | `gestionar_mesas` | `reservar` |
| `POST` | `/mesas/:id/cancelar-reserva` | `gestionar_mesas` | `cancelarReserva` |
| `POST` | `/mesas/unir` | `gestionar_mesas` | `unir` |
| `POST` | `/mesas/:id/salio-sin-pagar` | `gestionar_mesas`, `ver_caja` | `salioSinPagar` → `MesasService.registrarSalidaSinPagar` |

### Caja — `CajaController` → `/caja`

| Método | Ruta | Función |
|--------|------|---------|
| `GET` | `/caja/activa/:sucursal_id` | `obtenerActiva` |
| `POST` | `/caja/abrir` | `abrir` |
| `POST` | `/caja/cerrar` | `cerrar` |
| `GET` | `/caja/cuentas-por-cobrar/:sucursal_id` | `listarCuentasPorCobrar` |
| `POST` | `/caja/cuentas-por-cobrar` | `crearCuentaPorCobrar` |
| `PATCH` | `/caja/cuentas-por-cobrar/:id/pagar` | `pagarCuentaPorCobrar` |
| `GET` | `/caja/:caja_id/movimientos` | `listarMovimientos` |
| `POST` | `/caja/retiro-parcial` | `retiroParcial` |
| `POST` | `/caja/devolucion` | `registrarDevolucion` |
| `POST` | `/caja/gastos` | `registrarGasto` |

### Catálogo

| Prefijo | Controlador | CRUD |
|---------|-------------|------|
| `/productos` | `ProductosController` | listar, crear, patch, disponibilidad, toppings, bebidas, items-incluidos |
| `/categorias` | `CategoriasController` | CRUD |
| `/toppings` | `ToppingsController` | CRUD |
| `/bebidas` | `BebidasController` | CRUD |
| `/combos` | `CombosController` | listar, crear, disponibilidad |

### Inventario — `InventarioController` → `/inventario` (`@RequiereModulo('inventario')`)

Rutas verificadas en `inventario.controller.ts`: listar/crear/patch ingredientes, movimientos, costos, receta producto, compras, conteos, traslados, resumen hermanas.

### Costeo — `CosteoController` → `/costeo` (`@RequiereModulo('costeo')`)

| Método | Ruta |
|--------|------|
| `GET` | `/costeo/resumen/:sucursal_id` |
| `GET` | `/costeo/subrecetas/:sucursal_id` |
| `GET` | `/costeo/subrecetas/detalle/:id` |
| `GET` | `/costeo/combos/:sucursal_id` |
| `POST` | `/costeo/recalcular/:sucursal_id` |
| `GET` | `/costeo/productos/:id/impacto-stock` |
| `POST` | `/costeo/productos/:id/recalcular` |
| `POST` | `/costeo/combos/:id/recalcular` |
| `POST` | `/costeo/subrecetas` |
| `PATCH` | `/costeo/subrecetas/:id` |
| `POST` | `/costeo/subrecetas/:id/recalcular` |

### Cocinas + KDS + impresoras

| Prefijo | Controlador | Notas |
|---------|-------------|-------|
| `/cocinas` | `CocinasController` | CRUD estaciones |
| `/impresoras` | `ImpresorasController` | CRUD impresoras |
| `/cocina` | `CocinaTicketsController` | `GET tickets/:cocina_id`, `PATCH items/:item_id/estado` (KDS) |

### Domiciliarios — tres controladores en `domiciliarios.controller.ts`

| Prefijo | Rutas clave |
|---------|-------------|
| `/domiciliarios-planta` | `GET disponibles/:sucursal_id`, `POST asignar`, `POST dispatch-independiente/:pedido_id` |
| `/domiciliario` | `GET pedidos-asignados`, `PATCH pedidos/:id/en-camino`, `PATCH pedidos/:id/confirmar-entrega`, historial, estadísticas |
| `/domiciliarios` | sesión independiente, ofertas, pedidos activos, ganancias |

### Zonas — `ZonasController` → `/zonas`

`GET cotizar-domicilio` (público), CRUD zonas, configuración mapa, ubicación sucursal.

### Reportes — `/reportes` · Auditoría — `GET /auditoria/timeline` · Alertas — `/alertas/*`

### Facturación — `/facturacion` (`@RequiereModulo('facturacion')`)

`config`, `facturas`, `emitir/:pedido_id`, `anular/:factura_id`, PDF.

### Pagos — `/pagos`

`checkout`, `estado`, `sincronizar`, `webhook-wompi` (público rate-limit).

### Dispositivos — `/dispositivos`

`POST registrar`, `DELETE anonimizar/:device_id`.

### Dashboard — `/dashboard`

| Método | Ruta | Función |
|--------|------|---------|
| `GET` | `/dashboard/resumen?sucursal_id=` | `DashboardService.resumen` |

> **Corrección:** no es `GET /dashboard/:sucursal_id`.

### Super Admin — `SuperAdminController` → `/super` (no `/super-admin`)

Resumen, ciudades, restaurantes, sucursales, suscripciones, usuarios, domiciliarios, configuración global.

### Restaurantes / sucursales staff

| Prefijo | Rutas |
|---------|-------|
| `/restaurantes` | `GET :id/sucursales` |
| `/sucursales` | `mi-restaurante`, crear sucursal, horarios |

### Promociones — `/promociones`

Público: stories por ciudad, validar código. Admin: CRUD por sucursal.

### Notificaciones — `/notificaciones`

`diagnostico`, `procesar-cola`, `prueba`, `prueba-web`.

---

## 5. TABLAS PostgreSQL (por migración)

### Geografía / estructura (`001_geografia.sql`)
`ciudades`, `restaurantes`, `sucursales`, `zonas_cobertura`, `horarios_sucursal`

### Usuarios (`002_usuarios.sql`, `003_dispositivos.sql`)
`usuarios`, `roles_permisos`, `dispositivos_cliente`, **`tokens_push_admin`** (no `tokens_push_usuario`)

### Catálogo (`004_catalogo.sql`)
`cocinas`, `impresoras`, `categorias`, `productos`, `toppings`, `bebidas`, `producto_toppings`, `producto_bebidas`, `combos`, `combo_items`

### Pedidos (`005_pedidos.sql`, `034_producto_items_incluidos.sql`, `047_*`)
`mesas`, `pedidos`, `pedido_items`, `pedido_item_toppings`, `pedido_item_bebidas`, `pedido_combo_selecciones`, `estados_pedido_historial`, `transferencias_mesa`, `margenes_venta`, `producto_items_incluidos`, **`pagos_pedido`**, **`pago_pedido_items`**, **`pedidos_idempotencia`**

### Inventario (`006_inventario.sql`, `047_*`)
`ingredientes`, `presentaciones_compra`, `compras_inventario`, `compra_items`, `movimientos_ingrediente`, `recetas`, `receta_items`, `costos_receta`, `ajustes_stock`, `conteos_inventario`, `conteo_items`, **`traslados_inventario`**

### Caja (`007_caja.sql`)
`cajas`, `movimientos_caja`, `gastos`, `cuentas_por_cobrar`, `costos_operativos_fijos`

### Domiciliarios (`008_domiciliarios.sql`, `050_tokens_push_domiciliario.sql`)
`domiciliarios_independientes`, `documentos_domiciliario`, `domiciliarios_planta`, `domiciliarios_sesiones`, `ofertas_pedido`, `respuestas_oferta`, `asignaciones_domicilio`, `domiciliarios_ubicaciones_historial`, `ganancias_domiciliario`, `calificaciones_domiciliario`, **`tokens_push_domiciliario`**

### Alertas / auditoría (`009_alertas_auditoria.sql`)
`alertas_riesgo`, `auditoria_logs` (solo INSERT en app)

### Facturación / promociones (`010_facturacion_promociones.sql`)
`configuracion_fiscal_sucursal`, `facturas`, `estados_promociones`, `promocion_vistas`

### Suscripciones (`011_super_admin.sql`, `054_pagos_suscripcion.sql`)
`suscripciones_restaurante`, `configuracion_global_foody`, **`pagos_suscripcion`**

### Infra operativa (`047_escenarios_negocio_brechas.sql`)
**`notificaciones_pendientes`**, **`impresion_cocina_jobs`**

---

## 6. EVENTOS REALTIME

Fuente: `src/core/realtime/realtime-broadcast.service.ts`

| Canal | Evento | Método emisor |
|-------|--------|---------------|
| `sucursal_{id}` | `pedido_actualizado` | `pedidoActualizado` |
| `pedido_{id}` | `estado_actualizado` | `pedidoSeguimiento` |
| `sucursal_{id}` | `mesas_actualizadas` | `mesasActualizadas` |
| `cocina_{id}` | `cocina_actualizada` | `cocinaActualizada` |
| `domiciliario_{usuario_id}` | `pedido_asignado` | `domiciliarioPlantaActualizado` |
| `domiciliario_indep_{id}` | `oferta_nueva` | `domiciliarioIndepOferta` |
| `sucursal_{id}` | `caja_movimiento` | `cajaMovimiento` |
| `sucursal_{id}` | `alerta_nueva` | `alertaNueva` |
| `sucursal_{id}` | `qr_aprobacion_urgente` | `qrAprobacionUrgente` |
| `sucursal_{id}` | `catalogo_disponibilidad` | `catalogoDisponibilidad` |
| `foody_health_check` | `ping` | `verificarConexion` |

Emisores adicionales verificados: `PedidosEstadoService`, `MesasService`, `CajaService`, `CocinasService`, `DomiciliariosService`, `DispatchService.asignarPrimeraPlantaLibre`, `CatalogoDisponibilidadService`, `AlertasRiesgoService`.

---

## 7. SERVICIOS BACKEND (principales)

| Servicio | Archivo | Notas |
|----------|---------|-------|
| `OnboardingRestauranteService` | `core/onboarding/onboarding-restaurante.service.ts` | Registro restaurante + super-admin |
| `ImpresionService` | `core/impresion/impresion.service.ts` | Worker `setInterval` 5s → `impresion_cocina_jobs` |
| `PedidosService` | `modulos/pedidos/pedidos.service.ts` | Fachada |
| `PedidosEstadoService` | `modulos/pedidos/pedidos-estado.service.ts` | Kanban / transiciones (no único escritor de `pedidos.estado`) |
| `PedidosInventarioService` | `modulos/pedidos/pedidos-inventario.service.ts` | **No** `@Injectable`; instanciado con `new` en crear/estado/items |
| `PedidosCajaAuditoriaService` | `modulos/pedidos/pedidos-caja-auditoria.service.ts` | Puente pedidos → `movimientos_caja` + `auditoria_logs` |
| `PedidosPagosService` | `modulos/pedidos/pedidos-pagos.service.ts` | Cobro mesa → `pagos_pedido` |
| `CatalogoDisponibilidadService` | `modulos/catalogo/catalogo-disponibilidad.service.ts` | Stock → `productos.disponible` |
| `CosteoService` | `modulos/costeo/costeo.service.ts` | Hub recetas/costos (5+ consumidores) |
| `DispatchService` | `modulos/domiciliarios/dispatch.service.ts` | Auto-asignación planta + ofertas independientes |
| `AuditoriaService` | `modulos/auditoria/auditoria.service.ts` | **Solo lectura** timeline |
| `NotificacionesService` | `modulos/notificaciones/notificaciones.service.ts` | Cola + FCM (`@Global`) |
| `PlanFeaturesService` | `core/auth/plan-features.service.ts` | Límites y módulos por plan |

*(Resto sin cambios sustanciales respecto al inventario original §7.)*

---

## 8. GUARDS

| Guard | Archivo |
|-------|---------|
| `JwtAuthGuard` | `core/auth/guards/jwt-auth.guard.ts` |
| `RolGuard` | `core/auth/guards/rol.guard.ts` |
| `UsuarioActivoGuard` | `core/auth/guards/usuario-activo.guard.ts` |
| `SuscripcionActivaGuard` | `core/auth/guards/suscripcion-activa.guard.ts` |
| `PlanFeaturesGuard` | `core/auth/guards/plan-features.guard.ts` |
| `DomiciliarioIndependienteGuard` | `core/auth/guards/domiciliario-independiente.guard.ts` |
| `SuperAdminGuard` | `core/auth/guards/super-admin.guard.ts` |
| `RateLimitGuard` | `compartido/guards/rate-limit.guard.ts` (global `APP_GUARD`) |

---

## 9. PLANES Y LÍMITES

Fuente: `src/core/auth/plan-features.config.ts` (`LIMITES_POR_PLAN`, `MODULO_PLAN_MINIMO`)

| Plan | Sucursales | Staff | Mesas | Productos | Ingredientes |
|------|-----------|-------|-------|-----------|-------------|
| `gratis` | 1 | 2 | 2 | 5 | 5 |
| `basico` | 1 | 8 | 30 | 200 | 200 |
| `pro` | 3 | 25 | 100 | 9999 | 9999 |
| `enterprise` | 99 | 99 | 9999 | 9999 | 9999 |

Módulos desde `gratis`: inventario, costeo, cocina, domiciliarios, zonas_domicilio, reportes. Solo `facturacion` requiere `enterprise`.

---

## 10. ESTADOS DEL PEDIDO

Fuente: `src/modulos/pedidos/pedido-estados.ts`

Estados en `TRANSICIONES_PEDIDO`: `pendiente_aprobacion`, `pendiente`, **`confirmado` (legacy BD)**, `en_cocina`, `listo`, `pagando`, `asignado`, `en_camino`, `entregado`, `pagado`, `cancelado`, `rechazado`.

**Reglas verificadas en código:**
- Mesa: `transicionEstadoPermitida` bloquea `entregado` vía Kanban; cierre vía `PedidosPagosService.cobrarCuentaMesa` → estado `pagado`.
- Domicilio: `entregado` solo si `estadoActual === 'en_camino'` (salvo rutas directas en `DomiciliariosService.confirmarEntrega`).
- Domicilio: `pagando` prohibido.

**Escritores de `pedidos.estado` (más de uno):** `PedidosEstadoService`, `CocinasService.cambiarEstadoItem`, `DispatchService`, `DomiciliariosService`, `DomiciliariosIndependientesService`.

---

## 11. DEPENDENCIAS EXTERNAS

Supabase (Auth, Realtime, PostgreSQL), Firebase FCM, Wompi, Google OAuth, Photon (geocoding), Docker dev.

---

## 12. CORRECCIONES vs inventario Antigravity original

| Tema | Antigravity decía | Realidad en código |
|------|-------------------|-------------------|
| `GeografiaModule` | Zonas/polígonos | Solo `GET /geografia/buscar` (Photon). Zonas = `ZonasModule` |
| Auth | `refresh`, `logout` | **No existen** en `auth.controller.ts` |
| Dashboard | `GET /dashboard/:sucursal_id` | `GET /dashboard/resumen?sucursal_id=` |
| Super admin | `/super-admin/*` | Prefijo **`/super`** |
| Salud | solo `/salud` | También **`GET /health/realtime`** |
| Menú | solo `GET /menu/:sucursal_id` | También **`GET /menu/mesa/:qr_token`** |
| KDS | `PATCH /cocina/items/:id/estado` | **`PATCH /cocina/items/:item_id/estado`** (`CocinaTicketsController`) |
| Impresoras | bajo cocinas | Controlador **`/impresoras`** separado |
| Tabla push staff | `tokens_push_usuario` | **`tokens_push_admin`** (`003_dispositivos.sql`) |
| Tablas omitidas | — | `notificaciones_pendientes`, `impresion_cocina_jobs`, `pagos_pedido`, `traslados_inventario`, `pagos_suscripcion` |
| Submódulos | 29 módulos planos | Faltaban **`OnboardingModule`**, **`ImpresionModule`** |
| Costeo API | no documentada | 11 rutas en **`CosteoController`** |
| Auditoría API | no documentada | **`GET /auditoria/timeline`** |
| Auth self-service | no documentada | `registro-restaurante`, `login-google`, FCM |
| Máquina estados | sin `confirmado` | Estado **legacy** en `TRANSICIONES_PEDIDO` |
| Flutter | listado cerrado | Faltaban alertas, usuarios, zonas, facturación, mejorar plan, splash Foody |

### Lo que el inventario original tenía **bien**

- Los 29 módulos de `app.module.ts` (nombres y archivos `.module.ts`).
- Tabla de endpoints **mesas**, **pedidos staff**, **inventario**, **caja**, **domiciliarios** (prefijos planta/independiente).
- Límites plan gratis **2/2/5/5** (alineados a `plan-features.config.ts`).
- Eventos Realtime principales y canales Supabase.
- Desglose de servicios de pedidos (crear, estado, pagos, items, descuento).
- Guards y stack externo.

---

*Documento vivo: actualizar al añadir módulos/rutas en `foody_backend/src/`.*
