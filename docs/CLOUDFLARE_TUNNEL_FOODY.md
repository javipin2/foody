# Foody — Acceso externo con foodyy.store (Cloudflare Tunnel)

> Tu PC es el servidor. Cloudflare expone **HTTPS** sin IP estática ni abrir puertos en el router.

> **URLs / puertos:** edita [`config/foody-entorno.env`](../config/foody-entorno.env) y corre `.\scripts\sincronizar-entorno.ps1`. Guía: [`CONFIG_ENTORNO_FOODY.md`](CONFIG_ENTORNO_FOODY.md).

## Mapa público (valores por defecto)

| Público | App / servicio | Local |
|---------|----------------|-------|
| `https://foodyy.store` | **Cliente** (pedir comida, QR mesa) | Flutter **`:8081`** |
| `https://equipo.foodyy.store` | **Equipo** (admin, caja, cocina, domi) + **superadmin** (`/admin/foody-control`) | Flutter **`:8080`** |
| `https://api.foodyy.store` | NestJS API | **`:3000`** |
| `https://sb.foodyy.store` | Supabase | **`:8000`** |

**Superusuario Foody** no es un tercer flavor: entra en **equipo** con usuario `super_admin` → panel Foody Control.

**No rota la IP ni la URL.** Lo que se rompe suele ser: cloudflared apagado, Flutter no en el puerto, DNS del `@` mal, o `usarTunel = false`.

### Cloudflare — Rutas del túnel `foody` (obligatorio)

Zero Trust → Tunnels → **foody** → **Rutas** / Public Hostname:

| Hostname | Service |
|----------|---------|
| `foodyy.store` | `http://localhost:8081` |
| `equipo.foodyy.store` | `http://localhost:8080` |
| `api.foodyy.store` | `http://localhost:3000` |
| `sb.foodyy.store` | `http://localhost:8000` |

DNS: `equipo` tipo **CNAME** → `5fac6037-01fe-437c-aecf-2df42fb73f74.cfargotunnel.com` (proxy naranja), o tipo Túnel → `foody` si Zero Trust lo crea al agregar la ruta.  
`foodyy.store` ya debe ser CNAME/túnel (no A de parking Namecheap).

---

## Arranque diario (recomendado)

1. Docker Desktop (Supabase verde)
2. API Nest: `scripts\iniciar-backend-wsl.bat` (ventana abierta)
3. Web + túnel (cliente **y** equipo):

```bat
scripts\iniciar-foody-subdominios.bat
```

Eso arranca cloudflared (si falta) y sirve **ambos** puertos. Falla con error si `:8080` (equipo) o `:8081` (cliente) no quedan arriba.

- Rebuild web: `scripts\iniciar-foody-subdominios.bat rebuild`
- **No** hace falta correr `iniciar-cloudflare-tunnel.ps1` aparte (se duplica)

Comprobar:

```powershell
.\scripts\verificar-tunel-foodyy.ps1
```

---

## Por qué a veces falla

| Síntoma | Causa típica |
|---------|----------------|
| **Error 522** en `foodyy.store` pero `api` OK | DNS apex era A a parking Namecheap → debe ser CNAME/túnel a `foody` |
| Página **en blanco** en el dominio | `flutter run -d chrome` (debug); usar `web-server` / `iniciar-foody-subdominios` |
| `api` OK pero app 502 | No hay Flutter en `:8080` / `:8081` |
| App local OK, túnel no | `usarTunel = false` |
| CORS raro | API sin reiniciar tras `.env` |

### Arreglar Error 522 (apex) — causa real encontrada 2026-08-03

**Diagnóstico con logs `cloudflared --loglevel debug`:**

| Hostname | ¿Llega al conector en el PC? |
|----------|------------------------------|
| `api.foodyy.store` | Sí → `localhost:3000` |
| `sb.foodyy.store` | Sí → `localhost:8000` |
| `foodyy.store` | **No** (ningún request en el log) → Cloudflare responde **522** sin hablar con tu PC |

