# Foody — estado por módulo (qué hay / qué falta)

> **Resumen por módulo — fuente oficial de estado:** [`MASTER_STATUS.md`](MASTER_STATUS.md) (§ Módulos).  
> **No duplicar fixes aquí:** al cerrar un hallazgo, actualizar MASTER + [`INFORME_MAESTRO_FOODY.md`](INFORME_MAESTRO_FOODY.md). Este fichero es mapa Hecho/Falta por dominio; puede ir desfasado respecto a MASTER.
>
> - Spec objetivo: `INFRAESTRUCTURA/GUIA_DESARROLLO_FOODY_CURSOR.md`
> - Regla agentes: actualizar **MASTER_STATUS** + changelog en `AVANCE_PROYECTO.md`

**Última actualización:** 2026-08-06 — §23 Finanzas (gastos fijos + nómina + P&L).

**Próximo paso:** **F0** de [`INFORME_MAESTRO_FOODY.md`](INFORME_MAESTRO_FOODY.md) · P0-05 VPS.

---

## Cómo leer y mantener

| Símbolo | Significado |
|---------|-------------|
| ✅ | Listo para uso en dev (flujo principal cubierto) |
| 🟡 | Parcial — funciona pero falta spec, UX o integración |
| ⏳ | Pendiente o muy incompleto |
| 🚫 | Pospuesto por acuerdo (no implementar salvo petición explícita) |

**Al completar algo:** cambia el estado del módulo, mueve ítems de *Falta* → *Hecho*, añade fecha en *Últimos cambios* (abajo) y una viñeta en `AVANCE_PROYECTO.md`.

---

## ⚠️ Falta prioritario (siempre visible)

| # | Tema | Módulo | Estado |
|---|------|--------|--------|
| 1 | Impresión física `python-escpos` + agente local | Cocina / Impresión | 🟡 Modo archivo OK; falta QA hardware (P0-01) |
| 2 | Health check Realtime (`SUPABASE_*`) | Infra | ✅ P4.2 |
| 3 | Deep link FCM web | FCM | ✅ `notificationclick` SW + listener Dart |
| 4 | DIAN / factura electrónica real | Facturación | 🚫 pospuesto |
| 5 | Dashboard consolidado multi-sede | Multi-sucursal | ✅ |
| 6 | Scripts E2E extendidos (domi, inventario→menú) | QA | ✅ P5 |
| 7 | Centro de Análisis (BI) | Analítica | ✅ P1-08 |
| 8 | Self-service: auto-registro, plan gratis, login Google, cobro Wompi | Suscripciones / Onboarding | 🟡 F1–F7 hecho; desplegar webhook prod en VPS |

---

## Resumen global

| Área | % aprox. | Comentario |
|------|----------|------------|
| Operación diaria (pedidos, mesas, caja, cocina, inventario) | ~80% | Usable en demo; faltan impresión y pulidos |
| Cliente final | ~90% | Flujo completo; escaneo QR cámara ✅ |
| Corporativo / multi-sede | ~85% | Dashboard cadena + rol `gerente_cadena` ✅ |
| Facturación legal / DIAN | ~30% | Solo borrador HTML |
| Producción / infra | ~75% | RLS 064 ✅, CI 5/5, Docker build ✅; falta VPS |

---

## 1. Cliente (app sin login)

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Ciudad → restaurante → menú → carrito → checkout → seguimiento; mesa QR; **escaneo QR cámara** (`/cliente/escanear-qr`, `mobile_scanner`); toppings/combos; domicilio con mapa OSM; mis pedidos por `device_id`; promos con código; stories en menú; **`cached_network_image`** en cards del menú |
| **Falta** | — |
| **Prioridad falta** | — |

---

## 2. Pedidos y checkout

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | POST transacción atómica; IVA; zonas domicilio; stock al confirmar; descuentos; cancelación; cobro mesa/caja; pago mixto; Kanban + Realtime; **flujo estados v2** (`docs/FLUJO_ESTADOS_PEDIDOS.md`): sin columna Confirmado, `pagando→entregado` |
| **Falta** | DIAN; impresión auto; scripts E2E P5 |
| **Prioridad falta** | Media (DIAN pospuesto) |

---

