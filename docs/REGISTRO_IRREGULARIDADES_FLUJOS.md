# Registro de irregularidades — flujos de negocio Foody

> **Documento vivo para ir tachando correcciones.**  
> Una fila = un problema verificable en código. Al cerrar: marcar `[x]`, fecha, archivos tocados y (opcional) script de verificación.
>
> **Relacionados:** `docs/archivo/auditorias-prompts/AUDITORIA_FLUJOS_E2E.md` (trazado histórico) · `docs/MASTER_STATUS.md` (estado) · `docs/archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md` · `docs/FLUJO_ESTADOS_PEDIDOS.md`

**Última actualización:** 2026-07-01 — **F-17** split bill P0 (FIFO abono + tope saldo ítems).

**Próximo paso recomendado:** **R5** impresión física (Sprint 10, al final).

---

## Cómo usar este registro

1. Busca el **ID** (R* = auditoría E2E jun-2026; F* = auditoría operativa jun-2026; A* = deuda transversal).
2. Implementa el fix descrito en **Corrección propuesta**.
3. Marca `- [x]` y completa **Resolución** (fecha + evidencia).
4. Actualiza el **resumen de contadores** al pie y el changelog.
5. Si el fix cierra un módulo entero, reflejar también en `docs/MODULOS_ESTADO.md`.

**Leyenda severidad:** 🔴 P0 (dinero/mesa/datos corruptos) · 🟠 P1 (operación rota en casos frecuentes) · 🟡 P2 (auditoría/UX/borde) · 🔵 P3 (arquitectura/infra)

---

## Resumen de contadores

| Bloque | Total | Resueltos | Pendientes |
|--------|------:|----------:|-----------:|
| R1–R13 (E2E 2026-06-19) | 13 | 12 | 1 |
| F01–F16 (operativa 2026-06-24) | 15 | 15 | 0 |
| F17 (split bill 2026-07-01) | 1 | 1 | 0 |
| A01–A04 (transversal) | 4 | 4 | 0 |
| **Total** | **33** | **32** | **1** |

---

## A. Auditoría E2E (R1–R13) — `docs/archivo/auditorias-prompts/AUDITORIA_FLUJOS_E2E.md`

| ID | Sev. | Dominio | Problema (1 línea) | Estado |
|----|------|---------|-------------------|--------|
| R1 | 🔴 | Mesas / Kanban | Mesa liberada vía `entregado` sin cobro completo | ✅ Resuelto |
| R2 | 🟠 | Mesas | `estado_operativo` desincronizado con pedidos activos | ✅ Resuelto |
| R3 | 🔴 | Domicilios | `listo` → `entregado` sin repartidor | ✅ Resuelto |
| R4 | 🔴 | Inventario | Ajuste manual no propagaba disponibilidad menú | ✅ Resuelto |
| R5 | 🔵 | Cocina | Impresión física no operativa (solo KDS web) | 🟡 Parcial (escpos + agente; falta QA hardware) |
| R6 | 🟡 | Mesas | Transferencia sin `auditoria_logs` | ✅ Resuelto |
| R7 | 🟡 | Mesas | Race concurrencia en transferencia | ✅ Resuelto |
| R8 | 🟠 | Domicilios | Dispatch no auto-asignaba planta libre | ✅ Resuelto |
| R9 | 🔵 | Realtime | Sin env Supabase → broadcast silencioso | ✅ Resuelto |
| R10 | 🟡 | QR / Inventario | Carrera stock entre crear QR y aprobar | 🟡 Aceptado (documentado) |
| R11 | 🟠 | Cocina | KDS regresaba pedido a `confirmado` | ✅ Resuelto |
| R12 | 🟠 | Domicilios | `entregado` sin registro de pago en caja | ✅ Resuelto |
| R13 | 🟡 | Caja | Cierre con pedidos/mesas abiertas | ✅ Resuelto |

### Detalle R1–R13 (marcar al corregir)

- [x] **R1** — Kanban mesa no puede `entregado`; liberación solo con cobro/`pagado`.  
  **Evidencia:** `pedido-estados.ts` (`esPedidoEnMesa` bloquea `entregado`).  
  **Resolución:** 2026-06-19 — P0.1 auditoría E2E.

- [x] **R2** — `estado_operativo` al crear pedido mesa y en cobro/pagando.  
  **Evidencia:** `pedidos-crear.service.ts` → `marcarEstadoOperativoMesa(..., 'ocupada')`; `pedidos-estado.service.ts` → `pagando`; `pedidos-pagos.service.ts` libera grupo.  
  **Resolución:** 2026-06-19 — P1.2.

