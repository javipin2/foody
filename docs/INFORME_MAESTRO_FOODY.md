# INFORME MAESTRO FOODY — hallazgos, severidad y plan de corrección

**OPS-RUNTIME-02 (2026-11-25; corregido por OPS-RUNTIME-STALE-01):** PID 10204 atiende :3000 y `scripts/verificar-backend.bat` sale 0; comparación posterior de tiempos muestra que el proceso arrancó 07:22 local antes de escribirse el `dist/main.js` actual a las 08:28. `/salud` y probes demuestran disponibilidad/rutas, no que el filtro CAJ esté cargado. Activación de este artefacto y prueba semántica runtime pendientes. Tunnel, OAuth, credenciales y data comercial intactos.


| **OPS-STALE-ORDERS-02 / DOM-STATE-RECON-01 / OPS-STALE-CASH-SESSION-01** | Pedidos / Domicilios / Mesas / Caja | 🟡 Solo lectura: 15 pedidos operativos >24 h (14 >30 d), 4 de 11 mesas ocupadas, 7 cajas abiertas >30 d y 2 sesiones domiciliario >30 d; una asignación no coincide con estado/historial. Tunnel UI 11:26 COT muestra 9 abiertos/26 alertas, mesa y domicilio de 113 d 9 h; KDS 0 en Cocina y 6 Listos. DB read-only confirma 6/6 tickets visibles listos con >30 d; datos no clasificados como QA/negocio, no mutar hasta conciliar. |
| **IMP-QUEUE-CLASSIFY-01 / IMP-QUEUE-HEALTH-01** | Cocina / Impresión / Salud | 🟡 317 jobs terminales `error`: 316 agotaron 10 intentos con `ECONNREFUSED`, uno tiene 0 intentos/error vacío. Tres recientes cruzan con dos pedidos pagados y uno asignado antiguo. No reencolar en lote; conciliación por pedido pendiente. |
| **OPS-RUNTIME-STALE-01** | API / arranque | 🟡 Verificación 2026-11-25 21:43 COT: PID 7584 inició 13:50:31; dist/main.js se actualizó 22:08:55; fixes recientes no activos/probados en :3000. API local/pública, Equipo/Cliente local/públicos HTTP 200; health local/público exito=true y timestamps difieren 1s. Cloudflared PID 8940 activo. Falta reinicio coordinado + prueba semántica; sin OAuth/credenciales/datos tocados. |
| **WOMPI-EXT-TIMEOUT-01** | Suscripciones / Finanzas | 🟡 Cuatro llamadas externas carecen de timeout. Especialmente `POST /v1/transactions`: abortar puede ocultar una aprobación. Ya se corrigieron la asociación del webhook por referencia y la reserva transaccional que evita llamadas manuales/cron simultáneas. Falta estado ambiguo durable/reconciliación antes de establecer timeout o reintentar; no se presume idempotencia del endpoint estándar. |
| **WOMPI-WEBHOOK-REFERENCE-01** | Suscripciones / Renovaciones | 🟡 Corregido en fuente: webhook recurrente puede asociar por `reference` cuando no hay payment link ni `sku`, solo si corresponde a pago pendiente; 1/1 unit test + typecheck Nest. Wompi documenta referencia única y eventos transaction.updated. Falta E2E aislada y runtime actualizado; ver MASTER y fuentes oficiales. |
| **WOMPI-RENEWAL-CLAIM-01** | Suscripciones / Renovaciones | 🟡 Cron y petición manual serializados por fila de suscripción; pago pendiente/aprobado reciente bloquea otro intento y la fuente se reserva por 20 h en la misma transacción que inserta el pago local. UI explica el bloqueo. Backend 4/4 + typecheck; Flutter Plan y pagos 6/6 + analyzer. E2E con PostgreSQL aislado y runtime pendientes. |
| **DOMI-PAY-LEGACY-METHOD-01** | Domicilios / Caja / Pagos | 🟡 Fuente conserva primer método de pago previo en el scalar y registra la liquidación CxC como efectivo separado. E2E API :3001 + clon 1/1: abono transferencia $2.000, CxC/liquidación efectivo $6.000, pagos resumen y replay HTTP 400; SQL confirmó también el cargo de $5.000 fuera de Caja ausente del libro `pagos_pedido`. Clon retirado; :3000 sigue viejo. Ver DOMI-OFF-CAJA-TRACKING-01. |
| **FIN-PAYROLL-FREQUENCY-01** | Finanzas / Nómina | 🟡 El resumen considera pagado a cualquier empleado con un gasto de nómina en el mes calendario; ignora frecuencia_pago (diario/semanal/quincenal/mensual), los montos abonados y periodo_desde/hasta, aunque los pagos almacenan ese período. Riesgo de ocultar saldo/segunda quincena. Regla de sueldo base por período y liquidación parcial pendiente; no se alteró cálculo. |
| **REP-AUDIT-TZ-01** | Reportes / Auditoría / Caja | 🟡 El timeline comparaba fechas de negocio como UTC, desplazando eventos en los bordes locales. Cuatro fuentes ahora usan rango [inicio Bogotá, inicio del día siguiente Bogotá), conserva índice por sucursal/created_at; endpoint default usa fecha local. Nest 3/3, build OK, QA solo lectura confirmó extremos 05:00Z. Dist actualizado 22:03:45 pero :3000 PID 7584 inició 13:50:31; activación y endpoint runtime pendientes. Tunnel y datos intactos. |
| **ANA-CASH-COHORT-UX-01 / FIN-DATE-01** | Analítica / Reportes / Caja | 🟡 Reportes distingue cohorte por fecha de pedido del recaudo neto por fecha de movimiento (`created_at`); propinas excluidas. Análisis conserva cohorte por filtros. Responsive 8/8, PDF/CSV 2/2, Nest helper/contrato 6/6, analyzer y build OK. Activación de la versión servida no verificada por OPS-RUNTIME-STALE-01. El descuadre físico sigue siendo `cajas.diferencia`. |
| **PED-STAFF-IDEM-01/02 / PED-FLOW-E2E-01** | POS / Pedido / Cocina / Caja | 🟡 Replay concurrente autenticado: una orden/único recaudo, payload distinto → 409; no duplica ítem/ticket Cocina. 6 suites/44 E2E en clon QA descartable; clon eliminado, QA fuente intacta, :3001 detenida. Semántica del PID :3000 para la última compilación no verificada. Realtime, FCM e impresión física fuera de evidencia. |
| **PED-NUMBER-CONCURRENCY-01** | Cliente / Pedidos | 🟡 Cuatro pedidos públicos simultáneos reciben números únicos, E2E 1/1 en clon QA descartable. Clon eliminado, QA fuente intacta. La prueba cubre unicidad en esa carga acotada, no capacidad de carga ni p95. |
| **COC-PRODUCT-KITCHEN-ROUTE-01** | Catálogo / Cocina / Domicilios | ✅ Fix en fuente: guard de sede/categoría/cocina para productos vendibles, espejo/copia de menú y baja segura de cocinas. Nest focalizado 11/11 y E2E producto→pedido→KDS→listo 1/1 en clon desechable; clon retirado y QA fuente intacta. ⚠️ La API :3000 aún no ejecuta el `dist` compilado 16:52:42 (PID 7584 inició 13:50:31); su HTTP 200 solo confirma salud. Activación live pendiente. Líneas históricas no se reasignan al cambiar catálogo y deben evaluarse individualmente si se detectan. |
| **KDS-READY-AGE-01** | Cocina / Pedidos | ✅ Antigüedad del pedido listo basada en `created_at` (ámbar >24 h, rojo >30 d) aclara que no significa tiempo en estado listo; KDS 17/17 en 4 anchos + analyzer. Release Cliente/Equipo publicado por el procedimiento transaccional el 2026-11-25; Equipo y `/admin/login`, Cliente, FCM y salud API responden HTTP 200 por Tunnel; SHA-256 del JS Equipo público coincide con local. Cloudflare PID 8940 intacto. Seis tickets >30 d siguen sin clasificar y no se alteran; revisar su origen antes de cualquier recuperación. |
| **IMP-AGENT-BACKLOG-01 / RT-HEALTH-01** | Cocina / Realtime / Impresión | 🟡 Realtime y agente `:8765` conectados; agente está en modo `archivo`. 317 jobs históricos en `error`, 0 pendientes y health global degradado. Nest 3/3; prueba Python sintética aislada aprobada. No se reencoló ni limpió histórico; falta clasificar y decidir recuperación individual para evitar duplicados. |
| **ANA-FILT-PROD-01** | Analítica / Reportes | ✅ Fuente actual suma solo líneas coincidentes cuando se filtra producto; se corrigió evidencia documental obsoleta y se añadió regresión unitaria 1/1. |
| **ANA-PNL-COMP-FILTER-01** | Analítica / Finanzas | ✅ Rentabilidad comparaba COGS del período anterior sin aplicar filtros activos. Ahora reutiliza filtro de pedido, rango temporal y filtros por línea. Jest 3/3 + build; runtime :3000 pendiente por reinicio coordinado. |
| **ANA-PNL-EXP-SCOPE-01** | Analítica / Finanzas | 🟡 La utilidad neta bajo filtros de pedido descuenta el total de gastos de la sede/período; no se prorratea a productos/pedidos. La pantalla aclara el alcance. Política de asignación pendiente; no cambiar fórmula sin decisión contable. |
| **FIN-TIP-REPORT-01 / FIN-TIP-MIXED-ALLOC-01** | Caja / Analítica / Finanzas | 🟡 Propina voluntaria y aparte del pedido, solo persiste con pago real; no se conserva si se difiere. En pago mixto se prorratea por el importe del pedido aunque no se pregunta cómo se pagó la propina; definir si ese prorrateo es política o si se captura medio independiente. Falta beneficiario, reparto, cancelación y liquidación. |

