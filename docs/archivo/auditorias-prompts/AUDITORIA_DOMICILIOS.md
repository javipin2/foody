# Auditoría — Domicilios (Prompt 16)

> **Fecha:** 2026-11-25 (revisión adicional)
> **Alcance:** flujo pedido→asignación→entrega→cobro; estado domiciliario vs admin; cancel mid-ruta.  
> **Verificación:** `scripts/verificar-domicilios-ciclo.ps1` (OK, exit 0).  
> Código: `domiciliarios.service.ts` · `dispatch.service.ts` · `domiciliarios-independientes.service.ts` · `pedidos-estado.service.ts`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

## DOMI-PAY-DISPLAY-01 — desglose de pagos para domiciliarios

La auditoría de fiado encontró un caso con producto $13.000 pagado en tres partes: transferencia $2.000, efectivo $6.000 y Nequi $5.000 (el domicilio quedó fuera de Caja). El campo heredado `pedidos.metodo_pago` terminó como `efectivo`, por lo que no representaba los abonos. Las consultas de pedidos activos de planta e independiente y el historial de planta ahora agrupan `pagos_pedido` por método e importe bajo `(pedido_id, sucursal_id)` y entregan `pagos_resumen`; las tarjetas presentan cada par y el historial muestra el detalle. La interfaz recurre al método heredado solo cuando no hay filas de pago. El resumen no incluye la columna de propina; esta sigue aparte. No se alteran cobro, saldo, Caja, datos históricos ni la semántica/valor de `pedidos.metodo_pago`.

**Actualización DOMI-PAY-LEGACY-METHOD-01 (2026-11-25):** la liquidación de CxC de planta ya no fuerza `pedidos.metodo_pago='efectivo'`. El scalar mantiene el primer método registrado en `pagos_pedido` para ese pedido+sucursal, con fallback efectivo si no hubiera fila; el detalle por método sigue siendo `pagos_resumen`. El `UPDATE pedidos` también valida sucursal. Unitarias 2/2 y build Nest pasan. Se amplió `verificar-fiado-domiciliario.ps1 -CicloCompleto` para cubrir abono transferencia + liquidación efectivo y revisar el resumen, pero el E2E aún no se ejecutó; el control automático rechazó el comando compuesto que preparaba clon/API QA y su limpieza. La API :3000 sigue en runtime anterior al build.

Verificación: `domiciliarios-saldo-pendiente.spec.ts` 3/3 (incluye historial planta), Nest build OK, `tarjeta_pedido_domiciliario_test.dart` 2/2; el fixture cubre tres métodos/importes en móvil. SQL ejecutado con `default_transaction_read_only=on` en `foody_diseno_qa`: 44/44 entregas planta con resumen válido, 63 pedidos QA con >1 método y escalar `metodo_pago` discordante en todos. Es una instantánea QA, no estimación de producción. La consulta de pedidos activos de planta/independiente devolvió cero filas, por lo que no se probó un activo real del snapshot. **Pendiente:** API :3000 tiene dist viejo; activar normalmente y validar autenticado por app/Tunnel.

## Revisión visual autenticada adicional — 2026-11-25

La vista de administración cargó las reglas de cobro, saldos fiados, equipo de planta, entregas por repartidor y resumen de independientes; no mostró el falso saldo cero tras el ajuste de estados de error. En la captura se veían dos repartidores de planta “En ruta” y dos entregas listadas. El tablero relacionado mostraba el pedido `FDY-2026-0016` en camino por 113 d 5 h; podría ser dato QA/demo, pero no se confirmó. El sistema lo cuenta como activo/alerta. No se alteró pedido, liquidación ni cuenta; queda pendiente clasificar ese registro y decidir el manejo de pedidos de prueba obsoletos antes de cualquier limpieza.

La primera carga web tras compilar mostró `FormatException: Unexpected token '<'` y una pantalla vacía, en local y Tunnel. Se aisló el Future de inicialización de Firebase Messaging para que una respuesta inválida del servicio de push no deje una excepción asíncrona sin manejar. Tras rebuild release, login local, panel autenticado público y esta vista se renderizaron. No se capturó stack que pruebe qué endpoint devolvió HTML; registrar causa como probable y volver a investigarla si reaparece. OAuth y configuración de Tunnel quedaron intactos.

## Propina entregada al domiciliario — auditoría de contrato

