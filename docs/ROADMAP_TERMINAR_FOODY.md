# Foody — Roadmap para terminar el software (checklist maestro)

> **Documento vivo.** Marca cada ítem al completarlo: `- [ ]` → `- [x]`.
>
> **Fuentes consolidadas (2026-06-24):** `docs/MASTER_STATUS.md`, `docs/MODULOS_ESTADO.md`, `docs/REGISTRO_IRREGULARIDADES_FLUJOS.md`, `docs/ESCENARIOS_NEGOCIO_FOODY.md`, …
>
> **Regla:** al cerrar un ítem, actualizar también `docs/MODULOS_ESTADO.md` y una viñeta en `docs/AVANCE_PROYECTO.md` (changelog).

**Última actualización:** 2026-07-01 — P0-08 RLS + estrategia backend primero.

**Próximo ítem recomendado:** **P0-05** VPS (cuando haya servidor) · verificación diaria: `.\scripts\verificar-cierre-sin-vps.ps1 -SinDocker`

> **Frontend en pausa (2026-07-01):** P3-05, P3-08 y QA UI manual pospuestos.

> **Estrategia acordada (2026-06-24):** **Primero cerrar el producto vendible (P1 al 100%)**, luego pulido operativo (P2). **Infra técnica / go-live (P0, P3)** se pospone hasta tener el producto completo para demo y venta.

---

## Cómo usar este archivo

1. Trabaja **de arriba hacia abajo** dentro de cada prioridad (P0 antes que P1).
2. No saltes a P2/P3 si hay ítems P0/P1 abiertos que bloquean tu objetivo (demo cliente vs go-live vs venta SaaS).
3. Los ítems marcados 🚫 **no implementar** salvo petición explícita del dueño del producto.
4. Los ítems con nota «doc obsoleto» ya pueden estar hechos en código — verificar antes de codificar.

### Leyenda

| Símbolo | Significado |
|---------|-------------|
| ✅ | Hecho en dev (no marcar aquí salvo verificación) |
| 🟡 | Parcial — falta cerrar |
| ⏳ | No iniciado |
| 🚫 | Pospuesto por acuerdo |
| 📅 | Solo spec / planificado |

### Progreso global (actualizar al cerrar ítems)

| Bloque | Total ítems | Hechos | % |
|--------|------------:|-------:|--:|
| P0 — Go-live operativo | 9 | 4 | 44% |
| P1 — Producto vendible | 15 | 15 | 100% |
| P2 — Pulido ERP | 22 | 22 | 100% |
| P3 — Producción / deuda | 10 | 7 | 70% |
| 🚫 Pospuesto | 5 | — | — |
| **Total accionable** | **53** | **48** | **91%** |

> **Estado base del producto (no repetir trabajo):** cliente, pedidos, mesas QR, caja, KDS, inventario→menú, costeo base, domiciliarios+GPS, FCM, self-service F1–F7 en código, multi-sucursal Fase 1–2, 31/32 irregularidades E2E resueltas.

---

## P0 — Bloquea operación real o go-live

Sin estos, un restaurante no puede operar de forma fiable en producción o no puede cobrar suscripciones.

### Impresión cocina (R5 — único ítem abierto en registro irregularidades)

- [ ] **P0-01** QA impresión térmica real (red :9100 o USB) — **pendiente cuando tengas impresora**
  - Modo dev sin hardware: ✅ `FOODY_PRINTER_MODE=archivo` + `tickets/`
  - Guía: `docs/IMPRESION_RESTAURANTE.md`

- [x] **P0-02** Tickets automáticos al `en_cocina` — cola + WebSocket + archivo verificado (`verificar-impresion.ps1`)

- [x] **P0-03** Guía instalación agente Python — `docs/IMPRESION_RESTAURANTE.md`, `scripts/iniciar-impresora.ps1`

- [x] **P0-04** Config impresora por cocina en admin (UI + BD `impresoras.ip_local`); falta solo poner IP real en prod

