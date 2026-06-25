# FCM Foody — configuración

## Flujo

| App | Registro token | Tabla BD |
|-----|----------------|----------|
| **Cliente** (`APP_FLAVOR=cliente`) | `POST /dispositivos/registrar` | `dispositivos_cliente.fcm_token` |
| **Equipo** (`APP_FLAVOR=equipo`) | `POST /auth/registrar-fcm` (JWT) | `tokens_push_admin` |

Código Flutter: `lib/core/notificaciones/servicio_fcm_foody.dart`  
Envío backend: `foody_backend/src/modulos/notificaciones/` (`FcmService` + cola `notificaciones_pendientes`).

## Por qué la campaña de Firebase muestra «0 enviados»

1. **Probaste en Chrome (web)** — en logs sale `falta kVapidKeyWebFoody`; sin VAPID **no hay token FCM** en web.
2. **Campañas de Firebase Console** no usan tus tokens automáticamente salvo que elijas audiencia/dispositivo de prueba.
3. Hace falta **teléfono Android** (APK `cliente` o `equipo`), aceptar notificaciones e **iniciar sesión** (equipo) para registrar token en BD.

## Push automáticos (backend — ya conectados)

| Evento | Quién recibe push |
|--------|-------------------|
| Pedido `pendiente_aprobacion` (QR mesa) | mesero, admin, gerente, cajero |
| Pedido `confirmado` / `en_cocina` | cocina, admin |
| Pedido `listo` | mesero, cajero, admin, domiciliario planta + **cliente** (si tiene `device_id`) |
| Pedido `en_camino` / `asignado` | cliente |
| Oferta domicilio independiente (60 s) | repartidor independiente |

Migración requerida: `foody_supabase/migrations/050_tokens_push_domiciliario.sql`

## 1. Firebase Console (ya hecho)

- Proyecto `foody-pin2`
- Apps Android: `app.foody.cliente`, `app.foody.equipo`
- `google-services.json` en `android/app/src/cliente/` y `src/equipo/`

## 2. Backend — enviar push de verdad

1. Firebase Console → **Configuración del proyecto** → **Cuentas de servicio** → **Generar nueva clave privada** (JSON).
2. Guarda el archivo fuera del repo (ej. `C:\secrets\foody-pin2-firebase.json`).
3. En `foody_backend/.env`:

```env
FIREBASE_SERVICE_ACCOUNT_PATH=C:\secrets\foody-pin2-firebase.json
```

Reinicia el backend. En logs debe aparecer: `Firebase Admin inicializado`.

Sin esto, los tokens **sí se registran** en BD, pero el envío queda en modo cola/log.

## 3. Web (Chrome)

1. VAPID en `kVapidKeyWebFoody` (`servicio_fcm_foody.dart`) — ya configurado.
2. `web/firebase-messaging-sw.js` apunta a `foody-pin2`.
3. Ejecutar en Chrome:

```powershell
flutter run -d chrome --dart-define=APP_FLAVOR=cliente
# o equipo (login staff)
flutter run -d chrome --dart-define=APP_FLAVOR=equipo
```

4. Acepta permiso de notificaciones. En consola: `token cliente → NestJS` o `token staff → NestJS` con `plataforma: web`.
5. En primer plano, la app muestra notificación nativa del navegador (`Notification API`).

## 4. Probar en móvil

```powershell
.\scripts\flutter-run-flavor.ps1 -Flavor cliente
# Acepta permiso de notificaciones
# En logs: "ServicioFcmFoody: token cliente → NestJS"
```

Equipo:

```powershell
.\scripts\flutter-run-flavor.ps1 -Flavor equipo
# Login staff → "token staff → NestJS"
```

Verifica en BD:

```sql
SELECT device_id, left(fcm_token, 20) FROM dispositivos_cliente WHERE fcm_token IS NOT NULL;
SELECT usuario_id, left(fcm_token, 20) FROM tokens_push_admin WHERE activo = true;
```

## 5. Enviar push de prueba (Firebase Console)

**Engagement** → **Messaging** → **Nueva campaña** → **Notificaciones**  
Elige la app (`app.foody.cliente` o `app.foody.equipo`) y envía a un dispositivo de prueba.

## 6. Verificar desde backend

```powershell
.\scripts\verificar-fcm.ps1
```

Endpoints:
- `GET /notificaciones/diagnostico` — Firebase Admin + cola + conteo `tokens_web_*`
- `POST /notificaciones/prueba` — push al usuario logueado (todas las plataformas)
- `POST /notificaciones/prueba-web` — push solo a tokens con `plataforma = 'web'`
- `POST /notificaciones/procesar-cola` — forzar envío cola

## 7. Cola programática (desarrollo)

```typescript
await notificacionesService.encolar({
  tipo: 'pedido_listo',
  destinatario_usuario_id: 'uuid-del-mesero',
  payload: { titulo: 'Pedido listo', cuerpo: 'Mesa 5', pedido_id: '...' },
});
await notificacionesService.procesarPendientes();
```

Para cliente por `device_id`:

```typescript
payload: { device_id: '...', titulo: 'Tu pedido', cuerpo: 'En camino' }
```