| **FIN-TIP-UX-01** | POS / Caja de mesa | 🟡 Propina en pantallas de cobro aclarada como voluntaria y aparte del total; solo se registra junto con un pago real. No cambia API ni cálculos. Widgets POS+Mesa 27/27, analyzer focalizado limpio. Cliente/Equipo Release publicados y SHA local/Tunnel coincide. |

| **CAJ-OPEN-RECEIVABLE-01 / CAJ-DOM-IMPAGO-01** | Pedidos / Domicilios / Caja | 🟡 Fuente y `dist` listos: domicilio entregado con saldo aparece en “Entregados · por cobrar” con saldo visible y botón sujeto a `cobrar_pedido`; Dashboard cuenta abiertos; Cerrados hoy excluye entregas impagas. El cierre sigue bloqueado hasta registrar cobro. Flutter 285/5 omitidas + analyzer focalizado; Nest completo 55 suites/142, `npx tsc --noEmit` y build OK. Cliente/Equipo publicados y local/Tunnel 200; bundles por SHA-256 verificados; Cloudflare PID 8940. Reinicio de API PID 10204 rechazado por revisión automática, pendiente activar para que el filtro entre en runtime. No se tocó información de negocio. |

| **DOM-RT-INDEP-01 / DOM-LOCK-ORDER-01** | Pedidos / Domicilios / Realtime | 🟡 Cancelación notifica por canal privado y libera sesión correctamente; aceptación/cancelación comparten orden de bloqueo. Suite E2E domicilio 6/6 en clon desechable. Activación de la compilación más reciente en :3000 no está probada; verificación Realtime autenticada en app publicada pendiente. Evidencia: `AUDITORIA_DOMICILIOS.md`. |

