# INFORME MAESTRO FOODY — hallazgos, severidad y plan de corrección

> **Prompt 35 · Bloque H cierre**  
> **Fecha:** 2026-08-06  
> **Rol:** reemplazo operativo de un equipo QA externo — una sola fuente para priorizar arreglos.  
> **Entrada:** Prompts 01–34 (`archivo/auditorias-prompts/`; cola = este doc) + [`MASTER_STATUS.md`](MASTER_STATUS.md).  
> **Cómo usar:** (1) leer veredicto · (2) plan ordenado §5 · (3) fichas crítico/alto §4 · (4) inventario completo §2–3 · (5) escala/viral §6 **no es código de hoy**.

> **Detalle forense:** [`archivo/auditorias-prompts/README.md`](archivo/auditorias-prompts/README.md) — no lectura diaria.

---

## 1. Veredicto ejecutivo

Foody es un **POS multi-restaurante usable en demo/piloto** (~74/100 arquitectura). La columna pedido → stock → cocina → caja **funciona** en happy path.

**No está listo para go-live masivo** sin cerrar:

1. **Seguridad tenant** (cerrar caja ajena).  
2. **Bugs de salón/caja** (prepago bloquea cierre; pedido `listo` con ítems pendientes; N/D cocina traba pedido).  
3. **UI desfasada** tras Wi‑Fi/API (sin refetch).  
4. **P0 ops:** impresión térmica real, VPS HTTPS, Wompi prod.  
5. **Escala/viral** (Prompts 31–32): decisiones de infra/costo — §6.

| Severidad (este informe) | Criterio | # abiertos aprox. |
|--------------------------|----------|-------------------|
| **Crítico** | Rompe operación real o seguridad multi-tenant | **6** |
| **Alto** | Degrada fuerte salón/caja/cocina o riesgo dinero/datos | **~28** |
| **Medio** | Deuda / UX / consistencia / DX | **~80+** |
| **Bajo** | Cosmético, doc, naming | **~40+** |

*Conteos = hallazgos 🟣 vigentes + P0 ops; excluye ✅ ya cerrados y 🚫 pospuestos (DIAN).*

---

## 2. Inventario consolidado por severidad

### 2.1 Crítico — rompe operación real o seguridad

| ID | Módulo | Una línea | Origen |
|----|--------|-----------|--------|
| ~~**RBAC-TENANT-01** / **SEC-BAC-01**~~ | Caja / Auth | ✅ **Cerrado F0** — `cerrar` scopea `caja.sucursal_id` | P06/P25 |
| ~~**PED-PREPAGO-01**~~ | Pedidos + Caja | ✅ **Cerrado F0** — cobrado completo no bloquea cierre; cocina→`pagado` | P11/P29 |
| ~~**VIE-01**~~ | Pedidos / Salón | ✅ **Cerrado F0** — add en `listo`/`pagando` → `en_cocina` | P30 |
| ~~**COC-NODISP-01**~~ | Cocina | ✅ **Cerrado F0** — `no_disponible` cuenta resuelto → pedido `listo` | P12/P29 |
| **P0-01 / R5** | Impresión | Sin QA impresora térmica real — go-live salón incompleto | Roadmap |
| **P0-05/06/07** | Infra / Pagos | Sin VPS HTTPS + Wompi prod → SaaS no cobra planes | Roadmap |

### 2.2 Alto — impacto fuerte en operación o riesgo

