# Foody — Auditoría Flutter (Senior Engineer)

> **Alcance:** `lib/features/`, `lib/core/`, widgets compartidos  
> **Última actualización:** 2026-07-02  
> **Complementa:** `FRONTEND_DESIGN_AUDIT.md`, `FRONTEND_RESPONSIVE_STRATEGY.md`, `FRONTEND_NAVIGATION_MAP.md`

---

## Resumen ejecutivo

| Dimensión | Nota | Veredicto |
|-----------|:----:|-----------|
| Clean Architecture | **5/10** | Capas `data/domain/presentation` existen pero UI acapara lógica |
| Modularización | **4/10** | 6 «god files» >1000 LOC; panel super en un solo archivo |
| Reutilización | **5/10** | `operacion_ui` bien; resto copy-paste masivo |
| Estado (Riverpod) | **2/10** | Solo `carritoProvider`; todo lo demás `setState` |
| Performance | **6/10** | `ListView.builder` mayoría OK; timers agresivos y `shrinkWrap` en listas largas |
| Mantenibilidad | **5/10** | Funcional; costoso evolucionar sin romper |

**Veredicto:** MVP técnicamente sólido en integración API; **deuda estructural alta** para escalar equipo o features.

---

## Inventario de código UI

| Métrica | Valor |
|---------|------:|
| Archivos en `lib/features/` | ~110 |
| Pantallas (`*screen*.dart`) | 40 |
| Providers Riverpod | **1** (`carrito_provider.dart`) |
| Usos `setState` en features | **~200+** |
| `FutureBuilder` en UI | 14 archivos |
| `NumberFormat.currency` duplicado | **20+** archivos |
| Widgets compartidos maduros | `operacion_ui`, `foody_control_ui`, parcial `costeo_ui_bloques` |

---

## Widgets gigantes (god files)

Archivos que mezclan UI + negocio + diálogos + API en un solo lugar. **Objetivo:** &lt;400 LOC por archivo de pantalla; extraer sub-widgets y controllers.

| LOC | Archivo | Problema |
|----:|---------|----------|
| **1864** | `panel_foody_control_screen.dart` | 7 vistas + 3 diálogos + CRUD inline |
| **1665** | `mesas_grid_widget.dart` | Grid + QR PDF + cobro + realtime + 24 sheets |
| **1569** | `mesa_pedidos_sheet.dart` | Cobro split + CxC + pedidos en un sheet |
| **1273** | `inventario_admin_screen.dart` | 5 tabs + forms + conteo |
| **1242** | `pedidos_kanban_widget.dart` | Kanban + grid + domi assign |
| **1136** | `caja_admin_screen.dart` | Apertura + movimientos + fiados + cierre |
| **1055** | `menu_admin_screen.dart` | 4 tabs CRUD + imágenes |
| **1016** | `receta_producto_panel.dart` | Receta completa embebida |
| **955** | `costos_margenes_screen.dart` | Master-detail + tabs detalle |
| **840** | `pedido_cajero_screen.dart` | POS completo |
| **818** | `mejorar_plan_screen.dart` | Paywall + Wompi flow |

**Impacto:** difícil testear, revisar PRs y reutilizar piezas (p. ej. cobro mesa solo existe dentro del sheet).

---

## Código duplicado detectado

| Patrón | Repeticiones | Ubicación típica | Componente faltante |
|--------|-------------|------------------|---------------------|
| `NumberFormat.currency(es_CO)` | 20+ | Todas las pantallas money | `FoodyFormato.moneda` |
| Loading centrado `CircularProgressIndicator` | 40+ | Todas las screens | `FoodyEstadoCarga` |
| Error + botón Reintentar | 15+ | FutureBuilder / catch | `FoodyEstadoError` |
| `mensajeErrorHttp` + SnackBar | 50+ | OK centralizado en `core/red/` | Falta wrapper `FoodySnack.error()` |
| Patrón carga: `_cargando` + `_error` + `_cargar()` | 30+ screens | Admin CRUD | `AsyncNotifier` o mixin |
| Realtime + `PollRealtimeRespaldo` + Timer | mesas, kanban, kds, domi | 4 widgets | `FoodyRealtimeMixin` / service |
| AppBar staff (título + subtítulo rol) | cajero, mesero, panel | 3+ | `FoodyStaffAppBar` |
| Tab shell con `TabController` | 10+ pantallas | inventario, analítica… | `FoodyTabScaffold` |
| Diálogo form ancho fijo 360–420 | 20+ | admin | `FoodyFormDialog` |
| Mapa `Map<String, dynamic>` de API | Mayoría repos UI | Sin modelos tipados | DTO + `fromJson` |

