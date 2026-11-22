# Entorno local Foody — VPS de pruebas (tu PC con Ubuntu)

Guía para desarrollar con **Supabase self-hosted** + **NestJS** + **Flutter**, sin depender del cloud de Supabase.

> **URLs, puertos y dominio:** un solo archivo — [`config/foody-entorno.env`](../config/foody-entorno.env). Tras editar: `.\scripts\sincronizar-entorno.ps1`. Detalle: [`CONFIG_ENTORNO_FOODY.md`](CONFIG_ENTORNO_FOODY.md).

## Arquitectura en tu PC

```
┌─────────────────────────────────────────────────────────┐
│  Windows (desarrollo Flutter / Cursor)                  │
│  lib/ → Dio → http://IP_UBUNTU:3000/api/v1            │
└──────────────────────────┬──────────────────────────────┘
                           │ red local (Wi‑Fi)
┌──────────────────────────▼──────────────────────────────┐
│  Ubuntu 22.04 (VPS de pruebas)                          │
│  • Docker: PostgreSQL (+ stack Supabase opcional)       │
│  • NestJS foody_backend :3000                           │
│  • Supabase API :8000 (self-hosted)                     │
└─────────────────────────────────────────────────────────┘
```

## Requisitos en Ubuntu

- Docker + Docker Compose
- Node.js 20 LTS (`node -v`)
- Git

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-plugin git curl
sudo usermod -aG docker $USER
# Cerrar sesión y volver a entrar para usar docker sin sudo
```

## Paso 1 — PostgreSQL rápido (solo NestJS al inicio)

Desde la carpeta del proyecto (montada en Ubuntu o clonada ahí):

```bash
docker compose -f docker-compose.dev.yml up -d db
```

- Postgres: `localhost:5432`
- Base: `foody_db`
- Usuario: `postgres` / contraseña: `foody_password_dev` (solo desarrollo)

## Paso 2 — Supabase self-hosted (completo)

**Método recomendado (sin `git clone` completo):**

```bash
cd "FOODY APP"
sed -i 's/\r$//' scripts/setup-supabase-docker.sh   # si viene de Windows
chmod +x scripts/setup-supabase-docker.sh
./scripts/setup-supabase-docker.sh
```

O manualmente en `~/supabase-docker`:

```bash
mkdir -p ~/supabase-docker && cd ~/supabase-docker
curl -fsSL -o supabase.tar.gz https://github.com/supabase/supabase/archive/refs/heads/master.tar.gz
tar xzf supabase.tar.gz --strip-components=2 supabase-master/docker && rm supabase.tar.gz
cp .env.example .env
sh utils/generate-keys.sh --update-env
sh utils/add-new-auth-keys.sh --update-env
# Reemplazar IP_WSL por la de: hostname -I
sed -i 's#^SUPABASE_PUBLIC_URL=.*#SUPABASE_PUBLIC_URL=http://IP_WSL:8000#' .env
sed -i 's#^API_EXTERNAL_URL=.*#API_EXTERNAL_URL=http://IP_WSL:8000#' .env
sed -i 's#^SITE_URL=.*#SITE_URL=http://IP_WSL:8000#' .env
docker compose up -d
```

Documentación: https://supabase.com/docs/guides/self-hosting/docker

3. Anotar en `foody_backend/.env`:
   - `SUPABASE_URL=http://IP_UBUNTU:8000`
   - `SUPABASE_ANON_KEY=...`
   - `SUPABASE_SERVICE_KEY=...`
   - Con **Supavisor** (puerto 5432 en host):  
     `DATABASE_URL=postgresql://postgres.<POOLER_TENANT_ID>:TU_PASSWORD@localhost:5432/postgres`  
     (`POOLER_TENANT_ID` en `~/supabase-docker/.env`, suele ser `your-tenant-id`)
   - Sin pooler (solo `docker-compose.dev.yml`):  
     `postgresql://postgres:foody_password_dev@localhost:5432/foody_db`

4. Ejecutar migraciones Foody (cuando existan en `foody_supabase/migrations/`):

```bash
psql "$DATABASE_URL" -f foody_supabase/migrations/001_geografia.sql
# … en orden numérico
```

> Las migraciones completas están definidas en `INFRAESTRUCTURA/GUIA_DESARROLLO_FOODY_CURSOR.md` (Fase 1).

## Arranque rápido en Windows (sin buscar comandos)

WSL **no** hay que “abrirlo” como programa: se usa solo cuando ejecutas un script o `wsl`. Con **Docker Desktop** encendido, el flujo habitual es:

| Paso | Qué hacer |
|------|-----------|
| 1 | Encender **Docker Desktop** (Supabase en verde) |
| 2 | Doble clic en `scripts/iniciar-backend-wsl.bat` — **Node en Windows** (deja esa ventana abierta; no ejecutes otros comandos ahí) |
| 3 | Doble clic en `scripts/iniciar-flutter-web.bat` **o** `scripts/iniciar-foody-dev.bat` (abre backend + Flutter) |