| ID | Módulo | Una línea |
|----|--------|-----------|
| **RT-RECON-01** / **INFRA-EXT-SYNC-01** / **VIE-12** | Realtime / Flutter | ✅ F1 refetch al reconectar/resume |
| **INFRA-EXT-TO-01** | Red / Caja | ✅ F1 post-timeout GET + idempotency cobro |
| **API-IDEM-02** | Pedidos | ✅ F1 `idempotency_key` + `cobros_idempotencia` |
| **API-IDEM-03** | Caja | ✅ F1 `uq_caja_abierta_sucursal` |
| **RBAC-MESERO-01/02** | RBAC | ✅ F2 `cobrar_pedido` (mesero 403) |
| **RBAC-MESERO-03** | RBAC | ✅ F2 mesero solo `pagando`/`cancelado` |
| **CONS-STOCK-CASCADE-01** | Inventario / Menú | ✅ F2 cascade hermanos |
| **RBAC-GUARD-01/02** | RBAC | ✅ F3 posesión anonimizar + `prueba-web` con permiso |
| **CFG-GLOBAL-DEAD** / **HUER-CFG-02** | Config | ✅ F3 runtime lee `configuracion_global_foody` |
| **AUTH-STORE-01** | Auth | ✅ F4 JWT en `flutter_secure_storage` (+ migración prefs) |
| **AUTH-FLOW-01/02** | Auth | Sin refresh / logout server-side |
| **AQ-SOLID-06/07** / **FL-WIDGET-06** | Flutter | ✅ F4 `POST /pedidos/estimar` + checkout; sheets UI-only |
| **API-PAGE-02** / **BD-IDX-01** | Caja / BD | ✅ F6 índices + paginación movimientos |
| **API-VAL-02** / **BN-DTO-03** | API | Sin ParseUUIDPipe; bodies públicos flojos |
| **RT-SEC-01** | Realtime | ~~Canales no privados + QR~~ ✅ HMAC 2026-08-08 |
| **HUER-PERM-01** | Finanzas UI | ✅ F3 tab Rentabilidad gated `ver_finanzas` |
| **VIE-05/13** | Caja / Cocina | ✅ Decisión **C** — abono libre; `pagado` solo cocina completa o admin+motivo |
| **AQ-DUP-01** | Inventario | ✅ `StockMovimientoService` (+ producción costeo) |
| **AQ-CYCLE-01** | Nest | ✅ F7 — hooks dispatch; deps one-way |
| **DK-SEC-03** / **DK-LOG-01** | Docker | JWT débil pasa validador; logs sin rotación |
| **INF-TUN-01** / **INF-DISK-01** / **BD-BKP-01** | Infra | Tunnel/VPS/disco/backups no endurecidos |
| **PERF-LOAD** / **CAP-LOAD-01** | Perf | 200 conc → p50 7–10 s (techo lab) |
| **DASH-TZ-01** | Dashboard | ✅ F6 `(created_at AT TIME ZONE 'America/Bogota')` |
| **BN-EXC-01** | Pagos | Fallos Wompi fuente/renovación tragados |

### 2.3 Medio (resumen por tema)

| Tema | IDs representativos |
|------|---------------------|
| Flutter leaks/nav/god screens | FL-LEAK-02, FL-NAV-01, FL-WIDGET-01, FL-STATE-01 |
| Realtime poll/lifecycle | RT-POLL-01, RT-FALL-01, RT-LIFE-01, RT-LEAK-01 ✅ F7 |
| Consistencia módulos | CONS-NODISP-STOCK, CONS-KDS-UI, CONS-PROMO-ADD, CONS-REP-OPEN |
| Huérfanos UI/API | HUER-API-COC-*, HUER-HALF-01 (DIAN UI), HUER-API-COST-* |
| Caja/domicilio borde | CAJ-DOM-IMPAGO, DOM-CANCEL-INDEP, QR-MESA-ID |
| Config/dashboard | CFG-PATCH-SUCURSAL, DASH-RT-*, DASH-ORPH-02 |
| Fuzz/OWASP | FUZZ-500 UUID hot paths ✅ F7; otros controllers parcial; SEC-RLIMIT prod-only |
| E2E/DX | E2E-GAP-UI, E2E-CI-01, INFRA-EXT-UI-01/02, INFRA-EXT-DOWN-* |
| Perf Flutter | PERF-FL-LIST (caja unbounded), PERF-FL-MEM |

### 2.4 Bajo / aceptado / pospuesto

Naming `reserva_canchas`, scripts RT-SCRIPT, FSM ítem cocina, evidencia foto domi, DIAN/MATIAS (**FE-*** 🚫), R10 carrera stock QR (aceptado), Firebase legacy ruido.

