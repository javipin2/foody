# Foody — Monitoreo y health checks (P3-07)

> Endpoints públicos (sin JWT) para UptimeRobot, Cloudflare health checks y scripts locales.

---

## Endpoints

| Ruta | Uso | Criterio OK |
|------|-----|-------------|
| `GET /api/v1/salud` | Ping rápido + catálogo módulos | `exito=true`, `datos.base_datos=true` |
| `GET /api/v1/health` | **Consolidado** BD + Realtime + impresión + cola | `datos.estado` = `ok` o `degradado` (no `critico`) |
| `GET /api/v1/health/realtime` | Solo Supabase Realtime broadcast | `datos.conectado=true` |
| `GET /api/v1/health/impresion` | Agente Python + estadísticas cola | `datos.conectado=true` en prod con impresora |

Respuesta estándar: `{ exito, datos, mensaje }`.

### Campo `estado` en `/health`

| Valor | Significado |
|-------|-------------|
| `ok` | BD + Realtime + agente impresión + cola sin alertas |
| `degradado` | BD OK pero algún subsistema con aviso (Realtime off, agente off, jobs en error) |
| `critico` | PostgreSQL no responde |

### Alertas posibles (`datos.alertas[]`)

- `base_datos_no_responde`
- `realtime_no_configurado` / `realtime_desconectado`
- `agente_impresion_offline`
- `cola_impresion_errores:N`
- `cola_impresion_pendientes:N` (umbral > 20)

---

## Script local

```powershell
.\scripts\verificar-salud.ps1
.\scripts\verificar-salud.ps1 -BaseUrl https://api.foodyy.store/api/v1
.\scripts\verificar-salud.ps1 -Estricto   # exit 1 si agente impresion offline
```

Integrado en `verificar-ci.ps1` (modo rápido).

---

## Producción / túnel (OPS-05)

Se puede configurar **antes del VPS** apuntando al túnel Cloudflare.

### Valores exactos — foodyy.store (copiar a UptimeRobot)

| Campo | Valor |
|-------|--------|
| Tipo | HTTP(s) |
| URL | `https://api.foodyy.store/api/v1/health` |
| Intervalo | **5 minutos** |
| OK | HTTP **200** |
| Keyword | `"base_datos":true` |
| Alerta | email tras 2 fallos seguidos |

Opcional (más ligero): `https://api.foodyy.store/api/v1/salud` cada 1–2 min.

No exijas `"estado":"ok"` — con impresora offline el health puede ser `degradado` y eso es normal en demo.

### Checklist UptimeRobot (o Better Stack / Cloudflare Health)

1. Crear cuenta / monitor con la tabla de arriba.
2. Probar que el monitor pase en verde con el PC + túnel encendidos.
3. Cuando el monitor exista, marca OPS-05 ✅ en `RECOMENDACIONES_IMPLEMENTACION.md`.

### Validar desde el PC

```powershell
.\scripts\verificar-salud.ps1
.\scripts\verificar-salud.ps1 -BaseUrl https://api.foodyy.store/api/v1
```

### Load balancer / VPS

1. Health check path `/api/v1/salud` (ligero) o `/api/v1/health` (completo).
2. **Agente impresión:** en cada sede con impresora, `foody_python_printer` en la PC local; el backend verá `agente_impresion_offline` si no hay túnel WS — esperado hasta conectar por sede.
3. **Realtime:** requiere `SUPABASE_URL` + `SUPABASE_SERVICE_KEY` en `.env` del backend.

---

## Relacionado

- `docs/PREPARACION_VPS.md` — despliegue
- `docs/CI_E2E.md` — suite QA
- `scripts/verificar-impresion.ps1` — E2E cola impresión (pedido → job)
