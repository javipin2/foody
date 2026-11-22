# Foody — CI y pruebas E2E API

> **Roadmap:** P3-01 · **Regla agente:** `.cursor/rules/foody-verificar-antes-entregar.mdc`

## Scripts

| Script | Uso | Duracion aprox. |
|--------|-----|-----------------|
| `scripts/verificar-ci.ps1` | **Entrada recomendada** — modo rapido (default) o `-Completo` | 1–15 min |
| `scripts/verificar-todos-e2e.ps1` | Suite completa (= `verificar-ci.ps1 -Completo`) | 10–15 min |
| `scripts/verificar-paso0.ps1` | Smoke: salud, logins, rutas clave, migr. 064 RLS | ~1 min |
| `scripts/verificar-rls.ps1` | RLS exhaustivo Postgres (migr. 064) | ~10 s |
| `scripts/verificar-docker-prod.ps1` | Build imagen `docker-compose.prod.yml` | ~2 min |
| `scripts/verificar-salud.ps1` | BD + Realtime + cola impresion (`/health`) | ~15 s |
| `scripts/verificar-p2-pulido.ps1` | Copiar menu, traslado cancelar, super config | ~30 s |
| `scripts/verificar-qa-manual.ps1` | CI rapido + guia QA UI (`CHECKLIST_QA_ROLES.md`); `-FlujoApi` incluye flujo cruzado | ~1–3 min |
| `scripts/verificar-flujo-cruzado-api.ps1` | Checklist §4 automatizado (cliente, domi, mesas, caja, fiado…) | ~2 min |
| `scripts/verificar-e2e-jest.ps1` | **Prompt 33** — Jest/Supertest 5 flujos + VIE/CONS | ~10 s |
| `scripts/verificar-e2e-flutter.ps1` | **Prompt 33** — Flutter contratos API (VM; `-EnDispositivo` opcional) | ~30 s |
| `scripts/reparar-impresora-demo.ps1` | Impresora demo modo archivo (sin IP red) | ~5 s |
| `scripts/verificar-auth-flow.ps1` | AUTH-FLOW: refresh / logout / `token_version` | ~15 s |
| `scripts/verificar-bn-pipe-forbid.ps1` | BN-FIX-06: props/query extra → 400 | ~20 s |
| `scripts/verificar-bn-dto-query.ps1` | BN-FIX-04: query promo/geografía + IsBoolean pedido | ~20 s |
| `scripts/verificar-bn-dto-fcm.ps1` | BN-DTO-01/02: bodies FCM | ~15 s |
| `scripts/verificar-bn-ctrl-usuarios.ps1` | BN-CTRL-02: crear staff + gerente_cadena | ~20 s |
| `scripts/verificar-bn-residuales.ps1` | BN-DTO-28/33 · MOD-03 salud/completo · UUID pipe | ~20 s |
| `scripts/verificar-bn-dto-query-rest.ps1` | BN-DTO-24…27: pedidos/costeo/upload/retorno | ~25 s |
| `scripts/verificar-bn-dto-auditoria.ps1` | BN-DTO-23: timeline fechas/UUID/forbid | ~15 s |
| `scripts/verificar-bn-dto-inline.ps1` | BN-FIX-03: mutaciones con DTO | ~30 s |
| `scripts/verificar-bn-almacenamiento.ps1` | BN-FIX-01: upload catálogo | ~30 s |

**Lote remediación Nest/Auth (2026-08-07):** evidencia + **detalles a pulir** → [`REMEDIACION_NEST_AUTH_2026-08-07.md`](REMEDIACION_NEST_AUTH_2026-08-07.md).  
**2026-08-08:** `verificar-ci.ps1 -Completo` incluye `verificar-bn-*` + `verificar-rt-sec.ps1` (modo rápido sin cambio).

### Modo rapido (antes de commit / PR)

```powershell
.\scripts\verificar-ci.ps1
```

Ejecuta: `verificar-paso0` + `verificar-rls` + `verificar-salud` + `verificar-p2-pulido` + `verificar-multi-sucursal`.

Ver `docs/MONITOREO_SALUD.md` para endpoints de produccion.

### Modo completo (pre-release / piloto)

```powershell
.\scripts\verificar-ci.ps1 -Completo
```

Limpia demo QA y corre los 9 scripts E2E (mesas, domicilio, inventario, impresion, analitica, CxC, P2…).

## Pre-requisitos

1. Docker Desktop + Supabase local (`supabase-db` verde)
2. Backend: `scripts\iniciar-backend-wsl.bat` (Node Windows, `dist` actualizado)
3. `GET http://localhost:3000/api/v1/salud` → `exito: true`

## GitHub Actions

Workflow: `.github/workflows/ci.yml`

| Job | Cuando | Que hace |
|-----|--------|----------|
| `backend-build` | push / PR | `npm ci` + `nest build` |
| `flutter-analyze` | push / PR | `flutter analyze lib/` |
| `e2e-api` | **manual** (`workflow_dispatch`, input `run_e2e=true`) | Documentado; requiere runner con stack Foody |

E2E contra BD seeded no corre en GitHub hosted sin Postgres+64 migraciones; usar **runner self-hosted** en el VPS/PC de desarrollo o ejecutar scripts localmente antes de desplegar.

## Criterio P3-01 cerrado

- [x] Suite extendida (`verificar-todos-e2e.ps1` + 4 scripts nuevos)
- [x] Orquestador `verificar-ci.ps1` (rapido / completo)
- [x] Workflow CI build + analyze
- [x] **Prompt 33:** Jest E2E 5 flujos + Flutter contratos (`verificar-e2e-jest.ps1` / `verificar-e2e-flutter.ps1`) — ver `AUDITORIA_E2E_AUTOMATIZADO.md`
- [ ] E2E automatico en cada PR (bloqueado: seed BD en runner — P3-06 VPS / **E2E-CI-01**)