---

## 3. Agrupación por módulo afectado

| Módulo | Crítico | Alto (ejemplos) | Doc detalle |
|--------|---------|-----------------|-------------|
| **Caja** | RBAC-TENANT-01, PED-PREPAGO, API-IDEM-03 | API-PAGE-02, INFRA-EXT-TO (ops) | `AUDITORIA_CAJA`, RBAC, INFRA_EXTREMOS |
| **Pedidos** | VIE-01, PED-PREPAGO, API-IDEM-02 | AQ-SOLID-06, VIE-05/13 ✅ C | `AUDITORIA_PEDIDOS_*`, CASOS_VIERNES |
| **Cocina/KDS** | COC-NODISP-01 | COC-UI-PRIO ✅ F7; CONS-KDS-UI | `AUDITORIA_COCINA_KDS` |
| **Inventario/Menú** | CONS-STOCK-CASCADE ✅ · AQ-DUP-01 ✅ | — | `AUDITORIA_INVENTARIO`, CONSISTENCIA |
| **Auth/RBAC** | RBAC-TENANT, MESERO cobro/estado ✅ | MESERO-04 assign, AUTH-STORE, AUTH-FLOW | `AUDITORIA_RBAC`, AUTH_JWT |
| **Realtime/Flutter** | — | RT-RECON, INFRA-EXT-SYNC, FL-* | `AUDITORIA_REALTIME`, INFRA_EXTREMOS |
| **Config/Super** | — | CFG-GLOBAL-DEAD | `AUDITORIA_CONFIGURACION` |
| **Impresión** | P0-01/R5 | BN-EXC-18 encolado | `IMPRESION_RESTAURANTE` |
| **Infra/Deploy** | P0-05…07 | DK-*, INF-*, BD-BKP | DOCKER_ENV, INFRA, PREPROD |
| **Reportes/Dash** | — | DASH-TZ, CONS-REP-OPEN | REPORTES, DASHBOARD |
| **Escala/Viral** | — | *(§6 — no código hoy)* | CAPACITY, VIRAL_SPIKE |

---

## 4. Fichas crítico y alto (archivo, causa, solución, esfuerzo)

> Esfuerzo = horas-dev **una persona** que conoce el repo. Incluye test script + doc.  
> Código sugerido = dirección mínima (ponytail), no PR completo.

---

### C-01 · RBAC-TENANT-01 — IDOR cerrar caja

| | |
|--|--|
| **Sev** | Crítico |
| **Estado** | ✅ **Cerrado F0 (2026-08-06)** — `CajaService.cerrar` → `resolverEscritura(usuario, caja.sucursal_id)` |
| **Archivo** | `foody_backend/src/modulos/caja/caja.service.ts` · `caja.controller.ts` |
| **Test** | `verificar-idor-scope.ps1` — cerrar caja sede Norte con gerente Centro → 403 |

---

### C-02 · PED-PREPAGO-01 — Prepago bloquea cierre

| | |
|--|--|
| **Sev** | Crítico (ops viernes: no cierra caja) |
| **Estado** | ✅ **Cerrado F0 (2026-08-06)** — Opción A: `SQL_WHERE_PEDIDO_OPERACION_ABIERTA` excluye `monto_pagado >= total`; cocina listo+cobrado → `pagado` |
| **Archivo** | `pedido-estados.ts` · `cocinas.service.ts` |
| **Test** | Jest `casos-limite-28-30` PED-PREPAGO → `pagado` tras KDS |

---

### C-03 · VIE-01 — Add en `listo` no baja estado

| | |
|--|--|
| **Sev** | Crítico ops (sirven/cobran pensando listo) |
| **Estado** | ✅ **Cerrado F0 (2026-08-06)** — `agregarItems` demota `listo`/`pagando` → `en_cocina` |
| **Archivo** | `pedidos-items.service.ts` · `pedido-estados.ts` (TRANSICIONES) |
| **Test** | Jest `casos-limite-28-30` VIE-01 → `en_cocina` |

