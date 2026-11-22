# Foody — Auditoría Base de datos y Supabase self-hosted (Prompt 07)

> **Fecha:** 2026-08-06  
> **Alcance:** migraciones `foody_supabase/migrations` (001–079), Nest services (N+1), scripts/docs de backup.  
> **Método:** lectura estática + contraste con `docs/BACKUPS_FOODY.md`. Sin `EXPLAIN ANALYZE` runtime ni restore drill en esta pasada.  
> **Sucesora Prompt 08 (Docker):** [`AUDITORIA_DOCKER_ENV.md`](AUDITORIA_DOCKER_ENV.md) — DK-\*.  
> **Predecesoras:** AQ-\* · … · [`AUDITORIA_RBAC.md`](AUDITORIA_RBAC.md).  
> **Estado oficial:** [`MASTER_STATUS.md`](MASTER_STATUS.md) § BD / Supabase (BD-\*).  
> **Al cerrar un BD-\*:** marcar ✅ aquí + MASTER + viñeta en `AVANCE_PROYECTO.md`.  
> **Solapes:** N+1 menú/clone ≡ AQ-SCALE-03 / AQ-FIX-07; backups ≡ OPS-02.

---

## Veredicto

| Dimensión | Nota | Una línea |
|-----------|------|-----------|
| RLS | B+ | **73/73** tablas ENABLE+FORCE; modelo **deny-all** (no policies por tenant) |
| Filtro tenant en RLS | C | Tenant **no** en policies — aislamiento = NestJS + `SucursalScope` (RLS solo bloquea clientes directos) |
| Índices | B− | Pedidos/productos/mesas/usuarios OK (`056`/`070`); **faltan** caja/movimientos/catálogo extras |
| ON DELETE / FKs | B | Historial pedidos **protegido** (NO ACTION); `combo_items.item_id` sin FK |
| N+1 | C− | AQ-SCALE-03 vivo: menú combos, clone catálogo, stock por ítem |
| Backups | C | Scripts listos; **cron VPS + R2 no activados**; compose sin sidecar backup |

**Global Prompt 07:** ~**64 / 100** disciplina BD/ops (RLS deny-all sólido para el modelo Nest; backup prod y N+1 = deuda go-live).

**Qué ya está bien:**

- Migr. `028`→`064`: RLS exhaustivo + REVOKE `anon`/`authenticated`.
- Nest documentado: `DATABASE_URL` = rol postgres (bypass RLS) — Flutter no usa `postgres_changes` en tablas.
- `pedido_items.producto_id → productos` **sin CASCADE** → borrar producto con pedidos históricos **falla** (no borra historial).
- Índices hot path pedidos: `(sucursal_id, estado)`, `(sucursal_id, created_at)`, `pedido_items(pedido_id)`.
- Scripts `backup-postgres.ps1` / `.sh` + Task Scheduler Windows documentado.

---

## Índice de hallazgos

| Prefijo | Tema | Abiertos |
|---------|------|--------:|
| BD-RLS-* | Row Level Security | 4 |
| BD-IDX-* | Índices | 5 |
| BD-FK-* | Integridad referencial / ON DELETE | 4 |
| BD-N1-* | Consultas N+1 | 5 |
| BD-BKP-* | Backups automáticos | 4 |
| BD-FIX-* | Remediaciones | 7 |

Leyenda: `🟣 abierto` · `🟡 parcial / aceptado` · `✅ cerrado` · `📅 post-piloto`

---

## 1. RLS — ¿activo y filtrado por tenant? (BD-RLS)

### Modelo real

```
Cliente Supabase (anon/authenticated)  →  RLS FORCE + sin POLICY  →  0 filas
NestJS (DATABASE_URL / postgres)       →  bypass RLS              →  filtra en SQL app
```

| Pregunta | Respuesta |
|----------|-----------|
| ¿RLS activo en todas las tablas public? | **Sí** — 73/73 ENABLE + FORCE (`028`, `029`, `064`) |
| ¿Filtrado por `restaurante_id` / `sucursal_id` en policies? | **No** — 0 `CREATE POLICY` en `public.*` |
| ¿Qué protege RLS entonces? | Impide lectura/escritura directa desde Flutter/Supabase client o keys filtradas `anon` |
| ¿Tenant isolation? | **Aplicación** (`SucursalScope` + `WHERE sucursal_id`) — ver Prompt 06 |

Evidencia: `064_rls_exhaustivo_prod.sql:1-3`; `scripts/verificar-rls.ps1`.

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **BD-RLS-01** | ✅ | — | RLS ENABLE+FORCE en todas las tablas public críticas (pedidos, cajas, productos, usuarios, movimientos_*). **Revalidado 2026-08-06 Prompt 25:** **74/74** (+`empleados`) · ≡ SEC-RLS-01 |
| **BD-RLS-02** | 🟡 | Media | **No** hay policies por tenant — si alguien obtiene conexión con rol que bypass o un rol mal configurado, RLS no aísla A vs B | Aceptado por diseño mientras Nest = único writer |
| **BD-RLS-03** | 🟣 | Alta | Si `DATABASE_URL` en prod usara un rol **no**-superuser **con** grants pero **sin** policies, Nest rompería (0 filas) o al revés un rol con BYPASSRLS mal documentado | Documentar rol exacto en VPS (`PREPARACION_VPS`) |
| **BD-RLS-04** | 🟡 | Baja | Storage `foody-assets`: policies públicas de lectura; write “service” sin check explícito `auth.role()` en body de policy (`057`) | Revisar al endurecer Storage |

