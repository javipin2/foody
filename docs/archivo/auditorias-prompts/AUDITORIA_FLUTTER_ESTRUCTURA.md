# Foody — Auditoría Flutter estructura general (Prompt 03)

> **Fecha:** 2026-08-05  
> **Alcance:** `lib/` — estado, widgets, memory leaks, navegación, separación UI/API.  
> **Método:** lectura estática (grep + LOC + muestreo). Sin `flutter run` en esta pasada.  
> **Predecesoras:** [`AUDITORIA_ARQUITECTURA_CALIDAD.md`](AUDITORIA_ARQUITECTURA_CALIDAD.md) (Prompt 01, AQ-\*) · [`AUDITORIA_BACKEND_NESTJS.md`](AUDITORIA_BACKEND_NESTJS.md) (Prompt 02, BN-\*).  
> **Sucesora Prompt 04 (REST):** [`AUDITORIA_APIS_REST.md`](AUDITORIA_APIS_REST.md) — API-\* (no confundir con FL-API-\*).  
> **Complemento frontend:** [`frontend/FRONTEND_FLUTTER_ARCHITECTURE.md`](frontend/FRONTEND_FLUTTER_ARCHITECTURE.md) (estado Riverpod 2/10; F9-06 ⏳).  
> **Estado oficial:** hallazgos también en [`MASTER_STATUS.md`](MASTER_STATUS.md) § Flutter estructura (FL-\*).  
> **Al cerrar un FL-\*:** marcar ✅ aquí + MASTER + viñeta en `AVANCE_PROYECTO.md`.

---

## Veredicto

| Dimensión | Nota | Una línea |
|-----------|------|-----------|
| Gestión de estado | D+ | Doc dice Riverpod; realidad = **1** `carritoProvider` + ~535 `setState` |
| Widgets / rebuilds | C− | 15 pantallas >1k LOC; `ref.watch(carrito)` rebuilda menú entero |
| Memory leaks | C | Diálogos inventario TEC sin dispose; Realtime a menudo sin `removeChannel` |
| Navegación | B | Paths únicos; `go('/admin/cajero')` desde panel rompe back-stack |
| Separación UI / API | B− | **0** Dio crudo en widgets; repos embebidos en State + Realtime en UI |

**Global Prompt 03:** ~**62 / 100** disciplina Flutter estructural.

**Qué ya está bien (no rehacer):**

- `ProviderScope` en `main.dart`; sin `MultiProvider` legacy activo.
- HTTP NestJS concentrado en `*Repository` + `cliente_dio.dart` (no Dio en widgets).
- GoRouter único (`app_router.dart`); sin paths duplicados.
- Controllers de pantallas principales (checkout, login, KDS, caja State) sí hacen `dispose`.
- FCM app-lifetime (`ServicioFcmFoody`) sin cancel — correcto para proceso de proceso.
- Storage vía `AlmacenamientoRepository` (excepción documentada Foody).

**Solapes Prompt 01:** FL-WIDGET-06 ≡ AQ-SOLID-06/07 (totales en cliente); god screens ≈ F9-03…05; Riverpod gap = F9-06 / ST-04.

---

## Índice de hallazgos

| Prefijo | Tema | Abiertos (aprox.) |
|---------|------|------------------:|
| FL-STATE-* | Gestión de estado | 10 |
| FL-WIDGET-* | Widgets / rebuilds | 6 |
| FL-LEAK-* | Memory leaks | 6 |
| FL-NAV-* | Navegación | 6 |
| FL-API-* | Separación UI / API | 10 |
| FL-FIX-* | Remediaciones priorizadas | 7 |

Leyenda: `🟣 abierto` · `🟡 parcial / aceptado` · `✅ cerrado` · `📅 post-escala`

---

## 1. Gestión de estado (FL-STATE)

### Realidad vs documentación

