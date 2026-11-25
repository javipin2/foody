# Foody — Prioridades del sistema (lista viva)

> **Documento único para tachar avance.** Consolida `MASTER_STATUS`, `INFORME_MAESTRO` (F0–F8), `ROADMAP_TERMINAR_FOODY` (P0–P3), `CHECKLIST_F5_GOLIVE`, `REMEDIACION_NEST_AUTH_2026-08-07` y auditorías abiertas.
>
> **Regla:** trabajar **de arriba hacia abajo**. No saltar a “pulido Flutter” si P0/F5 está abierto y el objetivo es vender/operar.
>
> Al cerrar un ítem: `- [ ]` → `- [x]`, actualizar **Estado**, 1 línea en `AVANCE_PROYECTO.md` y el ID en `MASTER_STATUS.md`.

**Última actualización:** 2026-11-24 — piloto PC + Cloudflare Tunnel conservado; `MES-GROUP-ACCOUNT-01` y `MES-GROUP-FLATTEN-01` pasan E2E; Nest `:3000` actualizado y Tunnel responde. `FIN-FIXED-PARTIAL-BALANCE-01` está resuelto; nómina/ciclos permanece pendiente como `FIN-PAYROLL-PERIOD-01`, junto a `FIN-REC-OPEN-01` y `FIN-TIP-01`.
**Próximo foco recomendado:** continuar Pedidos → Cocina → Caja → Finanzas/Análisis y validar autenticación operativa; resolver política de enrolamiento legacy y recuperación de capability antes de producción. `CLIENT-DEVICE-CAP-01` tiene mitigación implementada; detalles y riesgos residuales en `AUDITORIA_CLIENTES_QR.md`.

### Decisiones founder (2026-08-08)

| Ítem | Decisión | Upgrade path (sin reescribir producto) |
|------|----------|----------------------------------------|
| **A1 impresión** | **Waiver piloto = modo archivo** (aún sin térmica) | Comprar térmica → IP en cocina + `FOODY_PRINTER_MODE=auto\|red` · `IMPRESION_RESTAURANTE.md` |
| **A2 Wompi** | Webhook + eventos + **pago sandbox → plan activo** ✅ (founder) | Prod = mismas URLs cuando Wompi apruebe cuenta |
| **A3 infra** | **Piloto = PC + Cloudflare Tunnel** (no VPS aún); mantener `MODO=tunel` para poder probar fuera de casa durante el desarrollo | Al terminar la app, revisar VPS/deploy y configurar según decisión; **dominios/Wompi/Uptime no cambian** · `MIGRACION_VPS_QUE_CAMBIA.md` |

---

## Cómo leer esta lista

| Campo | Significado |
|-------|-------------|
| **Por qué falta** | Motivo real (ops, decisión, deuda, dependencia) |
| **Depende de** | Qué debe existir antes (o en paralelo) |
| **Quién** | Código agente · Ops/founder · Decisión producto |
| `- [x]` | Hecho y verificado |
| `- [ ]` | Pendiente |
| `🟡` | Parcial (código sí / cierre humano no) |

---

## Mapa rápido (dónde estamos)

| Capa | Estado | Nota |
|------|--------|------|
| Salón / caja / pedidos (F0–F4, F6) | ✅ | Piloto local serio |
| Endurecimiento Nest/Auth (BN + AUTH-FLOW) | ✅ / 🟡 residuales | Ver Bloque C |
| Go-live (impresión · Wompi · VPS) | ✅ piloto / 🟡 compra | **Bloque A cerrado piloto** · térmica/VPS reales diferidos |
| Seguridad realtime canales | ✅ | **Bloque B1** topics HMAC staff · catálogo/pedido públicos |
| Flutter UX / god screens | 🟡 | Bloque D: STATE/WIDGET/AQ/DASH ✅ · huérfanos UI + más gods |
| Escala 100+ sedes (F8) | 📅 | Bloque E — $$ / arquitectura |
| Multi-negocio | 📅 | **No implementar** hasta post-P0 |

---

## BLOQUE A — Crítico: poder cobrar y operar en el mundo real (F5 / P0)

> Sin esto no hay piloto de pago ni restaurante “de verdad”. Impacto = dinero y reputación.

### A1. Impresión térmica (P0-01 / R5 / C-05)

