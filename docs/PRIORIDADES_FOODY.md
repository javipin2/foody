# Foody — Prioridades del sistema (lista viva)

- [ ] **PED-COMBO-KDS-STOCK-01 · Alta (parcial en fuente)** — migration 095 + snapshot ya conectan creación/agregado, stock/COGS, revalidación de QR pendientes, KDS e impresión en una sola línea cobrable. La inspección confirma que KDS aún usa un único `pedido_items.cocina_id` y `estado_cocina`; `componentes_snapshot` no tiene estación y no existe tarea por cocina. Catálogo y Nest bloquean combos de varias cocinas con error explícito. Antes de enrutar: modelar tareas por estación subordinadas a la línea cobrable, snapshot de cocina/componente, estados agregados e impacto en inventario/impresión. Definir qué hacer ante componente no disponible (sustituir o invalidar/cancelar el combo y ajustar su cobro). La devolución al cancelar ya usa el ledger de movimientos de venta. Faltan E2E de multiestación y no activar runtime hasta aplicar migraciones en QA.
- [ ] **PED-KITCHEN-POSTCOMMIT-01** — alta confirma DB antes de publicar eventos. Si consulta de cocinas falla, antes se cortaba el método y no intentaba encolar impresión; ahora captura/loguea la falla y conserva el enqueue, realtime por cocina aislado. Nest pedidos+impresión 20 suites/68; build OK; Flutter POS 20/20 + analyzer limpio. Falta runtime :3000 y smoke con agente/impresora real.
- [ ] **PED-QUOTE-RACE-01** — cotizaciones Checkout podían aplicar respuestas fuera de orden; ahora Flutter descarta respuestas y errores viejos por revisión monotónica. Backend recalcúla desde catálogo por sucursal, ignorando el precio cliente como autoridad. Checkout responsive 1/1 + analyzer limpio. Falta cubrir cambio de catálogo entre estimación y creación y confirmar el importe antes de aceptar un pedido si varió.
- [ ] **POS-TOTAL-DRIFT-01** — corregido y probado en fuente: POS manda `total_esperado` (Nest lo exige en cobros staff para llevar); compara en transacción antes de escribir pedido/pago/Caja y, ante diferencia, el POS refresca el total y exige segunda confirmación. Backend 15 pruebas focales + build; Flutter repositorio+POS 27/27 + analyzer limpio. Falta E2E transaccional en BD QA y activación coordinada de panel/API.
- [ ] **PED-ITEM-PAY-ALLOC-01** — proteger asignación de pagos por ítem: borrar/modificar importe de una línea cobrada podía borrar/cambiar su vínculo aunque el abono total cupiera en otras líneas. Fuente bloquea borrado/cambio monetario si `estado_cobro=cobrado` o existe `pago_pedido_items`; notas siguen permitidas y una selección de toppings idéntica ya no recalcula su precio snapshot. E2E de Caja/pedidos quedó incluido en la suite QA completa: 12 suites/54 pruebas pasaron. Aún falta cobertura de edición concurrente con pagos asociados. La protección de inventario por línea se sigue en PED-ITEM-STOCK-LEDGER-01.
- [ ] **PED-ITEM-STOCK-LEDGER-01 · Alta (parcial en fuente)** — migration 096 agrega referencia diferida de movimientos a línea, tipo `devolucion` y marcador `stock_snapshot_version`; altas nuevas, adiciones y aprobación QR preservan IDs de línea. Cancelación compensa saldo neto por ingrediente y evita duplicar la devolución por reintento. El FK usa `ON DELETE SET NULL` para mantener los movimientos al borrar una línea. Analítica muestra stock devuelto aparte. Verificado: backend 23 suites/85 pruebas + build Nest; Flutter analítica 8/8 + analyzer; E2E en clon aislado con migraciones 095/096: 12 suites/54 pruebas. La suite ahora prepara/cotiza el pedido del POS usando el endpoint autoritativo y datos de inventario QA. No se aplicó migración a la DB diaria ni se reinició :3000. Pendiente: snapshot/conciliación para cambios de receta y edición individual, además de combos con varias unidades.