| Qué | Código |
|-----|--------|
| Riverpod providers | **1**: `StateNotifierProvider` en `lib/features/pedidos/providers/carrito_provider.dart` |
| Consumidores `ref.watch` | Solo menú / carrito / checkout (cliente) |
| `package:provider` | En `pubspec.yaml`; **0 imports** en `lib/` |
| Bloc / GetX | Ausentes |
| Dominante | `StatefulWidget` + `setState` (~535 en features) + `FutureBuilder` (~23) |
| Sesión staff | `SesionStaffService` imperativo (SharedPreferences), no provider |

```114:114:lib/main.dart
  runApp(const ProviderScope(child: FoodyApp()));
```

Doc oficial: `.cursor/rules/foody-flutter.mdc` + `FRONTEND_FLUTTER_ARCHITECTURE.md` (Riverpod; nota estado **2/10**; F9-06 ⏳).

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **FL-STATE-01** | 🟣 | Alta | Gap doc vs código: Riverpod “oficial” / F9-06; realidad = 1 provider |
| **FL-STATE-02** | 🟣 | Alta | Sin estado compartido pedidos/mesas/caja: cada widget refetch + `setState` |
| **FL-STATE-03** | 🟣 | Media | Mezcla Riverpod + `setState` + `FutureBuilder` en mismas pantallas cliente (`MenuScreenFoody`, `CheckoutScreen`) |
| **FL-STATE-04** | 🟣 | Alta | Carrito calcula totales en cliente (≡ AQ-SOLID-06) — preview; cobro real vía API |
| **FL-STATE-05** | 🟣 | Media | Sesión staff global imperativa, no `sesionStaffProvider` |
| **FL-STATE-06** | 🟡 | Baja | Dominio `setState` masivo — aceptado mientras F9-06 no avance; documentar como convención temporal |
| **FL-STATE-07** | 🟣 | Media | `FutureBuilder` + future mutado en State (stale risk) en kanban/dashboards/menú |
| **FL-STATE-08** | 🟣 | Baja | Dep `provider` huérfana; ChangeNotifier legacy muerto (`lugar_ambient_music_service`) |
| **FL-STATE-09** | ✅ | — | `ValueNotifier` puntual en diálogos — OK local |
| **FL-STATE-10** | 🟣 | Media | POS cajero: carrito local en State, paralelo a `carritoProvider` del cliente |

---

## 2. Widgets — rebuilds y tamaño (FL-WIDGET)

### Top 15 archivos UI (>1k LOC)

| # | LOC≈ | Archivo |
|---|-----:|---------|
| 1 | 2276 | `catalogo/presentation/menu_admin_screen.dart` |
| 2 | 2129 | `admin/presentation/widgets/mesas_grid_widget.dart` |
| 3 | 1907 | `inventario/presentation/inventario_admin_screen.dart` |
| 4 | 1831 | `mesa/presentation/mesa_pedidos_sheet.dart` |
| 5 | 1769 | `admin/presentation/panel_foody_control_screen.dart` |
| 6 | 1652 | `analitica/presentation/analitica_screen.dart` |
| 7 | 1515 | `costeo/presentation/costos_margenes_screen.dart` |
| 8 | 1474 | `caja/presentation/caja_admin_screen.dart` |
| 9 | 1379 | `pedidos/presentation/pedido_cajero_screen.dart` |
| 10 | 1309 | `cocinas/presentation/kds_screen.dart` |
| 11 | 1303 | `admin/presentation/widgets/pedidos_kanban_widget.dart` |
| 12 | 1293 | `domiciliarios/presentation/domiciliarios_admin_screen.dart` |
| 13 | 1196 | `zonas/presentation/zonas_admin_screen.dart` |
| 14 | 1142 | `facturacion/presentation/facturacion_admin_screen.dart` |
| 15 | 1090 | `pedidos/presentation/checkout_screen.dart` |

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **FL-WIDGET-01** | 🟣 | Alta | God screens: fetch + diálogos + realtime + formularios en un `State` (top 15) |
| **FL-WIDGET-02** | 🟣 | Alta | `ref.watch(carritoProvider)` en raíz de `menu_screen_foody.dart:277` y `checkout_screen.dart:495` — sin `.select()`; badge debería ser leaf `Consumer` |
| **FL-WIDGET-03** | 🟣 | Media | `ListView(children:)` masivo (inventario conteo = 1 TextField por ítem; analitica; cajero; kanban) — sin `itemExtent`; OK si N chico, riesgoso si N grande |
| **FL-WIDGET-04** | ✅ | — | No hay `setState` síncrono dentro de `build` |
| **FL-WIDGET-05** | ✅ | — | `AnimatedBuilder` con `child` cacheado (login, splash, stories) |
| **FL-WIDGET-06** | 🟣 | Alta | UI + math de precios (≡ AQ-SOLID-06/07): `linea_carrito`, `carrito_provider.totalPrecio`, `checkout._totalEstimado`, sheets producto/combo, `pedido_cajero._totalVisual` |