- [x] Cola Nest + agente Python + modo archivo (`FOODY_PRINTER_MODE=archivo`)
- [x] Tickets al pasar a cocina + guía instalación
- [x] UI config impresora por cocina (falta poner IP real en sede)
- [x] Fallo encolado no tumba pedido (job `error` auditable) — BN-EXC-18
- [ ] **QA impresora térmica real** (:9100 o USB) — imprimir comanda y ver papel
  - **Por qué falta:** aún no hay hardware; piloto acepta archivo
  - **Depende de:** comprar térmica + IP en sede
  - **Quién:** Ops campo · Founder
  - **Estado:** diferido post-compra (no bloquea piloto)
- [x] Decisión founder: **waiver modo archivo** (2026-08-08) — stack listo para `auto`/`red` al comprar

Doc: `CHECKLIST_F5_GOLIVE.md` · `IMPRESION_RESTAURANTE.md`

### A2. Monetización Wompi producción (P0-06 / P0-07 / C-06)

- [x] Self-service planes + recurrente en **código** (fuentes_pago, cron, webhook handler)
- [x] Auditoría si falla registrar fuente (BN-EXC-01/02/03/04)
- [x] Registrar **webhook** Wompi en dashboard (`https://api.foodyy.store/api/v1/pagos/webhook-wompi`) — founder 2026-08-08 + llave eventos en `.env`
- [x] `WOMPI_REDIRECT_URL` HTTPS + secrets sandbox en `.env` (`verificar-wompi-tunel.ps1` OK)
- [x] Un pago sandbox OK documentado (checkout → webhook → plan activo sin sync manual) — founder 2026-08-08
  - **Quién:** Founder (confirmado en UI sandbox)
  - **Nota prod:** cuenta Wompi aún en revisión; mismas URLs al pasar a producción

Doc: `WOMPI_PRODUCCION.md` · `ACCIONES_HUMANAS_TUNEL.md`

### A3. VPS / HTTPS (P0-05)

- [ ] API NestJS en VPS + dominio HTTPS
  - **Por qué falta:** VPS aún no comprado; piloto deliberado en PC
  - **Depende de:** servidor Ubuntu + mover conector
  - **Quién:** Ops / Founder
  - **Estado:** diferido post-compra
- [ ] Aplicar migraciones (incl. RLS `064`) **en** la BD del VPS
  - **Depende de:** A3 deploy
- [ ] Backups automáticos (BD-BKP-01 / R2) activados
  - **Depende de:** A3 + `BACKUPS_FOODY.md`
- [x] Decisión documentada: **piloto = PC + Cloudflare Tunnel** (2026-08-08) — mismas URLs; día VPS = `MIGRACION_VPS_QUE_CAMBIA.md` (Wompi/DNS no se retocan)

Doc: `PREPARACION_VPS.md` · `MIGRACION_VPS_QUE_CAMBIA.md`

### Criterio Bloque A cerrado

- [x] Impresión real **o** waiver (waiver archivo 2026-08-08)
- [x] Webhook Wompi + 1 pago OK (sandbox E2E 2026-08-08)
- [x] VPS prod **o** decisión Fase 0 documentada (PC+túnel 2026-08-08)

> **Bloque A ✅ para piloto.** Quedan diferidos post-compra: QA térmica papel + deploy VPS real (upgrade paths ya escritos).

---

## BLOQUE B — Crítico de seguridad (antes de muchos clientes)

> Puede esperar un piloto controlado de 1 sede; **no** esperar a marketing masivo.

### B1. Realtime / tenant leak (P0-09 / RT-SEC-01)

- [x] Topics staff opacos HMAC (`sucursal_{id}_{firma16}`) + login/`GET /auth/realtime-canales`
  - **Hecho 2026-08-08:** Nest emite solo en topics firmados; Flutter staff usa `realtime_canales`; catálogo `*_catalogo` y `pedido_*_*` públicos
  - **Check:** `.\scripts\verificar-rt-sec.ps1` OK (anon no oye caja en topic plano)
  - **Nota:** re-login staff tras deploy; no es Realtime Authorization nativo (upgrade VPS documentado en `realtime-topics.ts`)
- [x] Criterio leak cerrado: QR + anon key **no** escucha caja/alertas

### B2. Secretos / JWT prod (DK-SEC / SEC-SECRET / AUTH TTL)

