# Foody — Auditoría arquitectura y calidad de código (Prompt 01)

> **Fecha:** 2026-08-05  
> **Alcance:** NestJS (`foody_backend/src`) + Flutter (`lib/`) — lectura estática de código.  
> **No mide:** latencia runtime, carga real 500 tenants, QA hardware.  
> **Canvas vivo:** `canvases/arquitectura-calidad-codigo.canvas.tsx` (Cursor).  
> **Sucesora Prompt 02 (NestJS):** [`AUDITORIA_BACKEND_NESTJS.md`](AUDITORIA_BACKEND_NESTJS.md) — BN-\*.  
> **Sucesora Prompt 03 (Flutter):** [`AUDITORIA_FLUTTER_ESTRUCTURA.md`](AUDITORIA_FLUTTER_ESTRUCTURA.md) — FL-\*.  
> **Sucesora Prompt 04 (REST):** [`AUDITORIA_APIS_REST.md`](AUDITORIA_APIS_REST.md) — API-\*.  
> **Predecesora (jun-12, mayoría resuelta):** [`AUDITORIA_ARQUITECTONICA_FOODY.md`](AUDITORIA_ARQUITECTONICA_FOODY.md)  
> **Estado oficial:** hallazgos abiertos también en [`MASTER_STATUS.md`](MASTER_STATUS.md) § Arquitectura / calidad (AQ-*).  
> **Al cerrar un AQ-\*:** marcar ✅ aquí + MASTER + viñeta en `AVANCE_PROYECTO.md`.

---

## Veredicto

| Dimensión | Nota | Una línea |
|-----------|------|-----------|
| Carpetas / nombres | B | ES claro; ruido EN (`health`/`salud`, `dispatch`) y dobles caja/menú |
| Ciclos Nest | C | `pedidos ↔ domiciliarios` (+ cocinas) con `forwardRef` |
| Controllers Nest | B+ | Casi todos delgados; **almacenamiento** gordo |
| Duplicación | C+ | Stock paralelo, CRUD catálogo, crons DIY, math Flutter |
| Acoplamiento | C | Pedidos = hub; inventario/caja/admin acoplados |
| Escala 50→500 | C− | Pool, N+1, rate-limit RAM, crons multi-réplica |
| SOLID / capas | C | Sin repos; god services; $ en Flutter |
| Flutter capas | C | Features irregulares; ciclos admin↔pedidos; Riverpod solo carrito |

**Global Prompt 01:** ~**68 / 100** calidad estructural (distinto del 74/100 producto de jun-12: ese midió integridad operativa; este mide deuda estructural).

**Piloto 5–50 sedes:** viable con pool bien configurado (`DB_POOL_MAX≥25`).  
**500 restaurantes activos / multi-réplica API:** no listo sin remediar AQ-SCALE-\* y unificar stock (AQ-DUP-01).

---

## Índice de hallazgos

| Prefijo | Tema | Abiertos |
|---------|------|--------:|
| AQ-DUP-* | Código duplicado | 9 |
| AQ-CYCLE-* | Dependencias circulares | 6 |
| AQ-SOLID-* | SOLID / capas mezcladas | 8 |
| AQ-COUPLE-* | Acoplamiento entre módulos | 8 |
| AQ-SCALE-* | Escalabilidad 50→500 | 8 |
| AQ-NAME-* | Nombres y carpetas | 8 |
| AQ-FIX-* | Remediaciones priorizadas (backlog) | 7 |

Leyenda estado: `🟣 abierto` · `🟡 parcial / aceptado` · `✅ cerrado` · `📅 post-escala`

---

## 1. Código duplicado (AQ-DUP)