- [x] **REP-ANALYTICS-PLAN-LINK-01** — CTA Reportes→Análisis indica «Análisis · Pro» si el módulo no está habilitado, y «Análisis» cuando sí. 11/11 tests + analyzer limpio; Cliente/Equipo publicados, ruta `/admin/login`, FCM y salud API 200 por Tunnel; SHA público/local de Equipo coincide. Tunnel PID 8940 intacto; no OAuth/datos. Nest sigue con runtime previo (no requiere este fix).

- [ ] **REP-AUDIT-TZ-01** — cuatro fuentes del timeline usaban día UTC, desfasando el calendario de Bogotá. Fuente corregida con límites semiabiertos compartidos e inicio default local; Nest 3/3 + build OK + CTE QA read-only. Dist compilado 22:03:45, :3000 PID 7584 arrancó 13:50:31; activar con reinicio coordinado y probar endpoint. Tunnel :8940 intacto.
- [ ] **OPS-RUNTIME-STALE-01** — Nest PID 7584 arrancó 13:50:31 y dist/main.js cambió 22:08:55; los fixes posteriores no están en runtime :3000. API local/pública, Cliente/Equipo local/públicos 200; cloudflared PID 8940 activo. Falta reinicio coordinado + smoke semántico. No reiniciar sin ventana porque se interrumpe acceso operativo por Tunnel.
- [ ] **WOMPI-WEBHOOK-REFERENCE-01** — webhook recurrente podía no encontrar pago: intenta payment_link_id/SKU aunque Wompi devuelve la `reference` enviada al crear la transacción. Fuente ahora tiene fallback restringido a pago pendiente; prueba unitaria 1/1 y typecheck OK. Falta E2E en QA aislada y activar runtime. No se hicieron pagos ni se tocaron credenciales.
- [ ] **WOMPI-RENEWAL-CLAIM-01** — cron y endpoint manual comparten reserva transaccional por suscripción, revisan pagos `pendiente/aprobado` de últimos cinco días y limitan reintento a 20 h; UI ya explica por qué no inicia otro cobro. Unitarias backend 4/4 + typecheck y Flutter Plan y pagos 6/6 + analyzer. E2E aislada y runtime pendientes. No se invocó Wompi ni se escribió DB.
- [ ] **DOMI-MANUAL-PAY-LEDGER-01** — fuente corregida: entrega marcada manualmente por Admin registra el mismo importe/método en `pagos_pedido` y Caja, propina 0; E2E exige conciliación del resumen frente al movimiento. Build OK, unitarias 2/6 y domicilio E2E 7/7 en clon desechable. Falta activar el dist al reiniciar Nest bajo el procedimiento normal; `:3000` PID 7584 sigue en ejecución con runtime previo.- [ ] **CAJ-CXC-DOMI-ROUTE-01** — La ruta genérica de Caja podía liquidar CxC de domiciliario dejando pedido y `pagos_pedido` sin actualizar. Fuente protege el endpoint y la UI dirige a Domiciliarios; Caja backend 7 suites/16 pruebas + Flutter 19/19 y build/analyzer OK. `foody_diseno_qa` read-only no tiene esos registros. Pendiente E2E aislada y activar runtime :3000.
- [x] **E2E-QA-ROLE-FIXTURE-01** — launcher crea en el clon una cuenta independiente de caja read-only y reconstruye la matriz de grants desde migraciones; `cajero.test` conserva permisos operativos. Suite completa 10/10 suites, 51/51 pruebas; clon y :3001 retirados, QA fuente y :3000 intactos.
- [ ] **E2E-SUCURSAL-READ-01** — spec E2E read-only comprueba 403 del gerente al listar Pedidos y Cocinas de la sede hermana. Política base 4/4 unitarias, `tsc` compila y Jest descubre la suite; pendiente ejecutar con API :3001 + clon descartable. Hoy solo existe la DB QA fuente, que no se usó ni alteró.

