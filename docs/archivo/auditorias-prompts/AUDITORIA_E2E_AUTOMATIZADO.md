# Foody — E2E automatizado (Prompt 33 · Bloque H)

> **Fecha:** 2026-08-06  
> **Alcance:** Jest/Supertest (Nest) + Flutter `integration_test` / `test/e2e` para **mesa, QR, domicilio, cocina, caja**, más casos límite de Prompts **28–30**.  
> **Estado oficial:** [`MASTER_STATUS.md`](MASTER_STATUS.md) § E2E automatizado.

Leyenda: 🟣 abierto · 🟡 aceptado · ✅ OK / corregido

---

## Veredicto

Hay suite **reproducible** contra API QA viva (`:3001` + seed demo). Los E2E mutan y limpian fixtures; no deben apuntar al backend del piloto `:3000`.

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
| **PED-PREPAGO-01** | Jest | `para_llevar` + efectivo → saldo completo y estado inicial `en_cocina`; reintento de cobro falla SIN_SALDO; ahora intenta `caja/cerrar` usando saldo de sistema antes de marcar KDS; al resolver todos los ítems → `pagado`. La extensión compila con TypeScript, pero aún no se ejecutó en QA aislada. |
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
# Pre: PostgreSQL QA aislado + API Nest QA en :3001
.\scripts\verificar-e2e-jest.ps1
.\scripts\verificar-e2e-flutter.ps1 -PermitirEscrituras
```

Ambos orquestadores verifican salud en el mismo destino que utilizará la suite y bloquean hosts distintos de `localhost:3001` salvo `FOODY_E2E_ALLOW_NON_QA=1`. El Flutter E2E además exige `-PermitirEscrituras`. La API `:3000` del Tunnel no debe usarse para estas pruebas.

Pre-requisitos demo: `admin@foody.demo` / `cajero.test@foody.demo` / `cocina@foody.demo` / `domi@foody.demo` · pass `123456`.

---

## Relación con suite PowerShell

| Ya existía | Prompt 33 añade |
|------------|-----------------|
| `verificar-todos-e2e.ps1`, `verificar-flujo-cruzado-api.ps1` | Jest portable + asserts tipados |
| `verificar-kds`, `verificar-pedidos-ciclo-vida`, … | IDs VIE/CONS explícitos en specs |
| Sin `integration_test` | Flutter VM + wrapper dispositivo |

No reemplazar los `.ps1` ops: son más anchos (impresora, CxC, multi-sucursal). Jest/Flutter = **núcleo + regressiones de auditoría**.

### Ejecución QA integral — 2026-11-24

- El default de los runners y scripts de operación es API local QA `127.0.0.1:3001` y base PostgreSQL aislada `foody_diseno_qa` en `127.0.0.1:55494`; se probó que los guards rechazan `:3000` antes de hacer requests/escrituras.
- Nest unitario: 26 suites / 57 pruebas. Nest E2E: 8 suites / 22 pruebas; incluye `FIN-SPLIT-01` (abono, rechazo de split sobre saldo, Caja sin movimiento ante rechazo, split válido y cierre). Build Nest OK.
- `scripts/verificar-todos-e2e.ps1`: 9/9 scripts: cobro mesa, domicilio, inventario-menú, transferencia, impresión modo archivo, multi-sucursal, analítica, CxC y P2. La semilla QA recibió migración `062_demo_segunda_sede_qa.sql` y una cuenta Mesero QA para habilitar cobertura de scope; no son datos del negocio ni de `:3000`.
- El script P2 se hizo compatible con `HttpResponseMessage` de PowerShell moderno y ahora omite con aviso los casos que requieren segunda sede/config global cuando el seed no los contiene. La configuración global de esta semilla sigue vacía.
- La suite confirmó que Mesero no tiene permiso para leer zonas (403) y sí queda bloqueado en alertas/zonas de otra sede (403). La batería es QA funcional, no prueba de carga ni aceptación visual autenticada.
- Al final se limpió la QA; se detuvieron Nest `:3001` y el agente de impresión temporal. API principal `:3000` (PID 7564) siguió activa; Cloudflare/Tunnel, frontends, OAuth, credenciales y datos comerciales no se alteraron.

### Reejecución reproducible — 2026-11-24

- Jest E2E: **8 suites / 32 pruebas aprobadas** contra API `:3001` y PostgreSQL QA aislada. Los fixtures de QR y numeración ahora registran un dispositivo sintético y envían `X-Foody-Device-Capability`, requerido por la mitigación `CLIENT-DEVICE-CAP-01`; al terminar anonimiza únicamente sus dispositivos sintéticos y conserva filas de pedidos para auditoría.
- `scripts/verificar-e2e-jest.ps1` comprueba el destino QA y ejecuta la limpieza/seed de demostración solo cuando el host es `localhost:3001`. La primera ejecución reveló stock agotado por una batería anterior; el reset reproducible corrigió el fixture agotado sin tocar `:3000`.
- Suite operativa `scripts/verificar-todos-e2e.ps1`: **9/9** scripts (mesa, domicilio, inventario/menú, transferencia, impresión en modo archivo, multi-sucursal, analítica, CxC y P2).
- Verificación adicional `scripts/verificar-idor-scope.ps1`: **7/7** expectativas; gerente de Centro recibe 403 en reportes/auditoría/config de otra sede y al cerrar caja Norte; la caja continúa abierta. Administrador corporativo mantiene acceso permitido a datos de la otra sucursal del mismo restaurante. Este seed no contiene dos restaurantes distintos.
- Flutter: suite global **248 aprobadas / 5 omitidas / 0 fallidas**. `flutter analyze` global: **0 errores, 0 warnings y 33 infos** existentes; salida no-cero porque infos siguen contabilizadas por el analizador.
- No se probó una impresora física ni un dispositivo móvil real, no se ejecutó prueba de carga ni aceptación visual autenticada; el script P2 omitió configuraciones no presentes en el seed. Estas son brechas, no resultados implícitos.
- QA Nest `:3001` y el agente de impresión temporal `:8765` se detuvieron. Al cierre solo `:3000`, frontends `:8080/:8081` permanecían escuchando; Cloudflare Tunnel y rutas públicas no se modificaron.
