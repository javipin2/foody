# Arranque web del panel Equipo

## Revalidación del lanzador de subdominios — 2026-11-26

Desde `scripts/iniciar1/iniciar-foody-subdominios.bat` se ejecutó el wrapper vigente con `FOODY_NOPAUSE=1`. La API `:3000` pasó healthcheck. Aunque se solicitó `-SkipBuild`, el script detectó que los artefactos Cliente/Equipo estaban ausentes o desactualizados y, correctamente, compiló ambos en staging antes de publicarlos. Cliente y Equipo quedaron disponibles en `:8081` y `:8080`; los servidores SPA reiniciaron con PID 10960 y 16620. Las seis comprobaciones GET (API, Equipo y Cliente local y público) devolvieron HTTP 200. El proceso `node dist/main.js` en `:3000` conservó PID 16876 y `cloudflared` conservó PID 17128. El wrapper terminó con exit code 0 y confirmó acceso público.

La salida mostró avisos no bloqueantes del ensayo WebAssembly (dependencias que importan `dart:html`/`dart:js_util` y dos lint de `image`), advertencia de fuente `CupertinoIcons` no incluida y 173 paquetes con versiones más nuevas fuera de las restricciones actuales. Ambos builds terminaron correctamente; no se actualizaron dependencias ni configuraciones por esos avisos. La salida de `sincronizar-entorno.ps1` indicó «Flutter entorno sin cambios»; no se cambió OAuth, CORS, credenciales, configuración del túnel ni datos. `git diff --check` pasó y el estado no muestra cambios en archivos lock.

**Conclusión:** el error antiguo de “Falta `build/web_cliente` — quita `-SkipBuild`” no se reprodujo con el launcher del workspace actual; este reconoce artefactos desactualizados y reconstruye en staging aun en ese modo. Si reaparece, revisar que el BAT usado realmente delegue a este checkout y que su ruta apunte al `servir-web-tunel-release.ps1` vigente. El build de Equipo reportó 78,9 s de compilación; puede volver a ejecutarse desde `scripts/iniciar1` de forma normal, sin necesidad de arrancar Cloudflare por separado.

**Fecha:** 2026-11-25  
**Alcance:** build `APP_FLAVOR=equipo`, arranque en el subdominio de túnel y navegación KDS. No se cambió OAuth, credenciales ni configuración Cloudflare.

## WEB-START-FCM-REJECTION-02 — promesa opcional sin manejar

Al reemplazar el build servido y recargar una ruta autenticada, Flutter quedó en blanco y `web/index.html` mostró `Promise: Error: FormatException: SyntaxError: Unexpected token '<', "<!DOCTYPE "...`. La pantalla de acceso también disparó el mismo aviso, por lo que no era un defecto exclusivo del dashboard.

En `ServicioFcmFoody.inicializar()` el caller ya trataba FCM como opcional, pero `_manejarAperturaDesdeNotificacion()` se lanzaba con `unawaited` y consultaba `FirebaseMessaging.getInitialMessage()` sin capturar su propio rechazo. Si el plugin recibe HTML en vez de JSON, ese Future anidado queda fuera del `catchError` del caller. Se añadió captura local con log solo en debug; FCM no bloquea el arranque.

## Verificación de salida

- `flutter analyze --no-pub lib/core/notificaciones/servicio_fcm_foody.dart`: limpio.
- `flutter build web --release --dart-define=APP_FLAVOR=equipo -t lib/main.dart -o build/web_equipo`: éxito. Avisos no bloqueantes: incompatibilidades del ensayo Wasm y ausencia de fuente `CupertinoIcons` en el build.
- Bundle nuevo SHA-256 `8E56BA20831F6466C4B6D6F8E4BA98D985E0ED3B4DCE21AD6668704988B0C3DE`; coincidió en build, `http://127.0.0.1:8080` y `https://equipo.foodyy.store` con query de cache única. Index público HTTP 200.
- Tras recargar el mismo navegador/sesión que había mostrado el error, volvió a abrir `/admin/panel` autenticado y navegó a Cocina KDS sin aviso `Promise` ni error visible. KDS expuso sus seis tickets listos y los controles de reimpresión.
- En el KDS publicado se abrió la confirmación de reimpresión y se canceló. No se disparó el endpoint ni se creó una copia física.

## Pendiente

Nest PID 10204 es anterior al `dist` vigente. El dashboard servido sigue mostrando dos fechas en la serie de siete días; la corrección de serie y rango está en fuente/build, pero aún requiere activación coordinada de API para validarse en el túnel. Las credenciales y el refresh de sesión del panel no se transmitieron ni modificaron.

**2026-11-25 — WEB-ASSET-FALLBACK-FCM-01:** tras rebuild, `/firebase-messaging-sw.js` faltaba del artefacto aunque existe en `web/`; además el servidor SPA devolvía `index.html` HTTP 200 para cualquier recurso faltante. `servir-web-tunel-release.ps1` ahora copia recursos web raíz distintos de `index.html` al bundle; `spa_http_server.py` responde 404 para extensiones de recursos no encontrados. Build Cliente/Equipo exit 0; recurso local `application/javascript` HTTP 200; manifiesto `application/json` HTTP 200; asset inexistente HTTP 404; ruta `/admin/login` HTTP 200 con fallback. Cloudflare aún tenía caché antigua para la ruta FCM (max-age 4 h); con query cache-buster devolvió el JS nuevo (MISS). Al recargar el Chrome de la sesión autenticada, el panel Equipo renderizó y mostró el Centro de operación. No se cambió OAuth, Firebase credentials, configuración de Tunnel, API ni datos. Tests domiciliarios 8/8; analyzer focalizado limpio. La caché antigua de Cloudflare puede seguir sirviéndose a otros clientes hasta expirar; purgarla requeriría acción desde Cloudflare.
