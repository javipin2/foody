# Auditoría — Capacity planning / crecimiento masivo (Prompt 31)

> **Fecha:** 2026-08-06  
> **Alcance:** techos reales de la infra actual (1 VPS + Docker Nest + Postgres/Supabase self-hosted + Tunnel/R2) frente a **100 / 500 / 1.000 / 5.000 / 10.000** restaurantes activos simultáneos.  
> **Método:** config y código auditados + mediciones previas (PERF/CONC) + `SHOW` / `pg_stat` en vivo. **No** es estimación abstracta sin evidencia.  
> Relacionados: [`AUDITORIA_PERF_BACKEND.md`](archivo/auditorias-prompts/AUDITORIA_PERF_BACKEND.md) · [`AUDITORIA_ESTRES_CONCURRENCIA.md`](archivo/auditorias-prompts/AUDITORIA_ESTRES_CONCURRENCIA.md) · [`AUDITORIA_ARQUITECTURA_CALIDAD.md`](archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md) (AQ-SCALE) · [`OPTIMIZACION_ESCALABILIDAD_FOODY.md`](../../OPTIMIZACION_ESCALABILIDAD_FOODY.md) · [`AUDITORIA_INFRA.md`](archivo/auditorias-prompts/AUDITORIA_INFRA.md) · [`AUDITORIA_FACTURACION.md`](archivo/auditorias-prompts/AUDITORIA_FACTURACION.md).

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta corta |
|----------|-----------------|
| ¿Aguanta 100 con infra actual? | **Solo piloto controlado** (pocos concurrentes reales). Pico tipo viernes multi-sede **no**: techo medido ~8–20 RPS / p50 7–10 s a 200 conc. |
| ¿500+? | **No** sin PM2/réplicas API + Redis + subir `max_connections`/PgBouncer + índices/caché. |
| ¿1.000+? | **No** — requiere réplica de lectura, DB dedicada afinada, partición/archivo, edge cache. |
| ¿5.000–10.000? | **No** en un solo VPS; arquitectura multi-nodo / sharding por tenant o clusters regionales. |
| Primer cuello global | **Nest single-process + pool PG ≤25** dentro de **`max_connections=100`** (Supabase ya consume ~20–40 slots). |
| Módulo que cae primero | **Cocina realtime + dashboard/reportes** (poll+SQL fresco+canales); pedidos write aguanta más por TX pero se encola detrás del pool. |
| Endpoint que satura primero | `GET /menu/:id` bajo miss/carga y `GET /dashboard/resumen` / `GET /reportes/financiero` (sin caché; SQL pesado). |
| SQL inviable primero | `created_at::date`, `COALESCE` en fechas caja, `SQL_VENTA_LINEA_ITEM` SubPlan, Seq Scan `pedido_items`/`movimientos_caja`. |
| Tablas sin control | **`notificaciones_pendientes`** (ya ~39k / 21 MB, sin purge) y **`auditoria_logs`** (~33k / 14 MB); luego `pedido_items` + historial estados. |
| Proceso más caro hoy | **Reportes/analítica SQL** + **cola FCM** (`setInterval` 60 s). WhatsApp OTP / MATIAS DIAN **no existen** en código (0 refs MATIAS). |
| Pantalla Flutter peor | **Caja movimientos** (unbounded + shrinkWrap) · kanban grid Wrap · insumos/catálogo dump. |
| Límite real pool hoy | Postgres **`max_connections = 100`**; Nest **`DB_POOL_MAX = 25`** (`.env`; código default **10**). Headroom práctico Nest ≈ **25** conexiones concurrentes a PG, no 100. |

**Veredicto:** infra actual = **demo / piloto ≤~20–50 sedes activas** con margen. **No** diseñada para SaaS masivo en un solo nodo.

---

## Baseline medido (esta sesión + Prompt 23/26)

### Infra / proceso

