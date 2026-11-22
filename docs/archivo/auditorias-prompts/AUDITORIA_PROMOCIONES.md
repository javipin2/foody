# Auditoría — Promociones y precios (Prompt 18)

> **Fecha:** 2026-08-06  
> **Alcance:** desactivar promo con pedido abierto; cambio de precio con pedidos vivos; apilado combo+promo.  
> **Verificación:** `scripts/verificar-promociones-precios.ps1` (OK, exit 0).  
> Código: `promociones.service.ts` · `pedidos-crear.service.ts` · `pedidos-items.service.ts` · `pedidos-pagos.service.ts`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| Desactivar promo en pedido abierto | Descuento **se mantiene** (snapshot en `pedidos.descuento`). Pedidos nuevos ya no la usan. Cobro = total congelado. |
| Cambiar precio con pedidos abiertos | Ítems ya creados: **precio viejo** (`precio_unitario`). Ítems nuevos: **precio catálogo actual**. Cobro = suma de snapshots. |
| Combos + promos apiladas | **Sí se apilan**: combo (`precio_fijo`) + 1 promo sobre el subtotal. Máx. **1** promo por pedido (código XOR automática; no suma 2 %). |

---

## Modelo

- Tabla: `estados_promociones` (no `pedido_promocion`).
- Pedido: `descuento`, `motivo_descuento`, `promocion_id` (FK única).
- Ítems: `pedido_items.precio_unitario` (snapshot al insertar).

---

## A) Desactivar promo abierta

```
Crear promo 10% → pedido con codigo → descuento=800, total=7200
PATCH activa=false
  → pedido sigue 800/7200
  → codigo rechazado en pedido NUEVO
  → cobro caja = 7200
```

---

## B) Cambio de precio

```
Pedido item @8000
PATCH producto.precio = 12000
  → item abierto sigue 8000; total sin cambio
POST /items (mismo producto)
  → nuevo item @12000
  → total = 20000
cobrar → caja 20000
```

---

## C) Apilado

| Regla | ¿Existe? |
|-------|----------|
| 1 promo por pedido | ✅ (`promocion_id` único; if código else auto) |
| Mejor automática (no suma) | ✅ 15% gana a 5% → 1200, no 1600 |
| Combo XOR promo | ❌ — combo + promo **coexisten** (10% sobre 25000 = 2500) |
| % XOR monto en misma promo | ✅ validación DTO |

Si el negocio **no** quiere descuento sobre combo: **gap** — no hay flag `excluye_promocion`.

---

## Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **PROMO-SNAP-01** | ✅ | — | Desactivar no recalcula pedido abierto | Script A |
| **PROMO-NEW-01** | ✅ | — | Código inactivo falla en pedido nuevo | Script A |
| **PRECIO-SNAP-01** | ✅ | — | Ítem abierto conserva precio | Script B |
| **PRECIO-ADD-01** | ✅ | — | Ítem nuevo usa catálogo actual | Script B |
| **PRECIO-COBRO-01** | ✅ | — | Cobro = total snapshot (no relee catálogo) | Script A/B |
| **PROMO-STACK-01** | 🟡 | Media | Combo + promo se apilan (sin anti-stack) | Script C |
| **PROMO-ONE-01** | ✅ | — | Máx. 1 promo; auto elige la mejor | Script C |
| **PROMO-DEL-01** | 🟡 | Baja | DELETE hard puede fallar si FK pedidos (sin SET NULL) | Código/migración |
| **PROMO-MANUAL-01** | 🟡 | Baja | Descuento manual sobrescribe monto sin limpiar `promocion_id` | `pedidos-descuento.service` |

---

## Backlog remediación sugerido

1. **PROMO-FIX-01** — Flag `aplica_a_combos` / exclusividad combo↔promo.
2. **PROMO-FIX-02** — Al DELETE: `ON DELETE SET NULL` o soft-delete.
3. **PROMO-FIX-03** — Descuento manual limpia `promocion_id` o deja audit trail claro.
4. **PROMO-FIX-04** — Recalcular % al agregar ítems (hoy monto fijo) = **CONS-PROMO-ADD-01** ([`AUDITORIA_CONSISTENCIA_MODULOS.md`](AUDITORIA_CONSISTENCIA_MODULOS.md)).

---

## Verificación

```powershell
.\scripts\verificar-promociones-precios.ps1
# exit 0
```

**Gaps:** click-through stories UI; descuento manual E2E no corrido en este script.