- [x] Auth refresh/logout/`token_version` (AUTH-FLOW)
- [x] Secure storage móvil + prefs web (F4 / AUTH-WEB)
- [x] Validador prod exige `JWT_EXPIRACION` corto (≤1d / Nh / Nm) + `JWT_SECRET` ≥32 chars
  - **Ops:** en VPS poner `JWT_EXPIRACION=1h` (o `2h`) con `ENTORNO=produccion`
- [x] JWT default de ejemplo no pasa validador prod (DK-SEC-03 endurecido)

### B3. Rate-limit / superficie pública

- [x] Rate-limit efectivo en prod (`RateLimitGuard` + `RateLimitPublico` en auth)
  - **QA local:** `RATE_LIMIT_FORZAR=1`
  - **Escala multi-instancia:** Postgres `rate_limit_entries` (F8 Redis si hace falta)
- [x] SEC-RLIMIT-03 — menú / ciudades / geografía con `@RateLimitPublico` (`verificar-sec-rlimit-kds.ps1`)
- [x] INFRA-EXT-UI-03 — lock UI por ítem KDS (`_itemsEnVuelo`)
- [ ] SEC-RLIMIT-01 — NO-OP fuera prod **aceptado** (CI); staging usa `RATE_LIMIT_FORZAR=1` 🟡
- [ ] DK-COMPOSE-04 — archivos en workspace; **commitear** cuando se pida 🟡

---

## BLOQUE C — Deuda Nest/API (calidad, no bloquea salón) ✅ cerrado 2026-08-11

> Mucho de BN/AUTH ya ✅. Consolidación HTTP + RBAC-MESERO-04 cerrados.

### C1. Ya cerrado (tachar histórico)

- [x] BN-FIX-01…06 (DTOs, pipe forbid, almacenamiento, billing logs)
- [x] BN-DTO-01/02/20–28/33 (FCM, queries, UUID hot paths)
- [x] BN-CTRL-02/03 (usuarios / traslados → service)
- [x] BN-EXC-03/04/18
- [x] AUTH-FLOW refresh/logout
- [x] BN-MOD-03 dual salud/health + `/salud/completo` (aceptado)
- [x] BN-PIPE-04 sin implicit conversion global (aceptado; usar `@Type`)

### C2. Pendiente Nest (prioridad relativa dentro del bloque)

- [x] **BN-MOD-05** — unificar SQL ventas (reportes ↔ analítica ↔ dashboard)
  - **Hecho 2026-08-11:** `compartido/sql/ventas-metricas.sql.ts` (filtros/fecha/caja/TZ); reportes+dashboard+analitica lo consumen. Check: `verificar-bn-mod-05.ps1`
- [x] **BN-CTRL-04/05/10–12** — gates/parse menores a services
  - **Hecho:** consolidado/comparativa corporativo; `resolverContexto` analitica; FCM prueba; HTML retorno-app; `crearStaff` pedidos. Check: `verificar-bn-ctrl-04.ps1`
- [x] **BN-CTRL-07** — default `subtotal` en DTO validar-código (sin `?? 0` en controller) — 2026-08-08
- [x] **API-HTTP** — creates 201 (pedidos/caja/usuarios/productos); conflictos 409 (caja/pedido cerrado); preservar `CAJA_YA_CERRADA`/`PEDIDO_CERRADO`/`SIN_SALDO`
  - Check: `verificar-api-http.ps1` (409 vivo + HttpCode static)
- [x] **API-PAGE** — tope/paginación usuarios/catálogo/insumos
  - **Hecho 2026-08-11:** sin `page` → array + LIMIT 200 (compat Flutter); con `page` → `{items,total,page,limit,totalPages}`. Toppings/bebidas/combos tope 200. Check: `verificar-api-page.ps1`
- [x] **PED-BYPASS-01** — `salio-sin-pagar` vía `PedidosEstadoCommandService` — 2026-08-08
  - Check: sección D de `verificar-pedidos-ciclo-vida.ps1` OK
- [x] **RBAC-MESERO-04** — mesero **no** asigna domiciliarios (solo `gestionar_domiciliarios`; UI kanban oculta slot)
  - **Hecho 2026-08-11:** decisión founder = mesero no asigna. Check: `verificar-rbac-mesero-04.ps1`
- [x] Residuales UUID: finanzas / domiciliarios-planta / super-admin — 2026-08-08
- [x] Scripts `verificar-bn-*` (+ `verificar-rt-sec`) en `verificar-ci.ps1 -Completo` — 2026-08-08

Doc cierre: `REMEDIACION_NEST_AUTH_2026-08-07.md`

---

