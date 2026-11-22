# Foody — Casos reales de restaurante (viernes alta demanda) · Prompt 30

> **Fecha:** 2026-08-06  
> **Perspectiva:** operador de salón/cocina/caja un viernes noche — **no** calidad de código.  
> **Regla:** si no hay regla de negocio clara → **DECISIÓN PENDIENTE** (2–3 opciones con pros/contras). No inventar el “correcto”.  
> **Base:** código Nest + scripts vivos + auditorías PED/MES/COC/PROMO/CAJ/RT/CONS.  
> **Estado oficial:** [`MASTER_STATUS.md`](MASTER_STATUS.md) § Casos viernes (VIE-\*).

Leyenda clase: **REGLA_CLARA** · **BUG** · **DECISIÓN_PENDIENTE**  
Leyenda estado: 🟣 abierto · 🟡 aceptado/parcial · ✅ OK ops

---

## Veredicto de operador

En un viernes de alta demanda Foody **soporta** el núcleo (agregar post-cocina, transferir mesa, carrera 2 meseros, split cobro, snapshots precio/promo, no reabrir pagado). Los dolores reales son:

1. Pedido en **`listo`** al que se le agregan ítems y **sigue diciendo listo**.  
2. **Cobrar / split** sin que cocina haya terminado (caja puede, salón/cocina se confunden).  
3. Cocina marca **`no_disponible`** y el pedido **nunca** pasa a listo.  
4. Dispositivos que **pierden Wi‑Fi** y pintan datos viejos.  
5. Impresora caída: cola en BD OK, **sin botón Reimprimir** claro.

---

## Verificación en vivo (esta sesión)

| Script | Resultado |
|--------|-----------|
| `GET /salud` | ✅ |
| `verificar-pedidos-ciclo-vida.ps1` | ✅ — ciclo mesa, prepago bug, add/edit/delete post-cocina, pagado bloqueado |
| `verificar-meseros-mesas.ps1` | ✅ — turno, transferir, split post-cocina, race 2 adds OK |
| `verificar-promociones-precios.ps1` | ✅ — promo off + precio catálogo con abiertos |
| `verificar-kds.ps1` | ✅ — tickets, N/D, DELETE staff, reencola impresión |
| Probe ad-hoc VIE-01 en pedido `listo` | ⛔ bloqueado por Auto-review; **trazado en código** |

Click-through salón físico / impresora térmica: **no corrido**.

---

## Matriz de los 13 casos

| # | Caso (viernes) | Clase | Sev ops | ID |
|---|----------------|-------|---------|-----|
| 1 | Cliente/staff agrega con parte ya preparada | BUG + regla | Alta | **VIE-01** |
| 2 | Quitar producto mientras cocina prepara | REGLA_CLARA | Media | **VIE-02** |
| 3 | Cambiar mesa de pedido en curso | REGLA_CLARA | Media | **VIE-03** |
| 4 | Dos meseros editan el mismo pedido | REGLA_CLARA | Baja–Media | **VIE-04** |
| 5 | Dividir cuenta tras enviar a cocina | DECISIÓN_PENDIENTE | Alta | **VIE-05** |
| 6 | Reabrir pedido ya cobrado | REGLA_CLARA | — | **VIE-06** |
| 7 | Cambiar precio con pedidos abiertos | REGLA_CLARA | Baja | **VIE-07** |
| 8 | Desactivar promo en uso | REGLA_CLARA | Baja | **VIE-08** |
| 9 | Ingrediente se agota mid-prep | DECISIÓN_PENDIENTE | Alta | **VIE-09** |
| 10 | Impresora deja de responder | REGLA_CLARA | Media–Alta | **VIE-10** |
| 11 | Backend reinicia con pedidos activos | REGLA_CLARA | Baja–Media | **VIE-11** |
| 12 | Dispositivo pierde red y vuelve | BUG (sync) | Alta | **VIE-12** |
| 13 | Acciones fuera de secuencia | Mixto | Alta | **VIE-13** |

---

## VIE-01 — Agregar productos cuando algunos ya están preparados

**Qué hace hoy (código + script C):** permitido hasta terminal. Descuenta stock si ya `stock_descontado`, líneas nuevas en `pendiente`, notifica cocina + reencola impresión. **No cambia** `pedidos.estado`.

