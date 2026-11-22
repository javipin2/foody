# Foody — Auditoría Docker y variables de entorno (Prompt 08)

> **Fecha:** 2026-08-06  
> **Alcance:** `docker-compose.dev.yml`, `docker-compose.prod.yml`, `foody_backend/Dockerfile`, `.env.example`, `validar-config-produccion.ts`, scripts VPS.  
> **Método:** lectura estática. Sin `docker compose up` en Hetzner en esta pasada.  
> **Predecesoras:** AQ-\* · … · [`AUDITORIA_BD_SUPABASE.md`](AUDITORIA_BD_SUPABASE.md) (BD-\*).  
> **Sucesora Prompt 09 (Infra):** [`AUDITORIA_INFRA.md`](AUDITORIA_INFRA.md) — INF-\*.  
> **Estado oficial:** [`MASTER_STATUS.md`](MASTER_STATUS.md) § Docker / env (DK-\*).  
> **Al cerrar un DK-\*:** marcar ✅ aquí + MASTER + viñeta en `AVANCE_PROYECTO.md`.  
> **Solapes:** backups ≡ BD-BKP / OPS-02; pool/JWT ≡ AUTH / AQ-SCALE.

---

## Veredicto

| Dimensión | Nota | Una línea |
|-----------|------|-----------|
| Compose prod (forma) | B− | Nest + HC + `unless-stopped`; **sin** Postgres/Supabase en el mismo archivo |
| Puertos / volúmenes | C+ | Prod: solo `3000` (OK detrás de túnel); **sin** volumen app (OK stateless); DB fuera |
| Secretos | C | `.env` no commiteado ✅; JWT default en código; `.env.example` **bypassea** el gate prod |
| Healthchecks | B | Nest `/health` + Postgres dev `pg_isready`; Supabase **fuera** del compose Foody |
| Restart | B+ | `unless-stopped` en prod y dev |
| Logs / disco Hetzner | D | **Sin** `logging.max-size` → riesgo llenar disco |
| Dockerfile higiene | C− | Sin `.dockerignore`, sin USER non-root; compose/Dockerfile **untracked** en git |

**Global Prompt 08:** ~**55 / 100** disciplina Docker/ops (esqueleto usable; no Hetzner-hardened).

**Qué ya está bien:**

- `restart: unless-stopped` en backend prod y Postgres dev.
- Healthcheck Nest consulta `/api/v1/health` y exige `datos.base_datos`.
- Postgres dev: volumen nombrado `foody_postgres_data` + `pg_isready`.
- `validarConfigProduccion()` rechaza JWT exacto `foody_jwt_secret_cambiar` y `CORS=*`.
- `.gitignore` ignora `.env` / `foody_backend/.env`.

---

## Índice de hallazgos

| Prefijo | Tema | Abiertos |
|---------|------|--------:|
| DK-COMPOSE-* | Compose prod/dev / puertos / volúmenes | 5 |
| DK-SEC-* | Secretos y env | 4 |
| DK-HC-* | Healthchecks | 3 |
| DK-RST-* | Restart | 1 |
| DK-LOG-* | Logs / disco | 2 |
| DK-FIX-* | Remediaciones | 7 |

Leyenda: `🟣 abierto` · `🟡 parcial` · `✅ cerrado` · `📅 post-piloto`

---

## 1. Docker Compose — puertos y volúmenes (DK-COMPOSE)

### `docker-compose.prod.yml` (VPS / Hetzner)

```yaml
# Solo servicio backend Nest
ports: '3000:3000'
restart: unless-stopped
env_file: ./foody_backend/.env
# SIN volumes · SIN logging · SIN depends_on DB
```

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **DK-COMPOSE-01** | 🟡 | Media | Puerto **3000** publicado en host — OK si Cloudflare Tunnel / firewall; **innecesario** si solo reverse-proxy en red Docker | Documentar “bind 127.0.0.1:3000” o red interna |
| **DK-COMPOSE-02** | ✅ | — | Sin volumen en Nest — correcto (stateless; datos en Postgres externo) |
| **DK-COMPOSE-03** | 🟣 | Alta | Postgres / Supabase **no** están en este compose — persistencia DB depende del stack aparte; si ese stack no tiene volumen, **pérdida total** | Verificar compose Supabase (`setup-supabase-docker.sh`) |
| **DK-COMPOSE-04** | 🟡 | Alta | Archivos **en workspace**; faltan `git add` en commit | Commitear cuando founder pida |
| **DK-COMPOSE-05** | 🟡 | Baja | Dev: `5432:5432` + password `foody_password_dev` — OK local; **nunca** usar este compose en VPS público | |

### `docker-compose.dev.yml`

| Aspecto | Valor |
|---------|-------|
| Volumen | `foody_postgres_data` → persistencia ✅ |
| Puerto | `5432` expuesto (local) |
| Password | hardcodeado `foody_password_dev` (dev) |

---

## 2. Variables de entorno y secretos (DK-SEC)

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **DK-SEC-01** | ✅ | — | `.env` real **no** en git | `.gitignore` |
| **DK-SEC-02** | 🟣 **prod-risk** | Alta | Fallback JWT en código: `?? 'foody_jwt_secret_cambiar'` | `auth.module.ts`, `jwt.strategy.ts` |
| **DK-SEC-03** | 🟣 **prod-risk** | Alta | `.env.example` usa `JWT_SECRET=foody_jwt_secret_cambiar_en_produccion` — **≠** default → **pasa** `validarConfigProduccion` con secreto débil conocido | `.env.example:18` vs `validar-config-produccion.ts:1-12` |
| **DK-SEC-04** | 🟡 | Media | Compose prod no hardcodea secrets (usa `env_file`) ✅; password solo en compose **dev** | |

