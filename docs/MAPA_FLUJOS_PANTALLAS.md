# Mapa de flujos y pantallas por rol

> **Fuente de diseño:** `INFRAESTRUCTURA/foody_flujo_completo_pantallas.html`  
> **Rutas Flutter:** `lib/core/rutas/app_router.dart` · **Redirección login:** `lib/core/rutas/redireccion_staff.dart`  
> **Estado vivo:** `docs/AVANCE_PROYECTO.md`

Este documento enlaza cada pantalla del HTML con su implementación actual y lo que falta.

**Leyenda:** ✅ usable · 🟡 parcial · ⏳ pendiente · 📅 planificado (pospuesto)

---

## Redirección post-login (`dashboard` del backend)

| Rol | `dashboard` API | Ruta Flutter | Shell |
|-----|-----------------|--------------|-------|
| `super_admin` | `foody_control` | `/admin/foody-control` | `PanelFoodyControlScreen` |
| `admin`, `gerente` | `restaurante` | `/admin/panel` | `PanelRestauranteScreen` |
| `cajero` | `cajero` | `/admin/cajero` | `PanelCajeroScreen` |
| `mesero` | `mesero` | `/admin/mesero` | `PanelMeseroScreen` |
| `domiciliario_planta` | `domiciliario` | `/admin/domiciliario` | `DashboardDomiciliarioScreen` |
| `cocina_*` | `cocina` | `/admin/cocina` | `KdsScreen` (standalone) |
| Repartidor independiente | `domiciliario_independiente` | `/domiciliario/independiente` | login propio |

Backend: `foody_backend/src/core/auth/auth.service.ts` → `resolverDashboard()`.

---

## App cliente (sin login)

| ID | Pantalla spec | Ruta / widget | Estado | Falta |
|----|---------------|---------------|--------|-------|
| P01 | Splash / Ciudad | `/splash` → `/cliente` | ✅ | Animación logo Foody completa |
| P02 | Restaurantes + stories | `/ciudades/:slug/restaurantes` | ✅ | `PromocionesCiudadStoriesBar` + cards banner/logo + búsqueda |
| P03 | Menú | `/menu/:sucursalId` · `/mesa/:qrToken` | ✅ | Tab «Encargos 📦» |
| P04 | Detalle producto | modal `DetalleProductoSheet` | ✅ | — |
| P05 | Carrito | `/carrito/:sucursalId` | ✅ | — |
| P06A | Checkout para llevar | `/checkout/:sucursalId` | ✅ | — |
| P06B | Checkout domicilio | mismo checkout (tipo domicilio) | ✅ | GPS + mapa modal + preview inline |
| P06C | Checkout mesa QR | mesa vía query `mesa_id` | ✅ | — |
| P07 | Seguimiento | `/pedidos/:id/seguimiento` | 🟡 | Mapa destino entrega; falta GPS repartidor en vivo (FCM pospuesto) |
| — | Mis pedidos | `/cliente/mis-pedidos` | ✅ | extra vs HTML antiguo |

---

## Cajero / POS

| ID | Pantalla spec | Implementación | Estado | Falta |
|----|---------------|----------------|--------|-------|
| A-CAJ-1 | Apertura caja obligatoria | `PanelCajeroScreen` bloquea POS si no hay caja | ✅ | — |
| A-CAJ-2 | Panel POS (menú + carrito) | `PedidoCajeroScreen` en tab POS | ✅ | Layout dual panel en móvil mejorable |
| A-CAJ-3 | Checkout cajero | diálogo en `PedidoCajeroScreen` | ✅ | Descuento % + motivo → `POST .../descuento` |
| A-CAJ-4 | Movimientos | tab Caja → `CajaAdminScreen` | ✅ | — |
| A-CAJ-5 | Cierre / arqueo | `CajaAdminScreen` | ✅ | Alerta visual >$5k en UI |

**Ruta:** `/admin/cajero` · **Demo:** crear usuario rol `cajero` en Foody Control.

---

## Mesero

| ID | Pantalla spec | Implementación | Estado | Falta |
|----|---------------|----------------|--------|-------|
| A-MES-1 | Vista mesas (grid colores) | tab Mesas → `MesasGridWidget` + leyenda | ✅ | — |
| A-MES-2 | Aprobación pedido QR | modal en `MesasGridWidget` | ✅ | Timer 3/5 min + push recordatorio |
| A-MES-3 | Pedidos activos mesa | `MesaPedidosSheet` en tap mesa ocupada | ✅ | Ítems con estado cocina + total mesa + marcar pagando |
| A-MES-4 | Transferencia mesa | long-press / menú en mesas | ✅ | — |

**Ruta:** `/admin/mesero` · **Demo:** usuario rol `mesero` en Foody Control.