**Respuesta corta:** RLS **está activo** en todas las tablas. **No** filtra por tenant en SQL policies; el filtro tenant es NestJS. Correcto para “Nest = cerebro”; insuficiente si se espera RLS multi-tenant clásico de Supabase.

---

## 2. Índices (BD-IDX)

### Cubiertos bien

| Tabla | Índices | Migr. |
|-------|---------|-------|
| `pedidos` | `(sucursal_id, estado)`, `(sucursal_id, created_at)` | `005` |
| `productos`, `categorias`, `mesas`, `usuarios` | `sucursal_id` (+ compuestos) | `056` |
| `pedido_items` | `pedido_id` | `056` |
| `ingredientes`, `movimientos_ingrediente` | sucursal / fecha | `056` |
| Analítica | mesera+created, cocina, producto, alertas | `070` |

### Gaps

| ID | Estado | Sev | Gap | Impacto |
|----|--------|-----|-----|---------|
| **BD-IDX-01** | 🟣 | Alta | `cajas` sin `(sucursal_id, estado)` | Lookup caja abierta en cada cobro |
| **BD-IDX-02** | 🟣 | Alta | `movimientos_caja` sin `caja_id` ni `(sucursal_id, created_at)` | Cuadre / listados (también API-PAGE unbounded). **Reconfirmado 2026-08-06 Prompt 23:** solo PK vivo; `idx_scan=0` · ≡ **PERF-IDX-01** |
| **BD-IDX-03** | 🟣 | Media | `combos` / `bebidas` / `toppings` / `recetas` / `cocinas` sin `sucursal_id` | Menú admin / clone |
| **BD-IDX-04** | 🟣 | Media | `facturas`, `gastos`, `cuentas_por_cobrar`, `zonas_cobertura`, `horarios_sucursal` | Reportes / pedido create |
| **BD-IDX-05** | 🟡 | Baja | Doc `OPTIMIZACION_ESCALABILIDAD_FOODY.md` desactualizado (aún pide índices ya hechos en `056`) | Confusión DX |

---

## 3. Integridad referencial / ON DELETE (BD-FK)

### ¿Borrar un producto con pedidos históricos?

```sql
-- 005_pedidos.sql
producto_id uuid REFERENCES productos(id)  -- sin ON DELETE → NO ACTION
```

| Acción | Resultado |
|--------|-----------|
| `DELETE FROM productos WHERE id = X` y existen `pedido_items` | **ERROR** FK violation — historial **intactos** |
| Soft-delete / `disponible=false` | Patrón seguro de app |
| CASCADE desde producto → pedido_items | **No existe** (bien) |

### Hallazgos

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **BD-FK-01** | ✅ | — | Historial pedidos/protegido: FKs a `productos`/`pedidos` = **NO ACTION** (default) |
| **BD-FK-02** | 🟣 | Media | `combo_items.item_id` **sin FK** (polimórfico) — integridad solo en app | Huérfanos posibles |
| **BD-FK-03** | 🟡 | Baja | CASCADE explícito solo en junctions (`producto_items_incluidos`, `pago_pedido_items→pago`, tokens, `fuentes_pago`) — no borra historial de ventas | OK si se documenta |
| **BD-FK-04** | 🟡 | Baja | `auth_uid` en dispositivos/pedidos sin FK a `auth.users` | Esperable (auth schema aparte) |

---

## 4. Consultas N+1 (BD-N1)

≡ AQ-SCALE-03 / AQ-FIX-07 (no duplicar remediación; registrar evidencia).

| ID | Estado | Sev | Ubicación | Patrón |
|----|--------|-----|-----------|--------|
| **BD-N1-01** | 🟣 | Alta | `menu.service.ts` ~183–194 | 1 query `combo_items` **por combo** en menú público |
| **BD-N1-02** | 🟣 | Alta | `catalogo.service.ts` clone ~622–808 | SELECT/INSERT por categoría/producto/vínculo |
| **BD-N1-03** | 🟣 | Alta | `pedidos-inventario.service.ts` ~334–386, ~844–894 | Expansión stock / queries por línea |
| **BD-N1-04** | 🟣 | Media | `catalogo-disponibilidad.service.ts` ~73–132 | Disponibilidad por producto + stock por ingrediente |
| **BD-N1-05** | 🟣 | Media | `inventario` hermanas; `analitica` KPIs por sede; cron QR auditoría | Loops `await` por sede/ítem |

**Contraste OK:** admin `listarCombos` usa `json_agg` batch; toppings/bebidas menú se agrupan en memoria tras 1 fetch.

