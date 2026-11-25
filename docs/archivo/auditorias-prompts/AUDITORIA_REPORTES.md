# Auditoría — Reportes y analítica (Prompt 20)

## Revalidación DOM-INDEP-SETTLE-01 — dirección y evidencia del dinero (2026-11-25)

La comisión del servicio de domiciliario independiente no es una suscripción de Foody ni una comisión sobre el valor de los productos: `DispatchService.calcularGanancias(costo_domicilio)` aplica `comision_domiciliario_porcentaje` (configuración global, fallback 15%) al costo del domicilio y deja el remanente como `ganancia_domiciliario`. `DomiciliariosIndependientesService.responderOferta()` registra ambos importes cuando se acepta la oferta, antes de entrega, con `pagado` en su default `false`.

La lectura de ganancias del independiente (`GET .../ganancias`) y el resumen administrativo no tienen operación complementaria de pago. En la revisión de fuentes no hay `UPDATE ganancias_domiciliario.pagado`, inserción de gasto/egreso, comprobante ni endpoint para liquidar independiente. En cambio, `POST /domiciliarios-planta/liquidar/:domiciliario_planta_id` liquida cuentas por cobrar de un domiciliario de planta: marca las CxC pagadas e inserta `pagos_pedido`/movimiento `venta` en efectivo, es decir, registra una entrada a Caja del negocio. No representa el pago que Foody/restaurante tendría que hacer al independiente.

**Coherencia de reportes:** `SuperAdminService.estadisticas()` suma `ganancias_domiciliario.comision_foody` creadas hoy y las expone con el nombre legacy `ingresos_foody_hoy`; el evento es aceptar oferta, no cobrar la comisión. La UI ya evita presentar esto como ingreso: el KPI se titula “Comisión estimada hoy” y aclara que no confirma recaudo. El resumen de sede suma `por_pagar` de filas `pagado=false` sin filtrar el estado de la asignación, de modo que cancelaciones pueden continuar en el saldo estimado. Ninguna cifra acredita por sí sola que se haya cobrado una comisión o pagado una ganancia.

**Decisión comercial/contable pendiente:** definir quién contrata y paga al independiente, origen de fondos, momento de devengo (aceptación/entrega/recaudo), regla de cancelación antes/después de desplazamiento, pagos parciales, medio y soporte, y cuentas/impacto en Caja/P&L. No cambiar el cálculo ni crear liquidación hasta resolverlo. La etiqueta `Liquidar` de UI es explícitamente de fiados de planta; no hay evidencia de E2E payout para independientes. Se verificó estáticamente el source; no se hicieron escrituras ni cambios de dinero.

## Complemento — REP-DEFAULT-DATE-TZ-01 (2026-11-24)

`ReportesService.resolverRango()` usaba `new Date().toISOString().slice(0, 10)` para el rango predeterminado. Con el host en `America/Bogota`, entre 19:00 y 23:59 locales ya es el día siguiente en UTC; “hoy” quedaba adelantado, aunque los filtros SQL interpretan días del negocio en `America/Bogota`.

Se corrigió el default para derivar la fecha con `Intl.DateTimeFormat` y `SQL_TZ_NEGOCIO`; fechas pedidas explícitamente conservan la conversión anterior. Test controla el reloj en `2026-11-25T04:30Z` y espera `hasta=2026-11-24`, `desde=2026-11-18`. Build OK; Nest 29 suites/66 pruebas. Sin lecturas ni escrituras de datos del negocio. API :3000 activada PID 14644, salud local/pública HTTP 200, Tunnel PID 11112 y `.env` hash intacto; Flutter global 220/5 omitidas.

## Complemento — DOM-READ-PARALLEL-01 (2026-11-24)

En `DomiciliariosAdminScreen._cargarLiquidacion()`, `GET /domiciliarios-planta/liquidacion/:sucursal` se esperaba antes de iniciar `GET /domiciliarios-planta/domicilios/:sucursal`. Son lecturas independientes; se cambió el cliente Flutter a `Future.wait`, conservando contratos, cálculos y manejo de error. Se elimina un RTT serial en el par, pero no se midieron milisegundos con la red externa.

**Evidencia:** test de `domiciliarios_admin_screen_test.dart` retiene ambas respuestas con `Completer` y verifica el inicio concurrente; módulo 5/5, Flutter global 212 aprobadas/5 omitidas, analyzer focalizado limpio. Launcher recompiló Cliente/Equipo; los bundles públicos coinciden byte a byte con local: Cliente SHA-256 `826DA39FBE0316C0D6560730A9B1B9CC4030FE490353C2734FDC06BED401D5DD`, Equipo `9A19FE5B17816DE729381A7CE1C34BB5EC3A23BF55FA0F31F3C5259BD1D8356E`. Seis endpoints HTTP 200; Nest :3000/Tunnel continuaron activos.

## Complemento — DOM-STALE-01 (2026-11-24)

`DomiciliariosAdminScreen._cargar()` ahora distingue carga inicial de refresh: únicamente la primera vista usa skeleton; al refrescar se retiene el contenido existente, y si falla la API aparece aviso inline con reintento, sin ocultar los datos ya recibidos. La prueba retiene el GET en vuelo para verificar continuidad y después inyecta excepción para comprobar la vista stale. Domiciliarios 6/6, Flutter global 213 aprobadas/5 omitidas, analyzer limpio. Cliente/Equipo release reconstruidos y verificados byte a byte contra sus URLs públicas; ambos sitios y salud API local/público HTTP 200. No se modificó backend.

> **Fecha:** 2026-08-06  
> **Alcance:** cifras API vs BD cruda, filtros combinables, rendimiento histórico, umbrales de alertas.  
> **Verificación:** `scripts/verificar-reportes-analitica.ps1` (OK, exit 0).  
> Relacionados: `verificar-analitica.ps1`, `verificar-coherencia-pedidos-analitica.ps1`, `verificar-reportes-export.ps1`, `docs/ALERTAS_AUTOMATICAS.md`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

## Complemento — validación del filtro COGS por estado (2026-11-24)

La revisión de `AnaliticaService.inicio()` y `clausulasPedidos()` confirmó que el COGS del período actual ya excluye cancelados/rechazados por defecto mediante `extraM`, igual que la consulta de ventas netas. Si se solicita un filtro explícito de estados, ambos caminos lo respetan. Por tanto, no había defecto de producción que corregir; añadir una exclusión fija habría contradicho filtros legítimos de estado. Se retiró esa adición y quedó `analitica-rentabilidad-cancelados.spec.ts` para proteger ambos contratos.

