# Auditoría — Fuzz testing de inputs (Prompt 27)

> **Fecha:** 2026-08-06  
> **Alcance:** inputs inválidos, extremadamente largos, caracteres especiales, tipos incorrectos en endpoints representativos (auth, menú, pedidos, staff lecturas/mutaciones).  
> **Criterio de éxito:** el servicio **no cae**; la respuesta al cliente **no expone stack trace** (paths, `node_modules`, `QueryFailedError`, campo `stack`).  
> **Check:** `scripts/verificar-fuzz-inputs.ps1` (curl + envelope `{exito,error,mensaje}`).  
> Relacionados: [`AUDITORIA_OWASP.md`](AUDITORIA_OWASP.md) · [`AUDITORIA_APIS_REST.md`](AUDITORIA_APIS_REST.md) (API-VAL) · `HttpExceptionFilter`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| ¿Algún input tumbó la API? | **No.** `/salud` post-fuzz OK + `base_datos: true` (45 casos). |
| ¿Stack trace al cliente? | **No** (`leaks=0`). 5xx devuelven `{"exito":false,"error":"ERROR_INTERNO","mensaje":"Ocurrió un error inesperado"}` (79 bytes). Stack solo en logs Nest. |
| ¿Validación temprana? | **Mayoría 400** en bodies (login, pedidos, caja, promos…). **Hueco:** UUID / path basura → **500 ERROR_INTERNO** (PG `invalid input syntax for type uuid`) en vez de 400. |
| ¿Payloads enormes? | Login/registro/notas largas → 400. **POST /mesas** con nombre 5k → **201** en sesión previa (sin `MaxLength` aparente). |

**Veredicto:** filtro global cumple el objetivo de **no filtrar stack** y **no tumbar** el proceso bajo fuzz lab. Queda deuda de **validar UUID/params antes de SQL** (5xx evitables) y **límites de longitud** en creates (mesas).

---

## Matriz de corrida (sesión)

```text
casos=45  2xx=5  4xx=34  5xx=6  leaks=0  down=0
verificar-fuzz-inputs.ps1 → exit 0, avisos=6
```

| Grupo | Comportamiento dominante |
|-------|--------------------------|
| A Auth/public | 8/8 → **400** (vacío, tipos, XSS, no-JSON, 5k/20k email) |
| B Paths/query | path traversal 404; UUID/XSS menú → **500** envelope; geo SQL 400; ciudades 2k 200 |
| C Pedidos public | bodies 400; `mios` device junk 200; estado UUID bad → **500** |
| D Staff lecturas | `sucursal_id` inválido/SQL/XSS → **500**; dashboard 404; reportes fechas 400; usuarios `page=-1` 200 |
| E Mutaciones | casi todo 400; `DELETE anonimizar` device SQL → **200** (≡ SEC-BAC-03) |
| F Extremos | array root / nested / Bearer basura → 400/401 |
| G Salud | OK post-fuzz |

---

## Hallazgos

### Estabilidad y superficie de error

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **FUZZ-STABLE-01** | ✅ | — | API viva tras 45 payloads hostiles | `/salud` post-fuzz |
| **FUZZ-STACK-01** | ✅ | — | 0 matches stack (`node_modules`, `.ts:`, `QueryFailedError`, `"stack":`) en bodies | script `Test-StackLeak` |
| **FUZZ-ENVELOPE-01** | ✅ | — | 5xx usan `HttpExceptionFilter` → `ERROR_INTERNO` genérico (sin path de archivo) | curl `Content-Length: 80` |
| **FUZZ-500-UUID-01** | 🟣 | Media | UUID inválido en path/query (`not-a-uuid`, XSS path) → **500** en vez de 400: menú, pedidos estado, listados con `sucursal_id` | 6 avisos script · PG uuid cast |
| **FUZZ-VAL-01** | ✅ | — | ValidationPipe + DTO rechazan tipos wrong / JSON roto en login y creates críticos | grupo A/C/E |
| **FUZZ-LEN-01** | 🟣 | Media | `POST /mesas` aceptó **nombre 5k** (HTTP 201) en corrida previa; sin tope MaxLength observable | sesion 1 script; posible mesa huérfana demo |
| **FUZZ-PAGE-01** | 🟡 | Baja | `GET /usuarios?page=-1&limit=999999` → 200 (sin clamp duro) | grupo D |
| **FUZZ-ANON-01** | 🟡 | — | `DELETE /dispositivos/anonimizar/' DROP…` → 200 (público; ≡ SEC-BAC-03) | grupo E |

### Relación con filter

```192:192:foody_backend/src/compartido/filtros/http-exception.filter.ts
    response.status(status).json(cuerpoRespuesta);
```

- Excepciones no-HTTP → status 500, `ERROR_INTERNO`, mensaje genérico; `logger.error(..., stack)` **solo server-side**.
- No hay `stack` en el JSON de respuesta.

---

## Cobertura vs “cada endpoint”

No se fuzzearon los ~221 handlers uno a uno (ponytail). Matriz **representativa** por superficie de confianza:

| Superficie | Endpoints tocados |
|------------|-------------------|
| Público sin JWT | login, login-google, registro-restaurante, menú, ciudades, geo, mesa QR, pedidos public, anonimizar, salud |
| Staff JWT | pedidos, dashboard, reportes, inventario, usuarios, analítica, estado, caja, mesas, catálogo, promos, zonas, finanzas |
| Parser | no-JSON, text/plain, array root, nested objects, Bearer basura/SQL, email 20k |

Gap: super-admin, KDS, Wompi webhook, upload Storage, WebSocket impresión — mismos patrones de UUID/DTO esperados; re-correr script al añadir endpoints críticos.

---

## Backlog (FUZZ-FIX)

| ID | Prio | Acción | Cierra |
|----|------|--------|--------|
| **FUZZ-FIX-01** | P2 | `ParseUUIDPipe` (o regex) en params/query `sucursal_id` / `:id` antes del SQL → 400 `SOLICITUD_INVALIDA` | FUZZ-500-UUID-01 |
| **FUZZ-FIX-02** | P2 | `@MaxLength` / check DB en `nombre` mesa (y campos texto similares: promo código, concepto gasto) | FUZZ-LEN-01 |
| **FUZZ-FIX-03** | P3 | Clamp `page`/`limit` usuarios (y listados unbounded) | FUZZ-PAGE-01 |
| **FUZZ-FIX-04** | P1 | Auth en anonimizar (reusa SEC-FIX) | FUZZ-ANON-01 |

---

## Verificación (sesión)

```text
.\scripts\verificar-fuzz-inputs.ps1
→ exit 0, avisos=6 (solo 5xx UUID/XSS path sin stack)
JSON: scripts/_tmp_fuzz_inputs.json
```

**Gaps:** cleanup mesa 5k demo si quedó de run 1; fuzz no exhaustivo de todos los controllers; no body-parser DoS multi-MB (techo lab 20k).