| **OPS-RUNTIME-01** | API / Arranque | 🟡 Revalidado 2026-11-25: `scripts/verificar-backend.bat` pasó y PID 10204 responde `/salud`, pero su inicio precede los artefactos actuales. Los builds recientes no están probados en runtime. Sitios/API por Tunnel HTTP 200 y Cloudflare activo. `.env`, OAuth y configuración Tunnel intactos. |
| **QR-SESSION-BIND-01** | Cliente / QR / Pedidos | 🟡 QR conserva el token hasta el pedido y Nest valida token↔mesa↔sucursal. E2E QR 6/6; regresión completa Nest 8/41 E2E, unitarias 51/128 y Flutter 276/5 omitidas. API activa; builds Cliente/Equipo verificados contra lo servido por Tunnel; queda aceptación visual con QR de prueba. |
| **FIN-PDF-UNICODE-01** | Reportes / Análisis | 🟡 Corregido y publicado: ambos PDFs incrustan Roboto con licencia; los 3 tests de exportación pasan, analyzer focalizado limpio y los assets de fuente del Tunnel coinciden por SHA-256 con los builds locales. |
| **PED-PAY-TRUST-01 / PED-STAFF-CASH-RBAC-01** | Pedidos / Caja / RBAC | 🟡 Corregido en fuente y QA; runtime activo :3000 PID 20152. Checkout no puede declarar pagos ni convertir método preferido en recaudo; POS exige `cobrar_pedido` para pago al crear y registra cobro simple con propina. Reproducción roja/verde; Nest 51/128 unitarias, E2E del lote actual 24/24, build OK. Tunnel y Cloudflare activos. La política de propina de Checkout se cerró en FIN-TIP-CHECKOUT-01; reparto/liquidación sigue pendiente. |
| **PED-TIP-REQUEST-01** | Checkout / Caja / Finanzas | 🟡 Checkout resuelto: propina voluntaria no se incluye en el total ni se conserva antes del pago; el API ignora este campo en clientes desactualizados. Propina realmente recaudada permanece separada en `pagos_pedido.propina`. Sin migrar histórico. Beneficiario/reparto, propina entregada al domiciliario y liquidación contable siguen pendientes. |
| **PERF-PEDIDO-CATALOGO-01** | Rendimiento / Pedidos | 🟡 Resuelto en fuente: catálogo agrupado al cotizar/crear pedido; no escalan las lecturas de SQL por número de líneas. Benchmark local aislado 1 línea p50 12,88 ms vs. 30 líneas 13,69 ms, 12 muestras, totales correctos. No es prueba de capacidad; combo sin cobertura runtime por ausencia de fixture. |
| **PERF-WEB-ASSET-01** | Rendimiento / Cloudflare Tunnel / Equipo | 🟡 `main.dart.js` público 6,96 MB decodificado, Brotli, tres GET 200 (1.677/586/495 ms, p50 586 ms, `REVALIDATED`). Muestra de asset HTTP, no waterfall ni carga. Medir con browser cold/warm y revisar CDN/client cache antes de ajustar headers. |
| **COC-KDS-IMMUTABLE-01** | Cocina / Caja / Despacho | 🟡 Corregido: Cocina rechaza cambio de línea si el pedido está en cobro/ruta/terminal antes de efectos de merma o catálogo. E2E Cocina+caja+QR 24/24 en clon limpio; cambio tardío 409 y línea permanece `preparando`. |
| **COC-PAID-KDS-01** | Cocina / Caja | 🟡 Fuente + `dist` verificados: E2E focalizado 1/1 en clon QA cubre abono, rechazo por rol, cobro admin con motivo y cierre posterior en KDS manteniendo `pagado`. Nest build/unitarias, Flutter KDS 15/15 + analyzer. Clon eliminado; :3001 detenida. Falta activar/controlar :3000 (PID 20152, build anterior). |
| **FIN-TIP-CHECKOUT-01** | Checkout / Caja / Finanzas | 🟡 Decisión y corrección Checkout: propina voluntaria no se agrega al total ni se persiste antes del pago; propina real capturada permanece en `pagos_pedido` separada de ventas/caja. E2E QA: solicitud pública ignorada (acumulado 0, sin pago). No se reclasificó histórico; liquidación/destinatario y propina de entrega siguen pendientes. |