## 3. Mesas y QR

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial / ~90% |
| **Hecho** | Grid, CRUD, QR, transferir, unir, reservar; turno; aprobación; split cobro; pedido público QR |
| **Hecho** | … + precio server-side + token permanente verificados (`verificar-qr-cliente.ps1`, Prompt 17) |
| **Falta** | Autoservicio sin mesero; exigir `mesa_id` en QR; auto-rechazo continuo; rotar token |
| **Audit** | `docs/archivo/auditorias-prompts/AUDITORIA_CLIENTES_QR.md` · `docs/archivo/auditorias-prompts/AUDITORIA_MESEROS_MESAS.md` |
| **Prioridad falta** | Media (QR-MESA-ID-01 / QR-AUTO-01 si producto lo pide) |

---

## 4. Panel admin y multi-sucursal

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado (gaps Prompt 21–22 documentados) |
| **Hecho** | Sidebar por permisos y plan; selector sede; scope API; **`GET /dashboard/consolidado`** + `DashboardConsolidadoWidget`; **`GET /dashboard/graficos`** + gráficos fl_chart en inicio; rol **`gerente_cadena`** (migr. `060`, `roles-food.ts`, UI staff); Centro de operación (KPIs + acordeones riesgo); config: horarios/zonas/marca/cocinas/fiado |
| **Falta** | Affordance favoritos (menor); frescura UI (DASH-*); tap Ventas→Reportes; TZ Bogota; **PATCH sede** + márgenes sede UI (CFG-*) |
| **Audit** | `docs/archivo/auditorias-prompts/AUDITORIA_DASHBOARD.md` · `docs/archivo/auditorias-prompts/AUDITORIA_CONFIGURACION.md` · scripts verificar-dashboard-general / verificar-config-restaurante / verificar-f3-confianza |
| **Archivos** | `lib/features/admin/presentation/panel_restaurante_screen.dart`, `docs/MULTI_SUCURSAL.md`, `lib/core/layout/foody_breakpoints.dart` |
| **Prioridad falta** | Media (PATCH sede) / Baja (favoritos) — CFG-GLOBAL ✅ F3 · DASH-TZ ✅ F6 |

---

## 5. Caja

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Abrir/cerrar; movimientos; gastos de turno; fiados; cobro mixto; devolución; arqueo ciego; cuadre en reportes; **CxC**; **F1:** unique caja + idempotency cobro (`081`); **F6:** índices `083` + movimientos paginados |
| **Falta** | — (egresos fijos/nómina → módulo Finanzas) |
| **Archivos** | `foody_backend/src/modulos/caja/`, `lib/features/caja/` |
| **Prioridad falta** | Baja |

---

## 5b. Finanzas (control + rentabilidad)

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Costos fijos; empleados; libro gastos; P&L; **resumen dueño** (mes vs anterior, por pagar, consejos); pago editable; CTA→Rentabilidad; permiso `ver_finanzas`; `verificar-finanzas.ps1` |
| **Falta** | Export P&L CSV; smoke UI dispositivo; nómina legal / SSS 🚫 |
| **Archivos** | `foody_backend/src/modulos/finanzas/`, `lib/features/finanzas/`, migr. `080`, **`docs/MODULO_FINANZAS.md`** |
| **Prioridad falta** | Baja |

---

## 6. Menú / catálogo admin

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | CRUD productos/toppings/bebidas/combos; **bebidas→producto** en menú; **toppings por plato** (checkboxes admin + `PUT …/toppings`); upsell sheet mixto; costeo P2-14 |
| **Falta** | — |
| **Prioridad falta** | — |

---

## 7. Cocina / KDS / impresoras

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | CRUD cocinas e impresoras; KDS por ítem; sonido; alerta >20 min; KDS respeta sede; estado pedido por ítems; **prioridad Urgente** (API+UI KDS, F7) |
| **Falta** | QA en impresora térmica real; tickets automáticos al confirmar (cola ya existe) |
| **Archivos** | `lib/features/cocinas/`, `foody_python_printer/`, `foody_backend/src/modulos/impresion/` |
| **Prioridad falta** | **Alta** |

---