---

## Componentes reutilizables — existentes vs faltantes

### ✅ Reutilizar y extender

| Componente | Archivo | Uso |
|------------|---------|-----|
| `OperacionUi` / `OperacionTarjeta` | `operacion_ui.dart` | Kanban, caja, POS |
| `FoodyControlUi` | `foody_control_ui.dart` | Super admin |
| `PanelSidebarNav` | `panel_sidebar_nav.dart` | Admin shell |
| `ClienteDio` + `RespuestaApi` | `core/red/` | HTTP |
| `mensajeErrorHttp` | `core/red/` | Errores |

### ❌ Crear (prioridad)

| Componente | Propósito |
|------------|-----------|
| `lib/core/ui/foody_formato.dart` | Moneda, fechas |
| `lib/core/ui/foody_estados.dart` | Carga, vacío, error |
| `lib/core/ui/foody_staff_app_bar.dart` | AppBar operación |
| `lib/core/ui/foody_async_body.dart` | Envuelve Future/AsyncValue |
| `lib/core/ui/foody_tab_scaffold.dart` | TabBar + scroll |
| `lib/core/ui/foody_money_text.dart` | Texto precio consistente |
| `lib/features/mesa/widgets/cobro_mesa_panel.dart` | Extraer de sheet |
| `lib/features/mesa/widgets/mesa_grid_tile.dart` | Tile extraído del grid |

---

## Manejo de estados

### Situación actual

```
Riverpod:  carritoProvider únicamente (3 pantallas cliente)
Resto:     StatefulWidget + setState + Future en State
Sesión:    SesionStaffService (imperativo, SharedPreferences)
Realtime:  Inicializado por widget; sin capa unificada
```

### Problemas

| ID | Problema | Ejemplo | Riesgo |
|----|----------|---------|--------|
| ST-01 | **Repository en State** como campo | `_repo = PedidosRepository()` en 35+ widgets | No testable, no swap DI |
| ST-02 | **`setState(() {})` vacío** solo para rebuild | Búsqueda en kanban, inventario | Rebuild completo del árbol |
| ST-03 | **Future almacenado en State** sin invalidación clara | `_future = _cargar()` | Stale data tras sucursal |
| ST-04 | **Sin estado global** pedidos/mesas/caja | Cada pantalla refetch | Datos desincronizados entre tabs |
| ST-05 | **Carrito calcula subtotales** en cliente | `linea_carrito.subtotalPara()` | Display OK; confirmación vía API ✅ |
| ST-06 | **Checkout `_totalEstimado`** en UI | `checkout_screen.dart` | Estimación visual; POST valida ✅ |
| ST-07 | **Múltiples Timer.periodic** con `setState` | Pulso mesas 800ms, reloj kanban 30s | Rebuilds innecesarios |

### Dirección recomendada (sin reescribir todo)

1. **Fase A:** Providers por módulo operativo (`pedidosActivosProvider`, `mesasProvider`, `cajaActivaProvider`) — `AsyncNotifier` + invalidación Realtime.
2. **Fase B:** Mantener `setState` local solo para UI efímera (tab index, sheet abierto).
3. **Fase C:** `ref.listen` para snackbars/errores globales.

---

## Performance y renders

### ListViews

| Patrón | Estado | Archivos |
|--------|--------|----------|
| `ListView.builder` / `GridView.builder` | ✅ Bien | kanban, inventario, kds, menú sliver |
| `ListView(children: [...])` | ⚠️ Mal si lista crece | `mis_pedidos`, `caja` panel lateral, varios admin |
| `shrinkWrap: true` + `NeverScrollableScrollPhysics` | ⚠️ Aceptable listas cortas | `caja_admin` movimientos, dashboard KPI |
| `SliverList` en menú cliente | ✅ Bien | `menu_screen_foody` |

**Riesgo:** `caja_admin` con muchos movimientos en turno largo → layout de toda la lista en memoria.

### Scrolls incorrectos / anidados

| ID | Ubicación | Problema |
|----|-----------|----------|
| SC-01 | `checkout_screen` | `ListView` largo + teclado; usa `viewInsets` ✅ |
| SC-02 | `mesa_pedidos_sheet` | `SingleChildScrollView` + contenido denso; sin `DraggableScrollableSheet` |
| SC-03 | `panel_restaurante` dashboard | `SingleChildScrollView` > `Column` > widgets con grids shrinkWrap — OK para dashboard |
| SC-04 | Kanban horizontal + vertical anidados | Scroll horizontal columnas; OK patrón Trello |
| SC-05 | `menu_screen` categorías | `ListView` horizontal en `Sliver` — OK |

