# Foody — Auditoría APIs REST (Prompt 04)

> **Fecha:** 2026-08-05  
> **Alcance:** `foody_backend/src` — códigos HTTP, validación de inputs, paginación, idempotencia, formato de respuesta.  
> **Método:** lectura estática (grep + muestreo controllers/services/filtros). Sin carga runtime ni fuzzing en esta pasada.  
> **Sucesora Prompt 05 (Auth):** [`AUDITORIA_AUTH_JWT.md`](AUDITORIA_AUTH_JWT.md) — AUTH-\*.  
> **Predecesoras:** AQ-\* · BN-\* · FL-\*.  
> **Estado oficial:** hallazgos abiertos también en [`MASTER_STATUS.md`](MASTER_STATUS.md) § APIs REST (API-\*).  
> **Al cerrar un API-\*:** marcar ✅ aquí + MASTER + viñeta en `AVANCE_PROYECTO.md`.  
> **Nota de IDs:** prefijo `API-*` (no confundir con `FL-API-*` de Prompt 03 = separación UI/repos Flutter).

---

## Veredicto

| Dimensión | Nota | Una línea |
|-----------|------|-----------|
| Códigos HTTP | C+ | Filter mapea 401/403/404; **0× `@HttpCode(201)`**; conflictos de negocio casi todos **400** |
| Validación inputs | C | Pipe `whitelist` OK; **sin** `forbidNonWhitelisted` / `ParseUUIDPipe`; ~19 bodies inline (≡ BN-DTO) |
| Paginación listas | C− | Helpers existen; solo pedidos (+movimientos inventario) los usan; caja/usuarios/catálogo **sin tope** |
| Idempotencia | B− | Pedidos `idempotency_key` + Wompi replay OK; **cobro/caja sin clave** cliente |
| Formato respuesta | B | Envelope `{ exito, datos\|error, mensaje }` global; bypass HTML/CSV; códigos 400 a menudo aplanados |

**Global Prompt 04:** ~**66 / 100** disciplina REST (contrato HTTP + listas + idempotencia crítica).

**Qué ya está bien (no rehacer):**

- `RespuestaInterceptor` + `HttpExceptionFilter` globales (`app.module.ts`).
- `ValidationPipe({ whitelist, transform })` en `main.ts`.
- SQL parametrizado dominante (`$1` / `SqlParams`); sin concat de input en SQL observado.
- Crear pedido: `idempotency_key` + `pedidos_idempotencia` + advisory lock TX.
- Cobro: `FOR UPDATE` en fila pedido (mitiga doble cobro concurrente).
- Webhook Wompi: firma + soft-idempotencia por `transaccion_wompi_id`.
- Helpers `resolverPaginacion` / `envolverPaginado` (limit ≤100) en `compartido/dto/paginacion.dto.ts`.
- `ConflictException` (409) en email duplicado (usuarios / onboarding / super-admin).

---

## Índice de hallazgos

| Prefijo | Tema | Abiertos (aprox.) |
|---------|------|------------------:|
| API-HTTP-* | Códigos de estado | 8 |
| API-VAL-* | Validación / inputs maliciosos | 8 |
| API-PAGE-* | Paginación de listados | 9 |
| API-IDEM-* | Idempotencia operaciones críticas | 6 |
| API-FMT-* | Consistencia formato respuesta | 6 |
| API-FIX-* | Remediaciones priorizadas | 6 |

Leyenda: `🟣 abierto` · `🟡 parcial / aceptado` · `✅ cerrado` · `📅 post-escala`

**Solapes (no duplicar remediación):**

| Este doc | Ya documentado |
|----------|----------------|
| API-VAL-01/02 (pipe / bodies) | BN-PIPE-03, BN-DTO-03…19 |
| API-PAGE-01… (listas) | AQ-SCALE-07 |
| API-FMT envelope | Prompt 02 “pipes OK” |

---

## 1. Códigos HTTP (API-HTTP)