## 8. Inventario

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Insumos, compras, ajustes, conteo físico; recetas; subrecetas; traslados entre sedes; vista hermanas (solo lectura); alertas stock bajo; impacto stock por plato |
| **Hecho** | … + **ajuste stock → menú** (`CatalogoDisponibilidadService`, Realtime) |
| **Hecho** | … + **compra y conteo físico → menú** (mismo hook tras `registrarCompra` / `cerrarConteo`) |
| **Hecho** | … + **descuento automático al cocina** (`stock_descontado`); propagación 3 capas verificada (`verificar-inventario-ciclo.ps1`) |
| **Hecho** | … + **AQ-DUP-01** write-path único (`StockMovimientoService`) incl. producción lote |
| **Falta** | Quién en API/UI de movimientos (INV-AUD-01); FCM opcional stock bajo; alerta tras ajuste manual |
| **Audit** | `docs/archivo/auditorias-prompts/AUDITORIA_INVENTARIO.md` (Prompt 14) |

---

## 9. Costeo industrial (KYG)

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Motor costos, merma, empaques domicilio; ítems incluidos; tab Costos; margen; precio sugerido llevar; lista de mercado; subrecetas CRUD; producción en lote; simulador popularidad ABC mesa/domicilio; **editor receta con empaques/subrecetas (P2-14)**; **recetas en bebidas/toppings con costeo + stock al vender (068)** |
| **Falta** | Import Excel KYG (solo referencia fórmulas) 🚫 pospuesto |
| **Archivos** | `docs/MODULO_COSTEO.md`, `foody_backend/src/modulos/costeo/`, `scripts/verificar-receta-extras.ps1` |
| **Prioridad falta** | Baja (Fase 2–3) |

---

## 10. Domiciliarios

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Planta: asignación Kanban, app mapa+panel Activos, chip GPS; independientes: dispatch, ofertas 60 s, UI inDriver; cobro al entregar; auto-dispatch |
| **Hecho** | … + ciclo completo + cancel mid-ruta admin verificado (`verificar-domicilios-ciclo.ps1`, Prompt 16) |
| **Falta** | Cancel no libera sesión indep / ofertas; evidencia foto; E2E hardware; 3 docs obligatorios |
| **Audit** | `docs/archivo/auditorias-prompts/AUDITORIA_DOMICILIOS.md` |
| **Prioridad falta** | Media (DOM-CANCEL-INDEP-01) / Baja resto |

---

## 11. Zonas / mapas / horarios

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Anillos km/precio; mapa OSM admin; cotización API checkout; horarios sucursal CRUD; geografía Photon (sin Google Maps) |
| **Falta** | — |
| **Archivos** | `lib/features/zonas/`, `lib/core/mapas/`, `foody_backend/src/modulos/zonas/` |
| **Prioridad falta** | — |

---

## 12. Promociones

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado / ~90% |
| **Hecho** | Stories, código checkout, snapshot descuento al crear; 1 promo/pedido; precio ítem congelado |
| **Hecho** | … + desactivar/cambio precio/apilado verificados (`verificar-promociones-precios.ps1`, Prompt 18) |
| **Falta** | Anti-stack combo↔promo (PROMO-STACK-01); DELETE FK; descuento manual limpia `promocion_id` |
| **Audit** | `docs/archivo/auditorias-prompts/AUDITORIA_PROMOCIONES.md` |

---

## 13. Reportes

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Financiero, productos, pedidos; cuadre caja; **export PDF + CSV**; cifras = BD cruda (`verificar-reportes-analitica.ps1`) |
| **Falta** | Filtros ricos (en Analítica); smoke visual dispositivo |
| **Archivos** | `lib/features/reportes/`, `foody_backend/src/modulos/reportes/` |
| **Audit** | `docs/archivo/auditorias-prompts/AUDITORIA_REPORTES.md` |
| **Prioridad falta** | Baja |

---

## 14. Facturación

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 ~30% · 🚫 DIAN/MATIAS pausados (X-01) |
| **Hecho** | Config, borrador, emitir local, HTML, anular soft; total=pedido (`verificar-facturacion-ciclo.ps1`) |
| **Falta** | Cliente MATIAS/FE, cola/reintentos, CUFE/XML, nota crédito real, líneas ítems |
| **Falta pospuesta** | Integración DIAN real 🚫 hasta acuerdo comercial |
| **Audit** | `docs/archivo/auditorias-prompts/AUDITORIA_FACTURACION.md` · `docs/FACTURACION_ELECTRONICA_PAUSADA.md` |
| **Prioridad falta** | Baja ahora / Alta al go-live legal |

---