| | |
|--|--|
| **Clase** | **BUG** si el pedido ya estaba `listo` (queda `listo` con ítems `pendiente`) · parte **REGLA_CLARA** (adds post-cocina permitidos) |
| **Riesgo viernes** | Mesero/caja ve “LISTO” y sirve/cobra; cocina aún tiene pendientes. Solo se corrige cuando cocina toca un ítem. |
| **Evidencia** | `pedidos-items.service.ts:17-22,587-600` · script ciclo C OK en `en_cocina` · `cocinas.service.ts` recalc solo en cambio de ítem |

**No es decisión pendiente:** el bug de estado es claro. Fix sugerido (producto): al agregar ítems, si había `listo`/`pagando` → forzar `en_cocina` (o equivalente).

**Regresión automatizada (Prompt 33):** Jest `casos-limite-28-30` + Flutter `test/e2e` afirman el bug actual (`estado === listo` tras add). Al fijar → cambiar expect a `en_cocina` · ver [`AUDITORIA_E2E_AUTOMATIZADO.md`](AUDITORIA_E2E_AUTOMATIZADO.md) **E2E-VIE-01-COV**.

---

## VIE-02 — Se elimina un producto mientras cocina lo prepara

Hay **dos** acciones distintas:

| Acción | Quién | Resultado |
|--------|-------|-----------|
| Soft-off catálogo (`disponible=false`) | Admin menú | Líneas del pedido **siguen**; KDS muestra nombre; no se puede **agregar** de nuevo |
| `DELETE` ítem del pedido | Staff (no cocina) | Borra línea; si `preparando`/`listo` → **merma** + alerta `item_eliminado_post_cocina`; KDS lo pierde |
| Cocina | Solo `no_disponible` | Ítem permanece; pedido puede trabarse (**COC-NODISP-01**) |

| | |
|--|--|
| **Clase** | **REGLA_CLARA** (tres caminos distintos documentados) |
| **Riesgo** | Cocina no puede “quitar” del ticket; depende del mesero. Hueco UX = **COC-CANCEL-01** |
| **Evidencia** | Script KDS C · `pedidos-items.service.ts:604+` · `cocinas.service.ts:355+` |

---

## VIE-03 — Cambiar la mesa de un pedido en curso

| | |
|--|--|
| **Clase** | **REGLA_CLARA** |
| **Qué pasa** | `POST /mesas/transferir`: `FOR UPDATE`, mismo `pedido_id`, destino sin otro activo, historial, RT mesas. **No** reimprime comanda ni reasigna mesera al destino. |
| **Riesgo viernes** | Comanda física sigue con mesa vieja; cocina confunde bandeja. |
| **Evidencia** | `verificar-meseros-mesas` B · `mesas.service.ts:514-677` · MES-XFER-UI (UI solo admin) |

Mejora ops (no ambigüedad de regla): reimprimir + heredar mesera (ya en backlog MES-FIX).

---

## VIE-04 — Dos meseros modifican el mismo pedido a la vez

| | |
|--|--|
| **Clase** | **REGLA_CLARA** |
| **Qué pasa** | `FOR UPDATE` en pedido serializa adds/edits/cobros. Script: 2 adds concurrentes → 3 ítems, sin pérdida. Mesero ajeno a mesa de turno → bloqueado. Sin columna `version` (optimistic UI). |
| **Riesgo** | Segundo mesero espera o ve error; no “lost update” en mismo pedido. Carrera stock **entre pedidos distintos** sigue posible (R10). |
| **Evidencia** | `verificar-meseros-mesas` D · MES-RACE-01 |

---

## VIE-05 — Dividir la cuenta después de enviar parte a cocina

| | |
|--|--|
| **Clase** | **REGLA_CLARA** (decisión **C** — 2026-08-07) |
| **Qué hace el código** | Abono / split / `pagando` **libre** aunque haya ítems en cocina. Transición a **`pagado`** (cobro que salda total) **bloqueada** si cocina incompleta, salvo `admin`/`gerente`/`gerente_cadena` + `motivo` no vacío. Cocina completa = todos los `pedido_items` con `estado_cocina IN ('listo','no_disponible')` (COC-NODISP-01). Liberar mesa solo con pedido `pagado`/`cancelado` (sin cambio). |
| **Evidencia** | `pedidoCocinaCompleta` · `pedidos-pagos.service.ts` · `scripts/verificar-vie-politica.ps1` |