---

## Cocina / KDS

| ID | Pantalla spec | Implementación | Estado | Falta |
|----|---------------|----------------|--------|-------|
| C01 | Login cocina | `/admin/login` → `/admin/cocina` | ✅ | — |
| C02 | KDS principal | `KdsScreen` | ✅ | Sonido/vibración ticket nuevo + badge minutos + alerta >20 min |
| C03 | Detalle ticket | expandir en KDS | 🟡 | Alerta visual >20 min |

---

## Admin / gerente

| ID | Pantalla spec | Sección sidebar (`PanelRestauranteScreen`) | Estado |
|----|---------------|---------------------------------------------|--------|
| A02 | Dashboard | `dashboard` → `DashboardResumenWidget` | 🟡 |
| A-KAN | Kanban pedidos | `pedidos` | ✅ |
| A-MEN | Gestión menú | `menu` | 🟡 |
| A-INV | Inventario | `insumos`, `costos_margenes` | 🟡 |
| A-DOM | Domiciliarios | `domiciliarios` | 🟡 |
| A-REP | Reportes | `reportes` | 🟡 |
| A-USU | Usuarios sucursal | `usuarios` | 🟡 |
| A-COC | Cocinas | `cocinas`, `cocina_kds` | ✅ |
| A-ALE | Alertas | `alertas` | 🟡 |
| A-SUC | Sucursales | `sucursales`, `horarios`, `zonas` | 🟡 |

**Ruta:** `/admin/panel` · Deep link: `/admin/panel?seccion=pedidos`

Sidebar agrupado: `menu_admin_grupo.dart` + `panel_sidebar_nav.dart`.

---

## Domiciliario

| ID | Pantalla spec | Implementación | Estado | Falta |
|----|---------------|----------------|--------|-------|
| D-REG | Registro independiente | `/domiciliario/registro` → `/domiciliario/espera` | ✅ | `POST /auth/registro-domiciliario` |
| D02 | Inicio turno + GPS | independiente dashboard | 🟡 | GPS cada 30s |
| D03 | Oferta 60s (FCM) | backend dispatch | 🟡 | Push FCM + overlay emergente |
| D04 | Pedido activo / estados | `DashboardDomiciliarioIndependienteScreen` | 🟡 | Mapa navegación |
| D-PL-1 | Pedidos planta | `DashboardDomiciliarioScreen` | ✅ | Mapa pequeño |
| D-PL-2 | Historial planta | tab en `DashboardDomiciliarioScreen` | ✅ | `GET /domiciliario/historial` + `/estadisticas` |

**Rutas:** `/admin/domiciliario` (planta) · `/domiciliario/independiente`

---

## Super Admin (Foody Control)

| ID | Pantalla spec | Sección Foody Control | Estado |
|----|---------------|----------------------|--------|
| F01 | Dashboard global | `resumen` | ✅ |
| F02 | Ciudades | `ciudades` | ✅ |
| F03 | Restaurantes + onboarding | `restaurantes` | ✅ |
| F04 | Suscripciones / planes | `planes` | 🟡 plan = metadata (ver `PLANES_SUSCRIPCION.md`) |
| F05 | Usuarios globales | `usuarios` | ✅ |
| F06 | Config global | `config` | ✅ |
| F07 | Domiciliarios + docs | `repartidores` | 🟡 |

**Ruta:** `/admin/foody-control` · **Demo:** `super@foody.demo` / `123456`

---

## Pospuesto por acuerdo (no en HTML o explícito en avance)

| Tema | Notas |
|------|--------|
| FCM / push | Ofertas domiciliario, recordatorios mesero |
| GPS tiempo real cliente | Seguimiento P07 |
| Registro domiciliario D-REG | ✅ `/domiciliario/registro` |
| Planes comerciales con límites | `docs/PLANES_SUSCRIPCION.md` |

---

## Cómo probar cada rol

1. Reiniciar backend (dashboard cajero/mesero en login).
2. Foody Control → Usuarios → crear staff con rol y sucursal.
3. `/admin/login` con ese usuario → debe ir al shell correcto.
4. Cliente: `/splash` o `/cliente` sin sesión staff.

---

## Próximas mejoras sugeridas (orden)

1. ~~Stories/promos en P02~~ ✅
2. ~~Checkout domicilio con mapa/GPS (P06B)~~ ✅
3. ~~Descuento en checkout cajero (A-CAJ-3)~~ ✅
4. ~~Historial domiciliario planta (D-PL-2)~~ ✅
5. ~~Registro domiciliario independiente (D-REG)~~ ✅
6. GPS repartidor en vivo (P07 + FCM, pospuesto salvo petición).