| PED-WAITER-PAYMENT-01 | Pedidos / Caja | 🟡 Corregido en Flutter y cubierto por widget test: pedidos creados por mesero enviaban `efectivo` aunque no existe UI para cobrar; ahora se envía `pendiente`. POS cajero conserva el default efectivo. Prueba focalizada 18/18, analyzer limpio, Cliente/Equipo Release publicados y seis rutas local/Tunnel HTTP 200. Aceptación visual autenticada pendiente. |
| UI-USR-DEACTIVATE-01 | Usuarios / Acceso | 🟡 Corregido en Flutter: desactivar una cuenta ahora explica que perderá acceso y pide confirmación; cancelar no muta, confirmar usa el PATCH existente. Reactivación y matriz de permisos sin cambios. Widgets móvil/escritorio y roles 6/6; analyzer limpio; Equipo Release publicado y JS del Tunnel verificado por SHA-256. |
| CAT-AVAILABILITY-UX-01 | Menú / Pedidos | 🟡 Corregido en Flutter: cambio de disponibilidad ahora indica progreso y, ante error de red, conserva el valor visible y ofrece reintento. Endpoint y lógica Nest intactos. Menú widget 13/13, analyzer limpio, Equipo Release publicado y JS público coincide por SHA-256. |
| **COC-NODISP-CUSTOMER-01** | Cocina / Cliente / Domicilio | 🟡 Corregido y revalidado en QA: seguimiento autorizado informa producto/cantidad; Flutter avisa que el total no cambia. Responsive 5/5; Cocina E2E focalizado 7/7, incluyendo token válido y bloqueo de despacho; fixture limpiado. API :3000/Tunnel y Cloudflare activos. Aún falta decidir ajuste/reembolso y aceptación visual autenticada. |

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

