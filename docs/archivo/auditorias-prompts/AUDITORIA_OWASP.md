# Auditoría — Seguridad OWASP (Prompt 25)

> **Fecha:** 2026-08-06  
> **Alcance:** Injection (SQL/NoSQL) · Broken Access Control (ofensivo / Prompt 06) · secretos · rate limiting · revalidación RLS.  
> **Método:** lectura estática Nest + live Postgres RLS + `verificar-rls.ps1` + `verificar-idor-scope.ps1` + `verificar-owasp.ps1`.  
> Relacionados: [`AUDITORIA_RBAC.md`](AUDITORIA_RBAC.md) · [`AUDITORIA_BD_SUPABASE.md`](AUDITORIA_BD_SUPABASE.md) · [`AUDITORIA_DOCKER_ENV.md`](AUDITORIA_DOCKER_ENV.md) (DK-SEC) · [`AUDITORIA_AUTH_JWT.md`](AUDITORIA_AUTH_JWT.md).

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta OWASP | Respuesta |
|----------------|-----------|
| ¿Injection en raw SQL? | **No explotable hallado.** Nest usa `pg` + `$1…$N`. Los `${suc}` de analítica son **placeholders** (`SqlParams.add` → `$1`), no valores. Sin Mongo/NoSQL de negocio. |
| ¿Broken Access Control? | **Sí, hallazgos Prompt 06 vigentes** + **nuevo** finanzas (`ver_finanzas` escribe). Spoof `sucursal_id` de otro resto → 403 (script IDOR OK). |
| ¿Secretos expuestos? | Fallback JWT hardcodeado + `.env.example` débil (DK-SEC). `config/foody-entorno.env` **añadido a `.gitignore`** esta sesión. Anon key Flutter en archivo gitignoreado. Logs sin tokens. |
| ¿Rate limit sensibles? | Decoradores en login / pedidos públicos / dispositivos — **solo activos en production** (`esProduccion()`). Sin OTP. Gaps: geografía, menú, ciudades. |
| ¿RLS intacto? | **74/74** tablas `public` con ENABLE+FORCE · **0** sin RLS · **0** policies (deny-all). Creció 73→74 con `empleados` (080). Script RLS OK. |

**Veredicto:** ~**55 / 100** postura OWASP para go-live. SQL/RLS fuertes; **BAC + secretos JWT** bloquean producción masiva.

> **Nota «137 alertas RLS»:** no hay registro de “137” en docs del repo (Prompt 07 documentó **73/73**). Revalidación viva = **74/74** cubiertas. Si el número venía de Security Advisor de Supabase u otra herramienta, el estado local actual es: **ninguna tabla public sin RLS+FORCE**.

---

## A) Injection (SEC-INJ)

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **SEC-INJ-01** | ✅ | — | Analítica `${suc}`/`${d}` = `$N` vía `SqlParams` | `analitica-filtros.util.ts:61-67` |
| **SEC-INJ-02** | ✅ | — | Login / create pedido / inventarios whitelist tabla | auth · pedidos-crear · inventario |
| **SEC-INJ-03** | ✅ | — | Sin ORDER BY / LIMIT dinámico desde cliente | — |
| **SEC-INJ-04** | ✅ | — | Sin Mongo/NoSQL app; Flutter no escribe tablas críticas por client | — |
| **SEC-INJ-05** | 🟡 | Baja | `ESTADOS_POST_COCINA` embebidos como literales SQL (const, no user input) | `analitica.service.ts:1360` |

---

## B) Broken Access Control — foco ofensivo (SEC-BAC)

Reconfirmado en código 2026-08-06 (≡ RBAC-\* abiertos). Spoof sede ajena: **bloqueado** (`verificar-idor-scope.ps1` OK).

| ID | Estado | Sev | Ataque | Evidencia |
|----|--------|-----|--------|-----------|
| **SEC-BAC-01** | ✅ | — | `POST /caja/cerrar` valida la sucursal real de la caja antes de escrituras; QA cross-tenant: admin de A intenta caja B → 403 y caja B permanece abierta | `CajaService.cerrar()` + clon QA 2026-11-24; ver `AUDITORIA_RBAC.md` y `AVANCE_PROYECTO.md` |
| **SEC-BAC-02** | ✅ | — | Ambas rutas de cobro exigen `cobrar_pedido`; mesero sin ese permiso recibe 403 | `pedidos.controller.ts` + guard specs; ver `AUDITORIA_RBAC.md` |
| **SEC-BAC-03** | ✅ | Alta | Anonimizar exige posesión FCM/sesión (F3) | `dispositivos.controller.ts` · `verificar-f3-confianza` |
| **SEC-BAC-04** | ✅ | Alta | `prueba-web` `@Permisos('ver_dashboard')` + tokens propios | `notificaciones.controller.ts` |
| **SEC-BAC-05** | ✅ | — | `procesar-cola` solo admite JWT activo con `SuperAdminGuard`; ya no es una ruta de staff con `ver_dashboard` | `notificaciones.controller.ts` + guard metadata spec; ver `AUDITORIA_RBAC.md` |
| **SEC-BAC-06** | 🟣 | Media | **NUEVO** `/finanzas/*` mutaciones solo `@Permisos('ver_finanzas')` | `finanzas.controller.ts` · migr. 080 |
| **SEC-BAC-07** | ✅ | — | Scope `sucursal_id` otro restaurante → 403 en reportes/auditoría/caja config | `verificar-idor-scope.ps1` |
| **SEC-BAC-08** | ✅ | — | `/super/*` + SuperAdminGuard | — |

