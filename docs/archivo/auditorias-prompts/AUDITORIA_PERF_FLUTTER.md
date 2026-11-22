# Auditoría — Performance Flutter (Prompt 24)

> **Fecha:** 2026-08-06  
> **Alcance:** tiempo de carga de pantallas con listas largas; memoria en sesión larga (turno 8 h); carga de imágenes (lazy / compresión / full-res).  
> **Método:** lectura estática + contraste API · `scripts/verificar-perf-flutter.ps1` · **sin** DevTools heap de 8 h reales (gap documentado).  
> Relacionados: [`AUDITORIA_FLUTTER_ESTRUCTURA.md`](AUDITORIA_FLUTTER_ESTRUCTURA.md) (FL-LEAK / FL-WIDGET) · [`AUDITORIA_REALTIME.md`](AUDITORIA_REALTIME.md) (RT-LEAK-01) · [`AUDITORIA_PERF_BACKEND.md`](AUDITORIA_PERF_BACKEND.md) · Prompt 23.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| ¿Listas largas cargan bien? | **Mixto.** Cerrados hoy + movimientos inventario **paginan**. Mis pedidos capped (API 50 / local 30) + `SliverList`. **Caja movimientos = unbounded + `shrinkWrap`** (peor path de turno). Kanban grid = `Wrap` eager. Insumos/catálogo = dump completo + builder. |
| ¿Memoria en 8 h sin cerrar? | **Riesgo medio-alto por canales Realtime** (`unsubscribe` sin `removeChannel` en ~9 pantallas). Timers/polls se cancelan en dispose. Caja acumula **todos** los movimientos del turno en RAM. **No** se midió heap 8 h con DevTools en esta sesión. |
| ¿Imágenes lazy + compresión? | **Lazy de scroll:** sí donde hay `ListView.builder` / Sliver. **Decode sized:** **no** — 0 `memCacheWidth`/`Height` en `lib/features`. **Upload:** Nest `sharp` → WebP ≤800 (`comprimirImagen`). Dep `flutter_image_compress` en pubspec **sin usos**. Admin aún mezcla `Image.network` vs `CachedNetworkImage`. |

**Veredicto:** usable en demo/piloto con catálogos chicos. Turno cajero largo + menú con muchas fotos = deuda clara (**caja + Realtime channels + decode full**).

---

## A) Listas largas — carga / paginación / UI

| Pantalla | API | UI | Riesgo N≈500+ |
|----------|-----|-----|---------------|
| Mis pedidos | `LIMIT 50` + cache local **30** | `SliverList.separated` | Bajo (tope duro) |
| Kanban activos | soft `limit` 100 | columnas `builder`; vista grid **`ListView`+`Wrap`** | Medio–alto (eager cards) |
| Kanban cerrados | **page/limit 30** + «Cargar más» | mismo Wrap sobre páginas cargadas | Medio si se acumulan páginas |
| Inventario insumos | **sin página** (lista activa completa) | `ListView.builder` | Medio payload; UI OK |
| Inventario movimientos | **page/limit 50** + cargar más | `ListView.builder` | Bajo–medio |
| Caja movimientos | **sin LIMIT** | `ListView.separated(shrinkWrap: true, NeverScrollable…)` anidado | **Alto** en turno busy |
| Catálogo admin | productos unbounded | `ListView.builder` | Medio + imágenes |
| Mesas | N típico bajo | `GridView.builder` | Bajo |
| Conteo físico | usa `_ingredientes` completo | `ListView(children: map…)` + 1 `TextEditingController`/ítem | Medio en cancel |

### Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **PERF-FL-LIST-01** | 🟣 | Media | Kanban vista grid construye **todas** las cards en un `Wrap` (no builder virtualizado) | `pedidos_kanban_widget.dart` ~1112–1134 |
| **PERF-FL-LIST-02** | 🟡 | Baja | Activos soft-cap 100 — OK ops; no es paginación offset | `pedidos_repository.dart` |
| **PERF-FL-LIST-03** | ✅ | — | Cerrados paginados + «Cargar más» | kanban + repo |
| **PERF-FL-LIST-04** | ✅ | — | Mis pedidos: Sliver + API 50 + local max 30 | `mis_pedidos_screen.dart` · `historial_pedidos_service.dart` `_maxEntradas=30` |
| **PERF-FL-LIST-05** | 🟣 | Media | Insumos: dump completo sin page | `inventario_repository` / service Nest |
| **PERF-FL-LIST-06** | ✅ | — | Movimientos inventario paginados | repo `page`/`limit` 50 |
| **PERF-FL-LIST-07** | 🟣 | **Alta** | Caja: API unbounded + lista `shrinkWrap` anidada (layout de **todas** las filas) | `caja_repository.dart` · `caja_admin_screen.dart` ~759–766 |
| **PERF-FL-LIST-08** | 🟣 | Media | Catálogo productos/combos sin paginación API | `catalogo_admin_repository` · `menu_admin_screen` |
| **PERF-FL-LIST-09** | ✅ | — | Mesas `GridView.builder` | `mesas_grid_widget.dart` |
| **PERF-FL-LIST-10** | 🟣 | Media | Sin `itemExtent` / `prototypeItem` en listas pesadas | ausente (salvo horarios) |
| **PERF-FL-LIST-11** | 🟣 | Media | Conteo: `ListView(children:)` + controllers por ítem; dispose solo si `ok==true` | `inventario_admin_screen.dart` ~1512–1583 · ≡ FL-LEAK-01 / FL-WIDGET-03 |

**Tiempo de carga:** no hay frames DevTools en esta pasada. Proxy: first-paint acotado por tamaño del JSON + si la UI es builder vs shrinkWrap. El path crítico de latencia percibida en staff es **abrir Caja tras muchas ventas** y **Kanban grid con ~100 cards**.

---

## B) Memoria — sesión larga (turno 8 h)

> **Gap:** no se dejó un dispositivo 8 h con DevTools Memory. Evidencia = patrones que **crecen o no liberan** si el panel permanece montado / se navega sin dispose correcto.

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **PERF-FL-MEM-01** | 🟣 | **Alta** | ~9 pantallas: `channel.unsubscribe()` **sin** `removeChannel` → canales pueden quedar en el mapa del cliente Supabase al cambiar sección | kanban, mesas_grid, mesa_pedidos_sheet, caja, alertas, menú, cajero, domiciliarios admin, seguimiento · ≡ **FL-LEAK-02** / **RT-LEAK-01** |
| **PERF-FL-MEM-02** | 🟡 | Media | Kanban: RT + poll 45–90 s + reloj 30 s `setState` (CPU continua; listas se **reemplazan**, no append infinito) | `pedidos_kanban_widget.dart` |
| **PERF-FL-MEM-03** | 🟣 | Media | Mesas: `Timer.periodic` 800 ms pulso `setState` de todo el grid mientras vive | `mesas_grid_widget.dart` ~89 |
| **PERF-FL-MEM-04** | ✅ | — | Polls/`AnimationController` suelen cancelarse en `dispose` / `detener()` | `PollRealtimeRespaldo`, splash, stories |
| **PERF-FL-MEM-05** | 🟣 | Media | Conteo: leak controllers si cancel (`ok != true`) | inventario ~1568 return sin dispose |
| **PERF-FL-MEM-06** | 🟣 | Media | Caja: `_movimientos` crece con **cada** venta/gasto del turno (sin ventana/paginación) | `caja_admin_screen` + LIST-07 |
| **PERF-FL-MEM-07** | ✅ | — | Eventos pedidos RT → `_recargar()` (replace), no append forever | kanban |
| **PERF-FL-MEM-08** | ✅ | — | `EventoDedup` TTL ~12 s | `evento_dedup.dart` |
| **PERF-FL-MEM-09** | 🟡 | Baja | Patrón bueno a copiar: KDS / domiciliario / panel usan `removeChannel` | `kds_screen.dart`, etc. |
| **PERF-FL-MEM-10** | 🟡 | Info | Sin medición heap 8 h — abrir DevTools Memory en tablet cajero = follow-up | gap |

---

## C) Imágenes — lazy / compresión / resolución

### Qué hay

| Capa | Estado |
|------|--------|
| Scroll lazy | Sí en menú (Sliver/builder), catálogo builder, carrito N chico |
| `CachedNetworkImage` | Menú cliente, combo sheet, carrito |
| `Image.network` / `NetworkImage` | Catálogo admin, promos/stories, restaurantes, sucursales, docs |
| `memCacheWidth` / `cacheWidth` | **0 usos** en `lib/features` |
| Upload Nest | `AlmacenamientoService.comprimirImagen`: sharp rotate → resize **800×800** inside → **webp q80** |
| Upload Flutter | `ImagePicker` → bytes a Nest; `flutter_image_compress` **declarado y no usado** |
| Legacy | `ImageUploadService` Firebase sube bytes crudos (deuda, no path Foody catálogo) |

### Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **PERF-FL-IMG-01** | 🟣 | **Alta** | Ninguna red image fija `memCacheWidth`/`Height` — thumbnails 56–72 px pueden decodificar bitmap completo (hasta ~800² WebP Nest o más si URL legacy) | grep features vacío |
| **PERF-FL-IMG-02** | 🟣 | Media | Story viewer fullscreen `Image.network` sin cache dims | `promocion_story_viewer.dart` |
| **PERF-FL-IMG-03** | 🟣 | Media | `flutter_image_compress` en `pubspec.yaml` sin imports/usos | pubspec + grep |
| **PERF-FL-IMG-04** | ✅ | — | Upload vía Nest **sí** comprime (sharp WebP ≤800) | `almacenamiento.service.ts` `comprimirImagen` |
| **PERF-FL-IMG-05** | 🟡 | Baja | Cliente menú usa `CachedNetworkImage` (mejor que bare network) pero sin mem dims | `menu_screen_foody.dart` ~713 |
| **PERF-FL-IMG-06** | 🟣 | Media | Admin catálogo usa `Image.network` en listas (sin disk/mem cache de package) | `menu_admin_screen.dart` |

**Respuesta corta a «¿lazy y compresión o full res?»**  
- **Lazy de widgets:** sí en listas builder.  
- **Compresión en origen (Nest):** sí para uploads Foody.  
- **Decode / memoria de display:** **full-res relativa al archivo** (sin downscale en cliente) → no es “todas a 4K”, pero **sí** más RAM de la necesaria para thumbs.

---

## D) Backlog (PERF-FL-FIX)

| ID | Prio | Acción | Cierra |
|----|------|--------|--------|
| **PERF-FL-FIX-01** | P0 | Paginar `GET /caja/:id/movimientos` + UI builder sin shrinkWrap anidado | LIST-07 · MEM-06 |
| **PERF-FL-FIX-02** | P0 | Unificar dispose Realtime: siempre `removeChannel` (patrón KDS) | MEM-01 · FL-FIX-02 |
| **PERF-FL-FIX-03** | P1 | `memCacheWidth`/`Height` (p.ej. 112–160) en thumbs menú/catálogo/carrito | IMG-01 |
| **PERF-FL-FIX-04** | P1 | Kanban grid → `ListView.builder` / sliver grid | LIST-01 |
| **PERF-FL-FIX-05** | P1 | `try/finally` dispose controllers conteo + otros diálogos inventario | MEM-05 · FL-FIX-01 |
| **PERF-FL-FIX-06** | P2 | Unificar `CachedNetworkImage` en admin; o quitar dep compress sin uso | IMG-03/06 |
| **PERF-FL-FIX-07** | P2 | Paginar insumos/catálogo si N>200 en clientes reales | LIST-05/08 |
| **PERF-FL-FIX-08** | P3 | Sesión DevTools 8 h tablet cajero (baseline heap + canales) | MEM-10 |
| **PERF-FL-FIX-09** | P3 | Reducir pulso mesas 800 ms (solo si visible / dirty) | MEM-03 |

---

## Verificación (esta sesión)

```text
.\scripts\verificar-perf-flutter.ps1 → exit 0
  network/cached image refs : 18
  memCacheWidth/Height      : 0
  .unsubscribe()            : 12
  removeChannel             : 6
  ListView/Grid/Sliver build: 26
  shrinkWrap:true           : 10
  FlutterImageCompress uso  : 0
  avisos: IMG-01, IMG-03, LIST-07, LIST-01
  backend sharp comprimirImagen OK
  dart analyze 5 pantallas clave → No issues found!

Gap: heap 8h DevTools no corrido; tiempos de frame no medidos en dispositivo.
```

## Solapes

| PERF-FL | Ya existía |
|---------|------------|
| MEM-01 | FL-LEAK-02 / RT-LEAK-01 |
| LIST-11 / MEM-05 | FL-LEAK-01 / FL-WIDGET-03 |
| LIST-07 | API-PAGE (caja unbounded) |