| Componente | Evidencia | Valor |
|------------|-----------|------:|
| Nest entry | `Dockerfile` `CMD ["node", "dist/main.js"]` · `main.ts` sin `cluster` | **1 proceso** |
| Compose prod | `docker-compose.prod.yml` → 1 servicio `backend` | **sin réplicas** |
| Pool Nest | `database.service.ts` `max: Number(DB_POOL_MAX) \|\| 10` · `.env` `DB_POOL_MAX=25` | **25** (local) |
| Postgres | `SHOW max_connections` en `supabase-db` | **100** |
| shared_buffers | vivo | **128 MB** (default chico) |
| Backends vivos demo | `pg_stat_activity` count | **~44** (idle+active; stack Supabase) |
| Apps PG | realtime, supavisor, PostgREST, pg_cron, Timescale… | ~15–25 slots fijos |
| Caché | `CacheModule` max **200**, TTL 300 s; solo menú | thrash multi-sede |
| Rate-limit | `Map` estático por proceso | rompe multi-réplica (AQ-SCALE-05) |
| Realtime | Broadcast Supabase; Nest `Map` de canales; Flutter WS a Supabase (no Nest) | AQ-SCALE-06 |
| Cluster Mode | ausente | — |

### Carga (lab, no VPS)

| Escenario | Resultado |
|-----------|-----------|
| PERF 200 conc salud/menú/dashboard | **0** fails HTTP; p50 **7–10 s**; RPS ~8–20 |
| CONC mixto 100×3 | p99 lecturas ~**10 s** |
| Writes 10× POST pedidos | p50 ~207 ms OK (cola corta) |

### Tablas que ya crecen (demo chica)

| Tabla | `n_live_tup` | Tamaño aprox. | Nota |
|-------|-------------:|---------------|------|
| `notificaciones_pendientes` | **39 526** | 21 MB | ~39k `enviada=true`; **sin DELETE/archivado** |
| `auditoria_logs` | **33 338** | 14 MB | solo INSERT; sin retención |
| `estados_pedido_historial` | 1 837 | — | crece con cada transición |
| `pedido_items` / `pedidos` | 676 / 611 | &lt;1 MB | aún chicos; plan Seq Scan ya aparece en reportes |

### Qué NO consume recursos (aún)

| Proceso | Estado código |
|---------|---------------|
| WhatsApp OTP | No hay integración WhatsApp/OTP outbound en Nest (AUTH OTP doc ≠ WhatsApp) |
| Facturación DIAN vía MATIAS | **0 refs MATIAS**; FE = borrador/HTML local (`FE-MATIAS-01`) |
| Réplica PG / LB | No existen |

---

## Definición de “restaurante activo simultáneo”

Para esta auditoría:

- 1 restaurante ≈ **1–3 dispositivos staff** (caja + cocina + mesero) + clientes esporádicos.
- Pico útil ≈ **0.3–1 request concurrente a PG por restaurante** en hora punta (menú/KDS/dashboard/pedido).
- Por tanto **100 restaurantes en punta** ≈ **30–100 queries concurrentes** → ya choca con pool **25** y techo RPS **~20**.

Si “activo” = solo suscripción pagada sin tráfico, los números bajan; aquí se asume **operando a la vez**.

---

## Tabla por nivel de escala

| Sedes activas | ¿Aguanta infra actual? | Bottleneck principal | Síntoma esperado | Causa raíz | Fix tipo | Esfuerzo / costo est. |
|--------------:|:----------------------:|----------------------|------------------|------------|----------|------------------------|
| **100** | 🟡 **Parcial** — piloto sí; pico viernes **no** | Nest 1 proceso + pool 25 + event-loop | Latencia 3–10 s; cola HTTP; KDS/dashboard “congelados”; 0 fails hasta saturar | PERF-LOAD-02/03 · AQ-SCALE-01 · `max_connections=100` compartido con Supabase | **Código + ops chica:** índices caja, rangos fecha, batch N+1, caché ciudades/dashboard, `DB_POOL_MAX` prod, purge notif; **infra:** VPS ≥4 vCPU/8 GB, `max_connections`↑ o pooler, opcional 2 workers PM2 + Redis | Índices/SQL: **1–3 d** · VPS upgrade: **€/~$** mes · PM2+Redis: **2–5 d** |
| **500** | ❌ **No** | Pool PG agotado + caché thrash (max 200) + canales Realtime/poll | Timeouts `pg` / 502 Tunnel; menú miss constante; rate-limit inconsistente si N réplicas sin Redis; canales RT-LEAK | AQ-SCALE-01/04/05/06 · CacheModule 200 · Map rate-limit · RT-LEAK | **Infra:** PgBouncer/Supavisor mode, PM2 cluster o N containers, Redis cache+RL, `max_connections` 200–400 + RAM; **código:** batch combos, MV/caché reportes cortos, `removeChannel` | Infra+código: **2–4 sem** · costo VPS+Redis **decenas €/mes** |
| **1 000** | ❌ **No** | CPU/RAM VPS único + Seq Scan reportes sobre `pedidos`/`pedido_items` millones de filas | Reportes 365d minutos; backup R2 hours; disco por logs/notif/auditoría; crear pedido encola | shared_buffers 128 MB · sin réplica lectura · sin partición · ANA-PERF-01 | **Infra:** DB dedicada (o managed) + **réplica lectura** para reportes/dashboard; API ≥3 nodos detrás LB; **código:** partición/archivo `pedidos` por mes, purge `auditoria_logs`/`notificaciones_pendientes`, MV diarias | **1–2 meses** · infra **cientos €/mes** |
| **5 000** | ❌ **No** | Disco + I/O PG + fan-out Realtime (5k× canales cocina/sucursal) + Tunnel single-origin | Caídas globales; Realtime drops; imposibilidad backup online; Nest OOM si Map canales crece | 1 VPS · 1 PG · broadcast sin shard · AQ-SCALE-06 | **Arquitectura:** multi-región o shard por `restaurante_id`/región; Realtime dedicado; object storage ya R2 OK; cola jobs (Bull/Redis) para FCM/reportes | **trimestre+** · infra **miles €/mes** |
| **10 000** | ❌ **No** | Todo lo anterior ×2 + compliance/ops 24×7 | SaaS entero cae con un nodo; RPO/RTO inaceptables | Single-tenant-of-infra | **Plataforma:** clusters API+PG (o serverless DB), CDN menú estático, observability, on-call | **programa multi-mes** · costo enterprise |