### Monetización en producción

- [ ] **P0-05** Desplegar API NestJS en VPS con dominio HTTPS — **diferido** (piloto PC+túnel 2026-08-08)
  - Guía: `docs/WOMPI_PRODUCCION.md`, `docs/ENTORNO_LOCAL.md`, `docs/MIGRACION_VPS_QUE_CAMBIA.md`

- [x] **P0-06** Registrar webhook Wompi en dashboard con URL prod (`POST /pagos/webhook`) — ✅ sandbox `api.foodyy.store` 2026-08-08

- [x] **P0-07** Configurar `WOMPI_REDIRECT_URL` HTTPS y probar flujo completo: checkout → pago → plan activo — ✅ sandbox E2E founder 2026-08-08 (prod cuando Wompi apruebe)

### Seguridad producción

- [x] **P0-08** RLS exhaustivo Supabase — migr. `064_rls_exhaustivo_prod.sql` (73 tablas RLS+FORCE); `scripts/verificar-rls.ps1`; repetir en VPS al desplegar
- [x] **P0-09** Canales Realtime staff opacos (RT-SEC-01 / OPS-07) — topics HMAC + `realtime_canales` en sesión; catálogo/pedido públicos. Check `verificar-rt-sec.ps1`. Upgrade nativo Realtime Authorization diferido.

---

## P1 — Producto completo para dueño / venta SaaS

Funciona en demo sin esto; falta para vender y retener clientes.

### Multi-sucursal y corporativo

- [x] **P1-01** Dashboard consolidado cadena (KPIs agregados: ventas, pedidos activos, alertas)
  - `GET /dashboard/consolidado` (permiso `gestionar_sucursales`); `DashboardConsolidadoWidget` en panel admin

- [x] **P1-02** Rol `gerente_cadena` explícito
  - Migración `060_rol_gerente_cadena.sql` (permisos = admin); `roles-food.ts`; `SucursalScopeService.esCorporativo()`; crear usuario solo corporativo; pagos/alertas/cron; UI `roles_foody.dart` + usuarios admin

### Centro de Análisis (BI) — módulo nuevo

Spec completa: `docs/MODULO_ANALITICA_BI.md`. Construir por fases:

- [x] **P1-03** F1 Backend: `foody_backend/src/modulos/analitica/` + `GET /analitica/resumen`
  - KPIs (ventas, ticket, margen, cancelación, efectivo/digital, alertas); presets fecha; `comparar=true` con Δ%; scope `SucursalScopeService`; migr. `061` permiso `ver_analitica`
- [x] **P1-04** F2 Backend: ventas, productos, cocinas (series temporales)
  - `GET /analitica/ventas` (día/hora≤7d, tipo, método, categoría); `/productos` (rankings + sin rotación); `/cocinas` (margen, tiempo prep, top 5)
- [x] **P1-05** F3 Backend: inventario, domiciliarios, caja, riesgo
  - `GET /analitica/inventario`, `/domiciliarios`, `/caja`, `/riesgo`; umbrales `UMBRALES_ALERTA`
- [x] **P1-06** F4 Flutter: `lib/features/analitica/` pantalla «Centro de Análisis»
  - `AnaliticaRepository` + `AnaliticaScreen` (8 tabs, presets, gráfica ventas `fl_chart`); menú Finanzas → «Centro de Análisis»
- [x] **P1-07** Permiso `ver_analitica` + `@RequiereModulo('analitica')` en planes Pro/Enterprise
  - `plan-features.config.ts` (`analitica: 'pro'`); controller `@RequiereModulo('analitica')`; Flutter `plan_modulos.dart` candado sidebar
- [x] **P1-08** QA analítica: admin sede solo ve su sucursal; corporativo puede comparar sedes
  - `GET /analitica/comparativa-sedes`; tab «Sedes» Flutter (corporativo); migr. `062`; `scripts/verificar-analitica.ps1`

