# Arquitectura técnica — Foody
## Documento de referencia para desarrollo

---

## Visión general

Foody es una plataforma SaaS multi-restaurante. Varios restaurantes se registran
y cada uno gestiona sus sucursales de forma independiente. Los datos de cada
sucursal están completamente aislados por `sucursal_id` en todas las tablas.

---

## Stack completo

| Capa | Tecnología | Razón |
|---|---|---|
| Apps cliente/admin | Flutter (Dart) | Una base de código, múltiples apps |
| Backend API | NestJS + TypeScript | Módular, escalable, decoradores limpios |
| Base de datos | PostgreSQL (Supabase self-hosted) | Relaciones complejas, transacciones |
| Auth | Supabase Auth | JWT, roles, RLS integrado |
| Tiempo real | Supabase Realtime | Incluido, sin infraestructura extra |
| Storage | Supabase Storage | Imágenes y documentos centralizados |
| Push notifications | Firebase FCM | Estándar de industria, gratis |
| Impresión | Python + python-escpos | Control directo de impresoras térmicas |
| Contenedores | Docker + Docker Compose | Entorno reproducible local y VPS |
| VPS producción | Ubuntu 22.04 | Estable, amplio soporte |
| Proxy inverso | Nginx | SSL, balanceo, archivos estáticos |

---

## Estructura de proyectos

```
foody/
├── foody_backend/          # NestJS API
├── foody_flutter/          # Flutter (todas las apps)
├── foody_python_printer/   # Servidor Python de impresión
├── foody_supabase/         # Migraciones SQL y config Supabase
└── docker-compose.yml      # Orquestación completa
```

---

## Estructura detallada del backend (NestJS)

```
foody_backend/
├── src/
│   ├── main.ts
│   ├── app.module.ts
│   ├── core/
│   │   ├── base de datos/          # Conexión Supabase/PostgreSQL
│   │   ├── autenticacion/          # Guards, estrategias JWT
│   │   ├── tiempo-real/            # Gateway Supabase Realtime
│   │   ├── notificaciones/         # Servicio FCM
│   │   └── impresion/              # Cliente WebSocket → servidor Python
│   ├── modulos/
│   │   ├── ciudades/
│   │   ├── restaurantes/
│   │   ├── sucursales/
│   │   ├── usuarios/
│   │   ├── productos/
│   │   ├── categorias/
│   │   ├── toppings/
│   │   ├── bebidas/
│   │   ├── combos/
│   │   ├── promociones/            # estados_promociones
│   │   ├── mesas/
│   │   ├── pedidos/                # Módulo más crítico
│   │   ├── cocinas/
│   │   ├── impresoras/
│   │   ├── inventario/
│   │   ├── domiciliarios/
│   │   ├── ofertas-pedido/         # Despacho automático
│   │   ├── caja/
│   │   ├── facturas/
│   │   ├── reportes/
│   │   └── auditoria/
│   └── compartido/
│       ├── decoradores/
│       ├── filtros/                # Manejo global de errores
│       ├── interceptores/
│       └── utilidades/
├── test/
├── .env
├── .env.example
├── docker-compose.yml
└── Dockerfile
```

---

## Estructura detallada Flutter

```
foody_flutter/
├── lib/
│   ├── main_cliente.dart           # Entry point app cliente
│   ├── main_admin.dart             # Entry point app admin
│   ├── main_cocina.dart            # Entry point app cocina
│   ├── main_domiciliario.dart      # Entry point app domiciliarios
│   ├── core/
│   │   ├── constantes/
│   │   │   ├── colores.dart        # #FF6B35, #2EC4B6, etc.
│   │   │   ├── rutas.dart          # Todas las rutas GoRouter
│   │   │   └── configuracion.dart  # URLs base, timeouts
│   │   ├── tema/
│   │   │   ├── tema_foody.dart     # ThemeData completo
│   │   │   └── tipografia.dart     # Poppins + Inter
│   │   ├── red/
│   │   │   ├── cliente_dio.dart    # Dio configurado con interceptores
│   │   │   └── interceptor_auth.dart
│   │   ├── almacenamiento/
│   │   │   └── preferencias.dart   # SharedPreferences (device_id, datos cliente)
│   │   └── errores/
│   │       └── manejador_errores.dart
│   ├── features/
│   │   ├── splash/
│   │   ├── ciudades/
│   │   ├── restaurantes/
│   │   ├── menu/
│   │   ├── carrito/
│   │   ├── checkout/
│   │   ├── pedido_seguimiento/
│   │   ├── auth/                   # Solo para usuarios internos
│   │   ├── admin_productos/
│   │   ├── admin_inventario/
│   │   ├── admin_caja/
│   │   ├── admin_reportes/
│   │   ├── admin_mesas/
│   │   ├── admin_domiciliarios/
│   │   ├── mesero_mesas/
│   │   ├── cocina_tickets/
│   │   └── domiciliario_pedidos/
│   └── compartido/
│       ├── widgets/
│       │   ├── boton_primario.dart
│       │   ├── tarjeta_producto.dart
│       │   ├── indicador_carga.dart
│       │   ├── estado_vacio.dart
│       │   └── error_widget.dart
│       ├── modelos/
│       └── proveedores/            # Riverpod providers compartidos
├── assets/
│   ├── imagenes/
│   ├── iconos/
│   └── fuentes/                    # Poppins, Inter
└── pubspec.yaml
```

