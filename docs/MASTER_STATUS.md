# Foody — MASTER STATUS (fuente oficial del proyecto)

> **Única fuente de verdad para el estado del producto.**  
> Consolidación inteligente de 34 documentos en `docs/`, 10 en `INFRAESTRUCTURA/`, `MEMORIA.md` y verificación contra código (2026-06-28).  
> **Mantener este archivo** al cerrar tareas. Specs técnicas detalladas siguen en `INFRAESTRUCTURA/`; procedimientos en `docs/ENTORNO_LOCAL.md`.

**Última consolidación:** 2026-11-22 — rediseño responsive de Insumos e Inventario (UI; flujos intactos).
**Próxima prioridad:** resto 🟡 aceptados/ops · VIRAL-SYNC · PERF-LOAD/VPS · térmica
**Doc cierre Nest/Auth:** [`REMEDIACION_NEST_AUTH_2026-08-07.md`](REMEDIACION_NEST_AUTH_2026-08-07.md)

---

## 📊 Resumen general del proyecto

| Métrica | Valor | Notas |
|---------|------:|-------|
| Módulos de negocio documentados | **23** | Ver fichas § Módulos |
| Módulos NestJS (`foody_backend/src/modulos/`) | **28** | incl. salud, pagos, almacenamiento, finanzas |
| Handlers HTTP (controllers) | **~221** | 37 archivos controller |
| Pantallas Flutter (`lib/features/`) | **37** | 26 carpetas feature |
| Pantallas legacy (`lib/screens/`) | **0** | Eliminado P3-03 (2026-07-01) |
| Migraciones SQL | **89** | `001`–`089` en `foody_supabase/migrations/` |
| Problemas abiertos (registro formal) | **1+AQ…+INF** | R5 · AQ…DK/INF-\* |
| Problemas resueltos (registro E2E/ops) | **31/32** | `REGISTRO_IRREGULARIDADES_FLUJOS.md` |
| Ítems roadmap pendientes | **4** | P0: 4 · P3: 1 (P3-06 VPS) |
| Escenarios negocio cubiertos | **123/131 ✅** | 1 ❌ (COC-015 offline) · 8 🟡 (DIAN/impresión) |

### Veredicto ejecutivo

Foody es un **POS multi-restaurante MVP avanzado (~74/100 arquitectura)** usable en demo y piloto controlado. La columna vertebral (pedido → stock → cocina → caja) está operativa. **No está listo para go-live masivo** sin: impresión física validada, RLS prod, VPS/Wompi prod, CI E2E y limpieza legacy.

**Stack fijo:** Flutter (solo UI) · NestJS + PostgreSQL · Supabase (Auth, Realtime broadcast, Storage) · FCM · Python impresión local.

---

## Leyenda de categorías

| Símbolo | Significado en este documento |
|---------|-------------------------------|
| ✅ | Implementado y funcional en dev |
| 🟡 | Implementado parcialmente |
| 🔴 | Pendiente (no existe o no usable) |
| 🔵 | Solo documentado / planificado, sin código |
| 🟣 | Problema detectado y **vigente** |
| 🟢 | Problema **resuelto** (con origen doc) |
| 🟠 | Mejora recomendada (no bloqueante) |

---

# ✅ Implementado

Funcionalidades que existen en código y cubren el flujo principal.

### Operación core
- Cliente: ciudad → restaurante → menú → carrito → checkout → seguimiento + **mis pedidos** (device_id + opcional Google) + **escaneo QR cámara**
- Pedido mesa QR: `/mesa/:qrToken`, aprobación mesero, cuenta acumulada, cobro, split por comensal
- Kanban pedidos por canal (mesa/llevar/domi), cards ricas, modal detalle, cerrados hoy
- Mesas: grid CRUD, QR, PDF/compartir, transferir, unir, reservar, turno mesas, panel mesero/cajero
- Caja: abrir/cerrar, movimientos, gastos, fiados, CxC avanzadas, arqueo ciego, cuadre en reportes, mensajes de error legibles al usuario
- Cocina: CRUD cocinas/impresoras, KDS por ítem, sonido, alerta >20 min
- Inventario: insumos, compras, ajustes, conteo, recetas, subrecetas, traslados, sync menú al cambiar stock
- Domiciliarios: planta + independientes, dispatch (auto-retry + radio), ofertas TTL config, GPS, documentos + app repartidor (ingresos/contacto/mapa)
- Zonas domicilio (Haversine/OSM), horarios sucursal, geografía Photon
- **Breakpoints operación unificados** (`FoodyBreakpoints` 720/1100) — POS/caja/costeo/mesas

### Admin / corporativo
- Panel admin con sidebar por permisos y plan; selector sede; multi-sucursal Fase 1–2 (**menú maestro / copiar sedes**)
- Dashboard sede + **consolidado cadena** + **gráficos** (`fl_chart`)
- Centro de Análisis — **Centro de Inteligencia** premium (SaaS UI kit, KPIs uniformes+sparklines, dual-series vs anterior, heatmap horario, preset Personalizado, insights/alertas, skeletons, fl_chart, FoodyBreakpoints); export PDF/CSV
- **ThemeMode** global Riverpod + SharedPreferences; toggle light/dark en AppBar panel admin (cliente queda light hasta pasada dedicada)
- Catálogo admin: productos, toppings, bebidas, combos, fotos Storage, precio local/llevar
- Costeo industrial: motor KYG, merma, empaques, subrecetas, producción lote, simulador ABC, editor receta P2-14, **recetas en bebidas/toppings (068)**
- Reportes: financiero, productos, pedidos, cuadre caja, **export PDF/CSV**
- Alertas automáticas + FCM nivel alto/crítico
- Usuarios staff: listar, crear, editar rol/nombre/sucursal, catálogo permisos por rol, activar/desactivar, rol `gerente_cadena`
- Super Admin → **Centro de Operaciones (NOC)** [`SUPERADMIN_FOODY_CONTROL.md`](SUPERADMIN_FOODY_CONTROL.md): ops base ✅ · **Fase A esencial** 📅 (KPI/semáforo/freemium/auditoría) · visión 10 módulos B/C
- FCM: cola, cron, web + móvil, deep link `notificationclick`

### SaaS / monetización (dev)
- Plan `gratis` + límites numéricos; `PlanFeaturesGuard` + paywall UI 403
- **UX-PAYWALL-BLUR ✅** — módulo fuera de plan: esqueleto estático difuminado + overlay CTA (0 API/Realtime); búsqueda admin lista candados
- Self-service F1–F7: registro público, Google OAuth, Wompi checkout/webhook, cobro recurrente, avisos vencimiento
- Auth JWT + guards (JWT → UsuarioActivo → Suscripción → Rol → SuperAdmin)

### Infra dev
- Docker Postgres dev, scripts `verificar-*`, Realtime broadcast + poll respaldo, health `/salud`
- Impresión: cola jobs, WebSocket agente Python, **modo archivo** sin hardware

---

# 🟡 Implementado parcialmente

| Área | Qué funciona | Qué falta |
|------|--------------|-----------|
| **Pedidos** | Transacción atómica, IVA, descuentos, propina POS+mesa, CxC desde «Pendiente» | DIAN real; impresión auto en prod; recibo cliente |
| **Mesas/QR** | Flujo completo demo | QA PDF QR en todos los dispositivos |
| **Cocina/impresión** | KDS + cola + agente | QA impresora térmica real (R5) |
| **Facturación** | Borrador HTML, emitir/anular | DIAN 🚫 pospuesto |
| **Self-service/Wompi** | F1–F7 + recurrente en código | Webhook HTTPS prod (P0-06/07) |
| **Producción/infra** | CI 5/5, RLS 064, Docker build, `/health` | Deploy VPS (P0-05) |

### Promovidos a ✅ (2026-07-30)
Menú admin · Reportes · Multi-sucursal · Usuarios staff · Super Admin → NOC Fase A 📅 · Analítica BI (~96%) · Panel breakpoints (FoodyBreakpoints / RS-20)

---

# 🔴 Pendiente

Ítems del roadmap y spec **sin implementación usable**.

### P0 — Go-live (residuales diferidos / cerrados piloto)
- P0-01 QA impresión térmica real — **diferido** (waiver archivo 2026-08-08)
- P0-05 API NestJS en VPS — **diferido** (piloto PC+túnel 2026-08-08)
- ~~P0-06 Webhook Wompi~~ ✅ dashboard 2026-08-08
- ~~P0-07 flujo pago sandbox~~ ✅ plan actualiza sin sync manual (founder 2026-08-08) · prod cuando Wompi apruebe cuenta

### P3 — Deuda técnica (2 abiertos; frontend pausado)
- P3-06 Deploy `docker-compose.prod.yml` en VPS (build local ✅)
- ~~P3-05, P3-08, P3-09~~ P3-09 ✅ · P3-05/08 pospuestos (Flutter)

### Otros pendientes técnicos
- Tokenización tarjeta Wompi (payment links no siempre guardan fuente)
- Email alertas críticas (opcional)
- Exigir 3 tipos documento aprobados antes activar domiciliario (mejora)
- KDS offline (🚫 pospuesto X-04)

---

# 🔵 Documentado pero no implementado

Ideas con spec escrita pero **sin código** o solo planificado.

| Tema | Documento origen | Estado |
|------|------------------|--------|
| Factura electrónica DIAN / proveedor FE | Sprint 9–11, X-01 | 🚫 pospuesto acuerdo comercial |
| Import Excel KYG costeos | `MODULO_COSTEO.md`, X-02 | 🚫 solo referencia fórmulas |
| App cocina APK separada | `foody-mismo-repositorio.mdc`, X-03 | Decisión: un `main.dart` |
| Google Maps en cliente | X-05 | Reemplazado por OSM + Photon ✅ |
| Vistas materializadas analítica F5 | `MODULO_ANALITICA_BI.md` | Planificado post-MVP |
| PM2 cluster + Redis | `OPTIMIZACION_ESCALABILIDAD_FOODY.md` | Solo con 100+ restaurantes |
| Menú maestro Fase 3 multi-sede | `MULTI_SUCURSAL.md` | Spec, sin UI |
| Restricciones tier Enterprise exclusivas (DIAN) | `PLANES_SUSCRIPCION.md` | Metadata; DIAN no existe |
| R2 Cloudflare imágenes prod | `OPTIMIZACION_ESCALABILIDAD_FOODY.md` | Pendiente primer pipeline prod |
| Winston + UptimeRobot | Optimización doc | Planificado prod |
| **Multi-negocio / tipo Treinta+** | [`multinegocio/`](multinegocio/README.md), [`PLAN_MULTINEGOCIO_FOODY.md`](PLAN_MULTINEGOCIO_FOODY.md) | 📅 Spec completa (visión, verticales, módulos, BD, UI, checklist). **No implementar** hasta post-P0 restaurante |

---

# 🟣 Problemas detectados (vigentes)

### Bugs / UX
| ID | Severidad | Problema | Estado |
|----|-----------|----------|--------|
| **R5** | Infra | Impresión física sin QA en hardware restaurante | 🟡 Código listo; falta validación |
| **R10** | Borde | Carrera stock entre 2 QR simultáneos — segundo falla al aprobar | 🟡 Aceptado por diseño |
| **Firebase web legacy** | Ruido | `CONFIGURATION_NOT_FOUND` en consola web (Tu Cancha Fácil) | 🟡 No bloquea Foody admin |
| **AlertDialog + QrImageView** | UX web | Otros diálogos mesas usan `AlertDialog` (crear mesa, etc.) — solo QR migrado a `Dialog` | 🟡 Bajo riesgo |

### Arquitectura / integración
| Problema | Detalle |
|----------|---------|
| Legacy dual path | ~~`lib/screens/`~~ eliminado P3-03; paquete `reserva_canchas` pendiente P3-05 |
| Paquete Dart `reserva_canchas` | Confusión onboarding; no bloquea runtime · **AQ-NAME-05** |
| RLS prod incompleto | ~~Migr. 064~~ ✅ local; aplicar en VPS con P0-05 |
| Wompi solo dev/local | Sin dominio HTTPS no hay monetización real |
| Paginación inconsistente | API pedidos pagina (`page`/`limit`); UI/reportes 🟡 — `RECOMENDACIONES_IMPLEMENTACION.md` OPT-04 |
| Caché menú | ✅ `MenuCacheService` TTL 15 min; 🟡 mejora thrash a escala (max ~200) · **AQ-SCALE-04** |
| Backups automáticos | Scripts ✅; cron+R2 en VPS 🟡 — `docs/BACKUPS_FOODY.md` |
| FCM reintentos infinitos | ✅ migr. `078` + abandono tras 10 intentos |
| Storage estados expirados | ✅ cron + `POST /promociones/admin/limpiar-expiradas` |

### Arquitectura / calidad (Prompt 01 — 2026-08-05)

> **Registro completo con IDs:** [`archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md`](archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md) (32 🟣/🟡 abiertos + 7 AQ-FIX).  
> Canvas: `canvases/arquitectura-calidad-codigo.canvas.tsx`. Predecesora jun-12 (C1–C5 ✅): `archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md`.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **AQ-DUP-01** | Alta | Stock duplicado: `InventarioService` vs `PedidosInventarioService` | ✅ `StockMovimientoService` (+ producción costeo 2026-08-07) |
| **AQ-CYCLE-01** | Alta | Ciclo Nest `pedidos ↔ domiciliarios` (`forwardRef`) | ✅ F7 hooks one-way |
| **AQ-SOLID-06/07** | Alta | Totales/precios calculados en Flutter (carrito, checkout, sheets) | ✅ F4 |
| **AQ-SOLID-08** | Alta | Fórmulas costeo Nest recalculadas en Dart | ✅ KPIs % desde API; preview líneas OK |
| **AQ-SCALE-01** | Prod | Pool PG default 10 (prod debe ≥25 documentado) | ✅ |
| **AQ-SCALE-02/05** | Prod | Crons líder único + rate-limit multi-réplica en Postgres (`rate_limit_entries`) | ✅ |
| **AQ-SCALE-03** | Media | N+1 menú combos (1 query combo_items + agrupar) | ✅ |
| **AQ-CYCLE-04** | Media | Pedidos staff + modelo en `features/pedidos/` (shim admin) | ✅ |
| **AQ-DUP-09** | Media | `AnaliticaTokens` en `core/tema/` (shim analitica) | ✅ |
| **AQ-SOLID-03** | Media | `AlmacenamientoController` con SQL + cache (controller gordo) | ✅ BN-FIX-01 |
| **AQ-DUP-04** | Media | Upload imagen ×4 copy-paste | ✅ `subirImagenEntidadCatalogo` |
| **AQ-NAME-05** | Baja | Package `reserva_canchas` (P3-05) | 🟣 |
| Controllers Nest delgados | — | Punto fuerte (almacenamiento ya delgado) | ✅ |
| Geografía/ciudades aislados | — | Bajo acoplamiento | ✅ |

**Backlog remediación (orden):** AQ-FIX-01 stock único → AQ-FIX-02 romper ciclo dispatch → ~~AQ-FIX-03 totales API~~ ✅ F4 → AQ-FIX-04 pool/cron/rate-limit → AQ-FIX-05…07 (Flutter ownership + tokens + batch SQL).

### Backend NestJS — estructura (Prompt 02 — 2026-08-05)

> **Registro completo con IDs:** [`archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md`](archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md) (BN-MOD/CTRL/DTO/EXC/PIPE + BN-FIX-01…06).  
> Solapes con Prompt 01: BN-CTRL-01 ≡ AQ-SOLID-03; god Pedidos ≈ AQ-SOLID-02.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **BN-CTRL-01** | Alta | `AlmacenamientoController` con SQL + UPDATE catálogo | ✅ service `subirImagenEntidadCatalogo` |
| **BN-DTO-03/04** | Alta | `POST /dispositivos/*` públicos sin DTO class-validator | ✅ DTOs `dispositivos.dto.ts` |
| **BN-EXC-01/02/05** | Alta | Fallos fuente Wompi / renovación | ✅ auditoria + log error + `renovaciones_fallos` |
| **BN-EXC-18** | Media | Encolado impresión tragado tras pedido OK | ✅ F5 parcial (job `error` en cola) |
| **BN-DTO-06…19** | Media | ~14 mutaciones staff con `@Body` inline | ✅ BN-FIX-03 |
| **BN-DTO-21/31** | Media | `CotizarDomicilioDto` huérfano | ✅ wired a `GET /zonas/cotizar-domicilio` |
| **BN-PIPE-03** | Media | ValidationPipe sin `forbidNonWhitelisted` | ✅ `main.ts` |
| **BN-DTO-01/02** | Media | Bodies FCM auth inline | ✅ `dto/fcm.dto.ts` |
| **BN-DTO-20/22/32** | Media | Query promo/geografía + bools CrearPedido | ✅ BN-FIX-04 |
| **BN-CTRL-02/03** | Media | Authz usuarios / traslados en controller | ✅ services |
| **BN-EXC-03/04** | Media | `pagos-recurrentes` TX/fuente parcial | ✅ throw sin source + error/`consulta_fallida` |
| **BN-DTO-23** | Media | Query timeline auditoría sin DTO | ✅ `TimelineAuditoriaDto` |
| **BN-DTO-24…27** | Baja–Media | Queries pedidos/costeo/upload/retorno-app | ✅ `verificar-bn-dto-query-rest.ps1` |
| **BN-DTO-28/33** | Baja | AprobarPedidoMesa · ParseUUIDPipe hot paths | ✅ `verificar-bn-residuales.ps1` |
| **BN-MOD-03** | Baja | `/salud` ligero · `/health` + `/salud/completo` profundo | 🟡 aceptado |
| **BN-PIPE-04** | Baja | enableImplicitConversion | 🟡 aceptado (`@Type` en DTOs) |
| **BN-MOD-05** | Media | SQL ventas reportes ↔ analitica ↔ dashboard | ✅ `compartido/sql/ventas-metricas.sql.ts` |
| Controllers delgados (mayoría) | — | Caja/mesas/pedidos/super-admin OK | ✅ |
| Filter + interceptor globales | — | `{exito,datos}` / errores unificados | ✅ |
| `core/caja` writer único | — | Frontera intencional | ✅ |