| ID | Estado | Hallazgo | Ubicación / evidencia | Impacto |
|----|--------|----------|----------------------|---------|
| **AQ-DUP-01** | ✅ | Dos cerebros de stock: admin vs pedido | Unificado vía `StockMovimientoService` + `StockMovimientoModule` (2026-08-06/07); Pedidos inventa recetas/cascade; Inventario orquesta admin; Costeo producción también escribe por el núcleo (`produccion_id`) | Drift venta/ajuste/compra/conteo/traslado/producción cerrado |
| **AQ-DUP-02** | 🟣 | Stack de 4 guards repetido (~15+ controllers) | `JwtAuthGuard` + `UsuarioActivo` + `SuscripcionActiva` + `RolGuard` por clase; sin `@StaffGuards()` compuesto | Ruido; riesgo de olvidar un guard en endpoint nuevo |
| **AQ-DUP-03** | 🟣 | CRUD catálogo casi idéntico | Controllers `categorias` / `productos` / `toppings` / `bebidas` / `combos` | Diffs grandes ante cambios de scope |
| **AQ-DUP-04** | ✅ | Upload imagen ×4 copy-paste | Unificado `subirImagenEntidadCatalogo` (2026-08-07) | Controller delgado |
| **AQ-DUP-05** | 🟣 | Crons DIY `setInterval` en ~7 sitios | impresión, dispatch, mesas-reserva, pedidos-qr, notificaciones, promociones, suscripciones | Cada réplica API ejecuta el mismo cron (carrera / trabajo duplicado) |
| **AQ-DUP-06** | 🟣 | Sheets producto ≈ combo (preview precio) | `detalle_producto_sheet.dart` ≈ `detalle_combo_sheet.dart` | Math local duplicada + mantenimiento UI |
| **AQ-DUP-07** | 🟣 | Fórmulas costeo Nest recalculadas en Flutter | `unidad_costeo_util.dart`, `receta_producto_panel.dart`, `costos_margenes_screen.dart` (comentario “alineado con NestJS”) | Desalineación precio sugerido / márgenes si Nest cambia |
| **AQ-DUP-08** | 🟡 | Stories promociones sede vs ciudad | `promociones_stories_bar` vs `promociones_ciudad_stories_bar` | Deuda UX menor |
| **AQ-DUP-09** | ✅ | `AnaliticaTokens` en `core/tema/` (+ shim feature) | `lib/core/tema/analitica_tokens.dart` |

**Qué ya está bien (no rehacer):**

- Interceptor respuesta `{ exito, datos, mensaje }` centralizado.
- `sql-venta-linea-item.ts` + `pedido-estados.ts` compartidos (analítica/reportes/dashboard/costeo).
- `SucursalScopeService` + helpers paginación en `compartido/`.

---

## 2. Dependencias circulares (AQ-CYCLE)

### Backend (Nest)

| ID | Estado | Ciclo | Evidencia |
|----|--------|-------|-----------|
| **AQ-CYCLE-01** | ✅ | `PedidosModule` ↔ `DomiciliariosModule` | Resuelto F7: `PedidosDispatchHooksService`; Pedidos no importa Domiciliarios; `DispatchService.onModuleInit` |
| **AQ-CYCLE-02** | 🟣 | `CocinasModule` → `PedidosModule` (+ usa Domiciliarios) | `cocinas.module.ts` `forwardRef(() => PedidosModule)`; `CocinasService` → soporte/estado/dispatch |
| **AQ-CYCLE-03** | 🟡 | Soft: Caja/Mesas → Pedidos (sin ciclo Nest) | `CajaModule` / `MesasModule` importan Pedidos; Pedidos escribe caja vía `CajaMovimientosService` global | Aceptable si se documenta; frágil al cambiar cobro |

### Flutter (imports cruzados)

| ID | Estado | Ciclo | Evidencia |
|----|--------|-------|-----------|
| **AQ-CYCLE-04** | ✅ | **admin ↔ pedidos** | Staff repo/modelo en `features/pedidos/`; shim en `admin/` | |
| **AQ-CYCLE-05** | 🟣 | **menu ↔ pedidos** | Sheets menú → `LineaCarrito` / `carritoProvider`; `pedido_cajero_screen` → menu repo + sheets |
| **AQ-CYCLE-06** | 🟣 | **costeo ↔ inventario** (+ catalogo↔costeo, admin↔mesa/caja) | `costeo_repository` vive en `inventario/data/`; UI costeo ↔ widgets inventario; `menu_admin` embebe costeo |

**Nota:** no hay barrels `index.dart`; los ciclos son imports directos feature↔feature.

---

