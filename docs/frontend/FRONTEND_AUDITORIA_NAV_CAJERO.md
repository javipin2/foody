# Foody — Auditoría de navegación / UX · Shell Cajero

> Cadena operativa del cajero: **abrir caja → POS / Mesas → cobrar → movimientos**.
> Sin Menú/Insumos/Costos (el rol no tiene esos permisos).

**Última actualización:** 2026-07-26 — NAV-CJ Alta+Media implementadas.

**Estado del ciclo:**

| Fase | Estado | Notas |
|------|--------|-------|
| 1. Diagnóstico | ✅ | 18 ítems NAV-CJ-01…18 |
| 2. Implementación | ✅ | Alta + Media clave |
| 3. Verificación | 🟡 | `flutter analyze` infos previos · smoke login `cajero` pendiente |

---

## Resumen

| Prioridad | Total | ✅ | ⏳ / diferido |
|-----------|------:|--:|-------------:|
| Alta | 6 | 6 | 0 |
| Media | 9 | 7 | 2 (15, 16) |
| Baja | 3 | 1 | 2 (17, 18) |

---

## Implementado

| ID | Qué |
|----|-----|
| **NAV-CJ-01** | `ocultarCabecera` en POS / Mesas / Caja dentro del shell |
| **NAV-CJ-02/04** | `onCajaEstadoCambiado` → auto POS al abrir; sin botón «Ya abrí…» |
| **NAV-CJ-03** | Bloqueo sin caja → SnackBar + salto a tab Caja |
| **NAV-CJ-05** | Refresh AppBar reinicia keys de tabs |
| **NAV-CJ-06** | Nav superior ≥720px (tablet/PC) |
| **NAV-CJ-07** | Hint «Toca para cobrar» en mesas ocupadas (modo piso) |
| **NAV-CJ-08** | Stats clicables: Libres / Por cobrar (+ QR si no cajero) |
| **NAV-CJ-09** | Sin banner/sheet aprobación QR para cajero |
| **NAV-CJ-11** | Sin «Transferir» en cajero/mesero |
| **NAV-CJ-13** | `onIrPedido` → SnackBar + atajo Mesas |
| **NAV-CJ-14** | Sin toggle arqueo ciego en shell cajero |

## Diferidos

| ID | Motivo |
|----|--------|
| **NAV-CJ-10** | Sheet ya tiene «Cobrar todo» + ExpansionTile (NAV-ADM-06) |
| **NAV-CJ-12** | Factura post-cobro — depende UI facturación cajero |
| **NAV-CJ-15** | Skip sheet mesa libre — fricción menor |
| **NAV-CJ-16** | Split POS móvil — tuning fino |
| **NAV-CJ-17/18** | Learning / tab Pedidos RO — YAGNI por ahora |

---

## Conexiones entre roles

- Aprobación QR queda en **mesero/admin** (cajero solo ve aviso).
- Transferir mesa solo **admin** en panel restaurante.
- Tras cobro, factura sigue siendo flujo admin salvo que se abra NAV-CJ-12.

---

## Changelog

- **2026-07-26:** Implementación NAV-CJ shell cajero (headers, sync caja, filtros mesas, QR, nav responsive).