### Cómo se decide el status hoy

| Pieza | Rol |
|-------|-----|
| Nest default | GET/POST/PATCH → **200** salvo que el handler lance excepción |
| `HttpExceptionFilter` | Traduce `HttpException.getStatus()` → body `{ exito:false, error, mensaje }` |
| Remapeo de `error` | 401→`NO_AUTORIZADO`, 403→`PROHIBIDO` (salvo plan), 404→`NO_ENCONTRADO`, 400→`SOLICITUD_INVALIDA` salvo `CODIGOS_ERROR_PRESERVAR` |
| Desconocido | **500** + log |

Evidencia: `http-exception.filter.ts:60-125`, `respuesta.interceptor.ts:13-17`.

### Conteos de excepciones (throws aprox.)

| Tipo | HTTP | Uso |
|------|-----:|-----|
| `BadRequestException` | 400 | ~247 |
| `NotFoundException` | 404 | ~119 |
| `ForbiddenException` | 403 | ~52 |
| `UnauthorizedException` | 401 | ~20 |
| `ConflictException` | 409 | **4** (emails) |
| `HttpException` 429 | 429 | 1 (rate-limit) |
| `UnprocessableEntityException` | 422 | **0** |
| `@HttpCode(201)` | 201 | **0** |

### Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **API-HTTP-01** | ✅ | Media | Creates clave con 201 Created | `@HttpCode(CREATED)` pedidos/caja/usuarios/productos |
| **API-HTTP-02** | ✅ | Media | Conflictos de negocio como **409** | `CAJA_YA_ABIERTA`/`CAJA_YA_CERRADA`/`PEDIDO_CERRADO` → `ConflictException` |
| **API-HTTP-03** | 🟣 | Baja | **422** no usado — validación semántica y de schema se mezclan en 400 | 0× `UnprocessableEntityException` |
| **API-HTTP-04** | ✅ | Baja | Códigos negocio preservados (añadidos cerrada/pedido/sin_saldo) | `CODIGOS_ERROR_PRESERVAR` |
| **API-HTTP-05** | ✅ | — | 401/403/404 coherentes vía guards + filter | JWT / Rol / SuperAdmin |
| **API-HTTP-06** | ✅ | — | Rate-limit público → **429** | `rate-limit.guard.ts:58-63` |
| **API-HTTP-07** | 🟡 | Baja | Webhook Wompi: fallos “soft” → **200** + `{ procesado:false }` (intencional) | `pagos.service.ts:423-500`; firma inválida sí lanza 400 |
| **API-HTTP-08** | ✅ | — | No hay patrón HTTP 200 con `exito:false` en controllers (solo el filter emite `exito:false`) | Muestreo controllers |

**Matriz esperada vs real (casos críticos):**

| Caso | Ideal | Hoy |
|------|-------|-----|
| Crear pedido OK | 201 | 200 |
| Idempotencia pedido (misma clave) | 200 (mismo recurso) | 200 + `idempotente:true` ✅ |
| Caja ya abierta | 409 | 400 `CAJA_YA_ABIERTA` |
| Pedido ya pagado al cobrar | 409 | 400 `PEDIDO_CERRADO` |
| Email duplicado | 409 | 409 ✅ |
| Body inválido class-validator | 400 | 400 ✅ |
| UUID path basura | 400 | a menudo 404/500 vía PG |
| Sin JWT staff | 401 | 401 ✅ |
| Rol incorrecto | 403 | 403 ✅ |
| Error no controlado | 500 | 500 ✅ |

---

## 2. Validación de inputs (API-VAL)

### Pipe global