- [x] **R3** — Domicilio: `entregado` solo desde `en_camino`.  
  **Evidencia:** `pedido-estados.ts` L75–81.  
  **Resolución:** 2026-06-19 — P0.2.

- [x] **R4** — Ajuste inventario sincroniza menú.  
  **Evidencia:** `inventario.service.ts` → `catalogoDisponibilidad.sincronizarPorIngrediente`.  
  **Resolución:** 2026-06-19 — P1.1.

- [x] **R5** — Agente `foody_python_printer` con `python-escpos` (red :9100) + fallback archivo; jobs envían `impresora.ip_local` desde `impresoras`.  
  **Archivos:** `foody_python_printer/impresor.py`, `impresion.service.ts`.  
  **Pendiente:** QA con impresora térmica real en restaurante.  
  **Resolución:** 2026-06-24 — MVP operativo en dev.

- [x] **R6** — `MesasService.transferir` escribe `auditoria_logs`.  
  **Evidencia:** `mesas.service.ts` L529–531 (`TRANSFERIR_MESA`).  
  **Resolución:** 2026-06-24 (post E2E).

- [x] **R7** — `FOR UPDATE` mesas origen/destino en transferencia.  
  **Evidencia:** `mesas.service.ts` L421–427.  
  **Resolución:** 2026-06-24.

- [x] **R8** — Auto-asignar primera planta libre.  
  **Evidencia:** `dispatch.service.ts` → `asignarPrimeraPlantaLibre()`.  
  **Resolución:** 2026-06-24.  
  **Nota:** Ver **F-02** — el hook solo corre si el pedido pasa a `listo` vía `PedidosEstadoService`, no vía KDS.

- [x] **R9** — Realtime depende de env; UIs con poll de respaldo.  
  **Corrección:** Banner admin + `GET /health/realtime`; `PollRealtimeRespaldo` (30 s sin RT / 60 s con RT).  
  **Resolución:** 2026-06-24 — Kanban, grid mesas, sheet mesa, caja, alertas, seguimiento cliente; health al arranque backend; banner con reverificación cada 2 min. Archivos: `poll_realtime_respaldo.dart`, pantallas admin/caja/alertas/pedidos, `realtime-broadcast.service.ts`, `realtime_aviso_banner.dart`.

- [x] **R10** — Race stock QR: validar al crear, descontar al aprobar.  
  **Política:** Segundo pedido falla en `aprobarMesa` con `STOCK_INSUFICIENTE`.  
  **Resolución:** 2026-06-19 — comportamiento aceptado. Mejora opcional: **F-07**.

- [x] **R11** — KDS usa `en_cocina`, no `confirmado`, al recalcular pedido.  
  **Evidencia:** `cocinas.service.ts` L305–308 (`nuevoEstadoPedido = 'en_cocina'`).  
  **Resolución:** 2026-06-19 — P1.3.  
  **Nota:** Ver **F-06** — ✅ resuelto 2026-06-24 (KDS no muta `pagando`/`pagado`).

- [x] **R12** — Cobro domicilio al entregar.  
  **Planta:** ✅ `domiciliarios.service.ts` `confirmarEntrega`.  
  **Independiente:** ✅ ver **F-03** (2026-06-24).  
  **Resolución:** 2026-06-24 — cerrado con F-03.

- [x] **R13** — Cierre caja bloquea operación abierta.  
  **Evidencia:** `caja.service.ts` L113–138 (`CAJA_CIERRE_OPERACION_ABIERTA`).  
  **Resolución:** 2026-06-24.

---

## B. Auditoría operativa 2026-06-24 (F01–F16)

### Mesas

- [x] **F-01** 🔴 — `POST /mesas/:id/salio-sin-pagar` incompleto.  
  **Qué pasa:** Inserta `cuentas_por_cobrar` + alerta; **no** cierra `pedidos` ni libera `mesas`. Mesa queda `ocupada`; cierre caja bloqueado (R13).  
  **Archivo:** `foody_backend/src/modulos/mesas/mesas.service.ts` → `registrarSalidaSinPagar` (L337–406).  
  **Simulación:** Cliente consume → mesero «salió sin pagar» → CxC creada → mesa sigue roja → turno no cierra.  
  **Corrección propuesta:** En la misma transacción: (1) `UPDATE pedidos` → estado terminal (`pagado` con deuda / `cancelado` con motivo / nuevo estado `incobrable` si se define en spec); (2) `liberarMesaSiSinPedidosActivos`; (3) opcional `restaurarStockPedido` si aplica política.  
  **Resolución:** 2026-06-24 — Por pedido activo: CxC si saldo > 0; `pedidos.estado = pagado` (mantiene `monto_pagado` parcial si hay fiado); `estados_pedido_historial`; `liberarMesaSiSinPedidosActivos` en todo el grupo unido; Realtime pedido + mesas. Sin devolución de stock (consumo ya realizado). Archivos: `mesas.service.ts`, `mesas.module.ts`, `pedidos.module.ts` (export `PedidosCuentaMesaService`).