---

## Detalle por nivel (preguntas del prompt)

### 100 restaurantes

| Pregunta | Respuesta |
|----------|-----------|
| ¿Aguanta? | **Parcial.** Lecturas ligeras OK; pico concurrente **no** (evidencia 50–200 conc → segundos). |
| Primer bottleneck | **Pool PG Nest (25)** y **CPU event-loop** single process — antes que ancho de banda Tunnel. |
| Módulo que cae primero | **Dashboard + cocina (poll/RT)** y **menú** bajo miss; pedidos write se encolan. |
| Endpoint | `GET /dashboard/resumen`, `GET /menu/:sucursal_id` (miss), `GET /reportes/financiero`. |
| SQL | `created_at::date = hoy` (PERF-SQL-01); `movimientos_caja` sin índice (PERF-IDX-01); top productos Seq Scan `pedido_items`. |
| Tabla | `notificaciones_pendientes` (ya 39k sin purge) → **CAP-GROW-01**. |
| Proceso | Reportes SQL + cron FCM 60 s; **no** MATIAS/WhatsApp. |
| Flutter | `caja_admin` movimientos unbounded (**PERF-FL-LIST-07**); kanban grid Wrap. |
| Pool | Techo Nest **25**; PG **100** totales (−~40 stack) → **~60** teóricos, pero un solo Nest no usa más de 25. |

### 500 restaurantes

| Pregunta | Respuesta |
|----------|-----------|
| ¿Aguanta? | **No** con 1 proceso + cache 200 + `max_connections=100`. |
| Primer bottleneck | **Conexiones PG** (Nest+Auth+Realtime+PostgREST pelean 100 slots) + **thrash caché menú**. |
| Módulo | Cocina realtime (canales + poll 45–90 s × N pantallas) + menú público. |
| Endpoint | Mismo + `GET /analitica/*` consolidado N+1 sedes (PERF-N1-02). |
| SQL | `SQL_VENTA_LINEA_ITEM` SubPlan × filas (PERF-SQL-02) en top/reportes. |
| Tabla | `auditoria_logs` + `pedido_items` (crecimiento O(pedidos×ítems)). |
| Proceso | FCM cola + reportes; al activar FE/MATIAS sería cola externa (hoy N/A). |
| Flutter | Insumos/catálogo dump; KDS OK si tickets del día, malo si refetch full sin filtro. |
| Pool | Hay que **subir `max_connections`** **y** PgBouncer; Nest pool por worker ~10–20 × N workers &lt; PG max. |

### 1 000 restaurantes