## 3. SOLID y arquitectura de capas (AQ-SOLID)

### Backend

| ID | Estado | Hallazgo | Detalle |
|----|--------|----------|---------|
| **AQ-SOLID-01** | 🟡 | Sin capa repository / dominio | ~50 services inyectan `DatabaseService` y embeben SQL. Arquitectura real: Controller → Fat Service → SQL | Aceptado por monolito; documentar como convención |
| **AQ-SOLID-02** | 🟣 | God services (LOC) | `CosteoService` ~2160 · `AnaliticaService` ~1625 · `InventarioService` ~1270 · varios Pedidos* 900–1100 | SRP roto; merges difíciles |
| **AQ-SOLID-03** | ✅ | Lógica de negocio en controller | Movida a `AlmacenamientoService` (BN-FIX-01) | Cerrado |
| **AQ-SOLID-04** | 🟣 | Ownership de dominio filtrado | Pedidos deduce stock sin `InventarioService`; Almacenamiento muta tablas de catálogo | DIP / bounded context rotos |
| **AQ-SOLID-05** | ✅ | Controllers delgados (mayoría) | `PedidosController`, `CajaController`, catálogo: scope + DTO → service | Mantener este patrón |

### Flutter (regla Foody: solo UI)

| ID | Estado | Hallazgo | Archivos |
|----|--------|----------|----------|
| **AQ-SOLID-06** | 🟣 | Totales / precio × cantidad en cliente | `linea_carrito.dart` (`subtotalPara`) · `carrito_provider.totalPrecio` · `checkout_screen._totalEstimado` · `pedido_cajero_screen` · `carrito_screen` |
| **AQ-SOLID-07** | 🟣 | Preview toppings/bebidas/combo en sheets | `detalle_producto_sheet._precioPreview` · `detalle_combo_sheet` |
| **AQ-SOLID-08** | 🟣 | Costeo / márgenes / precio sugerido en Dart | `unidad_costeo_util.dart` · paneles receta / incluidos · `dialogo_subreceta_form` |
| **AQ-SOLID-09** | 🟡 | Filtro stock bajo en dashboard (fallback local) | `dashboard_resumen_widget._filtrarStockBajo` | Preferir solo flag API `bajo_minimo` |

**Aceptable (no AQ):** sumar `p.total` ya calculado por API en headers kanban; mostrar IVA/subtotal de respuesta; UI de error `STOCK_INSUFICIENTE`.

---

## 4. Acoplamiento — ¿modificar uno sin romper otro? (AQ-COUPLE)

| ID | Estado | Cambio en… | ¿Seguro solo? | Por qué |
|----|--------|------------|---------------|---------|
| **AQ-COUPLE-01** | 🟡 | Menu público Nest | Sí a nivel módulo | Pedidos no importa `MenuModule`; lee precios por SQL |
| **AQ-COUPLE-02** | 🟣 | Columnas precio catálogo | No | `PedidosCrear` / items leen `productos` vía SQL |
| **AQ-COUPLE-03** | 🟣 | Inventario admin | No | Ruta pedido usa cerebro stock paralelo (AQ-DUP-01) |
| **AQ-COUPLE-04** | 🟣 | Caja cobro / estados | No | Caja ↔ `PedidosEstado` + `CajaMovimientos` global |
| **AQ-COUPLE-05** | 🟣 | Domiciliarios / dispatch | No | Ciclo hard AQ-CYCLE-01 |
| **AQ-COUPLE-06** | 🟣 | Flutter menu UI | No | Comparte carrito domain con pedidos |
| **AQ-COUPLE-07** | 🟣 | Flutter staff pedidos | No | Ownership split admin/ vs pedidos/ |
| **AQ-COUPLE-08** | ✅ | Geografía / ciudades | Sí | Bajo fan-in |

**Hubs de fan-in:** `PedidosModule` (Nest) · `features/admin` (Flutter shell) · `AnaliticaTokens` (tema accidental).

---

## 5. Escalabilidad 50 → 500 restaurantes (AQ-SCALE)

