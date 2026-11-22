# Foody — Auditoría de navegación / UX · Cadena Menú → Insumos → Costeo

> **Documento vivo de seguimiento.** Fase 1 = diagnóstico. Implementación por prioridad.
> Alcance: la **cadena de costeo** completa (insumos base → sub-recetas → ítems de menú → precio sugerido).
> Complementa: `FRONTEND_AUDITORIA_NAV_ADMIN.md`, `FRONTEND_RESPONSIVE_STRATEGY.md`.

**Última actualización:** 2026-07-26 — NAV-MC cerrado + **NAV-MG** (Gerente sede) 8/9 (MG-08 diferido).

**Estado del ciclo:**

| Fase | Estado | Notas |
|------|--------|-------|
| 1. Diagnóstico | ✅ Hecho | 2026-07-22 + refresh 2026-07-26 |
| 2. Aprobación plan | ✅ Hecho | Usuario pidió implementar |
| 3. Implementación | ✅ Hecho | MC-01…31 · MG-01…07+09 |
| 4. Verificación | 🟡 Parcial | `flutter analyze` · smoke móvil pendiente |

---

## Cadena y cableado actual

```
Menú (MenuAdminScreen)
  ├─ badge / ⋮ «Ver costos» ──_irCostosConProducto──▶ Costos + URL ?producto_id
  ├─ diálogo precios muestra costo/margen + atajo Costos
  ├─ extras/bebidas: badge tappable (mismo patrón productos)
  └─ empty gerente: sin copiar HQ + CTA crear (NAV-MG-02)
Costos (CostosMargenesScreen)
  ├─ lista sin auto-abrir primer plato (móvil)
  ├─ back / breadcrumb ──onVolverAlMenu()──▶ Menú
  ├─ CTA / ⋮ ──onIrInsumos()──▶ Insumos (NAV-MG-03)
  ├─ empty → CTA «Ir a Menú»
  ├─ banner umbral → filtro bajo_margen
  └─ RecetaProductoPanel (+ Subreceta → Insumos si cableado)
Insumos (InventarioAdminScreen)
  ├─ CTA «Ir a Costos» + SnackBar «Armar receta»
  ├─ CTA «Ver inventario de otras sedes» (NAV-MG-04)
  ├─ hermanas → «Ir a Traslados» (NAV-MG-06)
  ├─ TabBar con fade; alerta stock fuerza tab Mercado
  ├─ Movimientos tap → Mercado + editar insumo
  └─ filtroInicial desde Alertas (bajo_stock)
```

---

## Roles: `gerente` vs `gerente_cadena` (NAV-MG-09)

| Capacidad | `gerente` (sede) | `gerente_cadena` / admin |
|-----------|:----------------:|:------------------------:|
| Menú / Insumos / Costos | ✅ su sede | ✅ + cambia sede |
| Copiar menú desde otra sede | ❌ | ✅ |
| Selector multi-sede en panel | ❌ | ✅ |
| Nombre de sede en sidebar | ✅ (NAV-MG-01) | ✅ |
| Inventario hermanas (RO) | ✅ si permiso | ✅ |
| Traslados | ✅ si hay hermanas | ✅ |

---

## Resumen numérico NAV-MC

| Prioridad | Total | ⏳ | ✅ |
|-----------|------:|--:|--:|
| Alta | 12 | 0 | 12 |
| Media | 12 | 0 | 12 |
| Baja | 4 | 0 | 4 |
| **Total** | **28** | **0** | **28** |

## Resumen numérico NAV-MG (Gerente sede)

| Prioridad | Total | ⏳ | ✅ | Diferido |
|-----------|------:|--:|--:|--------:|
| Alta | 3 | 0 | 3 | 0 |
| Media | 4 | 0 | 4 | 0 |
| Baja | 2 | 0 | 1 | 1 (MG-08) |
| **Total** | **9** | **0** | **8** | **1** |

---

## Backlog NAV-MG — Gerente de sucursal

| ID | Prioridad | Qué | Est. |
|----|-----------|-----|------|
| **NAV-MG-01** | Alta | Nombre real de sede en sidebar (carga `mi-restaurante` con `ver_dashboard`) | ✅ 2026-07-26 |
| **NAV-MG-02** | Alta | Empty Menú: no puede copiar HQ; pedir cadena/admin + CTA crear | ✅ 2026-07-26 |
| **NAV-MG-03** | Alta | Costos→Insumos (`onIrInsumos` + CTA + subreceta navega) | ✅ 2026-07-26 |
| **NAV-MG-04** | Media | CTA descubrible «Ver inventario de otras sedes» | ✅ 2026-07-26 |
| **NAV-MG-05** | Media | Copy Traslados: sin permiso vs sin otras sedes (no «corporativo») | ✅ 2026-07-26 |
| **NAV-MG-06** | Media | Hermanas → «Ir a Traslados» | ✅ 2026-07-26 |
| **NAV-MG-07** | Media | GuiaPasos en Menú y Costos | ✅ 2026-07-26 |
| **NAV-MG-08** | Baja | Comparar margen RO vs hermana | 📅 YAGNI / futuro |
| **NAV-MG-09** | Baja | Docs: tabla gerente vs cadena | ✅ 2026-07-26 |

