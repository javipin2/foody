# Auditoría — Caja (Prompt 13)

> **Fecha:** 2026-08-06  
> **Alcance:** coherencia caja↔pedido, apertura/cierre/cuadre, pagos mixtos, reapertura de cobrado, anulaciones → reportes/inventario.  
> **Verificación:** `scripts/verificar-caja-ciclo.ps1` (OK, exit 0).  
> Código: `modulos/caja/` · `core/caja/caja-movimientos.service.ts` · `pedidos-pagos.service.ts` · `pedidos-caja-auditoria.service.ts`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| ¿Caja refleja el pedido real? | **Sí** — monto desde `pedidos.total` / saldo BD; tope `min(monto, total−ventas previas)`. Flutter no recalcula. Mesa: venta solo al cobrar. |
| Apertura / cierre / cuadre | Abrir 1×; cierre bloquea pedidos abiertos / mesas / domicilios impagos; `diferencia = contado − sistema`; alerta si \|>5000\| COP; `arqueo_ciego` oculta saldo al cajero |
| Pagos mixtos | **Sí** — N movimientos `venta` (uno por medio) + N `pagos_pedido`; suma debe = saldo |
| Reabrir pedido `pagado` | **No permitido** (y **no debería**): cobrar de nuevo / PATCH estado / agregar ítems → `PEDIDO_CERRADO` / transición inválida |
| Anulaciones | Sin cobro: no mueve caja. Con venta: 1× `devolucion` = neto. Stock: merma o restore. Reportes pedidos excluyen `cancelado`/`rechazado` |

---

## Flujo cobro → caja

```
Pedido.total (BD)
  → POST .../cobrar (pagos[] opcionales, suma = saldo)
  → N× registrarVentaEnCaja(monto, metodo)
  → tope vs pedidos.total
  → INSERT movimientos_caja tipo=venta
```

Mesa/staff: **no** hay venta al crear (diferido).  
Para llevar prepago con método de caja: venta y saldo se registran al crear; permanece operativo en cocina, pero el saldo cero ya no bloquea el cierre de caja. Cocina lo mueve a `pagado` al resolver el ticket (ver **PED-PREPAGO-01**, cerrado).

---

## Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CAJ-SYNC-01** | ✅ | — | Cobro mesa: `SUM(venta)=pedidos.total`; sin venta antes de cobrar | Script A |
| **CAJ-MIXTO-01** | ✅ | — | Efectivo+tarjeta → 2 movimientos + 2 `pagos_pedido`; suma incorrecta → `PAGOS_NO_COINCIDEN` | Script B |
| **CAJ-REOPEN-01** | ✅ | — | Reapertura cobrado bloqueada (cobrar/PATCH/ítems). Correcto: no debería permitirse sin flujo de anulación explícito | Script C |
| **CAJ-CANCEL-01** | ✅ | — | Cancel mesa sin cobro: 0 devoluciones. Cancel prepago: devolución = venta, neto 0 | Script D |
| **CAJ-INV-01** | ✅ | — | Cancel post-cocina deja rastro en `movimientos_ingrediente` (merma/restore) | Script D n≥1 |
| **CAJ-REP-01** | ✅ | — | Cancelados fuera de filtros reportes/analítica pedidos | `estado NOT IN (cancelado,rechazado)` |
| **CAJ-CIERRE-01** | ✅ | — | Doble apertura `CAJA_YA_ABIERTA`; cierre con abiertos `CAJA_CIERRE_OPERACION_ABIERTA`; cuadre + alerta diferencia | Script E |
| **CAJ-CIEGO-01** | ✅ | — | `arqueo_ciego`: cajero no ve `saldo_sistema` | Script E visible=False |
| **CAJ-DOM-IMPAGO-01** | 🟡 | Media | Domicilio `entregado` con `monto_pagado < total` **bloquea cierre** (by design). Demo tenía 7 pedidos históricos → cierre imposible hasta liquidar | SQL + cierre |
| **CAJ-MSG-01** | 🟡 | Baja | Filter aplana `CAJA_CIERRE_OPERACION_ABIERTA` a mensaje genérico (pierde detalle cocina/mesas/domi) | `http-exception.filter.ts` MENSAJES_NEGOCIO |
| **CAJ-TURNO-01** | ✅ | Baja | `horas_abierta` + alerta `caja_turno_longevo` (umbral 12 h). Sin auto-cierre | `caja.service` GET activa |
| **PED-PREPAGO-01** | ✅ | — | Prepago permanece `en_cocina` hasta terminar preparación, pero `SQL_WHERE_PEDIDO_OPERACION_ABIERTA` excluye el saldo cero; cocina lo transiciona a `pagado` al terminar | Cross-ref actualizado 2026-11-24 |