**Backlog remediación Nest (orden):** ~~BN-FIX-01…06~~ ✅ · ~~BN-DTO~~ ✅ · ~~BN-CTRL-02…12~~ ✅ · ~~BN-MOD-05~~ ✅ · ~~API-HTTP-01/02/04~~ ✅ · ~~API-PAGE~~ ✅ · ~~RBAC-MESERO-04 / RBAC-FIX-04~~ ✅. Lista: [`REMEDIACION_NEST_AUTH_2026-08-07.md`](REMEDIACION_NEST_AUTH_2026-08-07.md).

### Flutter — estructura (Prompt 03 — 2026-08-05)

> **Registro completo con IDs:** [`archivo/auditorias-prompts/AUDITORIA_FLUTTER_ESTRUCTURA.md`](archivo/auditorias-prompts/AUDITORIA_FLUTTER_ESTRUCTURA.md) (FL-STATE/WIDGET/LEAK/NAV/API + FL-FIX-01…07).  
> Solapes: FL-WIDGET-06 ≡ AQ-SOLID-06; F9-06 ≡ FL-STATE-01/02.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **FL-LEAK-01** | Alta | Diálogos inventario: TEC sin `dispose` | ✅ try/finally |
| **FL-STATE-01/02** | Alta | Riverpod solo carrito; sin estado compartido pedidos/mesas/caja | ✅ `operacionSucursalProvider` epoch |
| **FL-WIDGET-02** | Alta | `ref.watch(carrito)` rebuilda menú entero | ✅ `Consumer`+`select` barra |
| **FL-WIDGET-06** | Alta | Totales/precios calculados en UI (≡ AQ-SOLID-06) | ✅ F4 |
| **FL-NAV-01** | Alta | `go('/admin/cajero')` desde panel rompe back-stack | ✅ `push` mesas_grid |
| **FL-LEAK-02** | Media | Realtime `unsubscribe` sin `removeChannel` (~9 pantallas) | ✅ `FoodyRealtime.liberarCanal` |
| **FL-WIDGET-01** | Media | 15 pantallas/widgets >1k LOC (god screens) | 🟡 primer corte: `AsignarDomiciliarioSlot` |
| **FL-API-01** | — | Sin Dio crudo en widgets (repos OK) | ✅ |
| Paths GoRouter únicos | — | Sin rutas duplicadas | ✅ |

**Backlog remediación Flutter (orden):** FL-FIX-01 leaks inventario → FL-FIX-02 removeChannel → FL-FIX-03 select carrito → FL-FIX-04 nav cajero → FL-FIX-05 F9-06 Riverpod → FL-FIX-06 totales API → FL-FIX-07 split god screens.

### APIs REST — contrato HTTP (Prompt 04 — 2026-08-05)

> **Registro completo con IDs:** [`archivo/auditorias-prompts/AUDITORIA_APIS_REST.md`](archivo/auditorias-prompts/AUDITORIA_APIS_REST.md) (API-HTTP/VAL/PAGE/IDEM/FMT + API-FIX-01…06).  
> Solapes: API-VAL ≡ BN-DTO/PIPE; API-PAGE ≡ AQ-SCALE-07. Prefijo `API-*` ≠ `FL-API-*` (Flutter).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **API-HTTP-01/02** | Media | Creates 201 (pedidos/caja/usuarios/productos); conflictos caja/pedido → 409 | ✅ `verificar-api-http.ps1` |
| **API-VAL-02/03** | Alta | ParseUUID en rutas UUID residuales; DTOs públicos parcial | 🟡 |
| **API-PAGE-02** | Alta | Movimientos caja **sin** paginación (SELECT completo) | ✅ F6 |
| **API-PAGE-01/03/04** | Media | Pedidos opt-in; usuarios/catálogo/insumos con tope + page | ✅ `verificar-api-page.ps1` |
| **API-IDEM-02/03** | Alta | Cobro sin clave idempotencia; abrir caja TOCTOU | ✅ F1 |
| **API-IDEM-01/05** | — | Pedidos `idempotency_key` + Wompi replay OK | ✅ |
| **API-FMT-01** | — | Envelope `{ exito, datos\|error, mensaje }` global | ✅ |
| **API-FMT-06** | Media | Códigos 400 aplanados a `SOLICITUD_INVALIDA` | ✅ parcial (`CAJA_YA_CERRADA`/`PEDIDO_CERRADO`/`SIN_SALDO` preservados) |

**Backlog remediación API (orden):** API-FIX-01 paginación listas → ~~API-FIX-02 409~~ ✅ → API-FIX-03 idem cobro/caja → API-FIX-04 UUID+forbid → API-FIX-05 DTOs inline → ~~API-FIX-06 201 creates clave~~ ✅.

### Auth / JWT (Prompt 05 — 2026-08-06)

> **Registro completo con IDs:** [`archivo/auditorias-prompts/AUDITORIA_AUTH_JWT.md`](archivo/auditorias-prompts/AUDITORIA_AUTH_JWT.md) (AUTH-FLOW/EXP/REV/STORE/OTP + AUTH-FIX-01…06).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **AUTH-FLOW-01/02** | Alta | Refresh + logout server (`token_version` / claim `tv`) | ✅ |
| **AUTH-STORE-01** | Alta | JWT staff en SharedPreferences (no secure storage) | ✅ F4 |
| **AUTH-WEB-01** | Alta | Release web: `flutter_secure_storage` → MissingPluginException; login correo/Google no persistía JWT | ✅ prefs en `kIsWeb` + rebuild tunel |
| **AUTH-FB-01** | Baja | Consola: Identity Toolkit `CONFIGURATION_NOT_FOUND` (Firebase Auth no usado en staff; FCM/legacy) | 🟡 ruido; no bloquea Nest/Supabase login |
| **AUTH-REV-01** | — | Desactivar usuario → 401 en siguiente request (`UsuarioActivoGuard`) | ✅ |
| **AUTH-REV-02/03** | Media | Password/logout invalidan JWT vía `token_version` (mig `084`) | ✅ |
| **AUTH-EXP-01** | Media | Retry 1× tras refresh (AUTH-FIX-04); residual si JWT revocado | 🟡 **a pulir** |
| **AUTH-EXP-05** | Media | Refresh suave en Dio si `porExpirar` (ventana 30m); TTL default sigue 7d (`JWT_EXPIRACION`) | 🟡 **a pulir** (TTL prod) |
| **AUTH-OTP-01** | — | WhatsApp OTP **no implementado** | 🚫 / 📅 |
| **AUTH-FLOW-03/04** | — | Login roles + cliente `device_id` OK | ✅ |

**Backlog remediación auth (orden):** ~~AUTH-FIX-01~~ ✅ · ~~AUTH-FIX-03/04/05~~ ✅ · **a pulir:** AUTH-FIX-02 TTL corto prod (`JWT_EXPIRACION`) · AUTH-FLOW-05 re-emisión perfil · AUTH-FIX-06 OTP si producto. Detalle: [`REMEDIACION_NEST_AUTH_2026-08-07.md`](REMEDIACION_NEST_AUTH_2026-08-07.md) §3.2.