## BLOQUE D — Flutter / UX / confianza de pantalla (F7 resto)

> App usable; falta pulido de rendimiento y arquitectura UI. **No** es P0 de dinero.

### D1. Estado y navegación

- [x] **FL-STATE-01/02** — epoch compartido pedidos/caja (`operacionSucursalProvider`); caja publica + invalida; mesas/kanban `ref.listen` recargan
  - **Hecho:** no MultiProvider; repos locales siguen; sync hermanos al abrir/cerrar caja
  - **Falta (menor):** stores Riverpod de datos (listas) — opcional; epoch basta para refresh cruzado
- [x] **FL-WIDGET-02** — `select`/watch fino del carrito (no rebuild menú entero)
  - **Hecho:** `menu_screen_foody` — `Consumer` + `carritoProvider.select` solo en barra inferior
- [x] **FL-NAV-01** — `go('/admin/cajero')` rompe back-stack
  - **Hecho:** `mesas_grid_widget` → `context.push('/admin/cajero')` (back-stack OK)

### D2. God screens / perf UI

- [x] **FL-WIDGET-01** — partir pantallas >1k LOC (primer corte)
  - **Hecho:** `AsignarDomiciliarioSlot` fuera de kanban (~`asignar_domiciliario_slot.dart`); kanban deja de embeber el widget
  - **Falta:** más cortes (mesas/costeo/…)
- [x] **PERF-FL-IMG** — `memCacheWidth/Height` en listas (menú cliente + thumbs admin + costeo/promo/sedes/restaurantes)
- [x] **PERF-FL-LIST** — caja movimientos acotados (max 80 + viewport 420); kanban grid = `ListView.builder` por filas (no Wrap eager)
- [x] **PERF-FL-MEM-01** — re-audit: features usan `liberarCanal` / `removeChannel` (sin `unsubscribe` suelto)

### D3. Huérfanos UI ↔ API

- [x] **HUER-HALF-01** — Facturación: menú/título **Facturas internas**; ocultar resolución DIAN; copy FE pausada
  - **Hecho:** DIAN pausada sin “Resolución DIAN” en HTML/PDF (fix en `FacturacionService`)
- [x] Conectar o deprecar: observaciones KDS, costeo combos UI, ganancias domi indep., márgenes sede write
  - **Hecho:** observaciones KDS + costeo combos UI + ganancias domi indep. + `márgenes sede write` (`HUER-CFG-01`) con `scripts/verificar-huer-cfg-01.ps1`
- [x] **AQ-SOLID-08** — food cost % / margen % desde API en paneles receta/incluidos (sin `precio−costo` / % locales en KPIs)
  - **Residual aceptado:** preview suma de líneas + margen de error al editar receta; `calcularPrecioSugeridoUi` hint de precio sugerido

### D4. Dashboard / copy

- [x] **UX-PAYWALL-BLUR** — módulo fuera de plan: esqueleto estático borroso (0 API) + card upgrade; búsqueda incluye sesiones bloqueadas
- [x] **DASH-RT / DASH-FRESH / DASH-ORPH** — Inicio: «Actualizado HH:mm» + poll 75s; Ventas→Reportes; KPI QR; top por cantidad; copy tendencia; banner RT aclara Inicio
  - **Hecho:** `dashboard_resumen_widget` + `dashboard.service` ORDER BY cantidad; check `verificar-dashboard-general.ps1`
  - **Residual baja:** DASH-CONS-COMP/PERIOD (completados vs financiero; reportes default 7d)

Doc: `docs/frontend/FRONTEND_ROADMAP.md`

---

## BLOQUE E — Escala / viral (F8) — no es sprint de bugfix

> Solo cuando haya tráfico, presupuesto o meta “100 sedes”.

- [x] Pool PG prod ≥25 documentado + `DB_POOL_MAX` (AQ-SCALE-01 / PERF-POOL)
- [x] Crons / rate-limit multi-réplica (ya no `Map`/`setInterval` solo proceso)
- [x] N+1 menú combos / clone (AQ-SCALE-03 / BD-N1 / PERF-N1)
- [x] Cache menú Redis o techo thrash (AQ-SCALE-04) — mejora: single-flight + TTL 15 min
- [x] SQL sargable dashboard/reportes (PERF-SQL-01/02/04)
- [x] Rotación logs Docker + disco (DK-LOG / INF-DISK) — docker json-file max-size/max-file en `docker-compose.prod.yml`
- [x] Purga crecimiento (CAP-GROW-01/02) — cron cola FCM + auditoría
- [ ] Tunnel como servicio en VPS (INF-TUN)
- [ ] Decisiones CAP/VIRAL (flag cupo, cola, bcrypt worker) — doc INFORME §6
- [ ] PM2 / PgBouncer / réplica lectura (CAP) — pendiente; evidencia local multi-instancia con `scripts/verificar-cap-local.ps1` (rate-limit compartido) ya hecha.