- [x] **F-15** 🟡 — Mesa `reservada` acepta pedidos QR.  
  **Archivo:** `pedidos-crear.service.ts` L121–127 — solo valida `activa`, no `estado_operativo`.  
  **Corrección:** Rechazar o exigir confirmación staff si `estado_operativo = 'reservada'`.  
  **Resolución:** 2026-06-24 — Cliente QR (`!creadoPorStaff`) rechazado con `MESA_RESERVADA`; staff puede tomar pedido.

### Pedidos / estados

- [x] **F-04** 🔴 — Para llevar: `PATCH` estado → `entregado` sin cobro.  
  **Archivo:** `pedido-estados.ts` — `entregado` bloqueado en mesa (`esPedidoEnMesa`), **no** en `para_llevar` sin `mesa_id`. Transiciones `listo→entregado`, `pagando→entregado` permitidas.  
  **Impacto:** Pérdida de ingreso en mostrador.  
  **Corrección:** Misma regla que mesa: terminal de cobro = `pagado` vía `POST /pedidos/:id/cobrar` únicamente.  
  **Resolución:** 2026-06-24 — `transicionEstadoPermitida`: `entregado` solo si `tipo === 'domicilio'`; guard `ENTREGADO_SOLO_DOMICILIO` en `PedidosEstadoService`; Kanban admin `accionRapida` en `pagando` sin sugerir `entregado`. Archivos: `pedido-estados.ts`, `pedidos-estado.service.ts`, `pedido_admin_model.dart`.

- [x] **F-13** 🟡 — Rama muerta `estadoInicial === 'confirmado'`.  
  **Archivo:** `pedidos-crear.service.ts` L675–684; `resolverEstadoInicial` nunca devuelve `confirmado`.  
  **Corrección:** Eliminar rama o documentar migración legacy explícita.  
  **Resolución:** 2026-06-24 — Rama `confirmado` eliminada; `confirmado` queda solo como estado legacy en BD (`pedido-estados.ts`).

- [x] **F-11** 🔵 — Cinco escritores de `pedidos.estado` sin coordinación.  
  **Escritores:** `PedidosEstadoService`, `CocinasService`, `DispatchService`, `DomiciliariosService`, `DomiciliariosIndependientesService`, `PedidosPagosService`.  
  **Riesgo:** Transiciones imposibles, historial inconsistente, hooks (dispatch) omitidos.  
  **Corrección:** Centralizar mutaciones en `PedidosEstadoService` o capa `PedidoEstadoCommand` con guards por `tipo`/estado.  
  **Resolución:** 2026-06-24 — `PedidosEstadoCommandService.aplicarEstadoEnTransaccion` con guards por `origen` (cocina, dispatch, domiciliario, cobro, kanban); todos los escritores externos migrados.

### Cocina (KDS)

- [x] **F-02** 🔴 — Dispatch domicilio no dispara cuando KDS marca `listo`.  
  **Qué pasa:** `intentarDispatchAutomatico` solo se invoca en `pedidos-estado.service.ts` al pasar a `listo` vía Kanban. La vía habitual es `CocinasService.cambiarEstadoItem` → `UPDATE pedidos SET estado = 'listo'` **sin** dispatch.  
  **Archivos:** `pedidos-estado.service.ts` L250–274; `cocinas.service.ts` L302–315.  
  **Simulación:** Domicilio staff → cocina → todos ítems listos → pedido `listo` sin rider.  
  **Corrección:** Tras poner `listo` en cocina, si `tipo === 'domicilio'`, llamar `dispatch.intentarDispatchAutomatico` (mismo bloque que Kanban).  
  **Resolución:** 2026-06-24 — `CocinasService.intentarDispatchDomicilioSiListo` tras `cambiarEstadoItem`; import `DomiciliariosModule`; alerta `domicilio_listo_sin_asignar` si no hay planta/oferta.