- [x] **ANA-PNL-COMP-FILTER-01** — Rentabilidad en el período anterior aplicaba COGS sin filtros mientras los ingresos sí los respetaban; comparación de utilidad podía mezclar productos/categorías. Corregido para reutilizar filtros/rango del período actual; Jest focalizado 3/3 y build Nest OK. Runtime :3000 no activado ni comprobado.
- [ ] **FIN-PAYROLL-FREQUENCY-01** — Nómina: el resumen oculta al empleado tras cualquier gasto origen=nomina del mes aunque frecuencia sea diaria/semanal/quincenal y pago/periodo sea parcial. Definir unidad de sueldo base, ciclos/vencimientos y saldo antes de cambiar reglas; ver MASTER y finanzas.service.ts.
- [ ] **ANA-PNL-EXP-SCOPE-01** — cuando se filtran pedidos, Rentabilidad reduce ventas/COGS pero resta todos los gastos de la sede en el período. La pantalla aclara que no hay prorrateo; definir política antes de atribuir utilidad neta a un segmento. Sin cambio de fórmula ni datos.
- [ ] **DOMI-PAY-DISPLAY-01** — Fuente corregida: apps planta/independiente e historial planta exponen pagos mixtos reales con importe por método, agregados bajo sucursal; fallback legacy. Propina aparte/excluida, sin alterar cobro/Caja/`metodo_pago`. Nest 3/3 + build; Flutter 2/2. SQL read-only QA: 44/44 entregas planta con resumen; snapshot QA tiene 63 pedidos con métodos mixtos y escalar discordante (no extrapolar a producción). Requiere activar dist :3000 y verificar autenticado por Tunnel. Evidencia: `AUDITORIA_DOMICILIOS.md`.
- [ ] **WOMPI-EXT-TIMEOUT-01** — Abierto: 4 `fetch` del proveedor sin timeout. Webhook por referencia y reserva concurrente están corregidos en fuente (WOMPI-WEBHOOK-REFERENCE-01 / RENEWAL-CLAIM-01); falta persistir estado ambiguo para poder limitar `POST /v1/transactions` sin perder una aprobación ni reintentar doble. No se presume idempotencia de ese endpoint; ver MASTER y auditoría de rendimiento.
- [ ] **DOMI-PAY-LEGACY-METHOD-01** — Fuente conserva primer método de `pagos_pedido` por `(pedido_id,sucursal_id)`; el recaudo de CxC queda como efectivo aparte. Unitarias 2/2, build OK y E2E 1/1 en API :3001 + clon: abono $2.000 transferencia, CxC/liquidación $6.000 efectivo, método escalar transferencia y replay HTTP 400. API :3000 sigue con runtime anterior. Ver `AUDITORIA_DOMICILIOS.md`.
- [x] **CAJA-LOAD-80-01** — La lista Caja solo solicita hasta 2 páginas para presentar los 80 movimientos recientes, en vez de descargar el historial y truncarlo; el total de cierre no cambia. Repositorio + pantalla Caja 18/18; analyzer limpio.
- [x] **GEO-EXT-TIMEOUT-01** — Photon limitado a 5 s; timeout 504, fallo upstream 502, sin reintento y sin cachear fallos. Unitarias 3/3; regresión Nest completa 63 suites/175 pruebas y build OK. Ver MASTER y `AUDITORIA_RENDIMIENTO_PUNTA_A_PUNTA.md`.
- [x] **DB-POOL-ACQUIRE-TIMEOUT-01** — `pg.Pool` limita a 5 s adquisición/conexión, configurable vía `DB_POOL_CONNECT_TIMEOUT_MS`; sin límite de SQL ya iniciado. Unitarias 2/2; Nest 63/175 y build OK. Falta instrumentar conexiones activas/en espera y calibrar `DB_POOL_MAX` con DB+régimen de réplicas antes de VPS.