```ts
// main.ts:37-41
new ValidationPipe({ whitelist: true, transform: true })
// Falta: forbidNonWhitelisted, forbidUnknownValues
```

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **API-VAL-01** | ✅ | Media | `forbidNonWhitelisted: true` — campos extra → 400 (≡ BN-PIPE-03) | `main.ts` |
| **API-VAL-02** | 🟡 | Alta | ParseUUID en mayoría de `:id` UUID; residuales `sucursal_id` string en algunos listados | Controllers Nest |
| **API-VAL-03** | 🟣 | Alta | Bodies **inline** sin class-validator (≡ BN-DTO) | dispositivos públicos; vínculos productos; `motivo` pedidos; webhook `Record`; FCM auth |
| **API-VAL-04** | 🟡 | Media | `@MaxLength` / `@IsIn` presentes en DTOs clave pero **no universales** | ~60 DTO files; gaps en patches inline |
| **API-VAL-05** | ✅ | — | SQL injection: queries parametrizadas dominantes | `$1`/`SqlParams`; tablas dinámicas desde enum whitelist (inventario) |
| **API-VAL-06** | 🟡 | Baja | Sin límite global de tamaño body Nest (solo multer uploads ~20 MB) | `almacenamiento.service` `fileSizeLimit` |
| **API-VAL-07** | 🟣 | Media | Query `page`/`limit` como `string` + `Number(...)` sin DTO en pedidos controller | `pedidos.controller.ts` — `PaginacionQueryDto` **no importado** por ningún controller |
| **API-VAL-08** | ✅ | — | Rate-limit en rutas públicas sensibles (pedidos create, dispositivos, webhook) | decoradores `RateLimitPublico` |

**Rutas de mayor exposición a input malicioso:**

1. `POST /pedidos` (público) — DTO bueno + rate-limit; depende de `idempotency_key` opcional.
2. `POST /dispositivos/*` — públicos **sin** DTO (API-VAL-03).
3. `POST /pagos/webhook` — firma OK; body tipado débil.
4. Cualquier `PATCH/GET …/:id` con UUID inválido — falla tarde (API-VAL-02).

---

## 3. Paginación (API-PAGE)

### Infra existente

| Pieza | Capacidad |
|-------|-----------|
| `PaginacionQueryDto` | `page`/`limit` 1–100 con class-validator |
| `resolverPaginacion` | default 20, clamp 100 |
| `envolverPaginado` | `{ items, total, page, limit, totalPages }` |

**Uso real:** solo `pedidos.service` + `inventario.service` (movimientos). **Ningún controller** tipa query con `PaginacionQueryDto`.

### Inventario de listados

| ID | Estado | Endpoint / dominio | ¿Paginación? | Riesgo con muchos registros |
|----|--------|--------------------|--------------|------------------------------|
| **API-PAGE-01** | 🟣 | `GET /pedidos` staff | Opt-in (`page` query); sin `page` → **LIMIT 100** fijo, **sin** `total` | Medio: kanban OK; histórico incompleto sin meta |
| **API-PAGE-02** | 🟣 | `GET …/caja/…/movimientos` | **Ninguna** — SELECT completo | **Alto** en turno largo (≡ FL-55 Flutter) |
| **API-PAGE-03** | ✅ | `GET /usuarios` | Opt-in `page` + tope 200 | Medio (staff por restaurante) |
| **API-PAGE-04** | ✅ | Catálogo (productos + toppings/bebidas/combos) | Productos page opt-in; extras LIMIT 200 | Medio–alto menús grandes |
| **API-PAGE-05** | ✅ | Inventario ingredientes | Opt-in page + tope 200 | Medio |
| **API-PAGE-06** | 🟡 | Inventario movimientos | Opt-in page; default LIMIT 50 | Aceptable si se fuerza meta siempre |
| **API-PAGE-07** | 🟡 | Auditoría timeline | Hard **LIMIT 500** × 4 fuentes, sin offset cliente | Medio: trunca sin avisar bien |
| **API-PAGE-08** | 🟡 | Alertas / super-admin / impresión / analítica rankings | Soft caps (100 / 200–500 / 20–50 / top-N) | Bajo–medio |
| **API-PAGE-09** | ✅ | Analítica `pedidos-recientes` | Clamp limite 1–50 | OK |