---

## Estructura del servidor Python (impresión)

```
foody_python_printer/
├── main.py                 # Entry point, conecta WebSocket al backend
├── cola_impresion.py       # Cola local SQLite para reintentos
├── manejador_impresora.py  # python-escpos, formato de tickets
├── config.py               # URL backend, configuración impresoras
├── requirements.txt
└── foody_printer.db        # SQLite local para cola (se crea automático)
```

---

## Flujo de comunicación entre capas

```
[Flutter Cliente]
      ↓ HTTP (Dio)
[Backend NestJS — VPS]
      ↓ PostgreSQL driver
[Supabase self-hosted — PostgreSQL]
      ↓ Supabase Realtime (broadcast)
[Flutter Admin / Cocina / Mesero] ← escuchan cambios en tiempo real

[Backend NestJS]
      ↓ WebSocket
[Servidor Python — red local del negocio]
      ↓ USB / Red local
[Impresoras térmicas]

[Backend NestJS]
      ↓ HTTP
[Firebase FCM]
      ↓ Push
[Todos los dispositivos Flutter]
```

---

## Variables de entorno del backend (.env)

```env
# Supabase
SUPABASE_URL=http://localhost:8000
SUPABASE_SERVICE_KEY=tu_service_key
DATABASE_URL=postgresql://postgres:password@localhost:5432/postgres

# JWT
JWT_SECRET=clave_muy_larga_y_segura
JWT_EXPIRACION=7d

# Firebase FCM
FIREBASE_PROJECT_ID=foody-app
FIREBASE_PRIVATE_KEY=...
FIREBASE_CLIENT_EMAIL=...

# Puerto
PUERTO=3000
ENTORNO=desarrollo

# Impresión
WEBSOCKET_IMPRESION_PUERTO=3001

# Facturación (cuando se conecte)
PROVEEDOR_FE=factus
FACTUS_API_KEY=
FACTUS_API_URL=
```

---

## Variables de entorno Flutter

```dart
// lib/core/constantes/configuracion.dart
class Configuracion {
  static const String urlBackend = 'http://localhost:3000/api/v1';
  static const String urlSupabase = 'http://localhost:8000';
  static const String supabaseAnonKey = 'tu_anon_key';
  static const Duration timeoutConexion = Duration(seconds: 10);
  static const Duration timeoutRespuesta = Duration(seconds: 30);
}
```

---

## Convenciones de código

### Nombres
- Clases: PascalCase → `ServicioPedidos`, `ControladorCaja`
- Variables y funciones: camelCase → `confirmarPedido()`, `totalCalculado`
- Constantes: SCREAMING_SNAKE_CASE → `TIEMPO_EXPIRACION_OFERTA`
- Archivos: snake_case → `servicio_pedidos.dart`, `pedidos.service.ts`
- Tablas BD: snake_case → `pedido_items`, `movimientos_caja`

### Respuestas del backend
```typescript
// Éxito
{ exito: true, datos: { ... }, mensaje: "Pedido confirmado exitosamente" }

// Error
{ exito: false, error: "STOCK_INSUFICIENTE", mensaje: "No hay suficiente papa para esta salchipapa" }
```

### Manejo de errores en Flutter
```dart
// Todo endpoint usa try/catch y devuelve Either<Falla, Datos>
// Nunca dejar errores sin capturar
// Siempre mostrar mensaje al usuario en español
```

---

## Docker Compose local (desarrollo)

```yaml
version: '3.8'
services:
  backend:
    build: ./foody_backend
    ports:
      - "3000:3000"
      - "3001:3001"
    env_file: ./foody_backend/.env
    depends_on:
      - supabase-db

  # Supabase self-hosted se configura con su propio docker-compose
  # Ver: https://supabase.com/docs/guides/self-hosting/docker
```