**Verificación:** prueba focalizada 2/2; Nest build y suite unitaria 29 suites/65 pruebas. Flutter global 219 aprobadas/5 omitidas, sin fallos; analyzer global sin errores/warnings, 36 infos existentes. API :3000 sincronizada con build actual, PID 17080; salud local/pública HTTP 200, Tunnel PID 11112 y `.env` sin cambios. No se modificaron cálculos ni datos del negocio.

## Complemento — ANA-CASH-COHORT-UX-01: diferenciar saldo de pedidos de descuadre de turno

Las pestañas Caja de Analítica y Reportes comparan el valor de pedidos creados en el rango con movimientos de venta/devolución ligados a esos pedidos, atribuidos por `pedidos.created_at`; los movimientos sin pedido usan su propia fecha. Es un saldo de la cohorte de pedidos consultada y puede cambiar cuando se registren cobros posteriores. No es el descuadre físico del cajón ni el efectivo recibido dentro del rango. El descuadre real del turno es `cajas.diferencia` al cerrar. Se aclararon títulos, subtítulos y tooltips en ambas pantallas y el API explica la semántica; en Análisis se quitó el acento de alerta asociado a `descuadre_relevante`. Se conservan cálculos y contratos numéricos.

**Verificación:** widgets de Reportes, Análisis y exportación 13/13; Caja de Análisis cubre 320, 390, 820 y 1440 px. Nest `reportes-periodo-caja.spec.ts` + `analitica-caja-gastos.spec.ts` 3/3 comprueban SQL/metadata; `npm run build` OK; Flutter analyzer limpio. PDF/CSV usan “Ventas de pedidos”, “Cobros netos asociados” y “Ventas menos cobros”; no se cambiaron datos ni transacciones. No se reinició el proceso :3000, por lo que la metadata backend nueva queda compilada pero requiere activación para verse en runtime.

### Complemento — FIN-DATE-01: doble lectura de cohorte y recaudo (2026-11-25)

Reportes conserva ventas y cobros asociados a pedidos creados en el rango, y añade `recaudo_periodo`: suma ventas menos devoluciones cuya fecha real de movimiento (`movimientos_caja.created_at`) cae en el rango local de `America/Bogota`. Este segundo dato puede contener pedidos creados antes del rango. Así se exponen ambos universos sin reemplazar uno por otro ni llamar “descuadre” a su diferencia; el arqueo físico continúa en `cajas.diferencia`. La nueva lectura usa un rango sobre timestamp de movimientos; no toca datos ni transacciones. Las propinas siguen separadas y excluidas de ambos importes. Análisis no presenta el nuevo recaudo porque sus filtros de producto/estado pueden implicar una asignación que el movimiento de pago no contiene.

**Verificación:** helper de rango y contrato Nest 6/6; Reportes responsive 8/8; exportación PDF/CSV 2/2; analyzer focalizado limpio y `npm run build` OK. FIN-DATE-01 queda parcialmente resuelto en Reportes; sigue pendiente decidir cuál de las dos fechas debe ser la vista predeterminada para conciliación y si Análisis debe exponer un flujo general cuando no haya filtros de ítem.

## Complemento — FIN-TIP-REPORT-01, propinas fuera de ventas y utilidad

La caja informa `propinas_turno` por separado del saldo esperado de venta. En el código revisado, analítica y reportes calculan ventas desde `pedidos.total` o las líneas de `pedido_items`; no suman `pagos_pedido.propina` a ventas netas, ingresos de producto o utilidad. Esto es coherente con la regla confirmada por el usuario: el pedido se cobra completo y la propina es voluntaria y aparte. No presentar la propina como venta ni ingreso de Foody. Aún no existe un reporte consolidado para seguimiento/liquidación de propinas, ni una política contable confirmada sobre su beneficiario, retención o tratamiento en cancelaciones. La propina en cobros unificados de mesa puede quedar asociada a un pedido representativo; resolver el modelo de asignación antes de ofrecer análisis por pedido. Evidencia: SQL de `AnaliticaService`, consultas de reportes y cierre `CajaService.cerrar()`.

## Complemento — ANA-FILT-PROD-01, ventas por producto

La afirmación histórica de que el filtro `producto_ids` sumaba el ticket entero quedó obsoleta. El código actual detecta filtros de ítem, agrupa la consulta sobre `pedido_items`, aplica `pi.producto_id = ANY(...)` y suma `SQL_VENTA_LINEA_ITEM`; el header sin filtros de ítem conserva `SUM(pedidos.total)`. Se agregó una prueba SQL de regresión que verifica este contrato. Así, la métrica filtrada representa las líneas de producto coincidentes (incluidos extras según la expresión de ventas por línea), no el total del ticket. Revalidar si se modifica el universo de ventas o la semántica de filtros.

## Complemento — CAJ-REFUND-TRACE-01, efecto en P&L

La devolución manual de Caja se registra como movimiento neto de efectivo, pero la pantalla no la enlaza a un pedido y siempre la etiqueta como devolución en efectivo. El P&L calcula ventas desde pedidos no cancelados y COGS desde sus líneas; por tanto un reembolso manual no reduce ventas/utilidad del P&L. Reportes sí revela la diferencia contra movimientos netos de caja, pero no permite atribuirla a una venta o artículo. La política de reconocimiento contable, medio de reembolso, vínculo al ticket/ítem y destino del producto (stock o merma) queda pendiente. Evidencia y decisión de no alterar reglas en `AUDITORIA_CAJA.md` § CAJ-REFUND-TRACE-01.

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| ¿Cifras = datos crudos BD? | **Sí** para header financiero/resumen (`SUM(pedidos.total)`, count, descuentos) y top producto con extras. Mismo SQL que Nest. |
| ¿Filtros combinables? | **Analítica: sí (AND)**. Reportes: **solo** `sucursal_id` + `desde`/`hasta`. |
| ¿Rendimiento volumen alto? | Demo ~528 pedidos / 365d ≈ **30 ms**. Seq Scan OK a esta escala; **sin MV**; no probado a 50k+. |
| ¿Alertas con umbrales correctos? | Constantes `UMBRALES_ALERTA` alineadas a spec (30%, 3/día, $5k, 20%, 40%, 14d). Stock = `stock_minimo` por insumo. Batch ≠ eventos. |

---

## A) Cifras vs BD (evidencia script)

Periodo demo 7d, sede `c0000000-…0001`:

