# Auditoría — Pedidos ciclo de vida (Prompt 11)

> **Fecha:** 2026-08-06  
> **Alcance:** máquina de estados, transiciones inválidas vía API, efectos laterales (stock/caja/mesa/historial/impresión), edición post-cocina.  
> **Verificación:** `scripts/verificar-pedidos-ciclo-vida.ps1` (OK, exit 0).  
> Spec viva: [`FLUJO_ESTADOS_PEDIDOS.md`](FLUJO_ESTADOS_PEDIDOS.md) · Código: `pedido-estados.ts`, `pedidos-estado-command.service.ts`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta corta |
|----------|-----------------|
| ¿Hay máquina de estados? | **Sí** — `TRANSICIONES_PEDIDO` + `transicionEstadoPermitida` + guards por `origen` en `PedidosEstadoCommandService` |
| ¿Se puede forzar transición inválida por API? | **No** vía `PATCH /pedidos/:id/estado` (DTO + máquina). **Sí parcialmente** vía `POST .../cobrar` (salta a `pagado` desde casi cualquier no-terminal) y vía `POST /mesas/:id/salio-sin-pagar` (UPDATE directo fuera del command service) |
| Ciclo mesa creado→cocina→cobrado→cerrado | **OK** — stock, historial, mesa, caja, `pagos_pedido`, items `cobrado` verificados en vivo |
| Edición tras enviado a cocina | **Permitida** hasta terminal (`pagado`/`entregado`/`cancelado`/`rechazado`); descuenta stock, reimprime, merma+alerta si ítem ya `preparando`/`listo` |

---

## Estados posibles (13)

Fuente: `foody_backend/src/modulos/pedidos/pedido-estados.ts`

| Estado | Terminal | Notas |
|--------|:--------:|-------|
| `pendiente_aprobacion` | | Solo mesa QR cliente |
| `pendiente` | | Cliente domi/llevar o domi staff |
| `confirmado` | | Legacy; UI = cocina |
| `en_cocina` | | Activa stock si no descontado |
| `listo` | | Dispara dispatch domicilio |
| `pagando` | | Solo mesa / para llevar |
| `asignado` | | Solo domicilio (dispatch/app) |
| `en_camino` | | Solo domicilio |
| `entregado` | ✓* | *Terminal operativo domicilio si cobrado |
| `pagado` | ✓ | Solo vía cobro / salió-sin-pagar |
| `cancelado` | ✓ | |
| `rechazado` | ✓ | QR / rechazo |

**BD:** `pedidos.estado` es `text` **sin CHECK** (`005_pedidos.sql`) — validación 100% NestJS.

---

## Transiciones válidas (`TRANSICIONES_PEDIDO`)

```
pendiente_aprobacion → en_cocina | rechazado | cancelado
pendiente            → en_cocina | cancelado
confirmado           → en_cocina | listo | pagando | cancelado
en_cocina            → listo | pagando | cancelado
listo                → pagando | entregado | cancelado
pagando              → entregado | cancelado
asignado             → en_camino | cancelado
en_camino            → entregado | cancelado
entregado|pagado|cancelado|rechazado → ∅
```

Reglas extra en `transicionEstadoPermitida`:

- `pagando` **prohibido** en `tipo=domicilio`
- `entregado` **prohibido** si no es domicilio (salón cierra con `pagado`)
- domicilio: `entregado` **solo** desde `en_camino`

Guards por origen (`PedidosEstadoCommandService.transicionPermitidaParaOrigen`):

| Origen | Regla |
|--------|-------|
| `kanban` | `transicionEstadoPermitida` |
| `cobro` | → `pagado`/`pagando` desde cualquier no-`cancelado`/`rechazado`/`pagado` |
| `cocina` | solo → `en_cocina`/`listo`; bloqueado si inmutable |
| `dispatch`/`domiciliario` | `listo→asignado`, `asignado→en_camino`, `en_camino→entregado` |
| `aprobacion_qr` | solo `pendiente_aprobacion→en_cocina` |
| `sistema` | QR expirado → `rechazado` o mapa Kanban |

---

## Endpoints que mutan estado

| Método | Ruta | Origen efectivo |
|--------|------|-----------------|
| PATCH | `/pedidos/:id/estado` | `kanban` |
| PATCH | `/pedidos/:id/aprobar` | `aprobacion_qr` |
| PATCH | `/pedidos/:id/rechazar` | vía Kanban a `rechazado` |
| POST | `/pedidos/:id/cobrar` · `/pedidos/mesa/:id/cobrar` | `cobro` |
| POST | `/pedidos/:id/cancelar` (público) | `kanban` cancelado |
| PATCH | `/cocina/items/:id/estado` | `cocina` (recalcula pedido) |
| POST | `/domiciliarios-planta/asignar` · ofertas | `domiciliario`/`dispatch` |
| PATCH | `/domiciliario/.../en-camino` · `confirmar-entrega` | `domiciliario` |
| POST | `/caja/cerrar` | `sistema` (QR expirados) |
| POST | `/mesas/:id/salio-sin-pagar` | **UPDATE directo** (bypass) |

---

## Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **PED-PREPAGO-01** | 🟣 | **Alta (prod)** | Para llevar / mostrador con método de caja al crear: se registra venta + `monto_pagado=total` pero **estado queda `en_cocina`**. `POST .../cobrar` responde «No hay saldo pendiente». El pedido sigue en `SQL_WHERE_PEDIDO_OPERACION_ABIERTA` → **bloquea cierre de caja** aunque ya está cobrado. | `pedidos-caja-auditoria.service.ts:35-48` + `pedidos-crear.service.ts:885-899`; script B5b: estado=`en_cocina` monto=8000 total=8000; cobrar → `SIN_SALDO` aplanado |
| **PED-BYPASS-01** | ✅ | Media | `POST /mesas/:id/salio-sin-pagar` ahora usa `PedidosEstadoCommandService` (montos aparte; estado+historial en la puerta F-11). | `mesas.service.ts`; script D OK |
| **PED-COBRO-SKIP-01** | 🟡 | Media | Origen `cobro` permite `en_cocina`→`pagado` (salta `listo`/`pagando`). Intencional para caja, pero debilita la máquina Kanban. | `pedidos-estado-command.service.ts:111-116`; script B5 OK |
| **PED-EDIT-01** | 🟡 | Media | Ítems editables en `en_cocina`/`listo`/`pagando` (solo bloquea terminales). Agregar descuenta stock; editar pone `reimprimir`; borrar ítem `preparando`/`listo` → merma + alerta `item_eliminado_post_cocina`. | `pedidos-items.service.ts:17-22,70-77,670-691,1099-1124`; script C OK |
| **PED-CHECK-01** | 🟡 | Baja | Sin CHECK/ENUM en `pedidos.estado` en Postgres — inserts SQL directos pueden meter estados basura. | `005_pedidos.sql`; script E chk=0 |
| **PED-DOC-01** | ✅ | Baja | Doc flujo mostraba `entregado` en salón; alineado al código 2026-08-06 | `FLUJO_ESTADOS_PEDIDOS.md` |
| **PED-API-DTO-01** | ✅ | — | `pagado` no está en `CambiarEstadoPedidoDto` → PATCH a `pagado` = 400 validación. | DTO + script B1 |
| **PED-INV-01** | ✅ | — | Transiciones inválidas Kanban rechazadas: `en_cocina→entregado`, `→asignado`, `pagando→entregado` mesa, `cancelado→en_cocina`, estado inventado. | Script B |
| **PED-FLOW-01** | ✅ | — | Ciclo mesa: crear→`en_cocina`(stock+historial+mesa ocupada)→`listo`→`pagando`(mesa)→cobrar→`pagado`(caja+pagos+items+mesa libre). | Script A HIST `en_cocina>listo>pagando>pagado` |

---

## Efectos laterales por paso (mesa staff)

| Paso | Stock | Caja | Mesa | Historial | Realtime / impresión |
|------|-------|------|------|-----------|----------------------|
| Crear staff → `en_cocina` | Descuenta (Tx) | No (mesa diferido) | `ocupada` | INSERT | Post: cocina+impresión |
| → `listo` | — | — | — | INSERT | Pedido RT |
| → `pagando` | — | — | `pagando` | INSERT | FCM mesera |
| Cobrar → `pagado` | — | Venta (Tx) | `libre` | INSERT | Pedido+mesas+caja RT |
| Cancelar post-cocina | Merma o restaurar | Reversa ventas | Libera | INSERT | RT |
| Agregar ítem post-cocina | Descuenta delta | — | — | Auditoría | Reimprime comanda |
| Eliminar ítem `preparando` | Merma | — | — | Alerta alto | Reimprime |

---

## Edición después de enviado a cocina (detalle)

`ESTADOS_PEDIDO_CERRADO` = `entregado|cancelado|rechazado|pagado`.

1. **Agregar ítems** (`POST /pedidos/:id/items`): permitido; si `stock_descontado`, descuenta al vuelo; notifica cocina (reimpresión).
2. **Editar cantidad/toppings** (`PATCH .../items/:itemId`): permitido; si cambia cantidad/toppings → `estado_cocina` vuelve a `pendiente`; `reimprimir=true` si pedido en cocina/listo.
3. **Eliminar** (`DELETE`): no permite último ítem; si ítem `preparando`/`listo` → alerta `item_eliminado_post_cocina` + merma (no restaura stock).
4. **Comensal** (`PATCH .../comensal`): no valida estado del pedido (solo etiqueta).

---

## Backlog remediación (orden)

1. **PED-FIX-01** — Prepago para llevar/mostrador: al registrar caja en creación, transicionar a `pagado` (o estado terminal operativo) **o** excluir de `SQL_WHERE_PEDIDO_OPERACION_ABIERTA` cuando `monto_pagado >= total`.
2. **PED-FIX-02** — `salio-sin-pagar` → usar `PedidosEstadoCommandService` con origen `cobro` o `sistema`.
3. **PED-FIX-04** (opcional) — CHECK SQL `pedidos.estado IN (...)`.
4. **PED-FIX-05** (opcional) — Restringir edición de ítems en `pagando` o exigir permiso extra.

---

## Verificación

```text
.\scripts\verificar-pedidos-ciclo-vida.ps1
→ Verificacion pedidos ciclo de vida OK (exit 0)
```

Cobertura: ciclo mesa completo · 6+ transiciones inválidas · cobro salto · prepago bug · edición+merma+reimpresión · salió-sin-pagar · CHECK ausente.

**Gaps:** click-through UI Kanban/dispositivo no corrido; domicilio E2E completo (ya cubierto por `verificar-flujo-domicilio.ps1` / cobro-domicilio).

**Consistencia cross-módulo (Prompt 29):** prepago alimenta gap caja↔reportes — ver **CONS-REP-OPEN-01** + **CONS-PROMO-ADD-01** en [`AUDITORIA_CONSISTENCIA_MODULOS.md`](AUDITORIA_CONSISTENCIA_MODULOS.md).

**Casos viernes (Prompt 30):** add post-`listo` = **VIE-01**; cobro pre-listo = **VIE-05/13** (decisión A/B/C) — [`AUDITORIA_CASOS_VIERNES.md`](AUDITORIA_CASOS_VIERNES.md).