### Planes y self-service

- [x] **P1-09** Paywall UI Flutter al recibir `403 PLAN_LIMITE_EXCEDIDO`
  - Interceptor `ClienteDio` (staff) + `PaywallLimitePlanDialog` → `/admin/mejorar-plan`
  - Ref: `lib/core/red/manejo_error_plan.dart`, `paywall_limite_plan_dialog.dart`

- [x] **P1-10** Cobro **recurrente** Wompi (suscripción mensual, no solo pago único)
  - Migr. `059_fuentes_pago_recurrente.sql`; `PagosRecurrentesService`; cron renovación; `POST /pagos/renovar`
  - Guarda `payment_source_id` tras pago; cobro automático 2 días antes del vencimiento
  - UI: tarjeta «Renovación automática» + botón Renovar en `MejorarPlanScreen`

- [x] **P1-11** Historial pagos / estado suscripción en panel dueño (UI ajustes plan)
  - `GET /pagos/estado` → `historial`; tarjeta suscripción + lista en `MejorarPlanScreen`

### Super Admin

- [x] **P1-12** Flujo completo aprobar documentos domiciliario independiente en Foody Control
  - Backend: `POST/GET /domiciliarios/documentos`, Storage; super-admin aprobar/rechazar + FCM; login/registro con JWT y `pendiente_verificacion`
  - Flutter: `DomiciliarioDocumentosScreen`, `FoodyControlRepartidoresVista` (preview, agrupación, activar cuenta)

- [x] **P1-13** Guard tenant estricto en todos los endpoints `/super/*`
  - `SuperAdminGuard`: revalida `rol = super_admin` y `restaurante_id`/`sucursal_id` nulos en BD; códigos `SUPER_ADMIN_REQUERIDO` / `SUPER_ADMIN_SIN_TENANT`

- [x] **P1-14** Revisar `SuscripcionActivaGuard` aplicado en **todos** los módulos NestJS
  - Auditoría 39 controllers; brecha cerrada en `notificaciones`; pagos/auth con `@OmitirSuscripcionActiva` (reactivación con plan vencido); error `RESTAURANTE_BLOQUEADO`

### Alertas

- [x] **P1-15** Push FCM (y opcional email) para alertas críticas de riesgo
  - `AlertasRiesgoService` → FCM nivel `alto`/`critico` a admin/gerente; hooks post-commit; deep link alertas en Flutter

---

## P2 — Pulido operativo / UX (spec ERP completa)

El restaurante opera; esto mejora experiencia y cierra brechas de escenarios 🟡.

### Mesas y QR

- [x] **P2-01** PDF / imprimir QR de mesa desde admin
  - Diálogo QR con imagen + `MesaQrPdfFoody` + compartir PDF (`share_plus`)
- [x] **P2-02** Banner contador QR pendientes más visible en panel mesero
  - Banner destacado en `MesasGridWidget` modo mesero (contador + urgentes +3 min)
- [x] **P2-03** Recordatorio FCM o job si QR `pendiente_aprobacion` > N minutos sin aprobar
  - `PedidosQrCronService` cada 60 s; umbral 3 min (`qrRecordatorioAprobacionMinutos`); FCM + realtime + auditoría `QR_RECORDATORIO_APROBACION`
- [x] **P2-04** UX clara «cuenta unificada vs ticket separado» en mesa compartida
  - API `cuenta` en `GET /pedidos/mesa/:id`; banner + ayuda + chip tipo + «Cobrar este ticket» en `MesaPedidosSheet`

### Pedidos y cliente

- [x] **P2-05** Cliente puede **cancelar** su pedido (endpoint público + reglas tiempo)
  - `POST /pedidos/:id/cancelar` + botón en `SeguimientoPedidoScreen`
- [x] **P2-06** Botón «Llamar mesera» en seguimiento pedido
  - `POST /pedidos/:id/llamar-mesera` (device_id, cooldown 90 s, FCM meseros); botón en `SeguimientoPedidoScreen`