---

### C-04 · COC-NODISP-01 — N/D traba pedido

| | |
|--|--|
| **Sev** | Crítico ops |
| **Estado** | ✅ **Cerrado F0 (2026-08-06)** — `no_disponible` cuenta resuelto; pendientes=0 → `listo` (+ prepago → `pagado`) |
| **Archivo** | `cocinas.service.ts` `cambiarEstadoItem` |
| **Decisión** | N/D cierra ticket a nivel ítem; pedido avanza si el resto está listo/N/D |
| **Test** | Jest `cocina.e2e` COC-NODISP → `listo` |

---

### C-05 · P0-01 / R5 — Impresión térmica — 🟡 Waiver piloto

| | |
|--|--|
| **Sev** | Crítico go-live salón |
| **Estado código** | ✅ cola Nest + job `error` si encola falla (BN-EXC-18); modo archivo OK |
| **Falta humano** | QA térmica `:9100`/USB **diferida** — waiver modo archivo founder 2026-08-08 |
| **Check** | `verificar-impresion.ps1` · `CHECKLIST_F5_GOLIVE.md` |

---

### C-06 · P0-05/06/07 — VPS + Wompi — ✅ Piloto / 🟡 VPS diferido

| | |
|--|--|
| **Sev** | Crítico SaaS |
| **Estado código** | ✅ firma webhook; env preflight; fallo fuente → `auditoria_logs` (BN-EXC-01/02) |
| **Humano** | ✅ webhook + pago sandbox → plan activo (2026-08-08) · ✅ piloto PC+túnel · ⏳ VPS real diferido |
| **Docs** | `PREPARACION_VPS.md`, `WOMPI_PRODUCCION.md`, `CHECKLIST_F5_GOLIVE.md` |

---

### A-01 · RT-RECON / INFRA-EXT-SYNC / VIE-12 — UI desfasada — ✅ F1

| | |
|--|--|
| **Sev** | Alto |
| **Estado** | ✅ `onReconectado` + `AppLifecycleState.resumed` en KDS, kanban, caja, grid mesas, sheet mesa |
| **Archivo** | `lib/core/realtime/foody_realtime.dart` · pantallas ops |

---

### A-02 · INFRA-EXT-TO-01 + API-IDEM-02 — Timeout cobro — ✅ F1

| | |
|--|--|
| **Sev** | Alto |
| **Estado** | ✅ Busy `_cobrando`; `idempotency_key` + tabla `cobros_idempotencia`; post-timeout GET detalle/saldo |
| **Archivo** | `pedidos-pagos.service.ts` · mesa sheet · kanban · mig `081` |

---

### A-03 · API-IDEM-03 — Doble caja abierta — ✅ F1

| | |
|--|--|
| **Sev** | Alto |
| **Estado** | ✅ Unique parcial `uq_caja_abierta_sucursal`; insert+catch `23505` → `CAJA_YA_ABIERTA` |
| **Archivo** | `caja.service.ts` · mig `081_f1_caja_cobro_idempotencia.sql` |

---

### A-04 · RBAC-MESERO-01 — Mesero cobra — ✅ F2

| | |
|--|--|
| **Sev** | Alto (política) |
| **Estado** | ✅ `@Permisos('cobrar_pedido')` · mig `082` (admin/gerente/cajero) · UI mesero sin cobro |
| **Archivo** | `pedidos.controller.ts` · `082_f2_permiso_cobrar_pedido.sql` |

---

### A-05 · CONS-STOCK-CASCADE-01 — Hermanos siguen on — ✅ F2

| | |
|--|--|
| **Sev** | Alto ops (venden plato sin insumo) |
| **Estado** | ✅ `sincronizarPorIngredienteEnTransaccion` tras descontar/restaurar |
| **Archivo** | `pedidos-inventario.service.ts` |

---

### A-06 · CFG-GLOBAL-DEAD — Config super muerta — ✅ F3