La confirmación de entrega de repartidor independiente recibe los métodos de pago del producto y del domicilio (`ConfirmarEntregaDto`); no incluye monto ni destinatario de propina. `DomiciliariosIndependientesService.confirmarEntrega()` registra ambas líneas de producto/domicilio con `pagos_pedido.propina=0`, y el repositorio Flutter del independiente envía solo `metodo_pago`. Por tanto, una propina que el cliente entregue directamente al domiciliario queda fuera del registro de Foody y no se suma a Caja, tarifa, comisión Foody ni ganancia calculada por el despacho. No hay evidencia de que sea una falla financiera: no se definió que Foody deba capturar o liquidar ese dinero. Mantener como decisión de producto/contabilidad si se necesita registro, comprobante o reporte; no incluirla como deuda ni como payout sin esa decisión.

## Fiado de domiciliario de planta — cobertura y trazabilidad

`dashboard_domiciliario_screen.dart` ofrece “Dejar a mi cuenta” cuando la sucursal lo permite y envía `metodo_pago='pendiente_liquidacion'`; el método de pago del domicilio queda `null`. La decisión DOM-017 está documentada en `docs/AVANCE_PROYECTO.md` y migración 066: por defecto el domicilio queda fuera de Caja y se rastrea con el domiciliario (quien conserva ese cargo); con `domicilio_ingresa_a_caja=true` el restaurante también lo cobra. En Nest, `DomiciliariosService.confirmarEntrega()` crea una CxC por el saldo completo en el segundo modo, o solo por `productoPendiente` en el primero. `liquidarDomiciliario()` registra esas CxC como efectivo entrante a la sucursal y marca el pedido con `monto_pagado=total` y `metodo_pago='efectivo'`. La migración 065 describe efectivo recogido “en la calle” por el domiciliario y rendido al regresar. No se debe reabrir como decisión quién recibe la tarifa: el riesgo pendiente es la trazabilidad del medio del componente externo fuera de Caja y que el método agregado del pedido se fija a efectivo en la liquidación aunque haya pagos previos por otro medio.

**Cobertura actualizada (2026-11-25):** `verificar-fiado-domiciliario.ps1 -CicloCompleto` probó `pendiente_liquidacion` y ambos valores de `domicilio_ingresa_a_caja` en API :3001 + clon temporal. Con cuenta $13.000 y cargo de domicilio $5.000, flag `false` registró CxC/liquidación/pago/Caja por $8.000; flag `true` registró $13.000. Ambos ciclos completaron entrega y liquidación; clon eliminado y QA persistente intacta. No se probó aún abono previo de extremo a extremo, métodos distintos entre producto/domicilio, ni repetición de la ruta por API. La función `repartirCobroDomicilio()` y la lectura para apps sí tienen cobertura unitaria de saldo parcial (2 suites/7 pruebas), incluyendo abono aplicado primero al producto. Liquidación repetida no parece duplicar el movimiento: la transacción selecciona solo CxC pendientes bajo `FOR UPDATE`, marca pagada y una llamada posterior devuelve `SIN_CUENTAS_PENDIENTES`; falta probar esa respuesta y las filas en E2E. La CxC se liquida completa: el DTO no admite abonos parciales posteriores. No se cambió la implementación ni se mutaron datos operativos.

**Endurecimiento y ejecución del verificador (2026-11-25):** `scripts/verificar-fiado-domiciliario.ps1` consulta por defecto; `-CicloCompleto` exige API local :3001 y clon `foody_diseno_qa_codex_*`, bloquea si el domiciliario fixture ya tiene CxC, liquida el fixture y restaura `permite_fiado_domiciliario` incluso ante error. La ejecución en el clon cubrió ambos valores del flag y concilió CxC, fila de pago y movimiento Caja; falta cobertura E2E de abono previo, medio mixto y repetición. Las escrituras no llegaron a QA persistente ni al entorno detrás del Tunnel.

La suite orquestada `scripts/verificar-flujo-cruzado-api.ps1` se endureció después de encontrar que la preparación modificaba horarios y limpiaba pedidos antes de los casos. Ahora valida API local :3001 y una base clon desechable `foody_diseno_qa_codex_*`; el limpiador acepta esa base solo dentro del contenedor QA dedicado. La corrida posterior del flujo cruzado completó 12/12 casos en un clon aislado; el clon fue eliminado y la QA compartida quedó intacta. Ver `docs/AVANCE_PROYECTO.md` y `docs/MASTER_STATUS.md`.