### RBAC — roles y permisos (Prompt 06 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_RBAC.md`](archivo/auditorias-prompts/AUDITORIA_RBAC.md) (RBAC-GUARD/MESERO/CAJA/TENANT + RBAC-FIX-01…07).  
> **Prod-risk abierto:** — (mesero cobro ✅ F2; IDOR caja ✅ F0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **RBAC-TENANT-01** | Crítica | `POST /caja/cerrar` cierra caja de otro restaurante por UUID | ✅ F0 |
| **RBAC-MESERO-01/02** | Alta | Mesero cobra (OR `ver_pedidos`/`crear_pedido`) | ✅ F2 |
| **RBAC-MESERO-03/04** | Alta/Media | Mesero cambia estado + asigna domiciliarios | ✅ F2 estados / ✅ assign (FIX-04) |
| **RBAC-GUARD-01/02** | Alta | `anonimizar` público; `prueba-web` blast FCM | ✅ F3 |
| **RBAC-MESERO-05** | — | Módulo `/caja/*` / catálogo / reportes bloqueados a mesero | ✅ |
| **RBAC-TENANT-02** | — | Spoof `sucursal_id` otro resto → 403 (scope) | ✅ |

**Backlog remediación RBAC (orden):** RBAC-FIX-01 cerrar+sucursal → RBAC-FIX-02 cobro permiso caja → RBAC-FIX-03 estado → ~~RBAC-FIX-04 domi~~ ✅ → RBAC-FIX-05 anonimizar → RBAC-FIX-06/07 colas y writes.

### BD / Supabase self-hosted (Prompt 07 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_BD_SUPABASE.md`](archivo/auditorias-prompts/AUDITORIA_BD_SUPABASE.md) (BD-RLS/IDX/FK/N1/BKP + BD-FIX-01…07).  
> Solapes: N+1 ≡ AQ-FIX-07; backups ≡ OPS-02.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **BD-RLS-01** | — | RLS ENABLE+FORCE en 73/73 tablas (deny-all) | ✅ |
| **BD-RLS-02** | Media | Sin policies por tenant — aislamiento = NestJS | 🟡 |
| **BD-FK-01** | — | DELETE producto con pedidos históricos → FK bloquea (no CASCADE) | ✅ |
| **BD-IDX-01/02** | Alta | Faltan índices `cajas` / `movimientos_caja` | ✅ F6 |
| **BD-N1-01…03** | Alta | N+1 menú combos, clone, stock (≡ AQ-SCALE-03) | ✅ |
| **BD-BKP-01** | Prod | Backup auto VPS/cron+R2 **no activado** | 🟣 |

**Backlog remediación BD (orden):** BD-FIX-01 backups VPS → BD-FIX-02 índices caja → BD-FIX-03/04 N+1 batch → BD-FIX-05 doc rol PG → BD-FIX-06/07 soft-delete/combo FK.

### Docker / variables de entorno (Prompt 08 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_DOCKER_ENV.md`](archivo/auditorias-prompts/AUDITORIA_DOCKER_ENV.md) (DK-COMPOSE/SEC/HC/RST/LOG + DK-FIX-01…07).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **DK-LOG-01** | Prod | Rotación logs Docker (json-file max-size/max-file) aplicada en `docker-compose.prod.yml` | ✅ |
| **DK-SEC-03** | Prod | Validador prod rechaza JWT default / TTL largo (`validar-config-produccion`) | ✅ |
| **DK-COMPOSE-04** | Alta | Compose+Dockerfile **en workspace**; falta `git add` en commit | 🟡 |
| **DK-RST-01** | — | `restart: unless-stopped` OK | ✅ |
| **DK-HC-01/02** | — | Healthchecks Nest + Postgres dev OK | ✅ |
| **DK-COMPOSE-02** | — | Nest sin volumen (stateless) OK | ✅ |

**Backlog remediación Docker (orden):** DK-FIX-01 logging → DK-FIX-02 JWT gate → DK-FIX-03 commit+dockerignore → DK-FIX-04 bind localhost → DK-FIX-05 vols Supabase → DK-FIX-06/07 Dockerfile/CI.

### Infra Hetzner / Nginx / Cloudflare (Prompt 09 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_INFRA.md`](archivo/auditorias-prompts/AUDITORIA_INFRA.md) (INF-NGX/R2/TUN/SSL/DISK + INF-FIX-01…07).  
> Fase 0 = PC+Tunnel; VPS P0-05 abierto.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **INF-TUN-01/03** | Prod | WiFi/PC: tunnel foreground; VPS service no instalado | 🟣 |
| **INF-DISK-01/02** | Prod | Logs Docker con tope (≡ DK-LOG-01); presupuesto disco VPS sigue pendiente | 🟡 |
| **INF-NGX-01** | Alta | Nginx no en repo — edge = Cloudflare Tunnel (aceptado Fase 0) | 🟡 |
| **INF-R2-02/03** | Media | Storage write policies flojas; R2 backups no activado | 🟣 |
| **INF-SSL-01** | — | HTTPS Cloudflare (renovación automática CF) | ✅ |
| **INF-R2-01** | — | `foody-assets` público = intencional (menú) | 🟡 |

**Backlog remediación infra (orden):** INF-FIX-01 VPS+systemd tunnel → INF-FIX-02 logs/disco → INF-FIX-03 R2 privado → INF-FIX-04 plantilla Nginx → INF-FIX-05 Storage policies → INF-FIX-06/07 WiFi test + df.

### Realtime y sincronización (Prompt 10 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_REALTIME.md`](archivo/auditorias-prompts/AUDITORIA_REALTIME.md) (RT-CHAN/SEC/RECON/POLL/FALL/LIFE/LEAK/ENV/SCRIPT + RT-FIX-01…09).
> 16 pares emisor→oyente verificados en ejecución con `scripts/verificar-realtime-canales.js`.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **RT-CHAN-01** | Crítica | `catalogo_disponibilidad` emitido en `sucursal_{id}`; menú cliente y POS escuchaban `sucursal_{id}_catalogo` → suscripción muerta | ✅ |
| **RT-SEC-01** | Alta | Canales no privados: QR → UUID + anon oía caja | ✅ HMAC topics 2026-08-08 (`verificar-rt-sec.ps1`) |
| **RT-RECON-01** | Alta | Socket reconecta y re-une topics OK, pero broadcast sin replay y sin refetch al reconectar | ✅ F1 (refetch; sin replay) |
| **RT-POLL-01** | Media-Alta | Poll reevalúa salud RT cada ciclo (90s/30s) | ✅ |
| **RT-FALL-01** | Media | Poll en menú, POS, panel y domi planta | ✅ |
| **RT-LIFE-01** | Media | Refetch en `AppLifecycleState.resumed` pantallas ops (F1) | ✅ |
| **RT-LEAK-01** | Media | 9 pantallas exactas con `unsubscribe` sin `removeChannel`; agrava reconexión (≡ FL-LEAK-02 / AQ-SCALE-06) | ✅ F7 `FoodyRealtime.liberarCanal` |
| **RT-ENV-01** | Media | Una sola `SUPABASE_URL` en `.env` + nota en `.env.example` | ✅ |
| **RT-SCRIPT-01** | Baja | `verificar-realtime.ps1` leía `salud.datos.realtime` (campo solo en `/health`) | ✅ lee `/health` |
| **RT-ORPH-01** | — | Sin eventos huérfanos ni oyentes sin emisor | ✅ |
| Consistencia 2 dispositivos | — | BD converge (`FOR UPDATE` + máquina de estados); UI = convergencia eventual ≤90 s | 🟡 |

**Backlog remediación realtime (orden):** RT-FIX-01 canales privados/JWT → RT-FIX-02 refetch al reconectar → RT-FIX-03 poll adaptativo → RT-FIX-04 poll en menú/POS/panel → RT-FIX-05 refetch en `resumed` → RT-FIX-06 removeChannel → RT-FIX-07 `.env` → RT-FIX-08 script salud → RT-FIX-09 KDS incremental.

### Pedidos — ciclo de vida (Prompt 11 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`](archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md) (PED-PREPAGO/BYPASS/COBRO/EDIT/CHECK/DOC + PED-FIX-01…05).
> Verificado con `scripts/verificar-pedidos-ciclo-vida.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **PED-PREPAGO-01** | Alta | Para llevar con efectivo al crear: caja+`monto_pagado=total` pero estado=`en_cocina`; cobrar falla SIN_SALDO; bloquea cierre de caja | ✅ F0 |
| **PED-BYPASS-01** | Media | `salio-sin-pagar` UPDATE fuera de command FSM | ✅ 2026-08-08 vía `PedidosEstadoCommandService` |
| **PED-COBRO-SKIP-01** | Media | Origen `cobro` permite saltar a `pagado` desde `en_cocina` (intencional caja) | 🟡 aceptado |
| **PED-EDIT-01** | Media | Ítems editables post-cocina (hasta terminal); merma+alerta si ya preparando/listo | 🟡 aceptado |
| **PED-CHECK-01** | Baja | CHECK `pedidos.estado` (mig 089) | ✅ |
| **PED-DOC-01** | Baja | `FLUJO_ESTADOS_PEDIDOS.md` aún muestra `entregado` en salón | ✅ |
| **PED-INV-01** | — | PATCH Kanban rechaza transiciones inválidas | ✅ |
| **PED-FLOW-01** | — | Ciclo mesa `en_cocina→listo→pagando→pagado` stock/caja/mesa OK | ✅ |

**Backlog remediación pedidos:** PED-FIX-01 prepago terminal → PED-FIX-02 salio-sin-pagar vía command → PED-FIX-04 CHECK SQL → PED-FIX-05 edición en `pagando`.

### Cocina / KDS (Prompt 12 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_COCINA_KDS.md`](archivo/auditorias-prompts/AUDITORIA_COCINA_KDS.md) (COC-NODISP/CANCEL/UI-PRIO/FSM/REIMP + COC-FIX-01…05).
> Verificado con `scripts/verificar-kds.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **COC-NODISP-01** | Alta | `no_disponible` no cuenta como resuelto → pedido nunca llega a `listo` si hay algún ítem así | ✅ F0 |
| **COC-CANCEL-01** | Media | Cocina no puede DELETE ítem (404); cancelación real = DELETE staff + merma | 🟡 |
| **COC-UI-PRIO-01** | Media | API prioridad OK; Flutter KDS no llama ni muestra botón Urgente | ✅ F7 KDS + repo |
| **COC-FSM-01** | Baja | Sin máquina de estados en ítem (salto pendiente→listo OK) | 🟡 |
| **COC-REIMP-01** | Baja | `POST /impresion/reimprimir` + botón KDS (copia N; sin térmica física) | ✅ |
| **COC-RT-01** | — | Pedido nuevo → tickets KDS + comanda_copia + canal RT | ✅ |
| **COC-ORDER-01** | — | FIFO backend + sort urgencia/tiempo en Flutter | ✅ |
| **COC-FLOW-01** | — | Todos listo → pedido `listo` | ✅ |

**Backlog remediación cocina:** COC-FIX-01 no_disponible → COC-FIX-02 UI urgente/reimprimir → COC-FIX-03 UX cancelación cocina → COC-FIX-04 FSM ítem → COC-FIX-05 endpoint reimprimir.

### Caja (Prompt 13 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_CAJA.md`](archivo/auditorias-prompts/AUDITORIA_CAJA.md) (CAJ-SYNC/MIXTO/REOPEN/CANCEL/CIERRE/DOM + CAJ-FIX-01…03).
> Verificado con `scripts/verificar-caja-ciclo.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **CAJ-SYNC-01** | — | Cobro = `pedidos.total` en `movimientos_caja` (tope anti-doble) | ✅ |
| **CAJ-MIXTO-01** | — | Efectivo+tarjeta → N ventas + `pagos_pedido` | ✅ |
| **CAJ-REOPEN-01** | — | Pedido `pagado` no se reabre (correcto) | ✅ |
| **CAJ-CANCEL-01** | — | Cancel sin cobro no mueve caja; prepago → devolución = venta | ✅ |
| **CAJ-CIERRE-01** | — | Cuadre + alerta diferencia; bloqueo operación abierta | ✅ |
| **CAJ-DOM-IMPAGO-01** | Media | Domicilio entregado parcial bloquea cierre (by design; demo acumulaba 7) | 🟡 aceptado |
| **CAJ-MSG-01** | Baja | Filter conserva detalle de `CAJA_CIERRE_OPERACION_ABIERTA` | ✅ |
| **CAJ-TURNO-01** | Baja | `horas_abierta` + alerta `caja_turno_longevo` (>12 h, sin auto-cierre) + banner UI | ✅ |

**Backlog remediación caja:** CAJ-FIX-01 mensaje cierre detallado → CAJ-FIX-02 turno longevo → CAJ-FIX-03 UI bloqueadores de cierre.

### Inventario (Prompt 14 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_INVENTARIO.md`](archivo/auditorias-prompts/AUDITORIA_INVENTARIO.md) (INV-AUTO/PROP/ALERT/AUD + INV-FIX-01…03).
> Verificado con `scripts/verificar-inventario-ciclo.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **INV-AUTO-01** | — | Descuento automático al cocina; gap “solo manual” cerrado | ✅ |
| **INV-PROP-01** | — | Insumos←subreceta←plato propaga descuento | ✅ |
| **INV-ALERT-01** | — | `stock_minimo_alcanzado` tras venta ≤ mínimo | ✅ |
| **INV-ALERT-FCM-01** | Media | Stock bajo nivel medio → sin FCM (solo panel/RT) | 🟡 |
| **INV-ALERT-AJUSTE-01** | Baja | PATCH ajuste dispara `stock_minimo_alcanzado` | ✅ |
| **INV-AUD-01** | Media | Movimientos exponen `usuario_id` / `usuario_nombre` | ✅ |

**Backlog remediación inventario:** INV-FIX-01 exponer quién en movimientos → INV-FIX-02 FCM/nivel stock bajo → INV-FIX-03 alerta tras ajuste.

### Meseros / Mesas (Prompt 15 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_MESEROS_MESAS.md`](archivo/auditorias-prompts/AUDITORIA_MESEROS_MESAS.md) (MES-ASIG/XFER/SPLIT/RACE + MES-FIX-01…04).
> Verificado con `scripts/verificar-meseros-mesas.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **MES-ASIG-01** | — | Turno + bloqueo otra mesera | ✅ |
| **MES-XFER-01** | — | Transfer pedido activo + historial | ✅ |
| **MES-SPLIT-01** | — | Split cobro post-cocina (mismo pedido) | ✅ |
| **MES-RACE-01** | — | FOR UPDATE serializa adds concurrentes | ✅ |
| **MES-SPLIT-HIJO-01** | Media | No hay pedido hijo / mover ítems | 🟡 |
| **MES-XFER-MESERA-01** | Baja | Transfer copia mesera origen→destino | ✅ |
| **MES-XFER-UI-01** | Baja | Transfer UI admin+cajero (`cobrar_pedido`) | ✅ |
| **MES-MSG-01** | Baja | Códigos mesa preservados (no `SOLICITUD_INVALIDA`) | ✅ |

**Backlog remediación mesas:** MES-FIX-01 códigos error → MES-FIX-02 heredar mesera transfer → MES-FIX-03 pedido hijo (si producto) → MES-FIX-04 CTA mesero.

### Domicilios (Prompt 16 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_DOMICILIOS.md`](archivo/auditorias-prompts/AUDITORIA_DOMICILIOS.md) (DOM-FLOW/STATE/CANCEL + DOM-FIX-01…04).
> Verificado con `scripts/verificar-domicilios-ciclo.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **DOM-FLOW-01** | — | Flujo planta + cobro al entregar | ✅ |
| **DOM-SKIP-01** | — | Bloqueo `listo→entregado` | ✅ |
| **DOM-STATE-01** | — | `ocupado` admin coherente en ruta | ✅ |
| **DOM-CANCEL-01** | — | Admin cancela mid-ruta; asignación `cancelado` | ✅ |
| **DOM-CANCEL-WHO-01** | — | Cliente/domi no cancelan mid-ruta | ✅ |
| **DOM-CANCEL-INDEP-01** | Media | Cancel restaura `sesiones.disponible` indep | ✅ |
| **DOM-CANCEL-OFERTA-01** | Baja | Cancel cierra `ofertas_pedido` activas | ✅ |
| **DOM-EVID-01** | Baja | Sin foto/comprobante de entrega | 🟡 |

**Backlog remediación domicilios:** DOM-FIX-01 liberar sesión indep → DOM-FIX-02 ofertas → DOM-FIX-03 RT indep → DOM-FIX-04 evidencia (opcional).

### Clientes / QR (Prompt 17 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_CLIENTES_QR.md`](archivo/auditorias-prompts/AUDITORIA_CLIENTES_QR.md) (QR-FLOW/PRICE/TOKEN + QR-FIX-01…04).
> Verificado con `scripts/verificar-qr-cliente.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **QR-FLOW-01** | — | Pedido público QR → `pendiente_aprobacion` | ✅ |
| **QR-PRICE-01** | — | Precio body ignorado; BD manda | ✅ |
| **QR-PROD-01** | — | Producto off/ajeno rechazado | ✅ |
| **QR-TOKEN-01** | — | Token permanente; libre no invalida | ✅ |
| **QR-MULTI-01** | — | Varios pendientes mismo QR | ✅ |
| **QR-AUTO-01** | Media | No hay autoservicio sin aprobación mesero | 🟡 aceptado |
| **QR-MESA-ID-01** | Media | `tipo=mesa` sin `mesa_id` → 400 `MESA_REQUERIDA` | ✅ |
| **QR-EXP-01** | Baja | Sin auto-rechazo continuo (solo cierre caja >30m) | 🟡 |

**Backlog remediación QR:** QR-FIX-01 exigir mesa_id → QR-FIX-02 autoservicio opcional → QR-FIX-03 auto-rechazo → QR-FIX-04 rotar token.

### Promociones / Precios (Prompt 18 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_PROMOCIONES.md`](archivo/auditorias-prompts/AUDITORIA_PROMOCIONES.md) (PROMO-SNAP/STACK + PRECIO-SNAP + PROMO-FIX-01…04).
> Verificado con `scripts/verificar-promociones-precios.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **PROMO-SNAP-01** | — | Desactivar promo no recalcula pedido abierto | ✅ |
| **PRECIO-SNAP-01** | — | Ítem abierto conserva precio; cobro = snapshot | ✅ |
| **PRECIO-ADD-01** | — | Ítem nuevo usa catálogo actual | ✅ |
| **PROMO-ONE-01** | — | Máx. 1 promo; auto elige la mejor | ✅ |
| **PROMO-STACK-01** | Media | Combo + promo se apilan (sin exclusión) | 🟡 |
| **PROMO-DEL-01** | Baja | DELETE promo: `ON DELETE SET NULL` en pedidos (mig 089) | ✅ |
| **PROMO-MANUAL-01** | Baja | Descuento manual limpia `promocion_id` | ✅ |

**Backlog remediación promos:** PROMO-FIX-01 anti-stack combo → PROMO-FIX-02 DELETE/soft → PROMO-FIX-03 manual limpia FK → PROMO-FIX-04 recalc % al agregar ítems.

### Facturación DIAN/MATIAS (Prompt 19 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_FACTURACION.md`](archivo/auditorias-prompts/AUDITORIA_FACTURACION.md) + pausa [`FACTURACION_ELECTRONICA_PAUSADA.md`](FACTURACION_ELECTRONICA_PAUSADA.md).
> Verificado con `scripts/verificar-facturacion-ciclo.ps1` (exit 0 — capa local).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **FE-PAUSE-01** | — | Módulo DIAN/proveedor pausado X-01 | 🚫 |
| **FE-MATIAS-01** | Alta* | Cero integración MATIAS en repo | 🚫 |
| **FE-QUEUE-01** | Alta* | Sin cola/reintentos | 🚫 |
| **FE-ERR-01** | — | Errores locales (config/pagado) OK | ✅ |
| **FE-CONS-01** | — | total factura = total pedido | ✅ |
| **FE-ITEMS-01** | Media | Sin líneas de ítems en documento | 🟡 |
| **FE-NC-01** | Alta* | Nota crédito = stub; anular no toca pedido | 🚫 |

\*Al retomar go-live. Backlog: FE-FIX-01 cliente+estados → FE-FIX-02 cola → FE-FIX-03 ítems UBL → FE-FIX-04 NC real.

### Reportes / Analítica / Alertas (Prompt 20 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_REPORTES.md`](archivo/auditorias-prompts/AUDITORIA_REPORTES.md).  
> Verificado con `scripts/verificar-reportes-analitica.ps1` (exit 0 — API vs BD).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **REP-BD-01** | — | Financiero/resumen = SQL crudo | ✅ |
| **REP-LINE-01** | Baja | Header ticket vs ranking línea+extras | 🟡 |
| **ANA-FILT-01** | — | Filtros analítica AND combinables | ✅ |
| **ANA-FILT-PROD-01** | Media | Filtro producto/categoría/cocina: KPI y series = suma de líneas | ✅ |
| **REP-FILT-01** | Baja | Reportes solo fechas | 🟡 |
| **ANA-ESTADOS-01** | Media | `estados` omite cancelado/rechazado salvo `incluir_cancelados` | ✅ |
| **ANA-PERF-01** | Media | Demo OK; Seq Scan; sin MV; N+1 sedes | 🟡 |
| **ALT-UMB-01** | — | Umbrales = spec | ✅ |
| **ALT-BATCH-01** | — | Batch ≠ stock/cuadre (evento) | ✅ |
| **ALT-DOC-01** | Baja | Doc batch incompleto → actualizado | ✅ |

**Backlog:** REP-FIX-01 KPI por líneas filtradas · ANA-FIX-01 carga 50k · ANA-FIX-02 comparativa sedes · ALT-FIX-01 E2E umbral vivo.

### Dashboard general (Prompt 21 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_DASHBOARD.md`](archivo/auditorias-prompts/AUDITORIA_DASHBOARD.md).  
> Verificado con `scripts/verificar-dashboard-general.ps1` (exit 0 — ventas_hoy = financiero = analítica 187200).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **DASH-RT-01** | Media | Sin Realtime/poll; snapshot hasta refresh | ✅ poll 75s Inicio |
| **DASH-RT-02** | Media | Banner RT puede hacer creer que Inicio también auto-refresca | ✅ copy banner + «no en vivo» |
| **DASH-FRESH-01** | Media | Sin hora «Actualizado»; Reportes sí | ✅ HH:mm en header |
| **DASH-CACHE-01** | — | Sin cache Nest; GET = SQL vivo | ✅ |
| **DASH-ORPH-01** | Baja | `pedidos_pendientes_qr` en API, no en UI KPI | ✅ KPI QR → Mesas |
| **DASH-ORPH-02** | Media | KPI Ventas hoy → Caja (debería Reportes/Analítica) | ✅ → Reportes |
| **DASH-ORPH-03** | Baja | Top «por unidades» pero ORDER BY ventas | ✅ ORDER BY cantidad |
| **DASH-ORPH-04** | Baja | Copy «misma lectura que Análisis» sin mismo endpoint | ✅ «Tendencia sede (7d)» |
| **DASH-CONS-01** | — | ventas_hoy = reportes = analítica (hoy demo) | ✅ |
| **DASH-TZ-01** | Media-Alta | `created_at::date` vs Bogota en resumen/mix (riesgo noche CO) | ✅ F6 |
| **DASH-CONS-TOP** | Baja | Top dash=$ vs reportes=cantidad | ✅ alineado cantidad |
| **DASH-CONS-COMP** | Baja | KPI etiquetado «Cerrados hoy» (≠ tickets financiero) | ✅ |
| **DASH-CONS-PERIOD** | Baja | Reportes default 7d vs KPI hoy | 🟡 |

**Backlog residual:** DASH-PERIOD (si aplica).

### Configuración restaurante (Prompt 22 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_CONFIGURACION.md`](archivo/auditorias-prompts/AUDITORIA_CONFIGURACION.md).  
> Verificado con `scripts/verificar-config-restaurante.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **CFG-GLOBAL-DEAD** | Alta | Runtime lee `configuracion_global_foody` (umbrales + dispatch) | ✅ F3 |
| **CFG-PATCH-SUCURSAL-01** | Media | `PATCH /sucursales/:id` + UI Editar sede (nombre/dir/tel/activa) | ✅ |
| **CFG-MARGEN-UI-02** | Media | Márgenes sede en BD sin UI/API write | ✅ |
| **CFG-NOMBRE-MARCA-07** | Baja | `PATCH /sucursales/marca` admite nombre/teléfono + UI | ✅ |
| **CFG-POLIGONO-03** | Baja | `poligono` deprecado (COMMENT mig 088); cobertura = Haversine | 🟡 |
| **CFG-CACHE-MARCA-04** | Baja | Listado ciudad SQL vivo (sin caché Nest que invalidar) | 🟡 |
| **CFG-HORARIO-CACHE-08** | — | Horario invalida menú cache | ✅ |
| **CFG-IVA-PEDIDO-09** | — | IVA fiscal vivo en create | ✅ |
| **CFG-PLAN-API-10** | — | Guard plan lee BD | ✅ |
| **CFG-PLAN-UI-11** | Baja | Sidebar tras upgrade via `perfil` | 🟡 |
| **CFG-PLAN-FACT** | Info | Fiscal 403 plan demo (enterprise) | 🟡 |
| **CFG-REALTIME-06** | Info | Sin RT config (pull) | 🟡 |

**Backlog:** (CFG-FIX-01 cerrado vía F3). Residual: CFG-PLAN-UI.

### Performance backend (Prompt 23 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_PERF_BACKEND.md`](archivo/auditorias-prompts/AUDITORIA_PERF_BACKEND.md).  
> EXPLAIN + `scripts/verificar-perf-backend.ps1` + RunspacePool 10/50/200 (0 fails; p50 degrada).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **PERF-IDX-01** | Alta | `movimientos_caja` solo PK; `idx_scan=0` (≡ BD-IDX-02) | ✅ F6 |
| **PERF-SQL-01** | Alta | `SQL_PEDIDO_ES_HOY` ahora usa rango half-open (sin `created_at::date`) | ✅ |
| **PERF-SQL-02** | Alta | `SQL_VENTA_LINEA_ITEM` correlacionado: optimizado en dashboard + reportes/productos; analítica y otros endpoints pueden seguir | 🟡 |
| **PERF-SQL-04** | Alta | reportes caja: `COALESCE` reemplazado por filtros `OR` (evita no-sargable) | ✅ |
| **PERF-LOAD-02/03** | Alta | p50 3.7–10 s a 50–200 conc.; techo ~8–20 RPS | 🟣 |
| **PERF-POOL-01** | Alta | Pool default 10 si falta `DB_POOL_MAX` (≡ AQ-SCALE-01) | ✅ |
| **PERF-N1-01** | Alta | Menú combos N+1 (≡ BD-N1-01 / AQ-SCALE-03) | ✅ |
| **PERF-CACHE-02/03** | Media | Ciudades TTL 3 min · dashboard resumen TTL 30 s | ✅ |
| **PERF-CACHE-05** | Alta | Cache in-memory max 200 (≡ AQ-SCALE-04) | 🟡 |
| **PERF-SQL-03** | Media | Top productos drive desde `pedidos` (idx sucursal) | ✅ |
| **PERF-LOAD-01** | — | 0 errores HTTP en 10/50/200 | ✅ |
| **PERF-CACHE-01** | — | Menú TTL 5 min funciona | ✅ |

