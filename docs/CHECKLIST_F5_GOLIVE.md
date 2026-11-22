# Checklist F5 — Go-live P0 (humano + código)

> **Código/sesión agente:** BN-EXC fuente/impresión + `scripts/verificar-f5-golive.ps1` → **🟡 Parcial**.  
> **2026-08-08:** stack local OK · túnel Cloudflare levantado (antes 530) · Wompi tunel script OK · agente impresión modo archivo en `:8765`.  
> **No marcar F5 ✅** hasta completar los ítems humanos abajo.

Atajo preflight:

```powershell
.\scripts\verificar-f5-golive.ps1
.\scripts\verificar-wompi-tunel.ps1
.\scripts\verificar-impresion.ps1   # modo archivo OK
```

## C-05 — Impresión térmica (P0-01)

| # | Acción | Quién | Estado |
|---|--------|-------|--------|
| 1 | Agente Python + cola Nest en modo archivo | Dev | ✅ 2026-08-08 (`health/impresion` conectado) |
| 2 | Conectar impresora `:9100` o USB en restaurante | Ops campo | ⏳ diferido (sin hardware) |
| 3 | Imprimir comanda real (pedido cocina) y verificar papel | Ops campo | ⏳ diferido |
| 4 | **O** aceptar explícitamente modo archivo para piloto | Founder | ✅ **waiver 2026-08-08** — upgrade: `IMPRESION_RESTAURANTE.md` § producción |

Doc: `docs/IMPRESION_RESTAURANTE.md`.

## C-06 — VPS + Wompi (P0-05/06/07)

| # | Acción | Quién | Estado |
|---|--------|-------|--------|
| 1 | `.env` Wompi + redirect + secreto eventos | Dev | ✅ `verificar-wompi-tunel.ps1` |
| 2 | Registrar URL webhook en dashboard Wompi | Founder | ✅ 2026-08-08 (URL eventos + llave) |
| 3 | Pago sandbox → plan activa **sin** sync manual | QA / Founder | ✅ 2026-08-08 (confirmado founder) |
| 4 | Comprar/migrar VPS **o** documentar piloto = PC+túnel | Founder | ✅ **piloto PC+túnel** 2026-08-08 · upgrade `MIGRACION_VPS_QUE_CAMBIA.md` |
| 5 | `WOMPI_REDIRECT_URL` HTTPS + flujo completo | Ops | ✅ sandbox E2E (prod cuando Wompi apruebe cuenta) |

Webhook a pegar (túnel actual):

```text
https://api.foodyy.store/api/v1/pagos/webhook-wompi
```

## Criterio de cierre F5 ✅

- [x] C-05: térmica real **o** waiver escrito modo archivo  
- [x] C-06: webhook registrado + 1 pago sandbox OK  
- [x] C-06: VPS en prod **o** decisión documentada “piloto Fase 0 PC+túnel”

> **F5 piloto ✅** (2026-08-08). Diferidos: papel térmico real + VPS Ubuntu.

Cuando cierres un ítem humano, actualizá `docs/MASTER_STATUS.md` P0 y esta tabla.