| | |
|--|--|
| **Sev** | Alto (confianza ops Foody) |
| **Estado** | ✅ `ConfiguracionGlobalModule` carga BD → umbrales/dispatch; `actualizarConfiguracion` → `recargar()` |
| **Archivo** | `configuracion-global.module.ts` · `alertas-riesgo.service.ts` · dispatch |

---

### A-07 · AUTH-STORE-01 — JWT en SharedPreferences — ✅ F4

| | |
|--|--|
| **Sev** | Alto (móvil rooted / XSS web) |
| **Estado** | ✅ JWT en `FlutterSecureStorage`; meta sesión en prefs; migración one-shot; web residual XSS documentado |
| **Archivo** | `lib/core/sesion/sesion_staff_service.dart` |

---

### A-08 · AQ-SOLID-06 — Totales en Flutter — ✅ F4

| | |
|--|--|
| **Sev** | Alto (regla Foody + riesgo desfase) |
| **Estado** | ✅ `POST /pedidos/estimar` (mismo pricing que crear); checkout usa total servidor; sheets/badge = hint UI-only |
| **Archivo** | `pedidos-crear.service.ts` · `pedidos-public.controller.ts` · `checkout_screen.dart` |

---

### A-09 · RBAC-GUARD / anonimizar / FCM prueba — ✅ F3

| | |
|--|--|
| **Sev** | Alto |
| **Estado** | ✅ anonimizar exige posesión (`fcm_token` / auth); no muta `plataforma` inválida; `prueba-web` → `@Permisos('ver_dashboard')` + tokens propios |
| **Archivo** | `dispositivos.{controller,service}.ts` · `notificaciones.controller.ts` |

---

### A-10 · Índices caja + paginación movimientos — ✅ F6

| | |
|--|--|
| **Sev** | Alto (turno largo / reportes) |
| **Estado** | ✅ mig `083` índices; `GET …/movimientos?page&limit` + Flutter loop páginas |
| **Archivo** | `083_f6_indices_caja.sql` · `caja.service.ts` · `caja_repository.dart` |

---

### A-11 · AUTH-FLOW refresh

| | |
|--|--|
| **Sev** | Alto (sesión corta mid-turno) |
| **Esfuerzo** | **8–16 h** |

---

### A-12 · DASH-TZ-01 — Zona horaria Bogotá — ✅ F6

| | |
|--|--|
| **Sev** | Alto (KPIs noche) |
| **Estado** | ✅ resumen + por-tipo usan `(created_at AT TIME ZONE 'America/Bogota')::date` |
| **Archivo** | `dashboard.service.ts` |

---

## 5. Plan de corrección ordenado (impacto restaurante)

Orden = **qué duele primero un viernes noche / cierre de caja / seguridad tenant**, no “diff más fácil”.

| Fase | Qué | IDs | Horas | Por qué primero |
|------|-----|-----|------:|-----------------|
| **F0 — Parar sangre** | ✅ Cerrado 2026-08-06 — IDOR caja; prepago; VIE-01; COC-NODISP | C-01…C-04 | **0** | Dinero mal cerrado / salón mentiroso / seguridad |
| **F1 — Turno estable** | ✅ Cerrado 2026-08-06 — RT refetch; busy cobro; timeout→GET; idempotency cobro; unique caja | A-01, A-02, A-03, UI-01/02 | **0** | Wi‑Fi basura + doble tap + timeout |
| **F2 — Política & stock** | ✅ Cerrado 2026-08-06 — `cobrar_pedido`; cascade menú; mesero ≠ listo | A-04, A-05, RBAC-MESERO-03 | **0** | No vender sin insumo; quién cobra |
| **F3 — Confianza Foody** | ✅ Cerrado 2026-08-06 — CFG runtime; HUER-PERM; anonimizar/FCM | A-06, HUER-PERM, A-09 | **0** | Super no miente; finanzas no 403 sorpresa |
| **F4 — Sesión & totales** | ✅ Cerrado 2026-08-06 — secure storage JWT; `POST /pedidos/estimar` | A-07, A-08 | **0** | Cumplir “Flutter solo UI” |
| **F5 — Go-live P0** | ✅ Piloto 2026-08-08 — waiver archivo + Wompi sandbox E2E + PC+túnel; diferidos térmica papel / VPS | C-05, C-06 | **0** piloto / ops compra | Sin esto no hay piloto de pago |
| **F6 — Perf turno** | ✅ Cerrado 2026-08-06 — índices caja; paginar movs; DASH-TZ | A-10, A-12 | **0** | Cierre/reporte no se cuelga |
| **F7 — Deuda media** | 🟡 Parcial 2026-08-06 — UUID/RT/KDS/CYCLE/AQ-DUP-01 ✅; resto medias §2.3 | medias §2.3 | **resto ~12–30** | Calidad / escala suave |
| **F8 — Infra escala** | §6 CAP/VIRAL | — | **plan $$** | No es sprint de bugfix |