**Backlog:** PERF-FIX-01 índices caja · PERF-FIX-02 rangos fecha · PERF-FIX-03 batch venta línea · PERF-FIX-04 batch combos · PERF-FIX-05/06 caché ciudades/dashboard · PERF-FIX-07 pool prod.

### Performance Flutter (Prompt 24 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_PERF_FLUTTER.md`](archivo/auditorias-prompts/AUDITORIA_PERF_FLUTTER.md).  
> Estático + `scripts/verificar-perf-flutter.ps1`. Gap: heap DevTools 8 h.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **PERF-FL-LIST-07** | Alta | Caja movimientos unbounded + shrinkWrap anidado | ✅ max 80 + viewport 420 |
| **PERF-FL-MEM-01** | Alta | Realtime `unsubscribe` sin `removeChannel` (~9 pantallas) ≡ FL-LEAK-02 | ✅ re-audit liberarCanal |
| **PERF-FL-IMG-01** | Alta | 0 `memCacheWidth`/`Height` en features | ✅ menú+admin+costeo/promo/sedes |
| **PERF-FL-LIST-01** | Media | Kanban grid = `Wrap` eager | ✅ `ListView.builder` por filas |
| **PERF-FL-LIST-05/08** | Media | Insumos/catálogo con tope/page API (≡ API-PAGE) | ✅ |
| **PERF-FL-MEM-03/05/06** | Media | Pulso mesas solo si hay ocupadas (1.2s); `_movimientos` tope 80 en memoria | ✅ |
| **PERF-FL-IMG-03/06** | Media | `flutter_image_compress` sin uso; admin `Image.network` | 🟡 `cacheWidth` admin |
| **PERF-FL-LIST-03/04/06/09** | — | Cerrados/mis pedidos/movs inv/mesas OK | ✅ |
| **PERF-FL-IMG-04** | — | Nest sharp WebP ≤800 en upload | ✅ |

**Backlog:** PERF-FL-FIX-01 paginar caja · FIX-02 removeChannel · FIX-03 memCache thumbs · FIX-04 kanban builder · FIX-05 dispose conteo.

### Seguridad OWASP (Prompt 25 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_OWASP.md`](archivo/auditorias-prompts/AUDITORIA_OWASP.md).  
> Checks: `verificar-owasp.ps1` · `verificar-rls.ps1` (74/74) · `verificar-idor-scope.ps1` OK.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **SEC-BAC-01** | Crítica | IDOR cerrar caja UUID ajeno ≡ RBAC-TENANT-01 | ✅ F0 |
| **SEC-BAC-02** | Alta | Mesero cobra vía OR ver_pedidos ≡ RBAC-MESERO | ✅ F2 |
| **SEC-BAC-03/04** | Alta | anonimizar con posesión · prueba-web `@Permisos` (F3) | ✅ |
| **SEC-SECRET-01/02** | Alta | JWT fallback / example ≡ DK-SEC (validador prod) | ✅ |
| **SEC-BAC-06** | Media | Mutaciones finanzas → `gestionar_finanzas` (mig 087) | ✅ |
| **SEC-RLIMIT-01** | Baja | RL NO-OP fuera prod (CI); `RATE_LIMIT_FORZAR=1` para QA | 🟡 |
| **SEC-RLIMIT-03** | Media | `@RateLimitPublico` en menú/ciudades/geografía | ✅ |
| **SEC-INJ-*** | — | Raw SQL parametrizado; `${suc}` = `$N` | ✅ |
| **SEC-RLS-01** | — | 74/74 RLS+FORCE (era 73; +empleados) | ✅ |
| **SEC-BAC-07** | — | Spoof sucursal_id otro resto → 403 | ✅ |
| **SEC-SECRET-03** | — | `config/foody-entorno.env` → `.gitignore` | ✅ |

**Backlog:** SEC-FIX-01…08 (caja IDOR → cobro → anonimizar → JWT → RL → finanzas).

### Estrés / concurrencia (Prompt 26 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_ESTRES_CONCURRENCIA.md`](archivo/auditorias-prompts/AUDITORIA_ESTRES_CONCURRENCIA.md).  
> Checks: `verificar-estres-concurrencia.ps1` (exit 0, aviso caja) · `estres-1000-usuarios.mjs` 100×3 + 10 writes.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **CONC-CAJ-ABRIR-01** | Alta | Abrir caja check-then-insert TOCTOU ≡ API-IDEM-03 | ✅ F1 |
| **CONC-LOAD-LAT-01** | Alta | Mixto 100×3 p99~10 s (cola Nest/pool) ≡ PERF-LOAD | 🟣 |
| **CONC-LOAD-POOL-01** | Alta | Techo pool/Nest single-process | 🟣 |
| **CONC-INV-LOCK-01** | Media | `exigirIngrediente` con `FOR UPDATE` | ✅ |
| **CONC-CAJ-COBRO-01** | Media | Cobro FOR UPDATE OK; sin idempotency key ≡ API-IDEM-02 | ✅ F1 |
| **CONC-MT-01/02** | — | Multi-sede lecturas 60/60 OK; dashboards 200 | ✅ |
| **CONC-PED-IDEM-01** | — | Idempotency 2× → 1 pedido | ✅ |
| **CONC-PED-EST-01** | — | Doble `en_cocina`: FOR UPDATE + no-op; stock 1× | ✅ |
| **CONC-INV-ABS-01** | — | 2 PATCH absolutos → LWW sin valor corrupto | ✅ |
| **CONC-LOAD-OK-01** | — | 0 errores HTTP sostenido/pico/writes lab | ✅ |

**Backlog:** CONC-FIX-01 unique caja abierta · FIX-02 FOR UPDATE ingredientes · FIX-03 PERF pool/índices · FIX-04 idem cobro.

### Fuzz inputs (Prompt 27 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_FUZZ_INPUTS.md`](archivo/auditorias-prompts/AUDITORIA_FUZZ_INPUTS.md).  
> Check: `verificar-fuzz-inputs.ps1` (45 casos, exit 0, avisos=6).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **FUZZ-500-UUID-01** | Media | UUID/path basura → 500 ERROR_INTERNO (debería 400) | ✅ F7 parcial `ParseUUIDPipe` menú/caja/pedidos/cocina |
| **FUZZ-LEN-01** | Media | `@MaxLength(80)` en nombre mesa (crear/actualizar) | ✅ |
| **FUZZ-PAGE-01** | Baja | `PaginacionQueryDto` Min(1)/Max(100); clamp listado | ✅ |
| **FUZZ-ANON-01** | — | anonimizar device junk → 200 ≡ SEC-BAC-03 | 🟡 |
| **FUZZ-STABLE-01** | — | API no cae post-fuzz | ✅ |
| **FUZZ-STACK-01** | — | 0 stack traces en respuesta cliente | ✅ |
| **FUZZ-ENVELOPE-01** | — | 5xx envelope genérico sin paths | ✅ |
| **FUZZ-VAL-01** | — | Bodies inválidos → 400 (login/pedidos/caja…) | ✅ |

**Backlog:** FUZZ-FIX-01 ParseUUIDPipe · FIX-02 MaxLength textos · FIX-03 clamp page · FIX-04 auth anonimizar.

### Funcionalidad huérfana (Prompt 28 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_FUNCIONALIDAD_HUERFANA.md`](archivo/auditorias-prompts/AUDITORIA_FUNCIONALIDAD_HUERFANA.md).  
> Base: [`MAPA_FOODY.md`](MAPA_FOODY.md). Método: cruce estático Nest ↔ Flutter (sin click-through dispositivo).

| ID | Sev | Hallazgo | Fix | Estado |
|----|-----|----------|-----|--------|
| **HUER-PERM-01** | Alta | Tab Rentabilidad sin gate `ver_finanzas` (API 403) | CONECTAR | ✅ F3 |
| **HUER-CFG-02** | Alta | Super edita `configuracion_global_foody` sin efecto runtime (= CFG-GLOBAL-DEAD) | COMPLETAR/OCULTAR | ✅ F3 |
| **HUER-HALF-01** | Alta | Facturación DIAN pausado sin claim legal (sin “Resolución DIAN” en HTML/PDF) | COMPLETAR | ✅ |
| **HUER-API-COC-01** | Media | `PATCH …/prioridad` sin UI KDS (= COC-UI-PRIO-01) | CONECTAR | ✅ F7 |
| **HUER-API-COC-02** | Media | `PATCH …/observaciones` KDS sin UI | CONECTAR/DEPRECATE | ✅ F7 |
| **HUER-API-COST-01/02** | Media | Costeo combos GET+recalcular sin Flutter | CONECTAR | ✅ |
| **HUER-API-DOM-01** | Media | `GET /domiciliarios/ganancias` sin UI indep. | UI_NUEVA | ✅ 2026-08-08 tab Ingresos |
| **HUER-UI-01** | Media | Badge «No disponible» `onTap: () {}` menú admin | OCULTAR/CONECTAR | ✅ |
| **HUER-REPO-03** | Media | `actualizarCostoFijo` con diálogo editar | COMPLETAR | ✅ |
| **HUER-CFG-01** | Media | Márgenes sede BD sin API/UI write (= CFG-MARGEN-UI-02) | UI_NUEVA | ✅ |
| **HUER-REPO-01** | Baja | `costosProductos` repo muerto | DEPRECATE | ✅ |
| **HUER-DB-01/02** | Baja | Tablas `presentaciones_compra` / `ajustes_stock` sin Nest | DEPRECATE | ✅ |
| **HUER-OPS-*** | — | health/impresión/notif/webhook | OPS intencional | ✅ N/A |

**Backlog fix:** COC prioridad → costeo combos → ganancias domi → limpia repos/legacy (PERM/CFG ✅ F3).

### Consistencia entre módulos (Prompt 29 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_CONSISTENCIA_MODULOS.md`](archivo/auditorias-prompts/AUDITORIA_CONSISTENCIA_MODULOS.md).  
> Rutas: Pedido→Cocina→Caja→Inv→Análisis · Meseros→Pedidos→Cocina · Promo→Pedido→Caja · Inv→Productos→Cocina · Caja→Reportes · Config→Todos.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **PED-PREPAGO-01** | Alta | Cobrado al crear + estado `en_cocina` bloquea cierre | ✅ F0 |
| **COC-NODISP-01** | Alta | N/D cocina impide pedido `listo` | ✅ F0 |
| **CFG-GLOBAL-DEAD** | Alta | Config super → runtime vía `ConfiguracionGlobalService` | ✅ F3 |
| **CONS-STOCK-CASCADE-01** | Alta | Venta solo off el producto línea; hermanos con mismo insumo siguen on | ✅ F2 |
| **CONS-NODISP-STOCK-01** | Media | N/D cocina: merma (VIE-09 C) + `productos.disponible=false` + RT catálogo | ✅ |
| **CONS-KDS-UI-01** | Media | Pedido → `listo` cuando todos ítems `listo\|no_disponible` (COC-NODISP) | ✅ |
| **CONS-PROMO-ADD-01** | Media | Add/delete/update ítems reaplica % promo (o tope monto fijo) | ✅ |
| **CONS-REP-OPEN-01** | Media | Etiquetas tickets vs cobrado + `nota_universos` en API/UI | ✅ |
| **CONS-COSTO-SNAPSHOT-01** | Media | Canon: COGS=`pi.costo_unitario`; inv=`costo_actual`; ledger sync al editar qty | ✅ |
| **CONS-CUADRE-SQL-01** | Media | Script cuadre alineado a `ventas-metricas.sql` (neto+filtros) | ✅ |
| **CONS-SCRIPT-01** | Baja | Script coherencia llamaba `/caja/estado` 404 | ✅ fixed script |
| **RT-RECON-01** / **DASH-RT/TZ** | Alta/Media | UI desfasada entre pantallas | ✅ F1 refetch / ✅ F6 DASH-TZ |

**Checks:** salud OK · caja-coherencia OK · inventario-ciclo OK · promos OK · coherencia KPI 438175 · cuadre FAIL (esperado por universos).

### Viralización / spike de registros (Prompt 32 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_VIRAL_SPIKE.md`](archivo/auditorias-prompts/AUDITORIA_VIRAL_SPIKE.md).  
> Flujo real: `POST /auth/registro-restaurante` + TX multi-INSERT + bcrypt; **sin** OTP WhatsApp / MATIAS / FCM bienvenida Nest.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **VIRAL-CPU-01** | Prod | bcrypt rounds via `BCRYPT_ROUNDS` (8–12, default 10) | 🟡 |
| **VIRAL-POOL-01** | Prod | TX más corta (horarios/zona post-commit) · pool sigue techo | 🟡 |
| **VIRAL-SYNC-01** | Alta | Onboarding aún síncrono HTTP (sin cola pendientes) | 🟣 |
| **VIRAL-DEG-01** | Alta | Flag + cupo diario + max/min + UI waitlist | ✅ |
| **VIRAL-SIDE-01** | Prod | Cupo/flag mitiga spike; mismo nodo aún compartido | 🟡 |
| **VIRAL-RL-01** | Alta | RL IP + techo global `REGISTRO_MAX_POR_MINUTO` | 🟡 |
| **VIRAL-OTP/FE/FCM** | Info | OTP/MATIAS/bienvenida Nest no existen hoy | 🚫/🟡 |
| **VIRAL-META-01** | 📅 | Si OTP Meta: tier 250 falla Día 1 | 📅 |

**Línea tiempo:** D1 500 = degradación si burst · D2 5k = colapso onboarding+riesgo ops · D3–D4 20k–40k = outage.  
**Escalar primero:** waitlist/cola → Redis → PgBouncer → Nest réplicas → PG dedicado.  
**Roadmap F0–F7** en el doc (métricas + triggers).

**Backlog:** ~~FIX-01 flag/cupo~~ ✅ · FIX-02 cola pendientes · ~~FIX-03 defer horarios~~ ✅ · ~~FIX-04 RL global~~ 🟡 · ~~FIX-05 bcrypt rounds~~ 🟡 · FIX-06 runbook · FIX-07 OTP cola · FIX-08 pool separado.

### E2E automatizado (Prompt 33 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_E2E_AUTOMATIZADO.md`](archivo/auditorias-prompts/AUDITORIA_E2E_AUTOMATIZADO.md).  
> Jest/Supertest (API viva) + Flutter `test/e2e` + wrapper `integration_test`. Flujos: mesa, QR, domicilio, cocina, caja + VIE/CONS 28–30.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **E2E-SUITE-01** | — | 7 suites Jest (14) + 5 Flutter VM | ✅ |
| **E2E-STUB-01** | Baja | Stub Nest Hello World reemplazado por `/salud` | ✅ |
| **E2E-VIE-01-COV** | Alta | Regresión VIE-01 (expect `en_cocina` tras add) | ✅ F0 |
| **E2E-GAP-UI-01** | Media | Sin click-through pantallas Flutter | 🟣 |
| **E2E-FL-DEVICE-01** | Baja | `integration_test -d windows` necesita NuGet | 🟡 |
| **E2E-LIVE-01** | Info | Tests contra API viva (no Nest in-process) | 🟡 |
| **E2E-CI-01** | Media | GH Actions no corre Jest E2E (seed BD) | 🟣 |

**Checks:** `verificar-e2e-jest.ps1` ✅ · `verificar-e2e-flutter.ps1` ✅.

### Infra extremos (Prompt 34 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_INFRA_EXTREMOS.md`](archivo/auditorias-prompts/AUDITORIA_INFRA_EXTREMOS.md).  
> Timeout mid-TX · doble submit · API caída · reconexión/resync. Solapa API-IDEM / RT-RECON / VIE-12.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **INFRA-EXT-TO-01** | Alta | Timeout Dio mid-TX: Nest puede COMMIT; retry UX confusa | ✅ F1 (GET post-timeout) |
| **INFRA-EXT-TO-02** | Media | Dio `sendTimeout` (= `timeoutEnvio`) | ✅ |
| **INFRA-EXT-UI-01/02** | Media | Cobro mesa/kanban sin busy flag | ✅ F1 |
| **INFRA-EXT-UI-03** | Baja | KDS `_itemsEnVuelo` + `_conLockItem` (doble tap) | ✅ |
| **INFRA-EXT-DBL-01** | — | 2× cobrar paralelo → 1 OK / 1 reject | ✅ |
| **INFRA-EXT-DOWN-01/02** | Media | Banner API offline + splash no entra a panel si API caída | ✅ |
| **INFRA-EXT-SYNC-01** | Alta | Post-caída sin re-sync (= RT-RECON/LIFE, VIE-12) | ✅ F1 |
| **INFRA-EXT-MSG-01** | — | Mensajes timeout/conexión OK | ✅ |