- [x] **P2-07** Propina en checkout / cobro mesa
  - Campo propina en `CheckoutScreen` (para llevar/domicilio); `propina_acumulada` al crear; cobro mesa ya en `mesa_pedidos_sheet`
- [x] **P2-08** Split cuenta por comensal con etiquetas en UI (backend listo según escenarios)
  - Panel split + chips por comensal en `MesaPedidosSheet`; cobrar por comensal; botón asignar etiqueta por ítem
- [x] **P2-09** Alinear `cobrarCuentaMesa` con estado `pagando` del Kanban v2
  - Cobro parcial → `pagando` en BD + realtime; mesa `estado_operativo=pagando`; mismo fix en `cobrarPedidoCaja`

### Caja

- [x] **P2-10** Cuentas por cobrar avanzadas (más allá de fiados básicos)
  - `GET .../resumen` (total, antiguas +7d); listado con `dias_pendiente` y filtro historial; `PATCH .../pagar` con `metodo_pago`; UI banner + chips en `CajaAdminScreen`; `scripts/verificar-cxc.ps1` OK
- [x] **P2-11** Precio sugerido canal «para llevar» visible en pantalla Costos
  - `costeo.service.ts` enriquece `precio_sugerido_llevar`, `margen_llevar_porcentaje`, `costo_canal_llevar`; panel detalle en `costos_margenes_screen.dart`

### Menú y costeo

- [x] **P2-12** Producción en lote (`usa_produccion_lote`) — Fase 2 costeo
  - Migr. `063`; `POST/GET /costeo/producciones`; descuenta insumos + stock preparado; costo real/lote; toggle y UI en subrecetas; `verificar-produccion-lote.ps1` OK
- [x] **P2-13** Simulador popularidad mesa/domicilio — Fase 3 costeo
  - `GET /costeo/popularidad/:sucursal_id` (ABC + matriz estrella/caballo/puzzle/perro); UI sheet en Costos; `verificar-popularidad.ps1` OK
- [x] **P2-14** UI empaques/subrecetas en editor de receta
  - Grupo «Empaques domicilio» separado; desglose costo mesa vs domicilio; botones + Insumo/Subreceta/Empaque; margen error editable; badge empaque; API devuelve `costo_domicilio`; migr. 033 con `categoria_insumo=empaque`; `verificar-receta-empaque.ps1` OK

### Reportes

- [x] **P2-15** Gráficos avanzados en dashboard admin (no solo tarjetas)
  - `GET /dashboard/graficos` (ventas 7d, mix canal hoy, top productos); `DashboardGraficosWidget` con fl_chart; `verificar-dashboard-graficos.ps1` OK
- [x] **P2-16** Export PDF/Excel en módulo reportes
  - `ReporteExportFoody` (PDF + CSV/Excel); menú export en `ReportesAdminScreen`; `verificar-reportes-export.ps1` OK

### Usuarios staff

- [x] **P2-17** Editar rol y permisos granulares en UI (hoy: crear/activar-desactivar)
  - `GET /usuarios/catalogo-roles`, `PATCH /usuarios/:id`; diálogo Editar + chips permisos; `verificar-usuarios-editar.ps1` OK

### Multi-sucursal (si operan cadenas)

- [x] **P2-18** Menú maestro — `POST /categorias/sucursal/:destino/copiar-desde/:origen` + botón en `menu_admin_screen.dart`
- [x] **P2-19** Traslados entre sucursales — `POST .../cancelar`, UI usuario + gating corporativo

### Super Admin / config

- [x] **P2-20** PATCH config global Foody (`configuracion_global_foody`) desde panel — snackbar éxito

### Escenarios de negocio — verificar doc vs código

`docs/ESCENARIOS_NEGOCIO_FOODY.md` — **1 ❌** restante (COC-015 KDS offline):

