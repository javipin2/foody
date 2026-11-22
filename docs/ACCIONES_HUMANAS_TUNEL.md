# Acciones humanas — Foody PC + túnel (Fase 0 ya hecha)

> El código y la config local están listos (`verificar-listo-vps.ps1` OK).  
> Esto **no** lo puede hacer el agente: requiere tu login en dashboards.

Atajo:

```powershell
.\scripts\checklist-acciones-humanas-tunel.ps1
.\scripts\checklist-acciones-humanas-tunel.ps1 -AbrirNavegador
```

## 1. UptimeRobot (OPS-05) — ~10 min

1. Entrá a [uptimerobot.com](https://uptimerobot.com) → New Monitor.
2. Pegá:

| Campo | Valor |
|-------|--------|
| URL | `https://api.foodyy.store/api/v1/health` |
| Intervalo | 5 min |
| Keyword | `"base_datos":true` |

3. Cuando el monitor esté verde: OPS-05 ✅ (hecho 2026-08-03 — monitor `api.foodyy.store` Up).

Detalle: `docs/MONITOREO_SALUD.md`.

## 2. Wompi webhook (OPS-03) — ~10 min

**Estado backend:** redirect OK · claves OK · secreto de eventos ya en `.env` (alias `WOMPI_EVENT_KEY`) · ruta pública responde.

### Lo que falta (solo dashboard)

1. Entrá a [comercios.wompi.co](https://comercios.wompi.co) (sandbox o prod según tus claves).
2. **Desarrolladores** → **Eventos** / Webhooks.
3. URL de eventos (pegar tal cual):

```text
https://api.foodyy.store/api/v1/pagos/webhook-wompi
```

4. Guarda. Si Wompi muestra un **secreto de eventos** nuevo y es distinto al que ya tienes:
   - pégalo en `foody_backend/.env` como `WOMPI_EVENTS_SECRET=...` (o actualiza `WOMPI_EVENT_KEY`)
   - reinicia Nest (`iniciar-backend-wsl.bat`)
5. Comprueba: `.\scripts\verificar-wompi-tunel.ps1`
6. Opcional: un pago de prueba en **Mejorar plan** (sandbox) y confirma que el plan se activa sin pegar el ID a mano.

Redirect ya configurado: `https://equipo.foodyy.store/admin/panel?seccion=mejorar_plan`.

Doc: `docs/WOMPI_PRODUCCION.md`.

Cuando el webhook esté registrado en Wompi, avisa y marcamos OPS-03.

> **2026-08-08:** Founder registró URL de eventos + llave en dashboard (sandbox). OPS-03 webhook ✅.  
> **Pago sandbox E2E:** plan se actualiza sin sync manual (founder confirmado) → P0-07 ✅ piloto.

## 3. Comprar VPS (OPS-01) — cuando toque

1. Leer **[`MIGRACION_VPS_QUE_CAMBIA.md`](MIGRACION_VPS_QUE_CAMBIA.md)** (qué tocar / qué no).
2. Seguir [`PREPARACION_VPS.md`](PREPARACION_VPS.md) **Fase 1**.
3. Bootstrap: `scripts/setup-ubuntu-vps.sh`.

Mismas URLs públicas; solo movés cloudflared + Docker al servidor. **No** cambies UptimeRobot ni el webhook Wompi.
