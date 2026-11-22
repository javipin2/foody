# Recomendaciones ops / escala — implementado vs pendiente

**Última actualización:** 2026-08-03 — Fase 0 VPS PC+túnel (OPS-04 ✅; OPS-02/03/05 🟡).  
**Origen:** recomendaciones de sesión (VPS, backups, pool, FCM, estados, UX, analítica) + `OPTIMIZACION_ESCALABILIDAD_FOODY.md` + `AUDITORIA_PREPROD.md`.  
**Deuda estructural (código/capas, no solo ops):** ver `AUDITORIA_ARQUITECTURA_CALIDAD.md` (AQ-SCALE / AQ-FIX-04 solapan pool/crons/rate-limit).  
**Cómo usar:** implementar solo ítems `⏳` / `🟡` según prioridad; marcar `✅` al cerrar y actualizar `MASTER_STATUS.md`.

---

## Resumen ejecutivo

| Estado | Cantidad | Qué implica |
|--------|---------:|-------------|
| ✅ Hecho | 17 | No rehacer |
| 🟡 Parcial | 3 | Cerrar hueco (VPS / cuenta UptimeRobot / Winston) |
| ⏳ Pendiente | 5 | Spec lista; mayormente VPS/hardware/Wompi |
| 📅 Después (100+ sedes) | 3 | No tocar hasta escala |

**Bloqueantes go-live serio:** OPS-01 VPS, OPS-02 cron+R2 en servidor, OPS-03 Wompi prod.  
**Piloto 5–15 sedes:** OPS-01 + activar cron backups + `DB_POOL_MAX=25`.

**Verificación local:** `.\scripts\verificar-ops-recomendaciones.ps1` · estrés: `.\scripts\estres-api-foody.ps1`

### Benchmark estrés (2026-08-01, PC local + Docker + API :3000)

Lecturas mixtas (`/salud`, `/menu`, `/promociones`, `/pedidos`, `/inventario/movimientos`):

| Workers | Reqs | RPS | p50 | p95 | Errores |
|--------:|-----:|----:|----:|----:|--------:|
| 20 | 300–500 | ~410–480 | ~20 ms | ~90 ms | 0% |
| 40 | 600–1000 | ~330–540 | ~30–50 ms | ~140–220 ms | 0% |
| 80 | 1200 | ~445 | ~63 ms | ~434 ms | 0% |

### Benchmark 1000×5 + escrituras (2026-08-01)

```bash
node scripts/estres-1000-usuarios.mjs 1000 5 --writes=50
```

**Dónde pegan las consultas (no es Flutter):**

```
PC (Node fetch)
  → NestJS API  :3000  (proceso node dist/main.js)
      → MenuCacheService (RAM) para /menu en cache hit
      → Pool pg DB_POOL_MAX≈10
          → Docker supabase-db (PostgreSQL real)
```

No intervienen: Flutter Chrome, Cloudflare, FCM, impresora.

**Capacidad observada en la oleada 1000×5 (5000 lecturas):**

| Recurso | Durante el pico |
|---------|-----------------|
| RAM host | ~95–97% usada (~550–770 MB libres de 16 GB) |
| supabase-db CPU | **~60–88%** |
| supabase-db RAM | ~210 MB |
| Nest (node) | ~150–260 MB |
| foody_postgres_dev | casi idle (no es la BD que usa la API) |

**Lecturas 1000 usuarios × 5:**

| | |
|--|--:|
| Total | 5000 |
| OK | **5000 (0% error)** |
| Duración | **7,1 s** |
| RPS | ~704 |
| p50 / p95 | **1,0 s / 2,9 s** |
| Más lentos | `movimientos` y `pedidos` (SQL); `/menu` p50 **6 ms** (caché) |

**Escrituras 50 POST /pedidos en paralelo** (tras fix `precio` en DTO):

| | |
|--|--:|
| OK | **50/50** |
| Duración oleada | **9,6 s** |
| p50 / p95 | **2,8 s / 8,7 s** |
| RPS | ~5 |

Una 2ª ráfaga seguida (20 writes) empezó a **timeout** (pool/locks/mesa): las escrituras saturan mucho antes que las lecturas.