1. **Permisos y aislamiento residuales**: RBAC de Caja cerrado: migración 094 aplicada en DB local activa, runtime autenticado y override solo lectura probados. Permanecen pendientes limpiezas/promociones globales y billing staff. El IDOR de cierre de caja tiene E2E cross-tenant con 403 y sin mutación.
2. **Cierre operacional de pedidos/Cocina/Caja**: activar los builds corregidos en el API vivo y cerrar las políticas pendientes sobre líneas no disponibles, abonos, devoluciones y movimientos financieros.
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
| ~~**COC-NODISP-01**~~ | Cocina | ✅ **Cerrado F0** — 
o_disponible` cuenta resuelto → pedido `listo` | P12/P29 |
| **P0-01 / R5** | Impresión | Sin QA impresora térmica real — go-live salón incompleto | Roadmap |
| **P0-05/06/07** | Infra / Pagos | Sin VPS HTTPS + Wompi prod → SaaS no cobra planes | Roadmap |

### 2.2 Alto — impacto fuerte en operación o riesgo

| ID | Módulo | Una línea |
|----|--------|-----------|
| **CAJ-CASH-RECON-01** | Caja / Finanzas | 🟡 Corregido en fuente: saldo esperado concilia efectivo físico, no tarjeta/transferencia; devoluciones solo restan si fueron efectivo. Propinas siguen aparte. Nest 55/145 + build; Flutter Caja 16/16 y analyzer limpio. No activado en :3000. Confirmar si propinas en efectivo se retiran del cajón o se guardan dentro separadas. |
| **RT-RECON-01** / **INFRA-EXT-SYNC-01** / **VIE-12** | Realtime / Flutter | ✅ F1 refetch al reconectar/resume |
| **INFRA-EXT-TO-01** | Red / Caja | ✅ F1 post-timeout GET + idempotency cobro |
| **PED-POS-CAP-01** | Pedidos / POS | ✅ el POS registra y envía la capability requerida por `/pedidos/estimar`; prueba UI→API en Tunnel cotiza 35.000 COP sin crear pedido |
| **CLIENT-DOM-CONTACT-01** | Checkout / Domicilio | ✅ domicilio requiere teléfono válido (7–15 dígitos) en Flutter y DTO; nombre opcional. Flutter 3/3, DTO 8/8, QR E2E 4/4 en QA aislada. API `:3000` requiere activar el build |
| **E2E-CLEAN-TERMINAL-01** | QA / Pedidos | ✅ el limpiador ahora excluye `entregado` además de otros estados terminales; QA tenía 63 domicilios entregados y los 63 se preservaron en la regresión |
| **API-IDEM-02** | Pedidos | ✅ F1 `idempotency_key` + `cobros_idempotencia` |
| **API-IDEM-03** | Caja | ✅ F1 `uq_caja_abierta_sucursal` |
| **RBAC-MESERO-01/02** | RBAC | ✅ ambas rutas de cobro requieren `cobrar_pedido`; specs del guard 2026-11-23 bloquean mesero y permiten cajero |
| **RBAC-MESERO-03** | RBAC | 🟡 `crear_pedido` protege alta, edición de líneas y PATCH de estado; mesero limita por servicio a `pagando`/`cancelado`, admin/gerente/cajero pueden transiciones válidas FSM. UI ahora explica el alcance. Separación de permisos por operación pendiente de decisión |
| **CONS-STOCK-CASCADE-01** | Inventario / Menú | ✅ F2 cascade hermanos |
| **FIN-REC-OPEN-01** | Finanzas / Pedidos / Domicilios | 🟣 E2E QA confirma que una venta de mesa efectivamente cobrada cuadra entre pedido, caja, Reportes y Analítica (delta igual al total, diferencia incremental $0). Sigue pendiente decidir reconocimiento de pedidos abiertos/impagos, abonos, devoluciones y costo de domicilio; la prueba de una venta cobrada no resuelve esa política contable. |
| **FIN-MESA-SPLIT-01** | Pedidos / Caja / Reportes | 🟡 Corregido en fuente y probado en QA: al cobrar varios tickets de una mesa, cada método se distribuye entre los pedidos cubiertos y cada movimiento queda asociado al ticket correcto. :3000 sigue ejecutando el proceso anterior; activar después del reinicio coordinado permitido. |
| **FIN-MESA-TIP-TRACE-01** | Caja / Propinas / Devoluciones | 🟣 En cobro unificado, `propina_acumulada` se distribuye entre tickets, pero las filas `pagos_pedido` asignan la propina a un solo pedido representativo. Total de caja intacto; riesgo de atribución por pedido para reportes/reembolsos. Modelo de asignación de transacción de mesa pendiente. |
| **FIN-SPLIT-OVERCHARGE-01** | Pedidos / Caja | 🟡 Corregido y probado en QA: split por ítem omitía extras y no respetaba el saldo del ticket después de un abono; podía registrar de más en Caja. El backend ahora usa precio compartido de línea, prorratea descuento y rechaza antes de escribir (`ITEMS_EXCEDEN_SALDO`). :3000 sigue ejecutando el proceso anterior; requiere reinicio coordinado. |
| **FIN-TIP-01** | Pedidos / Caja / Finanzas | 🟡 Cálculo técnico corregido y regresión E2E (Caja 8/8): pedido creado antes de nueva caja, abono mixto con propina y pago final por transferencia; suma correcta 1.400, cuadre sin propinas. Pendiente decisión contable y pago al personal; faltan abonos que crucen turnos. Evidencia: `AUDITORIA_CAJA.md` y `AUDITORIA_PEDIDOS_CICLO_VIDA.md`. |
| **FIN-FIXED-PARTIAL-BALANCE-01** | Finanzas / Costos fijos | ✅ Resuelto y activo: el resumen descuenta abonos vinculados por sucursal, origen y mes, y expone saldo restante. Unitaria 2/2, SQL QA con rollback, build y API local/pública 200. |
| **FIN-PAYROLL-PERIOD-01** | Finanzas / Nómina | 🟣 Pendiente: cualquier gasto de nómina del mes suprime la obligación completa; la consulta no calcula saldo ni usa `periodo_desde/hasta`, y frecuencia diaria/semanal/quincenal no define ciclos adeudados. Definir sueldo por ciclo, vencimientos, abonos y pagos atrasados antes de modelar el saldo. |
| **FIN-TZ-01** | Reportes / Analítica / Finanzas | ✅ Corregido y activo en :3000: límites de rango (ventas, gastos y cierres) usan calendario America/Bogota; QA UTC, build y salud local/pública OK. `cloudflared` PID 11112 sigue activo. |
| **FIN-GASTO-DATE-01** | Analítica / Finanzas | 🟡 Semántica aclarada en UI: Analítica Caja filtra libro por fecha de registro; P&L por fecha del gasto y egresos por movimientos de Caja. Flutter responsive 5/5; fórmulas intactas. Pendiente decidir si se unifica el calendario financiero; separado de FIN-DATE-01 (fecha de pedido vs movimiento de caja). |
| **FIN-MIXED-REFUND-METHOD-01** | Caja / Reportes / Analítica | 🟡 Corregido en fuente/dist; unitaria 3/3 y E2E 1/1 en clon QA confirman devolución por el mismo medio (efectivo/tarjeta) y neto conciliado. :3000 todavía requiere activar y verificar el build probado. |
| **QA-EXTERNAL-EFFECTS-01** | QA / Notificaciones / Impresión | ✅ El modo `FOODY_QA_SIN_EFECTOS=1` ya bloquea el procesamiento inmediato de FCM (sin leer ni reintentar la cola) y el ping/drenaje de impresión. Unitarias de protección 3/3; build y E2E completa 8/8 suites, 36/36 en clon con logs de bloqueo. |
| **COC-CANCEL-NODISP-MERMA-01** | Cocina / Inventario / Pedidos | 🟡 Fuente corregida y E2E 1/1 en clon QA aislado: la cancelación omite merma N/D ya registrada por Cocina. `QA-PRINT-BYPASS-01` también corregido: en `FOODY_QA_SIN_EFECTOS=1` ping y drenaje de impresora no hacen I/O externo; unitarias 2/2, build OK. :3000 requiere activación. Pendiente precisar si `en_cocina` sin líneas iniciadas implica merma total. |
| **COC-DISPATCH-INCOMPLETE-01** | Cocina / Domicilios / Pedidos | 🟡 Fuente corregida y E2E 1/1 en clon PostgreSQL QA: ítem pendiente impide transición a `listo`; asignación manual responde 400 y búsqueda independiente `iniciado=false/PEDIDO_NO_LISTO`. Guard unitario 5/5. :3000 no se reinició, así que falta activar build y verificar runtime. |
| **PED-EDIT-01** | Pedidos / Cocina / Caja | 🟡 Fuente corregida; E2E 4/4 en clon QA: observación tras `listo` reabre Cocina; edición de cantidad, eliminación y reemplazo que dejan total bajo abono responden 409 y conservan total (16.000), abono (15.000) y líneas por rollback. :3000 aún requiere activación runtime. |
| **COC-NODISP-DOM-01** | Cocina / Domicilios / Caja | 🟡 Barrera compartida bloquea dispatch automático, asignación manual de planta, crear oferta y aceptar oferta independiente mientras exista línea 
o_disponible`. QA E2E aislada: flujo cocina→`listo` y dos vías de despacho bloqueadas; regresión secuencial 8/8 suites, 16/16 pruebas. Nest :3000 sigue sin reinicio, por lo que la API del Tunnel conserva binario anterior. Política de ajuste de línea, consentimiento del cliente y abonos sigue pendiente |
| **DOM-CANCEL-PAYOUT-01** | Domicilios / Finanzas | 🟡 Comisión y saldo del independiente se crean al aceptar oferta; una cancelación posterior no los revierte y el resumen los conserva por pagar. Confirmar si se compensa el intento/ruta cancelada antes de ajustar cálculo. |
| **DOMI-LIQUIDACION-METODO-EXTERNO-01 / DOMI-PAY-DISPLAY-01 / DOMI-OFF-CAJA-TRACKING-01** | Domicilios / Caja / Finanzas | 🟡 Ambos modos de `domicilio_ingresa_a_caja` y abono previo probados en clon. E2E 1/1: $2.000 transferencia + $6.000 efectivo liquidado en Caja; domicilio $5.000 fuera; SQL confirma `monto_pagado=13.000` y pagos/Caja $8.000. En `pendiente_liquidacion`, no se captura método del cargo externo ni aparece en `pagos_pedido`. No cambiar el modelo hasta definir si ese ledger representa pagos del cliente o recaudos Foody y quién registra dinero retenido por el domiciliario. Replay 400 sin duplicación. Clon eliminado, QA persistente intacta, :3000 sin dist actual. Ver `AUDITORIA_DOMICILIOS.md`. |
| **DOM-TIP-DIRECT-01** | Domicilios / Caja / Finanzas | 🟣 La entrega independiente no recibe ni registra propina directa al domiciliario; las líneas del pedido y domicilio se insertan con `propina=0`. No se suma a Caja ni a la comisión estimada. Decidir si se requiere comprobante/reporte; no inferir deuda ni liquidación de Foody. |
| **DOM-INDEP-SETTLE-01** | Domicilios / Finanzas | 🔴 Revalidado 2026-11-25: `pagado` nace false y no existe mutación/flujo de egreso para independientes. `POST /domiciliarios-planta/liquidar/:id` liquida CxC de planta cobrando efectivo a favor de la sede (no es pago al independiente). La API mantiene el nombre legacy `ingresos_foody_hoy` para comisiones creadas, no recaudos confirmados; `por_pagar` incluye asignaciones canceladas. Flutter ahora las etiqueta como ganancias estimadas, sin alterar el cálculo. Definir pagador, fondos, devengo, compensación por cancelación, pago parcial/medio y comprobante antes de implementar. |
| **CLIENT-DEVICE-CAP-01** | Cliente / Pedidos públicos | 🟡 Mitigación aplicada: secret capability separado del device_id, hash SHA-256 backend y posesión requerida para historial/acciones/vínculo Google; migración 092 y Web/APK reconstruidos. Pendiente riesgo de primer enrolamiento legacy, exposición ante XSS Web y recuperación/rotación. Evidencia en `AUDITORIA_CLIENTES_QR.md`. |
| **RL-GLOBAL-01** / **AQ-SCALE-05** | API / Seguridad | 🟡 Fix en fuente 2026-11-23: el guard atrapaba su propio HTTP 429 y caía al mapa local; 3 specs + build OK. API :3000 conserva proceso anterior. Tras reinicio controlado verificar el límite compartido; decidir si ante caída DB se permite fallback (fail-open) o se rechaza petición (fail-closed). |
| **RBAC-GUARD-01/02/03** | RBAC | ✅ Posesión al anonimizar, push web limitado al usuario y cola global reservada a Super Admin; falta billing staff y scopes de jobs |
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
| **INF-TUN-01** / **INF-DISK-01** / **BD-BKP-01** | Infra | 🟡 Smoke check de Cliente/Equipo/API añadido; se reprodujo 530/1033 con proceso `cloudflared` aún presente y se restauró. Token-file temporal restringido evita exponer el secreto en argv. Rotación de token pendiente por exposición en salida de diagnóstico; VPS, disco y backups siguen sin endurecer. |
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
| **Reportes/Dash** | FIN-TZ-01 ✅ | FIN-GASTO-DATE-01 🟣 · FIN-DATE-01 🟣 · DASH-TZ · CONS-REP-OPEN | REPORTES, DASHBOARD |
| **Cliente / QR** | CLIENT-DEVICE-CAP-01 🟣 | QR-FLOW, CLIENT-DOM-CONTACT | CLIENTES_QR, AUTH_JWT |
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
| **Test** | `verificar-idor-scope.ps1` — caja hermana de otra sede → 403; extendido en clon QA 2026-11-24: admin de restaurante A intenta cerrar caja de restaurante B → 403, caja B permanece abierta |

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
| **Estado** | ✅ **Cerrado F0 (2026-08-06)** — 
o_disponible` cuenta resuelto; pendientes=0 → `listo` (+ prepago → `pagado`) |
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
| **Archivo** | `dispositivos.{controller,service}.ts` · 
otificaciones.controller.ts` |

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