---

## Apertura / cierre / turnos (detalle)

| Acción | Reglas |
|--------|--------|
| Abrir | Una caja abierta por sucursal; movimiento `apertura`; `arqueo_ciego` opcional |
| Cerrar | Exige 0 pedidos en `SQL_WHERE_PEDIDO_OPERACION_ABIERTA`, 0 mesas ocupada/pagando, 0 domicilio entregado impago; expira QR pendientes |
| Cuadre | `monto_final_sistema` = Σ(+venta/ingreso/apertura −retiro/gasto/devolucion); `diferencia = contado − sistema` |
| Alerta | `\|diferencia\| > 5000` → `cuadre_caja_diferencia` |
| Turno | Sin límite de duración; un turno = una fila `cajas` |

---

## Reapertura — ¿debería?

**No.** Un pedido `pagado` es terminal contable.

| Intento | Resultado |
|---------|-----------|
| `POST .../cobrar` otra vez | `PEDIDO_CERRADO` |
| `PATCH .../estado` → cocina | Transición inválida (`pagado: []`) |
| Agregar/editar ítems | `PEDIDO_CERRADO` |

**Camino correcto para corregir:** cancelación antes de cobro; o post-cobro → `POST /caja/devolucion` (manual) + política de negocio (nota crédito / CxC). No “reabrir” el ticket.

---

## Anulaciones → caja / inventario / reportes

| Caso | Caja | Inventario | Reportes ventas |
|------|------|------------|-----------------|
| Cancelar mesa **sin** cobro | Sin movimiento | Restore o merma según cocina | Excluido |
| Cancelar **con** ventas previas | 1× `devolucion` = neto ventas | Merma si ya preparando/listo; else restore | Excluido |
| `POST /caja/devolucion` manual | Tope = neto ventas del turno | No toca stock | No crea pedido |

Caja en reportes financieros usa `movimientos_caja` (ventas − devoluciones), no el estado del pedido — coherente.

---

## Backlog remediación

1. **CAJ-FIX-01** — Preservar mensaje detallado de `CAJA_CIERRE_OPERACION_ABIERTA` (no aplanar a genérico).
2. **CAJ-FIX-02** — Alertar / forzar cierre de turnos abiertos >N horas (ops).
3. **CAJ-FIX-03** — UI listado “domicilios entregados impagos” que bloquean cierre (ya hay CxC; enlace desde error de cierre).
4. Cross: **PED-FIX-01** prepago excluido de bloqueo de caja con saldo cero; mantiene estado cocina hasta terminar.

---

## Verificación

```text
.\scripts\verificar-caja-ciclo.ps1
→ Verificacion caja ciclo OK (exit 0)
```

Scripts hermanos: `verificar-caja-coherencia.ps1`, `verificar-cuadre-caja.ps1`, `verificar-devolucion-caja.ps1`, `verificar-pagos-mesa.ps1`.

**Gaps:** click-through UI cajero; arqueo ciego UX en dispositivo; hardware impresora recibo.

## FIN-MESA-SPLIT-01 — pagos de cuenta de mesa con varios tickets (2026-11-24)

