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
| **PROMO-DEL-01** | ✅ | — | Borrar promoción deja `pedidos.promocion_id` en NULL por FK `ON DELETE SET NULL` | Migración 089 |
| **PROMO-MANUAL-01** | ✅ | — | Al aplicar descuento manual se limpia `promocion_id` para no afirmar que conserva el descuento de la promo | `pedidos-descuento.service.ts:126` |

---

## Backlog remediación sugerido

1. **PROMO-FIX-01** — Flag `aplica_a_combos` / exclusividad combo↔promo.
2. **PROMO-FIX-02** — ✅ Resuelto: FK promocional `ON DELETE SET NULL` (migración 089).
3. **PROMO-FIX-03** — ✅ Resuelto: el descuento manual limpia `promocion_id`; conservar la auditoría de la operación.
4. **PROMO-FIX-04** — ✅ Resuelto en fuente: agregar, editar y eliminar líneas reutilizan el recálculo de promoción; el verificador integrado cubre agregar. Mantener pruebas dedicadas de edición/eliminación. Ver **CONS-PROMO-ADD-01** ([`AUDITORIA_CONSISTENCIA_MODULOS.md`](AUDITORIA_CONSISTENCIA_MODULOS.md)).

---

## Verificación

```powershell
.\scripts\verificar-promociones-precios.ps1
# exit 0
```

**Gaps:** click-through stories UI; descuento manual E2E no corrido en este script.

**Matiz comercial por confirmar:** después de aplicar una promo a un pedido abierto, si la promo se desactiva, las rutas de agregar/editar/eliminar líneas siguen leyendo su porcentaje/monto por `promocion_id` y sucursal, sin exigir `activa=true`. El pedido existente puede conservar el beneficio al modificarse; pedidos nuevos sí deben validar la promo activa. Fuente comprobada, pero el script no prueba desactivar→agregar y la regla comercial no está especificada. Decidir si esa continuidad es parte del snapshot o si las líneas nuevas deben perder el beneficio; no se cambió el comportamiento.

## Reconciliación de estado (2026-11-24)

La ficha histórica se actualizó con el estado actual de código/migraciones: PROMO-DEL-01 y PROMO-MANUAL-01 están resueltos; PROMO-FIX-04/CONS-PROMO-ADD-01 también está corregido en fuente y el script integrado valida el caso de agregar ítems. En edición/eliminación de ítems existe un helper compartido, pero faltan casos QA dedicados. Permanece PROMO-STACK-01 como decisión del negocio: hoy combo y promoción pueden apilarse. No se cambió código ni se alteraron datos para esta reconciliación.