**Veredicto:** la paginación **existe como utilidad** pero **no es contrato de API** en la mayoría de listas. Con muchos registros se rompe o se trunca en silencio (caja movimientos, catálogo, usuarios). Relacionado: AQ-SCALE-07.

---

## 4. Idempotencia (API-IDEM)

| ID | Estado | Sev | Operación | Mecanismo hoy | Gap |
|----|--------|-----|-----------|---------------|-----|
| **API-IDEM-01** | ✅ | — | Crear pedido | Body `idempotency_key` → tabla `pedidos_idempotencia` + `pg_advisory_xact_lock` | No hay header `Idempotency-Key` (solo body) — OK si Flutter lo envía |
| **API-IDEM-02** | 🟣 | Alta | Cobrar pedido / mesa | `FOR UPDATE` + rechazo si ya `pagado` | **Sin** clave cliente; retry de red puede confundir UX (409 sería más claro); doble click mitigado por lock |
| **API-IDEM-03** | 🟣 | Alta | Abrir caja | Check-then-insert sin unique parcial DB en servicio | TOCTOU bajo concurrencia → dos cajas abiertas posibles si no hay constraint SQL |
| **API-IDEM-04** | 🟡 | Media | Cerrar caja / gastos / retiro | `FOR UPDATE` / exigir caja abierta | Sin idempotency key; retries pueden duplicar gasto |
| **API-IDEM-05** | ✅ | — | Webhook Wompi APPROVED | Lookup `transaccion_wompi_id` + estado aprobado → `motivo: 'idempotente'` | Soft; endurecer `UPDATE … AND estado='pendiente'` (BN-EXC solape) |
| **API-IDEM-06** | 🟣 | Media | Checkout plan / sync pago | Soft checks | Sin Idempotency-Key HTTP en checkout |

Evidencia clave:

- Pedidos: `crear-pedido.dto.ts` (`idempotency_key`); `pedidos-crear.service.ts:57-80`, `:110-146`, `:960-964`.
- Cobro: `pedidos-pagos.service.ts:308-320`.
- Caja abrir: `caja.service.ts:58-77`.
- Wompi: `pagos.service.ts:454-462`.

**Header `Idempotency-Key`:** 0 matches en el backend.

---

## 5. Formato de respuesta (API-FMT)

### Contrato canónico

**Éxito** (interceptor):

```json
{ "exito": true, "datos": <return del handler>, "mensaje": "Operación exitosa" }
```

**Error** (filter):

```json
{ "exito": false, "error": "<CODIGO>", "mensaje": "<texto>" }
```

Opcional: `detalles`, `limite`, `actual` (plan).

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **API-FMT-01** | ✅ | — | Envelope éxito/error unificado en la mayoría de rutas | interceptor + filter globales |
| **API-FMT-02** | 🟣 | Media | `mensaje` de éxito **fijo** — handlers no pueden devolver mensaje de negocio útil sin bypass | `respuesta.interceptor.ts:16` |
| **API-FMT-03** | 🟣 | Media | Throws mezclan `message` (Nest/EN) vs `mensaje` (ES) vs `{ error, message }` anidado | Filter intenta ambos (`:78-108`); frágil |
| **API-FMT-04** | 🟣 | Baja | class-validator: check `Array.isArray(mensaje)` **muerto** (después de asignar string) | `http-exception.filter.ts:91-95` |
| **API-FMT-05** | 🟡 | Baja | Bypass envelope: HTML retorno Wompi + CSV analítica | `pagos.controller` `@Res()`; `analitica.controller` export |
| **API-FMT-06** | 🟣 | Media | Códigos de negocio aplanados a `SOLICITUD_INVALIDA` en muchos 400 (Flutter pierde discriminante) | Filter `:120-125` + lista preserve incompleta |