### PED-KEY-SCOPE-01 — clave idempotente de pedido fuera de ámbito de tenant — ✅ corregido (alto)

La clave global podía devolver metadatos y token de seguimiento de un pedido de otra sucursal. Se corrigió el scope a `(sucursal_id, clave)`, se añadió huella de payload con conflicto ante contenido diferente y se migró la tabla a PK compuesta con RLS forzada. QA aislada comprobó replay, conflicto y rechazo de reuso cross-sucursal. En la BD diaria se migraron 164 claves históricas con sucursal asociada; huella nula se admite temporalmente para idempotencia legacy. E2E completo 8/26, unitarias 31/72, build OK. Nest diario activo PID 11708. Evidencia ampliada: `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

### COC-NODISP-COMMERCE-01 — artículo no servido conserva precio — 🟣 abierto (alto)

La transición de Cocina a 
o_disponible` marca merma y catálogo, y permite cerrar a `listo`, pero no modifica importe, saldo pagado, movimientos de caja ni factura. Para domicilios se impide el despacho; en mesa/recogida no hay reconciliación específica. El borrado manual de línea recalcula subtotal/total, pero no opera reembolso ni corrige abonos ya recibidos. No se cambia dinero ni stock por conjetura: definir sustitución autorizada, anulación de línea y reembolso/compensación para estados prepago/abono. E2E cocina QA 3/3; falta cobertura de saldo financiero. Detalle en `AUDITORIA_PEDIDOS_CICLO_VIDA.md` y matriz `AUDITORIA_CONSISTENCIA_MODULOS.md`.