| Métrica | API | BD cruda | Match |
|---------|-----|----------|-------|
| `reportes/financiero` ventas_total | 239200 | 239200 | ✅ |
| pedidos (excl. cancel/rechazo) | 22 | 22 | ✅ |
| descuentos | 800 | 800 | ✅ |
| `analitica/resumen` ventas_netas | 239200 | 239200 | ✅ |
| Top producto ingresos (+ toppings/bebidas) | 220000 | 220000 | ✅ |
| Cancelados en periodo | — | 116 | excluidos ✅ |

### Universos de cálculo (importante)

| Superficie | Fuente | Notas |
|------------|--------|-------|
| KPI header / financiero | `SUM(pedidos.total)` | Ticket completo |
| Ranking productos / margen | `SQL_VENTA_LINEA_ITEM` (línea + extras) | Puede divergir del header si se suman rankings vs KPI |
| Filtro `producto_ids` en resumen | Consulta `pedido_items` + `SQL_VENTA_LINEA_ITEM` con `pi.producto_id` | Suma líneas filtradas; prueba de regresión agregada en `analitica-filtro-producto.spec.ts` |

---

## B) Filtros

| Capa | Filtros | Combinación |
|------|---------|-------------|
| Analítica | fechas, mesera, cajero, producto, categoría, cocina, método pago, hora, cliente, caja, domi, estados, segmento… | **AND** (`clausulasPedidos`) |
| Reportes | `desde`, `hasta`, `sucursal_id` | Sin filtros ricos |

Script: `mesera_ids` + `producto_ids` + fechas → `combo ≤ solo_mesera` y = SQL con `EXISTS` producto.

**Si el cliente manda `estados=…`:** se **desactiva** la exclusión por defecto de cancelado/rechazado (pueden entrar en KPIs).

---

## C) Rendimiento

| Caso | Resultado |
|------|-----------|
| `analitica/resumen` 365d | ~32 ms (demo) |
| `reportes/financiero` 365d | ~28 ms |
| EXPLAIN ventas 365d | **Seq Scan** (tabla chica; planner no usa idx) |
| Vistas materializadas | No (F5 plan / YAGNI) |
| `comparativa-sedes` | Loop N+1 por sede (BD-N1-05) |

Techo: sin carga sintética 50k–500k; índices `005`/`056`/`070` existen pero no se vieron en plan local.

---

## D) Alertas / umbrales

Fuente: `UMBRALES_ALERTA` en `alertas-riesgo.service.ts`.

| Umbral | Valor código | Spec / doc |
|--------|--------------|------------|
| Descuento alto | 30% | ✅ |
| Cancelaciones/día | 3 | ✅ |
| Cuadre caja | 5000 COP | ✅ |
| Margen bajo | 20% / 7d (≥3 ventas) | ✅ |
| Caída ventas producto | 40% | ✅ |
| Producto sin venta | 14d | ✅ |
| Stock bajo | `ingredientes.stock_minimo` | ✅ (no global) |
| Prep cocina | +30% vs sem. ant. (≥3 muestras) | ✅ código |

| Mecanismo | Tipos |
|-----------|--------|
| **Evento** | stock_minimo, descuento, cuadre, cancelaciones frecuentes, demora entrega, costo ingrediente, … |
| **Batch** `POST /alertas/evaluar/:sid` | margen_bajo_prolongado, caida_ventas_producto, producto_sin_venta, mesero_cancelacion_alta, (+ prep cocina) |

Script: constantes presentes + `POST evaluar` + listado pendientes OK. **No** fuerza umbral con datos sintéticos (margen/stock) en esta pasada.

`docs/ALERTAS_AUTOMATICAS.md` estaba incompleto en batch (faltaban sin_venta / mesero / prep) — corregido en la misma sesión.

---

## Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **REP-BD-01** | ✅ | — | Financiero/resumen = SQL crudo | Script A |
| **FIN-TZ-01** | 🟡 | Media | Límites diarios estaban ligados a TimeZone de sesión; corregido a calendario America/Bogota, pendiente activación en :3000 | ventas-metricas.sql.ts, tests SQL + QA UTC |
| **REP-LINE-01** | 🟡 | Baja | Header ticket vs ranking línea+extras: universos distintos (coherentes cada uno) | Script A + `sql-venta-linea-item` |
| **ANA-FILT-01** | ✅ | — | Filtros analítica se combinan con AND | Script B + `clausulasPedidos` |
| **ANA-FILT-PROD-01** | ✅ | Media | Filtro producto/categoría/cocina: resumen y series suman líneas (`SQL_VENTA_LINEA_ITEM`) | `consultarVentasKpi` |
| **REP-FILT-01** | 🟡 | Baja | Reportes sin filtros ricos (by design; BI = analítica) | `reportes.controller` |
| **ANA-ESTADOS-01** | ✅ | Media | `estados` omite cancelado/rechazado salvo `incluir_cancelados=true` | `parseFiltrosDesdeDto` |
| **ANA-PERF-01** | 🟡 | Media | 365d OK en demo; Seq Scan; sin MV; N+1 sedes | Script C · BD-N1-05 |
| **ALT-UMB-01** | ✅ | — | Umbrales hardcode = spec | Script D |
| **ALT-BATCH-01** | ✅ | — | Stock/cuadre por evento; batch = margen/caída/sin venta/mesero | Código + doc |
| **ALT-DOC-01** | ✅ | Baja | Doc alertas batch incompleto → actualizado | `ALERTAS_AUTOMATICAS.md` |

---

## Backlog sugerido (si se prioriza)

1. ~~**REP-FIX-01** — KPI de filtros de producto/categoría por suma de líneas (resuelto: `ANA-FILT-PROD-01`; `consultarVentasKpi` y batería analítica QA).~~
2. **ANA-FIX-01** — Carga sintética / EXPLAIN ANALYZE con ≥50k pedidos antes de go-live cadena.
3. **ANA-FIX-02** — Materializar o cachear `comparativa-sedes` (cerrar BD-N1-05).
4. **ALT-FIX-01** — Test E2E que inserte margen &lt;20% y afirme INSERT alerta (umbrales vivos, no solo constantes).

---

## Verificación

```text
.\scripts\verificar-reportes-analitica.ps1
→ Verificacion reportes-analitica OK (exit 0)
```

Gaps: click-through UI Reportes/Analítica en dispositivo; umbrales disparados con datos sintéticos; volumen prod-like.

**Prompt 21 (dashboard vs estas cifras):** ver [`AUDITORIA_DASHBOARD.md`](AUDITORIA_DASHBOARD.md) — `ventas_hoy` coincide con financiero/analítica «hoy» en demo; gaps de frescura/TZ/top ranking.