**Vivo:** `verificar-infra-extremos.ps1` ✅ (doble cobro + host muerto ~2s).  
**Backlog:** FIX-01 GET tras timeout cobro · FIX-02 busy UI · API-FIX-03 · RT-FIX-02/05 · FIX-03 splash/salud · FIX-04 sendTimeout.

### Informe maestro (Prompt 35 — 2026-08-06)

> **Documento:** [`INFORME_MAESTRO_FOODY.md`](INFORME_MAESTRO_FOODY.md) — consolidación Prompts 01–34.  
> Plan F0–F8 por impacto ops restaurante; §6 CAP/VIRAL = decisiones infra/$$ (no bugfix).

| Fase | Foco | Horas ord. |
|------|------|------------|
| **F0** | ✅ IDOR caja · PED-PREPAGO · VIE-01 · COC-NODISP | 0 |
| **F1** | ✅ RT refetch · timeout cobro · busy UI · unique caja · idempotency | 0 |
| **F2** | ✅ cobrar_pedido · cascade stock · mesero ≠ listo | 0 |
| **F5** | Impresora + VPS + Wompi | 24–56 |
| **F8** | Escala/viral (§6) | plan $$ |

### Capacity planning / crecimiento masivo (Prompt 31 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_CAPACITY_PLANNING.md`](archivo/auditorias-prompts/AUDITORIA_CAPACITY_PLANNING.md).
> Baseline vivo: Nest **1 proceso**, `DB_POOL_MAX=25`, PG **`max_connections=100`** / `shared_buffers=128MB`, ~44 backends demo; techo lab ~8–20 RPS (PERF/CONC).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **CAP-INFRA-01** | Prod | Piloto = 1 nodo; compose documenta réplicas (no PM2 obligatorio) | 🟡 |
| **CAP-POOL-01/02** | Prod | Pool Nest vía `DB_POOL_MAX` (≥25 doc); falta PgBouncer | 🟡 |
| **CAP-LOAD-01** | Alta | 200 conc → p50 7–10 s (≡ PERF-LOAD) | 🟣 |
| **CAP-CACHE-01** | Alta | Cache max 200 thrash (≡ AQ-SCALE-04) | 🟡 |
| **CAP-GROW-01** | Alta | Cron purga cola FCM enviada/abandonada >14d | ✅ |
| **CAP-GROW-02** | Media | Cron purga `auditoria_logs` >90d | ✅ |
| **CAP-SQL-01** | Alta | Cast fecha / COALESCE caja / SubPlan: parcial (PERF-SQL-01/04 ✅ · 02 🟡 · 03 abierto) | 🟡 |
| **CAP-MOD-01 / EP-01** | Alta | Caen primero dashboard/menú/reportes + cocina RT | 🟣 |
| **CAP-FL-01** | Media | Caja tope + kanban builder (≡ PERF-FL-LIST) | ✅ |
| **CAP-PROC-01 / FE-01** | Info | WhatsApp/MATIAS no cargan hoy (no impl.) | 🟡 |

**Veredicto escala:** 100 = piloto parcial · 500+ = no sin PgBouncer/PM2/Redis · 1k+ = réplica lectura + partición · 5k–10k = multi-nodo.

**Backlog:** CAP-FIX-01 índices/SQL · FIX-02 pool VPS · FIX-03 purge notif · FIX-04 retención auditoría · FIX-05 Redis · FIX-06 PM2 tras Redis · FIX-07 réplica · FIX-08 Flutter listas · FIX-09 partición · FIX-10 cola MATIAS/FCM.

### Casos viernes alta demanda (Prompt 30 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_CASOS_VIERNES.md`](archivo/auditorias-prompts/AUDITORIA_CASOS_VIERNES.md).  
> Perspectiva operador; **DECISIÓN_PENDIENTE** = no inventar regla (opciones A/B/C).

| ID | Clase | Sev | Hallazgo | Estado |
|----|-------|-----|----------|--------|
| **VIE-01** | BUG | Alta | Add ítems con pedido `listo` → estado no baja a `en_cocina` | ✅ F0 |
| **VIE-05** | REGLA | Alta | Abono libre; `pagado` solo cocina completa o admin+motivo (**C**) | ✅ |
| **VIE-09** | REGLA | Alta | Fallo prep → N/D + merma + alerta (**C**) | ✅ |
| **VIE-13** | REGLA | Alta | Misma política cobro que VIE-05 (**C**) | ✅ |
| **VIE-12** | BUG | Alta | Reconnect sin refetch (= RT-RECON) | ✅ F1 |
| **VIE-QTY-01** | REGLA | Media | Prohibir qty↓ en preparando/listo; DELETE+merma (**C**) | ✅ |
| **VIE-02/03/04** | REGLA | — | Off catálogo / transfer / race FOR UPDATE | ✅ |
| **VIE-06/07/08** | REGLA | — | No reopen pagado; snapshots precio/promo | ✅ |
| **VIE-10/11** | REGLA | — | Cola impresión + pedidos en PG sobreviven restart | ✅ |

**Vivo:** pedidos-ciclo · meseros · promos · kds OK.

### Documentación (meta-problemas)
| Contradicción | Documentos | Resolución |
|---------------|------------|------------|
| Empaques/subrecetas «faltan» | `MODULOS_ESTADO.md` §6 vs §9 | **✅ Resuelto** en código P2-14 |
| Self-service «faltan F1–F3» | `MODULO_SELF_SERVICE_PLANES.md` | **✅ F1–F7** en código |
| Paywall «⏳» | `PLANES_SUSCRIPCION.md` | **✅ P1-09** |
| 8 escenarios ❌ | `ESCENARIOS_NEGOCIO_FOODY.md` | **✅ P2-21/22** — 1❌ restante (COC-015) |
| Tablas sprint AVANCE | Histórico jun-06 | **Referencia**; resumen 1 min = estado vivo |

---

# 🟢 Problemas resueltos

Problemas documentados que **ya están corregidos** en código.

| ID / Tema | Origen doc | Resolución |
|-----------|------------|------------|
| R1 Mesa liberada sin cobro | `archivo/auditorias-prompts/AUDITORIA_FLUJOS_E2E.md`, `REGISTRO_*` | 2026-06-19 — bloqueo `entregado` en mesa |
| R2 `estado_operativo` desincronizado | Idem | 2026-06-19 — sync en crear/cobro |
| R3 Domicilio `listo`→`entregado` sin repartidor | Idem | 2026-06-19 |
| R4 Ajuste inventario no propagaba menú | Idem | 2026-06-19 — `CatalogoDisponibilidadService` |
| R6 Transferencia sin auditoría | Idem | 2026-06-24 |
| R7 Race transferencia mesa | Idem | 2026-06-24 — `FOR UPDATE` |
| R8 Dispatch no auto-asignaba planta | Idem | 2026-06-24 |
| R9 Realtime silencioso sin env | Idem | 2026-06-24 — health + poll respaldo |
| R11 KDS regresaba a `confirmado` | Idem | 2026-06-19 / F-06 2026-06-24 |
| R12 Cobro domicilio al entregar | Idem | 2026-06-24 |
| R13 Cierre caja con operación abierta | Idem | 2026-06-24 — `CAJA_CIERRE_OPERACION_ABIERTA` |
| F01–F16 Auditoría operativa 2026-06-24 | `REGISTRO_IRREGULARIDADES_FLUJOS.md` | 15/15 ✅ |
| A01–A04 Deuda transversal backend | Idem | 4/4 ✅ |
| C1–C5 Críticos arquitectura | `archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md` | 2026-06-12 |
| I1–I7 Importantes arquitectura | Idem | Mayoría ✅; FCM/impresión eran ⏳, ahora 🟡 |
| Cobro mesa sin `movimientos_caja` | `ANALISIS_SISTEMA.md` | C1 auditoría ✅ |
| Sin KDS / sin cocinas CRUD | `ANALISIS_SISTEMA.md`, `PLAN_COMPLETAR_FOODY.md` | Bloque 1 ✅ migr. 026 |
| IVA siempre 0 | `ANALISIS_SISTEMA.md` | Bloque 2 ✅ migr. 027 |
| POST /mesas 401 ruido consola | Sesión 2026-06-28 | Probe → `GET /salud` |
| QR mesa congela web (LayoutBuilder) | Sesión 2026-06-28 | `Dialog` + `SizedBox` fijo en `_mostrarQr` |
| DioException crudo al cerrar caja | Sesión 2026-06-28 | `mostrarErrorSnackBar` + filtro HTTP preserva `CAJA_*` |
| Antigravity P0 bugs freemium | `walkthrough-antigravity.md` | 2026-06-24 |

---

# 🟠 Mejoras recomendadas (priorizadas)

> Spec completa: **`docs/RECOMENDACIONES_IMPLEMENTACION.md`** (matriz ✅/🟡/⏳).

### Alta — antes de go-live
1. ~~**OPS-05** UptimeRobot~~ ✅ monitor Up (2026-08-03)
2. ~~**OPS-03** Webhook Wompi~~ ✅ dashboard + pago sandbox E2E (2026-08-08)
3. **OPS-01 / P0-05** Comprar VPS + Fase 1 (`PREPARACION_VPS.md`) · cron R2 — **diferido**; piloto PC+túnel OK

### Media — backend / escala
4. **OPS-02** Cron + R2 en VPS (scripts listos; Windows Task Scheduler ya activo)
5. ~~OPT-04/05~~ ✅ paginación UI + poll RT

### Baja / pausado
6. **P3-05** Rename paquete · **P3-08** Animaciones
7. Winston · ~~Realtime JWT (OPS-07)~~ ✅ HMAC topics · Redis/R2 CDN (📅 100+ sedes)

> FCM-02, STOR-01, OPT-04, OPT-05 ✅ (2026-08-01). Spec: `RECOMENDACIONES_IMPLEMENTACION.md`.

---

# 📌 Estado de cada módulo

## 1. Cliente (pedir + historial)
| Campo | Valor |
|-------|-------|
| **Objetivo** | Descubrir restaurante, pedir (sin cuenta o con Google), seguir e historial |
| **Estado** | ✅ ~92% |
| **Implementado** | Ciudad, menú, carrito, checkout, seguimiento, mis pedidos (device_id + Google → `auth_uid`), QR mesa, escanear (Analítica + pegar + sesión activa), promos, domicilio+mapa, cancelar, llamar mesera |

| **Faltante** | Click-through Google en dispositivo real (redirect Supabase) |
| **Dependencias** | API pública, `device_id`, Realtime, Supabase Auth Google |
| **Riesgos** | Legacy Firebase en web (ruido consola) |

## 2. Pedidos y checkout
| Campo | Valor |
|-------|-------|
| **Objetivo** | Crear y gestionar pedidos con integridad financiera y stock |
| **Estado** | 🟡 ~90% |
| **Implementado** | POST atómico, IVA, zonas, descuentos, estados v2, propina, split, cobro, **Fase 2: PATCH ítem + Cambiar producto (agregar→quitar, también último ítem)**, combos con toppings/bebidas extra, POS menú con bebidas vendibles, CTA avance + mesero + Copia N, tabs+grid, reasignar domi, items_resumen, fiado CxC, **UX kanban/grid Analítica** (KPIs, chips/tabs ink, cards urgencia, CTA ink/Listo verde) |
| **Faltante** | DIAN; impresión auto prod; recibo cliente; DnD kanban / propina multi-mesero |
| **Dependencias** | Inventario, caja, mesas, cocina |
| **Riesgos** | R10 carrera stock QR (aceptado) · **PED-PREPAGO-01** para llevar cobrado sin `pagado` (bloquea cierre caja) |

## 3. Mesas y QR
| Campo | Valor |
|-------|-------|
| **Objetivo** | Gestión piso, QR cliente, cobro cuenta |
| **Estado** | 🟡 ~90% |
| **Implementado** | Grid, CRUD, QR+PDF, transferir, unir, reservar, turno, aprobación, split; pedido público QR → `pendiente_aprobacion`; precio server-side |
| **Faltante** | Autoservicio sin mesero (no existe); `mesa_id` obligatorio en QR; auto-rechazo continuo; rotar token |
| **Dependencias** | Pedidos, Realtime, FCM |
| **Riesgos** | Bajo · **QR-MESA-ID-01** · **QR-AUTO-01** · cross **RT-SEC-01** / **R10** |

## 4. Panel admin y multi-sucursal
| Campo | Valor |
|-------|-------|
| **Objetivo** | Operación staff por sede y cadena |
| **Estado** | ✅ ~90% |
| **Implementado** | Sidebar permisos/plan, selector sede, scope API, dashboard consolidado, gráficos, `gerente_cadena`, búsqueda + favoritos, **FoodyBreakpoints / RS-20**, **UI Horarios + Mis sucursales alineadas a Analítica** |
| **Faltante** | Discoverability favoritos (affordance) — menor |
| **Dependencias** | Auth, sucursal scope |
| **Riesgos** | Bajo |
| **Nav UX** | Ciclo 1 NAV-ADM ✅ · ciclo 2 **NAV-ADM2** 22/24 ✅ · breakpoints ADM2-06/24 ✅ |

## 5. Caja
| Campo | Valor |
|-------|-------|
| **Objetivo** | Turno caja, movimientos, fiados, cierre |
| **Estado** | ✅ ~95% |
| **Implementado** | Abrir/cerrar, gastos de turno, fiados, CxC, arqueo ciego, cuadre reportes, bloqueo cierre operación abierta, UX errores, CAJ-019, **CAJ-021**, pagos mixtos N movimientos, tope venta≤total pedido |
| **Faltante** | Mensaje cierre detallado (CAJ-MSG-01); alerta turno longevo |
| **Dependencias** | Pedidos pagos |
| **Riesgos** | Bajo · **CAJ-DOM-IMPAGO-01** (domi entregado parcial bloquea cierre) · cross **PED-PREPAGO-01** |

## 6. Menú / catálogo admin
| Campo | Valor |
|-------|-------|
| **Objetivo** | CRUD productos, precios canal, fotos |
| **Estado** | ✅ ~95% |
| **Implementado** | CRUD completo, fotos Storage, precio llevar, selector cocina, enlace costos, **copiar menú entre sedes (P2-18)**; **UI Menú alineada a Centro de Inteligencia** (filtros riesgo, tokens, responsive) |
| **Faltante** | — |
| **Dependencias** | Catálogo NestJS, Storage |
| **Riesgos** | Bajo |

## 7. Cocina / KDS / impresoras
| Campo | Valor |
|-------|-------|
| **Objetivo** | Preparación cocina + tickets impresos |
| **Estado** | 🟡 ~78% |
| **Implementado** | CRUD, KDS ítem, cola impresión, agente Python, modo archivo, RT `cocina_{id}`, prioridad API `[URGENTE]`, `comanda_copia` |
| **Faltante** | **QA hardware R5** · UI urgente/reimprimir · fix `no_disponible`→pedido listo |
| **Dependencias** | Pedidos, impresoras BD |
| **Riesgos** | **COC-NODISP-01** pedido trabado · **Alto** sin impresión física (R5) |

## 8. Inventario
| Campo | Valor |
|-------|-------|
| **Objetivo** | Stock, compras, recetas, sync menú |
| **Estado** | ✅ ~95% |
| **Implementado** | Descuento **automático** al cocina (`stock_descontado`); expansión subrecetas; insumos/compras/ajustes/conteo/traslados; alerta `stock_minimo_alcanzado`; sync catálogo; UI Insumos Analítica |
| **Faltante** | `usuario_id` en API/UI movimientos (INV-AUD-01); FCM stock bajo opcional; alerta tras ajuste manual |
| **Dependencias** | Costeo, pedidos |
| **Riesgos** | Bajo · **INV-AUD-01** (quién no visible en UI) |

## 9. Costeo industrial (KYG)
| Campo | Valor |
|-------|-------|
| **Objetivo** | Costos, márgenes, precios sugeridos |
| **Estado** | ✅ ~90% |
| **Implementado** | Motor costos, empaques, subrecetas, lote, ABC, editor P2-14, **recetas bebidas/toppings + descuento stock (068)**; **UI Costos alineada a Centro de Inteligencia** (intuitividad + riesgo + responsive) |
| **Faltante** | Import Excel 🚫 pospuesto |
| **Dependencias** | Inventario |
| **Riesgos** | Bajo |

## 10. Domiciliarios
| Campo | Valor |
|-------|-------|
| **Objetivo** | Entrega planta e independientes |
| **Estado** | ✅ ~90% |
| **Implementado** | Dispatch auto/manual + auto-retry/radio, ofertas TTL config, GPS, FCM, cobro al entregar, fiado CxC; **app repartidor** (NavigationBar, tarjeta contacto/mapa, ingresos+filtros, ganancia API) |
| **Faltante** | Cancel mid-ruta no libera sesión indep / ofertas; evidencia foto; E2E hardware; 3 docs obligatorios |
| **Dependencias** | Pedidos, FCM, Storage |
| **Riesgos** | Bajo · **DOM-CANCEL-INDEP-01** · cross **CAJ-DOM-IMPAGO-01** |