Atajo todo-en-uno: **`scripts/iniciar-foody-dev.bat`** (backend en ventana aparte, luego Flutter).

> **Importante:** el backend NestJS debe correr con **Node de Windows**, no en WSL. Las dependencias nativas (`sharp`) se instalan para Windows; en WSL el proceso muere al arrancar y `localhost:3000` queda vacío (`ERR_CONNECTION_REFUSED`). WSL sigue usándose para Supabase/scripts Docker.

La primera vez en `foody_backend` (PowerShell o CMD): `npm install` (y `.env` desde `.env.example` o `scripts/sincronizar-env-backend.bat`).

## Paso 3 — Backend NestJS

```bash
cd foody_backend
cp .env.example .env
# Completar .env con IP y claves
npm install
npm run start:dev
```

API: `http://IP_UBUNTU:3000/api/v1`

## Paso 4 — Flutter (Windows) apuntando al VPS

| Dónde corre la app | URL del backend |
|--------------------|-----------------|
| Emulador Android | `http://10.0.2.2:3000/api/v1` (si NestJS está en la misma máquina Windows) |
| Emulador Android → API en Ubuntu | `http://IP_UBUNTU:3000/api/v1` |
| Dispositivo físico | `http://IP_WIFI_PC:3000/api/v1` (misma red Wi‑Fi) — ver `docs/MOVIL_RED_LOCAL.md` |
| Chrome web (Windows) | `http://localhost:3000` o IP Ubuntu según dónde esté NestJS |

Copiar plantilla:

```bash
# En Windows, al crear configuracion.dart desde el ejemplo:
# lib/core/constantes/configuracion.ejemplo.dart → configuracion.dart
```

**Importante:** en móvil físico usa la **IP Wi‑Fi de Windows** (`ipconfig`), no `localhost` ni la IP WSL. Script: `.\scripts\sincronizar-ip-movil.ps1` → luego `flutter build apk`.

**Importante (WSL):** reemplazar `IP_UBUNTU` por la IP LAN de tu PC Ubuntu (`ip a` → `inet 192.168.x.x`).

### Flutter web en Windows (puertos)

| Flavor | Puerto | Comando típico |
|--------|--------|----------------|
| `equipo` | 8080 | `.\scripts\flutter-run-flavor.ps1 -Flavor equipo -Device chrome -WebPort 8080` |
| `cliente` | 8082 (si pediste 8080) | `.\scripts\flutter-run-flavor.ps1 -Flavor cliente -Device chrome` |

Si el puerto está ocupado (`errno 10048`): suele ser un `dartvm` de un `flutter run` anterior. **Solo DX local — no es fallo de producción.** Libera con `-LiberarPuerto` (ver `docs/ESTRATEGIA_BACKEND_PRIMERO.md`).

Firewall Ubuntu:

```bash
sudo ufw allow 3000/tcp
sudo ufw allow 8000/tcp
sudo ufw allow 5432/tcp   # solo si necesitas psql desde Windows; en producción cerrar
```

## Paso 5 — Script automatizado (Ubuntu)

```bash
chmod +x scripts/setup-ubuntu-vps.sh
./scripts/setup-ubuntu-vps.sh
```

## Variables de entorno

| Archivo | Uso |
|---------|-----|
| `foody_backend/.env` | NestJS (no commitear) |
| `foody_backend/.env.example` | Plantilla |
| `lib/core/constantes/configuracion.dart` | URLs Flutter (no commitear secretos) |

## Cursor

- Reglas: `.cursor/rules/*.mdc`
- Memoria: `MEMORIA.md` — adjuntar con `@MEMORIA.md` en tareas grandes
- Especificación: `INFRAESTRUCTURA/`

## Orden recomendado de puesta en marcha

1. Docker Postgres (`docker-compose.dev.yml`)
2. Crear proyecto NestJS en `foody_backend/` (Fase 0 de la guía)
3. Supabase self-hosted cuando necesites Auth + Realtime + Storage
4. Migraciones SQL
5. Flutter solo consume API

## Solución de problemas

| Problema | Revisar |
|----------|---------|
| Flutter no conecta | IP, firewall, mismo Wi‑Fi, CORS en NestJS |
| `connection refused` Postgres | `docker compose ps`, puerto 5432 |
| API 500 `Tenant or user not found` | Usar `postgres.<POOLER_TENANT_ID>` en `DATABASE_URL`, no solo `postgres` |
| Supabase no arranca | RAM (mín. ~4 GB libres para stack completo) |
| Zone mismatch web | Ver comentarios en `lib/main.dart` (web) |