---

## Resumen ejecutivo

### DOM-ESTIMATE-LABEL-01 — KPI de ganancias no liquidadas

La consulta `resumenComisionesIndependientes()` suma `ganancias_domiciliario` con `pagado=false`; cada fila se crea al aceptar una oferta, antes de la entrega. El filtro no excluye asignaciones canceladas y aún no existe un flujo de egreso/pago. Por eso “Por pagar independientes” comunicaba una obligación confirmada que la fuente no garantiza. Flutter ahora muestra “Ganancias estimadas” y “Estimado”, con ayuda que advierte que puede incluir pedidos cancelados y no confirma entrega ni pago. Sin cambio de monto, API o BD. Widget 8/8 en 320/390/820/1440 y analyzer limpio. Revisión en túnel posterior a la publicación pendiente.

| Pregunta | Respuesta |
|----------|-----------|
| Flujo completo | **Sí** — `pendiente→en_cocina→listo→asignado→en_camino→entregado`. Cobro **al entregar** (contraentrega); no venta al crear. |
| Estado vs admin | Planta: `ocupado` derivado de asignaciones activas — **consistente**. Indep: `sesiones.disponible` — modelo distinto. |
| Cancel mid-ruta | Solo **admin/gerente**. Asignación → `cancelado`; planta libera `ocupado`. Cliente/domi **no**. |

---

## Flujo (planta demo)

```
POST /pedidos/staff (tipo=domicilio, metodo=pendiente)
  → pendiente  [sin venta caja]
PATCH → en_cocina → listo
  → auto-dispatch planta (si libre) ó manual POST .../asignar
  → asignado
PATCH /domiciliario/pedidos/:id/en-camino
  → en_camino
PATCH .../confirmar-entrega { metodo_pago }
  → entregado + venta caja (producto; domicilio según flag sucursal)
```

| Regla | Evidencia script |
|-------|------------------|
| `listo→entregado` bloqueado | ✅ |
| Sin caja al crear | venta=0 |
| Cobro al entregar | venta=8000; `monto_pagado=total` (12000 c/ domicilio) |
| Independiente | ofertas 60s / radio km — `verificar-ofertas-independiente.ps1` |

---

## Estado domiciliario ↔ admin

| Rol | Qué reporta | Qué ve admin |
|-----|-------------|--------------|
| **Planta** | Pedidos asignados / en camino | `GET .../disponibles` → `ocupado` = EXISTS asignación `asignado\|en_camino` |
| **Indep** | `sesion.disponible` + `activa` | No hay `ocupado` unificado; ofertas + ganancias |

Script A/B: `ocupado=true` en asignado/ruta; `false` tras entregar o cancel.

**Sin campo** `estado_turno` / `en_ruta` en persona planta — se deriva.

---

## Cancel mid-ruta

| Actor | ¿Puede en `asignado`/`en_camino`? |
|-------|-----------------------------------|
| Cliente | **No** |
| Domi | **No** (sin endpoint; PATCH estado rechazado) |
| Admin/gerente | **Sí** |

Efectos verificados:
- `asignaciones_domicilio.estado = cancelado`
- Admin `ocupado=false`
- Inventario: rastro (merma post-cocina)
- Caja neto ≈ 0 (no había cobro aún)

### Gaps resueltos y pendientes

| ID | Gap |
|----|-----|
| **DOM-CANCEL-INDEP-01** | ✅ Cancel restaura `disponible` si no hay otro pedido activo |
| **DOM-CANCEL-OFERTA-01** | ✅ Cancel cierra ofertas activas del pedido |
| **DOM-RT-INDEP-01** | ✅ Evento privado `pedido_desasignado` también notifica al independiente; Flutter refresca pedidos/sesión |
| **DOM-LOCK-ORDER-01** | ✅ Aceptación bloquea pedido antes que oferta (orden compartido con cancelación); suite E2E posterior al ajuste 6/6 |

---

## Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **DOM-FLOW-01** | ✅ | — | Ciclo planta + cobro al entregar | Script A |
| **DOM-SKIP-01** | ✅ | — | Bloqueo `listo→entregado` | Script A |
| **DOM-STATE-01** | ✅ | — | `ocupado` admin coherente con ruta | Script A/B |
| **DOM-CANCEL-01** | ✅ | — | Admin cancela mid-ruta; asignación cancelada | Script C |
| **DOM-CANCEL-WHO-01** | ✅ | — | Cliente/domi no cancelan mid-ruta | Script C |
| **DOM-CANCEL-INDEP-01** | ✅ | Media | Cancel libera sesión solo si no queda otro pedido activo | Unit + E2E independiente |
| **DOM-CANCEL-OFERTA-01** | ✅ | Baja | Cancel cierra ofertas activas asociadas | Unit + E2E independiente |
| **DOM-RT-INDEP-01** | ✅ | Media | Broadcast por canal privado y listener Flutter actualiza datos | Specs + analyze; publicación/realtime conectado pendiente |
| **DOM-LOCK-ORDER-01** | ✅ | Alta | Aceptación/cancelación comparten orden de bloqueos para reducir deadlocks | Unitarias + E2E domicilio 6/6 (clone QA efímero) |
| **DOM-EVID-01** | 🟡 | Baja | Sin foto/comprobante de entrega | DTO solo metodo_pago |
| **CAJ-DOM-IMPAGO-01** | 🟡 | — | (cross) entregado parcial bloquea cierre caja | Prompt 13 |
| **AQ-CYCLE-01** | 🟣 | — | (cross) ciclo Nest pedidos↔domiciliarios | Arquitectura |

---

## Backlog remediación sugerido

1. Repetir `domicilio.e2e-spec.ts` después del ajuste de orden en clon QA temporal; la corrida previa pasó 5/5.
2. Reiniciar Nest para activar fuente; Flutter Equipo ya está publicado (hash local/Tunnel coincidente). Verificar evento con courier autenticado y Realtime conectado.
3. **DOM-EVID-01** — Evidencia fotográfica sigue opcional y requiere decisión de producto/storage.
4. Aclarar tratamiento financiero de comisiones de asignaciones independientes canceladas (`DOM-CANCEL-PAYOUT-01`).

---

## Verificación

```powershell
.\scripts\verificar-domicilios-ciclo.ps1
# exit 0
```

Relacionados: `verificar-flujo-domicilio.ps1`, `verificar-ofertas-independiente.ps1`, `verificar-fiado-domiciliario.ps1`.

### Revalidación 2026-11-25

`domicilio.e2e-spec.ts` pasó 6/6 después del ajuste al orden de bloqueos, sobre API Nest aislada :3001 y clon efímero `foody_diseno_qa_codex_indep_20261125`. Cubre planta, aceptación/cancelación independiente y el ciclo independiente hasta entrega: pedido entregado, monto_pagado total, ventas ligadas a Caja y ganancias visibles como pendientes cuando domicilio > 0. El clon se eliminó, QA fuente conservó sus datos, :3001 quedó detenida. `FOODY_QA_SIN_EFECTOS=1`; no prueba Realtime externo ni impresión física.

Las pruebas unitarias confirman evento privado `pedido_desasignado` y destino independiente; `dart analyze` sobre realtime y pantalla de courier no encontró issues. El build Flutter Release está publicado y su SHA coincide local/Tunnel; la E2E HTTP no observa Supabase Realtime real. Falta reiniciar Nest (PID :3000 sigue antiguo) y verificar con sesión independiente autenticada. `DOM-EVID-01` permanece opcional y la liquidación de comisión de asignaciones canceladas es una decisión financiera abierta, distinta de liberar disponibilidad.

### Revisión ampliada de fiado/liquidación (2026-11-25)

Se releyó el ciclo de planta, su configuración y las pruebas existentes. El importe de CxC sigue las dos reglas documentadas: `productoPendiente` cuando el domicilio queda para el domiciliario, o todo el saldo si el restaurante lo cobra. En liquidación, cada CxC genera un `pagos_pedido` efectivo y movimiento de caja; el pedido agregado termina con `monto_pagado=total` y `metodo_pago='efectivo'`. Ese agregado es engañoso si había abonos por otro medio o componentes recaudados fuera de Caja: los movimientos y `pagos_pedido` son más granulares, pero el resumen del pedido no representa necesariamente el mix real.

