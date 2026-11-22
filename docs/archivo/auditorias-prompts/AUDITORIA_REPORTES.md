# Auditoría — Reportes y analítica (Prompt 20)

> **Fecha:** 2026-08-06  
> **Alcance:** cifras API vs BD cruda, filtros combinables, rendimiento histórico, umbrales de alertas.  
> **Verificación:** `scripts/verificar-reportes-analitica.ps1` (OK, exit 0).  
> Relacionados: `verificar-analitica.ps1`, `verificar-coherencia-pedidos-analitica.ps1`, `verificar-reportes-export.ps1`, `docs/ALERTAS_AUTOMATICAS.md`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

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
| Filtro `producto_ids` en resumen | `EXISTS` ítem + **`SUM(p.total)` del pedido entero** | Sobre-atribuye ventas al producto (ticket completo) |

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

1. **REP-FIX-01** — Con filtro producto/categoría, KPI = suma de líneas filtradas (no `pedidos.total`).
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
