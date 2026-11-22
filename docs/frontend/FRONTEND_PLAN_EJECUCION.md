# Foody — Plan de ejecución frontend

> **Inicio:** 2026-07-02 · Orden por impacto × esfuerzo  
> **Maestro:** [FRONTEND_ROADMAP.md](FRONTEND_ROADMAP.md)

---

## Estrategia

1. **Fundación** (core UI) → cada sprint reutiliza componentes nuevos.
2. **Quick wins F1** antes de rediseños grandes (carrito/checkout).
3. **Un módulo operativo por sprint** (mesas, kanban) después de confianza cliente.
4. **Verificar siempre:** `.\scripts\verificar-flutter-ui.ps1`

---

## Sprint 1 — Confianza cliente + base UI ✅

| ID | Entrega | Doc |
|----|---------|-----|
| S1-01 | `FoodyFormato` + `FoodyEstadoUi` | FL-10, FL-11 |
| S1-02 | Splash marca Foody (sin legacy) | DS-04 |
| S1-03 | FF-02 Carrito +/− | F1-02 |
| S1-04 | FF-03 Factura colapsable | F1-03 |
| S1-05 | FF-01 «Terminé» sesión mesa | F1-01 |
| S1-06 | FF-05 Errores cliente humanos | F1-05 |
| S1-07 | FF-06 Auto-skip 1 sucursal | F1-06 |
| S1-08 | FF-04 KPIs ventas → caja | F1-04 |

---

## Sprint 2 — Operación rush hora ✅

| ID | Entrega | Doc |
|----|---------|-----|
| S2-01 | FF-07 Cobro mesa modo simple | F1-07 |
| S2-02 | AR-01 Kanban → mesa | F2-01 |
| S2-03 | RS-05 Tabs inventario scroll | F7 |
| S2-04 | `TemaFoody` extendido | DS-01 |

---

## Sprint 3 — Navegación premium ✅

| ID | Entrega | Doc |
|----|---------|-----|
| S3-01 | NAV-01 URL sync sidebar | F8-01 |
| S3-02 | AR-28 Búsqueda global (MVP) | F3-05 |
| S3-03 | AR-29 Favoritos sidebar | F4-01 |
| S3-04 | Cliente bottom nav | NAV-10 |

---

## Sprint 4 — Rediseño cliente (Square/Rappi) 🟡

| ID | Entrega | Doc |
|----|---------|-----|
| S4-01 | Carrito sticky + cards | DS-02 |
| S4-02 | Checkout pasos 1-2-3 | DS-02 |
| S4-03 | `FoodyScaffoldCliente` | DS-02 |
| S4-04 | Empty states ilustrados | DS-06 |

---

## Sprint 5 — Código mantenible

| ID | Entrega | Doc |
|----|---------|-----|
| S5-01 | Split `mesa_pedidos_sheet` | FL-02 |
| S5-02 | Split `mesas_grid_widget` | FL-02 |
| S5-03 | Providers mesas/pedidos | FL-30 |

---

*Actualizar estado al cerrar cada sprint en `FRONTEND_ROADMAP.md` changelog.*