El túnel **sí tiene** la ruta `foodyy.store → http://127.0.0.1:8080` (se ve en la config remota).  
El fallo es **DNS del apex**: el dominio raíz no está enlazado al túnel (nube naranja “clásica” sin origen, o registro A conflictivo).

**Arreglo (2 minutos) — Dashboard Cloudflare (no Zero Trust):**

1. Entrá a [dash.cloudflare.com](https://dash.cloudflare.com) → dominio **foodyy.store** → **DNS** → **Records**.
2. Buscá el registro de nombre `@` (o `foodyy.store`).
3. **Editá** o **creá** así:

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| **CNAME** | `@` | `5fac6037-01fe-437c-aecf-2df42fb73f74.cfargotunnel.com` | Proxied (naranja) |

   (Ese UUID es el Tunnel ID de **foody**; si tu túnel cambia, usá el ID del Overview.)

4. Si hay registros **A/AAAA** viejos del `@` apuntando a otra IP → **borralos** (solo debe quedar el CNAME al túnel).
5. Esperá 30–60 s. Probá `https://foodyy.store`.
6. En el PC debe haber algo en `:8080` (Flutter o `python -m http.server 8080`).

**Atajo si el apex sigue rebelde:** en Zero Trust → Tunnels → foody → Rutas → **Agregar** `app.foodyy.store` → `http://localhost:8080`. Los subdominios suelen crear el CNAME bien. Luego en DNS podés poner Redirect `@` → `app.foodyy.store`.

**Prueba rápida tras el fix:** si ves “Foody tunnel OK” (página de prueba) o la app Flutter, el DNS ya apunta al túnel.

Volver a solo localhost:

```powershell
.\scripts\usar-entorno-local.ps1
```

(y hot restart Flutter). Para túnel otra vez: `sincronizar-url-tunel.ps1` o el `.bat`.

---

## Configuración inicial (una vez)

### 1. Namecheap → nameservers Cloudflare

### 2. Cloudflare → Tunnels → `foody` → 3 rutas (Public hostnames)

| Hostname | URL servicio |
|----------|----------------|
| `foodyy.store` | `http://localhost:8081` (cliente) |
| `equipo.foodyy.store` | `http://localhost:8080` (equipo + superadmin) |
| `api.foodyy.store` | `http://localhost:3000` |
| `sb.foodyy.store` | `http://localhost:8000` |

### 3. Token en `scripts/cloudflare-tunnel.env`

```env
TUNNEL_TOKEN=eyJ...
```

Validar: `.\scripts\pegar-token-tunel.ps1`

### 4. Sincronizar

```powershell
.\scripts\configurar-foodyy-store.ps1
```

### 5. Google OAuth

- Redirect: `https://sb.foodyy.store/auth/v1/callback`
- Origen JS: `https://foodyy.store`
- Script: `.\scripts\actualizar-supabase-foodyy-store.ps1`

---

## Scripts

| Script | Uso |
|--------|-----|
| `iniciar-foody-subdominios.bat` | Cliente :8081 + equipo :8080 + tunel |
| `iniciar-foody-foodyy-store.bat` | Legacy (solo un Flutter); preferir subdominios |
| `verificar-tunel-foodyy.ps1` | Diagnostico puertos + URLs publicas |
| `iniciar-cloudflare-tunnel.ps1` | Solo conector |
| `iniciar-flutter-web-tunel.ps1` | Un flavor (`web-server`) |
| `sincronizar-url-tunel.ps1` | `usarTunel=true` + CORS |
| `usar-entorno-local.ps1` | `usarTunel=false` (dev local) |

---

## Migrar a VPS

Mismo dominio `foodyy.store` → conector `cloudflared` en el VPS (mismas rutas). Sin cambiar URLs de la app.

*Relacionado: `docs/MOVIL_RED_LOCAL.md` · `docs/WOMPI_PRODUCCION.md`*