- [ ] **ORD-PAY-SUMMARY-01** — agregado al detalle API `pagos_resumen` por sucursal y `propina_recibida` aparte. E2E autenticado pasa en clon desechable para split efectivo/tarjeta + pago final transferencia; total $8.000, propina $1.400 aparte. Revalidación: Flutter 295 aprobadas/5 omitidas, Nest 61/169 y build OK. Local y Tunnel siguen HTTP 200, pero PID 7584 arrancó 13:50:31 y `dist/main.js` se actualizó a 16:52:42; por tanto, proceso activo desfasado. Intento de reinicio exacto rechazado por control de seguridad; no cambió estado. Pendiente activación coordinada y click-through navegador autenticado.
- [ ] **FIN-PAY-MULTITICKET-01** — corregido: cada pago de cuenta mesa se distribuye a cada pedido/ticket en `pagos_pedido`, igual que Caja; split por ítems vincula la evidencia al pedido. `pagos_abonos` incluye `numero_pedido` bajo scope de sucursal y la UI lo muestra en el historial desplazable. E2E Caja 10/10, mesa sheet 9/9 responsive/analyzer OK; queda activar/verificar el nuevo dist en `:3000` tras reinicio coordinado.
- [ ] **FIN-PAY-RECONCILIATION-01** — la traza de devoluciones vinculadas confirmó `pedido_id` + `sucursal_id`. Detalle de pedido separa devoluciones vinculadas y recaudo neto de Caja (ventas de Caja menos devoluciones enlazadas), sin mezclar otros medios de `pagos_pedido`. Pruebas focalizadas backend y UI responsive pasan. No incluye devoluciones sin pedido ni resuelve reconocimiento contable/abonos/canales; continuar auditoría antes de llamarlo conciliación completa.
- [ ] **COST-RECIPE-LOAD-FAIL-01 / COST-RECIPE-EDIT-RESP-01 / COST-RECIPE-INTEGRATION-01** — carga fallida ya no se confunde con receta vacía; reintento y editor bloqueado hasta respuesta válida. Pruebas encontraron y corrigieron overflow del resumen/stock, selector y fila «Preparación [producto]» en acompañamientos; el paso activo sigue el contexto visible. Editor compacto: Ingredientes abierto y Preparaciones/Empaques plegables; escritorio mantiene grupos abiertos. Suite Costos 17/17: payload hasta repositorio en 320/390/820/1440 y composición de detalle con repositorios fake (sin red externa), analyzer limpio. Pendiente persistencia y recálculo autenticados en el API; no se escribió DB.

- [x] **COC-PRODUCT-KITCHEN-ROUTE-01** — guard de sede/cocina/categoría en creación, edición, activación, bebidas y copia de menú; bloqueo de baja de cocina con productos o ítems operativos; formulario evita venta si no hay cocina. Nest unitarias focalizadas 11/11 y E2E real Catálogo→pedido→ticket Cocina→listo 1/1 en clon desechable; clon retirado y QA fuente intacta (3 restaurantes). La afirmación anterior de que PID 7584 ejecutaba el `dist` reciente no es válida: ese proceso inició 13:50:31 y `dist/main.js` se recompiló 16:52:42; salud 200 no acredita frescura. Fix listo en fuente, activación live pendiente. Ver `docs/archivo/auditorias-prompts/AUDITORIA_ENRUTAMIENTO_COCINA.md`.
- [x] **RBAC-CAJA-WRITE-01** — lecturas Caja usan `ver_caja`; escrituras de CxC/gastos/devoluciones usan `gestionar_caja`, apertura/cierre/retiro mantienen permisos propios. Migración 094 aplicada a DB local activa: los 4 roles operativos verificados; 0 overrides en DB principal. E2E en clon tras migración: override `ver_caja` conserva lectura y recibe 403 al escribir (2/2); admin llega a validación DTO sin escribir. Runtime :3000: Cajero GET Caja 200 y POST malformado 400; admin POST malformado 400. UI Caja 17/17 responsive, analyzer focalizado limpio. Clon descartable eliminado, QA persistente y Tunnel conservados.
- [x] **QA-CROSS-ORCH-SAFETY-01** — flujo cruzado restringido a API :3001 + clon `foody_diseno_qa_codex_*`; preflight detecta scripts con destinos fijos. Parser limpio, guard a QA compartida probado y flujo integrado 12/12; clon desechable eliminado, QA compartida intacta. En el primer intento un subguion viejo tocó :3000; los datos sintéticos se limpiaron y la configuración actual de impresora demo quedó modo archivo/IP nula (valor anterior desconocido). Sin Wompi real ni cambios a OAuth/Tunnel. Ver MASTER y AVANCE 2026-11-25.
- [x] **KDS-READY-AGE-01** — “Listos” muestra antigüedad desde la creación, ámbar >24 h / rojo >30 d, y aclara que no es tiempo desde preparado; KDS 17/17 responsive + analyzer. Publicación comprobada visualmente en Chrome autenticado por Tunnel; bootstrap público/local 200 con SHA coincidente. Los 6 tickets históricos visibles >30 d siguen sin clasificación y no se modifican automáticamente; esa revisión operativa queda aparte. Ver `docs/archivo/auditorias-prompts/AUDITORIA_COCINA_KDS.md` y `AUDITORIA_ESTADOS_OPERACION_STALE.md`.
- [ ] **PERF-WEB-ASSET-01** — Bundle Equipo 6,96 MB descomprimido, Brotli, 3/3 HTTP 200; Inicio paraleliza cuatro fuentes (widget 10/10). Waterfall warm autenticado KDS: DOMContentLoaded 634 ms, Load 996 ms; 71 solicitudes acumuladas, 15,5 kB transferidos/16,8 MB recursos, mayormente caché. OPTIONS público previo carecía de `Access-Control-Max-Age`; fuente Nest fija `maxAge:300` y build pasó. En API QA :3001/DB clon, OPTIONS verificó `Max-Age:300` con allow-origin y credenciales sin cambios. API pública :3000 aún responde sin ese header; activación pendiente de reinicio normal y nueva verificación. No hay p50/p95 ni FCP Flutter. Ver auditoría de rendimiento.
- [x] **CAJ-CASH-RECON-01** — arqueo compara efectivo físico con movimientos clasificados como efectivo; electrónicos no se suman al saldo esperado. Cuenta completa se cobra aparte de la propina voluntaria (confirmado); la custodia del efectivo de propinas sigue pendiente. Fuente activa en Nest :3000 tras build reciente. Ver `docs/archivo/auditorias-prompts/AUDITORIA_CUADRE_EFECTIVO.md`.
- [ ] **FIN-TIP-MIXED-ALLOC-01** — decisión confirmada: el total obligatorio se cobra completo y la propina voluntaria queda aparte; no se conserva si el pago se difiere. Con pagos mixtos, Nest actualmente prorratea propina por proporción de la cuenta sin preguntar dónde se recibió. Antes de reportar/liquidar por canal, decidir entre no atribuir canal o capturarlo independientemente.
- [ ] **DOMI-SETTLEMENT-VS-PAID-01** — `pendiente_liquidacion` deja `monto_pagado` igual aunque el pedido ya fue entregado; al liquidar puede ponerlo en total mientras la CxC solo cubría producto. El filtro Analítica «Solo pendiente de pago» consulta ese escalar e incluye pedidos `entregado`. Decidir si significa pago del cliente o rendición a Foody y separar conceptos antes de cambiar dinero/reportes. Ver `AUDITORIA_DOMICILIOS.md`.

