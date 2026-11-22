# Auditoría — Performance backend (Prompt 23)

> **Fecha:** 2026-08-06  
> **Alcance:** queries pesadas (`EXPLAIN ANALYZE`), endpoints sin caché, latencia bajo carga (10 / 50 / 200 concurrentes).  
> **Entorno:** API Nest `http://127.0.0.1:3000`, Postgres demo (`supabase-db`), sucursal Centro `c0000000-0000-4000-8000-000000000001` (~528 pedidos / 546 ítems en sede).  
> **Checks:** `scripts/verificar-perf-backend.ps1` + EXPLAIN en `scripts/_tmp_perf_explain*.sql` (sesión).  
> Relacionados: [`AUDITORIA_BD_SUPABASE.md`](archivo/auditorias-prompts/AUDITORIA_BD_SUPABASE.md) (BD-IDX / BD-N1) · [`AUDITORIA_REPORTES.md`](archivo/auditorias-prompts/AUDITORIA_REPORTES.md) (ANA-PERF) · [`AUDITORIA_DASHBOARD.md`](archivo/auditorias-prompts/AUDITORIA_DASHBOARD.md) · AQ-SCALE-\* · `docs/OPTIMIZACION_ESCALABILIDAD_FOODY.md`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| ¿Hay queries “lentas” hoy en demo? | **No en ms absolutos** (todas &lt;1 ms en PG). Sí hay **planes que no escalan**: Seq Scan, `created_at::date`, `COALESCE` en fechas, subselects correlacionados en venta línea. |
| ¿Qué caché hay? | **Solo menú** (`MenuCacheService`, TTL 5 min, `CacheModule` max 200). Ciudades, dashboard, reportes, analítica = SQL fresco siempre. |
| ¿Aguanta 200 concurrentes? | **0 errores HTTP** en 10/50/200. Pero **latencia p50 se degrada** de ~0.4 s (n=10) a **7–10 s (n=200)** — Nest single-process + pool PG (max 25) saturan. Techo ~8–20 RPS en esta máquina. |

**Veredicto:** apto demo / piloto chico. **No listo** para pico concurrente de menú+dashboard sin índices caja, rewrite SQL fechas, batch N+1 menú y caché corta en lecturas calientes (o réplica/PM2+Redis a escala).

---

## A) EXPLAIN ANALYZE — queries pesadas

Datos: Sede Centro, `America/Bogota`. Ejecutado vía `docker exec supabase-db psql`.

| ID | Query / origen | Plan dominante | Exec | Hallazgo |
|----|----------------|----------------|------|----------|
| Q1 | Dashboard `ventas_7d` | Bitmap `idx_pedidos_sucursal_created` | **0.18 ms** | ✅ Índice OK |
| Q2 | Top productos 7d (join) | **Seq Scan `pedido_items`** (621 filas) + hash pedidos | **0.59 ms** | 🟣 escala O(tabla) |
| Q3 | Reportes financiero 365d | **Seq Scan `pedidos`** (planner ignora idx; tabla chica) | **0.18 ms** | 🟡 OK demo; riesgo 50k+ |
| Q4 | Dashboard resumen `created_at::date = hoy` | **Seq Scan** (cast invalida idx) | **0.26 ms** | 🟣 |
| Q5 | Menú `productos` sede | Seq Scan 40 filas (hay `idx_productos_sucursal`) | **0.06 ms** | 🟡 planner OK en chico |
| Q6 | Reportes caja `COALESCE(p.created_at, m.created_at)` | **Seq Scan `movimientos_caja`** + hash **todos** pedidos | **0.41 ms** | 🟣 sin índice + expresión no sargable |
| Q7 | Top con `SQL_VENTA_LINEA_ITEM` | SubPlan×N: **Seq Scan** `pedido_item_toppings` / `_bebidas` por ítem | **0.60 ms** (cost est. **1589**) | 🟣 |
| Q8 | Ventas hoy con **rango** `[date, date+1)` | Bitmap idx `created_at` | **0.19 ms** | ✅ forma correcta |

### Índices / stats en vivo