---

## Matriz rápida

| ID | Recomendación | Estado | Evidencia / dónde |
|----|---------------|--------|-------------------|
| UX-01 | Errores suscripción legibles (no DioException) | ✅ | `mensaje_error_http.dart`, `FoodyEstadoUi`, filter `RESTAURANTE_BLOQUEADO` |
| UX-02 | Ciudad persistente + Inicio = lugares | ✅ | `CiudadPreferenceService`, nav inferior, ⋮ Cambiar ciudad |
| UX-03 | Estados: 1 anillo/restaurante + video ≤30s | ✅ | migr. `077`, stories bar, `POST /almacenamiento/video` |
| BUG-01 | Analítica SQL `id` ambiguo + pool no tumba Node | ✅ | `analitica-filtros.util.ts`, `database.service.ts` `pool.on('error')` |
| OPT-01 | Pool PG configurable | ✅ | `DB_POOL_MAX` (default 10) |
| OPT-02 | Caché menú TTL 5 min | ✅ | `MenuCacheService` + invalidación catálogo |
| OPT-03 | Índices `sucursal_id` / fechas | ✅ | migr. `056_indices_rendimiento.sql` |
| OPT-04 | Paginación pedidos | ✅ | API `page`/`limit` en pedidos + cerrados-hoy + movimientos; UI «Cargar más» kanban/inventario |
| OPT-05 | Realtime > poll agresivo | ✅ | `PollRealtimeRespaldo` 90s/45s; KDS + domi independiente usan helper |
| FCM-01 | No marcar enviada si todos fallan | ✅ | `notificaciones.service.ts` |
| FCM-02 | Tope de reintentos / dead-letter | ✅ | migr. `078` `intentos`/`abandonada`; máx 10 (`FCM_MAX_INTENTOS`) |
| OPS-01 | Despliegue VPS + HTTPS | ⏳ | Fase 0 PC+túnel ✅ (`verificar-listo-vps.ps1`); deploy Ubuntu = Fase 1 |
| OPS-02 | Backups automáticos + offsite | 🟡 | Scripts ✅ + Task Scheduler Windows ✅; cron+R2 en VPS pendiente |
| OPS-03 | Wompi producción | 🟡 | Redirect+webhook URL túnel ✅; falta registrar en dashboard (+ claves prod si cobras) |
| OPS-04 | `DB_POOL_MAX` en prod (20–30) | ✅ | `DB_POOL_MAX=25` en `.env` PC (2026-08-03) |
| OPS-05 | Health + UptimeRobot externo | ✅ | Monitor `api.foodyy.store` Up (2026-08-03) · URL `/api/v1/health` · 5 min |
| OPS-06 | Impresora física en sitio | ⏳ | Modo archivo OK; hardware no validado |
| OPS-07 | Canales Realtime privados (JWT) | ⏳ | Anon key en cliente; riesgo documentado |
| STOR-01 | Limpieza Storage estados expirados | ✅ | Cron 6h + `POST /promociones/admin/limpiar-expiradas`; delete al eliminar |
| STOR-02 | R2 Cloudflare imágenes prod | 📅 | Self-hosted Storage OK hasta ~30 sedes |
| SCALE-01 | Redis + Nest cluster | 📅 | Solo 100+ sedes / multi-instancia |
| SCALE-02 | Winston / logs estructurados prod | 🟡 | Filter logs 500; Winston no |
| DOC-01 | MASTER “caché menú ausente” obsoleto | ✅ corregir en docs (esta sesión) |

---

## ✅ Ya implementado (no rehacer)

### UX / producto (sesión reciente)

1. **Suscripción bloqueada** — mensaje claro + CTA Reactivar; código `RESTAURANTE_BLOQUEADO` preservado en filtro HTTP.
2. **Home cliente** — ciudad guardada; picker solo 1ª vez / cambio; FCM sincroniza ciudad.
3. **Estados WhatsApp** — un anillo por restaurante; clips foto/video; mute autoplay web.

### Estabilidad / rendimiento fase 1