- [ ] **DOMI-FIADO-COVERAGE-01** — ambos modos previos y el ciclo de abono previo/liquidación pasan en clones desechables. Nuevo E2E 1/1: pedido $13.000 (producto $8.000 + domicilio $5.000), abono $2.000 transferencia, CxC producto $6.000, liquidación efectivo $6.000; pagos/Caja $8.000, CxC pagada, pedido `monto_pagado=13.000`, `metodo_pago=transferencia`, segundo POST HTTP 400 sin duplicar. SQL independiente confirmó importes; clon eliminado y QA fuente intacta. Hallazgo abierto **DOMI-OFF-CAJA-TRACKING-01**: el domicilio de $5.000 fuera de Caja no aparece en `pagos_pedido` y no captura método en ruta `pendiente_liquidacion`; decidir libro/propietario contable antes de cambiarlo. Runtime :3000 desfasado. Ver `AUDITORIA_DOMICILIOS.md`.

- [x] **DASH-EMPTY-UX-01** — dashboard aclara semana de ventas en cero y compacta mix/top vacíos; pruebas 4 tamaños 4/4 y analyzer limpio. Build Equipo publicado; fuente backend de 7 fechas sigue esperando activación runtime.
- [x] **WEB-START-FCM-REJECTION-02** — capturar Future de lectura de notificación inicial; recarga autenticada Equipo/Tunnel verificada sin pantalla en blanco. Analyzer limpio, build Release; SHA build/local/público coincide. API Nest sigue antigua. Evidencia `docs/archivo/auditorias-prompts/AUDITORIA_ARRANQUE_WEB.md`.
- [x] **COC-REPRINT-CONFIRM-01** — pedir confirmación antes de crear copia física; cancelar sin efecto y aceptar una solicitud. KDS 16/16 + analyzer limpio; sin prueba térmica real. Evidencia en `docs/archivo/auditorias-prompts/AUDITORIA_COCINA_KDS.md`.
- [x] **DASH-7D-ZERO-01** — dashboard de ventas completo para siete fechas locales (cero en días sin venta), límites Bogota explícitos y copy que distingue total de alertas vs primeras 8. Backend 7/7 + build; widget 9/9; API activa todavía anterior. Evidencia en `docs/archivo/auditorias-prompts/AUDITORIA_DASHBOARD_SERIE_7D.md`.

