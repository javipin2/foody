# Auditoría — Domicilios (Prompt 16)

> **Fecha:** 2026-08-06  
> **Alcance:** flujo pedido→asignación→entrega→cobro; estado domiciliario vs admin; cancel mid-ruta.  
> **Verificación:** `scripts/verificar-domicilios-ciclo.ps1` (OK, exit 0).  
> Código: `domiciliarios.service.ts` · `dispatch.service.ts` · `domiciliarios-independientes.service.ts` · `pedidos-estado.service.ts`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

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

### Gaps

| ID | Gap |
|----|-----|
| **DOM-CANCEL-INDEP-01** | Cancel **no** restaura `domiciliarios_sesiones.disponible` |
| **DOM-CANCEL-OFERTA-01** | Cancel **no** cierra `ofertas_pedido` activas |
| **DOM-RT-INDEP-01** | `pedidoDesasignado` RT solo notifica planta |

---

## Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **DOM-FLOW-01** | ✅ | — | Ciclo planta + cobro al entregar | Script A |
| **DOM-SKIP-01** | ✅ | — | Bloqueo `listo→entregado` | Script A |
| **DOM-STATE-01** | ✅ | — | `ocupado` admin coherente con ruta | Script A/B |
| **DOM-CANCEL-01** | ✅ | — | Admin cancela mid-ruta; asignación cancelada | Script C |
| **DOM-CANCEL-WHO-01** | ✅ | — | Cliente/domi no cancelan mid-ruta | Script C |
| **DOM-CANCEL-INDEP-01** | 🟡 | Media | Cancel no libera `disponible` indep | Code probe D |
| **DOM-CANCEL-OFERTA-01** | 🟡 | Baja | Cancel no toca ofertas activas | Code probe D |
| **DOM-EVID-01** | 🟡 | Baja | Sin foto/comprobante de entrega | DTO solo metodo_pago |
| **CAJ-DOM-IMPAGO-01** | 🟡 | — | (cross) entregado parcial bloquea cierre caja | Prompt 13 |
| **AQ-CYCLE-01** | 🟣 | — | (cross) ciclo Nest pedidos↔domiciliarios | Arquitectura |

---

## Backlog remediación sugerido

1. **DOM-FIX-01** — Al cancelar: `UPDATE sesiones SET disponible=true` si indep tenía la asignación.
2. **DOM-FIX-02** — Cancelar/expirar `ofertas_pedido` activas del pedido.
3. **DOM-FIX-03** — Broadcast desasignación también a canal indep.
4. **DOM-FIX-04** — (opcional producto) evidencia foto al confirmar entrega.

---

## Verificación

```powershell
.\scripts\verificar-domicilios-ciclo.ps1
# exit 0
```

Relacionados: `verificar-flujo-domicilio.ps1`, `verificar-ofertas-independiente.ps1`, `verificar-fiado-domiciliario.ps1`.

**Gaps:** click-through app domi; foto evidencia; E2E indep cancel mid-ruta con oferta viva.