## Revisión autenticada UI y alcance de KPIs (2026-11-23)

### Evidencia en código y pantalla

- `lib/features/analitica/presentation/analitica_screen.dart` solicita `pedidosRecientes(..., limite: 15)`.
- `AnaliticaService.pedidosRecientes` retorna los últimos pedidos del periodo, ordenados por fecha; no filtra estados operativos activos.
- La tarjeta anterior “Pedidos activos” mostraba `pedidosRecientes.length`. Nombre y valor no correspondían al KPI. Se renombró “Pedidos recientes” y se aclara que el valor es el conteo de la tabla del periodo; la tarjeta “Pedidos” mantiene el conteo analítico del periodo.
- La lista de pedidos activos del dashboard sí usa `ESTADOS_PEDIDO_ACTIVO` en `dashboard.service.ts`; por tanto, ambas superficies cuentan universos distintos y no deben compararse como si fueran el mismo indicador.
- El API entrega `cobertura_costo_pct` midiendo líneas de pedido con costo registrado. Se expuso en la cuadrícula, se evitó presentar el valor por defecto `100%` cuando el KPI no tiene pedidos, y se quitó “Ganancia est.” porque duplicaba el valor monetario de `margen_bruto_estimado`.
- El cálculo del margen bruto suma `COALESCE(pi.costo_unitario, 0)`: una línea sin costo registrado se toma como costo cero. Puede sobrestimar margen; el tooltip advierte y la cobertura visible permite evaluar calidad. **No se cambió fórmula contable ni se actualizó el backend vivo.** Para una decisión contable definitiva se requiere aprobación y contrastar datos de QA aislada.
- Revisión transversal de notificaciones: `lib/services/push_notification_service.dart` no tiene referencias fuera de sí mismo; no está conectado al flujo ejecutado. El servicio activo es `ServicioFcmFoody`, inicializado desde `main.dart`; solicita permiso web y obtiene token por un método separado, mientras login staff vuelve a registrar el token. No se modificó el archivo heredado ni se presentó/aceptó permiso de navegador.
- La tasa de cancelación usa estados `cancelado`/`rechazado` como numerador y total de pedidos incluidos en el periodo como denominador. El endpoint de alertas abiertas no aplica filtro de periodo; el subtítulo UI dice “Abiertas ahora”, que coincide con su semántica.

### Hallazgos observados en sesión autenticada (solo lectura)

- El análisis, pedidos, caja y domiciliarios cargaron; no se crearon pedidos, no se cobró/liquidó y no se cambiaron preferencias.
- Caja mostró alerta de turno abierto longevo. Es una alerta, no un cierre automático; el servicio de caja impide cierre si continúan pedidos operativos o domicilios entregados con saldo pendiente. No se arqueó ni cerró el turno observado.
- El banner ahora dice que revisen pedidos, mesas y domicilios pendientes antes de cerrar; antes mandaba directamente a cerrar/arqueo sin contexto. El backend bloquea por pedido operativo abierto, mesa ocupada/en cobro o domicilio entregado con saldo. No hay enlace desde el banner al listado de bloqueos; no se intentó cerrar ni cobrar. `caja_admin_screen_test.dart` verifica el copy con un turno de 14 h.
- Domiciliarios mostraba dos agregados financieros distintos: saldo de fiados/CxC de domiciliarios de planta y pago por liquidar a independientes. Copy actualizado para exponer esa diferencia; movimientos y cifras fuente intactos.
- La pantalla de pedidos llegó vacía para los estados consultados. Sin crear datos no se validaron transiciones visuales de cada estado.

### Cambios UI verificados

- `analitica_resumen_dashboard.dart`: “Pedidos recientes”, “Cobertura de costos”, estado sin pedidos y advertencia del margen estimado.
- `caja_admin_screen.dart`: banner de turno largo ahora prepara al usuario para resolver operaciones pendientes antes del cierre.
- `domiciliarios_admin_screen.dart`: “Fiado por cobrar”, “Pago a independientes” y sección de fiados de planta.
- Tests de Análisis, Domiciliarios y Caja verifican labels, estado sin pedidos y aviso de turno longevo; análisis `flutter analyze --fatal-infos` de archivos afectados sin issues.
- Suite Flutter completa posterior: 156 aprobadas/5 E2E mutadoras omitidas; análisis focalizado de los archivos modificados sin issues. `flutter analyze --fatal-infos` global queda en 55 issues preexistentes (54 info + 1 warning, incluyendo APIs web/deprecadas y `_convertirDiaSemana` sin uso); ninguno está en los archivos corregidos. El flujo push no se activó manualmente para no presentar/aceptar un permiso del navegador.
- Cliente y Equipo recompilados por el iniciador `scripts/iniciar1/iniciar-foody-subdominios.bat`; API :3000 y Cloudflare no reiniciados. Seis URLs locales/públicas (Equipo, Cliente, health API) respondieron HTTP 200. El bundle servido contiene el copy final de Caja y Análisis.

### Pendientes de validación

1. Reconciliar KPIs con consultas de BD QA aislada y casos de costos ausentes, cancelaciones, devoluciones y pedidos abiertos; no usar la BD operativa para mutaciones.
2. Revisar cada tab/filtro/export de Analítica y estados de Pedidos con escenarios seguros y permisos de cada rol.
3. Definir contablemente si el margen debe excluir del porcentaje las líneas sin costo o mostrar el resultado como incompleto; el tooltip y la cobertura reducen ambigüedad, pero no sustituyen esa decisión.
4. Probar registro/token push en navegador de QA, con permiso concedido explícitamente; en esta revisión se trazó el flujo pero no se disparó el prompt del sistema.

## Trazabilidad P&L, variaciones y fechas de caja (2026-11-23)

### Hallazgo y cambio comprobado