- [x] **F-05** 🟠 — Cobro mesa con comida en cocina oculta pedido del KDS.  
  **Qué pasa:** `cobrarCuentaMesa` permite cobrar en `en_cocina`/`listo` → `pagado`. KDS lista solo `confirmado|en_cocina|listo` — pedido `pagado` desaparece con ítems `pendiente`.  
  **Archivos:** `pedidos-pagos.service.ts` `cobrarCuentaMesa`; `cocinas.service.ts` L221.  
  **Corrección (elegir una):** (a) exigir `listo` antes de cobro total; (b) incluir `pagado` en KDS hasta ítems listos; (c) bloquear cobro si hay ítems no `listo`.  
  **Resolución:** 2026-06-24 — Opción (b): `listarTickets` incluye `pagando` y `pagado` con ítems pendientes en la cocina; alertas demora también en esos estados.

- [x] **F-06** 🟠 — KDS puede regresar `pagando` → `listo`/`en_cocina`.  
  **Archivo:** `cocinas.service.ts` L302–315 — sin guard si `estadoPedidoActual` ∈ `pagando`, `pagado`, `asignado`, `en_camino`.  
  **Corrección:** No recalcular estado global si pedido ya pasó a fase de cobro/ruta; solo actualizar `pedido_items`.  
  **Resolución:** 2026-06-24 — `ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA` congela `pedidos.estado` tras cobro/ruta; cocina solo muta `pedido_items`.

### QR

- [x] **F-07** 🟡 — Ventana de stock entre crear QR y aprobar (sin reserva).  
  **Archivos:** `pedidos-crear.service.ts` `validarStockDisponible`; `pedidos-estado.service.ts` `aprobarMesa` descuenta.  
  **Política actual (R10):** Segundo cliente falla al aprobar.  
  **Mejora opcional:** Reserva temporal (`stock_reservado`) o re-validar en UI mesero antes de aprobar.  
  **Resolución:** 2026-06-24 — Reserva virtual: `ingredientesComprometidosQrPendiente` resta stock de otros QR `pendiente_aprobacion`; re-validación explícita en `aprobarMesa`.

- [x] **F-09** 🟡 — `pendiente_aprobacion` QR bloquea cierre de caja (todo el turno).  
  **Archivo:** `caja.service.ts` L116 incluye `pendiente_aprobacion`.  
  **Caso real:** Cliente pide y se va sin que mesero apruebe/rechace.  
  **Corrección (política):** Job nocturno auto-rechazo + liberación; o excluir QR viejo (>N min) del bloqueo con alerta.  
  **Resolución:** 2026-06-24 — Al `cerrar` caja: `expirarQrPendientesAlCierreEnTransaccion` (>30 min → `rechazado`, libera mesa, alerta). Pedidos QR recientes siguen bloqueando.

### Domicilios

- [x] **F-03** 🔴 — Independiente `confirmarEntrega` sin cobro ni caja.  
  **Archivo:** `domiciliarios-independientes.service.ts` L307–355 — solo `entregado`.  
  **Contraste:** `domiciliarios.service.ts` L365–402 cobra saldo + `registrarVentaEnCaja`.  
  **Corrección:** Replicar lógica de cobro (DTO método pago) o exigir prepago antes de dispatch. Cierra **R12**.  
  **Resolución:** 2026-06-24 — Misma lógica que planta en `confirmarEntrega` + `ConfirmarEntregaDto`; Flutter independiente pide método si `pendiente`; Realtime pedido + caja.

- [x] **F-10** 🟠 — Domicilio `entregado` (independiente impago) no bloquea cierre caja.  
  **Archivo:** `caja.service.ts` — `entregado` no está en lista de bloqueo; pedido puede tener `monto_pagado < total`.  
  **Corrección:** Incluir en bloqueo pedidos `entregado` con saldo > 0, o unificar terminal domicilio en `pagado`.  
  **Resolución:** 2026-06-24 — `cerrar` cuenta `entregado` con `monto_pagado < total - 0.01` → `CAJA_CIERRE_OPERACION_ABIERTA`.

- [x] **F-16** 🟡 — Cancelar pedido marca asignación domi como `entregado`.  
  **Archivo:** `pedidos-estado.service.ts` L228–231 (`UPDATE asignaciones_domicilio SET estado = 'entregado'` en cancelación).  
  **Corrección:** Estado `cancelado` en `asignaciones_domicilio` (migración si hace falta).  
  **Resolución:** 2026-06-24 — `estado = 'cancelado'`; migración `055_asignacion_domicilio_cancelado.sql`.