Pruebas unitarias revisadas/ejecutadas: cobro de domicilio, guardas de despacho, guardas independiente y permisos del controlador: **4 suites / 16 pruebas aprobadas**. Luego se ejecutó `verificar-fiado-domiciliario.ps1 -CicloCompleto` en dos escenarios sobre Nest `:3001`, `FOODY_QA_SIN_EFECTOS=1` y clon temporal `foody_diseno_qa_codex_domi_20261125`. Con el domicilio fuera de Caja, cuenta $13.000, CxC/liquidación $8.000, pago/Caja $8.000; con el domicilio en Caja, CxC/liquidación/pago/Caja $13.000. Los dos terminaron entregados, sin saldo pendiente de CxC, y la configuración de fiado se restauró. Consulta SQL `READ ONLY` confirmó importes/método y `monto_pagado=total`.

Nest QA fue detenida, el clon se eliminó tras verificar cero sesiones, `foody_diseno_qa` conserva 3 restaurantes sin conexiones y API :3000/Tunnel siguen activos. No se tocó dato operativo. Sigue pendiente el escenario de abono previo/métodos mixtos, conciliación del cargo que queda fuera de Caja y rechazo de doble liquidación. Por esta brecha se mantiene el agregado `metodo_pago` como hallazgo sin corregir hasta determinar cómo representa el medio real de recaudo del domiciliario.


## Verificación focalizada de cobro contraentrega independiente (2026-11-25)

Se añadió una regresión unitaria a domiciliarios-independientes-dispatch-guard.spec.ts: pedido de 10.500 con 2.000 ya abonados y domicilio de 2.500; al entregar se separan 6.000 de productos y 2.500 de domicilio, con métodos efectivo y transferencia independientes. Ambos importes usan pagos_pedido con propina cero; si la sucursal configura domicilio dentro de caja, ambos movimientos se registran en caja, y monto_pagado queda en el total exacto. Las 6 pruebas del archivo pasan.

La nueva E2E cubre aceptación de oferta independiente → en camino → entrega → pagos/Caja/ganancias, y reconcilia por delta Reportes/Analítica: ventas de pedidos aumentan por el total; cobros netos y recaudo por movimientos aumentan por lo ingresado a Caja, sin contar dos veces el domicilio ni propinas. domicilio.e2e-spec.ts pasó 6/6 con Nest :3001 contra clon temporal foody_diseno_qa_codex_indep_20261125; efectos externos apagados. API temporal detenida y clon retirado; QA persistente intacta. No se hace liquidación real al domiciliario: continúa pendiente definir beneficiario, pagador, momento, cancelación y soporte contable. No se añadieron endpoints de payout ni se marcó ninguna ganancia como pagada.

### Cobertura de reintento de liquidación (2026-11-25)

Se añadió `domiciliarios-liquidacion-idempotencia.spec.ts`. Simula dos reintentos secuenciales cuando no hay CxC `pendiente`; ambos producen `SIN_CUENTAS_PENDIENTES`, la consulta mantiene `FOR UPDATE`, y no se registra venta en Caja. Test focalizado Nest: 1/1 suite y 1/1 prueba. Esto verifica el guard del segundo envío, no concurrencia PostgreSQL real ni escritura/rollback de una liquidación con saldo. Para esas garantías sigue pendiente un replay E2E con base clon temporal.

La aclaración comercial vigente es: el valor obligatorio completo se cobra; propina voluntaria es concepto separado y no se persiste si se difiere el pago. Esta decisión no define dónde se custodia/reparte propina, ni aclara el resumen `metodo_pago='efectivo'` al liquidar CxC con abonos anteriores por otros medios o recaudos de domicilio fuera de caja. No cambiar esas reglas financieras hasta resolver el contrato del resumen y su fuente contable.

### Reintento de liquidación en flujo API completo — 2026-11-25

`verificar-fiado-domiciliario.ps1 -CicloCompleto` ahora incluye un segundo POST de liquidación tras confirmar que no quedan CxC. Ejecución en Nest aislado `127.0.0.1:3001`, `FOODY_QA_SIN_EFECTOS=1`, clon temporal `foody_diseno_qa_codex_tipdomi_20261125`: el pedido fixture terminó entregado con CxC $8.000; primer POST liquidó un pedido por $8.000; resumen posterior mostró saldo cero; segundo POST fue rechazado HTTP 400 (`exito=false`); la configuración fiado volvió a su valor original `false`. Script exit 0.