### Opciones (histórico)

**A** Cobro libre · **B** Solo ítems/`pedido` listo · **C** ✅ **Elegida** — abono libre; `pagado` solo cocina completa o admin+motivo.

---

## VIE-06 — Reabrir un pedido ya cobrado

| | |
|--|--|
| **Clase** | **REGLA_CLARA** |
| **Qué pasa** | **No hay reopen.** `pagado → ∅` en FSM; agregar ítems → `PEDIDO_CERRADO`; cobrar de nuevo → ya cerrado. Corrección = `POST /caja/devolucion` (o nuevo pedido). |
| **Evidencia** | Script ciclo C “Agregar item a pagado rechazado” · `pedido-estados.ts` · AUDITORIA_CAJA |

Si el negocio **quiere** reopen, eso sería **nueva decisión de producto** (hoy no existe).

---

## VIE-07 — Cambiar precio con pedidos abiertos

| | |
|--|--|
| **Clase** | **REGLA_CLARA** |
| **Qué pasa** | Snapshot en `pedido_items.precio_unitario`. Abiertos no cambian; ítems nuevos = precio actual; cobro = suma. |
| **Evidencia** | `verificar-promociones-precios` B |

---

## VIE-08 — Desactivar promoción en uso

| | |
|--|--|
| **Clase** | **REGLA_CLARA** |
| **Qué pasa** | Descuento del pedido abierto **se mantiene**; pedidos nuevos rechazan código; cobro = total congelado. |
| **Matiz** | Agregar ítems después **no** reaplica % (**CONS-PROMO-ADD-01**). |
| **Evidencia** | `verificar-promociones-precios` A |

---

## VIE-09 — Un ingrediente se agota durante la preparación

| | |
|--|--|
| **Clase** | **REGLA_CLARA** (decisión **C** — 2026-08-07) |
| **Qué hace el código** | Acción «fallo de preparación»: ítem → `no_disponible` (motivo obligatorio); si `stock_descontado` → **merma** (no restore); alerta `fallo_preparacion` / `item_no_disponible_cocina` al salón; pedido avanza a `listo` cuando todos los ítems están resueltos (COC-NODISP-01). Endpoint: `POST /cocina/items/:id/fallo-preparacion` (+ PATCH estado N/D con mismo path de merma). |
| **Evidencia** | `cocinas.service.ts` · KDS diálogo N/D/Fallo · `verificar-vie-politica.ps1` |

### Opciones (histórico)

**A** Status quo · **B** Revalidar al `preparando` · **C** ✅ **Elegida** — fallo explícito + merma si ya descontado + alerta.

---

## VIE-10 — Impresora deja de responder mid-servicio

| | |
|--|--|
| **Clase** | **REGLA_CLARA** |
| **Qué pasa** | Jobs en `impresion_cocina_jobs` (`pendiente`); Nest reintenta ~5s hasta 10 → `error`. KDS web **no** depende de impresora. Sin `POST /impresion/reimprimir` dedicado; reencola vía edición/notif (**COC-REIMP-01**). |
| **Riesgo viernes** | Cocina trabaja en pantalla; bandejas físicas se pierden sin comanda papel. |
| **Evidencia** | `impresion.service.ts` · script KDS E · `verificar-impresion.ps1` (cola) |

---

## VIE-11 — Backend se reinicia con pedidos activos

| | |
|--|--|
| **Clase** | **REGLA_CLARA** |
| **Qué pasa** | Pedidos/caja/stock en Postgres → intactos. Al subir Nest, `ImpresionService` retoma jobs `pendiente`. Realtime: **sin replay** de eventos perdidos durante el corte. |
| **Riesgo** | Datos OK; pantallas pueden quedar stale hasta refresh/poll (**VIE-12**). |
| **Evidencia** | `impresion.service.ts:onModuleInit` · AUDITORIA_REALTIME |

---

## VIE-12 — Dispositivo pierde conexión y vuelve minutos después