- `FinanzasService.resumen()` entrega `delta_utilidad_pct`, calculado comparando `utilidad_neta` del mes actual con la del anterior. La UI lo mostraba tanto en la tarjeta **Ventas netas** como en **Utilidad neta**; la primera asociación era incorrecta. Se retiró el delta de Ventas y se conserva en Utilidad neta.
- La tarjeta compartida `SaaSKpiCard` desbordaba horizontalmente cuando el chip porcentual aparecía en tarjetas KPI estrechas. Se apiló el chip en el encabezado compacto y se corrigió el cálculo del ancho real de la celda (incluyendo separaciones), reservando altura adicional en grillas compactas.
- `test/finanzas_admin_screen_test.dart` ahora usa importes y variación distintos de cero, comprueba que el `+20%` no aparezca en Ventas y sí en Utilidad neta, y revisa el render sin overflow a 320/390/820/1440 px. Suite completa Flutter: 157 aprobadas, 5 E2E de escritura omitidas por requerir BD aislada. `flutter analyze --fatal-infos` focalizado en los archivos editados: limpio.
- Tras la corrección se reconstruyeron ambos flavors release mediante `scripts/iniciar1/iniciar-foody-subdominios.bat`; Cliente, Equipo y API de salud locales/públicos dieron HTTP 200. API :3000 y Cloudflare conservaron sus procesos. El build repitió avisos de compatibilidad Wasm de dependencias y fuente Cupertino faltante; los dos flavors JavaScript release terminaron correctamente.

### Modelo financiero y decisiones pendientes

- `FinanzasService.snapshotPl()` define `ventas_netas` como suma de `pedidos.total` con estados distintos de cancelado/rechazado, por fecha de creación. Esto puede incluir pedidos abiertos/impagos; la interfaz ya lo advierte.
- `costo_ventas` usa el snapshot histórico `pedido_items.costo_unitario` y los null suman costo cero. `total_gastos` usa filas registradas en `gastos` para ese periodo. Costos fijos y empleados no pagados aparecen en `pendientes`; la operación de pago crea el gasto asociado. Por tanto, la utilidad resultante combina tickets válidos aunque no estén cobrados con gastos registrados/pagados, mientras obligaciones pendientes no se descuentan. **No es necesariamente utilidad de caja ni P&L contable por devengo**; antes de cambiarla se debe decidir el criterio y renombrar/explicar los indicadores de acuerdo con él.
- `SQL_FECHA_CAJA_COALESCED_P2_P3` filtra movimientos de caja asociados a pedido usando `p.created_at`; solo movimientos sin `pedido_id` usan `m.created_at`. Así, el cuadre agrega cobros/devoluciones al día de creación del pedido (cohorte del ticket), no necesariamente al día en que se recibió o devolvió el dinero. El patrón se comparte en Reportes y Analítica y consta como precedente en `MODULO_ANALITICA_BI.md`.
- **Decisión pendiente `FIN-DATE-01`:** determinar si las vistas por periodo deben representar la cohorte de pedidos o los movimientos de dinero por su timestamp. Cohorte facilita comparar ticket vs cobro de esos pedidos; fecha del movimiento refleja flujo de caja diario. Pagos parciales en días distintos, cierres de día y devoluciones cambian de periodo según la elección. No cambié las reglas ni los reportes sin esa definición.
- Tampoco se ejecutaron pagos, cierres o consultas contra datos productivos. Las conclusiones anteriores provienen del código SQL y UI, más pruebas con repositorios sintéticos.

### Contexto visible de fechas para movimientos de caja (2026-11-23)

- **Hallazgo UX:** el nombre “Cobrado en caja (neto)” podía interpretarse como efectivo recibido dentro del rango visible, aunque el SQL asigna movimientos ligados a pedidos por `pedido.created_at`; los movimientos sin pedido se asignan por `movimiento.created_at`. El resultado mezcla reglas de fecha según relación del movimiento.
- **Cambio:** Reportes usa “Movimientos netos de caja” y explica la regla exacta junto a la diferencia. Análisis utiliza “Mov. caja netos” con subtítulo/tooltip. PDF y CSV incluyen la etiqueta y la nota; no se cambiaron cálculos, rangos ni datos. El nuevo texto del backend aclara que no representa necesariamente efectivo recibido en el rango; el frontend incorpora fallback para Nest previo.
- **Verificación:** suites Flutter Reportes y Análisis 10/10 (incluyen 320/390/820/1440 px); exportaciones CSV/PDF 2/2; Nest metadata 2/2 y build. `flutter analyze --fatal-infos` limpio en archivos focalizados. El PDF genera válido, pero las fuentes Helvetica base emiten un aviso genérico de soporte Unicode; no se reportaron glifos ausentes en la salida final. Build release Equipo actualizado y servido por Tunnel; `main.dart.js` local/público coincidieron por SHA-256; rutas local Equipo, Reportes por Tunnel y salud API HTTP 200. Cloudflared PID 11112 activo; no se reinició Nest ni se alteraron operaciones.
- **Sigue pendiente `FIN-DATE-01`:** decidir si caja por periodo debe seguir cohorte del pedido o fecha del movimiento. La aclaración reduce una interpretación errónea mientras esa decisión permanece abierta.

## Límites de fecha local y QA de reportes (2026-11-23)

- **Hallazgo `FIN-TZ-01`:** `sqlFechaRango()` y `SQL_FECHA_CAJA_COALESCED_P2_P3` convertían `YYYY-MM-DD` a `timestamptz` sin zona explícita. El PostgreSQL aislado reportó `TimeZone=UTC`; por tanto, los límites diarios podían desplazarse cinco horas respecto de `America/Bogota`. Finanzas ya filtraba por fecha local Bogota, lo que podía producir diferencias entre P&L y Reportes/Analítica alrededor de medianoche.
- **Corrección:** el helper compartido convierte el inicio del día y el inicio del día siguiente con `AT TIME ZONE 'America/Bogota'`. Las columnas timestamp permanecen sin envoltura de función para preservar el uso posible de índices. Se aplica a Reportes y a los filtros de pedido/caja en Analítica.
- **Verificación:** PostgreSQL QA en UTC confirmó que `2026-11-24 04:59:59Z` (23:59:59 del 23 en Bogota) queda fuera, `2026-11-25 04:59:59Z` (23:59:59 del 24 en Bogota) queda dentro y `2026-11-25 05:00:00Z` (00:00 del 25) queda fuera. Rutas autenticadas QA `reportes/financiero`, `reportes/productos`, `analitica/resumen` y `analitica/ventas` respondieron `exito=true` (9–17 ms en esa BD pequeña). Unit tests backend: 10 suites/32; E2E: 7 suites/14; build Nest OK.
- **Estado de activación:** cambio verificado en fuente/dist QA. El proceso de uso `:3000` no fue reiniciado; requiere reinicio controlado para activar esta corrección. Tunnel permaneció operativo.
- **Decisión pendiente `FIN-DATE-01`:** sigue abierta la elección entre periodo de cohorte del pedido y periodo de movimiento de dinero. Esta corrección solo unifica el calendario local; no decide reconocimiento contable ni reubica pagos parciales/devoluciones entre periodos.

