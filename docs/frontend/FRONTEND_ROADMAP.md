# Foody — Roadmap Frontend (documento maestro)

### 2026-11-25 — RBAC-CAJA-WRITE-01 · acciones según permiso

Caja recibe los permisos efectivos de sesión: `ver_caja` conserva consulta, `gestionar_caja` habilita CxC/gasto/devolución, y apertura/cierre/retiro usan sus permisos propios. Las acciones no autorizadas se ocultan; quien no puede abrir turno ve un aviso claro. Widget responsive Caja 17/17 y `dart analyze` de Caja, shells Admin/Cajero, Usuarios y test sin incidencias. Publicación y verificación autenticada esperan aplicar migración 094 y activar API.

### 2026-11-25 — DOM-ESTIMATE-LABEL-01 · saldos estimados de independientes

El KPI y las filas de Domiciliarios dejan de llamar “Por pagar” a saldos estimados al aceptar ofertas. La ayuda aclara que pueden incluir pedidos cancelados y no confirman entrega ni pago. Sin cambio de cálculos ni API. Test de Domiciliarios 8/8 en 320/390/820/1440; analyzer limpio. Pendiente publicar y revisar en navegador.

### 2026-11-25 — DASH-STATUS-UX-01 · frescura del Centro de operación

Se reemplazó la línea ambigua «no en vivo» por un estado compacto con hora de captura, actualización parcial o carga en curso e intervalo automático (75 s). Transición con movimiento reducido, tokens existentes y anuncio accesible. Tests dashboard 9/9 (320/390/820/1440 y estados); `dart analyze` focalizado limpio. No cambia consultas ni datos. Queda pendiente QA visual autenticada.

### 2026-11-25 — FIN-GASTO-DATE-01 · Análisis de Caja

Analítica Caja separa “Gastos registrados” de “Egresos de caja”; se aclaró que el libro se filtra por fecha de registro y Rentabilidad/P&L por fecha del gasto. La interfaz explica por qué pueden diferir y advierte que gastos manuales no siempre afectan arqueo. Fórmulas y contratos Nest sin cambio. `analitica_caja_screen_test.dart` 5/5 en 320/390/820/1440; analyzer focalizado limpio. Falta decisión contable sobre conservar ambas fechas o unificarlas; QA visual autenticada general permanece pendiente.

### 2026-11-25 — COC-NODISP-CUSTOMER-01 · Seguimiento de pedido

El flujo Cliente muestra las líneas que Cocina marcó como no disponibles, su cantidad y que el total todavía no se ajusta. Widget responsive 5/5 en 320/390/820/1440 y analyzer focalizado sin incidencias; E2E QA previo Cocina→Seguimiento 8/8 suites, 37/37. Revalidación actual: `cocina.e2e-spec.ts` 7/7 en QA incluye payload con token, nombre/cantidad y bloqueo de despacho; fixture limpiado. API activa PID 10208; Cliente/Equipo/API local/Tunnel HTTP 200 y ambos bundles JS verificados por SHA-256. No altera cobros, catálogo ni estados. Decisión de sustitución/ajuste/reembolso sigue en COC-NODISP-COMMERCE-01, además de la aceptación visual autenticada.

### 2026-11-25 — AR-17 navegación Pedido → Caja

El detalle transmite el ID del pedido a Caja y actualiza el deep link. Caja consulta su historial aunque el turno esté cerrado o no haya turno abierto. Nest valida `ver_caja` y sucursal; el DTO permite combinar `sucursal_id` con paginación; índice parcial 093 instalado solo en QA. Focalizados 320/390/820/1440, analyzer limpio; Flutter global 269 aprobadas/5 omitidas; Nest 50 suites/127 unitarias y build OK; E2E QA 8/8 suites y 37/37 pruebas incluye pago→cierre→consulta histórica. Runtime actual PID 10208; sin sesión, la ruta responde 401 `NO_AUTORIZADO` (registrada y protegida), mientras aceptación autenticada desde Cliente/Equipo y verificación de scope siguen pendientes. El Tunnel permanece activo.

### 2026-11-24 — regresión global y ciclo de vida de vistas

Reverificación global previa al cambio de AR-17: `flutter test --no-pub` pasó 265 pruebas y omitió 5. `flutter analyze --no-pub` terminó con código 1 por 25 issues informativas, sin errores ni warnings; se preservaron los avisos del registro OAuth. Menú ofrece edición de precios directa junto al producto; Cocinas carga estaciones e impresoras en paralelo; detalle de pedido respeta `ver_caja`. Las vistas tienen pruebas responsive de widget, pero el recorrido visual autenticado vista por vista sigue pendiente.

### 2026-11-24 — CLIENT-DOM-CONTACT-01

Checkout muestra validación inline de teléfono de contacto para domicilio (7–15 dígitos), acepta formato internacional, mantiene nombre opcional y no exige teléfono para recoger/mesa/encargo. `validar_telefono_checkout_test.dart` 3/3, `checkout_screen_responsive_test.dart` sin overflow en 320/390/820/1440 px y analyzer focalizado limpio. Backend DTO y E2E QA también verificados; pendiente activación de Nest :3000 antes de probar el flujo en Tunnel.

### 2026-11-24 — PED-POS-CAP-01 / estado vacío de carrito

POS enlaza la cotización con el contrato de capability que exige Nest: registra el dispositivo una vez y adjunta el secreto a `/pedidos/estimar`. Estado vacío ya indica agregar productos y no presenta reintento deshabilitado. Tests del repositorio 5/5, pantalla POS 17/17 y analyzer focalizado sin issues. Equipo autenticado por Tunnel mostró total del servidor de 35.000 COP y habilitó Confirmar; no se creó pedido. Release de Cliente y Equipo publicado; bundles locales y públicos coinciden por SHA-256 y seis endpoints responden HTTP 200.

### 2026-11-24 — GLOB-ERROR-STATE-RESP-01

El estado de error compartido ahora usa una superficie temática con ancho limitado, jerarquía de icono/mensaje y acciones de 48 px; en móvil el reintento ocupa el ancho disponible. Se comprobó claro/oscuro en 320, 390, 820 y 1440 px. `foody_estado_ui_test.dart`: 8/8; analyzer limpio. F5-03 avanza parcialmente: falta migrar y revisar estados ad hoc de cada feature.