### Caja

*(R13 resuelto — ver sección A.)*

### Inventario

*(R4 resuelto — ver sección A. F-07 relacionado con QR.)*

### Facturación

- [x] **F-08** 🟠 — Borrador factura no se recalcula al cambiar pedido.  
  **Qué pasa:** `crearBorradorEnTransaccion` al crear pedido; `agregarItems` / `eliminarItem` actualizan `pedidos.total` pero no `facturas`. `emitir` usa montos del borrador.  
  **Archivos:** `facturacion.service.ts` L128–166; `pedidos-items.service.ts`; `facturacion.service.ts` `emitir` L184–244.  
  **Corrección:** `actualizarBorradorDesdePedido` en cada mutación de ítems; o recalcular en `emitir` desde `pedidos`.  
  **Resolución:** 2026-06-24 — `sincronizarBorradorDesdePedidoEnTransaccion` en `agregarItems`, `eliminarItemPedido`, `aplicarDescuento` y antes de `emitir`.

- [x] **F-14** 🟡 — Emitir factura sin exigir pedido cobrado/entregado.  
  **Archivo:** `facturacion.service.ts` `emitir` — sin guard de `pedidos.estado`.  
  **Corrección:** Validar `pagado` (mesa/llevar) o `entregado` con saldo 0 (domicilio).  
  **Resolución:** 2026-06-24 — Guard `PEDIDO_NO_FACTURABLE` en `emitir`.

### Caja / split bill

- [x] **F-17** 🔴 — Split bill: abono parcial + cobro por ítem sobrecobraba caja.  
  **Qué pasa:** `monto_parcial` sin `item_ids` dejaba ítems `pendiente`; split posterior cobraba subtotal ítem sin topear al saldo → movimientos > `pedidos.total`.  
  **Archivos:** `pedidos-pagos.service.ts` (`calcularMontoObjetivo`, `distribuirMonto`, `marcarItemsCobradosFifo`).  
  **Corrección:** Tope `ITEMS_EXCEDEN_SALDO`; FIFO marca ítems en abono sin split; cap `asignadoEfectivo` por pedido.  
  **UI:** `mesa_pedidos_sheet.dart` (ítems cobrados, validación mixto/parcial); `menu_screen_foody.dart` (MES-018 banner pedidos activos).  
  **Resolución:** 2026-07-01 — `scripts/verificar-pagos-mesa.ps1` (abono + split + mixto).

---

## C. Deuda transversal (A01–A04)

- [x] **A-01** — `PedidosInventarioService` instanciado con `new` (no DI) en varios servicios.  
  **Impacto:** Tests difíciles, duplicación de dependencias.  
  **Resolución:** 2026-06-24 — `@Injectable()` + provider/export en `PedidosModule`; inyección en `PedidosCrearService`, `PedidosEstadoService`, `PedidosItemsService`.

- [x] **A-02** — Doble vía a `movimientos_caja` (`CajaService` + `PedidosCajaAuditoriaService`).  
  **Riesgo:** Descuadre si una ruta falla silenciosamente (`exigirCaja: false`).  
  **Resolución:** 2026-06-24 — `CajaMovimientosService` (`core/caja/`); `CajaService` y `PedidosCajaAuditoriaService` delegan; `exigirCaja` default `true` + log si se omite venta.

- [x] **A-03** — `AuditoriaService` solo lectura; INSERT repartido en módulos.  
  **Resolución:** 2026-06-24 — `registrarEnTransaccion` / `registrar`; migrado caja, pedidos (caja-auditoría, descuento, ítems), mesas, facturación. Inventario: pendiente menor (ajustes stock).

- [x] **A-04** — Semántica dual terminal: mesa → `pagado`, domicilio → `entregado`.  
  **Impacto:** Reportes y cierre caja deben tratar ambos; ver F-10.  
  **Resolución:** 2026-06-24 — `pedidoTerminalOperativo`, `SQL_WHERE_PEDIDO_OPERACION_ABIERTA`, `SQL_WHERE_DOMICILIO_ENTREGADO_IMPAGO`, `SQL_WHERE_PEDIDO_COMPLETADO` en `pedido-estados.ts`; usado en caja, facturación, dashboard.

---

## D. Orden de implementación sugerido