- [x] **P2-21** Actualizar escenarios MES-009 (unión mesas), MES-015 (salió sin pagar), MES-016 (reservada) → ✅
- [x] **P2-22** Revisar los 17 ❌ desactualizados y reclasificar → **82 ✅ · 47 🟡 · 1 ❌**

---

## P3 — Producción, calidad y deuda técnica

Necesario antes de publicar en stores o escalar clientes.

- [x] **P3-01** E2E automatizado en CI — `verificar-ci.ps1` (rapido/completo), suite extendida, `.github/workflows/ci.yml` (build+analyze); E2E API en runner manual/self-hosted · `docs/CI_E2E.md`
- [x] **P3-02** Checklist QA manual por rol — `docs/CHECKLIST_QA_ROLES.md` + `scripts/verificar-qa-manual.ps1` (VPS-ready)
- [x] **P3-10** Prueba UI Flutter por rol — cubierto en `CHECKLIST_QA_ROLES.md` §3
- [x] **P3-03** Eliminar `lib/screens/` legacy cuando no queden imports — 49 archivos; solo `lib/legacy/main_reserva_canchas.dart` referenciaba; stub P3-03
- [x] **P3-04** Eliminar `lib/services/pedido_service.dart` y providers Firebase muertos — + `menu_catalog_service.dart`, `lib/providers/` (11), utils reserva legacy
- [ ] **P3-05** Renombrar paquete `reserva_canchas` → `foody` — **pausado** (solo Flutter)
- [ ] **P3-06** `docker-compose.prod.yml` desplegado y probado en VPS — build local ✅ `verificar-docker-prod.ps1`; deploy real con P0-05
- [x] **P3-07** Health checks + monitoreo — `GET /health` consolidado; `/health/realtime`, `/health/impresion` + cola; `verificar-salud.ps1`; `docs/MONITOREO_SALUD.md`
- [ ] **P3-08** Pulido animaciones Foody vs legacy — **pausado** (solo Flutter)
- [x] **P3-09** Sincronizar docs obsoletos — MASTER, MODULOS, AVANCE resumen, README índice, SELF_SERVICE; `docs/archivo/` para histórico

### Deuda estructural (Prompt 01 — documentada, no implementada)

> Registro completo: [`AUDITORIA_ARQUITECTURA_CALIDAD.md`](archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md). No bloquea P0 go-live piloto; **sí** bloquea escala multi-réplica / 500 sedes y viola regla Flutter=UI.

- [x] **AQ-FIX-01** Unificar write-path stock (`StockMovimientoService`) — cierra AQ-DUP-01 (incl. costeo `produccion` 2026-08-07)
- [x] **AQ-FIX-02** Romper ciclo Nest pedidos↔domiciliarios (hooks one-way) — AQ-CYCLE-01 ✅ F7
- [x] **AQ-FIX-03** Totales carrito vía API / UI-only explícito — AQ-SOLID-06/07 ✅ F4 (`POST /pedidos/estimar`)
- [ ] **AQ-FIX-04** Pool prod + cron con lock + rate-limit compartido — AQ-SCALE-01/02/05
- [ ] **AQ-FIX-05** Mover repos/modelos staff pedidos a `features/pedidos/` — AQ-CYCLE-04
- [ ] **AQ-FIX-06** `AnaliticaTokens` → `core/tema/` + `costeo_repository` bajo costeo — AQ-DUP-09
- [ ] **AQ-FIX-07** Batch N+1 menú/combos + clone catálogo — AQ-SCALE-03

### Contrato APIs REST (Prompt 04 — documentada, no implementada)

> Registro completo: [`AUDITORIA_APIS_REST.md`](archivo/auditorias-prompts/AUDITORIA_APIS_REST.md). No bloquea piloto demo; **sí** riesgo en turnos largos (listas) y retries de cobro/caja.