### 2026-11-24 — Recuperación de acciones masivas KDS

“Todo listo” y “Volver a cocina” notifican resultados parciales y refrescan el ticket. Si falla la reversión, la vista cambia a Cocina para no ocultar el pedido. Prueba KDS 12/12; regresión Flutter 211/5 omitidas; analyzer limpio. Rebuild Cliente/Equipo, smoke de seis endpoints local/público HTTP 200. Pendiente QA autenticada y dispositivo/impresora real.

### 2026-11-24 — DOM-READ-PARALLEL-01

Resumen de liquidación y registro de domicilios independientes se solicitan ahora en paralelo. Prueba widget mantiene ambas respuestas pendientes y verifica que ambas solicitudes ya comenzaron; no supone tiempo de red específico. Domiciliarios 5/5, Flutter 212/5 omitidas, analyzer limpio. Rebuild publicado, los hashes públicos coinciden con los artefactos locales y seis endpoints responden HTTP 200.

### 2026-11-24 — DOM-STALE-01

Refresh manual/Realtime conserva lo que ya está pintado en vez de reemplazar la pantalla por skeleton. Si la consulta falla, se conservan los datos con error inline y acción de reintento. Prueba del GET pendiente/fallido; Domiciliarios 6/6, Flutter 213/5 omitidas, analyzer limpio. Build Cliente/Equipo publicado con hashes públicos iguales al artefacto local; los seis endpoints responden HTTP 200.

> **Fuente de verdad del trabajo Flutter/UI.**  
> Actualizar al cerrar cada sesión de frontend. Sincronizar resumen en [`../MASTER_STATUS.md`](../MASTER_STATUS.md).

**Última actualización:** 2026-11-24 — POS consulta cotización server-side para pago mixto. Smoke del atajo Tunnel reconstruyó Cliente/Equipo, URLs locales/públicas de Cliente/Equipo y API respondieron HTTP 200, los bundles JS locales/públicos coinciden. Regresión Flutter 209 aprobadas/5 omitidas; analyzer focalizado del POS limpio. Sigue pendiente QA visual autenticada (herramienta de captura no devolvió imagen de Chrome), acceso operativo por rol y definición del guard universal de Caja para pedidos con cobro diferido. Tunnel y OAuth conservados.

**Próximo paso:** ampliar cobertura de alta, acceso y operación por rol; reconstruir Cliente/Equipo y ejecutar regresión visual autenticada.

### 2026-11-24 — KDS “Todo listo” con recuperación parcial

La acción detiene la secuencia al primer ítem fallido, refresca ticket y comunica los éxitos parciales junto con pendientes reintentables. Widget 11/11; regresión Flutter 210/5 omitidas; analyzer focalizado limpio. Launcher reconstruyó Cliente y Equipo release; ambos subdominios y salud API responden HTTP 200 local y vía Tunnel. Sin tocar Nest/OAuth/datos. Sigue pendiente QA autenticada y dispositivo/impresora reales.

### Secuencia del rediseño Foody (2026-11-22)

| Etapa | Estado | Evidencia / salida |
|---|---|---|
| 1. Auditoría técnica y funcional | ✅ Cerrada por instrucción del producto | Diagnóstico previo de módulos, plan, comisiones y aislamiento |
| 2. Arquitectura de navegación | 🟡 Aplicada inicialmente | `FRONTEND_NAVIGATION_MAP.md`; centro Configuración y agrupación de ajustes existentes; deep links preservados |
| 3. Sistema visual | 🟡 Definido con referencias visuales del usuario | `FRONTEND_DESIGN_AUDIT.md`; cuatro referencias mapeadas por contexto; queda aterrizar tokens/componentes y migrar vistas gradualmente |
| 4. Implementación progresiva | 🔄 En curso | Navegación comprobada en 23 rutas y 7 secciones de plataforma. Escrituras de Caja, Inventario, Facturación y altas probadas con datos sintéticos. Continúa la cobertura de formularios por rol, tamaño y tema. |
| 5. Comercial y escalabilidad | 🟡 Validación parcial | Free se asigna en autoservicio y limita a dos mesas. La API habilitó Analítica en Pro y Facturación en Enterprise. Accesos cruzados rechazados entre dos restaurantes. Quedan por definir la transición al precio de Pro anunciado y la política de liquidaciones. |

La etapa 2 requiere validación de uso por roles durante QA. La etapa 3 se materializará vista por vista, usando las referencias del usuario según dispositivo y tarea, no como plantilla global. No se deben cambiar planes ni cargos sin decisión comercial explícita.

### Etapa 5 — decisiones a preservar

- **Suscripción Foody:** ingreso periódico del negocio por nivel contratado; el código actual define gratis/básico/pro/enterprise y precios backend que no coinciden con la visión inicial Free → Pro a $50.000 COP. No cambiar catálogo ni preservar Basic/Enterprise sin definir compatibilidad de clientes/suscripciones existentes.
- **Comisión sobre ventas:** no se encontró cálculo general porcentual aplicado al subtotal de ventas. No asumir que existe.
- **Cargo de domicilios:** `MEMORIA.md`, migración `011_super_admin.sql` y `ConfiguracionGlobalModule` documentan/configuran 15% como comisión sobre la entrega independiente; el servicio de domiciliarios calcula comisión e ingreso estimado del repartidor. Definir si Foody la cobra, quién paga, base (tarifa antes/después de ajustes), impuestos y cuándo se registra.
- **Pago al domiciliario:** `ganancias_domiciliario` almacena montos estimados y estado de pago; la auditoría previa no localizó un flujo de liquidación que cierre esta comisión end-to-end. Requiere revisión de endpoints/pantallas antes de darla por resuelta.
- **Auditoría 2026-11-24:** comprobado en controlador, servicio y UI: no hay operación que cambie `ganancias_domiciliario.pagado`; el panel solo muestra el saldo por pagar. La fila nace cuando aceptan oferta, antes de la entrega, y Super Admin la suma como ingreso del día. `DOM-INDEP-SETTLE-01`: antes de implementar payout, definir quién paga, fuente del dinero, devengo (aceptar/entregar/cobrar), cancelación/reclamo y comprobante; el ingreso actual debe entenderse como comisión estimada/acumulada, no recaudo confirmado. Ver `archivo/auditorias-prompts/AUDITORIA_REPORTES.md`.
- **Multi-tenant:** conservar aislamiento por organización (`restaurante_id`) y autorización/alcance por sede (`sucursal_id`) como invariantes a verificar. Preparar módulos verticales para otros sectores sin añadirlos al producto hasta que gastronomía tenga adopción probada.