| ID | Estado | Riesgo | Hoy | A ~500 sedes activas |
|----|--------|--------|-----|----------------------|
| **AQ-SCALE-01** | 🟣 **prod-risk** | Pool PG default bajo | `DB_POOL_MAX \|\| 10` en `database.service.ts` (local Fase 0 ya usa 25 en env) | TX largas de pedido + multi-sede → cola/timeouts si misconfig |
| **AQ-SCALE-02** | 🟣 **prod-risk** | Crons por réplica | `setInterval` DIY (AQ-DUP-05) | Trabajo duplicado / races sin advisory lock o leader |
| **AQ-SCALE-03** | 🟣 | N+1 SQL hot paths | Menu combos 1 query/combo; clone catálogo per-row; stock expansión por ítem | Latencia menú + crear pedido bajo pico |
| **AQ-SCALE-04** | 🟣 | Cache menú in-memory | `CacheModule` max ~200, TTL 300s | Thrashing entre muchas sucursales |
| **AQ-SCALE-05** | 🟣 **prod-risk** | Rate-limit en `Map` estático | Por proceso | Inútil con N réplicas; crecimiento memoria IP×path |
| **AQ-SCALE-06** | 🟡 | Realtime channel Map | Por sucursal/cocina/domi (bien shardeado) | Riesgo límites Supabase + hygiene de canales |
| **AQ-SCALE-07** | 🟡 | Listados / health globales | Pedidos default LIMIT 100; auditoría 500; impresión `COUNT(*)` sin `sucursal_id` | Respuestas pesadas / scan global jobs |
| **AQ-SCALE-08** | 🟡 | God screens Flutter | `menu_admin` ~2.2k · `mesas_grid` ~2.1k · inventario ~1.9k LOC | No escala de **equipo** (merge hell), no de tenants |

**Relacionado (no duplicar backlog):** [`RECOMENDACIONES_IMPLEMENTACION.md`](RECOMENDACIONES_IMPLEMENTACION.md) · [`OPTIMIZACION_ESCALABILIDAD_FOODY.md`](OPTIMIZACION_ESCALABILIDAD_FOODY.md) (PM2+Redis 📅 100+).

---

## 6. Convenciones de nombres y carpetas (AQ-NAME)

### Backend

| ID | Estado | Hallazgo |
|----|--------|----------|
| **AQ-NAME-01** | 🟡 | Carpetas ES OK (`pedidos`, `caja`, `salud`); archivos EN mezclados (`health.controller`, `jwt-*`, `fcm`, `wompi`, `dispatch`) |
| **AQ-NAME-02** | 🟡 | Doble “caja”: `modulos/caja` (API) + `core/caja` (writer global) — intencional pero confuso |
| **AQ-NAME-03** | 🟡 | Doble “menú”: `menu` (público) vs `catalogo` (admin) vs `core/cache/menu-cache` |
| **AQ-NAME-04** | 🟡 | `ciudades` (catálogo BD) vs `geografia` (Photon) — nombres próximos |

### Flutter

| ID | Estado | Hallazgo |
|----|--------|----------|
| **AQ-NAME-05** | 🟣 | Package Dart aún `reserva_canchas` (P3-05 pausado) |
| **AQ-NAME-06** | 🟡 | Features ES; archivos `*_screen` / `*_repository` EN; casi nunca `pantalla`/`repositorio` |
| **AQ-NAME-07** | 🟣 | Capas irregulares: solo ~7 features con `data/domain/presentation`; costeo sin `data/` (repo en inventario); staff pedidos en `admin/data/` |
| **AQ-NAME-08** | 🟡 | Riverpod solo `carritoProvider`; resto StatefulWidget + repos · `lib/providers/` carpeta vacía · `lib/screens/` = 0 ✅ |

**Deuda legacy residual (no pantallas):** `lib/models/` cancha (casi huérfanos); `lib/services/` mezcla vivo (`app_backend`, FCM, ciudad) + helpers cancha muertos.

---

## 7. Backlog de remediación priorizado (AQ-FIX)

Orden recomendado (ponytail: máximo impacto / mínimo diff). **No implementar aquí** — solo registro.