- [ ] **API-FIX-01** Paginación default-on + meta (pedidos, caja movimientos, usuarios, inventario)
- [ ] **API-FIX-02** 409 en conflictos `CAJA_YA_*` / `PEDIDO_CERRADO` + preservar códigos en filter
- [ ] **API-FIX-03** Idempotencia cobro + unique parcial una caja abierta / sucursal
- [x] **API-FIX-04** `forbidNonWhitelisted` (≡ BN-FIX-06) — ParseUUIDPipe parcial F7; completar params residuales aparte
- [x] **API-FIX-05** DTOs en bodies inline (≡ BN-FIX-02/03) — dispositivos + BN-DTO-06…19 + cotizar
- [ ] **API-FIX-06** `@HttpCode(201)` en creates (+ opcional 422 semántico)

### Auth / JWT (Prompt 05 — documentada, no implementada)

> Registro completo: [`AUDITORIA_AUTH_JWT.md`](archivo/auditorias-prompts/AUDITORIA_AUTH_JWT.md). Piloto OK con `UsuarioActivoGuard`; storage prefs + TTL 7d = deuda seguridad.

- [x] **AUTH-FIX-01** Secure storage JWT staff (móvil) — F4
- [~] **AUTH-FIX-02** Access TTL corto opcional (`JWT_EXPIRACION`) + refresh ✅ (`/auth/refresh`); TTL default 7d
- [x] **AUTH-FIX-03** `token_version` / invalidar al cambiar password — mig `084`
- [x] **AUTH-FIX-04** Retry interceptor tras refresh (1×; si refresh falla → login)
- [x] **AUTH-FIX-05** Logout server (bump `token_version`) — `POST /auth/logout`
- [ ] **AUTH-FIX-06** WhatsApp OTP — solo si producto lo pide (hoy 🚫 ausente)

### RBAC (Prompt 06 — documentada, no implementada)

> Registro completo: [`AUDITORIA_RBAC.md`](archivo/auditorias-prompts/AUDITORIA_RBAC.md). **P0 prod-risk:** IDOR cerrar caja + cobro mesero.

- [ ] **RBAC-FIX-01** `POST /caja/cerrar` exigir `caja.sucursal_id` scoped
- [ ] **RBAC-FIX-02** Cobrar requiere `ver_caja` / `cobrar_pedido` (no solo `ver_pedidos`)
- [ ] **RBAC-FIX-03** `PATCH …/estado` sin OR amplio `ver_pedidos`
- [x] **RBAC-FIX-04** Asignar domiciliario solo `gestionar_domiciliarios`
- [ ] **RBAC-FIX-05** Anonimizar device con prueba de posesión
- [ ] **RBAC-FIX-06** `prueba-web` / pagos staff con RolGuard
- [ ] **RBAC-FIX-07** Writes caja + colas globales acotadas

### BD / Supabase (Prompt 07 — documentada, no implementada)

> Registro completo: [`AUDITORIA_BD_SUPABASE.md`](archivo/auditorias-prompts/AUDITORIA_BD_SUPABASE.md). RLS deny-all ✅; backup VPS y N+1 = deuda.

- [ ] **BD-FIX-01** Cron VPS + R2 backups (OPS-02) + restore drill
- [ ] **BD-FIX-02** Índices `cajas` / `movimientos_caja` / catálogo extras
- [ ] **BD-FIX-03** Batch N+1 menú combos (≡ AQ-FIX-07)
- [ ] **BD-FIX-04** Batch clone catálogo + stock `ANY($1)`
- [ ] **BD-FIX-05** Documentar rol PG VPS + `verificar-rls.ps1` en prod
- [ ] **BD-FIX-06** UX soft-delete producto si hay pedidos
- [ ] **BD-FIX-07** Integridad `combo_items.item_id`

### Docker / env (Prompt 08 — documentada, no implementada)

> Registro completo: [`AUDITORIA_DOCKER_ENV.md`](archivo/auditorias-prompts/AUDITORIA_DOCKER_ENV.md). Restart/HC OK; logs + JWT example = deuda Hetzner.