---

## Cómo usar esta documentación

| Documento | Para qué |
|-----------|----------|
| **[FRONTEND_ROADMAP.md](FRONTEND_ROADMAP.md)** (este) | Orden de fases, estado global, qué sigue |
| **[FRONTEND_UX_AUDITORIA.md](FRONTEND_UX_AUDITORIA.md)** | Análisis UX por pantalla/rol (sin código) |
| **[FRONTEND_ACCESOS_RAPIDOS.md](FRONTEND_ACCESOS_RAPIDOS.md)** | Backlog de atajos y enlaces entre módulos (40 ítems) |
| **[FRONTEND_DESIGN_AUDIT.md](FRONTEND_DESIGN_AUDIT.md)** | Auditoría visual por pantalla (notas 1–10) + Design System |
| **[FRONTEND_NAVIGATION_MAP.md](FRONTEND_NAVIGATION_MAP.md)** | Mapa rutas, recorridos por rol, NAV-01…14 |
| **[FRONTEND_PRODUCT_AUDIT.md](FRONTEND_PRODUCT_AUDIT.md)** | Producto SaaS premium, PR-01…35, nota 6.0/10 |
| **[FRONTEND_FLUTTER_ARCHITECTURE.md](FRONTEND_FLUTTER_ARCHITECTURE.md)** | God files, estado, performance, FL-10…63 |
| **[FRONTEND_INSTRUCCIONES.md](FRONTEND_INSTRUCCIONES.md)** | Instrucciones adicionales del producto (ir agregando) |
| **[FRONTEND_RESPONSIVE_STRATEGY.md](FRONTEND_RESPONSIVE_STRATEGY.md)** | Breakpoints, overflow, RS-01…42 |
| **[FRONTEND_FRICTION_FIXES.md](FRONTEND_FRICTION_FIXES.md)** | Quick fixes UX (FF-01…) |
| **[../CHECKLIST_QA_ROLES.md](../CHECKLIST_QA_ROLES.md)** | Verificación manual por rol |
| **[../archivo/auditorias-prompts/AUDITORIA_PANTALLAS_BOTONES.md](../archivo/auditorias-prompts/AUDITORIA_PANTALLAS_BOTONES.md)** | Botones → API (técnico) |
| **[../ESTRATEGIA_BACKEND_PRIMERO.md](../ESTRATEGIA_BACKEND_PRIMERO.md)** | Flavors, usuarios demo, verificación |

### Convenciones de estado

| Símbolo | Significado |
|---------|-------------|
| ⏳ | Pendiente |
| 🔄 | En curso |
| ✅ | Hecho y verificado (analyze + prueba manual o script) |
| 🚫 | Pospuesto / bloqueado |
| 🟡 | Parcial |

### Al cerrar una tarea frontend

1. Marcar ítem en la tabla de fase correspondiente.
2. Añadir viñeta en **Changelog** (abajo).
3. Si aplica: actualizar [`../CHECKLIST_QA_ROLES.md`](../CHECKLIST_QA_ROLES.md) o `FRONTEND_ACCESOS_RAPIDOS.md`.
4. Ejecutar `.\scripts\verificar-flutter-ui.ps1`.
5. Una línea en [`../AVANCE_PROYECTO.md`](../AVANCE_PROYECTO.md) + [`../MASTER_STATUS.md`](../MASTER_STATUS.md).

---

## Estado actual (baseline 2026-07-02)

| Área | Estado |
|------|--------|
| Pantallas Flutter (`lib/features/`) | **36** pantallas, rutas en `AUDITORIA_PANTALLAS_BOTONES.md` |
| Botones → API | ~98% conectados |
| Backend listo para piloto | ✅ API + scripts E2E |
| QA manual navegador | ⏳ Pendiente (usuario) |
| Auditoría UX | ✅ Documentada |
| Accesos rápidos cross-módulo | ⏳ Backlog en `FRONTEND_ACCESOS_RAPIDOS.md` |
| Facturación DIAN | 🚫 Pausada — `FACTURACION_ELECTRONICA_PAUSADA.md` |

### Pulido UI ya hecho (2026-07-02)

| Ítem | Descripción |
|------|-------------|
| UX-001 | Cancelar pedido ≤2 min en seguimiento (`created_at` API) |
| UX-002 | Banner cuenta unificada mesa QR + total pendiente |
| UX-003 | Scope mesa QR (sin mis-pedidos global) |
| UX-004 | Cajero: snackbar si POS/Mesas sin caja |
| UX-005 | Mesero: banner QR en tab Pedidos |
| UX-006 | Repartidor: chip «GPS activo» |
| UX-007 | `verificar-flutter-ui.ps1` |

---

## Fases de trabajo

### Fase 0 — QA manual y baseline 🔄

**Objetivo:** Confirmar en navegador que lo documentado funciona antes de más cambios.

| ID | Tarea | Estado | Referencia |
|----|-------|--------|------------|
| F0-01 | Ejecutar `verificar-flutter-ui.ps1` | ✅ | 2026-07-26 / 31 |
| F0-02 | QA cliente + mesa QR (flavor `cliente`, puerto 8081) | 🔄 | Guion A · `qa-sesiones/2026-07-31-f0-ui.md` |
| F0-03 | QA staff: admin, mesero, cocina, cajero | 🔄 | Guion B · stack `:8080` |
| F0-04 | QA domi + repartidor + super (opcional) | 🔄 | Guion B/C |
| F0-05 | Registrar sesión en [`../qa-sesiones/`](../qa-sesiones/) | ✅ | `2026-07-31-f0-ui.md` + roles-api |

**Criterio de cierre Fase 0:** Flujo cruzado cliente→mesero→cocina·admin sin bloqueantes.  
**2026-07-31:** Docker+API+Flujo 12/12+Roles 38/38 OK; Chrome staff+cliente levantados; **falta marcar guion click-through**.

---

### Fase 1 — Quick wins UX (fricción alta, diff pequeño) ⏳

