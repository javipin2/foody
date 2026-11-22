# Foody — E2E automatizado (Prompt 33 · Bloque H)

> **Fecha:** 2026-08-06  
> **Alcance:** Jest/Supertest (Nest) + Flutter `integration_test` / `test/e2e` para **mesa, QR, domicilio, cocina, caja**, más casos límite de Prompts **28–30**.  
> **Estado oficial:** [`MASTER_STATUS.md`](MASTER_STATUS.md) § E2E automatizado.

Leyenda: 🟣 abierto · 🟡 aceptado · ✅ OK / corregido

---

## Veredicto

Hay suite **reproducible** contra API viva (`:3000` + seed demo):

| Capa | Comando | Resultado esta sesión |
|------|---------|------------------------|
| Nest Jest | `npm run test:e2e` / `scripts/verificar-e2e-jest.ps1` | ✅ **7 suites / 14 tests** |
| Flutter VM | `flutter test test/e2e/flujos_criticos_api_test.dart` / `verificar-e2e-flutter.ps1` | ✅ **5/5** |
| Flutter dispositivo | `verificar-e2e-flutter.ps1 -EnDispositivo` | 🟡 build Windows exige NuGet (gap DX) |

Los scripts PowerShell históricos (`verificar-pagos-mesa`, `verificar-flujo-domicilio`, …) **siguen** siendo la suite ops amplia; Jest/Flutter cubren el núcleo + regressiones VIE/CONS nombradas.

---

## Archivos

| Path | Rol |
|------|-----|
| `foody_backend/test/helpers/foody-e2e.ts` | Login, cleanup, mesa libre, helpers |
| `foody_backend/test/flujos/mesa.e2e-spec.ts` | Mesa + bloqueo entregado sin cobro |
| `foody_backend/test/flujos/qr.e2e-spec.ts` | Menú QR + pendiente_aprobacion + anti-tamper |
| `foody_backend/test/flujos/domicilio.e2e-spec.ts` | Bloqueo listo→entregado + flujo entrega |
| `foody_backend/test/flujos/cocina.e2e-spec.ts` | KDS tickets + **COC-NODISP-01** |
| `foody_backend/test/flujos/caja.e2e-spec.ts` | Cobro + **VIE-06** no reopen |
| `foody_backend/test/flujos/casos-limite-28-30.e2e-spec.ts` | **VIE-01**, VIE-05/13, **PED-PREPAGO-01** |
| `foody_backend/test/app.e2e-spec.ts` | Smoke `/salud` (reemplaza Hello World) |
| `test/e2e/flujos_criticos_api_test.dart` | Contratos Flutter (VM) |
| `integration_test/flujos_criticos_e2e_test.dart` | Wrapper `IntegrationTestWidgetsFlutterBinding` |
| `scripts/verificar-e2e-jest.ps1` | Orquestador Jest |
| `scripts/verificar-e2e-flutter.ps1` | Orquestador Flutter |

---

## Cobertura de casos límite (28–30)

| ID origen | En test | Qué afirma |
|-----------|---------|------------|
| **VIE-01** | Jest + Flutter | Add ítems con pedido `listo` → estado **sigue** `listo` (bug documentado) |
| **VIE-05 / VIE-13** | Jest + `verificar-vie-politica.ps1` | Decisión **C**: abono OK; `pagado` bloqueado sin cocina; admin+motivo OK |
| **VIE-06** | Jest caja | No reabrir `pagado` → `en_cocina` |
| **PED-PREPAGO-01** | Jest | `para_llevar` + efectivo → `en_cocina` + monto; cobrar falla |
| **COC-NODISP-01** | Jest cocina | `no_disponible` en un ítem → pedido **no** llega a `listo` |
| **VIE-02** | Jest (parcial) | Pedido abierto conserva líneas (sin mutar catálogo en suite) |
| HUER-\* (28) | — | No E2E (huérfanos UI/API; no flujo runtime) |
| CONS-STOCK-\* | — | Cubierto por scripts inventario; no duplicado aquí |

**Al corregir un BUG:** cambiar la aserción (p. ej. VIE-01 → `en_cocina`) y marcar el ID ✅ en MASTER.

---

## Hallazgos Prompt 33

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **E2E-SUITE-01** | — | Suite Jest 5 flujos + límites límite + Flutter contratos | ✅ |
| **E2E-STUB-01** | Baja | `app.e2e-spec.ts` era stub Nest «Hello World» (no Foody) | ✅ reemplazado por `/salud` |
| **E2E-VIE-01-COV** | Alta | VIE-01 ahora tiene regresión automatizada (afirma bug actual) | ✅ |
| **E2E-GAP-UI-01** | Media | Sin click-through de pantallas Flutter (solo contrato HTTP) | 🟣 |
| **E2E-FL-DEVICE-01** | Baja | `integration_test -d windows` intenta build nativo + NuGet; CI local usa VM | 🟡 aceptado |
| **E2E-LIVE-01** | Info | Tests asumen API **viva** (no boot Nest in-process) — alineado a scripts QA | 🟡 aceptado |
| **E2E-CI-01** | Media | GitHub Actions aún no corre Jest E2E (mismo bloqueo seed BD que P3-01) | 🟣 |

---

## Cómo correr

```powershell
# Pre: Docker Supabase + API Nest en :3000
.\scripts\verificar-e2e-jest.ps1
.\scripts\verificar-e2e-flutter.ps1
```

Pre-requisitos demo: `admin@foody.demo` / `cajero.test@foody.demo` / `cocina@foody.demo` / `domi@foody.demo` · pass `123456`.

---

## Relación con suite PowerShell

| Ya existía | Prompt 33 añade |
|------------|-----------------|
| `verificar-todos-e2e.ps1`, `verificar-flujo-cruzado-api.ps1` | Jest portable + asserts tipados |
| `verificar-kds`, `verificar-pedidos-ciclo-vida`, … | IDs VIE/CONS explícitos en specs |
| Sin `integration_test` | Flutter VM + wrapper dispositivo |

No reemplazar los `.ps1` ops: son más anchos (impresora, CxC, multi-sucursal). Jest/Flutter = **núcleo + regressiones de auditoría**.