### PED-DELETE-NODISP-STOCK-01 — restauración indebida tras merma — ✅ cerrado (media)

`eliminarItemPedido()` trataba 
o_disponible` como pendiente de preparación y reponía ingredientes, aunque el cambio N/D ya había registrado merma. La línea N/D ahora no restaura stock. E2E QA compara inventario y total tras alta, N/D y eliminación; batería 9/9, Jest E2E 27/27, unitarias 72/72, build y Flutter relacionado 50/50. El ajuste comercial de total/reembolso permanece separado en COC-NODISP-COMMERCE-01. Evidencia: `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.
| **PED-ENCARGO-QUOTE-DATE-01** | Pedidos / Checkout | ✅ Fuente corregida: cotizar encargo antes de seleccionar fecha; creación real mantiene validación estricta. Jest 5/5; falta E2E runtime. |

| **PED-CLIENT-CANCEL-RACE-01** | Pedidos / cancelación cliente | ✅ Fuente endurecida contra transición concurrente a cocina; prueba unitaria 1/1. Pendiente build/runtime. |

**Actualización PED-CLIENT-CANCEL-RACE-01:** regresión verificada en suite Nest completa 34/34 suites, 79/79 pruebas, y build OK; cliente conserva su validación de fecha límite particular.

**DOM-EARNINGS-TRUTH-01 (2026-11-24):** corregida la presentación para no confundir comisión/ganancia estimadas con entrega, cobro o pago. Agrega estado de asignación a las filas de lectura. Flutter 22/22 y analyzer limpios; no toca cálculos. DOM-CANCEL-PAYOUT-01 continúa abierto: falta decidir devengo, pagador y compensación.

| **POS-COTIZACION-CASH-GUARD-01** | POS / Caja | ✅ Cobro inmediato para llevar requiere cotización Nest vigente; reintento visible ante error. Flutter 16/16; build QA correcto; pendiente publicar y probar con sesión real. |
| **PED-POS-REPLACE-ATOMIC-01** | POS / Pedidos / Inventario | 🟡 Fix en fuente/dist: reemplazo agrega/quita en una transacción, es idempotente y bloquea líneas cobradas o reembolsos implícitos; POS envía una solicitud. Nest 37/92; Flutter 237 aprobadas/5 E2E omitidas, POS+repo 20/20. API :3000 aún sin reinicio coordinado. |
| **PED-CANCEL-REFUND-SEMANTICS-01** | Pedidos / Caja / Pagos | 🟣 Personal elevado puede cancelar pedidos ya pagados: Caja se revierte por método/caja y `monto_pagado` se pone en cero, pero no se ejecuta ni prueba reintegro externo. Definir dueño, evidencia, estado y conciliación del reembolso para evitar doble devolución manual. El copy Kanban quedó aclarado por PED-CANCEL-COPY-01. |
| **PED-CANCEL-RBAC-01** | Pedidos / Usuarios / Permisos | 🟣 Kanban/detalle enseñaban acciones que backend rechaza; CTAs de transición ahora requieren `crear_pedido` y aprobar/rechazar QR `aprobar_pedido_mesa`. Cancelar replica en UI los límites de rol/estado/2 min para no elevados. Solo lectura + cajero con pedido antiguo verificados; responsive 4/4, Kanban 12/12, analyzer OK. `cancelar_pedido` asignado a admin/gerente sigue sin uso; definir matriz antes de cambiar privilegios. |

### PED-DISCOUNT-READY-CLOSE-01 — saldo cubierto por descuento deja estado abierto — ✅ corregido en fuente (2026-11-24)

Al reducir el total de un pedido de salón listo/pagando por debajo de lo abonado, el servicio ajustaba `monto_pagado` y caja pero conservaba el estado anterior. Ahora usa la transición central a `pagado` cuando la cocina está completa y el nuevo saldo queda cubierto; no adelanta `en_cocina` ni evita que despacho reciba domicilio listo. Nest 36/36 suites y 86/86 pruebas, build OK; pendiente activar runtime.