**Objetivo:** Quitar fricción obvia sin rediseñar módulos enteros.

| ID | Tarea | Estado | Doc |
|----|-------|--------|-----|
| F1-01 | Botón visible «Salir de mesa» en menú cliente mesa | ✅ | FF-01 |
| F1-02 | Carrito: permitir aumentar cantidad (+) | ✅ | FF-02 |
| F1-03 | Checkout: sección factura colapsable por defecto | ✅ | FF-03 |
| F1-04 | Dashboard: KPIs clicables (pedidos → kanban, alertas → alertas) | ✅ | FF-04 |
| F1-05 | Mensajes error cliente sin jerga técnica (Docker/API) | ✅ | FF-05 |
| F1-06 | Una sede → saltar lista sucursales | ✅ | FF-06 |
| F1-07 | Cobro mesa: botón «Cobrar todo» más prominente; split en sección avanzada | ✅ | FF-07 |

**Criterio de cierre:** FF-01 a FF-07 hechos + `verificar-flutter-ui.ps1` OK.

---

### Fase 2 — Accesos rápidos P0 (operación diaria) ⏳

**Objetivo:** Enlaces directos entre módulos que el staff usa cada turno.

| ID | Tarea | Estado | Doc |
|----|-------|--------|-----|
| F2-01 | Pedido (kanban) → Ver mesa | ✅ | AR-01 |
| F2-02 | Pedido → Movimiento caja | 🟡 | AR-17 · NAV-ADM-02: link, endpoint scoped, vista de historial y pruebas listos en fuente; falta activar Nest :3000 y comprobar con sesión autorizada en Tunnel |
| F2-03 | Pedido → Factura (borrador) | ✅ | AR-18 · NAV-ADM-02 |
| F2-04 | Factura → Pedido origen | ✅ | AR-19 · NAV-ADM-17 |
| F2-05 | Mesa QR tile → Aprobar sin abrir sheet completo | 🟡 | AR-03 · NAV-ADM-04 (Revisar; inline ⏳) |
| F2-06 | Alerta → Entidad relacionada | ✅ | AR-32 · NAV-ADM-18 |

Ver lista completa: **[FRONTEND_ACCESOS_RAPIDOS.md](FRONTEND_ACCESOS_RAPIDOS.md)**.

---

### Fase 3 — Accesos rápidos P1 (catálogo + finanzas) ⏳

