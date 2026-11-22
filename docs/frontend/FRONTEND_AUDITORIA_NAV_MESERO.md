# Foody — Auditoría de navegación / UX · Rol Mesero

> Shell `/admin/mesero`: **Mesas** + **Pedidos**. Sin Menú/Insumos/Costos/Caja.

**Última actualización:** 2026-07-26 — NAV-MS Alta (+ Media clave) implementadas.

**Estado del ciclo:**

| Fase | Estado | Notas |
|------|--------|-------|
| 1. Diagnóstico | ✅ | 36 ítems NAV-MS-01…36 |
| 2. Implementación | ✅ | Alta + Media clave (copy, empty, cancel, filtros) |
| 3. Verificación | 🟡 | analyze · smoke UI `mesero` pendiente |

---

## Implementado (Alta + Media clave)

| ID | Qué |
|----|-----|
| **MS-01** | Refresh AppBar + `_refreshTick` |
| **MS-02** | Nav superior ≥720px |
| **MS-03** | `ocultarCabecera` Mesas/Pedidos |
| **MS-05** | Stat «Ocupadas» (no «Por cobrar») en modo mesero |
| **MS-06/14** | Banner QR tappable + CTA Revisar → tab Mesas |
| **MS-08** | Hint «ver cuenta / agregar» |
| **MS-11** | Empty sin CTA crear mesa |
| **MS-15/26** | Lista default móvil; kanban solo ≥720 |
| **MS-16** | Filtros sin domicilio; default mesa |
| **MS-17/29** | `onVerMesa` cableado |
| **MS-18** | Cancelar oculto en modoMesero |
| **MS-19/31** | SnackBar avisar cajero al marcar pagando |
| **MS-20** | CTA «Listo para cobrar»; cobro en ExpansionTile |
| **MS-21** | Sin «Salió sin pagar» en mesero |
| **MS-22** | POS con `ocultarCabecera` |
| **MS-24** | Error grid con Reintentar |
| **MS-25** | Sin sucursal + logout |
| **MS-32** | Redirect `/admin/panel` → `/admin/mesero` (+ cajero) |
| **MS-33/34/35/36** | FCM rutas `/admin/mesero?mesa_id&pedido_id&tab` |

## Diferidos

| ID | Motivo |
|----|--------|
| **MS-07** | Skip sheet mesa libre — fricción menor |
| **MS-09** | Filtro «Solo mis mesas» — Media |
| **MS-10** | Política transfer — producto |
| **MS-13** | Unificar motivos rechazo QR |
| **MS-28** | Menú ⋮ comensal |
| **MS-30** | Badge tiempo cocina |

---

## Conexiones entre roles

- Handoff cobro → **Cajero** ve mesa en `pagando` / «Por cobrar».
- FCM `pedido_listo` → mesero shell (antes panel `?tab=` roto).
- QR / llamar mesera → `mesa_id` en query.
- Cancelar / salió sin pagar → solo admin/cajero en UI.

---

## Changelog

- **2026-07-26:** Implementación NAV-MS shell mesero (paridad cajero), conexiones Mesas↔Pedidos, kanban móvil, handoff cobro, FCM.
