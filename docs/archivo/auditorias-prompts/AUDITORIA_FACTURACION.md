# Auditoría — Facturación electrónica DIAN / MATIAS (Prompt 19)

> **Fecha:** 2026-08-06  
> **Alcance:** errores MATIAS, cola/reintentos, consistencia cobro↔documento, anulación post-facturado.  
> **Verificación:** `scripts/verificar-facturacion-ciclo.ps1` (OK, exit 0).  
> **Estado producto:** 🚫 **PAUSADA** — `docs/FACTURACION_ELECTRONICA_PAUSADA.md` (X-01).  
> Código vivo: `facturacion.service.ts` (borrador/emitir local/HTML/anular soft).

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK · 🚫 pospuesto

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| ¿MATIAS API? | **No existe en el repo** (0 matches). Spec comercial apunta a Factus/Alegra/Carvajal; integración **no empezada**. |
| Errores si proveedor no responde | **N/A** — no hay cliente HTTP. Solo errores locales Nest (`CONFIG_FISCAL_INCOMPLETA`, `PEDIDO_NO_FACTURABLE`, etc.). |
| Cola / reintentos | **No** — sin cola, cron FE, ni `POST .../reintentar`. |
| Consistencia cobro ↔ documento | Capa **interna**: `facturas.total` = `pedidos.total` (IVA desglosado). Sin líneas de ítems en FE. |
| Anular pedido post-facturado | Anular factura = soft `anulada` + stub “nota crédito DIAN”. Pedido sigue `pagado`. Cancelar `pagado` bloqueado por FSM. |

---

## Qué hay vs qué falta

| Capa | Estado |
|------|--------|
| Borrador al `requiere_factura` | ✅ |
| Emitir número local `FE-########` | ✅ |
| HTML informativo | ✅ |
| Anular soft + auditoría | ✅ |
| Plan gate `enterprise` | ✅ |
| CUFE / XML UBL / DIAN | 🚫 |
| Cliente MATIAS (u otro FE) | 🚫 |
| Estados `aceptada_dian` / `rechazada_dian` | 🚫 |
| Nota crédito electrónica | 🚫 stub texto |
| Cola de pendientes / reintentos | 🚫 |

---

## Errores (capa local verificada)

| Caso | Resultado |
|------|-----------|
| Emitir sin pedido pagado/entregado | Rechazado (`PEDIDO_NO_FACTURABLE`) |
| Config sin NIT/razón | `CONFIG_FISCAL_INCOMPLETA` |
| Doble emitir | `FACTURA_YA_EMITIDA` |
| Timeout/rechazo MATIAS | **No hay path** — no se llama a nadie |

---

## Consistencia montos

```
pedido.total (cobrado)
  → sync borrador (si estado=borrador)
  → facturas.subtotal / iva / total  (IVA incluido → desglose)
  → emitir
```

- Script: total factura **8000** = total pedido; subtotal+IVA ≈ total.
- **Sin** `factura_items`: el documento no lista platos; solo agregados.
- No relee `productos.precio` al emitir (usa total del pedido).

---

## Post-facturado

| Acción | Efecto |
|--------|--------|
| `POST /facturacion/anular/:id` | `facturas.estado=anulada`; pedido **intacto** |
| Respuesta | `nota: 'Nota crédito DIAN pendiente integración proveedor'` |
| Cancelar pedido `pagado` | FSM bloquea (`pagado: []`) |

**Desync posible:** factura `anulada` + pedido `pagado` sin NC legal.

---

## Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **FE-PAUSE-01** | 🚫 | — | DIAN/proveedor FE pausado (X-01) | `FACTURACION_ELECTRONICA_PAUSADA.md` |
| **FE-MATIAS-01** | 🚫 | Alta* | Cero integración MATIAS (ni stub HTTP) | Grep + script §0 |
| **FE-QUEUE-01** | 🚫 | Alta* | Sin cola ni reintentos de emisión | Script §0/C |
| **FE-ERR-01** | ✅ | — | Errores locales (config/pagado) OK | Script A |
| **FE-CONS-01** | ✅ | — | Total factura = total pedido cobrado | Script B |
| **FE-ITEMS-01** | 🟡 | Media | Sin líneas de ítems en documento | Script B |
| **FE-NC-01** | 🚫 | Alta* | Nota crédito = stub; anular no toca pedido | Script C |
| **FE-PLAN-01** | ✅ | — | Módulo gated a enterprise | 403 en plan pro |

\*Severidad **cuando se retome** go-live legal; hoy aceptado por pausa.

---

## Backlog al retomar (orden sugerido)

1. Elegir proveedor (MATIAS u otro) + credenciales.
2. **FE-FIX-01** — Cliente HTTP + estados DIAN + mapeo rechazo/timeout.
3. **FE-FIX-02** — Cola/reintentos con backoff + UI pendientes.
4. **FE-FIX-03** — Snapshot ítems (o UBL desde `pedido_items`).
5. **FE-FIX-04** — Nota crédito real + política anular vs cancelar pedido.

---

## Verificación

```powershell
.\scripts\verificar-facturacion-ciclo.ps1
# exit 0 — eleva plan a enterprise temporalmente y lo restaura
```

**Gaps:** emisión legal real; UI click-through enterprise en prod.