## 15. Alertas

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Listar; marcar revisada; evaluar batch; disparadores evento; umbrales verificados Prompt 20; **FCM** alto/crítico |
| **Falta** | Email crítico (opcional); E2E umbral sintético (ALT-FIX-01) |
| **Archivos** | `lib/features/alertas/`, `docs/ALERTAS_AUTOMATICAS.md` |
| **Audit** | `docs/archivo/auditorias-prompts/AUDITORIA_REPORTES.md` |
| **Prioridad falta** | Baja |

---

## 16. Usuarios staff

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Listar, crear, **editar** (nombre, rol, sucursal, **permisos por usuario**), catálogo + checklist; activar/desactivar; selector sucursal si corporativo; rol **`gerente_cadena`**; sync `domiciliarios_planta`; mig `085` `usuario_permisos` |
| **Falta** | — |
| **Archivos** | `lib/features/usuarios/` · `usuarios.service.ts` · `auth.service.ts` |
| **Prioridad falta** | — |

---

## 17. Super Admin (Foody Control → NOC)

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial — ops base ✅ · **Fase A NOC** 📅 |
| **Hecho** | Panel 7 secciones; restaurantes; planes; límites; cron; usuarios; ciudades; onboarding; docs domi; SuperAdminGuard; PATCH config UI; estadísticas + `suscripciones_por_plan`; PATCH plan/estado |
| **Falta** | [`SUPERADMIN_FOODY_CONTROL.md`](SUPERADMIN_FOODY_CONTROL.md) §3 **Fase A:** home *¿Cómo está Foody?*, KPI Gratis/Pro/Ultra, kill switch freemium, plan+motivo auditado, errores agrupados, asistente reglas. Visión 10 módulos = B/C |
| **Archivos** | `panel_foody_control_screen.dart` · `foody_backend/.../super-admin/` |
| **Prioridad falta** | Alta al lanzar freemium / stores (solo Fase A) |

---

## 18. FCM / notificaciones push

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Cola + cron; eventos pedido/domi; móvil + web recibir; `/prueba` y `/prueba-web`; primer plano web (Notification API); **`notificationclick`** en SW (segundo plano) + `fcm_click_web.dart`; logout desactiva token |
| **Falta** | — |
| **Archivos** | `docs/FCM_FOODY.md`, `foody_backend/src/modulos/notificaciones/`, `lib/core/notificaciones/` |
| **Prioridad falta** | Media |

---

## 19. Impresión Python

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | Cola `impresion_cocina_jobs`; WebSocket agente; **modo archivo** sin hardware; reintentos; `GET /health/impresion`, `GET /impresion/jobs`; migr. `058`; scripts `iniciar-impresora.ps1`, `verificar-impresion.ps1` |
| **Falta** | QA impresora térmica real (red :9100) cuando haya hardware |
| **Archivos** | `foody_python_printer/`, `foody_backend/src/modulos/impresion/` |
| **Prioridad falta** | **Alta** |

---

## 20. Producción / calidad / legacy

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Avanzado |
| **Hecho** | `verificar-ci.ps1` (5 scripts); `verificar-rls.ps1` (migr.064); `verificar-salud.ps1`; `verificar-docker-prod.ps1`; legacy `lib/screens/` eliminado; `GET /health` |
| **Falta** | Deploy VPS (P0-05); `docker compose up` en prod (P3-06) |
| **Archivos** | `docs/PREPARACION_VPS.md`, `docs/MONITOREO_SALUD.md`, `docker-compose.prod.yml` |
| **Prioridad falta** | Alta antes de go-live |

---

## 21. Centro de Análisis (Analítica / BI)

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Endpoints `/analitica/*` + filtros AND + export; KPIs = BD; dashboard Resumen; charts; **tab Rentabilidad**; `verificar-analitica.ps1` + `verificar-reportes-analitica.ps1` |
| **Falta** | Vistas materializadas / XLSX (YAGNI); carga 50k; smoke visual |
| **Archivos** | `foody_backend/src/modulos/analitica/`, `docs/MODULO_ANALITICA_BI.md` |
| **Audit** | `docs/archivo/auditorias-prompts/AUDITORIA_REPORTES.md` |

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial (F1–F7 + recurrente P1-10 en código) |
| **Hecho** | … + **cobro recurrente** (`fuentes_pago`, `POST /pagos/renovar`, cron renovación, UI Mejorar plan); paywall global 403 plan; historial pagos |
| **Falta** | Registrar webhook en dashboard Wompi con dominio prod; `WOMPI_REDIRECT_URL` HTTPS; tokenización tarjeta en primer pago (payment links no siempre guardan fuente — requiere checkout con 3DS en fase posterior) |
| **Por qué falta** | Requiere VPS/dominio público |
| **Cuándo** | Al desplegar API en prod |
| **Archivos** | `docs/WOMPI_PRODUCCION.md`, `lib/features/pagos/`, `foody_backend/src/modulos/pagos/` |
| **Prioridad falta** | Media-alta (habilita crecimiento sin super-admin manual) |