---

## 5. Backups Postgres self-hosted (BD-BKP)

### ¿Está configurado el backup automático?

| Entorno | ¿Automático? | Dónde | Frecuencia |
|---------|--------------|-------|------------|
| Windows / PC + túnel | **Opcional** vía Task Scheduler (`programar-backup-windows.ps1`) | `./backups/foody_db-*.sql` | Diario **03:00** si se registró la tarea |
| Docker compose (dev/prod) | **No** — sin sidecar/cron en compose | — | — |
| VPS Ubuntu (prod objetivo) | **No activado** — cron solo documentado | Objetivo: `/var/backups/foody/*.sql.gz` | Diario 03:00 (cuando se instale) |
| Offsite R2 | **No wired** — script soporta `R2_REMOTE` | R2 path configurable | Tras dump local |

Evidencia: `docs/BACKUPS_FOODY.md` (checklist prod abierto); `scripts/backup-postgres.sh`; `setup-ubuntu-vps.sh` **imprime** cron, no lo instala.

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **BD-BKP-01** | 🟣 **prod-risk** | Alta | Backup automático **VPS no activo** — riesgo pérdida total si cae disco sin dump | OPS-02 |
| **BD-BKP-02** | 🟣 | Media | Compose sin job de backup — depende de cron del host | |
| **BD-BKP-03** | 🟡 | Media | Windows Task Scheduler documentado; **no verificado** en esta pasada si la tarea está instalada en la máquina del user | |
| **BD-BKP-04** | 🟣 | Media | Sin restore drill reciente documentado (checklist mensual abierto) | |

**Respuesta corta:** hay **scripts** y runbook. El contenedor Postgres **no** hace backup solo. Automático = cron del SO / Task Scheduler. En VPS **aún no** está el cron+R2 según docs.

---

## 6. Backlog remediación (BD-FIX)

| ID | Prioridad | Acción | Cierra | Prod-risk |
|----|-----------|--------|--------|-----------|
| **BD-FIX-01** | P0-ops | Activar cron VPS + R2; 3 mañanas OK; update checklist `BACKUPS_FOODY` | BD-BKP-01/02/04, OPS-02 | **Sí** |
| **BD-FIX-02** | P1 | Migr. índices: `cajas(sucursal_id,estado)`, `movimientos_caja(caja_id)`, catálogo extras, facturas/gastos/CxC | BD-IDX-01…04 | Medio |
| **BD-FIX-03** | P1 | Batch N+1 menú combos (≡ AQ-FIX-07) | BD-N1-01 | Medio |
| **BD-FIX-04** | P1 | Batch clone catálogo + stock `ANY($1)` | BD-N1-02/03 | Medio |
| **BD-FIX-05** | P2 | Documentar rol PG exacto en VPS + verificar `verificar-rls.ps1` en prod | BD-RLS-02/03 | Bajo |
| **BD-FIX-06** | P2 | Soft-delete productos documentado / UI “no se puede borrar si hay pedidos” | BD-FK-01 UX | Bajo |
| **BD-FIX-07** | P3 | FK o check constraint en `combo_items` / validación estricta en service | BD-FK-02 | Bajo |

---

## 7. Matriz de conteo

| Grupo | 🟣 | 🟡 | ✅ |
|-------|---:|---:|---:|
| BD-RLS | 1 | 2 | 1 |
| BD-IDX | 4 | 1 | 0 |
| BD-FK | 1 | 2 | 1 |
| BD-N1 | 5 | 0 | 0 |
| BD-BKP | 3 | 1 | 0 |
| **Total** | **14** | **6** | **2** |
| BD-FIX | 7 | | |

---

## 8. Cómo verificar al remediar

| Fix | Evidencia |
|-----|-----------|
| BD-FIX-01 backup | 3 archivos en `/var/backups/foody` o R2; restore a DB test |
| BD-FIX-02 índices | `\d+ cajas` / `movimientos_caja` muestran índices; `EXPLAIN` caja abierta usa index |
| BD-FIX-03/04 N+1 | Un request menú con N combos → O(1) queries combo_items; clone 1 TX batch |
| BD-FIX-05 RLS | `.\scripts\verificar-rls.ps1` en VPS → OK |
| Borrar producto | `DELETE producto` con pedidos → error FK; UI mensaje claro |

---

## Changelog de este documento

| Fecha | Cambio |
|-------|--------|
| 2026-08-06 | **PERF-23:** BD-IDX-02 reconfirmado en vivo (`movimientos_caja` solo PK, `idx_scan=0`) · ≡ PERF-IDX-01 |
| 2026-08-06 | Enlace a Prompt 08 (`AUDITORIA_DOCKER_ENV.md`) |
| 2026-08-06 | **Creación** Prompt 07 — BD-RLS/IDX/FK/N1/BKP + BD-FIX-01…07; enlazado MASTER / AVANCE / README / ROADMAP |

---

*Fin — Auditoría Base de datos y Supabase (Prompt 07).*