### Renders innecesarios

| Causa | Archivo | Fix |
|-------|---------|-----|
| Timer 800ms toggle `_pulso` | `mesas_grid_widget` | `AnimatedOpacity` solo en tile QR pendiente |
| Timer 30s reloj kanban | `pedidos_kanban_widget` | `ValueListenableBuilder` por tarjeta o `Stream` |
| `onChanged: (_) => setState(() {})` | Búsquedas | `debounce` + provider filtrado |
| `KeyedSubtree` sucursal en panel | `panel_restaurante` | ✅ Correcto — fuerza remount al cambiar sede |
| Falta `const` en hijos estáticos | Global | Pasar linter `prefer_const_constructors` gradual |

### Memoria / red

- Realtime channel por widget sin dispose consistente — mayoría hace `dispose` ✅.
- Imágenes menú: `CachedNetworkImage` ✅ en varios sitios.
- `panel_foody_control` mantiene listas completas en memoria por vista — aceptable admin.

---

## Clean Architecture — evaluación por capa

```
lib/
├── core/           ✅ HTTP, tema, rutas, realtime, sesión
├── features/
│   ├── */data/     ✅ Repositories (Dio)
│   ├── */domain/   🟡 Parcial (MenuModel, PedidoAdminModel; mucho Map)
│   └── */presentation/  ❌ Lógica de negocio y API calls en State
├── services/       🟡 Legacy (FCM, preferencias) — convivir hasta migrar
└── widgets/        🟡 Mapas, planes — mover a core/ o features
```

| Principio | Cumplimiento | Nota |
|-----------|:------------:|------|
| UI sin reglas de negocio | 🟡 | Display money OK; no decide stock/caja |
| Repositories únicos | ✅ | Un repo por módulo |
| Domain models | 🟡 | Admin usa `PedidoAdminModel`; CRUD usa `Map` |
| Use cases / services | ❌ | Lógica en `State` y widgets |
| Dependency injection | ❌ | `Repository()` inline |
| Testabilidad widgets | ❌ | Casi sin widget tests |

**Nota Foody:** regla de producto «Flutter solo UI» se cumple en **decisiones** (caja, stock); **sí hay** formateo y estimaciones visuales en cliente — aceptable si POST es fuente de verdad.

---

## Estrategia: Flutter profesional y mantenible

### Fase 0 — Reglas y métricas (1 sprint, sin feature nueva)

| ID | Acción |
|----|--------|
| FL-00 | Límite CI: **ningún archivo nuevo presentation &gt;500 LOC** |
| FL-01 | Documentar en `AGENTS.md`: patrón `FoodyAsyncBody` obligatorio en pantallas nuevas |
| FL-02 | Script `scripts/verificar-foody-loc.ps1` — falla si `*screen*.dart` &gt;800 LOC |

### Fase 1 — Core UI kit (`lib/core/ui/`) — P0

| ID | Entregable | Archivos afectados |
|----|------------|-------------------|
| FL-10 | `FoodyFormato.moneda(context, n)` | Reemplazar 20+ NumberFormat |
| FL-11 | `FoodyEstadoCarga` / `FoodyEstadoError` / `FoodyEstadoVacio` | Todas las screens |
| FL-12 | `FoodyStaffAppBar` | cajero, mesero, panel |
| FL-13 | Extender `TemaFoody` (Fase 6 diseño) | `tema_foody.dart` |

**Esfuerzo:** bajo · **Impacto:** alto en consistencia.

### Fase 2 — Descomponer god files — P0

Orden por riesgo operativo:

| Orden | Archivo | Split propuesto |
|------:|---------|-----------------|
| 1 | `mesa_pedidos_sheet.dart` | `cobro_mesa_panel`, `mesa_pedidos_lista`, `mesa_acciones_bar` |
| 2 | `mesas_grid_widget.dart` | `mesa_grid_tile`, `mesa_qr_dialog`, `mesa_opciones_admin` |
| 3 | `pedidos_kanban_widget.dart` | `kanban_columna`, `tarjeta_pedido`, `kanban_toolbar` |
| 4 | `panel_foody_control_screen.dart` | 1 archivo por `_Vista*` en `foody_control/` |
| 5 | `caja_admin_screen.dart` | `caja_apertura`, `caja_movimientos`, `caja_cierre` |
| 6 | `inventario_admin_screen.dart` | 1 tab = 1 archivo |

### Fase 3 — Estado con Riverpod — P1