---

1. ⏳ Impresión física (`python-escpos`) — R5 / P0-01
2. ✅ Centro de Análisis — F1–F8 completos
3. ✅ FCM web deep link
4. ✅ Dashboard cadena + rol `gerente_cadena`
5. ✅ Storage imágenes catálogo
6. ✅ GPS domiciliario
7. 🚫 DIAN (cuando haya proveedor FE)
8. ⏳ Sprint 11 producción (RLS, E2E, legacy) — ver P3 en ROADMAP

---

## Últimos cambios (este documento)

| Fecha | Cambio |
|-------|--------|
| 2026-08-07 | **AQ-DUP cierre** — producción costeo → `StockMovimientoService` / `StockMovimientoModule` |
| 2026-08-06 | **UX subrecetas** — modos «al vender» vs «preparar lote»; badge Sin preparar; Prep fuera de alertas insumos |
| 2026-08-06 | **Unidades g↔kg/ml↔L** — selector en subreceta/receta; stock convierte a unidad_base |
| 2026-08-06 | **F7 AQ-DUP-01** — `StockMovimientoService`; write-path inventario/pedidos unificado |
| 2026-08-06 | **Finanzas claro** — resumen mes/pendientes/consejos; pago editable; CTA Rentabilidad |
| 2026-08-06 | **F7 AQ-CYCLE** — hooks dispatch; Pedidos no importa Domiciliarios; flujo domicilio OK |
| 2026-08-06 | **F7 parcial** — ParseUUIDPipe hot; liberarCanal RT×9; KDS Urgente; `verificar-f7-deuda.ps1`; AQ-DUP/CYCLE abiertos |
| 2026-08-06 | **F6** — índices caja mig `083`; paginación movimientos; DASH-TZ Bogota |
| 2026-08-06 | **F5** — BN-EXC Wompi/impresión; `verificar-f5-golive.ps1`; `CHECKLIST_F5_GOLIVE.md` (parcial) |
| 2026-08-06 | **F4** — secure storage JWT; `POST /pedidos/estimar`; checkout total API |
| 2026-08-06 | **F3** — CFG-GLOBAL runtime; HUER-PERM Rentabilidad; RBAC-GUARD anonimizar/FCM; `verificar-f3-confianza.ps1` |
| 2026-08-06 | **§17 NOC** — visión Centro de Operaciones + Fase A esencial en `SUPERADMIN_FOODY_CONTROL.md` |
| 2026-08-06 | **§17 Spec Foody Control** — `SUPERADMIN_FOODY_CONTROL.md` (SAC-*); estado 🟡 mando capacidad |
| 2026-08-06 | **Prompt 22** — config restaurante BD↔UI; `AUDITORIA_CONFIGURACION.md`; CFG-GLOBAL-DEAD |
| 2026-08-06 | **§4 Prompt 21** — dashboard frescura/huérfanos/consistencia; `AUDITORIA_DASHBOARD.md` |
| 2026-08-06 | **§13/15/21 Prompt 20** — cifras reportes=BD; filtros AND; umbrales alertas; `AUDITORIA_REPORTES.md` |
| 2026-08-06 | **§5b Finanzas** — gastos fijos + nómina + P&L; migr. 080; tab Rentabilidad Analítica |
| 2026-07-30 | **UI Analítica premium** — `pedidos-recientes` + dashboard Resumen + charts tabs |
| 2026-07-30 | Cierre 🟡: panel breakpoints; Super P2-20 ✅; POS propina+CxC pendiente; MASTER alineado |
| 2026-07-23 | **Recetas extras** — bebidas/toppings con `receta_id`+costo (068); stock al vender; Costos lista extras; `verificar-receta-extras.ps1` |
| 2026-06-28 | **Reportes P2-16** — export PDF/CSV; `verificar-reportes-export.ps1` |
| 2026-06-28 | **Costeo P2-14** — editor receta empaques/subrecetas; `costo_domicilio` en API; `verificar-receta-empaque.ps1` |
| 2026-06-24 | **Analítica P1-08** — `comparativa-sedes`, tab Sedes, migr. 062, script QA |
| 2026-06-24 | **Analítica P1-05** — `/inventario`, `/domiciliarios`, `/caja`, `/riesgo` |
| 2026-06-24 | **Analítica P1-04** — `/ventas`, `/productos`, `/cocinas` |
| 2026-06-24 | **Analítica P1-03** — `GET /analitica/resumen`; `AnaliticaModule`; migr. `061` |
| 2026-06-24 | **Multi-sede P1-02** — rol `gerente_cadena`; migr. `060`; `roles-food.ts`; UI `roles_foody.dart` |
| 2026-06-24 | **Multi-sede P1-01** — `GET /dashboard/consolidado`; UI cadena en panel admin |
| 2026-06-24 | **Alertas P1-15** — FCM push alto/crítico; `TransactionHooksService` |
| 2026-06-24 | **Seguridad P1-14** — `SuscripcionActivaGuard` auditado; `@OmitirSuscripcionActiva` pagos/auth |
| 2026-06-24 | **Super Admin P1-13** — `SuperAdminGuard` revalida rol y sin tenant en BD para `/super/*` |
| 2026-07-02 | **DOM-UI inDriver** — Flutter mapa+ofertas independiente; planta mapa Activos; `verificar-ofertas-independiente.ps1` |
| 2026-06-24 | **Domiciliarios P1-12** — subida documentos, Foody Control revisión, FCM activación cuenta |
| 2026-06-24 | **Self-service P1-10** — `fuentes_pago`, cobro recurrente Wompi, cron renovación, `POST /pagos/renovar` |
| 2026-06-24 | **Self-service P1-09/P1-11** — paywall global plan; historial pagos en Mejorar plan |
| 2026-06-24 | **Impresión modo archivo** — E2E sin hardware; guía `IMPRESION_RESTAURANTE.md` |
| 2026-06-24 | **Cliente QR cámara** — `EscanearQrMesaScreen`, `mobile_scanner`, ruta `/cliente/escanear-qr` |
| 2026-06-24 | **FCM web deep link** — `notificationclick` en SW + listener `fcm_click_web.dart` |
| 2026-06-24 | **Antigravity + freemium** — límites gratis reducidos; docs `*-antigravity.md`; R1/R4/R10 en backend |
| 2026-06-24 | **Módulo 22 F4** — avisos FCM vencimiento, bloqueo escalonado, banner panel, script verificación |
| 2026-06-24 | **Módulo 22 Self-service F1–F3** — registro público, login Google, plan gratis, UI Flutter |
| 2026-06-20 | **Módulo 21 Analítica/BI** — spec `docs/MODULO_ANALITICA_BI.md`; añadido a backlog y falta prioritario |
| 2026-08-06 | **F2 politica** — cobrar_pedido + cascade stock + mesero estados (`082`) |
| 2026-08-06 | **F1 turno** — unique caja + idempotency cobro (`081`); RT refetch ops |
| 2026-06-19 | **`docs/archivo/auditorias-prompts/AUDITORIA_FLUJOS_E2E.md`** — 9 flujos, R1–R13, plan P0–P5; prioridades §Falta prioritario actualizadas |
| 2026-06-19 | Creación inicial del mapa 20 módulos; prioridades visibles; enlace desde `AVANCE_PROYECTO.md` |
| 2026-06-19 | **Pedidos — flujo estados v2** — Sin columna Confirmado; `pagando→entregado`; doc `FLUJO_ESTADOS_PEDIDOS.md` |
| 2026-06-19 | Módulo 18: FCM web operativo (`/prueba-web`, primer plano Chrome) |

---

## Plantilla para actualizar un módulo

Copia y rellena al cerrar una tarea:

```markdown
### [Nombre módulo] — YYYY-MM-DD
- Estado: ✅ / 🟡 / ⏳
- Completado: ...
- Sigue faltando: ...
- Archivos tocados: ...
```