### FIN-DISCOUNT-REFUND-METHOD-01 — devolución por descuento sin método — 🟣 decisión pendiente

`PedidosDescuentoService` registra el exceso como `devolucion` con `metodo_pago = NULL`; Reportes/Analítica lo presentan como `sin_metodo`. Definir si debe conservar el medio original, solicitar el medio real usado por caja o distribuir pagos mixtos. Sin cambios contables hasta acordar la regla.
**Verificación extendida:** junto al estado final se libera la mesa si queda sin pedidos activos y se emite evento realtime; prueba unitaria cubre ambos efectos. Suite Nest 36/36 y 86/86, build/formato OK. Runtime aún no activado.

### PUSH-PERM-STATUS-01 — token FCM web rechazado por comparación de tipos — ✅ corregido en fuente

El resultado de `requestPermission()` es `NotificationSettings`; se comparaba el objeto con `AuthorizationStatus` y una autorización podía fallar la validación. Se compara ahora `permission.authorizationStatus`. Validación Dart focalizada sin errores/warnings; Flutter 236 aprobadas y 5 E2E omitidas por DB aislada. No se activaron permisos ni se cambió OAuth. El servicio de notificaciones queda corregido en fuente; los artefactos no se publicaron en este paso.

### DOMI-TOTAL-ENTREGAS-ACCEPT-01 — contador suma aceptación como entrega — ✅ corregido en fuente

El incremento de `total_entregas` se movió desde `responderOferta()` hasta `confirmarEntrega()`, dentro de la transacción de cierre; aceptar/cancelar ya no produce una entrega falsa. Sin alterar histórico. Suite domiciliarios 4/4; Nest completa 36/36 suites y 87/87 pruebas; build/formato OK. La fuente/dist espera activación de runtime.


| **DOM-INDEP-SETTLE-TRACE-02** | Domicilios / Caja / Finanzas / Analítica | 🟡 Unit + E2E domicilio 6/6 en clon descartable; aceptación→ruta→entrega valida pago total, movimiento de Caja y ganancias pendientes. Reportes/Analítica concilian ventas por total del pedido y cobros por movimiento (domicilio según flag). Sin liquidación real; pagador, destinatario, momento, cancelación y soporte siguen pendientes. |

**FIN-PAY-RECONCILIATION-01 addendum (2026-11-25):** parcialmente avanzado en fuente. Detalle calcula por sucursal el neto de movimientos de Caja (ventas enlazadas menos devoluciones enlazadas), separado de pagos de otros canales y propina. Devoluciones sin vínculo quedan fuera. Jest 1/1, build Nest y Flutter detalle 5/5 (320/390/820/1440), analyzer limpio. Falta cerrar conciliación por estados/canales, abonos y reconocimiento contable. No runtime activado.
# Hallazgo reciente — DOMI-MANUAL-PAY-LEDGER-01 (2026-11-25)

En la transición Admin de domicilio a `entregado`, el código registraba venta en Caja y asignaba `monto_pagado=total`, pero omitía insertar el cobro en `pagos_pedido`. El detalle administrativo agrega los métodos desde `pagos_pedido`, así que una venta cobraba en Caja pero el resumen de pago quedaba vacío. La fuente ahora inserta el importe de producto que efectivamente entra a Caja, con igual método, dentro de la transacción; no inventa registro para el cargo de domicilio fuera de Caja. Se añadió expectativa E2E. `npm run build` pasó, 2 suites unitarias cercanas aprobaron (6 pruebas) y `domicilio.e2e-spec.ts` pasó 7/7 en clon aislado. El clon se retiró. Requiere activar el nuevo dist diario bajo el procedimiento normal.

### E2E-QA-ROLE-FIXTURE-01 — resuelto

La cuenta operativa `cajero.test@foody.demo` se separó del perfil de permisos mínimos requerido por `caja-rbac-write.e2e-spec.ts`. El test usa `cajero.sololectura.test@foody.demo`; `verificar-e2e-jest.ps1` lo crea dentro del clon a partir del hash demo ya presente, asigna únicamente `ver_caja`, restaura en ese clon la matriz de `roles_permisos` leyendo las migraciones y limpia overrides del Admin/cajero operativo. La suite completa pasó **10/10 suites, 51/51 pruebas**. Se confirmó en QA fuente, con consulta read-only, 1.274 pedidos, 76 grants y cero usuario read-only sintético: rectificación, el fixture tenía 76 grants, no dos; faltaban los cuatro de 094. El clon fue eliminado, :3001 detenido y :3000 PID 7584 intacto. Ningún permiso de negocio cambió.


**OPS-RUNTIME-STALE-01 / IMP-QUEUE-CLASSIFY-01 — comprobación posterior (2026-11-25 23:12 COT):** `GET /api/v1/health` local y público HTTP 200, con estado `degradado` exclusivamente por 317 errores de impresión; base de datos, Realtime y agente conectados, 0 jobs pendientes y 1 enviado en 24 h. Se confirma que no es una caída de API/Tunnel; requiere clasificar los errores históricos antes de actuar. PID Nest 7584 precede al `dist/main.js`; no prueba el código fuente actual. Cloudflared 8940 y web local/pública (8080/8081, PID 9892/8480) activos. Sin reencolar, reiniciar ni escribir datos.