| ID | Tarea | Estado | Doc |
|----|-------|--------|-----|
| F3-01 | Producto menú → Ver receta / margen | ⏳ | AR-10, AR-11 |
| F3-02 | Producto no disponible → Insumo faltante | ⏳ | AR-12 |
| F3-03 | Insumo → Movimientos filtrados | ⏳ | AR-14 |
| F3-04 | Cliente: reordenar último pedido | ⏳ | AR-23 |
| F3-05 | Búsqueda global admin (pedido #, mesa, producto) | ✅ | AR-28 · NAV-ADM-08 |

---

### Fase 4 — Navegación y shell admin ⏳

| ID | Tarea | Estado | Doc |
|----|-------|--------|-----|
| F4-01 | Favoritos en sidebar (3 módulos pinneados) | ✅ | AR-29 |
| F4-02 | Reducir tabs Inventario (agrupar o subnav) | ✅ | Selector compacto tipo menú bajo breakpoint; desktop conserva cinco áreas. `inventario_seccion_selector_test.dart` 6/6 (320/390 claro-oscuro, 820/1440) y analyzer limpio. |
| F4-03 | Reducir tabs Analítica en móvil | ✅ | Selector único sincronizado con TabController bajo 720 px; Widget tests 390/1440 px. QA autenticada/visual pendiente. |
| F4-04 | Unificar grid mesas mesero/cajero/admin (mismos patrones) | ✅ | Los tres roles reutilizan `MesasGridWidget`; variantes se limitan a modo/acciones autorizadas. Prueba de grid y diálogos 10/10; analyzer limpio. |
| F4-05 | Wizard crear restaurante (super admin) | ⏳ | AR-37 |

---

### Fase 5 — Pulido visual y animaciones (P3-08) 📅

| ID | Tarea | Estado | Notas |
|----|-------|--------|-------|
| F5-01 | Renombrar paquete `reserva_canchas` → foody (P3-05) | ⏳ | Solo Dart |
| F5-02 | Animaciones legacy → `ColoresFoody` / `TemaFoody` | ⏳ | |
| F5-03 | Estados vacío/error consistentes en todas las features | 🟡 | `FoodyEstadoUi.errorUi` refinado; migración y QA por feature pendientes |
| F5-04 | Responsive tablet: sidebar labels siempre visibles opción | ⏳ | |

---

### Fase 6 — Design System y rediseño visual ⏳

> Auditoría completa: **`FRONTEND_DESIGN_AUDIT.md`** · Media actual **5.8/10**

| ID | Tarea | Estado | Doc |
|----|-------|--------|-----|
| F6-01 | Extender `TemaFoody` (buttons, inputs, cards, chips, tabs) | ✅ | DS-01 |
| F6-02 | Cliente: menú + carrito + checkout (Uber/Square) | 🟡 | DS-02 — + seguimiento/mis pedidos Analítica + Google historial |
| F6-03 | Admin CRUD → `OperacionUi` + tabla Shopify | 🟡 | DS-03 — Usuarios confirma desactivación; Menú comunica progreso/error en disponibilidad y ofrece edición de precios explícita. Faltan patrones CRUD compartidos y unificar tablas por módulo |
| F6-04 | Splash + logo Foody (quitar legacy) | ✅ | DS-04 |
| F6-05 | Unificar fondos cliente (`ColoresFoody` vs hex sueltos) | ⏳ | DS-05 |
| F6-06 | Empty/error states ilustrados | 🟡 | DS-06 — `FoodyEstadoUi` en ciudades/mis-pedidos |
| F6-07 | Secundario/acento en CTAs secundarios | ⏳ | DS-07 |
| F6-08 | Inventario/Analítica: menos tabs, sub-nav | 🟡 | DS-08 — Inventario ya usa selector compacto móvil y Análisis selector de métricas; Inventario 6/6 tests (320/390 light/dark, 820/1440 escritorio). Pendiente decidir si reorganizar las cinco áreas en sub-nav lateral en pantallas grandes; QA visual autenticada pendiente. |

**Referencias visuales internas (8+/10):** KDS, Sidebar admin, Menú cliente (base), Kanban.

---

### Fase 7 — Responsive (mobile · tablet · desktop · web) ⏳

> Estrategia completa: **`FRONTEND_RESPONSIVE_STRATEGY.md`** · Media responsive global **6.5/10**

| ID | Tarea | Estado | Doc |
|----|-------|--------|-----|
| F7-01 | `FoodyBreakpoints` + `context.foodyLayout` | ⏳ | RS-01 |
| F7-02 | `FoodyAdaptiveContainer` (maxWidth cliente/admin) | ⏳ | RS-02 |
| F7-03 | `FoodyAdaptiveDialog` (sheet móvil / dialog desktop) | ⏳ | RS-03 |
| F7-04 | Unificar breakpoints (720 panel, 800 super → 720) | ⏳ | RS-04 |
| F7-05 | TabBar scrollable (inventario, menú admin, reportes, costeo, facturación, domi) | ✅ | RS-05 |
| F7-06 | Cliente: fix overflow combos (+ fade chips menú) | 🟡 | RS-14 parcial; grid menú/checkout 2 cols ⏳ |
| F7-07 | Operación: mesas 2 cols &lt;400; POS 2 cols &lt;400; kanban fade | 🟡 | RS-20…23 parcial |
| F7-08 | CRUD: listas densas→card móvil (movimientos, fiados, trailing) | 🟡 | RS-30…31 parcial |
---

### Fase 8 — Arquitectura de navegación ⏳

> Mapa completo: **`FRONTEND_NAVIGATION_MAP.md`**

| ID | Tarea | Estado | Doc |
|----|-------|--------|-----|
| F8-01 | URL sync sidebar (`?seccion=` al navegar) | ✅ | NAV-01 |
| F8-02 | Favoritos sidebar (3 pins) | ✅ | NAV-02 / AR-29 |
| F8-03 | Dashboard → módulos (KPIs clicables) | ✅ | NAV-03 / FF-04 |
| F8-04 | Enlaces cruzados kanban ↔ mesa ↔ caja | 🟡 | NAV-04 — kanban→mesa ✅ |
| F8-05 | Renombrar domi planta vs gestión domiciliarios | ✅ | NAV-05 + NAV-DP-06 «Mi ruta» |
| F8-06 | FAB «Nuevo pedido» dentro de kanban (quitar ítem sidebar) | ⏳ | NAV-09 |
| F8-07 | Cliente bottom nav (Inicio / Pedidos / QR) | ✅ | NAV-10 |
| F8-08 | Limpiar `case inventario` muerto | ⏳ | NAV-08 |

---

### Fase 9 — Arquitectura Flutter (mantenibilidad) ⏳

> Auditoría: **`FRONTEND_FLUTTER_ARCHITECTURE.md`** · Nota global **5/10**

| ID | Tarea | Estado | Doc |
|----|-------|--------|-----|
| F9-01 | Core UI: `FoodyFormato` + estados carga/error/vacío | ✅ | FL-10, FL-11 |
| F9-02 | `FoodyStaffAppBar` + `FoodyAsyncBody` | 🟡 | FL-12 — `FoodyAsyncBody` creado |
| F9-08 | Script `verificar-foody-loc.ps1` (LOC >800) | ✅ | FL-00 |
| F9-03 | Split `mesa_pedidos_sheet` + `mesas_grid_widget` | ⏳ | FL-02 fase 2 |
| F9-04 | Split `pedidos_kanban_widget` | ⏳ | FL-02 |
| F9-05 | Split `panel_foody_control` (1 vista/archivo) | ⏳ | FL-02 |
| F9-06 | Providers: `pedidosActivos`, `mesas`, `cajaActiva` | ⏳ | FL-30 |
| F9-07 | `mis_pedidos` → `ListView.builder`; debounce búsquedas | ⏳ | FL-50…53 |

---

### Fase 10 — Producto SaaS premium ⏳

> Auditoría: **`FRONTEND_PRODUCT_AUDIT.md`** · Nota producto **6.0/10** (vendible piloto, no premium)

| ID | Tarea | Estado | Doc |
|----|-------|--------|-----|
| F10-01 | Dashboard gerente command center (KPIs clicables) | 🟡 | KPIs y enlaces ya existen; DASH-STATUS-UX-01 clarifica frescura/error parcial. Falta priorización contextual por rol y QA visual autenticada. |
| F10-02 | Búsqueda global ⌘K + favoritos sidebar | ✅ | PR-14, AR-28/29 |
| F10-03 | `FoodyEmptyState` + copy por contexto | ⏳ | PR + DS-06 |
| F10-04 | `FoodyInsightCard` (tarjetas métricas) | ⏳ | PR-04 |
| F10-05 | Splash/logo Foody (quitar legacy) | ✅ | A1, DS-04 |
| F10-06 | FAB acciones rápidas por rol | ⏳ | PR-10…13 |
| F10-07 | Wizard onboarding restaurante trial | ⏳ | PR-05 |
| F10-08 | Microinteracciones P0 (carrito badge, undo snackbar) | ⏳ | PR-20…25 |

---

## Mapa de pantallas (referencia rápida)

### Cliente (flavor `cliente`)

`splash` → `ciudades` → `restaurantes` → `sucursales` → `menu` → `carrito` → `checkout` → `seguimiento`  
Atajos: `mis_pedidos`, `escanear_qr`, `mesa/:token`

**Auditoría UX/UI:** [`FRONTEND_AUDITORIA_UX_CLIENTE.md`](FRONTEND_AUDITORIA_UX_CLIENTE.md) — nota **6.5/10**; **CL-01…08 ✅** (2026-07-31); quedan CL-10…23 (P1/P2).

### Staff por rol (flavor `equipo`)

| Rol | Ruta | Pantalla |
|-----|------|----------|
| Admin/gerente | `/admin/panel?seccion=` | Panel + 20 submódulos |
| Cajero | `/admin/cajero` | 3 tabs |
| Mesero | `/admin/mesero` | 2 tabs |
| Cocina | `/admin/cocina` | KDS |
| Domi planta | `/admin/domiciliario` | Dashboard |
| Repartidor | `/domiciliario/*` | Login → dashboard |
| Super | `/admin/foody-control` | 7 secciones |

Detalle UX staff/cliente baseline: **FRONTEND_UX_AUDITORIA.md**. Cliente profundo: **FRONTEND_AUDITORIA_UX_CLIENTE.md**.

---

## Verificación frontend

```powershell
# Puerta obligatoria antes de declarar hecho
.\scripts\verificar-flutter-ui.ps1

# Cliente (puerto según tu terminal)
.\scripts\flutter-run-flavor.ps1 -Flavor cliente -Device chrome -WebPort 8081

# Staff
.\scripts\flutter-run-flavor.ps1 -Flavor equipo -Device chrome -WebPort 8080
```

---

## Changelog frontend

- **2026-11-24:** **GLOB-ERROR-STATE-RESP-01** — estado de error compartido con superficie del tema, ancho máximo, acciones de 48 px y CTA ancho en móvil. Tests 8/8 (320/390/820/1440, claro/oscuro), analyzer limpio. Cliente/Equipo release publicados por el lanzador; hosts locales/públicos y API salud HTTP 200, bundles SHA-256 locales/públicos idénticos. Build JS terminó con advertencias preexistentes de Wasm/CupertinoIcons. Falta migración de estados ad hoc y QA autenticada.
- **2026-11-24:** **F4-04 Mesas por rol** — confirmado que admin, cajero y mesero componen el mismo `MesasGridWidget`, con parámetros solo para el modo operativo y las acciones del rol. Suite `mesas_grid_widget_test.dart`: 10/10; analyzer de los tres paneles y widget limpio.

- **2026-11-23:** **UX/RBAC-USUARIOS-01** — permiso `crear_pedido` se presenta como «Crear y operar pedidos» con su alcance real (líneas y transiciones FSM). El formulario detectó overflow en selector de rol a 320 px; `isExpanded` lo corrige en crear/editar. Usuarios widget tests 4/4 incluyendo 320×568; suite Flutter completa 160/5 omitidas; analyze focalizado limpio. Cliente/Equipo release recompilados y cinco rutas locales/públicas responden HTTP 200; cloudflared/API permanecieron activos. Matriz de autorización backend sin cambio; QA autenticada por roles sigue pendiente.
- **2026-11-23:** **COC-NODISP-DOM-01 (guard backend)** — no hay cambio visual requerido hasta que se defina el flujo de ajuste parcial/abonos. UI de domicilios debe presentar el error de asignación que devuelve Nest; activación del backend y QA autenticada aislada pendientes.
- **2026-11-23:** **UX-DOMI-NUMERIC-01** — La UI normaliza importes API `num` o `String` para KPIs, comisiones y confirmación de liquidación; no altera cálculos ni liquidaciones en backend. Fixture usa importes string en 390/820/1440; `dart analyze` limpio, suite 131/5 skips. Rebuild túnel pendiente.
- **2026-11-23:** **UX-INV-MERCADO-EMPTY-LAYOUT-01** — Mercado diferencia lista filtrada vacía de catálogo sin datos y permite quitar búsqueda/filtros; el vacío se vuelve desplazable a 320×568. La prueba integrada encontró y cubrió además un `Spacer` dentro de tarjeta de alto intrínseco que causaba `RenderFlex` al mostrar precio de compra; reemplazado por espaciado fijo. Pantalla + selector: 7 pruebas, analyze limpio y suite global 131 aprobadas/5 E2E mutadoras omitidas. Cliente/Equipo release reconstruidos; endpoints locales y públicos de ambos sitios y salud API responden HTTP 200. Túnel/OAuth sin cambios. Falta QA autenticada de tareas/roles.
- **2026-11-23:** **UX-MENU-EMPTY-RECOVERY-01** — La lista de productos conserva el vacío inicial con CTA «Crear primer producto» y presenta una recuperación específica cuando búsqueda/filtros no tienen coincidencias. Prueba de búsqueda→limpiar→producto visible añadida; `menu_admin_screen_test.dart`: 9/9 en 320/390/820/1440 px, analyze limpio. Suite global 130 aprobadas/5 E2E mutadoras omitidas; Cliente/Equipo release reconstruidos y los hosts locales/públicos más salud API responden HTTP 200. Tema oscuro y QA autenticada de subflujos siguen abiertos.
- **2026-11-23:** **UX-PED-EMPTY-RECOVERY-01** — Pedidos diferencia «No hay pedidos en [estado]» de cero coincidencias por canal/búsqueda y ofrece limpiar filtros para volver a la lista; no cambia estados ni llamadas. Widget tests: 6/6 para 320/390/820/1440 y flujo filtro domicilio→limpiar→pedido visible; analyze limpio; suite global 129 aprobadas y 5 E2E mutadoras omitidas; release Cliente/Equipo reconstruidos y verificados HTTP 200 local/público. QA autenticada sigue pendiente.

| Fecha | Cambio |
|-------|--------|
| 2026-11-22 | **Usuarios admin** — tabla densa en escritorio y cards en móvil/tablet; estado con etiqueta textual; test responsive 390/820/1440 px. Los permisos y acciones existentes se conservan. |
| 2026-11-22 | **Inicio — centro de operación** — indicadores con destino reconocible y expansión animada de paneles; respeta reducir movimiento y conserva destinos/umbrales. |
| 2026-11-22 | **Domiciliarios admin** — resumen de independientes diferencia comisión Foody y saldo por pagar; normalización de importes PostgreSQL `numeric` en repositorio Flutter; tests de contrato y responsive en 390/820/1440 px. QA visual autenticado y tema oscuro pendiente. |
| 2026-11-22 | **Menú admin / Productos** — tabla densa tema-aware para escritorio y tarjetas existentes para móvil/tablet; acciones de disponibilidad, precios, cocina, toppings, foto y costos intactas; falta analyzer final y QA visual. |
| 2026-11-22 | **Oleada admin / inventario** — listado Mercado con tabla desktop/grid tablet/cards móvil; registro de movimientos prioriza transición de stock; Traslados responsivo; shells de formulario y editor de Subreceta respetan tema claro/oscuro. API y flujos intactos; análisis focalizado sin errores (1 info previo en interpolación de subreceta); QA visual pendiente. |
| 2026-11-22 | **Insumos responsive** — hero azul oscuro/naranja, acción Nuevo insumo en escritorio, resumen con datos disponibles y tabs iconográficas; lógica/backend intactos |
| 2026-11-22 | **Caja + Facturación** — pruebas widget 320/390/820/1440; Facturación verifica lista móvil y tabla escritorio; no se alteran reglas ni API. |
| 2026-11-22 | **Tarjeta Kanban de pedido** — QA 280/320/390/820/1440 detectó y permitió corregir overflow de número/tiempo/total en tarjeta estrecha; `dart analyze` limpio. |
| 2026-11-22 | **KDS** — QA sin Supabase en 320/390/820/1440; overflow pestañas corregido y fallo de suscripción ya no interrumpe la pantalla/polling de respaldo. QA Realtime autenticado sigue pendiente. |
| 2026-11-22 | **Mesas** — grilla basada en ancho disponible, no en MediaQuery global; prueba en móvil y tablet con sidebar/contenido limitado. Sheets aún requieren auditoría. |
| 2026-11-22 | **Detalle de cuenta Mesa** — tokens de superficie/texto/borde dependen del tema; prueba en claro/oscuro a 320×568 y 390×844 con datos de ticket. |
| 2026-11-22 | **Pedidos Kanban** — pruebas de estado vacío, acción de cambio a columnas y pedido activo; corrige prefijo duplicado de nombre de mesa. |
| 2026-08-04 | **Checkout cliente UX** — ink AppBar/tipo/pago/campos/CTA; tip confirmación |
| 2026-08-04 | **Carrito detalle** — tap sheet Incluye/extras, swipe borrar, Vaciar |
| 2026-08-04 | **Carrito cliente UX** — ink AppBar/pasos/cards/CTA; qty pill animada |
| 2026-08-04 | **Menú cliente UX** — ink, tip + animaciones, snackbar Ver, sheets producto/combo |
| 2026-08-04 | **Escanear mesa UX** — AppBar/cards Analítica; Pegar + Ir a mesa ink; banner sesión activa; linterna + haptic; web hero |
| 2026-08-04 | **Mis pedidos + Google + Seguimiento UX** — banner Continuar con Google; sync `auth_uid`; AppBar/cards Analítica; no es login staff |
| 2026-08-04 | **Sucursales cliente UX** — AppBar/cards/CTA Analítica; auto-nav 1 sede intacto |
| 2026-08-04 | **Home lugares UX** — AppBar/nav/cards/estados ink; sin arcoíris en placeholders |
| 2026-08-04 | **Elegir ciudad UX** — header denso + tiles Analítica; FCM/preferencia intactos |
| 2026-08-04 | **Splash UX** — canvas neutro sin arcoíris; marca en card; lógica intacta |
| 2026-08-04 | **Registro repartidor UX** — card ink + espera; API intacta |
| 2026-08-04 | **Auth UX** — registro restaurante + login repartidor ink; `AuthFormEstilo` |
| 2026-08-04 | **Login staff UX** — card Analítica, CTA ink, demo colapsable; OAuth intacto |
| 2026-08-04 | **Chrome panel** — sidebar activo neutro + AppBar/sede ink; sin naranja Material |
| 2026-08-04 | **Pedidos UX** — KPIs, chips/tabs ink, cards urgencia + CTA ink/Listo verde; API/Realtime intactos |
| 2026-08-04 | **Dashboard ops** — acordeones Mesas/Domicilio/Stock/Alertas + KPIs + charts Analítica |
| 2026-08-04 | **Config cocinas** — dual + KPIs riesgo + FoodyDialogo; KDS atajo en header |
| 2026-08-04 | **KDS Cocina \| Listos** — pestañas separadas; Listo mueve ticket a Listos |
| 2026-08-04 | **KDS UX** — altura al contenido, urgencia franja/tiempo real, Listo primario, Todo listo, Wrap responsive |
| 2026-08-04 | **Repartidores UX** — KPIs, config≠operación, liquidar primario, dual layout, diálogo seguro |
| 2026-08-04 | **Zonas UX** — layout dual, mapa+leyenda, presets km/precio, timeline, atajos vacío (flujo real, no solo color) |
| 2026-08-04 | **Zonas domicilio UI** — tokens Analítica, mapa + anillos densos, CTA ink, FoodyDialogo; sin cambios API |
| 2026-08-04 | **Mis sucursales UI** — tokens Analítica, marca densificada, cards sede, CTA ink, FoodyDialogo; sin cambios API |
| 2026-08-04 | **Horarios UI** — tokens Analítica, resumen neutro, cards densas, switch ink, FoodyDialogo; sin cambios API |
| 2026-08-04 | **Usuarios UI** — tokens Analítica, badges rol, CTA/switch ink, FoodyDialogo; sin cambios API |
| 2026-08-04 | **Alertas UI** — tokens Analítica, badges tipo/nivel, chip/CTA ink, vacío guiado; sin cambios API |
| 2026-08-04 | **Mesas polish** — cards minimal, KPIs neutros, FoodyDialogo (sin naranja Material) |
| 2026-08-04 | **Mesas UI** — salón creativo (cards CTA, filtros KPI, orden QR→ocupadas, sheet cuenta); lógica intacta |
| 2026-08-04 | **Caja UI** — tokens Analítica, apertura ink, turno + movimientos/CxC; lógica intacta |
| 2026-08-04 | **Nuevo pedido UI** — tokens Analítica, chips/toggle ink, grid neutro, carrito + confirmar; lógica POS intacta |
| 2026-08-04 | **Promociones UI** — tokens Analítica, vacío guiado, cards densas + badges, FAB ink; sin cambios API |
| 2026-08-04 | **Plan y pagos UI** — tokens Analítica, suscripción + planes responsive (3 col), historial denso; Wompi/lógica intacta |
| 2026-08-04 | **Facturación UI** — tokens Analítica, secciones emisor/IVA/DIAN, facturas densas + estados; sin cambios API |
| 2026-08-03 | **Menú UI** — tokens Analítica, filtros riesgo, badges receta/margen/cocina, tabs densos; sin cambios API |
| 2026-08-03 | **Costos UI** — intuitividad (guía editor, tabs claros, CTAs), riesgo semántico, FoodyBreakpoints; sin cambios API |
| 2026-08-03 | **Insumos UI** — línea visual Analítica (tokens, riesgo semántico, FoodyBreakpoints, FAB compacto); sin cambios API |
| 2026-08-03 | **Reportes UI** — misma línea visual que Centro de Inteligencia (header, KPIs, surfaces, charts, skeletons); sin cambios API |
| 2026-08-03 | **Centro de Inteligencia** — rediseño UI Analítica (header, KPIs+sparklines, insights, skeletons, charts, filtros); sin cambios de lógica/API |
| 2026-07-31 | **Cliente oleada A** — CL-01…08 ✅ (staff oculto, agotado, sticky carrito, pills, subtotal extras, stories CTA, FoodyEstadoUi, checkout inline) |
| 2026-07-31 | **Auditoría UX cliente** — `FRONTEND_AUDITORIA_UX_CLIENTE.md` (ciudad→seguimiento, promos, QR); backlog CL-01…23; sin código |
| 2026-07-26 | **NAV-DP** — Domi planta 13/13; doc `FRONTEND_AUDITORIA_NAV_DOMICILIARIO.md` |
| 2026-07-26 | **F0 QA** — `verificar-flutter-ui` + FlujoApi 12/12 + RolesApi 38/38; sesión `qa-sesiones/2026-07-26.md`; UI click-through ⏳ |
| 2026-07-26 | **NAV-ADM2** — deep-links pedido/insumo, kanban móvil, alertas→costos, cabeceras operación, cross-links finanzas/cocina/staff; doc `FRONTEND_AUDITORIA_NAV_ADMIN2.md` (22/24) |
| 2026-07-26 | **Overflow móvil** — ListTiles densos, grids POS/mesas 2 cols &lt;400, FAB padding, tabs costeo scroll, `FoodyScrollHorizontalFade`; R-01/R-08 ✅ |
| 2026-07-22 | **NAV-ADM Baja** 20–23 ✅; ciclo nav admin cerrado salvo 14/24 |
| 2026-07-22 | **NAV-ADM Media** 07–13,15–19 ✅ (14/24 diferidos); Alta 01–06 ✅ |
| 2026-07-22 | **Auditoría nav admin** — `FRONTEND_AUDITORIA_NAV_ADMIN.md` (NAV-ADM-01…24); ciclo diagnóstico ✅ |
| 2026-07-02 | **AR-28 completo** — búsqueda admin pedido#/mesa/módulo; alertas→mesa/caja; menú AppBar blanco; `FoodyAsyncBody`; `verificar-foody-loc.ps1`; QA API 37/37 |
| 2026-07-02 | **Sprints 2–4** — FF-07 cobro mesa; AR-01 kanban→mesa; AR-28 búsqueda admin; AR-29 favoritos; AR-32 alertas→panel; NAV-01 `?seccion=`; NAV-10 bottom nav; `FoodyScaffoldCliente` + `FoodyPasosPedido`; carrito sticky; `verificar-flutter-ui.ps1` OK |
| 2026-07-02 | **Sprint 1** — FF-01…06, `FoodyFormato`/`FoodyEstadoUi`, splash Foody, carrito +/− |
| 2026-07-02 | Reorganización: suite frontend en `docs/frontend/` + índice README |
| 2026-07-02 | Arquitectura Flutter — `FRONTEND_FLUTTER_ARCHITECTURE.md` (god files, FL-10…63); Fase 9 |
| 2026-07-02 | Navegación — `FRONTEND_NAVIGATION_MAP.md` (22 rutas, 6 redundancias, recorridos por rol, NAV-01…14); Fase 8 |
| 2026-07-02 | Auditoría visual `FRONTEND_DESIGN_AUDIT.md` (48 pantallas, media 5.8/10); Fase 6 Design System |
| 2026-07-02 | Pulido UX-001…007 (cancelar 2min, mesa QR, cajero, mesero, GPS) |
| 2026-07-02 | Estrategia: frontend activo; DIAN pausada |

---

## Próximas instrucciones del producto

Añadir en **[FRONTEND_INSTRUCCIONES.md](FRONTEND_INSTRUCCIONES.md)** cada nueva petición. Este roadmap se actualiza al priorizarlas en fases.

**2026-11-24 — PED-POS-REPLACE-ATOMIC-01:** el reemplazo usa un único endpoint Nest y transacción compartida para agregar/quitar, guarda idempotencia y UI hace una sola petición. Se bloquea si la línea ya fue cobrada/asignada, o si el nuevo total requiere reembolso. Nest 37 suites/92 pruebas; Flutter global 237 aprobadas/5 E2E omitidas, POS + repositorio 20/20; analyzer focalizado limpio; web release compilada en salida QA aislada, con avisos heredados de Wasm/iconos. API :3000 no reiniciada; corrección aún no activa en runtime.

### 2026-11-24 — KDS interpreta estados heredados de cocina

`estado_cocina` NULL/desconocido queda como pendiente en Cocina, no se filtra a Listos y mantiene acción accesible “Marcar listo”. Nueva regresión con `estado_cocina: null`; suite KDS 14/14, responsive en 320/390/820/1440 px. Chrome quedó en `/admin/login`; QA autenticada por rol y captura visual siguen pendientes, sin tocar credenciales.

**Disponibilidad tras cambios de fuente (2026-11-24):** API salud, Cliente y Equipo respondieron HTTP 200 en localhost y Tunnel (6/6). Es smoke de disponibilidad, no valida sesión autenticada ni activa los artefactos compilados; no hubo reinicio/publicación.

### 2026-11-24 — navegación compacta de Inventario validada

Inventario ya presenta selector emergente con icono, sección activa y progreso «Sección n de 5» en compactos; escritorio conserva navegación visible para Mercado, Movimientos, Subrecetas, Conteo y Traslados. `inventario_seccion_selector_test.dart` 6/6 (320/390 claro y oscuro, 820/1440) y analyzer focalizado limpio. F4-02 queda cerrado como subnavegación responsive; la agrupación conceptual de entidades queda como decisión aparte si cambian módulos.

**2026-11-25 — publicación web verificada:** resolución de recursos estáticos FCM y 404 para assets inexistentes está documentada en docs/archivo/auditorias-prompts/AUDITORIA_ARRANQUE_WEB.md; panel Equipo volvió a renderizar tras recarga del Tunnel. Cache edge antigua de la URL FCM puede persistir hasta su TTL.