**Depende de:** Bloque A (VPS) en la práctica.

---

## BLOQUE F — Pospuesto / no hacer ahora

| Ítem | Por qué no ahora |
|------|------------------|
| Multi-negocio / verticales Treinta+ | Spec en `docs/multinegocio/` — **post-P0 restaurante** |
| WhatsApp OTP (AUTH-FIX-06) | Solo si producto lo pide |
| DIAN facturación electrónica | Pausada a propósito |
| Rename package `reserva_canchas` (P3-05) | Cosmético; rompe imports |
| Frontend “rediseño total” | Regla: evolucionar base, no UI desde cero |

---

## Orden de ejecución sugerido (arriba → abajo)

```text
1. A1 Impresión (o waiver)
2. A2 Wompi webhook + 1 pago
3. A3 VPS o decisión Fase 0 documentada
4. B1 Realtime privado (si vas a más de 1 cliente / internet)
5. B2 JWT TTL + secrets prod
6. ~~C2 Nest~~ ✅ (BN-MOD-05 · API-PAGE · RBAC-MESERO-04)
7. D1–D3 Flutter según fricción de usuarios piloto
8. E Escala solo con métrica de carga o $$
```

---

## Contador (actualizar a mano al tachar)

| Bloque | Hechos | Abiertos | Parciales |
|--------|-------:|---------:|----------:|
| A Go-live | ~6 código | ~6–8 humano | F5 🟡 |
| B Seguridad | AUTH-FLOW ✅ | RT-SEC, TTL, RL | — |
| C Nest | **Cerrado** ✅ | — | PIPE/MOD-03 🟡 acept. |
| D Flutter | HUER/PERF/STATE/WIDGET/AQ/DASH ✅ | huérfanos UI · más gods | DASH-CONS residual |
| E Escala | 0 | muchos | — |
| F Pospuesto | — | n/a | — |

---

## Fuentes (no duplicar detalle forense aquí)

| Doc | Rol |
|-----|-----|
| `MASTER_STATUS.md` | Estado oficial por ID |
| `INFORME_MAESTRO_FOODY.md` | Fases F0–F8 + fichas |
| `ROADMAP_TERMINAR_FOODY.md` | Checklist P0–P3 histórico |
| `CHECKLIST_F5_GOLIVE.md` | Acciones humanas F5 |
| `REMEDIACION_NEST_AUTH_2026-08-07.md` | Cierre BN/AUTH + a pulir |
| `archivo/auditorias-prompts/*` | Evidencia forense por prompt |

---

## Changelog de este documento