## 11. Zonas / mapas / horarios
| Campo | Valor |
|-------|-------|
| **Objetivo** | Cobertura domicilio y horarios operación |
| **Estado** | ✅ ~95% |
| **Implementado** | Anillos km, mapa OSM, cotización API, horarios CRUD, Photon |
| **Faltante** | — |
| **Dependencias** | Sucursales |
| **Riesgos** | Bajo |

## 12. Promociones
| Campo | Valor |
|-------|-------|
| **Objetivo** | Marketing y descuentos |
| **Estado** | ✅ ~90% |
| **Implementado** | Stories, código checkout, snapshot descuento al crear, DELETE; precio ítem congelado; 1 promo/pedido |
| **Faltante** | Anti-stack combo↔promo; DELETE con pedidos FK; limpia `promocion_id` en descuento manual |
| **Dependencias** | Storage, pedidos |
| **Riesgos** | Bajo · **PROMO-STACK-01** (combo+promo se apilan) |

## 13. Reportes
| Campo | Valor |
|-------|-------|
| **Objetivo** | Informes financieros y operativos |
| **Estado** | ✅ ~96% |
| **Implementado** | Financiero, productos, pedidos, cuadre caja, **export PDF/CSV**; **UI alineada a Centro de Inteligencia**; cifras = BD (`verificar-reportes-analitica.ps1`) |
| **Faltante** | Filtros ricos (viven en Analítica); smoke visual dispositivo |
| **Dependencias** | Caja, pedidos |
| **Riesgos** | Bajo · **REP-LINE-01** |
| **Audit** | `archivo/auditorias-prompts/AUDITORIA_REPORTES.md` |

## 14. Facturación
| Campo | Valor |
|-------|-------|
| **Objetivo** | Factura fiscal Colombia |
| **Estado** | 🟡 ~30% · 🚫 DIAN/MATIAS pausados (X-01) |
| **Implementado** | Config fiscal, borrador, emitir número local, HTML, anular soft; total=pedido; plan enterprise |
| **Faltante** | Cliente MATIAS/FE, cola/reintentos, CUFE/XML, nota crédito real, líneas ítems |
| **Dependencias** | Acuerdo comercial + proveedor |
| **Riesgos** | Legal prod sin FE · **FE-NC-01** stub |

## 15. Alertas
| Campo | Valor |
|-------|-------|
| **Objetivo** | Riesgos operativos automáticos |
| **Estado** | ✅ ~90% |
| **Implementado** | Reglas batch + evento; umbrales `UMBRALES_ALERTA` verificados; FCM alto/crítico; UI admin |
| **Faltante** | Email opcional; E2E umbral con datos sintéticos (ALT-FIX-01) |
| **Dependencias** | FCM, transacciones |
| **Riesgos** | Bajo · **ALT-UMB-01** ✅ |

## 16. Usuarios staff
| Campo | Valor |
|-------|-------|
| **Objetivo** | Gestión equipo restaurante |
| **Estado** | ✅ ~95% |
| **Implementado** | CRUD, editar rol/nombre/sucursal, catálogo permisos, gerente_cadena; **checklist permisos por usuario** (mig `085` `usuario_permisos`; JWT merge; create/edit UI); UI Centro de Inteligencia |
| **Faltante** | — |
| **Dependencias** | Auth, límites plan |
| **Riesgos** | Bajo |

## 17. Super Admin (Foody Control → NOC)
| Campo | Valor |
|-------|-------|
| **Objetivo** | Centro de Operaciones de plataforma: *«¿Cómo está Foody?»* |
| **Estado** | 🟡 ops base ~75% · **Fase A NOC** 📅 · visión 10 módulos diferida B/C |
| **Implementado** | 7 secciones, onboarding, docs domiciliarios, guards, PATCH config UI, estadísticas + planes, PATCH suscripción |
| **Faltante** | [`SUPERADMIN_FOODY_CONTROL.md`](SUPERADMIN_FOODY_CONTROL.md) **§3 Fase A:** home semáforo, KPI Gratis/Pro/Ultra, freemium kill switch, plan+motivo auditado, errores agrupados, asistente reglas (**SAC-***) |
| **Dependencias** | Auth super_admin · `/health` · perf |
| **Riesgos** | Alto lanzar freemium viral sin SAC-FREE-01; no construir visión completa pre-go-live |

## 18. FCM / notificaciones
| Campo | Valor |
|-------|-------|
| **Objetivo** | Push operativos y comerciales |
| **Estado** | ✅ ~90% |
| **Implementado** | Cola, cron, web+móvil, deep links |
| **Faltante** | — |
| **Dependencias** | Firebase SA backend |
| **Riesgos** | Bajo |

## 19. Impresión Python
| Campo | Valor |
|-------|-------|
| **Objetivo** | Tickets cocina en impresora local |
| **Estado** | 🟡 ~70% |
| **Implementado** | Jobs, WS, escpos, modo archivo, scripts |
| **Faltante** | QA hardware R5 |
| **Dependencias** | Cocinas, red local |
| **Riesgos** | **Alto** operación cocina sin ticket físico |

## 20. Producción / calidad / legacy
| Campo | Valor |
|-------|-------|
| **Objetivo** | Go-live stores y escala |
| **Estado** | 🟡 ~35% |
| **Implementado** | Scripts verificación, CI 5/5, RLS migr. 064, Docker prod compose, legacy screens eliminados |
| **Faltante** | Deploy VPS; rename paquete Flutter (P3-05 pausado); animaciones (P3-08 pausado) |
| **Dependencias** | VPS, proceso QA |
| **Riesgos** | **Alto** si se publica sin P3 |

## 21. Centro de Análisis (BI)
| Campo | Valor |
|-------|-------|
| **Objetivo** | KPIs dueño/admin tier Pro |
| **Estado** | ✅ ~98% |
| **Implementado** | Endpoints + filtros AND + PDF/CSV + comparativa + `pedidos-recientes` + **UI Centro de Inteligencia premium** (`lib/core/saas_ui/`, preset Personalizado, dual-series, heatmap, KPIs uniformes); KPIs = BD; **tab Rentabilidad** |
| **Faltante** | XLSX / MV (YAGNI); ranking meseros/clientes (empty honestos hasta API); smoke visual; carga 50k (ANA-FIX-01) |
| **Dependencias** | Reportes, pedidos, inventario data, §23 Finanzas |
| **Riesgos** | Bajo · **ANA-PERF-01** |
| **Audit** | `archivo/auditorias-prompts/AUDITORIA_REPORTES.md` · `scripts/verificar-reportes-analitica.ps1` |

## 22. Self-service / onboarding / planes
| Campo | Valor |
|-------|-------|
| **Objetivo** | Registro autónomo y monetización |
| **Estado** | 🟡 ~80% |
| **Implementado** | F1–F7 código, freemium, Wompi dev, recurrente; **UI Plan y pagos** (tokens Analítica, planes responsive) |
| **Faltante** | Prod HTTPS webhook/redirect |
| **Dependencias** | VPS, Wompi dashboard |
| **Riesgos** | **Alto** ingresos SaaS sin prod |

## 23. Finanzas (gastos fijos + nómina + P&L)
| Campo | Valor |
|-------|-------|
| **Objetivo** | Control de egresos del local y rentabilidad neta |
| **Estado** | ✅ ~90% UI / ~85% datos |
| **Implementado** | Migr. `080`; `empleados`; libro `gastos`; CRUD `/finanzas/*`; **`GET /finanzas/resumen`**; `GET /analitica/rentabilidad`; **hub UI premium** (KPIs, ingresos vs gastos, donut categorías, tablas SaaS, empty honestos presupuesto/proyección/facturas/flujo bancario); `verificar-finanzas.ps1` · Spec: [`docs/MODULO_FINANZAS.md`](MODULO_FINANZAS.md) |
| **Faltante** | API presupuesto / proyección 12m / flujo caja bancario; export P&L CSV; smoke UI dispositivo; recordatorios cron; nómina formal SSS 🚫 |
| **Dependencias** | Caja (gastos de turno), costeo/pedidos (snapshot `costo_unitario`), Analítica |
| **Riesgos** | Bajo si se respeta: pagos fijos/nómina/manual **no** tocan `movimientos_caja` |

---

# 🗂 Historial y documentos reemplazados

Cuando dos fuentes trataban el mismo tema, **prevalece la fecha más reciente verificada en código**.

| Tema | Documento vigente | Reemplaza / obsoleto |
|------|-------------------|----------------------|
| Estado proyecto | **Este `MASTER_STATUS.md`** | Fragmentos status en `AVANCE`, `MODULOS_ESTADO`, `PLAN_COMPLETAR` |
| Checklist accionable | `ROADMAP_TERMINAR_FOODY.md` | `PLAN_COMPLETAR_FOODY.md` (jun-04) |
| Problemas E2E | `REGISTRO_IRREGULARIDADES_FLUJOS.md` | Resumen ejecutivo `archivo/auditorias-prompts/AUDITORIA_FLUJOS_E2E.md` (jun-19, no actualizado) |
| Arquitectura | **`archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md`** (P01) + **`archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md`** (P02) + **`archivo/auditorias-prompts/AUDITORIA_FLUTTER_ESTRUCTURA.md`** (P03) + `MEMORIA.md` | `archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md` (jun-12) · `archivo/ANALISIS_SISTEMA.md` |
| Planes SaaS | `PLANES_SUSCRIPCION.md` | §2 `MODULO_SELF_SERVICE_PLANES.md` (marca F1–F7 ✅) |
| Self-service fases | Roadmap P1-09–11 + código | `MODULO_SELF_SERVICE_PLANES.md` §2 tabla «Falta» |
| Sesión Antigravity | Changelog en ROADMAP | `walkthrough-antigravity.md`, `implementation_plan-antigravity.md` |
| Inventario código jun-24 | Este MASTER + grep código | `inventario_sistema_foody-antigravity.md` (snapshot) |
| Escenarios negocio | Código + migr. 047 | `ESCENARIOS_NEGOCIO_FOODY.md` contadores jun-12 |
| Optimización | `OPTIMIZACION_ESCALABILIDAD_FOODY.md` | `foody_optimizacion.docx` (corregido en doc MD) |

### Changelog MASTER_STATUS

