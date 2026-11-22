# Google OAuth — Supabase self-hosted (Foody)

> **Equipo:** «Continuar con Google» en `/admin/login` y `/admin/registro` → JWT Nest (`/auth/login-google`).  
> **Cliente:** «Continuar con Google» en `/cliente/mis-pedidos` → vincula `device_id` ↔ `auth_uid` (`POST /dispositivos/vincular-auth`). **No** crea fila en `usuarios` staff.

## Por qué fallaba

1. En `~/supabase-docker/docker-compose.yml` las líneas de Google venían **comentadas** (Supabase no las activa solo con `.env`).
2. Faltaban `GOOGLE_CLIENT_ID` y `GOOGLE_SECRET` en `~/supabase-docker/.env`.
3. Hace falta un proyecto OAuth en **Google Cloud** (Foody no puede crearlo por ti).

## Configuración automática (recomendado)

### 1. Crear credenciales en Google Cloud

1. [Google Cloud Console → Credenciales](https://console.cloud.google.com/apis/credentials)
2. **Crear credenciales** → **ID de cliente de OAuth** → **Aplicación web**
3. **URI de redirección autorizada** — **solo** estas (Google **no** acepta IPs `192.168.x.x`):

   ```
   http://localhost:8000/auth/v1/callback
   ```

   Si usas túnel (ngrok) en producción/pruebas móvil, añade también:
   `https://TU-SUBDOMINIO.ngrok-free.app/auth/v1/callback`

4. **Orígenes JavaScript autorizados** (Flutter web):

   ```
   http://localhost:8080
   http://localhost:8081
   ```

   > **No pongas** `http://192.168.227.118:8000/...` — Google muestra error «debe terminar en .com».

5. Copia **Client ID** y **Client secret**.

### 2. Ejecutar script (PowerShell en Windows)

```powershell
.\scripts\configurar-google-oauth-supabase.ps1 `
  -ClientId "TU_ID.apps.googleusercontent.com" `
  -ClientSecret "GOCSPX-TU_SECRET"
```

Esto actualiza `.env` en WSL, `ADDITIONAL_REDIRECT_URLS` y recrea `supabase-auth`.

### 3. Probar

```powershell
# Staff
.\scripts\flutter-run-flavor.ps1 -Flavor equipo -Device chrome -WebPort 8080
# Cliente (historial)
.\scripts\flutter-run-flavor.ps1 -Flavor cliente -Device chrome -WebPort 8081
```

Equipo → **Continuar con Google** (staff).  
Cliente → **Mis pedidos** → **Continuar con Google** (historial en la nube).

Redirects que deja el script en `ADDITIONAL_REDIRECT_URLS`:

- `http://localhost:8080/admin/login`
- `http://localhost:8080/admin/registro`
- `http://localhost:8081/cliente/mis-pedidos`
- `foody://login`

## Sin Google (alternativa inmediata)

**Crear cuenta** con correo + contraseña en `/admin/registro` — no usa Supabase OAuth.

## Archivos

| Archivo | Rol |
|---------|-----|
| `scripts/configurar-google-oauth-supabase.ps1` | Entrada Windows |
| `scripts/configurar-google-oauth-supabase.sh` | Lógica en WSL |
| `~/supabase-docker/docker-compose.yml` | `GOTRUE_EXTERNAL_GOOGLE_*` |
| `lib/features/auth/presentation/staff_login_screen.dart` | `signInWithOAuth` |
| `lib/features/auth/domain/google_oauth_staff_service.dart` | OAuth staff + redirect web/móvil |
| `lib/features/auth/domain/google_oauth_cliente_service.dart` | OAuth consumidor → vincular-auth |
| `lib/features/pedidos/presentation/mis_pedidos_screen.dart` | CTA Google + historial |
| `lib/config/app_link_config.dart` | `foody://login` deep link móvil |

## Móvil (APK / Play Store)

Tras actualizar el script OAuth, Supabase acepta `foody://login` como redirect adicional.

1. **Android:** intent-filter `foody` + host `login` en `AndroidManifest.xml` (ya en repo).
2. **iOS:** scheme `foody` en `Info.plist`.
3. Re-ejecutar `.\scripts\configurar-google-oauth-supabase.ps1` para añadir `foody://login` a `ADDITIONAL_REDIRECT_URLS`.
4. Flujo registro con Google en móvil: OAuth → vuelve a la app → login procesa → registro solo con datos del restaurante.