4. **Pool** — `DB_POOL_MAX` + handler de error en cliente idle.
5. **Caché menú** — `@nestjs/cache-manager` / `MenuCacheService`.
6. **Índices** — migr. `056`.
7. **Paginación API pedidos** — query `page`/`limit`.
8. **Compose prod + Dockerfile** — build local verificable.
9. **Backup manual** — `scripts/backup-postgres.ps1`.
10. **Health** — `/salud`, `/health`, `verificar-salud.ps1`.
11. **FCM** — no marca `enviada` si 0 envíos exitosos.
12. **Fix analítica** — filtros sin ambigüedad de `id`.

---

## 🟡 Parcial — cerrar

### OPT-04 — Paginación en UI / reportes ✅

- `GET /pedidos/cerrados-hoy?page&limit` → `{ items, total, … }`
- `GET /inventario/movimientos/:id?page&limit` igual
- Auditoría timeline: techo `LIMIT 500` por fuente
- UI: kanban «Cargar más» cerrados; inventario movimientos paginado
- Script: `scripts/verificar-paginacion-ops.ps1`

### OPT-05 — Poll vs Realtime ✅

- `PollRealtimeRespaldo`: 90 s con RT OK / 45 s si caído
- KDS y domiciliario independiente usan el helper (ya no poll fijo 20–30 s)

### OPS-04 — Pool en producción

| | |
|--|--|
| **Hecho** | `DB_POOL_MAX=25` en `.env` PC + `.env.example` (2026-08-03). |
| **Falta** | Confirmar mismo valor en `.env` del VPS al desplegar OPS-01. |

### OPS-05 — Monitor externo

| | |
|--|--|
| **Hecho** | Monitor UptimeRobot **Up** (2026-08-03): `https://api.foodyy.store/api/v1/health`, cada 5 min. |
| **Falta** | Nada bloqueante. Opcional: alerta email + keyword `"base_datos":true` si el plan lo permite. |

### SCALE-02 — Logs

| | |
|--|--|
| **Hecho** | `HttpExceptionFilter` loguea 500. |
| **Falta** | Winston o pino + rotación en VPS (opcional). |

---

## ⏳ Pendiente — spec de implementación

### OPS-01 — VPS + HTTPS (P0-05 / P3-06)

**Objetivo:** API + Supabase + Flutter web en servidor Ubuntu, no en PC.

**Pasos (orden):** ver `docs/PREPARACION_VPS.md`. Resumen:

1. VPS Ubuntu 22.04+, Docker Compose.
2. Clonar repo → Supabase self-hosted → migraciones `001…077+`.
3. `.env` con `ENTORNO=produccion`, `JWT_SECRET` fuerte, CORS cerrado.
4. `docker compose -f docker-compose.prod.yml up -d --build`.
5. Cloudflare Tunnel **o** Nginx+TLS.
6. `verificar-salud.ps1 -BaseUrl https://…` + QA roles.

**Criterio hecho:** `/health` OK desde Internet; login demo staff vía dominio; PC apagado no tumba el servicio.

**No incluye:** comprar VPS (acción humana).

---

### OPS-02 — Backups automáticos + offsite (auditoría P0-07 backups)

> Nota: en `ROADMAP_TERMINAR_FOODY.md`, **P0-07** es Wompi redirect. Aquí **OPS-02** = backups (como en `AUDITORIA_PREPROD.md`).

**Objetivo:** dump diario + retención + copia fuera del VPS + alerta si falla.

**Fase A — Cron en VPS (mínimo viable)**

1. Reutilizar lógica de `scripts/backup-postgres.ps1` en bash:
   - `scripts/backup-postgres.sh` (nuevo): `docker exec` pg_dump → `/var/backups/foody/foody_YYYYMMDD_HHMM.sql.gz`.
2. Cron: `0 3 * * * /opt/foody/scripts/backup-postgres.sh`.
3. Retención local: borrar `> 14` días (`find … -mtime +14 -delete`).
4. Log: `/var/log/foody-backup.log`; exit ≠ 0 → mail/Telegram (script).

**Fase B — Offsite (obligatorio antes de dinero real)**