```text
movimientos_caja → SOLO movimientos_caja_pkey
pg_stat: movimientos_caja seq_scan=477, idx_scan=0
pedidos: idx_scan=13639 (bien usado) pero seq_scan=706 (casts / rangos amplios)
```

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **PERF-SQL-01** | 🟣 | Alta | `created_at::date = hoy` (dashboard/resumen y similares) fuerza Seq Scan; rango half-open usa índice | Q4 vs Q8 · `dashboard.service.ts` |
| **PERF-SQL-02** | 🟣 | Alta | `SQL_VENTA_LINEA_ITEM` = 2 subselects correlacionados → SubPlan Seq Scan por fila en top/reportes | Q7 · `sql-venta-linea-item.ts` |
| **PERF-SQL-03** | ✅ | Media | Top productos: `FROM pedidos` filtrado → join items (usa idx sucursal) | `dashboard.service.ts` |
| **PERF-SQL-04** | ✅ | Alta | Caja: filtros `OR` sargables (`SQL_FECHA_CAJA_COALESCED`) | `ventas-metricas.sql.ts` |
| **PERF-IDX-01** | 🟣 | Alta | `movimientos_caja` **sin** índice secundario en BD viva (≡ **BD-IDX-02**) | `\d` / `pg_indexes` · `idx_scan=0` |
| **PERF-SQL-05** | 🟡 | Baja | Financiero 365d elige Seq Scan con ~564 pedidos; techo documentado en ANA-PERF-01 | Q3 |
| **PERF-N1-01** | 🟣 | Alta | Menú combos: 1 query `combo_items` por combo (≡ **BD-N1-01** / AQ-SCALE-03) | `menu.service.ts` ~183 |
| **PERF-N1-02** | 🟣 | Media | Dashboard/analítica consolidado / comparativa-sedes: loop `await` por sede (≡ BD-N1-05) | `dashboard.service.ts` consolidado · `analitica.service.ts` |

---

## B) Caché — qué hay / qué falta

### Inventario

| Capa | Estado |
|------|--------|
| `@nestjs/cache-manager` global | TTL default 300 s, **max 200** claves |
| `MenuCacheService` | Único uso de dominio: `GET /menu/:sucursal_id` (+ invalidación catálogo/horario/fotos) |
| Dashboard / reportes / analítica / ciudades | **Sin** caché servidor |
| Redis / multi-réplica | No (in-memory; ≡ AQ-SCALE-04 thrash) |

### Latencia single (mediana 3 muestras, 2026-08-06)

| Endpoint | med ms | Cache |
|----------|-------:|-------|
| `GET /salud` | 18 | n/a |
| `GET /ciudades` | 19 | **NO** |
| `GET /ciudades/:slug/restaurantes` | 21 | **NO** |
| `GET /menu/:id` | 23 | **SI** (hit ~22–23 vs 1ª ~39) |
| `GET /dashboard/resumen` | 22 | **NO** |
| `GET /dashboard/graficos` | 25 | **NO** |
| `GET /analitica/resumen` | 31 | **NO** |
| `GET /reportes/financiero` (rango amplio) | 43 | **NO** |
| `GET /dashboard/consolidado` | 12 | **NO** (N+1 sedes; 3 sedes demo) |

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **PERF-CACHE-01** | ✅ | — | Menú tiene caché TTL 5 min; hit baja ~39→23 ms | `menu-cache.service.ts` + script |
| **PERF-CACHE-02** | ✅ | Media | `GET /ciudades` + restaurantes por slug TTL 3 min (`CACHE_MANAGER`) | `ciudades.service.ts` |
| **PERF-CACHE-03** | ✅ | Media | Dashboard resumen TTL 30 s (`CACHE_MANAGER`) | `dashboard.service.ts` |
| **PERF-CACHE-04** | 🟣 | Baja | Analítica/reportes sin caché por `(sucursal, rango)`; OK si raro, caro si panel refresca | reportes/analitica services |
| **PERF-CACHE-05** | 🟣 | Alta | `CacheModule.max = 200` + in-memory → thrash multi-sede (≡ **AQ-SCALE-04**) | `app.module.ts` |
| **PERF-CACHE-06** | 🟡 | Info | No cachear cobros/caja/KDS (correcto: deben ser frescos) | diseño |

---

## C) Carga concurrente (10 / 50 / 200)

### Método

1. **Start-Job** (`verificar-perf-backend.ps1`): overhead alto de jobs → RPS ~7–9; latencia individual ~100–200 ms; **0 fails**. Útil para smoke.  
2. **RunspacePool** (concurrencia real, pool 10/50/80): métricas de saturación.

### Resultados RunspacePool (canónicos)