> **Documento único para tachar avance.** Consolida `MASTER_STATUS`, `INFORME_MAESTRO` (F0–F8), `ROADMAP_TERMINAR_FOODY` (P0–P3), `CHECKLIST_F5_GOLIVE`, `REMEDIACION_NEST_AUTH_2026-08-07` y auditorías abiertas.
>
> **Regla:** trabajar **de arriba hacia abajo**. No saltar a “pulido Flutter” si P0/F5 está abierto y el objetivo es vender/operar.
>
> Al cerrar un ítem: `- [ ]` → `- [x]`, actualizar **Estado**, 1 línea en `AVANCE_PROYECTO.md` y el ID en `MASTER_STATUS.md`.

**Última actualización:** 2026-11-25 — CAJ-CXC-DOMI-ROUTE-01 protege liquidación de domiciliario por Caja general; DOMI-SETTLEMENT-VS-PAID-01 requiere decisión sobre semántica de `monto_pagado`. La política automática bloqueó el arranque QA `:3001`; clon temporal creado en esta prueba ya fue retirado. Hallazgos impresión cola previos: 317 errores terminales (316 `ECONNREFUSED` con 10 intentos, 1 registro anómalo vacío), 0 pendientes; 3 jobs en últimas 24 h, uno ligado a domicilio `asignado` desde agosto. Salud profunda degradada solo por esos errores; API/Tunnel vivos, Nest `scripts/verificar-backend.bat` exit 0. No se reintentó ni alteró la cola. Ver `AUDITORIA_IMPRESION_COLA.md`.
**Criterio transversal agregado (2026-11-25):** rendimiento y capacidad son parte explícita del objetivo. Reusar `docs/AUDITORIA_RENDIMIENTO_PUNTA_A_PUNTA.md` como fuente de evidencia; separar latencia de PC/Tunnel de Flutter, Nest, pool/SQL y servicios externos; medir p50/p95, errores y CPU/RAM/conexiones en QA aislada; corregir el cuello confirmado y repetir solo las pruebas afectadas. Conservar PC + Docker + Cloudflare Tunnel hasta la migración posterior a VPS; medir capacidad para una referencia inicial 2 vCPU/8 GB con carga representativa antes de estimar concurrencia. Caché/Redis solo ante beneficio medido y con invalidación/versionado al cambiar precios, menú o disponibilidad; Nest conserva autoridad de precio, stock, pagos y finanzas. No volver a recorrer ni revalidar hallazgos cerrados salvo que el código o runtime haya cambiado.
**Hallazgo de operación agregado (2026-11-25):** se observó una mesa y el pedido `FDY-2026-0016` aún contados como activos tras 113 d 5 h. No se alteraron registros; confirmar si son QA/demo y definir tratamiento. El ajuste de aislamiento del arranque Firebase Messaging ya fue publicado/verificado local y Tunnel.
**Próximo foco recomendado:** clasificar con el founder si la BD local y las operaciones envejecidas son datos QA/demo antes de cualquier mutación; revisar los pedidos activos (>30 días), las 7 cajas abiertas, 2 sesiones activas y 3 fallos de impresión recientes. Después, activar Nest con un reinicio coordinado y comprobar semántica real del cobro pendiente (el verificador de salud no prueba que se cargó el último build). Luego continuar con revisión visual autenticada, conciliación financiera, política de liquidación de propinas/ganancias y rendimiento autenticado con waterfall/SQL en QA. Detalle de estado: `AUDITORIA_ESTADOS_OPERACION_STALE.md`.

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


**DOM-INDEP-SETTLE-TRACE-02 (2026-11-25):** unit + E2E domicilio 6/6 en clon temporal validan aceptación, entrega independiente, monto pagado, Caja, ganancias pendientes y reconciliación por Reportes/Analítica. La liquidación continúa pendiente de definición comercial/contable; no reconocer la comisión como ingreso cobrado.

- [ ] **WOMPI-TX-LOOKUP-AUTH-01** — consulta de estado usaba llave pública; Wompi exige llave privada para `GET /transactions/{id}` y devuelve 404 con `pub_*`. Fuente corregida y prueba focalizada 2/2 + typecheck Nest OK. Falta verificación aislada de integración/runtime; sin llamadas a Wompi ni credenciales reales.