| Pregunta | Respuesta |
|----------|-----------|
| ¿Aguanta? | **No.** |
| Primer bottleneck | **I/O y CPU Postgres** en agregaciones; RAM `shared_buffers` 128 MB insuficiente. |
| Módulo | **Reportes/analítica** primero (lecturas pesadas); luego pedidos en cola. |
| Endpoint | `GET /reportes/financiero` rangos largos; `GET /dashboard/consolidado` (loop sedes). |
| SQL | Seq Scan `pedidos` 365d (ANA-PERF-01) deja de ser “OK en 30 ms”. |
| Tabla | `pedidos` + `pedido_items` + `estados_pedido_historial` → partición por tiempo. |
| Proceso | Generación reportes on-demand (bloquea pool). |
| Flutter | Reportes admin / analítica con payloads grandes. |
| Pool | Pooler obligatorio; réplica lectura para reportes. |

### 5 000 / 10 000

| Pregunta | Respuesta |
|----------|-----------|
| ¿Aguanta? | **No** en un VPS. |
| Primer bottleneck | **Arquitectura single-node** (CPU/RAM/disco/Tunnel origin único). |
| Módulo | Cualquier fan-out (RT, FCM, reportes globales super-admin). |
| Endpoint / SQL | Agregados cross-tenant (`/super/estadisticas` a escala) + joins ítems. |
| Tablas | Todas hot-path sin partición; backups inviables sin streaming. |
| Proceso | Cualquier job síncrono en el request path. |
| Flutter | Irrelevante frente a API caída. |
| Pool | Multi-cluster; límites por shard. |

---

## Hallazgos CAP-\* (nuevos / consolidados)

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CAP-INFRA-01** | 🟣 | **Prod** | Un solo proceso Node en prod (`Dockerfile` CMD); sin PM2/cluster | `foody_backend/Dockerfile` L16 · `main.ts` |
| **CAP-POOL-01** | 🟣 | **Prod** | Nest pool default **10**; local **25**; PG **`max_connections=100`**; ~44 backends ya vivos en demo | `database.service.ts` · `.env` · `SHOW max_connections` · `pg_stat_activity` |
| **CAP-POOL-02** | 🟣 | Alta | Headroom real Nest ≈ **min(DB_POOL_MAX, max_connections − stack Supabase)** ≈ **25**, no 100 | Cálculo + backends vivos |
| **CAP-PG-01** | 🟣 | Alta | `shared_buffers=128MB` default — insuficiente &gt;cientos sedes / tablas grandes | `SHOW shared_buffers` |
| **CAP-CACHE-01** | 🟣 | Alta | Cache in-memory max **200** → thrash ≥200 sucursales menú (≡ AQ-SCALE-04 / PERF-CACHE-05) | `app.module.ts` |
| **CAP-LOAD-01** | 🟣 | Alta | Techo lab ~**8–20 RPS**; p50 **7–10 s** a 200 conc (≡ PERF-LOAD / CONC-LOAD) | Prompt 23/26 |
| **CAP-GROW-01** | 🟣 | Alta | `notificaciones_pendientes` ~**39k** filas / 21 MB; enviadas no se borran | `pg_stat_user_tables` + `GROUP BY enviada` |
| **CAP-GROW-02** | 🟣 | Media | `auditoria_logs` ~**33k** / 14 MB; sin política de retención/partición | mismo |
| **CAP-GROW-03** | 🟣 | Media | Sin `PARTITION` / jobs de purge en migraciones para hot tables | grep migraciones |
| **CAP-MOD-01** | 🟣 | Alta | Primer módulo saturado: **lecturas calientes** (dashboard/menú/reportes) + **cocina RT/poll**; writes pedido encolan | PERF + RT docs |
| **CAP-EP-01** | 🟣 | Alta | Endpoints: `/dashboard/resumen`, `/menu/:id`, `/reportes/financiero` | latencias + sin caché |
| **CAP-SQL-01** | 🟣 | Alta | Queries: cast fecha, COALESCE caja, SubPlan venta línea, Seq `pedido_items`/`movimientos_caja` | PERF-SQL/IDX |
| **CAP-PROC-01** | 🟡 | Info | WhatsApp OTP / MATIAS **no** son carga hoy (no implementados); FCM cron + reportes sí | FE-MATIAS-01 · notificaciones-cron |
| **CAP-FL-01** | 🟣 | Media | Flutter: caja unbounded (LIST-07), kanban Wrap (LIST-01), insumos/catálogo dump | PERF-FL |
| **CAP-RT-01** | 🟣 | Media | Escala RT limitada por canales Supabase + leaks `removeChannel` (RT-LEAK) + poll fijo | AUDITORIA_REALTIME |
| **CAP-FE-01** | 🟡 | Info | Cuando se active MATIAS, facturación será **nuevo** cuello (cola HTTP externa); planificar cola async | AUDITORIA_FACTURACION |

