# Auditoría — Inventario (Prompt 14)

> **Fecha:** 2026-08-06  
> **Alcance:** descuento automático vs manual, propagación insumos→subrecetas→platos, alertas stock bajo, auditoría de ajustes.  
> **Verificación:** `scripts/verificar-inventario-ciclo.ps1` (OK, exit 0).  
> Código: `pedidos-inventario.service.ts` · `costeo.service.ts` (`expandirReceta`) · `inventario.service.ts` · `alertas-riesgo.service.ts`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| ¿Descuento automático al confirmar? | **Sí** — al entrar a cocina (`en_cocina` / `confirmado`). Gap histórico “solo manual” **cerrado** (flag `stock_descontado`, ~041). No es ajuste manual. |
| ¿Propaga insumos → subrecetas → platos? | **Sí** — `expandirReceta` recursivo (o lote → insumo `es_subreceta`). Script: plato→sub→Papa −100g. |
| ¿Alertas stock bajo? ¿A quién? | **Sí** — tipo `stock_minimo_alcanzado`, nivel **medio**. Panel admin + Realtime. **Sin FCM** (solo alto/crítico). Sin cron de stock. |
| ¿Ajustes manuales auditados? | **Parcial** — `movimientos_ingrediente` guarda **quién + cuándo + por qué**; **no** escribe `auditoria_logs`. API/UI de movimientos **omitens `usuario_id`**. |

---

## Cuándo se descuenta stock

```
validarStockDisponible (siempre al crear)
  ↓
estadoActivaCocina(estado)?  →  descontarStockPedido + stock_descontado=true
```

| Origen | Estado inicial | ¿Descuenta? |
|--------|----------------|-------------|
| Staff mesa / para llevar | `en_cocina` | **Sí, al crear** |
| Staff domicilio | `pendiente` | Al pasar a cocina |
| Cliente QR mesa | `pendiente_aprobacion` | Al **aprobar** |
| Cliente domicilio/llevar | `pendiente` | Al pasar a cocina |
| Agregar ítems | — | Solo si pedido ya tenía `stock_descontado` |
| Cancel / rechazo | — | Restaura o merma |

Evidencia script A: staff mesa → `en_cocina`, Papa −200g, 1 movimiento `venta` con `pedido_id`.

---

## Cadena 3 capas

```
producto.receta_id
  → receta_items (ingrediente | subreceta | empaque)
    → subreceta: expandirReceta recursivo
       └─ si usa_produccion_lote → descuenta Prep:… (es_subreceta)
```

Script B: subreceta 50g Papa / 100g resultado; plato pide 200g sub → **necesita 100g** Papa; venta descuenta 100g.

---

## Alertas stock bajo

| Aspecto | Detalle |
|---------|---------|
| Tipo | `stock_minimo_alcanzado` |
| Umbral | `stock_posterior <= stock_minimo` tras venta |
| Nivel | `medio` |
| Destino | `alertas_riesgo` + Realtime `alertaNueva` → `AlertasAdminScreen` |
| FCM | **No** (push solo `alto`/`critico` → admin/gerente) |
| Cron | **No** — `POST /alertas/evaluar` no evalúa stock |
| Ajuste manual | **No** dispara alerta al bajar stock con PATCH |
| Dedup | `deduplicar: true` — no reinserta si ya hay pendiente del mismo insumo |

También existe `intento_pedido_sin_stock` (nivel alto → **sí FCM**) cuando falla validación.

---

## Ajustes manuales

**Endpoint:** `PATCH /inventario/:id` con `stock_nuevo` + `motivo_ajuste`.

| Campo / destino | ¿Registrado? |
|-----------------|--------------|
| `movimientos_ingrediente.usuario_id` | ✅ |
| `movimientos_ingrediente.motivo` | ✅ (default «Ajuste manual») |
| `movimientos_ingrediente.created_at` | ✅ |
| `auditoria_logs` | ❌ |
| API `GET .../movimientos` expone `usuario_id` | ❌ |
| UI movimientos muestra quién | ❌ (sí motivo + fecha) |

Tabla legacy `ajustes_stock` **sin usos** en Nest — el camino vivo es `movimientos_ingrediente` tipo `ajuste`.

---

## Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **INV-AUTO-01** | ✅ | — | Descuento automático al cocina; gap “solo manual” cerrado | Script A |
| **INV-PROP-01** | ✅ | — | Subreceta expande y descuenta insumos hoja | Script B (100g) |
| **INV-ALERT-01** | ✅ | — | Alerta `stock_minimo_alcanzado` tras venta ≤ mínimo | Script C |
| **INV-ALERT-FCM-01** | 🟡 | Media | Stock bajo = medio → **sin push**; solo panel/RT | `enviarPushSiCritica` |
| **INV-ALERT-AJUSTE-01** | 🟡 | Baja | PATCH ajuste no llama `alertarStockBajo` | `actualizarIngrediente` |
| **INV-AUD-01** | 🟡 | Media | Quién/cuándo/por qué en `movimientos`; **no** en `auditoria_logs`; API/UI sin `usuario_id` | Script D |
| **AQ-DUP-01** | ✅ | Alta | Write-path unificado `StockMovimientoService` (incl. producción costeo 2026-08-07) | Arquitectura |
| **R10** | 🟡 | — | (aceptado) Carrera 2 QR al aprobar | Flujos E2E |

---

## Backlog remediación sugerido

1. **INV-FIX-01** — Exponer `usuario_id` (+ email/nombre) en `GET /inventario/movimientos` y pintarlo en UI.
2. **INV-FIX-02** — Opcional: subir `stock_minimo_alcanzado` a `alto` **o** FCM también para `medio` (producto).
3. **INV-FIX-03** — Tras PATCH ajuste, si `stock <= minimo` → misma alerta que venta.
4. **AQ-FIX-01** — Unificar cerebros de stock (ya en roadmap calidad).
5. **CONS-STOCK-CASCADE-01** (Prompt 29) — Tras descontar por pedido, llamar `sincronizarPorIngrediente` (hermanos off menú). Ver [`AUDITORIA_CONSISTENCIA_MODULOS.md`](AUDITORIA_CONSISTENCIA_MODULOS.md).

---

## Verificación

```powershell
.\scripts\verificar-inventario-ciclo.ps1
# exit 0 — A auto · B 3 capas · C alerta · D ajuste+usuario BD
```

**Gaps:** click-through UI alertas/movimientos en dispositivo no corrido; lote `usa_produccion_lote` cubierto por `verificar-produccion-lote.ps1` (no re-ejecutado en este script).
