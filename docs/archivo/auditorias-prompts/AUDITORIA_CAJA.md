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
Para llevar con método de caja al crear: venta inmediata (ver **PED-PREPAGO-01**).

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
| **PED-PREPAGO-01** | 🟣 | Alta | (Prompt 11) Prepago deja `en_cocina` + venta en caja → también bloquea cierre hasta cancelar/cerrar estado | Cross-ref |

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
4. Cross: **PED-FIX-01** prepago → estado terminal (deja de bloquear caja).

---

## Verificación

```text
.\scripts\verificar-caja-ciclo.ps1
→ Verificacion caja ciclo OK (exit 0)
```

Scripts hermanos: `verificar-caja-coherencia.ps1`, `verificar-cuadre-caja.ps1`, `verificar-devolucion-caja.ps1`, `verificar-pagos-mesa.ps1`.

**Gaps:** click-through UI cajero; arqueo ciego UX en dispositivo; hardware impresora recibo.
