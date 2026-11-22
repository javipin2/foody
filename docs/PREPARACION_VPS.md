# Foody — Preparación migración VPS (PC+túnel adelanta casi todo)

> **Fase 0 (ahora):** PC + Docker + Cloudflare Tunnel (`foodyy.store`).  
> **Fase 1:** comprar Ubuntu VPS y mover el mismo conector/procesos.  
> Preflight: `.\scripts\verificar-listo-vps.ps1`

## Día del VPS — leer primero

**Checklist de qué cambia / qué no:** [`MIGRACION_VPS_QUE_CAMBIA.md`](MIGRACION_VPS_QUE_CAMBIA.md)

URLs / puertos: [`config/foody-entorno.env`](../config/foody-entorno.env) · [`docs/CONFIG_ENTORNO_FOODY.md`](CONFIG_ENTORNO_FOODY.md).

---

**Acciones humanas (Fase 0):** ver [`ACCIONES_HUMANAS_TUNEL.md`](ACCIONES_HUMANAS_TUNEL.md) o `.\scripts\checklist-acciones-humanas-tunel.ps1`.

---

## Fase 0 — PC + túnel (adelantar sin VPS)

| Ítem | Estado / cómo |
|------|----------------|
| Dominio HTTPS | ✅ Túnel `foody` → app/equipo/api/sb |
| Config central | ✅ `config/foody-entorno.env` + `sincronizar-entorno.ps1` |
| `DB_POOL_MAX=25` | ✅ OPS-04 en `.env` |
| Wompi redirect + webhook URL | ✅ `equipo` / `api.foodyy.store` — registrar en dashboard |
| Health público | ✅ `verificar-salud.ps1 -BaseUrl https://api.foodyy.store/api/v1` |
| UptimeRobot | ✅ Monitor Up (2026-08-03) |
| Backups PC | ✅ `backup-postgres.ps1` + `programar-backup-windows.ps1` |
| Compose prod build | ✅ `docker-compose.prod.yml` + `verificar-docker-prod.ps1` |
| Preflight | `.\scripts\verificar-listo-vps.ps1` |

**No hace falta** en Fase 0: `ENTORNO=produccion` (usar en VPS con JWT fuerte).

---

## Qué ya está listo para migrar

| Pieza | Archivo / script | Notas |
|-------|------------------|-------|
| Backend producción | `docker-compose.prod.yml` + `foody_backend/Dockerfile` | `env_file` → `foody_backend/.env` |
| Health check | `GET /api/v1/salud`, `GET /api/v1/health` | `docs/MONITOREO_SALUD.md` |
| Dominio + HTTPS | `docs/CLOUDFLARE_TUNNEL_FOODY.md` | Mismo túnel; conector en Ubuntu |
| Flutter web | `servir-web-tunel-release.ps1` / Nginx | Builds `build/web_*` |
| Supabase | Self-hosted Docker | Migraciones `foody_supabase/migrations/` |
| Wompi | `docs/WOMPI_PRODUCCION.md` | Webhook ya apunta al túnel |
| Bootstrap Ubuntu | `scripts/setup-ubuntu-vps.sh` | Docker, compose.prod, cron backup, cloudflared |
| QA | `verificar-qa-manual.ps1` | Misma suite |
| CI | `.github/workflows/ci.yml` | |

---

## Fase 1 — Cuando tengas VPS (P0-05 → P0-08)

1. **Ubuntu 22.04+** — SSH
2. En el VPS: `git clone` → `/opt/foody` (o ruta acordada)
3. Copiar desde el PC (scp/rsync): `config/foody-entorno.env`, `foody_backend/.env`, `scripts/cloudflare-tunnel.env`
4. `chmod +x scripts/setup-ubuntu-vps.sh && ./scripts/setup-ubuntu-vps.sh` (instala Docker; imprime siguientes pasos)
5. **Supabase self-hosted** — `docs/ENTORNO_LOCAL.md`
6. **Migraciones** — `foody_supabase/migrations/001…NNN` (+ RLS `064` si aplica)
7. Ajustar `.env`: `ENTORNO=produccion`, `JWT_SECRET` fuerte, `DATABASE_URL` interno, `DB_POOL_MAX=25`
8. `docker compose -f docker-compose.prod.yml up -d --build`
9. **Mover cloudflared** al VPS (mismas Public Hostnames; apagar conector del PC)
10. Flutter web release en `:8080`/`:8081` o Nginx
11. Confirmar Wompi webhook (misma URL) + UptimeRobot sigue verde
12. Cron backup: ver `docs/BACKUPS_FOODY.md`
13. Validar: `verificar-listo-vps.ps1` desde PC contra URLs públicas (o QA roles)

---

## Variables local → VPS

Detalle completo (dashboards, antipatrones, orden de corte): **[`MIGRACION_VPS_QUE_CAMBIA.md`](MIGRACION_VPS_QUE_CAMBIA.md)**.

| Variable | PC+túnel | VPS |
|----------|----------|-----|
| `DOMINIO` / hosts | `foodyy.store` (igual) | Igual |
| `DATABASE_URL` | Docker local | Host interno compose/Supabase |
| `ENTORNO` | `desarrollo` | `produccion` |
| `JWT_SECRET` | demo/dev | **Nuevo secreto fuerte** |
| `DB_POOL_MAX` | `25` | `25` |
| `WOMPI_*` URLs | HTTPS túnel | **Sin cambiar** |
| UptimeRobot | Ya Up | **Sin cambiar URL** |
| cloudflared | En el PC | **Solo en el VPS** (apagar PC) |
| Flutter | `usarTunel=true` | Igual tras sync |

---

## Tras el primer deploy

1. Cron + R2 (`docs/BACKUPS_FOODY.md`)
2. Monitor UptimeRobot ya creado en Fase 0
3. RLS prod si el VPS es BD nueva

## Referencias

- **Qué cambia al migrar:** `docs/MIGRACION_VPS_QUE_CAMBIA.md`
- `docs/CONFIG_ENTORNO_FOODY.md`
- `docs/RECOMENDACIONES_IMPLEMENTACION.md` (OPS-01…05)
- `docs/ROADMAP_TERMINAR_FOODY.md` (P0-05…08)
- `docs/BACKUPS_FOODY.md` · `docs/WOMPI_PRODUCCION.md` · `docs/MONITOREO_SALUD.md`