---

## C) Secretos (SEC-SECRET)

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **SEC-SECRET-01** | 🟣 | Alta | Fallback `foody_jwt_secret_cambiar` si falta env | `jwt.strategy.ts:17` · `auth.module.ts:30` ≡ **DK-SEC-02** |
| **SEC-SECRET-02** | 🟣 | Alta | `.env.example` JWT «cambiar_en_produccion» **pasa** validador (solo rechaza string exacto corto) | ≡ **DK-SEC-03** |
| **SEC-SECRET-03** | ✅ | — | `config/foody-entorno.env` ahora en `.gitignore` (antes riesgo commit) | `.gitignore` 2026-08-06 |
| **SEC-SECRET-04** | 🟡 | Baja | Anon key Flutter en `configuracion.dart` (gitignoreado; bundle web la lleva — esperado para anon) | — |
| **SEC-SECRET-05** | ✅ | — | Sin log de Authorization/password/token en `src` (grep) | — |
| **SEC-SECRET-06** | ✅ | — | `foody_backend/.env` gitignored; Wompi/service key vía ConfigService | — |

---

## D) Rate limiting (SEC-RLIMIT)

| Endpoint / área | ¿Decorator? | ¿Activo en dev? |
|-----------------|-------------|-----------------|
| `POST /auth/login*` / registro / Google | Sí (5–20/min) | **No** (NO-OP) |
| `POST /pedidos` (+ públicos pedidos) | Sí | **No** |
| Dispositivos registrar/vincular/anonimizar | Sí | **No** |
| OTP | N/A (no existe) | — |
| `GET /geografia/buscar` | **No** | — |
| `GET /menu/*` | **No** | — |
| `GET /ciudades*` | **No** | — |

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **SEC-RLIMIT-01** | 🟡 | Baja | Guard NO-OP fuera prod (CI); `RATE_LIMIT_FORZAR=1` para QA |
| **SEC-RLIMIT-02** | ✅ | — | Login + create pedido tienen `@RateLimitPublico` (prod) |
| **SEC-RLIMIT-03** | ✅ | — | Menú / ciudades / geografía con `@RateLimitPublico` |
| **SEC-RLIMIT-04** | 🟡 | Media | El contador Postgres compartido sí existe; un `catch` capturaba también el 429 y degradaba al mapa local. Fix fuente 2026-11-23 + 3 specs y build OK; falta activación/verificación en el Nest vivo. Ante error DB el fallback sigue fail-open por diseño actual (decidir fail-open/fail-closed). ≡ AQ-SCALE-05 / RL-GLOBAL-01 |

---

## E) RLS — revalidación viva

| Métrica (2026-08-06) | Valor |
|----------------------|------:|
| Tablas `public` | **74** |
| Con RLS ENABLE | **74** |
| Con FORCE | **74** |
| Sin RLS / sin FORCE | **0** |
| `CREATE POLICY` en public | **0** (deny-all) |
| `verificar-rls.ps1` | **exit 0** |

Módulo nuevo `empleados` (080): `REVOKE` + ENABLE + FORCE en la misma migración — **no reabrió** huecos.

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **SEC-RLS-01** | ✅ | — | 74/74 RLS+FORCE; spot-check pedidos + pagos_pedido |
| **SEC-RLS-02** | 🟡 | Media | Sin policies tenant (aislamiento = Nest) ≡ **BD-RLS-02** |
| **SEC-RLS-03** | ✅ | — | Tabla nueva finanzas cubierta; no regresión vs 073/064 |

---

## F) Backlog (SEC-FIX)

| ID | Prio/estado | Acción | Cierra |
|----|------------|--------|--------|
| **SEC-FIX-01** | P0 · ✅ | `CajaService.cerrar` valida scope por la sucursal leída de la caja; prueba cross-tenant QA 403 y sin mutación (2026-11-24) | SEC-BAC-01 |
| **SEC-FIX-02** | P0 · ✅ | Las dos rutas de cobro exigen `cobrar_pedido`; guard specs bloquean mesero y permiten cajero | SEC-BAC-02 |
| **SEC-FIX-03** | P0 | Anonimizar: posesión device / HMAC | SEC-BAC-03 |
| **SEC-FIX-04** | P1 | `prueba-web` → super_admin + no-prod | SEC-BAC-04 |
| **SEC-FIX-05** | P1 | JWT: fallar boot si secret default/débil | SEC-SECRET-01/02 |
| **SEC-FIX-06** | P1 | Rate limit geografía/menú; considerar activar en staging | SEC-RLIMIT-03 |
| **SEC-FIX-07** | P2 | Finanzas: permisos write dedicados | SEC-BAC-06 |
| **SEC-FIX-08** | P2 · 🟡 | La prueba cross-tenant ya se ejecutó en clon QA; falta incorporarla a `verificar-idor-scope` como caso reproducible | SEC-BAC-01 |

---

## Verificación (esta sesión)

```text
.\scripts\verificar-rls.ps1 → OK (74 tablas RLS+FORCE)
.\scripts\verificar-idor-scope.ps1 → OK (spoof sede → 403)
.\scripts\verificar-owasp.ps1 → exit 0 (avisos BAC/JWT/RLIMIT esperados)
.gitignore: + config/foody-entorno.env
API /salud → exito:true
```

**Gaps:** no se ejecutó IDOR real de cerrar-caja cross-tenant (hallazgo estático confirmado); rate limit no medido en `NODE_ENV=production`.