| | |
|--|--|
| **Clase** | **BUG** (capa sync UI) |
| **Qué pasa** | Mutaciones posteriores ven BD actual. Flutter reconecta canales pero **sin refetch garantizado** → UI stale hasta poll/manual (**RT-RECON-01**, **RT-LIFE-01**). |
| **Riesgo viernes** | Mesero cobra/comanda sobre pantalla vieja; dos tablets muestran mundos distintos. |
| **Evidencia** | AUDITORIA_REALTIME · CONS Path 2 |

---

## VIE-13 — Acciones fuera de secuencia

| Acción | Hoy | Clase |
|--------|-----|-------|
| Cobrar antes de `listo` | Abono OK; `pagado` solo cocina completa o admin+motivo | **REGLA_CLARA** (VIE-05 **C**) |
| Kanban `listo` sin todos ítems listos | PATCH puede desalinear ítems | **BUG** / drift |
| Cocina → `listo` pedido | Solo si todos ítems `listo` | REGLA_CLARA |
| Cancelar `pagado` | Rechazado | REGLA_CLARA |
| Cocina muta pedido en `pagando`/`pagado` | Ítem sí; estado pedido no | REGLA_CLARA |
| PATCH Kanban a `pagado` | 400 (DTO) | REGLA_CLARA |
| Prepago para llevar + cierre caja | Bloquea (PED-PREPAGO-01) | **BUG** ops |

### Opciones cobro pre-listo (compartidas con VIE-05)

**A** Bypass caja · **B** Exigir listo salvo admin · **C** ✅ **Elegida** (igual VIE-05) — abono libre; `pagado` solo cocina completa o admin+motivo.

---

## Bug adicional (edición cantidad post-cocina)

| ID | Clase | Hallazgo |
|----|-------|----------|
| **VIE-QTY-01** | **REGLA_CLARA** (decisión **C** — 2026-08-07) | Prohibido bajar `cantidad` si `estado_cocina IN ('preparando','listo')` → `400 CANTIDAD_COCINA_INMUTABLE`. Subir qty OK. Corrección = `DELETE` ítem con motivo (merma). |
| Evidencia | `pedidos-items.service.ts` · UI editar ítem · `verificar-vie-politica.ps1` |

### Opciones (histórico)

**A** Qty↓ = merma · **B** Qty↓ = restore · **C** ✅ **Elegida** — prohibir qty↓ en preparando/listo; solo DELETE + motivo.

---

## Checklist operador “antes del viernes”

| OK si… | Bloqueante si… |
|--------|----------------|
| Transfer mesa + historial | Pedidos `listo` con pendientes (VIE-01) |
| Race 2 meseros no pierde ítems | Cierre caja con prepago (PED-PREPAGO) |
| Promo/precio snapshot | Cocina N/D traba pedido (COC-NODISP) |
| Pagado no se reabre | Tablets sin refetch (VIE-12) |
| Cola impresión en BD | Sin plan B papel / reimprimir |

---

## Prioridad remediación (ops)

| Prio | ID | Acción |
|-----:|----|--------|
| 1 | VIE-01 | Al add ítems: si pedido `listo` → volver a `en_cocina` |
| 2 | VIE-05 / VIE-13 | ✅ Decisión **C** implementada (2026-08-07) |
| 3 | COC-NODISP + VIE-09 | ✅ COC-NODISP + decisión **C** fallo/merma |
| 4 | VIE-12 / RT-RECON | Refetch al reconectar |
| 5 | PED-PREPAGO-01 | Cerrar prepago vs cierre caja |
| 6 | VIE-10 / COC-REIMP | Botón reimprimir / estado impresora visible |
| 7 | VIE-QTY-01 | ✅ Decisión **C** — prohibir qty↓ en cocina |

---

## Enlaces

- Pedidos: [`AUDITORIA_PEDIDOS_CICLO_VIDA.md`](AUDITORIA_PEDIDOS_CICLO_VIDA.md)  
- Meseros: [`AUDITORIA_MESEROS_MESAS.md`](AUDITORIA_MESEROS_MESAS.md)  
- Cocina: [`AUDITORIA_COCINA_KDS.md`](AUDITORIA_COCINA_KDS.md)  
- Consistencia: [`AUDITORIA_CONSISTENCIA_MODULOS.md`](AUDITORIA_CONSISTENCIA_MODULOS.md)  
- Realtime: [`AUDITORIA_REALTIME.md`](AUDITORIA_REALTIME.md)