**Consistencia entre módulos:** alta en el shape (`exito`/`datos`/`error`/`mensaje`); baja en semántica de `error` (muchos códigos reales se pierden) y en HTTP status (casi todo conflicto = 400).

---

## 6. Backlog remediación (API-FIX)

Orden ponytail (máximo impacto / mínimo diff). **No implementar en esta pasada** — solo registro.

| ID | Prioridad | Acción | Cierra / reduce | Prod-risk |
|----|-----------|--------|-----------------|-----------|
| **API-FIX-01** | P1 | Paginación **default-on** + meta en pedidos, caja movimientos, usuarios, inventario listados; reusar `PaginacionQueryDto` | API-PAGE-01…06, AQ-SCALE-07 | Sí (OOM/latencia listas) |
| **API-FIX-02** | P1 | `ConflictException` (409) para `CAJA_YA_*`, `PEDIDO_CERRADO`; ampliar `CODIGOS_ERROR_PRESERVAR` | API-HTTP-02/04, API-FMT-06 | No (contrato) |
| **API-FIX-03** | P1 | Idempotency key (body o header) en cobro + unique parcial “una caja abierta por sucursal” | API-IDEM-02/03 | Sí (doble cobro / doble caja) |
| **API-FIX-04** | P2 | ~~`forbidNonWhitelisted`~~ ✅ BN-FIX-06; ParseUUIDPipe residual en params sueltos | API-VAL-01/02 | Bajo |
| **API-FIX-05** | P2 | DTOs en bodies inline públicos/staff (≡ BN-FIX-02/03) | API-VAL-03 | Medio (abuso dispositivos) |
| **API-FIX-06** | P3 | `@HttpCode(201)` en creates; opcional 422 para reglas semánticas vs 400 schema | API-HTTP-01/03 | No |

**Después:** mensaje éxito configurable; arreglar array class-validator en filter; endurecer `UPDATE` Wompi con `estado='pendiente'`.

---

## 7. Matriz de conteo

| Grupo | 🟣 | 🟡 | ✅ | 📅 |
|-------|---:|---:|---:|---:|
| API-HTTP | 4 | 2 | 2 | 0 |
| API-VAL | 5 | 2 | 1 | 0 |
| API-PAGE | 5 | 3 | 1 | 0 |
| API-IDEM | 3 | 1 | 2 | 0 |
| API-FMT | 4 | 1 | 1 | 0 |
| **Total hallazgos** | **21** | **9** | **7** | **0** |
| API-FIX backlog | 6 abiertos | | | |

---

## 8. Cómo verificar al remediar

| Fix | Evidencia mínima |
|-----|------------------|
| API-FIX-01 paginación | Curl lista caja/pedidos sin `page` → meta + limit; con `page=2` → offset; script smoke |
| API-FIX-02 409 | Abrir caja dos veces → 409 + `CAJA_YA_ABIERTA`; cobrar pedido pagado → 409 |
| API-FIX-03 idem cobro | Dos POST cobro misma key → un movimiento caja; unique caja abierta bajo 2 concurrentes |
| API-FIX-04 UUID/pipe | `GET …/pedidos/not-a-uuid` → 400; body con campo extra → 400 si forbid |
| API-FIX-05 DTOs | Dispositivo body basura → 400 class-validator |
| API-FIX-06 201 | `POST /pedidos` happy → 201 |

Scripts útiles: `scripts/verificar-ci.ps1`, curls en `docs/CI_E2E.md`, `estres-api-foody.ps1` para listas.

---

## Changelog de este documento

| Fecha | Cambio |
|-------|--------|
| 2026-08-06 | Enlace a Prompt 05 (`AUDITORIA_AUTH_JWT.md`) |
| 2026-08-05 | **Creación** Prompt 04 — API-HTTP/VAL/PAGE/IDEM/FMT + API-FIX-01…06; enlazado MASTER / AVANCE / README |

---

*Fin — Auditoría APIs REST (Prompt 04).*
