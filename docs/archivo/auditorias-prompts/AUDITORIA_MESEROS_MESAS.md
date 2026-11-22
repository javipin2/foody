# Auditoría — Meseros y mesas (Prompt 15)

> **Fecha:** 2026-08-06  
> **Alcance:** asignación de mesas, cambio de mesa con pedido activo, división de cuenta post-cocina, carrera entre dos meseros.  
> **Verificación:** `scripts/verificar-meseros-mesas.ps1` (OK, exit 0).  
> Código: `mesas.service.ts` · `pedidos-soporte.service.ts` · `pedidos-pagos.service.ts` · `pedidos-items.service.ts`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| Asignación de mesas | **Sí** — turno (`POST /mesas/asignar-turno`) + tomar mesa al crear/aprobar. Otra mesera → bloqueo. |
| Cambio de mesa con pedido | **Sí** — `POST /mesas/transferir` (mismo `pedido_id`, `FOR UPDATE`, historial). UI solo admin. |
| División de cuenta post-cocina | **Split de cobro** (ítems/abono) en el **mismo** pedido. **No** hay pedido hijo ni mover ítems. |
| Carrera 2 meseros | Turno aísla mesas. Mismo pedido: **`FOR UPDATE`** serializa (sin `version`). Sin pérdida de ítems en race medido. |

---

## Asignación

| Mecanismo | Efecto |
|-----------|--------|
| `POST /mesas/asignar-turno` | `mesas.mesera_asignada_id` |
| Pedido staff (rol mesero) | Assert turno + `pedidos.mesera_id` + mesa `ocupada` |
| Aprobar QR | Set `mesera_id`; admin puede forzar `mesera_id` en body |

Script A: mesero2 en mesa de mesero1 → rechazado; mesero1 crea OK con `mesera_id` propio.

---

## Transferir con pedido en curso

```
FOR UPDATE origen + destino + pedido
  → bloquea si estado terminal (pagado/cancelado/…)
  → bloquea si destino tiene otro activo
  → UPDATE pedidos.mesa_id (mismo id)
  → destino ocupada / origen libre
  → transferencias_mesa + auditoria_logs
```

| Qué se mueve | ¿Sí? |
|--------------|------|
| `pedido_id` / ítems / stock / cocina | Mismo pedido; **no** reimpresión automática |
| `mesera_asignada` al destino | **No** (origen se limpia; destino no hereda) |
| Transferir en `pagando` | **Permitido** (no está en cerrados) |

UI: CTA transfer oculto a mesero/cajero; API con `gestionar_mesas` sí permite.

---

## División de cuenta

| Capacidad | Estado |
|-----------|--------|
| Cobrar por `item_ids` / `monto_parcial` / mixto | ✅ mismo `pedido_id` |
| Tras cocina → parcial → `pagando` | ✅ |
| Agregar ítems tras split parcial | ✅ |
| Separar ítems a **pedido hijo** | ❌ gap (404 `/dividir`) |
| Etiqueta comensal | ✅ `PATCH .../items/:id/comensal` |

Script C: 2 ítems en `en_cocina` → cobro 1 ítem → `pagando` → add ítem → cierre saldo.

---

## Carrera / concurrencia

| Defensa | Detalle |
|---------|---------|
| Turno mesera | Segunda no edita mesa ajena |
| `FOR UPDATE` en pedido | Adds concurrentes serializan |
| Optimistic `version` | **No existe** |
| Realtime | `pedido_actualizado` / `mesas_actualizadas` → grid refresca |

Script D: 2× `POST .../items` en paralelo → 3 ítems totales, total 8000→24000. Sin lost update.

**R10** (QR stock) sigue aceptado: carrera entre *pedidos distintos* al aprobar, no el mismo pedido.

---

## Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **MES-ASIG-01** | ✅ | — | Turno + bloqueo otra mesera | Script A |
| **MES-XFER-01** | ✅ | — | Transfer pedido activo OK + historial | Script B |
| **MES-SPLIT-01** | ✅ | — | Split cobro post-cocina en mismo pedido | Script C |
| **MES-SPLIT-HIJO-01** | 🟡 | Media | No hay dividir→pedido hijo / mover ítems | 404 `/dividir` |
| **MES-RACE-01** | ✅ | — | FOR UPDATE evita lost update en adds concurrentes | Script D |
| **MES-XFER-MESERA-01** | 🟡 | Baja | Transfer no reasigna mesera al destino | `mesas.service.ts` |
| **MES-XFER-UI-01** | 🟡 | Baja | Mesero no ve transfer en UI (sí API con permiso) | `mesas_grid_widget` |
| **MES-MSG-01** | 🟡 | Baja | Códigos `MESA_ASIGNADA_*` / destino ocupada aplanados a `SOLICITUD_INVALIDA` | filter HTTP |
| **R10** | 🟡 | — | (cross) Carrera stock 2 QR al aprobar | Aceptado previo |

---

## Backlog remediación sugerido

1. **MES-FIX-01** — Preservar código de error en filter (como CAJ-MSG-01).
2. **MES-FIX-02** — Al transferir, opcional: heredar/reasignar `mesera_asignada_id` al destino.
3. **MES-FIX-03** — Si producto pide “cuenta separada física”: endpoint mover ítems → pedido hermano (hoy no).
4. **MES-FIX-04** — CTA transfer visible a mesero con permiso (o doc explícita “solo admin”).
5. **VIE-05** (Prompt 30) — Política cobro/split vs cocina incompleta: decisión A/B/C en [`AUDITORIA_CASOS_VIERNES.md`](AUDITORIA_CASOS_VIERNES.md) (no inventar).

---

## Verificación

```powershell
.\scripts\verificar-meseros-mesas.ps1
# exit 0 — A asignacion · B transfer · C split · D race
```

Relacionados: `verificar-transferencia-mesa.ps1`, `verificar-pagos-mesa.ps1`.

**Gaps:** click-through panel mesero en dispositivo; reimpresión post-transfer no ejercida.
