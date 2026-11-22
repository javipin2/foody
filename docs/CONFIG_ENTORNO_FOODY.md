# =============================================================================
# Foody — configuración centralizada (migración PC ↔ VPS)
# =============================================================================

## Un solo archivo para URLs y puertos

**Edita:** [`config/foody-entorno.env`](../config/foody-entorno.env)  
**Plantilla:** [`config/foody-entorno.env.example`](../config/foody-entorno.env.example)

| Clave | Qué controla |
|-------|----------------|
| `MODO` | `tunel` (HTTPS público) o `local` (localhost/LAN) |
| `DOMINIO` | `foodyy.store` (cámbialo si migras de dominio) |
| `HOST_APP` / `HOST_EQUIPO` / `HOST_API` / `HOST_SB` | Subdominios (`@` = raíz) |
| `PUERTO_*` | Puertos locales (Tunnel / Nest / Flutter web) |
| `TUNNEL_NOMBRE` | Nombre del conector Cloudflare |

**No van ahí los secretos** (JWT, Wompi, DB, token del túnel):

| Secretos | Archivo |
|----------|---------|
| API Nest, DB, Wompi, FCM | `foody_backend/.env` |
| Token Cloudflare | `scripts/cloudflare-tunnel.env` |

## Aplicar cambios

```powershell
.\scripts\sincronizar-entorno.ps1
.\scripts\verificar-entorno.ps1   # comprueba Flutter + CORS
```

Eso actualiza:

1. `lib/core/constantes/configuracion.dart` (Flutter)
2. `CORS_ORIGEN` + `CLIENT_WEB_URL` en `foody_backend/.env`
3. Imprime tabla de rutas Cloudflare + checklist Google OAuth

Compatibilidad (siguen funcionando):

- `.\scripts\sincronizar-url-tunel.ps1` → modo túnel  
- `.\scripts\usar-entorno-local.ps1` → modo local  

## Migrar a VPS (checklist corto)

**Detalle de qué cambia / qué no:** [`MIGRACION_VPS_QUE_CAMBIA.md`](MIGRACION_VPS_QUE_CAMBIA.md)

1. Copia el repo + `config/foody-entorno.env` (mismo dominio o edita `DOMINIO`).
2. En el VPS: mismos `PUERTO_*` o ajústalos y sincroniza.
3. `.\scripts\sincronizar-entorno.ps1` (o equivalente en Linux)
4. `.\scripts\actualizar-supabase-foodyy-store.ps1` (o equivalente en Linux)
5. Mueve `cloudflared` al VPS (mismas rutas públicas; **apaga el del PC**).
6. Completa secretos en `foody_backend/.env` (`ENTORNO=produccion`, JWT fuerte, `DATABASE_URL` interno, `DB_POOL_MAX=25`).
7. **No** cambies URLs de UptimeRobot ni webhook Wompi (siguen `api.foodyy.store`).
8. Rebuild web/APK solo si cambió `usarTunel`/hosts.

Detalle túnel: `docs/CLOUDFLARE_TUNNEL_FOODY.md` · VPS: `docs/PREPARACION_VPS.md`