Se detuvo el proceso Nest QA; el clon quedó con 0 sesiones y se eliminó. La base QA persistente no se alteró; el API productivo/Tunnel no se reinició. Los workers de QA registraron avisos de procesamiento FCM/impresión bloqueado por el modo sin efectos; no hubo envío/impresión externa. La prueba cubre replay secuencial con datos reales de Postgres aislado; no cubre dos solicitudes simultáneas concurrentes. El abono previo extremo a extremo y los métodos mixtos para liquidación de planta siguen pendientes.

### Abono previo y pago mixto — domiciliario de planta E2E (2026-11-25)

Se agregó al E2E `domicilio.e2e-spec.ts` un recorrido de API completo: staff crea domicilio de $13.000 ($8.000 producto + $5.000 domicilio), Cocina lo prepara, planta lo asigna y marca en camino, Caja registra $2.000 previos por transferencia, y el domiciliario confirma entrega cobrando el producto restante por efectivo y el domicilio por Nequi. Con `domicilio_ingresa_a_caja=false`, E2E pasó y verificó pedido entregado/pagado $13.000; ventas en Caja por este pedido: $2.000 transferencia + $6.000 efectivo = $8.000. El servicio persiste además $5.000 Nequi con referencia `Domicilio (fuera de caja)`, visible en lectura SQL del clon.

Una consulta SQL de solo lectura encontró que el resumen `pedidos.metodo_pago` queda `efectivo`: es el medio usado para producto contra entrega, aunque el pedido tenga tres `pagos_pedido` y la suma de métodos no sea efectivo. Los reportes/analítica de Caja agrupan `movimientos_caja.metodo_pago`, mientras el pedido expone un único `metodo_pago`; el campo de pedido no representa el mix completo. No se actualizó a `mixto` porque la constraint histórica de `pedidos.metodo_pago` enumera solo efectivo/tarjeta/transferencia/nequi/pendiente y el contrato de UI/API puede depender de ese conjunto. Propuesta para decisión/implementación: derivar y exponer un `resumen_pagos` desde `pagos_pedido` y usar `mixto` como etiqueta de presentación cuando existan varios métodos, preservando las líneas fuente; si se quiere guardar `mixto` en BD, auditar y migrar primero constraint, filtros y consumidores.

La primera corrida alcanzó entrega y falló solo al consultar configuración por una ruta mal escrita en el test; se corrigió el endpoint del test. Repetición final del E2E focalizado pasó **1/1** (los otros 6 tests de esa suite fueron omitidos por el filtro). La consulta SQL vio dos pedidos con nombre fijo originados en las corridas previas, ambos con el mismo resultado; el test ahora usa nombre único por timestamp. Base y API QA eran descartables. No se tocaron pedidos productivos.

### Verificación de `Access-Control-Max-Age` en Nest QA

En la misma API QA `:3001` compilada con `maxAge:300`, OPTIONS devolvió `204`, `Access-Control-Max-Age: 300`, origen exacto `https://equipo.foodyy.store` y `Access-Control-Allow-Credentials: true`. El API público `:3000` continuó sin max-age porque su proceso no se reinició. Nest QA se apagó; clon `foody_diseno_qa_codex_abonomix_20261125` se eliminó con 0 conexiones. Persisten pendientes medición fría, primer frame Flutter y percentiles.

### Regresión amplia del workspace — 2026-11-25

- `foody_backend`: `npm test -- --runInBand` — **60 suites, 168 pruebas aprobadas**. `npm run build` — exit 0.
- Flutter: `flutter test --no-pub` — **295 aprobadas, 5 omitidas**, todas las pruebas ejecutadas pasan.
- `flutter analyze --no-pub` — exit 1 por **10 findings informativos**, sin diagnósticos de severidad error en la salida: APIs `dart:html` web deprecated/no plugin, tres usos de `BuildContext` tras gaps async en registro de restaurante y un `DropdownButtonFormField.value` deprecated. No se corrigieron aquí: son deuda preexistente fuera del cambio de E2E y requieren revisión puntual por riesgo de compatibilidad web y de flujo de registro.
- E2E Domicilio completa en clon QA: 7/7; Nest QA detenido y clon retirado. No usar suite de unidad/widget para afirmar que todos los flujos integrados fueron probados.