## Aislamiento del E2E de cocina

El caso `COC-NODISP-01` prueba de forma intencional que cocina marque un producto no disponible, y Nest lo retira del catálogo. Ese efecto válido contaminaba los E2E posteriores de mesa/QR porque compartían la semilla. El `afterAll` de cocina ahora restaura la disponibilidad del SKU demo por API, solo como limpieza de fixture; la regla de negocio en producción permanece intacta. Suite completa repetida: 7/7, 14/14.

- **Conciliación de lectura QA (2026-11-23):** para 2026-11-01..2026-11-23, Finanzas.mes_actual.ventas_netas = Reportes.resumen.ventas_total = SQL crudo con el mismo rango Bogota: **300.000 COP**; diferencia entre P&L y tickets = **0**, Reportes y suma SQL = **0**. Reportes.cuadre_caja.ventas_movimientos_caja devolvió **286.250 COP** y explicó que caja neta representa cobros/devoluciones y tickets incluyen pedidos abiertos. La brecha de 13.750 COP no se interpreta como descuadre hasta definir cohorte versus fecha de movimiento (FIN-DATE-01). Solo lectura a QA.

## Aclaración de medidas de gastos en Caja (2026-11-24)

- **Hallazgo y corrección en fuente:** `CajaService.registrarGasto` persiste el mismo gasto en `gastos` y como `movimientos_caja.tipo='gasto'`. Gastos fijos, nómina y registros manuales también pueden existir solo en `gastos` (`caja_id` nulo), por lo que libro y caja representan universos distintos. `AnaliticaService.caja` sumaba el total categorizado del libro y el total de movimientos de gasto, duplicando las salidas originadas en caja. Ahora `gastos_total` se calcula únicamente desde categorías del libro; `gastos_movimientos_caja` se expone por separado para conciliación.
- **Interfaz:** Caja presenta “Gastos registrados” y “Egresos de caja” separados; el gráfico dice “Gastos registrados por categoría” y advierte que puede incluir registros que no afectan el arqueo. Hasta actualizar Nest `:3000`, el campo nuevo está ausente; la tarjeta muestra “— / Dato no disponible” y evita presentar un cero falso.
- **Evidencia:** `analitica-caja-gastos.spec.ts` simula un gasto presente en ambas fuentes y confirma libro = 100 COP (no 200) y egreso = 100. Prueba backend 1/1 y build Nest exitosos. `analitica_caja_screen_test.dart` verifica render a 320/390/820/1440 y compatibilidad con API anterior (5/5); analyzer de la prueba limpio.
- **Activación:** bundle `build/web_equipo` regenerado con flavor `equipo`, contiene KPI y fallback. Equipo local (`:8080`), Cliente local (`:8081`), Equipo por Tunnel y salud API pública respondieron HTTP 200. Procesos de API/Tunnel no se reiniciaron; el cálculo corregido requiere reinicio controlado para reflejarse en runtime. No hubo escritura ni lectura de datos de negocio.
- **Decisiones aún abiertas:** fecha de reconocimiento de gastos, anulaciones/reembolsos y pedidos pendientes en el P&L. Separar el libro del efectivo evita duplicar presentación, pero no define el criterio contable.

## Periodos predeterminados y pagos parciales (2026-11-24)

- **Corregido `FIN-TZ-DATE-02`:** los gastos de Finanzas por defecto usaban `new Date().toISOString().slice(0, 10)` (día UTC), aunque el resumen y los períodos de negocio usan `America/Bogota`. A las 21:30 del 31 de enero en Colombia, UTC ya es 1 de febrero; el registro caía en el mes siguiente y desaparecía del período esperado. Caja usaba `CURRENT_DATE`, dependiente de la zona horaria configurada en PostgreSQL. Ahora el backend comparte `fechaHoyNegocio()` para `America/Bogota`, y los gastos de Caja obtienen su fecha con `(now() AT TIME ZONE 'America/Bogota')::date`.
- **Prueba:** con reloj fijado a `2026-02-01T02:30Z`, Finanzas lista enero (`2026-01-01..2026-01-31`) y el helper produce `2026-01-31`; a `05:00Z` ya devuelve `2026-02-01`. El test de Caja verifica que la fecha SQL no use `CURRENT_DATE`. Analítica de Caja, helper de fechas, Caja y Finanzas: 4 suites / 5 pruebas; build Nest exitoso.
- **Corregido parcialmente `FIN-PARTIAL-01` (2026-11-24):** para costos fijos, cuyo importe esperado es explícitamente mensual, `resumen()` ahora resta del importe los gastos de origen `fijo` enlazados a ese concepto, sucursal y mes de negocio; devuelve el saldo y excluye obligaciones ya cubiertas. Nómina se conserva sin cambios porque frecuencia diaria/semanal/quincenal/mensual no determina por sí sola los periodos vencidos. El cálculo fijo agrupa por fecha del gasto; la aplicación futura de `periodo_desde/hasta` a meses distintos requiere una regla contable explícita.
- **Decisión funcional pendiente:** definir si el pago parcial está permitido y debe dejar saldo, si el monto es el valor completo del período o si `sueldo_base` significa monto por cada ciclo diario/semanal/quincenal/mensual. Hoy Empleados permite esas cuatro frecuencias, pero el resumen modela una sola obligación por mes y la UI deja el período vacío. Sin definir obligación/ciclo, no hay saldo restante correcto que se pueda calcular sin inventar reglas. Recomendado: especificar ciclo y fechas obligatorias por frecuencia, prorrateo/acumulación y tratamiento de excedentes antes de migrar el resumen; preservar gastos históricos como registros inmutables.
- **Pruebas y activación:** unitarias de Finanzas 2/2; SQL equivalente ejecutado dentro de transacción QA con tablas temporales: costo 500 menos abono 100 → saldo 400, totalmente pagado/sobrepagado excluido y abono de otra sede ignorado; `ROLLBACK` confirmado. Build Nest OK; API `:3000` reiniciada y salud local/pública HTTP 200. No se insertaron datos persistentes ni se tocó OAuth/credenciales/Tunnel.
- **Pendiente `FIN-PAYROLL-PERIOD-01`:** definir sueldo base por ciclo, fechas de obligación, frecuencia que vence dentro del mes, abonos, pagos atrasados, edición retroactiva y datos históricos; luego modelar un ledger de obligaciones con saldo. Los campos `periodo_desde/hasta` de nómina no generan hoy obligaciones periódicas.

