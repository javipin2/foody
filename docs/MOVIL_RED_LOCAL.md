# Foody — APK en móvil físico (PC como servidor)

## Por qué el APK no conecta aunque Chrome en el PC sí

| URL | ¿Funciona en PC? | ¿Funciona en móvil? |
|-----|------------------|---------------------|
| `localhost` / `127.0.0.1` | ✅ | ❌ (es el propio teléfono) |
| IP WSL `192.168.227.x` | A veces en PC | ❌ (red virtual, el móvil no la ve) |
| **IP Wi‑Fi del PC** `192.168.1.x` | ✅ | ✅ (misma red) |

Flutter usa `lib/core/constantes/configuracion.dart`:
- **Web** → `localhost:3000` y `localhost:8000`
- **APK** → `http://{ipLan}:3000` y `:8000`

## Pasos (cada vez que cambie tu IP Wi‑Fi)

1. Docker Desktop + Supabase en verde
2. `scripts\iniciar-backend-wsl.bat` (API puerto 3000)
3. En PowerShell, desde la raíz del repo:

```powershell
.\scripts\sincronizar-ip-movil.ps1
flutter build apk --release
```

4. Instala el APK nuevo en el móvil
5. **Móvil y PC en la misma Wi‑Fi** (no uses datos móviles)

## Probar sin recompilar (navegador del móvil)

En el teléfono, abre Chrome y visita:

```
http://TU_IP_PC:3000/api/v1/salud
```

Debe devolver JSON con `"exito": true`. Si no carga, el problema es red/firewall, no Flutter.

## Firewall Windows (si el móvil no llega)

Ejecutar **PowerShell como administrador**:

```powershell
netsh advfirewall firewall add rule name="Foody API 3000" dir=in action=allow protocol=TCP localport=3000
netsh advfirewall firewall add rule name="Foody Supabase 8000" dir=in action=allow protocol=TCP localport=8000
```

## ¿Funciona “por fuera” como un VPS real?

| Escenario | ¿Funciona? |
|-----------|------------|
| Mismo Wi‑Fi que el PC | ✅ con `ipLan` |
| Otra Wi‑Fi / datos móviles / otra ciudad | ❌ sin más configuración |
| Internet público (como VPS) | Necesitas **una** de estas: |

1. **VPS real** (producción Foody en Ubuntu en la nube) — objetivo final del proyecto
2. **Cloudflare Tunnel + foodyy.store** — `docs/CLOUDFLARE_TUNNEL_FOODY.md` · `scripts/iniciar-foody-foodyy-store.bat`
3. **VPN** a tu red de casa (WireGuard/OpenVPN) y seguir usando `ipLan`

El PC de desarrollo **no es** un VPS: tu router no expone puertos a Internet salvo que configures port forwarding manual (no recomendado en dev).

## Realtime (Supabase)

El móvil también necesita llegar a `:8000` para Realtime. `usesCleartextTraffic="true"` ya está en `AndroidManifest.xml` (HTTP local).

## Resumen

```
Teléfono (Wi‑Fi)  →  http://192.168.1.5:3000/api/v1  →  NestJS (WSL/Docker)
                  →  http://192.168.1.5:8000         →  Supabase (Docker)
```

Actualiza IP con `sincronizar-ip-movil.ps1` y **vuelve a generar el APK**.
