# Auditoría — Estrés y concurrencia (Prompt 26)

> **Fecha:** 2026-08-06  
> **Alcance:** multi-restaurante/usuarios en paralelo; races pedido / inventario / caja; carga sostenida vs pico.  
> **Entorno:** API Nest `http://127.0.0.1:3000`, Postgres demo (`supabase-db`), sedes Centro + Norte.  
> **Checks:** `scripts/verificar-estres-concurrencia.ps1` · `scripts/estres-1000-usuarios.mjs` (100×3 + 10 writes) · refs `estres-api-foody.ps1`.  
> Relacionados: [`AUDITORIA_PERF_BACKEND.md`](AUDITORIA_PERF_BACKEND.md) (PERF-LOAD) · [`AUDITORIA_APIS_REST.md`](AUDITORIA_APIS_REST.md) (API-IDEM) · [`AUDITORIA_MESEROS_MESAS.md`](AUDITORIA_MESEROS_MESAS.md) (MES-RACE-01) · R10.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| ¿Varios tenants/sedes en paralelo se pisan? | **No en lecturas** — 60 GET menú A/B + salud + ciudades OK; dashboards Centro/Norte 200. Aislamiento por `sucursal_id` en queries. |
| ¿Dos procesos al mismo pedido/ítem? | **Pedido:** `FOR UPDATE` + no-op si mismo estado → ambos HTTP OK, stock una vez. **Inventario ajuste absoluto:** LWW sin `FOR UPDATE` (final = uno de los targets). **Caja abrir:** race no ejecutada (turno abierto); código = check-then-insert ≡ **API-IDEM-03**. |
| ¿Sostenido vs pico “viernes noche”? | Salud sostenida ~70 RPS p95~5 ms. Pico menú+salud 80 conc ~675 RPS p95~3 ms (endpoints ligeros). Bajo mezcla real (100 usuarios × 3 endpoints + pedidos): **0 err**, p99 lecturas ~10 s, writes ×10 p50~207 ms — mismo techo que PERF-LOAD (pool Nest/PG). |

**Veredicto:** concurrencia de **negocio** en pedido (estado/idempotencia/mesa adds) es sólida. Huecos: **abrir caja TOCTOU**, **ajuste stock sin row lock** (lost update relativo), saturación de **latencia** bajo pico mixto (no caídas HTTP). Apto demo/piloto; “viernes noche” multi-sede masivo necesita pool/índices/PM2 (Prompt 23).

---

## A) Multi-tenant / multi-usuario paralelo

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CONC-MT-01** | ✅ | — | 15 rounds × (menú Centro + menú Norte + salud + ciudades) = 60/60 OK, wall ~150–170 ms | `verificar-estres-concurrencia.ps1` A |
| **CONC-MT-02** | ✅ | — | Dashboard ambas sedes 200 (admin cadena); no mezcla de datos en respuesta por path | Mismo script |
| **CONC-MT-03** | 🟡 | Info | No stresseamos N restaurantes con JWT distintos escribiendo a la vez (solo lecturas + admin demo) | Gap QA |

---

## B) Races mismo registro

### Pedido

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CONC-PED-IDEM-01** | ✅ | — | 2× `POST /pedidos` misma `idempotency_key` → **1** pedido único (`pg_advisory_xact_lock` + tabla) | Script B · ≡ API-IDEM-01 |
| **CONC-PED-EST-01** | ✅ | — | 2× `PATCH …/estado` → `en_cocina` concurrentes: **ok=2** (1 aplica + 1 no-op `anterior===nuevo` tras `FOR UPDATE`); estado final `en_cocina`; sin doble descuento stock (flag `stock_descontado`) | `pedidos-estado.service.ts` L91–121 · script B |
| **CONC-PED-MESA-01** | ✅ | — | Adds concurrentes a mesa serializados (doc previo) | ≡ MES-RACE-01 |
| **R10** | 🟡 | Borde | 2 QR distintos → stock insuficiente al **aprobar** (diseño) | REGISTRO / MASTER |

### Inventario

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CONC-INV-ABS-01** | ✅ | — | 2 PATCH `stock_nuevo` (+1 vs +2) → ambos 200; stock final **uno** de los targets (LWW); sin valor intermedio “roto” | Script B |
| **CONC-INV-LOCK-01** | ✅ | Media | `exigirIngrediente` usa `FOR UPDATE` | `inventario.service.ts` · `verificar-conc-inv-infra-down.ps1` |
| **CONC-INV-PED-01** | ✅ | — | Descuento por pedido usa locks en path cocina/inventario pedido | `pedidos-inventario` FOR UPDATE |