## Comisión y liquidación de domiciliarios independientes (2026-11-24)

- **Comisión calculada:** `ConfiguracionGlobalService.comisionFoodyPct()` lee el parámetro `comision_domiciliario_porcentaje` (default 15%) y `DispatchService.calcularGanancias()` lo aplica al `costo_domicilio`; el restante se asigna a `ganancia_domiciliario`. Es una comisión del servicio de domicilio, separada de las suscripciones Foody y de una comisión general sobre ventas de productos.
- **Momento contable real:** `DomiciliariosIndependientesService.responderOferta()` inserta la fila de `ganancias_domiciliario` al aceptar la oferta, antes de la entrega. `SuperAdminService.estadisticas()` suma esas filas recién creadas en `ingresos_foody_hoy`; no exige asignación entregada. Por eso es una comisión estimada/acumulada al aceptar, no evidencia de dinero cobrado. Si el pedido se cancela, el resumen por sede continúa mostrando la comisión y el saldo del repartidor: coincide con `DOM-CANCEL-PAYOUT-01`, aún sin política definida.
- **Liquidación no implementada:** la tabla tiene `pagado bool DEFAULT false`; la UI de Equipo muestra el acumulado “Por pagar”. El controlador ofrece GET del resumen de comisión y el endpoint del repartidor GET `/ganancias`; no se encontró en `foody_backend/src` ni Flutter ninguna mutación de `ganancias_domiciliario.pagado` ni endpoint para registrar pago/soporte. A diferencia del domiciliario de planta, que liquida CxC y escribe pago/caja en una transacción, el payout al independiente no tiene flujo end-to-end. Las entradas pueden quedar `pagado=false` permanentemente.
- **Decisión de negocio necesaria:** determinar quién paga al independiente (Foody o establecimiento), desde qué fondos (recaudo de domicilio), cuándo nace el derecho (aceptación/entrega/cobro), tratamiento de cancelación/reclamo, si existe pago parcial y qué comprobante/auditoría se exige. No añadí una acción de pago porque eso cambiaría saldos reales bajo una política no definida.
- **Corrección relacionada aplicada:** pedidos del día e ingreso estimado por comisión en Super Admin ahora comparten el rango half-open de `America/Bogota` (`SQL_PEDIDO_ES_HOY`) en lugar de `CURRENT_DATE`, preservando índice en `created_at`. Pruebas de fecha, comisión Caja/Analítica, Super Admin y Finanzas: 5 suites / 6 pruebas; build Nest correcto. No se leyó ni escribió base de datos.
- **Activación:** Nest fuente/dist compilados; instancia de uso `:3000` continúa sin reiniciar y Tunnel sigue operativo.

### Seguimiento adicional — estados, comisiones y contador del domiciliario independiente (2026-11-24)

La cancelación administrativa actual revierte movimientos de venta en Caja, deja la asignación `cancelado`, cancela ofertas activas y libera la sesión del repartidor. **No marca ni revierte** la fila correspondiente de `ganancias_domiciliario`. El resumen por sucursal suma todas las filas enlazadas a asignaciones sin filtrar `ad.estado`, y `por_pagar` filtra solo `gd.pagado = false`; por ello un pedido cancelado puede seguir sumando comisión estimada y saldo pendiente. Esto no demuestra que se haya pagado dinero al repartidor ni determina si debe compensarse un trayecto; confirma que el dashboard contabiliza el pendiente bajo la regla actual.

También `responderOferta()` incrementa `domiciliarios_independientes.total_entregas` al aceptar la oferta. La tarjeta de Super Admin lo presenta como “Entregas”, aunque la asignación todavía puede cancelarse. El contador puede sobreestimar las entregas efectivas; cambiar su semántica requiere decidir si la métrica cuenta aceptaciones, rutas iniciadas o entregas finalizadas, y cómo corregir el histórico.

**Corrección de presentación — DOM-DELIVERY-COUNT-LABEL-01 (2026-11-24):** se conserva el valor histórico y se cambia su etiqueta a “Ofertas aceptadas (histórico)”, que describe el evento que realmente incrementa el contador. No se afirmó que sean entregas completadas ni se cambió el cálculo. Widget 2/2; analyzer focalizado limpio. La métrica de entregas efectivas requerirá un evento de cierre confiable.

### Reconciliación comercial — suscripción, comisión de domicilio y pago al repartidor

- **MEMORIA vs estrategia actual:** `MEMORIA.md` declara “suscripción mensual por restaurante + comisión domiciliarios” y registra 15% como comisión Foody sobre domicilio. La estrategia definida en esta conversación prioriza plan gratis permanente y Free → Pro a $50.000 COP/mes; deja la conexión amplia entre comercios, pedidos y domiciliarios para cuando exista adopción. Esa estrategia no confirma si el 15% debe cobrarse ahora, luego o mantenerse, así que el alcance comercial de la comisión queda pendiente.
- **Suscripción Foody:** es un pago mensual independiente (`pagos_suscripcion`/`suscripciones_restaurante`, checkout Wompi). La fuente Flutter y el backend coinciden hoy en Básico $50.000, Pro $100.000 y Enterprise $130.000 COP/mes. No coincide con la propuesta de esta conversación, que asigna $50.000 a Pro; requiere resolver nombre, precio y funcionalidades antes de alterar checkout o renovaciones.
- **Comisión sobre ventas de comida:** en los flujos inspeccionados de creación/cobro de pedidos no encontré una tasa aplicada al subtotal de productos para cobrar a Foody. No debe confundirse con la tarifa de domicilios.
- **Servicio de domicilio:** Nest calcula `comision_foody` usando `costo_domicilio × comision_domiciliario_porcentaje` (configurable, fallback 15%) y asigna el remanente a `ganancia_domiciliario`. No es un porcentaje del precio de la comida. La fila se crea al aceptar una oferta, no al entregar o conciliar un recaudo; `ingresos_foody_hoy` suma esas comisiones estimadas y la UI ya lo llama “Comisión estimada hoy”.
- **Pago al domiciliario independiente:** `ganancia_domiciliario` queda como saldo registrado (`pagado=false`). No hallé flujo de liquidación con comprobante/fecha de pago. La cancelación de una asignación no revierte la fila ni la excluye del saldo por pagar. Esto no demuestra que el repartidor haya recibido dinero ni define si merece compensación por una ruta cancelada.
- **Decisiones pendientes:** si Foody cobra el 15% y a quién; si se devenga al aceptar, entregar o recaudar; quién asume el costo cuando el pedido se cancela; cómo se liquida el remanente al repartidor; y si el módulo actual de domiciliarios independientes forma parte de la oferta inicial o del ecosistema futuro. Mantener esos conceptos separados de las suscripciones y de cualquier comisión sobre ventas hasta que se decida.