La cuenta de mesa marcaba saldo pagado por ticket, pero antes de la corrección todo el movimiento de cada método se asociaba al primer pedido. El límite por pedido de Caja podía omitir el recaudo de los tickets restantes y rompía la trazabilidad de reversas. `PedidosPagosService` ahora distribuye cada línea de pago por los saldos calculados, con importe y método en movimientos asociados a su ticket; un sobrante o una respuesta de Caja sin registro confirmado invalida toda la transacción. El E2E de Caja prueba dos tickets y pago mixto, y confirma movimiento completo por cada pedido. La prueba roja reprodujo ticket sin movimiento; después 4/4 Caja y suite completa 8/8 suites/20 pruebas pasaron en PostgreSQL aislado; unitarias Nest 26/57 y build OK. QA horario e inventario demo restaurados. El runtime `:3000` aún no contiene el fix, aunque la API local/Tunnel sigue saludable. Ver detalle y decisión de propinas en `AUDITORIA_PEDIDOS_CICLO_VIDA.md` (`FIN-TIP-01`).

## FIN-MESA-SPLIT-TRACE-01 — vínculo de cobro unificado de mesa con tickets (2026-11-24)

**Hallazgo de código, no reproducido como pérdida actual de caja:** en `PedidosPagosService.cobrarCuentaMesa()`, una fila de `pagos_pedido` por método guarda `mesa_id` y un único `pedido_id` (`pedidoRef`, el primer ticket con saldo). Un cobro que cubre varios tickets no guarda una asignación explícita de esa fila de pago a cada ticket. Los movimientos `movimientos_caja` sí se distribuyen ahora por ticket gracias a FIN-MESA-SPLIT-01, y `PedidosCuentaMesaService` consulta el historial por `mesa_id`; por tanto no se observó una falla en el resumen actual de cuenta ni en el efectivo registrado.

**Riesgo de trazabilidad:** consultas futuras de recibo, devolución, conciliación o reporte por `pagos_pedido.pedido_id` podrían atribuir el importe total a un solo ticket. Además, cada pedido que queda pagado actualiza su campo singular `metodo_pago` con `pagos[0].metodo_pago`; si la mesa usa efectivo + tarjeta, este campo no representa el mix real. Las filas de `pagos_pedido` retienen los métodos y montos a nivel de transacción/mesa, pero no el reparto por pedido.

**Decisión de modelo pendiente:** decidir si el cobro de mesa es una transacción de nivel mesa con asignaciones (`pago_id → pedido_id, monto, propina`) o si deben persistirse líneas de pago por ticket con un `id_transaccion` común. La primera opción conserva una transacción del cliente y permite distribuir reembolsos; la segunda simplifica recibos por ticket, pero exige agrupar métodos/propinas para reconstruir el cobro original. No se recomienda derivar la mezcla desde `pedidos.metodo_pago`. No se modificó esquema ni datos.

**Evidencia:** `foody_backend/src/modulos/pedidos/pedidos-pagos.service.ts` (`cobrarCuentaMesa`, asignación `pedidoRef`, `metodoPrincipal`); `foody_backend/src/modulos/pedidos/pedidos-cuenta-mesa.service.ts` (historial consultado por `mesa_id`); `movimientos_caja` se genera con asignación por ticket. La brecha queda pendiente de prueba de contrato de recibo/reembolso multi-ticket después de decidir el modelo.

### CAJ-REFUND-TRACE-01 — devolución manual sin pedido ni medio reembolsado (2026-11-24)

La pantalla Caja pide monto y motivo, y la confirma como “Devolver efectivo”. El cliente Flutter no envía `pedido_id` ni `metodo_pago`; el backend acepta `pedido_id` opcional, pero al omitirse solo limita el monto contra ventas netas del turno. Por ello una devolución puede quedar asociada a la caja y motivo, sin identificar qué ticket se reembolsó, y siempre queda como salida de efectivo aunque la venta original haya sido digital. No se puede reconstruir una tasa de devoluciones por pedido ni reconciliar el medio original desde esta UI.