### Caja

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CONC-CAJ-ABRIR-01** | 🟣 | Alta | `abrir`: SELECT abierta → INSERT **fuera** de un único lock/unique parcial; TOCTOU → 2 cajas abiertas posibles | `caja.service.ts` L58–77 · ≡ **API-IDEM-03** |
| **CONC-CAJ-SKIP-01** | 🟡 | — | Race abrir **omitida** en demo (caja ya abierta; no cerramos turno automático) | Script aviso |
| **CONC-CAJ-COBRO-01** | 🟡 | Media | Cobro con `FOR UPDATE` pedido; sin idempotency key cliente ≡ **API-IDEM-02** | AUDITORIA_APIS_REST |

---

## C) Carga sostenida vs pico

| Escenario | n | ok/fail | wall / RPS | p50 / p95 (ms) | Notas |
|-----------|---|:-------:|------------|----------------|-------|
| Sostenido GET `/salud` | 160 seq-ish pool | 160/0 | ~2.3 s / ~70 RPS | 2 / 5 | Script C |
| Pico 80 conc menú+salud | 80 | 80/0 | ~0.12 s / ~650–675 RPS | 1–2 / 3 | Cache menú ayuda |
| Mixto 100×3 (salud/menú/promo/pedidos/movs) | 300 | 300/0 | ~10.6 s / ~28 RPS | 110 / 347; **p99~10500** | `estres-1000-usuarios.mjs` |
| Pico writes POST pedidos | 10 | 10/0 | 0.56 s / ~18 RPS | 207 / 468 | Mismo script |
| PERF 200 conc (Prompt 23) | 200 | 0 fail HTTP | — | p50 **7–10 s** | Techo Nest+pool |

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CONC-LOAD-OK-01** | ✅ | — | 0 errores HTTP en sostenido ligero, pico ligero, 100×3 y 10 writes | Scripts sesión |
| **CONC-LOAD-LAT-01** | 🟣 | Alta | Bajo mezcla “operación real” p99≈10 s (cola pool) — mismo fenómeno **PERF-LOAD-02/03** | estres-1000 · PERF |
| **CONC-LOAD-POOL-01** | 🟣 | Alta | Cuello: Nest single-process + `DB_POOL_MAX` (default 10 / demo 25) | ≡ PERF-POOL / AQ-SCALE-01 |
| **CONC-LOAD-FRI-01** | 🟡 | Info | “Viernes noche” simulado solo en 1 PC/1 Nest; no multi-réplica ni edge Cloudflare | Limitación lab |

---

## Inventario de locks / idempotencia (código)

| Área | Mecanismo | Notas |
|------|-----------|--------|
| Crear pedido | `idempotency_key` + `pg_advisory_xact_lock` | Fuerte |
| Cambiar estado / cobro / items mesa | `SELECT … FOR UPDATE` en `pedidos` | Idempotente si mismo estado |
| Stock al cocinar | Transacción + `stock_descontado` | Evita doble descuento |
| Abrir caja | Check-then-insert | **Débil** |
| Ajuste ingrediente manual | Transacción sin row lock | LWW absoluto |
| Rate limit | Decorators login/pedidos | Solo si `NODE_ENV=production` (SEC-RLIMIT) |

---

## Backlog (CONC-FIX)

| ID | Prio | Acción | Cierra |
|----|------|--------|--------|
| **CONC-FIX-01** | P1 | Unique parcial `cajas (sucursal_id) WHERE estado='abierta'` + abrir dentro de tx/`FOR UPDATE` advisory | CONC-CAJ-ABRIR-01 / API-IDEM-03 |
| **CONC-FIX-02** | P2 | `FOR UPDATE` en `exigirIngrediente` (o `UPDATE … WHERE stock_actual=$esperado`) | CONC-INV-LOCK-01 |
| **CONC-FIX-03** | P1 | Subir pool + índices/caché (reusa PERF-FIX) para picos viernes | CONC-LOAD-LAT-01 |
| **CONC-FIX-04** | P3 | Idempotency key en cobro (API-FIX-03) | CONC-CAJ-COBRO-01 |
| **CONC-FIX-05** | P3 | Extender script: race abrir caja en sede sin turno + 2 JWT staff distintos | CONC-CAJ-SKIP / CONC-MT-03 |

---

## Verificación (sesión)

```text
verificar-estres-concurrencia.ps1 → exit 0, avisos=1 (caja abierta)
estres-1000-usuarios.mjs 100 3 --writes=10 → lecturas 300/0, writes 10/0, VEREDICTO OK
```

**Gaps:** click-through UI multi-caja; race abrir caja no corrida en demo; no 1000 usuarios reales ni VPS.
