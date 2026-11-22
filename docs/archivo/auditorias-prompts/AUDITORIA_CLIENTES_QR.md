# Auditoría — Clientes / QR / autoservicio (Prompt 17)

> **Fecha:** 2026-08-06  
> **Alcance:** pedido por QR sin JWT mesero, anti-manipulación precios/productos, QR expirado / mesa reutilizada.  
> **Verificación:** `scripts/verificar-qr-cliente.ps1` (OK, exit 0).  
> Código: `menu.service.ts` · `pedidos-public.controller.ts` · `pedidos-crear.service.ts` · `pedidos-estado.service.ts` · `pedidos-qr-cron.service.ts`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| Flujo QR sin cuenta mesero | **Parcial** — cliente pide **sin JWT** → `pendiente_aprobacion`. **No** hay autoservicio que salte aprobación: hace falta staff+mesero para aprobar. |
| Manipular precios vía request | **No** — body `precio` se **ignora**; precio desde BD. Producto ajeno/off → rechazado. |
| QR expirado / mesa reusada | Token QR **permanente**. Mesa libre no invalida token. Varios clientes coexisten. Expiración dura de pedido: **cierre caja >30 min** (no cron continuo). |

---

## Flujo QR (sin JWT en el pedido)

```
GET /menu/mesa/:qr_token   (público)
POST /pedidos              (público, device_id)
  → estado = pendiente_aprobacion
  → stock_descontado = false
PATCH /pedidos/:id/aprobar (JWT + mesera_id)  ← mesero obligatorio
  → en_cocina + descuento stock
```

| Paso | ¿Mesero? |
|------|----------|
| Ver menú / crear pedido | No |
| Aprobar / cocina | **Sí** (admin asigna `mesera_id` o mesero con permiso) |

`scripts/verificar-self-service.ps1` = onboarding SaaS, **no** mesa sin mesero.

---

## Anti-manipulación

| Ataque | Resultado |
|--------|-----------|
| `precio: 1` en body | Ignorado → `precio_unitario` = catálogo (8000) |
| Producto otra sucursal / UUID fake | Rechazado |
| `disponible=false` | Rechazado |
| PATCH estado → `en_cocina` sin JWT | `NO_AUTORIZADO` |
| Aprobar sin JWT | `NO_AUTORIZADO` |

Comentario código: *“Precio autoritativo del servidor… no validamos tampering estricto”* — no hay error si difiere; simplemente se sobrescribe.

---

## QR / sesión / reutilización

| Escenario | Comportamiento |
|-----------|----------------|
| Token tras mesa `libre` | Sigue resolviendo menú |
| 2 devices mismo QR | Ambos pueden crear `pendiente_aprobacion` |
| Mesa `activa=false` | Menú QR → 404 |
| Token inventado | 404 |
| Pedido >30 min sin aprobar | Sigue pendiente; rechazo en **cierre de caja** (F-09) |
| Cron QR | Solo FCM/recordatorio 3/5 min — **no** auto-rechaza |
| Sesión Flutter | SharedPreferences **sin TTL** |

---

## Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **QR-FLOW-01** | ✅ | — | Menú+pedido públicos → `pendiente_aprobacion` | Script A |
| **QR-AUTO-01** | 🟡 | Media | No hay autoservicio sin aprobación mesero | Script A |
| **QR-PRICE-01** | ✅ | — | Precio body ignorado; BD manda | Script B |
| **QR-PROD-01** | ✅ | — | Producto off/ajeno rechazado | Script B |
| **QR-TOKEN-01** | ✅ | — | Token permanente; libre no invalida | Script C |
| **QR-MULTI-01** | ✅ | — | Varios pendientes mismo QR OK | Script C |
| **QR-EXP-01** | 🟡 | Baja | Sin auto-rechazo continuo; solo cierre caja >30m | Script C |
| **QR-MESA-ID-01** | 🟡 | Media | `tipo=mesa` **sin** `mesa_id` aceptado → pendiente huérfano | Script C GAP |
| **R10** | 🟡 | — | (cross) Carrera stock 2 QR al aprobar | Aceptado |
| **RT-SEC-01** | 🟣 | — | (cross) Menú QR expone ids → canales RT | Realtime |

---

## Backlog remediación sugerido

1. **QR-FIX-01** — Exigir `mesa_id` si `tipo=mesa` en `POST /pedidos` público.
2. **QR-FIX-02** — (producto) Modo autoservicio opcional por sucursal que auto-apruebe o vaya directo a cocina.
3. **QR-FIX-03** — Cron opcional: auto-rechazar `pendiente_aprobacion` > N min (hoy solo cierre caja).
4. **QR-FIX-04** — Rotar/invalidar token al regenerar QR (si se quiere invalidar escaneos viejos).

---

## Verificación

```powershell
.\scripts\verificar-qr-cliente.ps1
# exit 0
```

Relacionados: `verificar-carga-qr.ps1`, `verificar-qa-roles-api.ps1` (aprobar con mesero).

**Gaps:** click-through Flutter escáner; regenerar QR en UI no ejercido.