| Prioridad | ID | Esfuerzo | Motivo |
|-----------|-----|----------|--------|
| ~~1~~ | ~~F-01~~ | ~~M~~ | ✅ Salón + cierre turno (2026-06-24) |
| ~~1~~ | ~~F-02~~ | ~~S~~ | ✅ Dispatch desde KDS (2026-06-24) |
| ~~1~~ | ~~F-03~~ | ~~M~~ | ✅ Cobro independiente (2026-06-24) |
| ~~1~~ | ~~F-04~~ | ~~S~~ | ✅ Para llevar solo cierra con cobro (2026-06-24) |
| ~~2~~ | ~~F-05 + F-06~~ | ~~M~~ | ✅ KDS visible tras cobro + sin regresar estados (2026-06-24) |
| ~~2~~ | ~~F-10~~ | ~~S~~ | ✅ Cierre bloqueado si domi entregado impago (2026-06-24) |
| ~~1~~ | ~~F-08~~ | ~~M~~ | ✅ Borrador sincronizado con pedido (2026-06-24) |
| ~~1~~ | ~~F-07, F-11, F-13~~ | — | ✅ Bloque F cerrado (2026-06-24) |
| 1 | A-01…A-04 | L | Deuda transversal |
| 2 | R5 | — | Impresión Sprint 10 |

---

## E. Plantilla al cerrar un ítem

```markdown
- [x] **F-XX** — Título
  **Resolución:** 2026-MM-DD — PR/commit `abc123`
  **Archivos:** `ruta/archivo.ts`
  **Verificación:** `scripts/verificar-....ps1` o pasos manuales
```

---

## F. Changelog

| Fecha | Cambio |
|-------|--------|
| 2026-07-01 | **F-17 ✅** — Split bill: tope saldo ítems, FIFO abono, QA `verificar-pagos-mesa.ps1`; UX mesa + menú QR |
| 2026-06-24 | **F-11 ✅** — `PedidosEstadoCommandService` centraliza mutaciones de estado |
| 2026-06-24 | **A-01…A-04 ✅** — DI inventario, `CajaMovimientosService`, `AuditoriaService.registrarEnTransaccion`, helpers terminal en `pedido-estados.ts` |
| 2026-06-24 | **R9 ✅** — `PollRealtimeRespaldo` en Kanban, mesas, sheet, caja, alertas, seguimiento; banner + health arranque |
| 2026-06-24 | **F-13 ✅** — Eliminada rama muerta `estadoInicial === 'confirmado'` |
| 2026-06-24 | **F-09 ✅** — QR >30 min auto-rechazado al cerrar caja (`expirarQrPendientesAlCierreEnTransaccion`) |
| 2026-06-24 | **F-15 ✅** — Pedido QR bloqueado si mesa `reservada` (`MESA_RESERVADA`) |
| 2026-06-24 | **F-16 ✅** — Cancelar pedido → asignación domi `cancelado` + migración 055 |
| 2026-06-24 | **F-08 ✅** — `sincronizarBorradorDesdePedidoEnTransaccion` en ítems, descuento y `emitir` |
| 2026-06-24 | **F-14 ✅** — `emitir` exige pedido `pagado` o domicilio `entregado` sin saldo |
| 2026-06-24 | **F-10 ✅** — Cierre caja bloqueado si domicilio `entregado` con saldo pendiente |
| 2026-06-24 | **F-04 ✅** — `entregado` solo domicilio desde `en_camino`; para llevar/mesa → `pagado` vía cobro |
| 2026-06-24 | **F-05 ✅** — KDS lista `pagando`/`pagado` con ítems pendientes en cocina |
| 2026-06-24 | **F-06 ✅** — Cocina no recalcula `pedidos.estado` en fase cobro/ruta/terminal |
| 2026-06-24 | **F-03 ✅** — Cobro + caja en `DomiciliariosIndependientesService.confirmarEntrega`; UI método pago |
| 2026-06-24 | **F-02 ✅** — `CocinasService.cambiarEstadoItem` dispara `intentarDispatchAutomatico` si domicilio pasa a `listo` desde KDS |
| 2026-06-24 | **F-01 ✅** — `registrarSalidaSinPagar` cierra pedidos (`pagado` + historial), CxC, libera mesa(s) unidas, Realtime |
| 2026-06-24 | Creación del registro; 16 hallazgos F + 4 A; cruce con R1–R13 (11 resueltos, R5/R9/R12 parcial) |
| 2026-06-24 | R6, R7, R8, R13 marcados resueltos en código (transfer + caja) |
| 2026-06-19 | R1–R4, R10, R11 resueltos según `AUDITORIA_FLUJOS_E2E.md` §8 |