| Fecha | Cambio |
|-------|--------|
| 2026-08-20 | **Lote 🟡** — CAJ-TURNO, ANA-FILT-PROD/ESTADOS, COC-REIMP; check `verificar-lote-turno-ana-reimp.ps1` |
| 2026-08-19 | **Lote 🟡** — QR-MESA, promo, cancel domi, INV ajuste/aud, transfer/msgs, CHECK pedidos; check `verificar-lote-amarillo.ps1` |
| 2026-08-11 | **VIRAL antispike** — cupo/flag/max-min + UI waitlist + defer horarios; check `verificar-viral-registro.ps1` |
| 2026-08-11 | **SEC-RLIMIT + KDS lock** — menú/ciudades/geo RL; INFRA-EXT-UI-03; DK-COMPOSE 🟡; check `verificar-sec-rlimit-kds.ps1` |
| 2026-08-11 | **RT-POLL/FALL + CONS-NODISP** — poll adaptativo; menú/POS/panel/domi; off menú tras N/D; check `verificar-rt-fall-poll.ps1` |
| 2026-08-11 | **AQ-CYCLE/DUP + DASH** — tokens→core; pedidos staff→features/pedidos; KPI Cerrados hoy; check `verificar-aq-cycle-dup.ps1` |
| 2026-08-11 | **PERF-CACHE/SQL + API-VAL** — ciudades+dashboard TTL; top productos desde pedidos; ParseUUID residual; check `verificar-perf-cache-api-val.ps1` |
| 2026-08-11 | **CONC-INV + OFFLINE + SEC sync** — FOR UPDATE stock; banner API offline; splash no entra sin API; SEC-BAC F3 re-OK; check `verificar-conc-inv-infra-down.ps1` |
| 2026-08-11 | **CONS-COSTO + CFG-GLOBAL sync** — margen ledger al editar qty; fuentes_cogs en analítica; F3 confianza re-OK |
| 2026-08-11 | **CONS-REP/CUADRE + POLIGONO** — script cuadre = API; UI Tickets vs Cobrado; mig 088 depreca poligono; check `verificar-cuadre-caja.ps1` |
| 2026-08-11 | **CFG-NOMBRE-MARCA-07** — marca edita nombre/tel; check `verificar-cfg-nombre-marca.ps1`; CACHE-MARCA → 🟡 |
| 2026-08-11 | **CONS-PROMO-ADD + CFG-PATCH** — % promo se reaplica al add ítems; `PATCH /sucursales/:id` + UI Editar sede; check `verificar-cons-promo-cfg-patch.ps1` |
| 2026-08-11 | **Lote 🟣** — FUZZ-LEN · SEC-BAC-06 (`gestionar_finanzas` + mig 087) · RT-ENV · CAP-GROW cron · Dio sendTimeout · sync MASTER desfasados; check `verificar-lote-purpura-abiertos.ps1` |
| 2026-08-11 | **DASH-*** — FRESH/RT poll+hora; ORPH Ventas→Reportes, KPI QR, top cantidad, copy; check `verificar-dashboard-general.ps1` |
| 2026-08-11 | **Bloque D** — FL-STATE-01/02 (`operacionSucursalProvider`); FL-WIDGET-01 (`AsignarDomiciliarioSlot`); AQ-SOLID-08 KPIs costeo desde API; check `verificar-bloque-d-flutter.ps1` |
| 2026-08-11 | **Bloque D parcial** — HUER-HALF-01 Facturas internas; PERF-FL-LIST caja+kanban; PERF-FL-IMG residual; PERF-FL-MEM-01 audit; check `verificar-bloque-d-flutter.ps1` |
| 2026-08-11 | **Bloque C cerrado** — RBAC-MESERO-04 ✅ mesero 403 en asignar/reasignar/dispatch/disponibles; check `verificar-rbac-mesero-04.ps1` |
| 2026-08-11 | API-PAGE ✅ tope 200 + page opt-in usuarios/productos/insumos; Bloque C código (resta RBAC-MESERO-04) |
| 2026-08-11 | Bloque C: BN-MOD-05 ✅ · BN-CTRL-04/05/10–12 ✅ · API-HTTP ✅; resta API-PAGE + RBAC-MESERO-04 |
| 2026-08-08 | Creación: prioridades A→F, dependencias, checkboxes, mapa de estado |

**Prioridad operativa actualizada (2026-11-24):** FIN-TZ-01 quedó corregido y activado en Nest :3000; local y Tunnel responden HTTP 200. `COC-CANCEL-NODISP-MERMA-01`, `COC-DISPATCH-INCOMPLETE-01`, `PED-EDIT-01` y `FIN-MIXED-REFUND-METHOD-01` pasaron E2E en clones PostgreSQL QA; `QA-PRINT-BYPASS-01` está corregido. Ninguno de estos builds recientes se considera activado en :3000 hasta resolver la activación coordinada. Se conserva como pendiente `FIN-GASTO-DATE-01` (registro vs fecha operativa del gasto), FIN-DATE-01 y FIN-REC-OPEN-01. COC-NODISP-COMMERCE-01 sigue antes de rediseñar el cierre de pedidos: acordar sustitución/ajuste/devolución y efectos en prepago, abono, factura, Caja e inventario.

- [x] **PED-CLIENT-CANCEL-RACE-01** — revalidar cancelación de cliente bajo FOR UPDATE para que una aceptación concurrente no se pueda revertir desde el cliente. Regresión unitaria 1/1; build/runtime pendiente.

**PED-CLIENT-CANCEL-RACE-01 — verificación:** suite Nest 34/34 suites y 79/79 pruebas; build OK. Fuente corregida, API diaria todavía requiere activación coordinada.