**Suma F0–F4 (piloto serio local):** ~**60–100 h**.  
**+ F5 go-live comercial:** ~**+24–56 h** ops.  
**F8:** presupuesto cloud, no “un PR”.

### Decisiones de producto bloqueantes (antes de código)

| ID | Pregunta | Si no decides |
|----|----------|---------------|
| **VIE-05/13** | ✅ Decisión **C** — abono libre; `pagado` cocina completa o admin+motivo | `verificar-vie-politica.ps1` |
| **VIE-09** / **COC-NODISP** | ✅ Fallo prep + merma; N/D resuelve ticket (COC-NODISP) | `verificar-vie-politica.ps1` |
| **RBAC-MESERO** | ¿Mesero cobra en tu modelo comercial? | A-04 |

---

## 6. Escala y viralización (Prompts 31–32) — NO es arreglo de código hoy

> Estos ítems **no se “cierran” con un fix Nest**. Son **capacidad, dinero y arquitectura de despliegue**. Planificar en roadmap infra; ejecutar cuando haya tráfico o presupuesto.

### 6.1 Capacity (Prompt 31) — CAP-\*

| Hallazgo | Implicación | Decisión de negocio |
|----------|-------------|-------------------|
| Nest **1 proceso**, pool **25**, PG **100** conn | Techo lab ~8–20 RPS | ¿Cuántos restaurantes concurrentes el primer año? |
| **CAP-LOAD** p50 7–10 s @ 200 | Dashboard/menú caen primero | SLA aceptable en hora pico |
| Cache menú max **200** | Thrash multi-tenant | Redis sí/no y cuándo ($) |
| Tablas crecen sin purge | Disco + queries lentas | Retención notif/auditoría (ops) |
| Sin PM2/PgBouncer | 500+ sedes no viable | Fecha objetivo 100 vs 1k sedes |

**Orden de inversión (doc CAP):** índices/SQL → pool VPS → purge → Redis → PM2 → réplica lectura → partición.

### 6.2 Viral spike (Prompt 32) — VIRAL-\*

| Hallazgo | Implicación | Decisión |
|----------|-------------|----------|
| Registro **síncrono** + bcrypt cost 10 | 5k altas/día saturan pool/CPU | Waitlist / cupo diario **antes** de campaña |
| Sin cola onboarding | Spike tumba tenants existentes | Separar pool registro vs ops |
| OTP/MATIAS/FCM bienvenida **no existen** | Marketing no debe prometerlos | Scope producto vs ads |
| Meta OTP tier 250 | Si se añade OTP WhatsApp, Día 1 falla | Contrato Meta + cola |

**Orden (doc VIRAL):** flag/cupo → cola pendientes → defer horarios → RL global → bcrypt worker → runbook → (OTP después).

### 6.3 Checklist ejecutivo (fundador)

- [ ] Meta: ¿piloto 10 / 100 / 1000 restaurantes en 12 meses?  
- [ ] Presupuesto mensual: VPS + Redis + PgBouncer + monitoring.  
- [ ] Política: ¿cerramos registro con waitlist si CPU/pool > X%?  
- [ ] Fecha: no lanzar ads masivos hasta F0+F1+F5 mínimos.  
- [ ] Owner infra vs owner producto (quién aprueba $$).