**Respuesta corta:** no hay secretos de prod en el compose. Sí hay defaults JWT en código y un example que **esquiva** el validador. CORS `*` en example es OK solo con `ENTORNO=desarrollo`.

---

## 3. Healthchecks (DK-HC)

| Contenedor | ¿HC? | Cómo |
|------------|------|------|
| Nest (`foody_backend`) | ✅ | `fetch http://127.0.0.1:3000/api/v1/health` → `datos.base_datos` |
| Postgres (dev compose) | ✅ | `pg_isready` |
| Supabase (Kong/DB/Realtime) | 🚫 en Foody compose | Script espera Kong; stack upstream |

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **DK-HC-01** | ✅ | — | Backend prod tiene healthcheck + `start_period: 20s` |
| **DK-HC-02** | ✅ | — | Postgres dev tiene healthcheck |
| **DK-HC-03** | 🟡 | Media | HC Nest ignora `estado=degradado` (impresión/realtime) — solo exige DB | Aceptable; UptimeRobot puede usar `/salud` |

---

## 4. Estrategia de reinicio (DK-RST)

| ID | Estado | Hallazgo |
|----|--------|----------|
| **DK-RST-01** | ✅ | `restart: unless-stopped` en `backend` (prod) y `db` (dev) — correcto para VPS |

No hace falta `always` (reiniciaría tras `docker stop` intencional). `unless-stopped` es el estándar recomendado.

---

## 5. Logs — ¿llenarán el disco Hetzner? (DK-LOG)

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **DK-LOG-01** | 🟣 **prod-risk** | Alta | **Ningún** compose define `logging: driver: json-file` + `max-size` / `max-file` | Logs Docker crecen sin tope |
| **DK-LOG-02** | 🟣 | Media | Nest `console.log` / Logger sin rotación de archivo propia | Depende 100% del driver Docker |

**Respuesta corta:** hoy **sí hay riesgo** de llenar disco en Hetzner con el tiempo. Mitigar con:

```yaml
logging:
  driver: json-file
  options:
    max-size: '10m'
    max-file: '3'
```

(y lo mismo en el compose de Supabase del VPS).

---

## 6. Dockerfile (relacionado)

| Gap | Impacto |
|-----|---------|
| Sin `foody_backend/.dockerignore` | `COPY . .` puede meter `.env`, tests, basura en imagen |
| Sin `USER node` | Proceso root en contenedor |
| `npm install` (no `ci`) | Builds no reproducibles al 100% |

---

## 7. Backlog remediación (DK-FIX)

| ID | Prioridad | Acción | Cierra | Prod-risk |
|----|-----------|--------|--------|-----------|
| **DK-FIX-01** | P0 | Añadir `logging` max-size/max-file a `docker-compose.prod.yml` (+ doc Supabase) | DK-LOG-01/02 | **Sí** |
| **DK-FIX-02** | P0 | Endurecer `validarConfigProduccion`: rechazar cualquier JWT que contenga `foody_jwt_secret` / longitud mínima; alinear `.env.example` | DK-SEC-02/03 | **Sí** |
| **DK-FIX-03** | P1 | Commitear `docker-compose.prod.yml` + `Dockerfile`; crear `.dockerignore` | DK-COMPOSE-04 | Medio |
| **DK-FIX-04** | P1 | Bind `127.0.0.1:3000:3000` o red interna detrás de Caddy/túnel | DK-COMPOSE-01 | Medio |
| **DK-FIX-05** | P1 | Documentar/verificar volúmenes persistentes del stack Supabase en VPS | DK-COMPOSE-03 | **Sí** |
| **DK-FIX-06** | P2 | Dockerfile: `USER node`, `npm ci`, multi-stage limpio | — | Bajo |
| **DK-FIX-07** | P2 | Checklist `verificar-docker-prod.ps1` + logging + JWT en CI | — | Bajo |

---

## 8. Matriz de conteo

| Grupo | 🟣 | 🟡 | ✅ |
|-------|---:|---:|---:|
| DK-COMPOSE | 2 | 2 | 1 |
| DK-SEC | 2 | 1 | 1 |
| DK-HC | 0 | 1 | 2 |
| DK-RST | 0 | 0 | 1 |
| DK-LOG | 2 | 0 | 0 |
| **Total** | **6** | **4** | **5** |
| DK-FIX | 7 | | |

---

## 9. Cómo verificar al remediar

| Fix | Evidencia |
|-----|-----------|
| DK-FIX-01 logs | `docker inspect foody_backend` → `LogConfig.Config` con MaxSize |
| DK-FIX-02 JWT | Arrancar con example secret + `ENTORNO=produccion` → **falla** bootstrap |
| DK-FIX-03 git | `git ls-files docker-compose.prod.yml Dockerfile .dockerignore` |
| DK-FIX-04 puerto | `ss -tlnp` solo 127.0.0.1:3000 o sin publish |
| DK-FIX-05 Supabase vol | `docker volume ls` en VPS incluye datos Postgres Supabase |

Scripts: `scripts/verificar-docker-prod.ps1`, `setup-ubuntu-vps.sh`.

---

## Changelog de este documento

| Fecha | Cambio |
|-------|--------|
| 2026-08-06 | Enlace a Prompt 09 (`AUDITORIA_INFRA.md`) |
| 2026-08-06 | **Creación** Prompt 08 — DK-COMPOSE/SEC/HC/RST/LOG + DK-FIX-01…07; enlazado MASTER / AVANCE / README / ROADMAP |

---

*Fin — Auditoría Docker y variables de entorno (Prompt 08).*