---

## 3. Memory leaks (FL-LEAK)

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **FL-LEAK-01** | ✅ | Alta | Diálogos inventario: TEC con `try/finally` dispose (compra/ajuste/lote/conteo) | `inventario_admin_screen.dart` |
| **FL-LEAK-02** | ✅ | Media | Realtime: `FoodyRealtime.liberarCanal` / `removeChannel` en pantallas ops | F7 + kanban/mesa/caja/menú/… |
| **FL-LEAK-03** | 🟡 | Baja | Debounce estático `Timer` en `FoodyRealtime` puede invocar callback post-dispose (~300 ms) | Mitigado si callback chequea `mounted` |
| **FL-LEAK-04** | ✅ | — | Click listener web FCM — lifetime = notificación | Aceptable |
| **FL-LEAK-05** | ✅ | — | `ServicioFcmFoody` listeners app-lifetime | Correcto |
| **FL-LEAK-06** | 🟣 | Baja | Legacy `push_notification_service.dart` paralelo (no init desde `main`); riesgo doble handler si se llama | Deuda muerta |

**OK verificado (muestreo):** checkout TECs, staff login anim+OAuth, splash/story AnimationController, caja TECs+poll, menú admin TabController, KDS `removeChannel`, tracking GPS `detener()`, deep-link services cancelan `_sub`.

**Referencia buena Realtime:** `kds_screen.dart` usa `removeChannel`.

---

## 4. Navegación (FL-NAV)

Router único: `lib/core/rutas/app_router.dart`.

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **FL-NAV-00** | ✅ | — | **Sin paths duplicados** |
| **FL-NAV-01** | 🟣 | Alta | `context.go('/admin/cajero')` desde `mesas_grid_widget.dart:1418` (panel restaurante) **sustituye** el stack y pierde `/admin/panel` |
| **FL-NAV-02** | 🟡 | Media | Paywall `push('/admin/mejorar-plan')` → redirect a `?seccion=mejorar_plan` — funciona pero engañoso |
| **FL-NAV-03** | ✅ | — | Post-checkout `go` a seguimiento limpia stack (intencional) |
| **FL-NAV-04** | ✅ | — | Bottom nav / roles con `go` — correcto para shells |
| **FL-NAV-05** | 🟡 | Media | Con mesa activa, redirect bloquea **cualquier** `/menu/:id` (incluso otra sucursal); `errorBuilder` mesa puede doble-navegar |
| **FL-NAV-06** | ✅ | — | Login staff con `go` (no push encima de panel) — bien |

**Sin rutas huérfanas claras** en el muestreo (todas las paths principales tienen navegación o son initial/redirect).

---

## 5. Separación lógica / UI — ¿API en widgets? (FL-API)

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **FL-API-01** | ✅ | — | **0** llamadas Dio / `.get|.post` crudas en `presentation/` / `*_screen|widget|sheet` |
| **FL-API-02** | 🟣 | Media | Anti-patrón: `final _repo = XRepository()` como campo del State (no DI / difícil de testear) — decenas de pantallas |
| **FL-API-03** | 🟣 | Media | Realtime/Supabase lifecycle acoplado a UI (`FoodyRealtime.suscribir*` en widgets) |
| **FL-API-04** | 🟡 | Baja | Uploads Storage orquestados en pantallas admin vía repo (OK regla Foody; lógica de flujo en UI) |
| **FL-API-05** | 🟣 | Media | Estructura features irregular (ver tabla abajo) |
| **FL-API-06** | 🟣 | Media | Costeo sin `data/`: usa repos de inventario/catálogo (cross-feature) |
| **FL-API-07** | 🟣 | Baja | Dos repos mesa: `mesa_repository` (QR público) vs `mesas_repository` (staff) — naming confuso |
| **FL-API-08** | 🟡 | Baja | `realtime_aviso_banner` instancia `SaludRepository()` directo |
| **FL-API-09** | 🟡 | Baja | OAuth: presentación → services domain → `Supabase.auth` (no Dio; domain “gordo”) |
| **FL-API-10** | ✅ | — | Repos NestJS concentran Dio bajo `features/*/data/` |