---

## Row Level Security (RLS) en Supabase

Reglas base que se aplican a todas las tablas con `sucursal_id`:
- Un usuario autenticado solo puede leer/escribir datos de su propia sucursal
- El `super_admin` puede acceder a cualquier sucursal
- Las policies se definen en las migraciones SQL
- Flutter nunca accede directo a Supabase para operaciones críticas (pasa por backend)
- Flutter SÍ puede acceder directo a Supabase Storage para subir imágenes

---

## Actualización — Tres dashboards y flujo de login

### Entry points Flutter (actualizados)

```
foody_flutter/lib/
  ├── main_cliente.dart        → App pública sin login
  └── main_admin.dart          → Login único que redirige según rol:
                                   - super_admin       → PanelFoodyScreen
                                   - domiciliario_planta → DashboardDomiciliarioScreen
                                   - cualquier otro    → PanelRestauranteScreen
```

### Estructura de carpetas nuevas en Flutter

```
foody_flutter/lib/features/
  ├── auth/
  │   ├── presentation/
  │   │   └── login_screen.dart          → Pantalla única de login
  │   └── domain/
  │       └── redireccionador_rol.dart   → Switch que navega según dashboard
  │
  ├── super_admin/                        → Panel Foody (solo super_admin)
  │   ├── ciudades/
  │   ├── restaurantes/
  │   ├── suscripciones/
  │   ├── usuarios_globales/
  │   ├── configuracion_global/
  │   └── estadisticas_globales/
  │
  ├── domiciliario_planta/               → Dashboard domiciliario
  │   ├── pedidos_asignados/
  │   ├── historial/
  │   ├── estadisticas/
  │   └── perfil/
  │
  └── panel_restaurante/                 → Panel interno del restaurante
      ├── dashboard/
      ├── pedidos_kanban/
      ├── menu_productos/
      ├── inventario/
      ├── mesas/
      ├── cocinas/
      ├── caja/
      ├── domiciliarios/
      ├── reportes/
      ├── alertas/
      ├── usuarios_sucursal/
      ├── sucursales/
      └── configuracion/
```

### Módulos NestJS nuevos

```
foody_backend/src/modulos/
  ├── super-admin/
  │   ├── ciudades/
  │   ├── restaurantes/
  │   ├── suscripciones/
  │   ├── usuarios-globales/
  │   └── configuracion-global/
  └── domiciliario-planta/
      ├── pedidos-asignados/
      └── estadisticas/
```

### Guard de super_admin en NestJS

```typescript
// Todos los endpoints /super/* tienen este guard
@UseGuards(JwtAuthGuard, SuperAdminGuard)

// SuperAdminGuard verifica:
// 1. Token válido
// 2. rol === 'super_admin'
// Si no cumple → 403 SUPER_ADMIN_REQUERIDO
```

### Guard de suscripción activa

```typescript
// Todos los endpoints del restaurante tienen este guard adicional
@UseGuards(JwtAuthGuard, RolGuard, SuscripcionActivaGuard)

// SuscripcionActivaGuard verifica:
// 1. Obtiene restaurante_id del usuario
// 2. Consulta suscripciones_restaurante
// 3. Si estado = 'bloqueada' o 'vencida' → 403 RESTAURANTE_BLOQUEADO
// 4. Si activa o prueba → continúa
```

### Construcción dinámica del menú en Flutter

```dart
// PanelRestauranteScreen recibe la lista de permisos del token
// y construye solo las pestañas permitidas

class MenuDinamico {
  static List<TabItem> construir(List<String> permisos) {
    final tabs = <TabItem>[];

    if (permisos.contains('ver_dashboard'))
      tabs.add(TabItem(icono: Icons.dashboard, label: 'Dashboard', ruta: '/dashboard'));
    if (permisos.contains('ver_pedidos'))
      tabs.add(TabItem(icono: Icons.receipt, label: 'Pedidos', ruta: '/pedidos'));
    if (permisos.contains('editar_productos'))
      tabs.add(TabItem(icono: Icons.restaurant_menu, label: 'Menú', ruta: '/menu'));
    if (permisos.contains('editar_stock'))
      tabs.add(TabItem(icono: Icons.inventory, label: 'Inventario', ruta: '/inventario'));
    if (permisos.contains('ver_caja'))
      tabs.add(TabItem(icono: Icons.point_of_sale, label: 'Caja', ruta: '/caja'));
    // ... y así por cada permiso

    return tabs;
  }
}
```