- [ ] **DK-FIX-01** `logging` max-size/max-file en compose prod (+ Supabase)
- [ ] **DK-FIX-02** Rechazar JWT débiles del example; alinear `.env.example`
- [ ] **DK-FIX-03** Commitear compose prod + Dockerfile + `.dockerignore`
- [ ] **DK-FIX-04** Bind `127.0.0.1:3000` detrás de túnel/proxy
- [ ] **DK-FIX-05** Verificar volúmenes persistentes Supabase VPS
- [ ] **DK-FIX-06** Dockerfile USER non-root + `npm ci`
- [ ] **DK-FIX-07** CI checklist docker-prod endurecido

### Infra Cloudflare / VPS (Prompt 09 — documentada, no implementada)

> Registro completo: [`AUDITORIA_INFRA.md`](archivo/auditorias-prompts/AUDITORIA_INFRA.md). Fase 0 Tunnel OK; VPS/Nginx/R2 = deuda. SSL = Cloudflare ✅.

- [ ] **INF-FIX-01** VPS + `cloudflared` systemd (P0-05 / OPS-01)
- [ ] **INF-FIX-02** Logs + alerta disco (≡ DK-FIX-01)
- [ ] **INF-FIX-03** R2 backups privados + lifecycle (≡ BD-FIX-01 / OPS-02)
- [ ] **INF-FIX-04** Plantilla Nginx (body 25m, timeouts, headers) si se deja Tunnel
- [ ] **INF-FIX-05** Storage policies `service_role` explícito
- [ ] **INF-FIX-06** Test reconnect WiFi + runbook
- [ ] **INF-FIX-07** Presupuesto disco GB + `df` en cron

---

## 🚫 Pospuesto — no implementar salvo petición explícita

| ID | Tema | Motivo | Spec |
|----|------|--------|------|
| X-01 | Factura electrónica DIAN / proveedor FE | **🚫 Pausada** — ver `docs/FACTURACION_ELECTRONICA_PAUSADA.md` | Sprint 9–11 (cuando haya recursos) |
| X-02 | Import Excel KYG costeos | Solo referencia fórmulas | `TABLA DE COSTEOS KYG.xlsx` |
| X-03 | App cocina APK separada | Un solo `main.dart`; KDS en `/admin/cocina` | `foody-mismo-repositorio.mdc` |
| X-04 | KDS offline sin red | Complejidad alta; no bloquea MVP | Escenarios COC |
| X-05 | Google Maps en cliente | Reemplazado por OSM + Photon | Decisión tomada |

---

## Mapa por módulo (referencia rápida)

| # | Módulo | Estado | Ítems abiertos en este roadmap |
|---|--------|--------|-------------------------------|
| 1 | Cliente | ✅ | P2-05, P2-06 |
| 2 | Pedidos | 🟡 | P0-02, P2-07, P2-08, P2-09 |
| 3 | Mesas/QR | 🟡 | P2-01–04 |
| 4 | Admin multi-sede | ✅ | — |
| 5 | Caja | ✅ | P2-10 |
| 6 | Menú admin | 🟡 | P2-11–14 |
| 7 | Cocina/KDS | 🟡 | P0-01–04 |
| 8 | Inventario | ✅ | — |
| 9 | Costeo | 🟡 | P2-12, P2-13 |
| 10 | Domiciliarios | ✅ | — |
| 11 | Zonas/mapas | ✅ | — |
| 12 | Promociones | 🟡 | — |
| 13 | Reportes | 🟡 | P2-16 ✅ export |
| 14 | Facturación | 🟡 | X-01 🚫 |
| 15 | Alertas | ✅ | — |
| 16 | Usuarios | ✅ | P2-17 |
| 17 | Super Admin | ✅ | P2-20 |
| 18 | FCM | ✅ | — |
| 19 | Impresión Python | 🟡 | P0-01–04 |
| 20 | Producción/legacy | 🟡 | P0-05 VPS, P3-06 deploy |
| 21 | Analítica BI | ✅ | — |
| 22 | Self-service | 🟡 | P0-05–07 |