---

## Límite real de conexiones (respuesta directa)

```
Postgres max_connections          = 100          (vivo supabase-db)
Slots típicos stack Supabase      ≈ 20–40        (realtime, supavisor, rest, cron…)
NestJS Pool.max (config actual)   = 25           (.env DB_POOL_MAX; código fallback 10)
Workers Nest                      = 1            → usa como mucho 25

⇒ Conexiones simultáneas “de app Foody” soportadas hoy ≈ 25
⇒ Techo duro PG compartido ≈ 100 (si Nest sube pool sin subir max_connections → Auth/Realtime mueren)
```

**Recomendación numérica mínima antes de 100 sedes en punta:**

1. `max_connections` ≥ 200 **o** PgBouncer transaction mode.  
2. Nest: 2–4 workers × `DB_POOL_MAX=15–20` cada uno, suma &lt; pooler.  
3. Redis para caché menú + rate-limit.  
4. Purge `notificaciones_pendientes` enviadas &gt;7 d; retención `auditoria_logs`.

---

## Backlog remediación (CAP-FIX)

| ID | Prio | Acción | Cierra | Tipo |
|----|------|--------|--------|------|
| **CAP-FIX-01** | P0 | Índices `movimientos_caja` + rangos fecha sin cast (≡ PERF-FIX-01/02) | CAP-SQL-01 | Código/SQL |
| **CAP-FIX-02** | P0 | Documentar+exigir `DB_POOL_MAX` y `max_connections` en VPS; no default 10 | CAP-POOL-01/02 | Ops |
| **CAP-FIX-03** | P0 | Job purge/archivado `notificaciones_pendientes` (`enviada`/`abandonada` antiguas) | CAP-GROW-01 | Código |
| **CAP-FIX-04** | P1 | Retención `auditoria_logs` (partición mensual o archive R2) | CAP-GROW-02 | Código+ops |
| **CAP-FIX-05** | P1 | Redis + subir `CacheModule` / menú compartido; RL compartido | CAP-CACHE-01 · AQ-SCALE-04/05 | Infra+código |
| **CAP-FIX-06** | P1 | PM2 cluster o réplicas compose **solo tras** CAP-FIX-05 + advisory locks cron | CAP-INFRA-01 · AQ-SCALE-02 | Infra |
| **CAP-FIX-07** | P2 | Réplica lectura + reportes/dashboard contra réplica | CAP 1k+ | Infra |
| **CAP-FIX-08** | P2 | Paginar caja + kanban virtualizado (PERF-FL-FIX) | CAP-FL-01 | Código |
| **CAP-FIX-09** | P3 | Particionado `pedidos`/`pedido_items` por tiempo | CAP 1k+ | SQL |
| **CAP-FIX-10** | P3 | Plan MATIAS/FCM en cola Redis (no en request path) | CAP-FE-01 · CAP-PROC-01 | Código |

---

## Verificación (esta sesión)

```text
GET /api/v1/salud → exito:true, base_datos:true
SHOW max_connections → 100
SHOW shared_buffers → 128MB
pg_stat_activity backends → ~44
DB_POOL_MAX en foody_backend/.env → 25
n_live_tup notificaciones_pendientes → 39526 (enviada=t ~39352)
n_live_tup auditoria_logs → 33338
Dockerfile CMD → node dist/main.js (sin cluster)
```

**Gaps:** no se midió en VPS Hetzner real (P0-05 abierto); no hay 50k pedidos sintéticos (PERF-FIX-08); “restaurantes activos” es modelo, no carga multi-tenant 100 JWT reales.

---

## Solapes (no duplicar fix)

| CAP | Ya existía |
|-----|------------|
| CAP-POOL-* | AQ-SCALE-01 · PERF-POOL-01 · CONC-LOAD-POOL-01 |
| CAP-CACHE-01 | AQ-SCALE-04 · PERF-CACHE-05 |
| CAP-LOAD-01 | PERF-LOAD-02/03 · CONC-LOAD-LAT-01 |
| CAP-SQL-01 | PERF-SQL/IDX · ANA-PERF-01 · BD-IDX-02 |
| CAP-FL-01 | PERF-FL-LIST-01/07 |
| CAP-RT-01 | RT-LEAK-01 · AQ-SCALE-06 |
| CAP-FE-01 | FE-MATIAS-01 |