1. Subir `.sql.gz` a **Cloudflare R2** o S3 (rclone o AWS CLI).
2. Credenciales solo en VPS (`R2_ACCESS_KEY`, bucket `foody-backups`).
3. Retención offsite 30 días.
4. Probar restore en staging 1 vez al mes (checklist).

**Criterio hecho:** 3 mañanas seguidas hay dump local + objeto en R2; restore de prueba documentado en `docs/archivo/qa-sesiones/`.

**Archivos a tocar:**

| Archivo | Acción |
|---------|--------|
| `scripts/backup-postgres.sh` | Crear (Linux/cron) |
| `scripts/backup-postgres.ps1` | Mantener (dev Windows) |
| `docs/archivo/auditorias-prompts/AUDITORIA_PREPROD.md` | Marcar OPS-02 al cerrar |
| `docs/PREPARACION_VPS.md` | Sección «Backups» con cron + R2 |

---

### OPS-03 — Wompi producción

**Doc:** `docs/WOMPI_PRODUCCION.md`.  
**Hecho (túnel):** redirect `equipo.foodyy.store` + webhook URL `api.foodyy.store` + `verificar-wompi-tunel.ps1`.  
**Falta:** registrar URL en dashboard Wompi (+ claves `pub_prod_` si cobras en serio) y un pago de prueba.

---

### FCM-02 — Tope de reintentos ✅

Migr. `078`: columnas `intentos`, `abandonada`. Tras `FCM_MAX_INTENTOS` (default 10) deja de reintentar. Diagnóstico: `abandonadas_24h`, `max_intentos`.

### STOR-01 — Limpieza Storage estados ✅

`PromocionesCronService` cada 6 h; `POST /promociones/admin/limpiar-expiradas`; `eliminar` borra objeto Storage. Grace 7 días tras `expira_at`.

---

### OPS-06 — Impresora física

**Doc:** `docs/IMPRESION_RESTAURANTE.md`.  
**Criterio:** ticket real en cocina en un restaurante piloto.

---

### OPS-07 — Realtime privado

**Riesgo:** cliente con anon key puede suscribirse a canales si conoce el nombre.  
**Implementar:** canales privados + JWT Supabase Realtime (spec en `ESTRATEGIA_REALTIME_FOODY.md`).  
**Cuándo:** pre go-live multi-tenant serio; no bloquea demo.

---

## 📅 Después (no implementar ahora)

| ID | Qué | Disparador |
|----|-----|------------|
| STOR-02 | Imágenes en R2 CDN | >30 sedes o disco VPS al límite |
| SCALE-01 | Redis + varias réplicas Nest | >100 sedes o multi-instancia API |
| — | PM2 cluster sin Redis sticky | Solo si una sola máquina y CPU ociosa; Realtime/WS revisar |

---

## Orden recomendado de ejecución

```
1. ~~OPS-05 UptimeRobot~~ ✅ (monitor Up 2026-08-03)
2. OPS-03 registrar webhook Wompi en dashboard                   🟡
3. OPS-01 VPS Ubuntu (Fase 1 PREPARACION_VPS)                    ⏳
4. OPS-02 cron + R2 en VPS                                       🟡
5. OPS-06 impresora                                              ⏳
6. OPS-07 Realtime JWT                                           ⏳
```

Hecho en código (2026-08-01): FCM-02, STOR-01, scripts backup, OPT-04, OPT-05.
---

## Checklist al implementar un ítem

1. Código / script / cron según spec de arriba.  
2. Verificación real (comando o restore).  
3. Actualizar esta tabla → `✅`.  
4. Viñeta en `docs/AVANCE_PROYECTO.md` + fila en `MASTER_STATUS.md`.  
5. Si es P0 roadmap, checkbox en `ROADMAP_TERMINAR_FOODY.md` (usar ID correcto: Wompi ≠ backups).

---

## Referencias

- `docs/archivo/auditorias-prompts/AUDITORIA_PREPROD.md` — P0 preprod  
- `docs/PREPARACION_VPS.md` — deploy  
- `docs/OPTIMIZACION_ESCALABILIDAD_FOODY.md` — fases rendimiento  
- `docs/MONITOREO_SALUD.md` — health  
- `scripts/backup-postgres.ps1` — backup manual actual  