| Provider | Tipo | Invalida cuando |
|----------|------|-----------------|
| `sesionStaffProvider` | `FutureProvider` | login/logout |
| `pedidosActivosProvider(sucursalId)` | `AsyncNotifier` | Realtime pedidos |
| `mesasProvider(sucursalId)` | `AsyncNotifier` | Realtime mesas |
| `cajaActivaProvider(sucursalId)` | `FutureProvider` | abrir/cerrar caja |
| `menuSucursalProvider(id)` | `FutureProvider` | pull refresh |

**Migración incremental:** pantalla por pantalla; no `MultiProvider` legacy.

### Fase 4 — Tipado domain — P1

| Área | Hoy | Objetivo |
|------|-----|----------|
| Inventario insumos | `Map<String,dynamic>` | `InsumoModel` |
| Caja movimientos | `Map` | `MovimientoCajaModel` |
| Mesas grid | `Map` | `MesaResumenModel` (parcial en `PedidoAdminModel`) |
| Super admin listas | `Map` | DTOs en `admin/domain/` |

### Fase 5 — Performance — P2

| ID | Acción |
|----|--------|
| FL-50 | `mis_pedidos` → `ListView.builder` |
| FL-51 | Quitar pulso global mesas → animación localizada |
| FL-52 | Kanban reloj: actualizar solo texto tiempo, no `setState` padre |
| FL-53 | `debounce` 300ms en campos búsqueda (kanban, inventario, menú admin) |
| FL-54 | `RepaintBoundary` en tiles mesa y tarjetas kanban |
| FL-55 | Caja movimientos: paginación API o virtual scroll si &gt;100 ítems |

### Fase 6 — Calidad y mantenimiento — P2

| ID | Acción |
|----|--------|
| FL-60 | Widget tests: `OperacionTarjeta`, `FoodyEstadoError`, carrito provider |
| FL-61 | Golden tests opcionales: KDS tile, mesa tile |
| FL-62 | Renombrar package `reserva_canchas` → `foody` (P3-05) |
| FL-63 | Mover `lib/services/` restante a `core/` o `features/` |

---

## Roadmap integrado (con otras fases frontend)

```
F0  QA manual
F1  Quick wins UX
F6  Design System (TemaFoody)
F7  Responsive (FoodyBreakpoints)
F8  Navegación (URL sync)
F9  Arquitectura Flutter (este doc)  ← FL-10…63
```

**Orden recomendado implementación:**

1. **FL-10, FL-11** (core UI) — mismo sprint que **DS-01**
2. **FL-02** mesa sheet + mesas grid split — desbloquea cobro y QA mesero
3. **FL-30** `pedidosActivosProvider` + kanban — unifica mesero/admin
4. God files restantes por prioridad operativa
5. Performance FL-50…55 cuando haya datos reales de turnos largos

---

## Matriz de salud por módulo

| Módulo | LOC max | Estado | Riverpod | Prioridad refactor |
|--------|--------:|:------:|:--------:|:------------------:|
| Admin super | 1864 | 🔴 | No | Alta |
| Mesas | 1665+1569 | 🔴 | No | **Crítica** |
| Pedidos/kanban | 1242+840 | 🟠 | No | Alta |
| Caja | 1136 | 🟠 | No | Alta |
| Inventario | 1273 | 🟠 | No | Media |
| Cliente menú/checkout | 699+726 | 🟡 | Carrito ✅ | Media |
| KDS | 559 | 🟢 | No | Baja |
| Auth/login | 334 | 🟢 | No | Baja |

---

## Anti-patrones a prohibir en código nuevo

1. Archivo presentation &gt;500 LOC sin justificación en PR.
2. `Repository()` instanciado en `build()`.
3. `ListView(children: items.map(...))` con lista dinámica de API.
4. `setState(() {})` vacío — usar `ValueNotifier` o provider filtrado.
5. Nueva pantalla admin sin `OperacionUi` / design tokens.
6. `Map<String,dynamic>` en capa presentation — parsear en repository.

---

## Relación con docs

| Doc | Enlace |
|-----|--------|
| `FRONTEND_ROADMAP.md` | Fase 9 — Arquitectura Flutter |
| `FRONTEND_INSTRUCCIONES.md` | INS-008 |
| `.cursor/rules/foody-proyecto.mdc` | Flutter solo UI |
| `.cursor/rules/ponytail.mdc` | Mínimo diff al refactorizar |

---

*Próxima revisión: tras FL-10/11 + split `mesa_pedidos_sheet` — remediar LOC y contar providers.*