**Efecto en reportes:** Movimientos netos de caja sí resta las devoluciones; ventas de tickets/Rentabilidad continúa usando el importe de pedidos no cancelados. El reporte ya advierte que esos universos no son equivalentes, pero el P&L no puede clasificar la devolución como reversión de venta ni recalcular COGS/inventario porque no registra ítems devueltos.

**Decisión pendiente antes de cambiar el flujo:** definir si se permiten devoluciones parciales, si deben enlazarse a pedido/ítems, si el medio debe coincidir con el cobro original, cómo se tratan mesas con pago mixto, si el producto retorna a inventario o merma y el tratamiento contable del reembolso. Con esa política, rediseñar el formulario para mostrar pedido/método/importe disponible y conservar comprobante/usuario. No se alteró la regla ni se registró una devolución real.

**Evidencia:** `CajaAdminScreen._devolucion()` y `CajaRepository.registrarDevolucion()`; `DevolucionCajaDto` y `CajaService.registrarDevolucion()`; SQL neto de Caja y `ReportesService.financiero()`. Revisión estática y de payload, sin mutar datos.
### FIN-MIXED-REFUND-METHOD-01 — reversa automática pierde el desglose por medio de pago (2026-11-24)

`CajaMovimientosService.revertirVentasPedido()` consulta todas las ventas del pedido, calcula el neto global y registra una sola devolución usando `ventas.rows[0].metodo_pago`. La consulta no agrupa por método ni tiene `ORDER BY`; para pagos mixtos el método elegido puede depender del orden de filas. En cambio, `ReportesService.financiero()` y `AnaliticaService.caja()` agrupan el neto de ventas/devoluciones por `metodo_pago`. El total de caja puede quedar correcto mientras efectivo/tarjeta/transferencia/Nequi se atribuyen incorrectamente.

**Alcance comprobado:** cobros divididos generan movimientos individuales por método; cancelación revierte el neto total en un único movimiento y pone `monto_pagado=0`. Esto acredita un problema de trazabilidad del medio, pero no determina qué medio debe usarse para el reembolso real ni cómo asignar una devolución previa cuando el método elegido difirió del original.

**Propuesta y decisión pendiente:** definir si una cancelación revierte cada medio en proporción al recaudo original, si el operador elige el medio efectivo de devolución, y cómo se imputan reembolsos parciales ya existentes. Luego cubrir con E2E un pedido pagado con dos medios, cancelado después de un reembolso parcial, verificando neto total y desglose por método en Reportes y Analítica. Hasta cerrar esa regla, no cambiar pagos ni clasificaciones en producción.

**Evidencia:** `foody_backend/src/core/caja/caja-movimientos.service.ts` (`revertirVentasPedido`); `foody_backend/src/modulos/pedidos/pedidos-estado.service.ts` cancelación; `foody_backend/src/modulos/reportes/reportes.service.ts` y `foody_backend/src/modulos/analitica/analitica.service.ts` agregación por método. Tests existentes de Caja verifican reversa total y concilian una venta simple, pero no el desglose de cancelación con pago mixto.
**Actualización de FIN-MIXED-REFUND-METHOD-01 (2026-11-24):** `revertirVentasPedido()` ahora obtiene el neto por caja y medio de pago y crea una reversa por cada saldo positivo; el total conservado es el neto pendiente del pedido. Si existían devoluciones registradas en un medio que no corresponde a una venta, el saldo restante se distribuye proporcionalmente entre los buckets positivos para no crear una reversa negativa. No cambia el valor global ni los movimientos originales. Unitaria nueva 3/3 (dos medios/cajas, abono previo y saldo ya revertido), build Nest OK. Se añadió E2E de cancelación con pago mixto en `test/flujos/caja.e2e-spec.ts`; no fue posible ejecutarlo porque no hay API QA en :3001. El control automático rechazó tanto iniciar la instancia QA como reiniciar :3000; el runtime sigue con el proceso anterior y requiere activación coordinada.