---

## 7. Mapa rápido → documentos fuente

Índice de auditorías: [`archivo/auditorias-prompts/README.md`](archivo/auditorias-prompts/README.md)

| Qué | Dónde |
|-----|-------|
| Estado vivo | `MASTER_STATUS.md` |
| Cola F0–F8 | este documento |
| Roadmap P0 | `ROADMAP_TERMINAR_FOODY.md` |
| Prompts 01–34 (forense) | `archivo/auditorias-prompts/` |
| Escala / viral | §6 de este doc + CAP/VIRAL en archivo |

---

## 8. Criterio de “piloto listo” (definición mínima)

Un restaurante piloto **puede operar un viernes** si:

1. ~~F0 cerrado~~ ✅ (IDOR, prepago/cierre, VIE-01, NODISP).  
2. ~~F1 cerrado~~ ✅ (RT refetch ops + busy/idempotency cobro + unique caja).  
3. ~~F2 cerrado~~ ✅ (`cobrar_pedido`; cascade stock; mesero estados).  
4. ~~F3 cerrado~~ ✅ (CFG global viva; Rentabilidad gated; anonimizar/FCM).  
5. ~~F4 cerrado~~ ✅ (JWT secure storage; checkout vía `/pedidos/estimar`).  
6. Impresión validada en **su** impresora (F5 parcial) **o** aceptación explícita modo archivo.  
7. Backup + health monitor mínimos (BD-BKP / MONITOR).  
8. **No** se requiere Redis/PM2/viral waitlist para ≤20 sedes (CAP).

---

## 9. Changelog de este informe

| Fecha | Nota |
|-------|------|
| 2026-08-08 | **RT-SEC / Bloque B ✅** — topics staff HMAC; `verificar-rt-sec.ps1`; P0-09 cerrado piloto |
| 2026-08-08 | **F5 piloto ✅** — waiver archivo; webhook+pago sandbox Wompi → plan activo; PC+túnel; C-05/C-06 criterio piloto cerrado; VPS/térmica diferidos |
| 2026-08-06 | **F6 cerrado** — mig `083` índices caja; movimientos paginados; DASH-TZ Bogota; check `verificar-f6-perf.ps1` |
| 2026-08-06 | **F5 parcial** — BN-EXC fuente→auditoría + job impresión error; `verificar-f5-golive.ps1`; checklist humano `CHECKLIST_F5_GOLIVE.md` (C-05/C-06 no ✅) |
| 2026-08-06 | **F4 cerrado** — `flutter_secure_storage` JWT; `POST /pedidos/estimar`; checkout server total; check `verificar-f4-sesion.ps1` |
| 2026-08-06 | **F3 cerrado** — CFG global runtime; tab Rentabilidad `ver_finanzas`; anonimizar posesión + fix plataforma; `prueba-web` permiso; check `verificar-f3-confianza.ps1` |
| 2026-08-06 | **F2 cerrado** — `cobrar_pedido` (mesero 403); cascade stock hermanos; mesero ≠ listo; check `verificar-f2-politica.ps1` |
| 2026-08-06 | **F1 cerrado** — RT-RECON/VIE-12 refetch; INFRA-EXT-UI busy; timeout→GET; API-IDEM-02/03 + mig `081`; check `verificar-f1-turno.ps1` |
| 2026-08-06 | **F0 cerrado** — RBAC-TENANT-01, PED-PREPAGO-01, VIE-01, COC-NODISP-01 (Nest + Jest + `verificar-idor-scope.ps1`) |
| 2026-08-06 | Prompt 35 — primera consolidación 01–34; plan F0–F8; §6 CAP/VIRAL separado |

**Mantenedor:** actualizar este archivo al cerrar cada fase F0–F5 (marcar IDs ✅ y bajar horas restantes). El detalle forense sigue viviendo en `AUDITORIA_*.md`; este informe es la **cola de trabajo**.