- [x] **POS-COTIZACION-CASH-GUARD-01** — impedir cobro inmediato del aproximado local cuando falla cotización; requiere total servidor y da reintento. Flutter 16/16, analyzer/build OK; publicación y sesión real pendientes.

- [ ] **COC-KDS-NULL-STATE-01** — guard de caja, recálculo y consulta KDS tratan NULL como pendiente. Nest 35/35 suites, 83/83 pruebas; build y formato OK. Pendiente activar proceso API en mantenimiento para aplicar runtime sin interrumpir Tunnel.

- [x] **PED-DISCOUNT-READY-CLOSE-01** — saldo de salón cubierto por descuento cierra pedido listo/pagando por máquina central; suite 36/86 y build OK. Runtime pendiente de activación.
- [ ] **FIN-DISCOUNT-REFUND-METHOD-01** — definir y modelar método real del reembolso por descuento (método original, selección real o mix); hoy NULL aparece como `sin_metodo` en reportes. No inferir ni alterar histórico.
- [x] **KDS-LEGACY-STATE-UI-01** — estado de cocina nulo se muestra como pendiente en KDS; widget responsive 14/14. QA autenticada manual permanece pendiente.
- [x] **NAV-ANL-01 / F4-03** — selector de secciones móvil (<720 px) y TabBar escritorio comprobados con widgets 390/1440 px; permisos e índice se conservan. Falta QA visual autenticada.
- [x] **PUSH-PERM-STATUS-01** — comparar Firebase `NotificationSettings.authorizationStatus` para que permisos autorizados no bloqueen el token web; Flutter suite 236 aprobadas, 5 E2E omitidas, Dart focalizado sin error.
- [x] **DOMI-TOTAL-ENTREGAS-ACCEPT-01** — contar `total_entregas` solo al confirmar entrega, no al aceptar oferta; 36 suites/87 pruebas y build OK. Runtime pendiente de activación.

- [ ] **DOMI-LIQUIDACION-METODO-EXTERNO-01** — acordar semántica del ledger, capturar método de pago realmente recibido por el domiciliario y evitar metodo_pago='efectivo' como resumen de pagos mixtos. Después implementar idempotencia y validar cuadre entre pedidos, pagos, CxC y caja; no inventar medios ni alterar histórico.
- [x] **PED-POS-REPLACE-ATOMIC-01** — reemplazar línea en una transacción idempotente; bloquea líneas ya cobradas y operaciones que requieren reembolso de abonos; Nest 37 suites/92 pruebas, Flutter global 237/5 E2E omitidas, POS+repo 20/20, build/analyzer OK. Runtime API :3000 pendiente de activación coordinada.
- [x] **PED-CANCEL-COPY-01** — el diálogo Kanban ahora distingue reversa contable en Caja de reembolso realmente ejecutado por el proveedor de pago; sin cambio monetario.
- [ ] **PED-CANCEL-REFUND-SEMANTICS-01** — decidir cómo se confirma/registra el reembolso externo cuando personal cancela un pedido ya pagado, y cómo conciliarlo con la reversa automática de Caja sin doble devolución.
- [ ] **PED-CANCEL-RBAC-01** — decidir semántica de `cancelar_pedido`: hoy no se aplica; ruta exige `crear_pedido`, y el servicio usa rol/estado/ventana. UI ya oculta mutaciones no autorizadas por el contrato API vigente; no cambiar privilegios hasta definir matriz por rol.
- [ ] **COC-DISPATCH-INCOMPLETE-01** — el gate compartido bloquea dispatch si alguna línea no está resuelta y el comando central impide estado global `listo` con líneas pendientes/NULL o pedido vacío; mensaje de error se conserva en UI. E2E 1/1 sobre clon PostgreSQL: transición bloqueada, asignación manual 400 y dispatch independiente no iniciado (`PEDIDO_NO_LISTO`); guard unitario 5/5. Falta activar el proceso API y verificar runtime; la prueba de dispatch automático queda cubierta por guard unitario, pues la ruta de pedido incompleto no alcanza un estado despachable.
- [ ] **PED-EDIT-01** — editar preparación en `listo`/`pagando` devuelve línea y pedido a Cocina; edición/borrado/reemplazo no permite dejar un total inferior a lo ya recibido sin registrar devolución. E2E 4/4 en clon PostgreSQL QA: observación reabre Cocina; reducir, eliminar y reemplazar conservan ítems, total y abono tras 409/rollback. Falta activar el build en API :3000 y verificar runtime.