| ID | Prioridad | Acción | Cierra / reduce | Capa |
|----|-----------|--------|-----------------|------|
| **AQ-FIX-01** | P1 | ✅ Unificar write-path stock (`StockMovimientoService`); producción costeo incluida | AQ-DUP-01, AQ-SOLID-04, AQ-COUPLE-03 | Nest |
| **AQ-FIX-02** | P1 | ✅ Romper ciclo pedidos↔domiciliarios (`PedidosDispatchHooksService`) | AQ-CYCLE-01/02, AQ-COUPLE-05 | Nest |
| **AQ-FIX-03** | P1 | Totales carrito: preview API o marcar UI-only; **nunca** confiar Dart al cobrar | AQ-SOLID-06/07, AQ-DUP-06 | Flutter+Nest |
| **AQ-FIX-04** | P0-ops | `DB_POOL_MAX` documentado en prod + rate-limit Redis/shared + cron con lock/leader | AQ-SCALE-01/02/05, AQ-DUP-05 | Ops/Nest |
| **AQ-FIX-05** | P2 | Mover `PedidosRepository` staff + `PedidoAdminModel` a `features/pedidos/` | AQ-CYCLE-04, AQ-COUPLE-07, AQ-NAME-07 | Flutter |
| **AQ-FIX-06** | P2 | `AnaliticaTokens` → `core/tema/`; `costeo_repository` → `costeo/data/` | AQ-DUP-09, AQ-CYCLE-06 | Flutter |
| **AQ-FIX-07** | P2 | Batch N+1 menú/combos + clone catálogo + expansión stock | AQ-SCALE-03 | Nest |

**Fuera de alcance inmediato (📅):** PM2 cluster + Redis cache (doc escala 100+); rename paquete P3-05; split god screens al tocarlos (no big-bang).

---

## 8. Matriz de conteo (mantener al cerrar)

| Grupo | 🟣 | 🟡 | ✅ | 📅 |
|-------|---:|---:|---:|---:|
| AQ-DUP | 7 | 1 | 1 | 0 |
| AQ-CYCLE | 4 | 1 | 1 | 0 |
| AQ-SOLID | 6 | 2 | 1 | 0 |
| AQ-COUPLE | 6 | 1 | 1 | 0 |
| AQ-SCALE | 5 | 3 | 0 | 0 |
| AQ-NAME | 2 | 6 | 0 | 0 |
| **Total hallazgos** | **30** | **14** | **4** | **0** |
| AQ-FIX backlog | 5 abiertos (01/02 ✅; 03–07) | | | |

> Nota: AQ-SOLID-05 y AQ-COUPLE-08 cuentan como ✅ (puntos fuertes confirmados).  
> Actualizar esta tabla al cerrar cada ID.

---

## 9. Cómo verificar al remediar

| Fix | Evidencia mínima |
|-----|------------------|
| AQ-FIX-01 stock | Script pedidos+inventario: crear pedido descuenta igual que ajuste admin; un solo servicio en traza |
| AQ-FIX-02 ciclo | Quitar `forwardRef` pedidos↔domiciliarios; `nest build` + smoke dispatch |
| AQ-FIX-03 totales | Checkout usa totales de respuesta API; Dart solo display (o endpoint preview) |
| AQ-FIX-04 escala | 2 instancias API sin jobs duplicados; rate-limit compartido; pool documentado |
| Flutter moves | `dart analyze` paths tocados; kanban/menu/costeo smoke |

Scripts existentes útiles: `verificar-ci.ps1`, `verificar-ops-recomendaciones.ps1`, `estres-api-foody.ps1`, `verificar-inventario-menu.ps1`.

---

## Changelog de este documento

| Fecha | Cambio |
|-------|--------|
| 2026-08-05 | Enlace a Prompt 04 (`AUDITORIA_APIS_REST.md`) |
| 2026-08-05 | Enlace a Prompt 02 (`AUDITORIA_BACKEND_NESTJS.md`) |
| 2026-08-05 | **Creación** Prompt 01 — 32+ hallazgos AQ-* documentados; backlog AQ-FIX-01…07; enlazado MASTER / AVANCE / README / ROADMAP |

---

*Fin — Auditoría arquitectura y calidad (Prompt 01).*