| Fecha | Cambio |
|-------|--------|
| 2026-11-22 | **UX-INV-REDISENO-01** — hero azul oscuro/naranja, resumen con datos actuales, CTA escritorio y tabs con iconos; `dart analyze` sin incidencias; QA visual manual pendiente |
| 2026-08-20 | **Lote 🟡** — CAJ-TURNO alerta+UI; ANA-FILT-PROD/ESTADOS; COC-REIMP endpoint+KDS; `verificar-lote-turno-ana-reimp.ps1` |
| 2026-08-19 | **Lote 🟡 bugs** — QR-MESA-ID, PROMO-MANUAL/DEL, DOM-CANCEL indep+oferta, INV-AJUSTE/AUD, MES-XFER/MSG, CAJ-MSG, PED-CHECK mig 089; `verificar-lote-amarillo.ps1` |
| 2026-08-11 | **VIRAL-DEG/SIDE/RL/CPU/POOL** — flag+cupo+max/min; GET registro-estado; UI waitlist; defer horarios; BCRYPT_ROUNDS; RBAC-MESERO assign sync ✅; `verificar-viral-registro.ps1` OK |
| 2026-08-11 | **SEC-RLIMIT-03 + INFRA-EXT-UI-03** — RL menú/ciudades/geo; KDS lock ítem; SEC-RLIMIT-01 🟡 FORZAR; DK-COMPOSE-04 🟡 workspace; `verificar-sec-rlimit-kds.ps1` OK |
| 2026-08-08 | **PRIORIDADES_FOODY.md** — lista viva A→F (go-live → seguridad → Nest → Flutter → escala → pospuesto); README + MASTER enlazan |
| 2026-08-07 | **Residuales menores** — `/salud/completo`; ParseUUIDPipe mesas/catálogo/…; aprobar sin `= {}`; PIPE-04 doc; `verificar-bn-residuales.ps1` OK |
| 2026-08-07 | **BN-DTO-24…27** — DTOs listar pedidos/cerrados, impacto-stock, upload imagen/video, retorno-app; `verificar-bn-dto-query-rest.ps1` OK |
| 2026-08-07 | **BN-DTO-23 + BN-EXC-03/04** — `TimelineAuditoriaDto`; recurrentes throw sin source + `consulta_fallida`; `verificar-bn-dto-auditoria.ps1` OK |
| 2026-08-07 | **Doc remediación Nest/Auth** — `REMEDIACION_NEST_AUTH_2026-08-07.md` (cerrado + evidencia + **a pulir** + gaps QA); MASTER/AVANCE/auditorías enlazados |
| 2026-08-07 | **BN-DTO-01/02 + BN-CTRL-02/03 + BN-EXC-18** — FCM DTOs; authz usuarios/traslados→service; impresión encola con job error; scripts `verificar-bn-dto-fcm` / `verificar-bn-ctrl-usuarios` OK |
| 2026-08-07 | **BN-FIX-04/05** — query DTOs `validar-codigo` + `geografia/buscar`; `@IsBoolean` en CrearPedido; cron expone `renovaciones_fallos`; `verificar-bn-dto-query.ps1` OK |
| 2026-08-07 | **BN-FIX-06** — `forbidNonWhitelisted: true` en ValidationPipe; `verificar-bn-pipe-forbid.ps1` OK (login/disponibilidad/cotizar) |
| 2026-08-07 | **BN-FIX-01** — SQL/ownership/UPDATE imagen → `AlmacenamientoService.subirImagenEntidadCatalogo` (cierra AQ-SOLID-03 / AQ-DUP-04); `verificar-bn-almacenamiento.ps1` OK |
| 2026-08-07 | **BN-FIX-03 + RT-SCRIPT-01** — DTOs inline 06…19 + CotizarDomicilioDto; `verificar-bn-dto-inline.ps1`; realtime script → `/health` |
| 2026-08-07 | **AUTH-FLOW** — mig `084` `token_version`; claim JWT `tv`; `POST /auth/refresh` + `/auth/logout`; password bump; Flutter logout server + refresh Dio; `verificar-auth-flow.ps1` OK |
| 2026-08-11 | **DASH-*** — FRESH/RT poll 75s + «Actualizado»; ORPH Ventas→Reportes, KPI QR, top cantidad, copy tendencia; Nest reiniciado; `verificar-dashboard-general.ps1` OK |
| 2026-08-11 | **Bloque D** — FL-STATE-01/02 `operacionSucursalProvider`; FL-WIDGET-01 slot domiciliario; AQ-SOLID-08 KPIs costeo API; HUER/PERF previos; `verificar-bloque-d-flutter.ps1` OK |
| 2026-08-11 | **Bloque D parcial** — HUER-HALF-01 Facturas internas (DIAN UI oculta); PERF-FL-LIST caja+kanban; PERF-FL-IMG residual; PERF-FL-MEM audit; `verificar-bloque-d-flutter.ps1` OK |
| 2026-08-11 | **USR-PERM-01b** — checklist = plantilla del rol; API rechaza perms ajenos; UI cobrar gated por `cobrar_pedido` |
| 2026-08-11 | **USR-PERM-01** — permisos por usuario (no plantilla rol): mig `085`, `permisosEfectivos`, POST/PATCH `permisos[]`, GET `:id/permisos`, checklist Usuarios; `verificar-usuario-permisos.ps1` OK |
| 2026-08-11 | **Bloque C cerrado** — RBAC-MESERO-04 / RBAC-FIX-04: solo `gestionar_domiciliarios` en planta asignar/reasignar/dispatch/disponibles; kanban oculta UI; `verificar-rbac-mesero-04.ps1` OK |
| 2026-08-11 | **Bloque C Nest** — +API-PAGE (tope 200 / page opt-in usuarios·productos·insumos). Check `verificar-api-page.ps1`. Resta RBAC-MESERO-04 |
| 2026-08-11 | **Bloque C Nest** — BN-MOD-05 `ventas-metricas.sql.ts`; BN-CTRL-04/05/10–12 services; API-HTTP 201+409. Checks: `verificar-bn-mod-05` · `verificar-bn-ctrl-04` · `verificar-api-http` OK. Resta: API-PAGE |
| 2026-08-10 | **UX-COSTEO-STITCH-02** — lista full-page + detalle 2 col Stitch; FAB ARMAR RECETA; API resumen +imagen/categoría; analyze OK |
| 2026-08-10 | **UX-SHELL-01** — `SaasScrollableShell` en Costos, Analítica, Menú, Insumos, Reportes + caja/usuarios/alertas/facturación/domiciliarios/zonas/horarios/sucursales/cocinas; Finanzas/Promociones ya ListView; `dart analyze` 0 errors |
| 2026-08-10 | **UI SaaS Insights+Finanzas** — `lib/core/saas_ui/` + ThemeMode Riverpod (toggle AppBar admin); Analítica Resumen 9 filas (Personalizado, dual-series, heatmap); Finanzas hub KPIs/charts/tablas + empty honestos; `dart analyze` 0 errors; `verificar-finanzas.ps1` OK; `/salud` OK |
| 2026-08-08 | **Bloque C parcial** — PED-BYPASS-01 (salio-sin-pagar→EstadoCommand); ParseUUIDPipe finanzas/domi/super; BN-CTRL-07; `verificar-ci -Completo` orquesta bn+rt-sec; residuales+CxC OK |
| 2026-08-08 | **Bloque B / RT-SEC-01 ✅** — topics staff HMAC; login `realtime_canales`; anon no oye caja; `verificar-rt-sec.ps1` OK; JWT prod validator + RATE_LIMIT_FORZAR |
| 2026-08-08 | **F5 / Bloque A piloto ✅** — pago sandbox Wompi → plan activo (founder); waiver archivo; PC+túnel; siguiente = Bloque B RT-SEC |
| 2026-08-08 | **Bloque A decisiones** — waiver impresión archivo; webhook Wompi+eventos ✅; piloto PC+túnel; upgrade paths térmica/VPS documentados |
| 2026-08-08 | **Bloque A smoke** — Docker/Supabase/Nest up; túnel CF (530→OK); agente impresión archivo `:8765`; `verificar-f5-golive` + `verificar-wompi-tunel` OK; C-05/C-06 humanos abiertos |
| 2026-08-07 | **FL-LEAK-01 + BN-DTO-03** — dispose TEC inventario; DTOs públicos dispositivos; `verificar-f3-confianza.ps1` OK |
| 2026-08-07 | **AQ-DUP-01 cierre** — costeo producción usa `StockMovimientoService` (+ `produccion_id`); `StockMovimientoModule` sin ciclo Nest |
| 2026-08-06 | **UX subrecetas/lote** — modos stock al vender vs preparar; sin falso stock bajo Prep; CTA Preparar lote |
| 2026-08-06 | **Costeo unidades** — UI permite g/kg y ml/L en receta/subreceta; `expandirReceta` convierte a `unidad_base` al descontar stock; `verificar-unidades-costeo.ps1` OK |
| 2026-08-06 | **F7 AQ-DUP-01** — `StockMovimientoService`; PedidosInventario + Inventario (ajuste/compra/conteo/traslado) escriben por el mismo núcleo; `verificar-inventario-ciclo.ps1` OK |
| 2026-08-06 | **Finanzas claro** — `GET /finanzas/resumen`; consejos P&L; pago editable; CTA→Rentabilidad; `verificar-finanzas.ps1` OK |
| 2026-08-06 | **F7 AQ-CYCLE** — `PedidosDispatchHooksService`; Pedidos no importa Domiciliarios; auto-dispatch OK (`verificar-flujo-domicilio.ps1`); AQ-DUP sigue MULTI_DAY |
| 2026-08-06 | **F7 parcial** — `ParseUUIDPipe` hot paths; `FoodyRealtime.liberarCanal` ×9; KDS Urgente; `verificar-f7-deuda.ps1` OK; AQ-DUP/CYCLE abiertos |
| 2026-08-06 | **F6 cerrado** — mig `083` índices caja/movimientos; paginación movs; DASH-TZ Bogota; `verificar-f6-perf.ps1` OK |
| 2026-08-06 | **F5 parcial** — BN-EXC Wompi/impresión; `verificar-f5-golive.ps1`; `CHECKLIST_F5_GOLIVE.md` |
| 2026-08-06 | **AUTH-WEB-01** — login staff roto en `equipo.foodyy.store` (MissingPluginException secure_storage); web→prefs; `servir-web-tunel-release` + `verificar-f4-sesion` OK |
| 2026-08-06 | **F4 cerrado** — JWT `flutter_secure_storage`; `POST /pedidos/estimar`; checkout total servidor; `verificar-f4-sesion.ps1` OK |
| 2026-08-06 | **F3 cerrado** — CFG global runtime (`ConfiguracionGlobalModule`); HUER-PERM tab Rentabilidad; anonimizar posesión + fix plataforma; `prueba-web` `ver_dashboard`; `verificar-f3-confianza.ps1` OK |
| 2026-08-06 | **F2 cerrado** — `cobrar_pedido` mig `082`; cascade `sincronizarPorIngrediente`; mesero estados whitelist; `verificar-f2-politica.ps1` OK |
| 2026-08-06 | **F1 cerrado** — RT refetch (KDS/kanban/caja/mesas); busy+idempotency cobro; unique caja; mig `081`; `verificar-f1-turno.ps1` OK |
| 2026-08-06 | **F0 cerrado** — RBAC-TENANT-01 (cerrar caja scope), PED-PREPAGO-01 (SQL + cocina→pagado), VIE-01 (demote add), COC-NODISP-01 (N/D resuelto); Jest 6/6 + `verificar-idor-scope.ps1` |
| 2026-08-06 | **Unificación docs** — `AUDITORIA_*.md` → `archivo/auditorias-prompts/`; `qa-sesiones/` archivadas; hub `README.md` corto; cola = `INFORME_MAESTRO_FOODY.md` |
| 2026-08-06 | **Prompt 35 Informe maestro** — consolidación 01–34; F0–F8 por impacto ops; § CAP/VIRAL aparte; `INFORME_MAESTRO_FOODY.md` |
| 2026-08-06 | **Prompt 34 Infra extremos** — timeout mid-TX, doble cobro (1/1 OK), API caída, resync=RT-RECON; `archivo/auditorias-prompts/AUDITORIA_INFRA_EXTREMOS.md` + `verificar-infra-extremos.ps1` |
| 2026-08-06 | **Prompt 33 E2E automatizado** — Jest 14 + Flutter 5; VIE-01/COC-NODISP/PED-PREPAGO; `archivo/auditorias-prompts/AUDITORIA_E2E_AUTOMATIZADO.md` + `verificar-e2e-*.ps1` |
| 2026-08-06 | **Prompt 32 Viral spike** — D1–D4 500→40k registros; VIRAL-\*; waitlist+cola primero; `archivo/auditorias-prompts/AUDITORIA_VIRAL_SPIKE.md` |
| 2026-08-06 | **Prompt 31 Capacity planning** — 100→10k sedes; CAP-\*; pool PG 100 / Nest 25; `archivo/auditorias-prompts/AUDITORIA_CAPACITY_PLANNING.md` |
| 2026-08-06 | **NOC Foody** — spec a Centro de Operaciones; Fase A esencial vs visión 10 módulos; §17 |
| 2026-08-06 | **Spec Foody Control (SAC-*)** — `SUPERADMIN_FOODY_CONTROL.md`: KPI Gratis/Pro/Ultra, semáforo escala, incidentes, cupo freemium; §17 → 🟡 |
| 2026-08-06 | **Prompt 30 Casos viernes** — 13 escenarios ops; VIE-01/05/09/12/13; decisiones A/B/C sin inventar; `archivo/auditorias-prompts/AUDITORIA_CASOS_VIERNES.md` |
| 2026-08-06 | **Prompt 29 Consistencia módulos** — 6 rutas de datos; NEW CONS-STOCK/PROMO-ADD/NODISP-STOCK/KDS-UI/REP-OPEN; reconfirm PED-PREPAGO+COC-NODISP+CFG-GLOBAL-DEAD; `archivo/auditorias-prompts/AUDITORIA_CONSISTENCIA_MODULOS.md` |
| 2026-08-06 | **Prompt 28 Funcionalidad huérfana** — ~12 huérfanos producto (KDS prio, costeo combos, ganancias, PERM rentabilidad, CFG-GLOBAL-DEAD); ops OK; `archivo/auditorias-prompts/AUDITORIA_FUNCIONALIDAD_HUERFANA.md` |
| 2026-08-06 | **Prompt 27 Fuzz inputs** — 45 payloads; 0 stack/0 down; UUID→500; mesas 5k; `archivo/auditorias-prompts/AUDITORIA_FUZZ_INPUTS.md` + `verificar-fuzz-inputs.ps1` |
| 2026-08-06 | **Prompt 26 Estrés/concurrencia** — multi-sede OK; races pedido/inv; caja TOCTOU; carga p99~10s; `archivo/auditorias-prompts/AUDITORIA_ESTRES_CONCURRENCIA.md` + `verificar-estres-concurrencia.ps1` |
| 2026-08-06 | **Prompt 25 OWASP** — injection OK; BAC Prompt 06 vivo + finanzas; JWT/DK-SEC; RL prod-only; RLS 74/74; `archivo/auditorias-prompts/AUDITORIA_OWASP.md` + `verificar-owasp.ps1`; gitignore entorno |
| 2026-08-06 | **Prompt 24 PERF Flutter** — listas/memoria/imágenes; `archivo/auditorias-prompts/AUDITORIA_PERF_FLUTTER.md` + `verificar-perf-flutter.ps1`; gaps LIST-07 / MEM-01 / IMG-01 |
| 2026-08-06 | **Prompt 23 PERF backend** — EXPLAIN queries; caché menú-only; carga 10/50/200; `archivo/auditorias-prompts/AUDITORIA_PERF_BACKEND.md` + `verificar-perf-backend.ps1`; gaps PERF-IDX/SQL/LOAD/CACHE |
| 2026-08-06 | **Prompt 22 Config restaurante** — BD↔UI; propagación; multi-rol; `archivo/auditorias-prompts/AUDITORIA_CONFIGURACION.md` + `verificar-config-restaurante.ps1`; **CFG-GLOBAL-DEAD** |
| 2026-08-06 | **Prompt 21 Dashboard** — frescura/huérfanos/consistencia vs reportes; `archivo/auditorias-prompts/AUDITORIA_DASHBOARD.md` + `verificar-dashboard-general.ps1`; gaps DASH-TZ / DASH-RT / DASH-ORPH |
| 2026-08-06 | **Prompt 20 Reportes/Analítica** — cifras=BD; filtros AND; umbrales alertas; `archivo/auditorias-prompts/AUDITORIA_REPORTES.md` + `verificar-reportes-analitica.ps1`; gaps ANA-FILT-PROD / ANA-PERF |
| 2026-08-06 | **§23 Finanzas** — gastos fijos + nómina simple + P&L (`080`, `/finanzas/*`, tab Rentabilidad, `verificar-finanzas.ps1`) |
| 2026-08-06 | **Prompt 09 doc** — `archivo/auditorias-prompts/AUDITORIA_INFRA.md` (Nginx ausente, R2/Storage, Tunnel WiFi, SSL CF, disco); § Infra en problemas vigentes |
| 2026-08-06 | **Prompt 08 doc** — `archivo/auditorias-prompts/AUDITORIA_DOCKER_ENV.md` (compose, secretos, HC, restart, logs); § Docker/env en problemas vigentes |
| 2026-08-06 | **Prompt 07 doc** — `archivo/auditorias-prompts/AUDITORIA_BD_SUPABASE.md` (RLS deny-all, índices, FKs, N+1, backups OPS-02); § BD en problemas vigentes |
| 2026-08-06 | **Prompt 06 doc** — `archivo/auditorias-prompts/AUDITORIA_RBAC.md` (RBAC-\* IDOR caja + mesero cobro + guards); § RBAC en problemas vigentes |
| 2026-08-06 | **Prompt 05 doc** — `archivo/auditorias-prompts/AUDITORIA_AUTH_JWT.md` (AUTH-FLOW/EXP/REV/STORE/OTP + AUTH-FIX-01…06); § Auth/JWT en problemas vigentes |
| 2026-08-05 | **Prompt 04 doc** — `archivo/auditorias-prompts/AUDITORIA_APIS_REST.md` (API-HTTP/VAL/PAGE/IDEM/FMT + API-FIX-01…06); § APIs REST en problemas vigentes |
| 2026-08-05 | **Prompt 03 doc** — `archivo/auditorias-prompts/AUDITORIA_FLUTTER_ESTRUCTURA.md` (FL-\* estado/widgets/leaks/nav/API + FL-FIX-01…07); § Flutter estructura en problemas vigentes |
| 2026-08-05 | **Prompt 02 doc** — `archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md` (BN-\* módulos/controllers/DTOs/excepciones/pipes + BN-FIX-01…06); § Backend NestJS en problemas vigentes |
| 2026-08-05 | **Prompt 01 doc** — `archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md` (AQ-\* duplicación/ciclos/SOLID/acoplamiento/escala/nombres + AQ-FIX-01…07); § Arquitectura/calidad en problemas vigentes |
| 2026-08-04 | **UX checkout cliente** — AppBar/chips/campos/CTA ink; tip; resumen densificado |
| 2026-08-04 | **Carrito detalle** — tap desglose (incluye/extras), swipe borrar, Vaciar; snapshot línea |
| 2026-08-04 | **Icono app** — `assets/logo_foody.png` en APK Android, Windows `.ico`, PWA/web |
| 2026-08-04 | **Icono Foody** — `assets/foody.png` en APK Android, Windows `.ico`, PWA/web (favicon + Icon-192/512 + manifest) |
| 2026-08-04 | **UX carrito cliente** — AppBar/pasos/cards/CTA ink; FoodyPasosPedido neutro |
| 2026-08-04 | **UX menú cliente** — ink + tip pedido, + rebote, snackbar Ver, sheets Analítica |
| 2026-08-04 | **UX sucursales cliente** — AppBar/cards Analítica, CTA Ver menú ink; sede única intacta |
| 2026-08-04 | **Estados premium** — hold oculta chrome, swipe-down cierra, tiempo `created_at` |
| 2026-08-04 | **UX home lugares** — AppBar/nav/cards/estados ink; placeholders sin arcoíris |
| 2026-08-04 | **UX elegir ciudad** — header denso ink, tiles Analítica; preferencia/FCM intactos |
| 2026-08-04 | **UX splash** — canvas neutro Analítica (sin naranja+teal); logo en card; arranque intacto |
| 2026-08-04 | **UX registro repartidor** — Analítica/ink + pantalla espera |
| 2026-08-04 | **UX auth** — registro restaurante + login repartidor Analítica/ink; `AuthFormEstilo` compartido |
| 2026-08-04 | **UX login staff** — sin AppBar naranja; card Analítica, CTA ink, demo colapsable; OAuth/auth intactos |
| 2026-08-04 | **UX chrome panel** — sidebar oscuro activo neutro (sin naranja); AppBar/sede/iconos ink + canvas Analítica; rutas intactas |
| 2026-08-04 | **UX Pedidos** — kanban/grid Analítica: KPIs Activos/Total, chips/tabs ink, cards franja urgencia + CTA ink (Listo verde); Realtime/API intactos |
| 2026-08-04 | **UX KDS** — tickets altura contenido, urgencia franja+tiempo real, Listo primario, Todo listo, grid Wrap responsive |
| 2026-08-04 | **UX Repartidores** — KPIs, config≠operación, liquidar primario, dual ≥980, diálogo dispose seguro; no solo tokens |
| 2026-08-04 | **UX Zonas domicilio** — layout dual ≥980, mapa con leyenda+ubicación, edición con presets km/precio, timeline cerca→lejos, atajos vacío; no solo tokens |
| 2026-08-04 | **UI Zonas domicilio** — tokens Analítica, mapa + anillos densos, CTA ink, FoodyDialogo; lógica intacta |
| 2026-08-04 | **UI Mis sucursales** — tokens Analítica, marca + sedes densas, CTA ink, FoodyDialogo; lógica intacta |
| 2026-08-04 | **Escanear mesa UX** — Analítica + Pegar + banner sesión mesa + linterna/haptic; sin API |
| 2026-08-04 | **Historial cliente + Google** — `079` auth_uid; `POST /dispositivos/vincular-auth`; `GET /pedidos/mios` con Bearer; Mis pedidos + Seguimiento Analítica; script `verificar-historial-cliente-auth.ps1` |
| 2026-08-04 | **UI Horarios** — tokens Analítica, resumen cliente neutro, cards densas + switch ink, FoodyDialogo; lógica intacta |
| 2026-08-04 | **UI Usuarios** — tokens Analítica, cards densas + badges rol, CTA/switch ink, FoodyDialogo; lógica staff intacta |
| 2026-08-04 | **UI Alertas** — tokens Analítica, chip/CTA ink, cards + badges tipo/nivel (sin slugs), vacío/error guiados; lógica intacta |
| 2026-08-04 | **Mesas polish** — cards minimal (barra/punto), KPIs neutros, `FoodyDialogo` en modales cobro/comensal/cuenta |
| 2026-08-04 | **UI Mesas piso** — cards táctiles + CTA, filtros KPI, orden urgencia QR, sheet cuenta densificado; lógica intacta |
| 2026-08-04 | **UI Caja** — tokens Analítica, apertura ink, turno activo + movimientos/CxC laterales; lógica intacta |
| 2026-08-04 | **UI Nuevo pedido** — tokens Analítica, chips/toggle ink, cards neutras, carrito + confirmar; lógica POS intacta |
| 2026-08-04 | **UI Promociones** — tokens Analítica, vacío guiado, cards densas + badges, FAB ink; sin cambios API |
| 2026-08-04 | **UI Plan y pagos** — tokens Analítica, header denso, suscripción semántica, planes 3 col ≥980, historial; Wompi intacto |
| 2026-08-04 | **UI Facturación** — tokens Analítica, config en secciones (emisor/IVA/DIAN), facturas densas + estados semánticos, responsive; sin cambios API |
| 2026-08-03 | **UI Menú admin** — tokens Analítica, filtros sin receta/margen/no disponible, cards densas + riesgo, tabs; sin cambios API |
| 2026-08-03 | **UI Costos y márgenes** — tokens Analítica, riesgo (sin receta/bajo margen), editor más guiado, tabs claros, responsive; sin cambios API |
| 2026-08-03 | **UI Insumos** — misma línea visual que Analítica/Reportes (tokens, banner riesgo, cards densas + responsive); sin cambios API |
| 2026-08-03 | **UI Reportes** — misma línea visual que Analítica (header, KPIs, surfaces, tendencia, skeletons); sin cambios API |
| 2026-08-03 | **UI Centro de Inteligencia** — rediseño solo presentación (`lib/features/analitica/`): header hero, KPIs+sparklines, insights, skeletons, charts premium, filtros sheet; sin cambios API/lógica |
| 2026-08-01 | **OPT-04/05** — paginación cerrados-hoy + movimientos inventario + UI «Cargar más»; poll RT 90/45s; KDS/domi independiente; techo auditoría 500; `verificar-paginacion-ops.ps1` OK |
| 2026-08-01 | **OPS lote 1** — backup.sh+retención (`BACKUPS_FOODY.md`); FCM-02 (`078` intentos/abandonada); STOR-01 limpieza estados; `verificar-ops-recomendaciones.ps1` OK |
| 2026-08-01 | **Gap recomendaciones** — `docs/RECOMENDACIONES_IMPLEMENTACION.md`: 12✅ / 6🟡 / 8⏳ / 3📅; specs OPS-01/02, FCM-02, STOR-01; corregido «caché menú ausente» |
| 2026-08-01 | **Estados WhatsApp** — 1 anillo por restaurante; viewer multi-clip; video ≤30s (`077`, `POST /almacenamiento/video`, `tipo_media`); admin Foto/Video |
| 2026-07-31 | **DX puertos Flutter** — `flutter-run-flavor.ps1 -LiberarPuerto`; regla `foody-riesgos-produccion.mdc` (dartvm≠prod); doc ESTRATEGIA/ENTORNO |
| 2026-08-01 | **Toppings ≠ bebidas** — toppings solo extras (`PUT /productos/:id/toppings` + checkboxes admin); bebidas siguen producto; migr. `076` borra espejo topping→producto |
| 2026-08-01 | **Extras = productos** — migr. `075` espejo topping/bebida→producto; sheet/cajero agregan líneas de producto (no adicionales); crear topping/bebida publica en menú |
| 2026-07-31 | **Upsell menú** — cards horizontales toppings/bebidas en detalle producto/combo; hint admin Bebidas (extra ≠ producto); vacío categoría Bebidas; migr. `074` relink extras demo |
| 2026-07-31 | **Stories polish + DELETE** — CTA oval transparente; media `contain`; anillo gris visto local; nav CTA vía `appNavigatorKey`; `DELETE /promociones/:id` + admin Eliminar |
| 2026-07-31 | **Cliente premium + estados** — stories WhatsApp (24h, producto, auto-avance); AppBar/cards lugares; nav sede única estable; `073` + marca `PATCH /sucursales/marca`; admin logo/portada y producto en estado |
| 2026-07-31 | **Cliente UX oleada A** — CL-01…08 implementados (staff oculto, agotado, sticky carrito, pills, subtotal extras, stories CTA, FoodyEstadoUi, checkout inline); doc auditoría actualizado |
| 2026-07-31 | **Auditoría UX cliente** — `docs/frontend/FRONTEND_AUDITORIA_UX_CLIENTE.md` (todas las ventanas + promos); backlog CL-01…23; sin código |
| 2026-07-31 | **F0 UI** — Docker+API; Flujo 12/12; Roles 38/38 (aprobar QR=mesero); guion `qa-sesiones/2026-07-31-f0-ui.md`; Chrome `:8080`/`:8081` listos |
| 2026-07-31 | **Pedidos Fase 1 verify-docs** — `verificar-pedidos-kanban.ps1` OK; analyze pedidos/kanban sin errores; plan columnas/cards/modal/domicilio/cerrados confirmado en código |
| 2026-07-31 | **Coherencia pedidos↔BI** — `SQL_VENTA_LINEA_ITEM` en analítica/reportes/dashboard/costeo/cuenta mesa/cobro; filtros analítica con estados QR/confirmado/rechazado; dashboard activos incluye `pagando`/`asignado`; `verificar-coherencia-pedidos-analitica.ps1` |
| 2026-07-31 | **POS coherencia** — bebidas en menú crear pedido; combos admin/POS con toppings+bebidas; cambiar producto estable (DELETE limpia FKs); `verificar-pos-menu-cambiar.ps1` |
| 2026-07-30 | **Pedidos Fase 2** — `PATCH /pedidos/:id/items/:itemId`; UI Editar/Cambiar producto; `topping_ids` en resumen; DELETE reimprime; `verificar-pedido-items.ps1` |
| 2026-07-30 | **Pedidos CTA** — confirmar QR con mesero (`mesera_id`), modal UI, FCM mesero; comanda `Copia N` (migr. 071); CTA Listo/A cobrar/En camino en tarjeta |
| 2026-07-30 | **Pedidos UX** — default tabs+grid (sin scroll lateral); card cliente/hora/#; `POST /domiciliarios-planta/reasignar` + UI Cambiar; script kanban OK |
| 2026-07-30 | **UI Pedidos Fase 1** — columnas por canal, cards+pills, modal detalle, `items_resumen`, `cerrados-hoy`, POS domicilio real; script `verificar-pedidos-kanban.ps1` |
| 2026-07-30 | **UI Analítica premium** — Resumen dashboard (KPIs+charts+tabla pedidos+pills); `GET /analitica/pedidos-recientes`; charts tabs; FoodyBreakpoints; `verificar-analitica` OK |
| 2026-07-30 | **Cierre 🟡 parciales** — propina POS llevar + CxC al «Pendiente»; MASTER: menú/reportes/multi/usuarios/super/analítica/panel → ✅; producción §20 alinea CI/RLS |
| 2026-07-30 | **UX/responsive operación** — `FoodyBreakpoints` (split 720); cobro mesa compacto; mesas 4/5 cols; RS-20 ✅ |
| 2026-07-30 | **Analítica Fase 3** — lista alertas en resumen; Δ prep + caída categoría en riesgo/cron; UI; script OK |
| 2026-07-30 | **Analítica Fase 2** — `GET /analitica/export` CSV; comparativa KPIs en tabs (no resumen); Flutter export CSV + rango comparar custom; script verificar ampliado |
| 2026-07-30 | **QA sesión completa Analítica** — Supabase-db + migr.070 + API :3000; `verificar-analitica.ps1` OK; probe shapes Q1–Q3 + inventario fix `bajoMinimo` params; reportes-export OK; analyze Flutter OK. Regla nueva `foody-sesion-completa-antes-entregar.mdc` |
| 2026-07-29 | **Analítica Fase 1** — filtros combinables API+UI, gráficas, export PDF Análisis, `duracion_estado_anterior_seg`, migr. 070 distancia_km, alertas `producto_sin_venta`/`mesero_cancelacion_alta`; plan doc actualizado. QA API viva pendiente (Supabase down) |
| 2026-07-29 | **Plan Analítica/Reportes** — `docs/PLAN_COMPLETAR_ANALITICA_REPORTES.md` (filtros solo Análisis, datos duración/distancia/segmento cliente, export híbrido, 3 fases); §21 → 🟡 plan documentado; sin código |
| 2026-07-31 | **F0 UI** — Docker+API arrancados; Flujo 12/12; Roles 38/38 (fix aprobar QR=mesero); guion `qa-sesiones/2026-07-31-f0-ui.md`; Chrome `:8080`/`:8081` |
| 2026-07-26 | **NAV-DP** — Domi planta: FCM+redirect, cobro 1 sheet, sheet arrastrable, split ≥720, «Mi ruta», saldo liquidar, copy web; doc `FRONTEND_AUDITORIA_NAV_DOMICILIARIO.md` |
| 2026-07-26 | **F0 QA** — FlujoApi 12/12 + RolesApi 38/38 + CI; sesión `docs/archivo/qa-sesiones/2026-07-26.md`; click-through UI pendiente |
| 2026-07-26 | **NAV-ADM2** — deep-link `pedido_id`/`ingrediente_id`, kanban móvil, alertas→pedido/insumo/costos, cabeceras operación, cross-links Reportes↔Analítica/KDS/promos/domi/sucursales/usuarios; doc `FRONTEND_AUDITORIA_NAV_ADMIN2.md` (22/24; 06/24 diferidos) |
| 2026-07-26 | **Multi-negocio (docs)** — paquete `docs/multinegocio/` + hub `PLAN_MULTINEGOCIO_FOODY.md`; fila en § Documentado; sin código |
| 2026-06-28 | **P2-17** — editar rol/nombre/sucursal staff; `GET /usuarios/catalogo-roles`, `PATCH /usuarios/:id`; UI permisos read-only; `verificar-usuarios-editar.ps1` |
| 2026-06-28 | **P2-16** — export PDF/CSV reportes admin; script `verificar-reportes-export.ps1` |