---

## Backlog — Prioridad Alta NAV-MC (todas ✅)

| ID | Qué | Est. |
|----|-----|------|
| **NAV-MC-01…07** | Overflow, back, header ⋮, crear insumo, guía, subrecetas ⋮, badge Menú | ✅ 2026-07-22 |
| **NAV-MC-20** | Menú→Costos sync URL (`producto_id` + `_irCostosConProducto`) | ✅ 2026-07-26 |
| **NAV-MC-21** | No auto-abrir primer plato en móvil | ✅ 2026-07-26 |
| **NAV-MC-22** | Selector sede en móvil (AppBar + ⋮) | ✅ 2026-07-26 |
| **NAV-MC-13** | Diálogo precios con costo/margen + atajo Costos | ✅ 2026-07-26 |
| **NAV-MC-10** | Insumos→Costos (CTA + SnackBar Armar receta) | ✅ 2026-07-26 |

---

## Backlog — Prioridad Media NAV-MC (todas ✅)

| ID | Qué | Est. |
|----|-----|------|
| **NAV-MC-08** | Fade TabBar Insumos | ✅ |
| **NAV-MC-09** | Fade chips Insumos | ✅ (sesión overflow) |
| **NAV-MC-11** | + Subreceta siempre visible + hint Insumos | ✅ |
| **NAV-MC-12** | Header Menú ⋮ hasta &lt;720px | ✅ |
| **NAV-MC-14** | Nombre plato en cabecera Costos móvil | ✅ |
| **NAV-MC-15** | Alerta→Insumos con `filtroInicial=bajo_stock` | ✅ (sin highlight ítem) |
| **NAV-MC-23** | Empty Productos + CTA | ✅ |
| **NAV-MC-24** | Banner error + Reintentar Menú | ✅ |
| **NAV-MC-25** | Empty Costos → Ir a Menú | ✅ |
| **NAV-MC-26** | Banner umbral → filtro bajo_margen | ✅ |
| **NAV-MC-27** | Alerta stock fuerza tab Mercado | ✅ |
| **NAV-MC-28** | Badge costeo en extras/bebidas | ✅ |
| **NAV-MC-29** | Fade TabBar Menú | ✅ |
| **NAV-MC-30** | Combos vacío → CTA Costos / crear | ✅ |

---

## Backlog — Prioridad Baja NAV-MC (todas ✅)

| ID | Qué | Est. |
|----|-----|------|
| **NAV-MC-16** | Menú: `_barraCrear` tonal unificada (toppings/bebidas/combos) + empty CTA | ✅ 2026-07-26 |
| **NAV-MC-17** | Movimientos: tap → tab Mercado + búsqueda + diálogo editar | ✅ 2026-07-26 |
| **NAV-MC-18** | Recalcular: mismo `Icons.calculate_outlined` + label «Recalcular» | ✅ 2026-07-26 |
| **NAV-MC-31** | Alias `inventario` → normaliza a `insumos` en `_seleccionarSeccion` | ✅ 2026-07-26 |

---

## Changelog

- **2026-07-26:** **NAV-MG-01…07+09 ✅** (MG-08 diferido) — nombre sede gerente; empty Menú bootstrap; Costos↔Insumos; CTA hermanas; copy Traslados; hermanas→Traslados; GuiaPasos Menú/Costos; docs roles.
- **2026-07-26:** **Baja MC-16/17/18/31 ✅** — barra crear unificada Menú; movimientos→insumo; recalcular alineado; alias inventario. **Ciclo NAV-MC cerrado.**
- **2026-07-26:** Alta MC-10/13/20–22 + Media 08/11–15/23–30. Panel: URL Costos, selector sede móvil, `onIrCostos`, filtro alertas. Costos: sin auto-select, nombre header, banner filtro, empty CTA. Menú: precios+costeo, empty/error, badges extras, fade tabs, ⋮ &lt;720. Insumos: CTA Costos, SnackBar Armar receta, fade TabBar, tab Mercado en alerta. Analyze sin errores nuevos.
- **2026-07-22:** MC-01…07 Alta completa.
- **2026-07-22:** Creación diagnóstico 19 ítems.