**Pendientes funcionales de alto impacto:** (1) resolver `DOM-CANCEL-PAYOUT-01` — quién paga, momento de devengo, cancelación antes/después de ruta, disputas y pago parcial; (2) implementar flujo auditable de liquidación, porque la auditoría de código no encontró endpoint/UI que cambie `ganancias_domiciliario.pagado`; (3) separar cifras de comisión estimada, comisión cobrada a Foody y pago al domiciliario; hoy Super Admin reporta como ingreso del día la suma de comisiones creadas con la oferta aceptada, no un recaudo bancario conciliado. Mantener separado suscripción SaaS, comisión del servicio de domicilio y dinero del repartidor.

**Evidencia:** `pedidos-estado.service.ts` cancellation block; `domiciliarios-independientes.service.ts` (`responderOferta`, `resumenGanancias`); `domiciliarios.service.ts` (`resumenComisionesIndependientes`); `super-admin.service.ts` (`ingresos_foody_hoy`). La etiqueta inicial fue corregida por `DOM-DELIVERY-COUNT-LABEL-01`; la cifra continúa siendo total histórico de ofertas aceptadas, no entregas completadas. No se cambiaron reglas ni pagos.

### FIN-PARTIAL-01 — obligación financiera desaparece tras cualquier abono (2026-11-24)

**Evidencia nueva en fuente:** `FinanzasService.resumen()` obtiene costos fijos y empleados pendientes con `NOT EXISTS` sobre `gastos` en el rango de fechas del mes. La condición no compara `SUM(g.monto)` contra el monto esperado, ni usa `periodo_desde`/`periodo_hasta`. En consecuencia, un abono de cualquier valor suprime la obligación completa de la lista de pendientes durante ese mes; la UI deja de ofrecerla aunque reste saldo. Para nómina también se ignora `frecuencia_pago` al determinar cuántos periodos vencen en el mes. El formulario permite monto parcial y conserva rango de periodo opcional, pero el resumen no consume esos campos.

**Ejemplos reproducibles por lectura de la regla:** costo fijo mensual de $500.000 con un gasto vinculado de $100.000 desaparece de pendientes, sin saldo visible de $400.000. Empleado con pago parcial también desaparece de la lista del mes, incluso si la frecuencia exige otro periodo.

**Corrección propuesta:** representar obligaciones por periodo con importe esperado, vencimiento y pagos aplicados; calcular saldo = obligación − pagos confirmados; permitir varios abonos y mostrar estado pagado/parcial/pendiente. Para nómina usar periodos explícitos de pago, no inferirlos solo del mes calendario. Antes de migrar hay que definir qué significa `sueldo_base` para frecuencias diaria/semanal/quincenal, calendario laboral, corte de periodos, pagos atrasados y si una edición del salario altera obligaciones ya creadas. Una tabla/ledger de obligaciones evita reconstruir obligaciones históricas desde egresos.

**Decisión y límite:** el bug de ocultar obligaciones parciales está demostrado estáticamente; no se cambiaron cálculos ni se hicieron pagos. Implementar el saldo sin resolver semántica de frecuencia podría generar montos vencidos o duplicados. Requiere política de nómina y reconciliación de gastos preexistentes antes de corregir backend.

## FIN-TZ-ANALITICA-CAJA-01 — gastos y cierres en día local (2026-11-24)

**Hallazgo confirmado:** `AnaliticaService.caja()` filtraba `gastos.created_at` y `cajas.cierre_at` con `::timestamptz` sobre fechas `YYYY-MM-DD`. Ambas columnas son `timestamptz` (migración `007_caja.sql`); esos límites heredaban la TimeZone de la sesión PostgreSQL, así que una sesión UTC movía el inicio del día de negocio de Bogotá cinco horas.

**Corrección:** las dos consultas usan `sqlFechaRango(columna, desde, hasta)`, con inicio local explícito `AT TIME ZONE 'America/Bogota'`, rango semiabierto y columna sin envolver para permitir índices. No cambia las fechas ni importes persistidos.

**Verificación:** test de Analítica Caja comprueba los límites generados para gastos y cierres; suite analítica/reportes/finanzas + helper compartido: 6 suites/11 pruebas; `npm run build` exitoso. PostgreSQL QA en `TimeZone=UTC` confirmó para el 1 de marzo: `04:59:59Z` excluido, `05:00:00Z` incluido, `04:59:59Z` del día siguiente incluido y `05:00:00Z` del siguiente excluido. Solo CTE/SELECT, sin mutaciones persistentes.

**FIN-GASTO-DATE-01 — semántica aclarada en UI; política contable abierta:** Analítica Caja agrupa gastos del libro por `gastos.created_at` (momento de registro), mientras Rentabilidad/P&L usa `gastos.fecha` (fecha operativa seleccionada). Los egresos de caja son una tercera cifra, proveniente de `movimientos_caja`; los gastos manuales retroactivos no crean movimiento de caja. Por eso los tres totales pueden diferir sin que la suma esté duplicada. `AnaliticaScreen` ahora identifica el KPI como “Fecha de registro” y aclara que Rentabilidad usa la fecha del gasto; también advierte que algunos gastos no afectan el arqueo. Prueba responsive de Caja 5/5 en 320/390/820/1440 y analyzer focalizado limpio. No se cambió cálculo ni contrato. Falta decidir si el producto debe conservar ambas fechas de análisis o unificar los reportes en una sola fecha de negocio. No confundir con FIN-DATE-01 (fecha de pedido frente a movimiento de venta/devolución).

**Actualización de transparencia UI (2026-11-24):** el resumen del repartidor independiente ya no presenta importes de `ganancias_domiciliario` como “ganancia neta” ni las filas como entregas. La etiqueta “Ganancia estimada” avisa que se crea al aceptar la oferta, puede incluir asignaciones canceladas y no demuestra pago. `GET /ganancias` ahora incluye `estado_asignacion` por fila para mostrar la situación actual. Se conservaron `comision_foody`, `ganancia_domiciliario`, `pagado`, filtros y agregados. Widget 8/8 en cuatro anchos y ambos temas; admin domiciliarios 14/14; análisis Flutter focalizado limpio. No se publicó Equipo ni se cambió regla contable; payout, derecho por cancelación y devengo siguen abiertos.