---

# Mantenimiento de este documento

**Al cerrar cualquier tarea:**

1. Mover ítem entre ✅ / 🟡 / 🔴 en la sección correspondiente.
2. Actualizar ficha del módulo (%, faltante).
3. Si resuelves un 🟣 → mover a 🟢 con fecha.
4. Ajustar contadores del resumen general.
5. Añadir viñeta al changelog.
6. Actualizar checkbox en `ROADMAP_TERMINAR_FOODY.md` (checklist operativo).

**No duplicar aquí:** variables de entorno, UUIDs seed, listado completo endpoints — usar `docs/AVANCE_PROYECTO.md` § Referencias persistentes o `INFRAESTRUCTURA/endpoints_api_foody.md` hasta migrarlos a anexo único.

---

# Documentos que pueden archivarse

**Hecho 2026-06-28** — ver `docs/archivo/README.md`.

| Documento | Ubicación actual |
|-----------|------------------|
| `ANALISIS_SISTEMA.md` | `docs/archivo/` |
| `PLAN_COMPLETAR_FOODY.md` | `docs/archivo/` |
| `auditoria_flujos_foody-antigravity.md` | `docs/archivo/` |
| `walkthrough-antigravity.md` | `docs/archivo/` |
| `implementation_plan-antigravity.md` | `docs/archivo/` |
| `inventario_sistema_foody-antigravity.md` | `docs/archivo/` |
| `AUDITORIA_FLUJOS_E2E.md` | `docs/archivo/auditorias-prompts/` |

### Reducir rol (mantener como referencia, no como status)

| Documento | Rol restante |
|-----------|--------------|
| `docs/AVANCE_PROYECTO.md` | Referencias persistentes (BD, env, endpoints) hasta anexo único |
| `docs/MODULOS_ESTADO.md` | Plantilla por módulo — **sincronizar desde MASTER** o deprecar |
| `docs/REGISTRO_IRREGULARIDADES_FLUJOS.md` | Solo mientras quede R5 abierto; luego archivar |
| `docs/ESCENARIOS_NEGOCIO_FOODY.md` | Catálogo QA tras P2-21/22 |
| `archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md` | Informe arquitectura jun-12 (mayoría resuelto) |
| `archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md` | **Prompt 01 (2026-08-05)** — deuda estructural AQ-\*; mantener vivo al cerrar fixes |
| `archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md` | **Prompt 02 (2026-08-05)** — NestJS módulos/controllers/DTOs/excepciones/pipes (BN-\*) |
| `archivo/auditorias-prompts/AUDITORIA_FLUTTER_ESTRUCTURA.md` | **Prompt 03 (2026-08-05)** — Flutter estado/widgets/leaks/nav/API (FL-\*) |
| `archivo/auditorias-prompts/AUDITORIA_APIS_REST.md` | **Prompt 04 (2026-08-05)** — contrato REST HTTP/validación/paginación/idempotencia (API-\*) |
| `archivo/auditorias-prompts/AUDITORIA_AUTH_JWT.md` | **Prompt 05 (2026-08-06)** — auth/JWT login/refresh/revocación/storage/OTP (AUTH-\*) |
| `archivo/auditorias-prompts/AUDITORIA_RBAC.md` | **Prompt 06 (2026-08-06)** — roles/permisos, mesero escalada, IDOR multi-tenant (RBAC-\*) |
| `archivo/auditorias-prompts/AUDITORIA_BD_SUPABASE.md` | **Prompt 07 (2026-08-06)** — RLS, índices, FKs, N+1, backups (BD-\*) |
| `archivo/auditorias-prompts/AUDITORIA_DOCKER_ENV.md` | **Prompt 08 (2026-08-06)** — Docker compose, secretos, healthchecks, logs (DK-\*) |
| `archivo/auditorias-prompts/AUDITORIA_INFRA.md` | **Prompt 09 (2026-08-06)** — Hetzner/Nginx/Cloudflare Tunnel/R2/disco (INF-\*) |
| `archivo/auditorias-prompts/AUDITORIA_REPORTES.md` | **Prompt 20 (2026-08-06)** — Reportes/analítica vs BD + alertas (REP-/ANA-/ALT-\*) |
| `archivo/auditorias-prompts/AUDITORIA_DASHBOARD.md` | **Prompt 21 (2026-08-06)** — Dashboard frescura/huérfanos/consistencia (DASH-\*) |
| `archivo/auditorias-prompts/AUDITORIA_CONFIGURACION.md` | **Prompt 22 (2026-08-06)** — Config restaurante BD↔UI/propagación (CFG-\*; CFG-GLOBAL-DEAD) |
| `archivo/auditorias-prompts/AUDITORIA_PERF_BACKEND.md` | **Prompt 23 (2026-08-06)** — Performance backend: EXPLAIN, caché, carga (PERF-\*) |
| `archivo/auditorias-prompts/AUDITORIA_PERF_FLUTTER.md` | **Prompt 24 (2026-08-06)** — Performance Flutter: listas, memoria 8h, imágenes (PERF-FL-\*) |
| `archivo/auditorias-prompts/AUDITORIA_OWASP.md` | **Prompt 25 (2026-08-06)** — OWASP: injection, BAC, secretos, rate limit, RLS (SEC-\*) |
| `archivo/auditorias-prompts/AUDITORIA_ESTRES_CONCURRENCIA.md` | **Prompt 26 (2026-08-06)** — Estrés/concurrencia: multi-sede, races, carga (CONC-\*) |
| `archivo/auditorias-prompts/AUDITORIA_FUZZ_INPUTS.md` | **Prompt 27 (2026-08-06)** — Fuzz inputs: inválidos/largos/stack (FUZZ-\*) |
| `archivo/auditorias-prompts/AUDITORIA_FUNCIONALIDAD_HUERFANA.md` | **Prompt 28 (2026-08-06)** — Funcionalidad huérfana API↔UI↔BD (HUER-\*) |
| `archivo/auditorias-prompts/AUDITORIA_CONSISTENCIA_MODULOS.md` | **Prompt 29 (2026-08-06)** — Consistencia entre módulos (CONS-\*) |
| `archivo/auditorias-prompts/AUDITORIA_CASOS_VIERNES.md` | **Prompt 30 (2026-08-06)** — Casos viernes alta demanda (VIE-\*) |
| `archivo/auditorias-prompts/AUDITORIA_CAPACITY_PLANNING.md` | **Prompt 31 (2026-08-06)** — Capacity planning 100→10k (CAP-\*) |
| `archivo/auditorias-prompts/AUDITORIA_VIRAL_SPIKE.md` | **Prompt 32 (2026-08-06)** — Spike viral registros D1–D4 (VIRAL-\*) |
| `archivo/auditorias-prompts/AUDITORIA_E2E_AUTOMATIZADO.md` | **Prompt 33 (2026-08-06)** — E2E Jest + Flutter 5 flujos + VIE/CONS (E2E-\*) |
| `archivo/auditorias-prompts/AUDITORIA_INFRA_EXTREMOS.md` | **Prompt 34 (2026-08-06)** — Timeout/doble submit/API caída/resync (INFRA-EXT-\*) |
| `docs/INFORME_MAESTRO_FOODY.md` | **Prompt 35 (2026-08-06)** — Consolidación hallazgos + plan F0–F8 + § escala/viral |

### Mantener sin archivar (spec / procedimiento, no status)

- `INFRAESTRUCTURA/*` — especificación objetivo
- `MEMORIA.md` — contexto permanente
- `docs/ENTORNO_LOCAL.md`, `docs/MOVIL_RED_LOCAL.md` — operación dev
- `docs/ROADMAP_TERMINAR_FOODY.md` — checklist accionable P0–P3
- `docs/frontend/` — suite `FRONTEND_*.md` (roadmap, **FRONTEND_AUDITORIA_NAV_ADMIN.md** + **ADMIN2**, NAV-MC/CJ/CK/MS, auditorías UX/diseño/producto/arquitectura, F0–F10)
- `docs/MODULO_*.md`, `docs/MULTI_SUCURSAL.md`, `docs/FLUJO_*.md` — diseño funcional
- `docs/WOMPI_PRODUCCION.md`, `docs/IMPRESION_RESTAURANTE.md`, `docs/FCM_FOODY.md` — guías integración
- `AGENTS.md` — instrucciones agentes (apuntar a MASTER_STATUS como status)

---

*Fin del documento maestro.*