### Features — capas (FL-API-05)

| Feature | data | domain | presentation | Nota |
|---------|:----:|:------:|:------------:|------|
| pedidos | ✓ | ✓ | ✓ | + `providers/` (único) |
| admin, auth, menu, ciudades, restaurantes, pagos | ✓ | ✓ | ✓ | domain a menudo = models |
| alertas, analitica, caja, catalogo, cocinas, domiciliarios, facturacion, inventario, mesa, promociones, reportes, sucursales, usuarios, zonas | ✓ | — | ✓ | sin domain tipado |
| **costeo** | — | ✓ | ✓ | data prestada |
| **cliente**, **splash** | — | — | ✓ | shell UI |
| **almacenamiento**, **auditoria** | ✓ | — | — | solo data shared |

---

## 6. Backlog remediación (FL-FIX)

| ID | Estado | Acción | Cierra |
|----|--------|--------|--------|
| **FL-FIX-01** | ✅ | `try/finally { ctrl.dispose() }` en diálogos inventario + conteo cancelado | FL-LEAK-01 |
| **FL-FIX-02** | ✅ | Unificar dispose Realtime: `FoodyRealtime.liberarCanal` | FL-LEAK-02 |
| **FL-FIX-03** | 🟣 | Leaf `Consumer` / `ref.watch(carritoProvider.select(...))` para badge menú | FL-WIDGET-02 |
| **FL-FIX-04** | 🟣 | No `go('/admin/cajero')` desde panel completo — `push` o `?seccion=` / deep-link rol | FL-NAV-01 |
| **FL-FIX-05** | 🟣 | F9-06: providers `pedidosActivos` / `mesas` / `cajaActiva` (reduce refetch) | FL-STATE-01/02/07 |
| **FL-FIX-06** | 🟣 | Totales preview vía API o marcar UI-only (≡ AQ-FIX-03) | FL-WIDGET-06, FL-STATE-04 |
| **FL-FIX-07** | 🟣 | Split god screens (F9-03…05): menú admin, mesas grid, inventario, sheet mesa | FL-WIDGET-01 |

**Después:** quitar dep `provider` (FL-STATE-08); alinear paywall nav (FL-NAV-02); naming repos mesa (FL-API-07); borrar legacy FCM (FL-LEAK-06).

---

## 7. Cómo verificar al remediar

| Cambio | Evidencia |
|--------|-----------|
| Leaks inventario | Abrir/cancelar diálogo compra ×10; profile memory o assert dispose en test widget |
| Realtime | Salir de KDS/kanban/mesas; log canales Supabase = 0 residuales |
| Badge carrito | Añadir ítem en menú: solo badge rebuild (DevTools timeline) |
| Nav cajero | Desde panel → Modo caja → back vuelve a panel |
| Riverpod F9-06 | Dos tabs admin ven mismo pedido sin refetch manual |

Scripts útiles: `dart analyze` paths tocados; smoke manual flavors `equipo`/`cliente`.

---

## Changelog de este documento

| Fecha | Cambio |
|-------|--------|
| 2026-08-05 | Enlace a Prompt 04 (`AUDITORIA_APIS_REST.md`) |
| 2026-08-05 | **Creación** Prompt 03 — FL-STATE/WIDGET/LEAK/NAV/API + FL-FIX-01…07; enlazado MASTER / AVANCE / README / Prompt 01 |

---

*Fin — Auditoría Flutter estructura (Prompt 03).*