| Endpoint | n | ok | fail | wall ms | RPS | p50 ms | p95 ms | max ms |
|----------|--:|---:|-----:|--------:|----:|-------:|-------:|-------:|
| salud | 10 | 10 | 0 | 510 | 19.6 | 415 | 423 | 432 |
| menu | 10 | 10 | 0 | 634 | 15.8 | 537 | 587 | 588 |
| dashboard | 10 | 10 | 0 | 429 | 23.3 | 366 | 375 | 376 |
| salud | 50 | 50 | 0 | 4464 | 11.2 | **3740** | 3977 | 3980 |
| menu | 50 | 50 | 0 | 6150 | 8.1 | **5387** | 5662 | 5685 |
| dashboard | 50 | 50 | 0 | 4505 | 11.1 | **3726** | 3920 | 3941 |
| salud | 200 | 200 | 0 | 18869 | 10.6 | **7105** | 7750 | 7821 |
| menu | 200 | 200 | 0 | 25963 | 7.7 | **10329** | 10658 | 10860 |
| dashboard | 200 | 200 | 0 | 19456 | 10.3 | **7455** | 7940 | 8134 |

Interpretación: a n≥50 la cola en el event loop / pool PG (`DB_POOL_MAX=25`) domina; menú (payload + posibles misses) es el peor. **Correctness OK; latency SLA no.**

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **PERF-LOAD-01** | ✅ | — | 0 errores en 10/50/200 en salud/menú/dashboard | RunspacePool |
| **PERF-LOAD-02** | 🟣 | Alta | p50 ~3.7–5.4 s a 50 conc. y ~7–10 s a 200 — degradación severa | tabla arriba |
| **PERF-LOAD-03** | 🟣 | Alta | Techo ~8–20 RPS en proceso Nest single + pool 25 (≡ AQ-SCALE-01) | RPS columna |
| **PERF-LOAD-04** | 🟣 | Media | Menú bajo carga peor que `/salud` pese a caché (payload + CPU serializan) | menu n=200 p50 10 s |
| **PERF-LOAD-05** | 🟡 | Baja | Start-Job subestima RPS (~9); no usar para capacidad; sí para smoke fails=0 | script Jobs |
| **PERF-POOL-01** | 🟣 | Alta | Pool default código `\|\| 10`; `.env` local tiene 25 — prod sin `DB_POOL_MAX` vuelve a 10 | `database.service.ts` · AQ-SCALE-01 |

---

## D) Backlog remediación (PERF-FIX)

| ID | Prioridad | Acción | Cierra |
|----|-----------|--------|--------|
| **PERF-FIX-01** | P0 | Migr. índices `movimientos_caja(sucursal_id, created_at)` + `(caja_id)` (+ cajas abierta) | PERF-IDX-01 / BD-IDX-01/02 |
| **PERF-FIX-02** | P0 | Reescribir filtros “hoy” / día a rango `[::date, ::date+1)` sin cast en columna | PERF-SQL-01 · DASH-TZ overlap |
| **PERF-FIX-03** | P1 | Batch `SQL_VENTA_LINEA_ITEM` (LEFT JOIN agregados toppings/bebidas una vez) | PERF-SQL-02 |
| **PERF-FIX-04** | P1 | Batch combo_items menú (≡ AQ-FIX-07 / BD-FIX-03) | PERF-N1-01 |
| **PERF-FIX-05** | P1 | Caché corta ciudades (+ listado restaurantes ciudad) TTL 1–5 min | PERF-CACHE-02 |
| **PERF-FIX-06** | P2 | Caché dashboard resumen/gráficos 15–60 s + header Age | PERF-CACHE-03 |
| **PERF-FIX-07** | P2 | Exigir `DB_POOL_MAX≥25` en validador prod; doc VPS | PERF-POOL-01 |
| **PERF-FIX-08** | P3 | Carga sintética ≥50k pedidos + re-EXPLAIN antes de cadena | PERF-SQL-05 / ANA-PERF-01 |
| **PERF-FIX-09** | P3 | Redis + PM2 solo con 100+ sedes (doc escala) | PERF-CACHE-05 / AQ-SCALE-04 |

---

## Verificación (esta sesión)

```text
GET /api/v1/salud → exito:true
.\scripts\verificar-perf-backend.ps1 -Niveles 10,50,200 → exit 0 (Jobs smoke)
RunspacePool 10/50/200 → 0 fails (tabla §C)
EXPLAIN ANALYZE Q1–Q8 → ver §A
```

**Gaps:** no se midió POST `/pedidos` bajo 200 (existe `verificar-carga-qr.ps1` aparte); no hay 50k filas sintéticas; no se midió en VPS.

---

## Solapes (no duplicar fix)

| PERF | Ya existía |
|------|------------|
| PERF-IDX-01 | BD-IDX-02 |
| PERF-N1-01 | BD-N1-01 / AQ-SCALE-03 |
| PERF-N1-02 | BD-N1-05 |
| PERF-CACHE-05 | AQ-SCALE-04 |
| PERF-POOL-01 | AQ-SCALE-01 |
| PERF-SQL-05 | ANA-PERF-01 |
