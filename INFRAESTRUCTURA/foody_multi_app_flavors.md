# Foody — Dos apps desde un solo repo Flutter

> **Decisión:** Un repositorio, un `lib/main.dart`, **dos variantes (flavors)** con `applicationId` distinto para publicar en tiendas y desplegar en subdominios separados.

## Las dos apps

| Flavor | `applicationId` / Bundle ID | Nombre en tienda | Quién la usa | Ruta inicial |
|--------|----------------------------|------------------|--------------|--------------|
| `cliente` | `app.foody.cliente` | **Foody** | Consumidor final | `/splash` |
| `equipo` | `app.foody.equipo` | **Foody Equipo** | Dueño, domiciliario, cajero, mesero, cocina | `/admin/login` |

**Importante:** Dueño y domiciliario **comparten la misma app** (`equipo`). Tras el login, el backend redirige según rol (panel restaurante, dashboard repartidor, caja, cocina, etc.). En login staff hay enlace «Soy repartidor» → `/domiciliario/login`; en login domiciliario, «Soy staff del restaurante» → `/admin/login`.

La app **cliente** no expone rutas `/admin/*` ni `/domiciliario/*` (guard en `app_router.dart`).

## Código compartido

```
lib/
├── main.dart                    # Único entry point
├── core/config/app_flavor.dart  # APP_FLAVOR + guards de rutas
├── features/                    # Pantallas compartidas; cada build solo usa su subconjunto
└── firebase_options.dart        # FCM — una app Firebase por flavor
```

```dart
AppFlavor.actual // lee --dart-define=APP_FLAVOR=cliente|equipo
```

## Comandos

### Android

```bash
# Cliente (consumidor)
flutter run --flavor cliente --dart-define=APP_FLAVOR=cliente

# Equipo (dueño + domiciliario + operación sede)
flutter run --flavor equipo --dart-define=APP_FLAVOR=equipo
```

Release:

```bash
flutter build appbundle --flavor cliente --dart-define=APP_FLAVOR=cliente --release
flutter build appbundle --flavor equipo --dart-define=APP_FLAVOR=equipo --release
```

Atajo Windows: `.\scripts\flutter-run-flavor.ps1 -Flavor equipo`

### Web (subdominios)

| Subdominio (ejemplo) | Flavor |
|----------------------|--------|
| `app.foody.com` / `cliente.foody.com` | `cliente` |
| `equipo.foody.com` / `panel.foody.com` | `equipo` |

```bash
flutter build web --dart-define=APP_FLAVOR=equipo --release
```

### iOS (pendiente)

Dos bundle IDs en Xcode:

- `app.foody.cliente`
- `app.foody.equipo`

## Firebase / FCM

Proyecto `foody-pin2`, **dos apps** por plataforma móvil:

| Flavor | Android / iOS package | Dart options | google-services.json |
|--------|----------------------|--------------|----------------------|
| cliente | `app.foody.cliente` | `lib/firebase_options_cliente.dart` | `android/app/src/cliente/` |
| equipo | `app.foody.equipo` | `lib/firebase_options_equipo.dart` | `android/app/src/equipo/` |

Inicialización: `lib/core/firebase/firebase_inicializador.dart` (elige archivo según `AppFlavor.actual`).

Regenerar (desde raíz del proyecto):

```bash
dart pub global run flutterfire_cli:flutterfire configure --project=foody-pin2 --yes \
  --platforms=android,ios,web,windows \
  --android-package-name=app.foody.cliente --ios-bundle-id=app.foody.cliente \
  --android-out=android/app/src/cliente/google-services.json \
  --out=lib/firebase_options_cliente.dart -f

dart pub global run flutterfire_cli:flutterfire configure --project=foody-pin2 --yes \
  --platforms=android,ios \
  --android-package-name=app.foody.equipo --ios-bundle-id=app.foody.equipo \
  --android-out=android/app/src/equipo/google-services.json \
  --out=lib/firebase_options_equipo.dart -f
```

Build release:

```powershell
.\scripts\flutter-build-flavor.ps1 -Flavor cliente
.\scripts\flutter-build-flavor.ps1 -Flavor equipo
```

## Backend

Un solo API NestJS. La variante solo limita **qué rutas Flutter** están disponibles al abrir la app; permisos reales = JWT + rol.

## MEMORIA.md

Los `main_cliente.dart` / `main_domiciliario.dart` de la guía maestra se reemplazan por **`main.dart` + `APP_FLAVOR`**, sin repos duplicados (`foody-mismo-repositorio.mdc`).
