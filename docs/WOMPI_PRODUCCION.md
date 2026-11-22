# Wompi en producción — Foody

Guía para activar cobro de planes con **HTTPS** (túnel PC hoy; mismo dominio en VPS).

Fuente de URLs: `config/foody-entorno.env` → `.\scripts\sincronizar-entorno.ps1`.

## URLs actuales (foodyy.store)

| Uso | URL |
|-----|-----|
| Redirect tras pago (bridge → app) | `https://api.foodyy.store/api/v1/pagos/retorno-app` |
| Deep link app | `foody://plan?pago_id=…` |
| Fallback web | `https://equipo.foodyy.store/admin/panel?seccion=mejorar_plan` |
| Webhook eventos | `https://api.foodyy.store/api/v1/pagos/webhook-wompi` |

Con el túnel Cloudflare el webhook **sí llega** al Nest del PC (no hace falta VPS ni ngrok).

## Variables de entorno (`foody_backend/.env`)

```env
WOMPI_PUBLIC_KEY=pub_prod_...   # o pub_test_ en sandbox
WOMPI_PRIVATE_KEY=prv_prod_...
WOMPI_EVENTS_SECRET=prod_events_...
WOMPI_AMBIENTE=production       # sandbox | production
WOMPI_REDIRECT_URL=https://api.foodyy.store/api/v1/pagos/retorno-app
WOMPI_EQUIPO_URL=https://equipo.foodyy.store
```

| Variable | Uso |
|----------|-----|
| `WOMPI_PUBLIC_KEY` | Consulta transacciones + checkout |
| `WOMPI_PRIVATE_KEY` | Crear payment links |
| `WOMPI_EVENTS_SECRET` | Validar firma del webhook (`x-event-checksum`) |
| `WOMPI_AMBIENTE` | `production` / `prod` → API `production.wompi.co` |
| `WOMPI_REDIRECT_URL` | Tras pagar (HTTPS obligatorio). Bridge abre `foody://plan` |
| `WOMPI_EQUIPO_URL` | Fallback si no hay app instalada |

`sincronizar-entorno.ps1` **reescribe** `WOMPI_REDIRECT_URL` y `WOMPI_EQUIPO_URL`.

## Webhook (obligatorio)

1. Dashboard Wompi → **Eventos** → URL:
   ```
   https://api.foodyy.store/api/v1/pagos/webhook-wompi
   ```
2. Copia el **secreto de eventos** a `WOMPI_EVENTS_SECRET`.
3. Endpoint **público** (sin JWT); solo firma válida.
4. Evento: `transaction.updated` con `status = APPROVED`.

Sandbox: mismas URLs del túnel; claves `pub_test_` / `prv_test_` y `WOMPI_AMBIENTE=sandbox`.

## Flujo usuario

1. Admin → **Plan y pagos** → paga en Wompi (navegador).
2. Wompi → webhook → backend activa plan + Realtime `suscripcion_actualizada`.
3. Wompi → redirect bridge → intenta abrir app (`foody://plan`) o panel web.
4. App al volver (resume/deep link): sync + refresco de perfil (sin reiniciar a mano).
5. Si el webhook falla: **Activar plan** con ID de transacción (`POST /pagos/sincronizar`).

## Verificación

```powershell
.\scripts\verificar-wompi-tunel.ps1
.\scripts\verificar-salud.ps1 -BaseUrl https://api.foodyy.store/api/v1
```

## Seguridad

- Nunca commitear claves `prv_prod_` ni secretos de eventos.
- Webhook rechaza firmas inválidas (`400`).
- Idempotencia por `transaccion_wompi_id`.

Ver también: `docs/MODULO_SELF_SERVICE_PLANES.md` (F5–F7).