---

## Orden de ejecución recomendado (sprints lógicos)

> **Prioridad actual:** Sprint **D** (cerrar P1) → Sprint **E** (P2) → Sprints **A/B/C/F** (P0 + P3, cuando el producto esté vendible).

### Sprint D — Cerrar producto vendible (ahora) ⭐
**P1-08** → endpoint `GET /analitica/comparativa-sedes` (corporativo) + selector sede en Flutter + script `verificar-analitica.ps1` (scope 403 admin sede vs gerente cadena).

Al terminar P1-08: **P1 = 15/15 (100%)** — producto listo para vender/demo sin depender de VPS.

### Sprint E — Pulido operación (después de P1)
P2-* según feedback de restaurantes piloto (mesas, propina, cancelar pedido, export reportes…).

### Sprint A — Cocina física (cuando tengas impresora / antes de prod)
P0-01 → P0-02 → P0-03 → P0-04

### Sprint B — Dinero en prod (VPS + dominio)
P0-05 → P0-06 → P0-07

### Sprint C — Seguridad go-live
P0-08 → P3-06 → P3-07

### Sprint F — Cierre producción (pre-stores)
P3-* completo (legacy, CI, rename paquete)

---

## Documentación — estado post-auditoría (2026-07-01)

| Documento | Estado |
|-----------|--------|
| `MASTER_STATUS.md` | ✅ Fuente oficial — sincronizado |
| `MODULOS_ESTADO.md` | ✅ Módulo 20 producción actualizado |
| `AVANCE_PROYECTO.md` | ✅ Resumen 1 min + changelog; tablas sprint históricas = referencia |
| `MODULO_SELF_SERVICE_PLANES.md` | ✅ F1–F7 hechos; pendiente solo Wompi prod |
| `ESCENARIOS_NEGOCIO_FOODY.md` | ✅ 82✅ · 47🟡 · 1❌ (post P2-21/22) |
| `docs/archivo/*` | Histórico — no backlog |

---

## Plantilla al cerrar un ítem

```markdown
### [ID ítem] — YYYY-MM-DD
- [x] Descripción
- Archivos: ...
- Verificación: script / pasos manuales
- MODULOS_ESTADO: módulo N actualizado
```

---

## Changelog de este documento

| Fecha | Cambio |
|-------|--------|
| 2026-08-06 | **Prompt 09** — backlog INF-FIX-01…07 (doc `AUDITORIA_INFRA.md`); sin código |
| 2026-08-06 | **Prompt 08** — backlog DK-FIX-01…07 (doc `AUDITORIA_DOCKER_ENV.md`); sin código |
| 2026-08-06 | **Prompt 07** — backlog BD-FIX-01…07 (doc `AUDITORIA_BD_SUPABASE.md`); sin código |
| 2026-08-06 | **Prompt 06** — backlog RBAC-FIX-01…07 (doc `AUDITORIA_RBAC.md`); sin código |
| 2026-08-06 | **Prompt 05** — backlog AUTH-FIX-01…06 (doc `AUDITORIA_AUTH_JWT.md`); sin código |
| 2026-08-05 | **Prompt 04** — backlog API-FIX-01…06 (doc `AUDITORIA_APIS_REST.md`); sin código |
| 2026-08-05 | **Prompt 01** — backlog AQ-FIX-01…07 bajo P3 (doc `AUDITORIA_ARQUITECTURA_CALIDAD.md`); sin código |
| 2026-07-01 | **P3-09** auditoría docs; **P0-08** RLS migr.064; frontend pausado |
| 2026-06-24 | **P0-02/03/04 impresión** — modo archivo, migr. 058, health/jobs API, `verificar-impresion.ps1` |
| 2026-06-28 | **P2-16 reportes export** — PDF + CSV/Excel; `ReporteExportFoody`; script QA |
