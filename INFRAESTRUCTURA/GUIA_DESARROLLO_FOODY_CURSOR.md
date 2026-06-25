# GUÍA MAESTRA DE DESARROLLO — FOODY
## Documento de instrucciones para Cursor AI
### Paso a paso completo desde cero hasta producción

> **INSTRUCCIÓN PARA CURSOR:** Este documento es la guía definitiva del proyecto Foody.
> Léelo completo antes de escribir una sola línea de código. Cada decisión de arquitectura,
> nombre de variable, estructura de carpetas y flujo de datos ya está definido aquí.
> No improvises. No inventes nombres. No cambies el stack. Sigue esta guía al pie de la letra.

---

## CONTEXTO DEL PROYECTO

Foody es una plataforma SaaS multi-restaurante. Varios restaurantes se registran
y cada uno gestiona sus sucursales de forma independiente. Los datos de cada
sucursal están completamente aislados por `sucursal_id` en TODAS las tablas.

**Stack definitivo (no negociable):**
- Apps: Flutter (Dart) — una base de código, múltiples entry points
- Backend: NestJS + TypeScript
- Base de datos: PostgreSQL via Supabase self-hosted
- Auth: Supabase Auth con JWT
- Tiempo real: Supabase Realtime
- Storage: Supabase Storage
- Push notifications: Firebase FCM
- Impresión: Python + python-escpos (servidor local en el negocio)
- Contenedores: Docker + Docker Compose

**Base de referencia:** El proyecto Tu Cancha Fácil (canchas sintéticas) tiene
patrones reutilizables: providers con Riverpod, modelos Dart, servicios de auth,
estructura de carpetas, manejo de SharedPreferences. Usar como referencia de
estructura y patrones, adaptando nomenclatura y lógica a Foody.

---

## REGLAS ABSOLUTAS — NUNCA VIOLAR

```
1. Flutter NUNCA calcula totales, precios, descuentos ni IVA.
   Solo el backend NestJS calcula y valida. Flutter solo muestra.

2. Flutter NUNCA escribe directamente a Supabase para operaciones críticas.
   Toda escritura pasa por el backend (excepto Storage para subir imágenes).

3. Toda confirmación de pedido es una transacción PostgreSQL atómica.
   Si un solo paso falla, TODO se revierte. BEGIN/COMMIT/ROLLBACK.

4. El stock se descuenta SIEMPRE al confirmar el pedido, no al entregarlo.
   En la misma transacción, nunca separado.

5. auditoria_logs es inmutable. Solo INSERT. Nunca UPDATE ni DELETE.

6. Las impresoras NUNCA reciben órdenes desde Flutter.
   Solo el servidor Python local en la red del negocio.

7. Cada query de datos de sucursal DEBE incluir WHERE sucursal_id = X.
   Sin excepción. Siempre.

8. Los precios en pedido_items se copian al momento del pedido.
   No se referencian del producto original.

9. Los clientes consumidores NO tienen login ni fila en tabla usuarios.
   Se identifican por device_id en dispositivos_cliente.

10. El IVA va incluido en el precio del menú. El cliente ve precio final.
    El desglose solo aparece en la factura electrónica.
```

---

## VARIABLES GLOBALES — COLORES Y CONFIGURACIÓN

```dart
// Colores Foody (copiar exacto)
colorPrimario   = #FF6B35   // naranja vibrante
colorSecundario = #2EC4B6   // turquesa
colorAcento     = #FFE66D   // amarillo
colorFondo      = #FAFAFA
colorTexto      = #1A1A2E
colorError      = #E63946
colorExito      = #2DC653

// URLs (desarrollo)
urlBackend  = 'http://localhost:3000/api/v1'
urlSupabase = 'http://localhost:8000'

// Timeouts
timeoutConexion  = 10 segundos
timeoutRespuesta = 30 segundos

// Tipografía
fuente principal = Poppins
fuente secundaria = Inter
```

---

## ESTRUCTURA COMPLETA DEL REPOSITORIO

```
foody/
├── foody_backend/              ← NestJS API
├── foody_flutter/              ← Flutter (todas las apps)
├── foody_python_printer/       ← Servidor Python de impresión
├── foody_supabase/             ← Migraciones SQL
│   └── migrations/
│       ├── 001_geografia.sql
│       ├── 002_usuarios.sql
│       ├── 003_dispositivos.sql
│       ├── 004_catalogo.sql
│       ├── 005_pedidos.sql
│       ├── 006_cocinas.sql
│       ├── 007_inventario.sql
│       ├── 008_caja.sql
│       ├── 009_domiciliarios.sql
│       ├── 010_facturacion.sql
│       ├── 011_reportes.sql
│       ├── 012_auditoria.sql
│       ├── 013_promociones.sql
│       ├── 014_super_admin.sql
│       └── 015_rls_policies.sql
└── docker-compose.yml
```

---

# FASE 0 — CONFIGURACIÓN INICIAL DEL ENTORNO

## Paso 0.1 — Crear estructura de carpetas del repositorio

```bash
mkdir foody
cd foody
mkdir foody_backend foody_flutter foody_python_printer foody_supabase
mkdir foody_supabase/migrations
```

## Paso 0.2 — Crear docker-compose.yml raíz

Crear `foody/docker-compose.yml`:

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
      - db
    restart: unless-stopped

  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: foody_password_dev
      POSTGRES_DB: foody_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## Paso 0.3 — Inicializar proyecto NestJS

```bash
cd foody_backend
npm i -g @nestjs/cli
nest new . --skip-git
npm install @nestjs/config @nestjs/jwt @nestjs/passport
npm install passport passport-jwt bcrypt
npm install @supabase/supabase-js pg
npm install class-validator class-transformer
npm install @nestjs/websockets @nestjs/platform-socket.io socket.io
npm install firebase-admin
npm install uuid
npm install @types/bcrypt @types/passport-jwt --save-dev
```

## Paso 0.4 — Crear .env del backend

Crear `foody_backend/.env`:

```env
# Base de datos
DATABASE_URL=postgresql://postgres:foody_password_dev@localhost:5432/foody_db

# Supabase
SUPABASE_URL=http://localhost:8000
SUPABASE_SERVICE_KEY=tu_service_key_aqui
SUPABASE_ANON_KEY=tu_anon_key_aqui

# JWT
JWT_SECRET=foody_jwt_secret_muy_largo_y_seguro_cambiar_en_produccion
JWT_EXPIRACION=7d

# Firebase FCM
FIREBASE_PROJECT_ID=foody-app
FIREBASE_PRIVATE_KEY=
FIREBASE_CLIENT_EMAIL=

# Servidor
PUERTO=3000
ENTORNO=desarrollo
WEBSOCKET_IMPRESION_PUERTO=3001
```

## Paso 0.5 — Crear .env.example (igual pero sin valores reales)

Copiar .env pero vaciar todos los valores. Commitear solo .env.example. NUNCA .env.

## Paso 0.6 — Crear Dockerfile del backend

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 3000 3001
CMD ["node", "dist/main"]
```

## Paso 0.7 — Inicializar proyecto Flutter

```bash
cd foody_flutter
flutter create . --org com.foody --platforms android,ios
```

Agregar dependencias en `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # Estado
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.4
  # Navegación
  go_router: ^13.2.0
  # HTTP
  dio: ^5.4.3
  # Storage local
  shared_preferences: ^2.2.3
  # Supabase
  supabase_flutter: ^2.5.0
  # Firebase
  firebase_core: ^2.30.1
  firebase_messaging: ^14.9.1
  # Imágenes
  cached_network_image: ^3.3.1
  image_picker: ^1.1.1
  # Mapas
  google_maps_flutter: ^2.6.0
  # UI utilidades
  flutter_svg: ^2.0.10
  shimmer: ^3.0.0
  lottie: ^3.1.0
  intl: ^0.19.0
  # QR
  qr_flutter: ^4.1.0
  mobile_scanner: ^5.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.0
  flutter_lints: ^3.0.1

flutter:
  uses-material-design: true
  assets:
    - assets/imagenes/
    - assets/iconos/
    - assets/fuentes/
  fonts:
    - family: Poppins
      fonts:
        - asset: assets/fuentes/Poppins-Regular.ttf
        - asset: assets/fuentes/Poppins-Medium.ttf
          weight: 500
        - asset: assets/fuentes/Poppins-SemiBold.ttf
          weight: 600
        - asset: assets/fuentes/Poppins-Bold.ttf
          weight: 700
    - family: Inter
      fonts:
        - asset: assets/fuentes/Inter-Regular.ttf
        - asset: assets/fuentes/Inter-Medium.ttf
          weight: 500
```

---

# FASE 1 — BASE DE DATOS (MIGRACIONES SQL)

Crear cada archivo en `foody_supabase/migrations/` en el orden indicado.
Ejecutar en PostgreSQL en el mismo orden.

## Paso 1.1 — Migración 001: Geografía y acceso

Archivo: `001_geografia.sql`

```sql
-- Habilitar extensión UUID
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- CIUDADES
CREATE TABLE ciudades (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre text NOT NULL,
  slug text UNIQUE NOT NULL,
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- RESTAURANTES
CREATE TABLE restaurantes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ciudad_id uuid REFERENCES ciudades(id),
  nombre text NOT NULL,
  descripcion text,
  logo_url text,
  banner_url text,
  telefono text,
  activo bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- SUCURSALES
CREATE TABLE sucursales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurante_id uuid REFERENCES restaurantes(id),
  ciudad_id uuid REFERENCES ciudades(id),
  nombre text NOT NULL,
  direccion text,
  telefono text,
  lat numeric(10,7),
  lng numeric(10,7),
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- ZONAS DE COBERTURA
CREATE TABLE zonas_cobertura (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text,
  costo_domicilio numeric(12,2) NOT NULL,
  distancia_max_km numeric NOT NULL,
  poligono jsonb,
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- HORARIOS DE SUCURSAL
CREATE TABLE horarios_sucursal (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  dia_semana int NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
  hora_apertura time NOT NULL,
  hora_cierre time NOT NULL,
  activo bool DEFAULT true
);
```

## Paso 1.2 — Migración 002: Usuarios, roles y permisos

Archivo: `002_usuarios.sql`

```sql
-- USUARIOS (personal interno — clientes NO van aquí)
CREATE TABLE usuarios (
  id uuid PRIMARY KEY,  -- mismo UUID de Supabase Auth
  sucursal_id uuid REFERENCES sucursales(id),
  restaurante_id uuid REFERENCES restaurantes(id),
  nombre text NOT NULL,
  email text UNIQUE NOT NULL,
  telefono text,
  foto_url text,
  rol text NOT NULL,  -- super_admin, admin, gerente, cajero, mesero, cocina_X, domiciliario_planta, inventario
  activo bool DEFAULT true,
  ultimo_acceso timestamptz,
  created_at timestamptz DEFAULT now()
);

-- ROLES Y PERMISOS
CREATE TABLE roles_permisos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rol text NOT NULL,
  permiso text NOT NULL,
  UNIQUE(rol, permiso)
);

-- Insertar permisos por defecto
INSERT INTO roles_permisos (rol, permiso) VALUES
  ('admin', 'ver_dashboard'),
  ('admin', 'ver_pedidos'),
  ('admin', 'crear_pedido'),
  ('admin', 'cancelar_pedido'),
  ('admin', 'editar_productos'),
  ('admin', 'editar_stock'),
  ('admin', 'ver_caja'),
  ('admin', 'abrir_caja'),
  ('admin', 'cerrar_caja'),
  ('admin', 'hacer_retiro_parcial'),
  ('admin', 'aplicar_descuento'),
  ('admin', 'ver_reportes'),
  ('admin', 'ver_alertas'),
  ('admin', 'gestionar_usuarios'),
  ('admin', 'gestionar_sucursales'),
  ('admin', 'gestionar_mesas'),
  ('admin', 'gestionar_domiciliarios'),
  ('admin', 'ver_inventario'),
  ('admin', 'editar_inventario'),
  ('gerente', 'ver_dashboard'),
  ('gerente', 'ver_pedidos'),
  ('gerente', 'crear_pedido'),
  ('gerente', 'cancelar_pedido'),
  ('gerente', 'editar_productos'),
  ('gerente', 'editar_stock'),
  ('gerente', 'ver_caja'),
  ('gerente', 'abrir_caja'),
  ('gerente', 'cerrar_caja'),
  ('gerente', 'aplicar_descuento'),
  ('gerente', 'ver_reportes'),
  ('gerente', 'ver_alertas'),
  ('gerente', 'gestionar_mesas'),
  ('gerente', 'ver_inventario'),
  ('gerente', 'editar_inventario'),
  ('cajero', 'ver_pedidos'),
  ('cajero', 'crear_pedido'),
  ('cajero', 'ver_caja'),
  ('cajero', 'abrir_caja'),
  ('cajero', 'cerrar_caja'),
  ('cajero', 'ver_reportes'),
  ('mesero', 'ver_pedidos'),
  ('mesero', 'gestionar_mesas'),
  ('mesero', 'aprobar_pedido_mesa');
```

## Paso 1.3 — Migración 003: Dispositivos y notificaciones

Archivo: `003_dispositivos.sql`

```sql
-- DISPOSITIVOS CLIENTE (para clientes sin login)
CREATE TABLE dispositivos_cliente (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id text UNIQUE NOT NULL,
  fcm_token text,
  ciudad_id uuid REFERENCES ciudades(id),
  nombre_opcional text,
  telefono_opcional text,
  plataforma text CHECK (plataforma IN ('android', 'ios', 'web')),
  ultimo_acceso timestamptz,
  created_at timestamptz DEFAULT now()
);

-- TOKENS PUSH PARA ADMIN/STAFF
CREATE TABLE tokens_push_admin (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid REFERENCES usuarios(id),
  fcm_token text NOT NULL,
  plataforma text,
  activo bool DEFAULT true,
  updated_at timestamptz DEFAULT now()
);
```

## Paso 1.4 — Migración 004: Catálogo y menú

Archivo: `004_catalogo.sql`

```sql
-- COCINAS (antes del catálogo porque productos las referencian)
CREATE TABLE cocinas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- IMPRESORAS
CREATE TABLE impresoras (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  cocina_id uuid REFERENCES cocinas(id),
  nombre text NOT NULL,
  ip_local text,
  tipo text DEFAULT 'termica',
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- CATEGORÍAS
CREATE TABLE categorias (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  imagen_url text,
  orden int DEFAULT 0,
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- PRODUCTOS
CREATE TABLE productos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  categoria_id uuid REFERENCES categorias(id),
  cocina_id uuid REFERENCES cocinas(id),
  nombre text NOT NULL,
  descripcion text,
  precio numeric(12,2) NOT NULL,
  precio_sugerido numeric(12,2),
  costo_calculado numeric(12,2),
  imagen_url text,
  disponible bool DEFAULT true,
  es_encargo bool DEFAULT false,
  orden int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- TOPPINGS
CREATE TABLE toppings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  precio numeric(12,2) DEFAULT 0,
  disponible bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- TOPPINGS DISPONIBLES POR PRODUCTO
CREATE TABLE producto_toppings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id uuid REFERENCES productos(id),
  topping_id uuid REFERENCES toppings(id),
  UNIQUE(producto_id, topping_id)
);

-- BEBIDAS
CREATE TABLE bebidas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  precio numeric(12,2) NOT NULL,
  disponible bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- BEBIDAS DISPONIBLES POR PRODUCTO
CREATE TABLE producto_bebidas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id uuid REFERENCES productos(id),
  bebida_id uuid REFERENCES bebidas(id),
  UNIQUE(producto_id, bebida_id)
);

-- COMBOS
CREATE TABLE combos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  descripcion text,
  precio_fijo numeric(12,2) NOT NULL,
  imagen_url text,
  disponible bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- ÍTEMS DE COMBO
CREATE TABLE combo_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  combo_id uuid REFERENCES combos(id),
  tipo_item text NOT NULL CHECK (tipo_item IN ('producto', 'bebida', 'topping')),
  item_id uuid NOT NULL,
  cantidad int DEFAULT 1
);
```

## Paso 1.5 — Migración 005: Pedidos

Archivo: `005_pedidos.sql`

```sql
-- MESAS
CREATE TABLE mesas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  qr_token text UNIQUE NOT NULL DEFAULT gen_random_uuid()::text,
  activa bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- PEDIDOS
CREATE TABLE pedidos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  mesa_id uuid REFERENCES mesas(id),
  device_id text REFERENCES dispositivos_cliente(device_id),
  cajero_id uuid REFERENCES usuarios(id),
  numero_pedido text NOT NULL,
  tipo text NOT NULL CHECK (tipo IN ('mesa', 'para_llevar', 'domicilio', 'encargo')),
  estado text NOT NULL DEFAULT 'pendiente',
  cliente_nombre text,
  cliente_telefono text,
  direccion_entrega text,
  lat numeric(10,7),
  lng numeric(10,7),
  metodo_pago text CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'transferencia', 'nequi', 'pendiente')),
  subtotal numeric(12,2) NOT NULL DEFAULT 0,
  costo_domicilio numeric(12,2) DEFAULT 0,
  descuento numeric(12,2) DEFAULT 0,
  motivo_descuento text,
  total numeric(12,2) NOT NULL DEFAULT 0,
  requiere_factura bool DEFAULT false,
  observaciones text,
  tiempo_estimado_minutos int,
  created_at timestamptz DEFAULT now()
);

-- ÍNDICES CRÍTICOS
CREATE INDEX idx_pedidos_sucursal_estado ON pedidos(sucursal_id, estado);
CREATE INDEX idx_pedidos_sucursal_created ON pedidos(sucursal_id, created_at DESC);

-- HISTORIAL DE ESTADOS DEL PEDIDO
CREATE TABLE estados_pedido_historial (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid REFERENCES pedidos(id),
  estado_anterior text,
  estado_nuevo text NOT NULL,
  usuario_id uuid REFERENCES usuarios(id),
  motivo text,
  duracion_estado_anterior_seg int,
  fecha timestamptz DEFAULT now()
);

-- ÍTEMS DEL PEDIDO
CREATE TABLE pedido_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid REFERENCES pedidos(id),
  producto_id uuid REFERENCES productos(id),
  cocina_id uuid REFERENCES cocinas(id),
  cantidad int NOT NULL,
  precio_unitario numeric(12,2) NOT NULL,  -- precio al momento del pedido
  costo_unitario numeric(12,2),            -- costo al momento del pedido
  observaciones text,
  estado_cocina text DEFAULT 'pendiente' CHECK (estado_cocina IN ('pendiente', 'preparando', 'listo')),
  created_at timestamptz DEFAULT now()
);

-- TOPPINGS DE CADA ÍTEM
CREATE TABLE pedido_item_toppings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_item_id uuid REFERENCES pedido_items(id),
  topping_id uuid REFERENCES toppings(id),
  nombre_topping text NOT NULL,  -- copia al momento
  precio_topping numeric(12,2) NOT NULL  -- precio al momento
);

-- BEBIDAS DE CADA ÍTEM
CREATE TABLE pedido_item_bebidas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_item_id uuid REFERENCES pedido_items(id),
  bebida_id uuid REFERENCES bebidas(id),
  nombre_bebida text NOT NULL,  -- copia al momento
  precio_bebida numeric(12,2) NOT NULL,  -- precio al momento
  cantidad int DEFAULT 1
);

-- SELECCIONES DE COMBO EN PEDIDO
CREATE TABLE pedido_combo_selecciones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_item_id uuid REFERENCES pedido_items(id),
  combo_id uuid REFERENCES combos(id),
  nombre_combo text NOT NULL,
  precio_combo numeric(12,2) NOT NULL
);

-- TRANSFERENCIAS DE MESA (auditado)
CREATE TABLE transferencias_mesa (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid REFERENCES pedidos(id),
  mesa_origen_id uuid REFERENCES mesas(id),
  mesa_destino_id uuid REFERENCES mesas(id),
  usuario_id uuid REFERENCES usuarios(id),
  motivo text,
  created_at timestamptz DEFAULT now()
);

-- MÁRGENES DE VENTA (foto histórica de margen por venta)
CREATE TABLE margenes_venta (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid REFERENCES pedidos(id),
  pedido_item_id uuid REFERENCES pedido_items(id),
  sucursal_id uuid REFERENCES sucursales(id),
  precio_venta numeric(12,2) NOT NULL,
  costo_al_momento numeric(12,2) NOT NULL,
  margen_porcentaje numeric(5,2),
  created_at timestamptz DEFAULT now()
);
```

## Paso 1.6 — Migración 006: Inventario completo

Archivo: `006_inventario.sql`

```sql
-- INGREDIENTES
CREATE TABLE ingredientes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  unidad_base text NOT NULL,  -- 'gramo', 'ml', 'pieza'
  tipo_costeo text NOT NULL CHECK (tipo_costeo IN ('peso', 'pieza', 'rendimiento', 'produccion')),
  rendimiento_porcentaje numeric(5,2) DEFAULT 100,
  stock_actual numeric(12,3) DEFAULT 0,
  stock_minimo numeric(12,3) DEFAULT 0,
  costo_unitario_actual numeric(12,4) DEFAULT 0,  -- costo por unidad base
  activo bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- PRESENTACIONES DE COMPRA
CREATE TABLE presentaciones_compra (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ingrediente_id uuid REFERENCES ingredientes(id),
  nombre text NOT NULL,
  cantidad_unidades_base numeric(12,3) NOT NULL,  -- 1 saco = 25000 gramos
  activa bool DEFAULT true
);

-- COMPRAS DE INVENTARIO
CREATE TABLE compras_inventario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  usuario_id uuid REFERENCES usuarios(id),
  proveedor text,
  total_compra numeric(12,2) NOT NULL,
  fecha_compra timestamptz DEFAULT now(),
  observaciones text,
  created_at timestamptz DEFAULT now()
);

-- ÍTEMS DE COMPRA
CREATE TABLE compra_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  compra_id uuid REFERENCES compras_inventario(id),
  ingrediente_id uuid REFERENCES ingredientes(id),
  presentacion_id uuid REFERENCES presentaciones_compra(id),
  cantidad_presentaciones numeric(12,3) NOT NULL,
  precio_presentacion numeric(12,2) NOT NULL,
  cantidad_unidades_base numeric(12,3) NOT NULL,  -- calculado
  costo_unitario_base numeric(12,4) NOT NULL       -- calculado
);

-- MOVIMIENTOS DE INGREDIENTE (trazabilidad completa)
CREATE TABLE movimientos_ingrediente (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  ingrediente_id uuid REFERENCES ingredientes(id),
  pedido_id uuid REFERENCES pedidos(id),
  tipo text NOT NULL CHECK (tipo IN ('compra', 'venta', 'ajuste', 'merma', 'produccion', 'conteo')),
  cantidad numeric(12,3) NOT NULL,  -- positivo = entrada, negativo = salida
  stock_anterior numeric(12,3) NOT NULL,
  stock_posterior numeric(12,3) NOT NULL,
  motivo text,
  usuario_id uuid REFERENCES usuarios(id),
  created_at timestamptz DEFAULT now()
);

-- RECETAS
CREATE TABLE recetas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  nombre text NOT NULL,
  descripcion text,
  rendimiento_porciones int DEFAULT 1,
  created_at timestamptz DEFAULT now()
);

-- ÍTEMS DE RECETA (ingredientes y subrecetas)
CREATE TABLE receta_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receta_id uuid REFERENCES recetas(id),
  tipo_item text NOT NULL CHECK (tipo_item IN ('ingrediente', 'subreceta', 'empaque')),
  ingrediente_id uuid REFERENCES ingredientes(id),
  subreceta_id uuid REFERENCES recetas(id),
  cantidad numeric(12,3) NOT NULL,
  unidad text NOT NULL,
  orden int DEFAULT 0
);

-- COSTOS DE RECETA (calculado automáticamente)
CREATE TABLE costos_receta (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receta_id uuid REFERENCES recetas(id),
  costo_total numeric(12,4) NOT NULL,
  costo_por_porcion numeric(12,4) NOT NULL,
  calculado_at timestamptz DEFAULT now()
);

-- PRODUCTO → RECETA
ALTER TABLE productos ADD COLUMN receta_id uuid REFERENCES recetas(id);

-- AJUSTES DE STOCK MANUALES
CREATE TABLE ajustes_stock (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  ingrediente_id uuid REFERENCES ingredientes(id),
  cantidad_ajuste numeric(12,3) NOT NULL,
  motivo text NOT NULL,
  usuario_id uuid REFERENCES usuarios(id),
  created_at timestamptz DEFAULT now()
);

-- CONTEOS FÍSICOS
CREATE TABLE conteos_inventario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  usuario_id uuid REFERENCES usuarios(id),
  estado text DEFAULT 'en_proceso',
  created_at timestamptz DEFAULT now(),
  cerrado_at timestamptz
);

CREATE TABLE conteo_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conteo_id uuid REFERENCES conteos_inventario(id),
  ingrediente_id uuid REFERENCES ingredientes(id),
  cantidad_teorica numeric(12,3) NOT NULL,
  cantidad_real numeric(12,3) NOT NULL,
  diferencia numeric(12,3) GENERATED ALWAYS AS (cantidad_real - cantidad_teorica) STORED
);
```

## Paso 1.7 — Migración 007: Caja

Archivo: `007_caja.sql`

```sql
-- CAJAS (turnos)
CREATE TABLE cajas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  usuario_apertura_id uuid REFERENCES usuarios(id),
  usuario_cierre_id uuid REFERENCES usuarios(id),
  monto_inicial numeric(12,2) NOT NULL,
  monto_final_contado numeric(12,2),
  monto_final_sistema numeric(12,2),
  diferencia numeric(12,2),
  estado text DEFAULT 'abierta' CHECK (estado IN ('abierta', 'cerrada')),
  apertura_at timestamptz DEFAULT now(),
  cierre_at timestamptz,
  observaciones_cierre text
);

-- MOVIMIENTOS DE CAJA
CREATE TABLE movimientos_caja (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  caja_id uuid REFERENCES cajas(id),
  sucursal_id uuid REFERENCES sucursales(id),
  pedido_id uuid REFERENCES pedidos(id),
  tipo text NOT NULL CHECK (tipo IN ('venta', 'retiro', 'gasto', 'ingreso_extra', 'apertura')),
  monto numeric(12,2) NOT NULL,
  metodo_pago text,
  descripcion text,
  usuario_id uuid REFERENCES usuarios(id),
  created_at timestamptz DEFAULT now()
);

-- GASTOS OPERATIVOS
CREATE TABLE gastos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  caja_id uuid REFERENCES cajas(id),
  concepto text NOT NULL,
  monto numeric(12,2) NOT NULL,
  categoria text,  -- 'insumo', 'servicio', 'nomina', 'otro'
  usuario_id uuid REFERENCES usuarios(id),
  created_at timestamptz DEFAULT now()
);

-- CUENTAS POR COBRAR (fiados)
CREATE TABLE cuentas_por_cobrar (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  pedido_id uuid REFERENCES pedidos(id),
  cliente_nombre text NOT NULL,
  cliente_telefono text,
  monto numeric(12,2) NOT NULL,
  estado text DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'pagada')),
  pagada_at timestamptz,
  usuario_id uuid REFERENCES usuarios(id),
  created_at timestamptz DEFAULT now()
);

-- COSTOS OPERATIVOS FIJOS (para cálculo de punto de equilibrio)
CREATE TABLE costos_operativos_fijos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  concepto text NOT NULL,
  monto_mensual numeric(12,2) NOT NULL,
  activo bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);
```

## Paso 1.8 — Migración 008: Domiciliarios

Archivo: `008_domiciliarios.sql`

```sql
-- DOMICILIARIOS INDEPENDIENTES
CREATE TABLE domiciliarios_independientes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre text NOT NULL,
  email text UNIQUE NOT NULL,
  telefono text,
  foto_url text,
  tipo_vehiculo text,
  placa text,
  ciudad_id uuid REFERENCES ciudades(id),
  estado_cuenta text DEFAULT 'pendiente_verificacion'
    CHECK (estado_cuenta IN ('pendiente_verificacion', 'activo', 'suspendido', 'bloqueado')),
  calificacion_promedio numeric(3,2) DEFAULT 0,
  total_entregas int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- DOCUMENTOS DE DOMICILIARIO
CREATE TABLE documentos_domiciliario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domiciliario_id uuid REFERENCES domiciliarios_independientes(id),
  tipo text NOT NULL,  -- 'cedula_frente', 'cedula_reverso', 'foto_vehiculo', 'seguro'
  url text NOT NULL,
  estado text DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'aprobado', 'rechazado')),
  motivo_rechazo text,
  revisado_por uuid REFERENCES usuarios(id),
  created_at timestamptz DEFAULT now()
);

-- DOMICILIARIOS DE PLANTA (empleados fijos del restaurante)
CREATE TABLE domiciliarios_planta (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid REFERENCES usuarios(id),  -- tiene login de empleado
  sucursal_id uuid REFERENCES sucursales(id),
  activo bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- SESIONES DE DOMICILIARIO INDEPENDIENTE (turno activo)
CREATE TABLE domiciliarios_sesiones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domiciliario_id uuid REFERENCES domiciliarios_independientes(id),
  lat_actual numeric(10,7),
  lng_actual numeric(10,7),
  ciudad_id uuid REFERENCES ciudades(id),
  disponible bool DEFAULT true,
  activa bool DEFAULT true,
  iniciada_at timestamptz DEFAULT now(),
  cerrada_at timestamptz
);

-- OFERTAS DE PEDIDO (dispatch a domiciliario)
CREATE TABLE ofertas_pedido (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid REFERENCES pedidos(id),
  sucursal_id uuid REFERENCES sucursales(id),
  radio_busqueda_km numeric NOT NULL,
  intento_numero int DEFAULT 1,
  estado text DEFAULT 'activa' CHECK (estado IN ('activa', 'aceptada', 'expirada', 'cancelada')),
  expira_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- RESPUESTAS A OFERTAS
CREATE TABLE respuestas_oferta (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oferta_id uuid REFERENCES ofertas_pedido(id),
  domiciliario_id uuid REFERENCES domiciliarios_independientes(id),
  respuesta text CHECK (respuesta IN ('aceptada', 'rechazada', 'no_vio')),
  respondido_at timestamptz DEFAULT now()
);

-- ASIGNACIONES DE DOMICILIO
CREATE TABLE asignaciones_domicilio (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid REFERENCES pedidos(id),
  sucursal_id uuid REFERENCES sucursales(id),
  domiciliario_independiente_id uuid REFERENCES domiciliarios_independientes(id),
  domiciliario_planta_id uuid REFERENCES domiciliarios_planta(id),
  tipo_domiciliario text NOT NULL CHECK (tipo_domiciliario IN ('planta', 'independiente')),
  estado text DEFAULT 'asignado' CHECK (estado IN ('asignado', 'en_camino', 'entregado')),
  asignado_at timestamptz DEFAULT now(),
  entregado_at timestamptz
);

-- HISTORIAL DE UBICACIONES GPS DURANTE ENTREGA
CREATE TABLE domiciliarios_ubicaciones_historial (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asignacion_id uuid REFERENCES asignaciones_domicilio(id),
  lat numeric(10,7) NOT NULL,
  lng numeric(10,7) NOT NULL,
  registrado_at timestamptz DEFAULT now()
);

-- GANANCIAS DEL DOMICILIARIO
CREATE TABLE ganancias_domiciliario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domiciliario_id uuid REFERENCES domiciliarios_independientes(id),
  asignacion_id uuid REFERENCES asignaciones_domicilio(id),
  valor_domicilio numeric(12,2) NOT NULL,
  comision_foody numeric(12,2) NOT NULL,
  ganancia_domiciliario numeric(12,2) NOT NULL,
  pagado bool DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- CALIFICACIONES
CREATE TABLE calificaciones_domiciliario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asignacion_id uuid REFERENCES asignaciones_domicilio(id),
  device_id text REFERENCES dispositivos_cliente(device_id),
  calificacion int CHECK (calificacion BETWEEN 1 AND 5),
  comentario text,
  created_at timestamptz DEFAULT now()
);
```

## Paso 1.9 — Migración 009: Alertas y auditoría

Archivo: `009_alertas_auditoria.sql`

```sql
-- ALERTAS DE RIESGO
CREATE TABLE alertas_riesgo (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  tipo text NOT NULL,
  nivel text NOT NULL CHECK (nivel IN ('bajo', 'medio', 'alto', 'critico')),
  descripcion text NOT NULL,
  referencia_id uuid,
  referencia_tipo text,
  revisada bool DEFAULT false,
  revisada_por uuid REFERENCES usuarios(id),
  revisada_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- AUDITORÍA (INMUTABLE — solo INSERT)
CREATE TABLE auditoria_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  usuario_id uuid REFERENCES usuarios(id),
  accion text NOT NULL,
  tabla_afectada text,
  registro_id uuid,
  datos_antes jsonb,
  datos_despues jsonb,
  ip text,
  created_at timestamptz DEFAULT now()
);

-- Revocar UPDATE y DELETE sobre auditoria_logs
REVOKE UPDATE, DELETE ON auditoria_logs FROM PUBLIC;
```

## Paso 1.10 — Migración 010: Facturación y promociones

Archivo: `010_facturacion_promociones.sql`

```sql
-- CONFIGURACIÓN FISCAL POR SUCURSAL
CREATE TABLE configuracion_fiscal_sucursal (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id) UNIQUE,
  nit text,
  razon_social text,
  regimen text CHECK (regimen IN ('simplificado', 'comun')),
  aplica_iva bool DEFAULT false,
  porcentaje_iva numeric(5,2) DEFAULT 19,
  resolucion_dian text,
  prefijo_factura text,
  consecutivo_actual int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- FACTURAS
CREATE TABLE facturas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  pedido_id uuid REFERENCES pedidos(id),
  numero_factura text,
  nit_cliente text,
  nombre_fiscal_cliente text,
  email_cliente text,
  subtotal numeric(12,2),
  iva numeric(12,2),
  total numeric(12,2),
  estado text DEFAULT 'borrador' CHECK (estado IN ('borrador', 'emitida', 'anulada')),
  pdf_url text,
  emitida_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- PROMOCIONES / ESTADOS (tipo WhatsApp stories)
CREATE TABLE estados_promociones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid REFERENCES sucursales(id),
  titulo text,
  imagen_url text NOT NULL,
  descripcion text,
  activa bool DEFAULT true,
  expira_at timestamptz,
  vistas int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- VISTAS DE PROMOCIÓN
CREATE TABLE promocion_vistas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  promocion_id uuid REFERENCES estados_promociones(id),
  device_id text REFERENCES dispositivos_cliente(device_id),
  visto_at timestamptz DEFAULT now()
);
```

## Paso 1.11 — Migración 011: Super Admin

Archivo: `011_super_admin.sql`

```sql
-- SUSCRIPCIONES DE RESTAURANTE
CREATE TABLE suscripciones_restaurante (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurante_id uuid REFERENCES restaurantes(id) UNIQUE,
  estado text NOT NULL DEFAULT 'prueba'
    CHECK (estado IN ('prueba', 'activa', 'vencida', 'bloqueada')),
  plan text NOT NULL DEFAULT 'basico'
    CHECK (plan IN ('basico', 'pro', 'enterprise')),
  fecha_inicio timestamptz NOT NULL DEFAULT now(),
  fecha_vencimiento timestamptz NOT NULL,
  bloqueado_por uuid REFERENCES usuarios(id),
  motivo_bloqueo text,
  created_at timestamptz DEFAULT now()
);

-- CONFIGURACIÓN GLOBAL FOODY
CREATE TABLE configuracion_global_foody (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clave text UNIQUE NOT NULL,
  valor text NOT NULL,
  descripcion text,
  editado_por uuid REFERENCES usuarios(id),
  updated_at timestamptz DEFAULT now()
);

-- Valores iniciales del sistema
INSERT INTO configuracion_global_foody (clave, valor, descripcion) VALUES
  ('comision_domiciliario_porcentaje', '15', '% que cobra Foody por entrega independiente'),
  ('tiempo_expiracion_oferta_seg', '60', 'Segundos antes de que expire una oferta de domicilio'),
  ('radio_inicial_busqueda_km', '3', 'Radio inicial para buscar domiciliarios'),
  ('ampliacion_radio_km', '2', 'Cuánto amplía el radio por intento fallido'),
  ('intentos_max_busqueda', '3', 'Intentos antes de alertar al restaurante'),
  ('umbral_alerta_descuento_pct', '30', '% de descuento que dispara alerta de riesgo'),
  ('umbral_alerta_cuadre_caja', '5000', 'Diferencia COP que dispara alerta de caja'),
  ('umbral_alerta_costo_sube_pct', '15', '% de subida de costo que dispara alerta'),
  ('umbral_alerta_margen_bajo_pct', '20', '% de margen mínimo antes de alertar'),
  ('dias_datos_restaurante_bloqueado', '30', 'Días que se guardan datos tras bloqueo'),
  ('tiempo_aprobacion_mesera_min', '3', 'Minutos para que mesera apruebe pedido QR'),
  ('umbral_reloj_pedido_rojo_min', '15', 'Minutos en estado antes de poner reloj en rojo');
```

---

# FASE 2 — BACKEND NESTJS

## Estructura completa de carpetas del backend

```
foody_backend/src/
├── main.ts
├── app.module.ts
├── core/
│   ├── database/
│   │   └── database.service.ts       ← cliente PostgreSQL
│   ├── auth/
│   │   ├── auth.module.ts
│   │   ├── auth.service.ts
│   │   ├── auth.controller.ts
│   │   ├── jwt.strategy.ts
│   │   └── guards/
│   │       ├── jwt-auth.guard.ts
│   │       ├── rol.guard.ts
│   │       ├── super-admin.guard.ts
│   │       ├── suscripcion-activa.guard.ts
│   │       └── usuario-activo.guard.ts
│   ├── realtime/
│   │   └── realtime.gateway.ts       ← Supabase Realtime broadcast
│   ├── notificaciones/
│   │   └── fcm.service.ts            ← Firebase Cloud Messaging
│   └── impresion/
│       └── impresion.gateway.ts      ← WebSocket → servidor Python
├── modulos/
│   ├── ciudades/
│   ├── restaurantes/
│   ├── sucursales/
│   ├── usuarios/
│   ├── dispositivos/
│   ├── menu/                         ← menú público completo
│   ├── categorias/
│   ├── productos/
│   ├── toppings/
│   ├── bebidas/
│   ├── combos/
│   ├── mesas/
│   ├── pedidos/                      ← MÓDULO MÁS CRÍTICO
│   ├── cocinas/
│   ├── impresoras/
│   ├── inventario/
│   ├── domiciliarios/
│   ├── ofertas-pedido/
│   ├── caja/
│   ├── facturas/
│   ├── reportes/
│   ├── alertas/
│   ├── auditoria/
│   ├── promociones/
│   └── super-admin/
│       ├── ciudades/
│       ├── restaurantes/
│       ├── suscripciones/
│       ├── usuarios-globales/
│       ├── domiciliarios-globales/
│       └── configuracion-global/
└── compartido/
    ├── decoradores/
    │   ├── usuario-actual.decorator.ts
    │   ├── sucursal-actual.decorator.ts
    │   └── permisos.decorator.ts
    ├── filtros/
    │   └── http-exception.filter.ts
    ├── interceptores/
    │   └── respuesta.interceptor.ts
    └── utilidades/
        ├── numero-pedido.util.ts
        └── calculos.util.ts
```

## Paso 2.1 — main.ts

```typescript
// foody_backend/src/main.ts
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.enableCors({ origin: '*' }); // Ajustar en producción

  const puerto = process.env.PUERTO || 3000;
  await app.listen(puerto);
  console.log(`Foody backend corriendo en puerto ${puerto}`);
}
bootstrap();
```

## Paso 2.2 — Formato de respuesta estándar

**TODAS las respuestas del backend siguen este formato sin excepción:**

```typescript
// Éxito
{ exito: true, datos: { ... }, mensaje: "Descripción en español" }

// Error
{ exito: false, error: "CODIGO_ERROR", mensaje: "Mensaje legible en español" }
```

Crear interceptor global `respuesta.interceptor.ts` que envuelva todas las respuestas en este formato.

## Paso 2.3 — Guards de seguridad (implementar en orden)

Los guards se aplican en este orden en CADA request autenticado:

```typescript
// 1. JwtAuthGuard — verifica token válido
// 2. UsuarioActivoGuard — verifica usuario.activo = true
// 3. SuscripcionActivaGuard — verifica suscripcion IN ('activa', 'prueba')
//    EXCEPTO rutas /super/* y /auth/*
// 4. RolGuard — verifica permiso según rol
// 5. SuperAdminGuard — SOLO para rutas /super/*
```

## Paso 2.4 — Módulo Auth (implementar primero)

**Endpoint:** `POST /api/v1/auth/login`

Lógica:
1. Buscar usuario por email
2. Verificar usuario.activo = true
3. Comparar contraseña con bcrypt
4. Si todo bien → generar JWT con payload: `{ sub: usuario.id, rol, sucursal_id, restaurante_id, permisos: [] }`
5. Determinar `dashboard` según rol:
   - `super_admin` → `'foody_control'`
   - `domiciliario_planta` → `'domiciliario'`
   - cualquier otro → `'restaurante'`
6. Obtener permisos de `roles_permisos` según rol
7. Devolver token + dashboard + rol + permisos + datos usuario

```typescript
// Response exitoso del login
{
  exito: true,
  datos: {
    token: "eyJ...",
    dashboard: "restaurante",
    rol: "cajero",
    permisos: ["ver_pedidos", "crear_pedido", "ver_caja"],
    usuario: {
      id: "uuid",
      nombre: "Juan Pérez",
      sucursal_id: "uuid",
      restaurante_id: "uuid"
    }
  }
}
```

## Paso 2.5 — Módulo Menú (público, sin auth)

**Endpoint:** `GET /api/v1/menu/:sucursal_id`

Lógica:
1. Verificar sucursal activa
2. Verificar horario actual → si fuera de horario, devolver `horario_activo: false` igualmente (cliente puede ver menú)
3. Obtener categorías activas con sus productos disponibles
4. Por cada producto: obtener toppings disponibles y bebidas disponibles
5. Obtener combos disponibles
6. Devolver estructura completa

Este endpoint es el más consultado de toda la plataforma. Optimizar con índices.

## Paso 2.6 — Módulo Pedidos (el más crítico)

**Endpoint:** `POST /api/v1/pedidos`

Implementar como una sola transacción PostgreSQL atómica con exactamente estos 20 pasos:

```
1.  BEGIN TRANSACTION
2.  Validar sucursal activa y en horario
3.  Validar que cada producto existe y disponible=true
4.  Validar que cada precio enviado coincide exactamente con el de la BD
5.  Por cada producto → consultar receta_items → verificar stock en ingredientes
6.  Calcular: subtotal, costo_domicilio según zona, descuento (si aplica), total
7.  INSERT pedidos con numero_pedido generado (FDY-YYYY-NNNN)
8.  INSERT estados_pedido_historial (estado inicial)
9.  INSERT pedido_items (copiar precio_unitario y costo_unitario AL MOMENTO)
10. INSERT pedido_item_toppings (copiar nombre y precio al momento)
11. INSERT pedido_item_bebidas (copiar nombre y precio al momento)
12. INSERT pedido_combo_selecciones si aplica
13. Por cada ingrediente de cada receta: UPDATE stock en ingredientes (restar)
14. INSERT movimientos_ingrediente tipo='venta' por cada ingrediente
15. CHECK: si stock <= stock_minimo → INSERT alertas_riesgo tipo stock_minimo_alcanzado
16. CHECK: si stock = 0 → UPDATE productos SET disponible=false
17. INSERT margenes_venta con costo_al_momento
18. Si metodo_pago definido → INSERT movimientos_caja automático
19. Si requiere_factura → INSERT facturas estado='borrador'
20. INSERT auditoria_logs
21. COMMIT

POST-TRANSACCIÓN (async, paralelo):
- Supabase Realtime broadcast al canal sucursal_{sucursal_id}
- WebSocket → servidor Python → impresión por cocina
- FCM push a roles cocina involucrados
- FCM push a meseros si es tipo='mesa' (para aprobar)
- Si tipo='domicilio' → iniciar búsqueda de domiciliario
```

---

# FASE 3 — FLUTTER: ESTRUCTURA Y CORE

## Paso 3.1 — Entry points (múltiples apps en un solo proyecto)

```dart
// lib/main_cliente.dart   → App pública para clientes (sin login)
// lib/main_admin.dart     → Login único → redirige según rol
```

## Paso 3.2 — Estructura completa de carpetas Flutter

```
foody_flutter/lib/
├── main_cliente.dart
├── main_admin.dart
├── core/
│   ├── constantes/
│   │   ├── colores.dart              ← #FF6B35, #2EC4B6, etc.
│   │   ├── rutas.dart                ← GoRouter completo
│   │   └── configuracion.dart        ← URLs, timeouts
│   ├── tema/
│   │   ├── tema_foody.dart           ← ThemeData completo
│   │   └── tipografia.dart           ← Poppins + Inter
│   ├── red/
│   │   ├── cliente_dio.dart          ← Dio con interceptores
│   │   └── interceptor_auth.dart     ← agrega Bearer token automático
│   ├── almacenamiento/
│   │   └── preferencias.dart         ← SharedPreferences
│   └── errores/
│       └── manejador_errores.dart
├── features/
│   ├── splash/
│   │   └── presentation/
│   │       └── splash_screen.dart
│   ├── ciudades/
│   │   ├── data/
│   │   │   └── ciudad_repository.dart
│   │   ├── domain/
│   │   │   └── ciudad_model.dart
│   │   └── presentation/
│   │       ├── ciudades_screen.dart
│   │       └── ciudades_provider.dart
│   ├── restaurantes/
│   ├── menu/
│   ├── carrito/
│   ├── checkout/
│   ├── pedido_seguimiento/
│   ├── auth/
│   │   └── presentation/
│   │       └── login_screen.dart
│   ├── panel_restaurante/
│   │   ├── dashboard/
│   │   ├── pedidos_kanban/
│   │   ├── menu_productos/
│   │   ├── inventario/
│   │   ├── mesas/
│   │   ├── cocinas/
│   │   ├── caja/
│   │   ├── domiciliarios/
│   │   ├── reportes/
│   │   ├── alertas/
│   │   ├── usuarios_sucursal/
│   │   └── configuracion/
│   ├── domiciliario_planta/
│   │   ├── pedidos_asignados/
│   │   ├── historial/
│   │   ├── estadisticas/
│   │   └── perfil/
│   └── super_admin/
│       ├── ciudades/
│       ├── restaurantes/
│       ├── suscripciones/
│       ├── usuarios_globales/
│       └── configuracion_global/
└── compartido/
    ├── widgets/
    │   ├── boton_primario.dart
    │   ├── tarjeta_producto.dart
    │   ├── indicador_carga.dart
    │   ├── skeleton_loader.dart
    │   ├── estado_vacio.dart
    │   └── error_widget_foody.dart
    ├── modelos/
    └── proveedores/                   ← Riverpod providers compartidos
```

## Paso 3.3 — colores.dart (copiar exacto)

```dart
import 'package:flutter/material.dart';

class ColoresFoody {
  static const Color primario    = Color(0xFFFF6B35);
  static const Color secundario  = Color(0xFF2EC4B6);
  static const Color acento      = Color(0xFFFFE66D);
  static const Color fondo       = Color(0xFFFAFAFA);
  static const Color texto       = Color(0xFF1A1A2E);
  static const Color error       = Color(0xFFE63946);
  static const Color exito       = Color(0xFF2DC653);
  static const Color gris        = Color(0xFF9E9E9E);
  static const Color grisSuave   = Color(0xFFF5F5F5);
  static const Color tarjeta     = Color(0xFFFFFFFF);
}
```

## Paso 3.4 — configuracion.dart

```dart
class Configuracion {
  // Desarrollo
  static const String urlBackend  = 'http://10.0.2.2:3000/api/v1';
  // Nota: 10.0.2.2 = localhost desde emulador Android
  // Para dispositivo físico en desarrollo: usar IP de la máquina (ej: 192.168.1.X)
  // Para producción: 'https://api.foody.com/api/v1'

  static const Duration timeoutConexion  = Duration(seconds: 10);
  static const Duration timeoutRespuesta = Duration(seconds: 30);
}
```

## Paso 3.5 — cliente_dio.dart

```dart
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constantes/configuracion.dart';

class ClienteDio {
  static Dio instancia() {
    final dio = Dio(BaseOptions(
      baseUrl: Configuracion.urlBackend,
      connectTimeout: Configuracion.timeoutConexion,
      receiveTimeout: Configuracion.timeoutRespuesta,
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // Si 401 → limpiar token y redirigir a login
        if (error.response?.statusCode == 401) {
          SharedPreferences.getInstance().then((p) => p.remove('token'));
        }
        return handler.next(error);
      },
    ));

    return dio;
  }
}
```

## Paso 3.6 — preferencias.dart

```dart
import 'package:shared_preferences/shared_preferences.dart';

class Preferencias {
  static Future<String?> obtenerToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('token');
  }

  static Future<void> guardarToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token);
  }

  static Future<void> guardarDeviceId(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('device_id', id);
  }

  static Future<String?> obtenerDeviceId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('device_id');
  }

  static Future<void> guardarCiudadId(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('ciudad_id', id);
  }

  static Future<String?> obtenerCiudadId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('ciudad_id');
  }

  static Future<void> limpiarTodo() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }
}
```

---

# FASE 4 — FLUTTER: APP CLIENTE (sin login)

## Paso 4.1 — main_cliente.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/tema/tema_foody.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/ciudades/presentation/ciudades_screen.dart';
import 'features/restaurantes/presentation/restaurantes_screen.dart';
import 'features/menu/presentation/menu_screen.dart';
import 'features/carrito/presentation/carrito_screen.dart';
import 'features/checkout/presentation/checkout_screen.dart';
import 'features/pedido_seguimiento/presentation/seguimiento_screen.dart';

void main() {
  runApp(const ProviderScope(child: FoodyClienteApp()));
}

class FoodyClienteApp extends StatelessWidget {
  const FoodyClienteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Foody',
      theme: TemaFoody.tema(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash',        builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/ciudades',      builder: (_, __) => const CiudadesScreen()),
    GoRoute(
      path: '/restaurantes/:ciudad_id',
      builder: (_, state) => RestaurantesScreen(ciudadId: state.pathParameters['ciudad_id']!),
    ),
    GoRoute(
      path: '/menu/:sucursal_id',
      builder: (_, state) => MenuScreen(sucursalId: state.pathParameters['sucursal_id']!),
    ),
    GoRoute(path: '/carrito',       builder: (_, __) => const CarritoScreen()),
    GoRoute(path: '/checkout',      builder: (_, __) => const CheckoutScreen()),
    GoRoute(
      path: '/seguimiento/:pedido_id',
      builder: (_, state) => SeguimientoScreen(pedidoId: state.pathParameters['pedido_id']!),
    ),
  ],
);
```

## Paso 4.2 — Pantalla Splash (P01)

**Lo que hace:**
1. Mostrar logo Foody centrado con animación fade-in
2. Generar device_id único si no existe (UUID v4, guardar en SharedPreferences)
3. Registrar/actualizar device en backend: `POST /dispositivos/registrar`
4. Verificar si ya tiene ciudad guardada en SharedPreferences
5. Si tiene ciudad → navegar directo a RestaurantesScreen
6. Si no tiene → navegar a CiudadesScreen

## Paso 4.3 — Pantalla Ciudades (P01 — selección)

**Lo que hace:**
- Llamar: `GET /ciudades`
- Mostrar lista de ciudades activas como cards con nombre e imagen
- Al tocar: guardar ciudad_id en SharedPreferences → navegar a RestaurantesScreen

**Estados:** cargando (skeleton), vacío ("Próximamente en tu ciudad"), error (reintentar)

## Paso 4.4 — Pantalla Restaurantes (P02)

**Lo que hace:**
- Llamar: `GET /ciudades/:slug/restaurantes`
- Header con nombre ciudad y botón cambiar
- Scroll horizontal de promociones (stories circulares)
- Lista de restaurantes con banner, logo, nombre, estado (abierto/cerrado)
- Restaurantes cerrados al final con overlay "Cerrado"

## Paso 4.5 — Pantalla Menú del Restaurante (P03)

**Lo que hace:**
- Llamar: `GET /menu/:sucursal_id`
- Header con banner grande, logo superpuesto, nombre, estado
- Tabs de categorías en scroll horizontal sticky
- Grid/lista de productos por categoría
- Botón flotante del carrito (aparece cuando hay ítems)
- Productos sin stock: overlay gris "No disponible"

## Paso 4.6 — Modal Detalle de Producto (P04)

**Lo que muestra:**
- Imagen grande, nombre, precio, descripción completa
- Sección "Agrega extras": chips de toppings con precio
- Sección "¿Qué vas a tomar?": selector de bebida
- Campo observaciones (texto libre)
- Contador de cantidad (-, n, +)
- Botón "Agregar al carrito" con total del ítem

**IMPORTANTE:** El carrito se gestiona con Riverpod (estado local en Flutter).
Nunca llamar al backend hasta confirmar el pedido completo.

## Paso 4.7 — Pantalla Carrito (P05)

**Lo que muestra:**
- Lista de ítems con foto, nombre, toppings, precio, botones editar/eliminar
- Subtotal, costo domicilio, total
- Selector tipo: Mesa / Para llevar / Domicilio
- Botón "Confirmar pedido" → va a checkout según tipo

## Paso 4.8 — Pantalla Checkout (P06A y P06B)

**Para llevar:** nombre opcional, método de pago, total, botón hacer pedido

**Domicilio:** nombre, teléfono, dirección, botón GPS, checkbox guardar datos,
toggle factura (si activa → pide NIT, nombre fiscal, email), método de pago, total con domicilio

**Al confirmar:** llamar `POST /pedidos` → manejar respuestas:
- Éxito → navegar a SeguimientoScreen con pedido_id
- Error STOCK_INSUFICIENTE → mostrar qué producto no tiene stock
- Error RESTAURANTE_CERRADO → mostrar horario
- Error PRECIO_INVALIDO → refrescar menú automáticamente

## Paso 4.9 — Pantalla Seguimiento (P07)

**Lo que muestra:**
- Número de pedido grande
- Línea de tiempo: Pendiente → Confirmado → En cocina → Listo → En camino → Entregado
- Estado actual resaltado, anteriores como completados
- Si hay domiciliario asignado: nombre, foto, calificación, mapa con ubicación en tiempo real

**Tiempo real:** Suscribirse a Supabase Realtime canal `sucursal_{sucursal_id}`
y escuchar cambios en el pedido específico. Actualizar la línea de tiempo sin reload.

---

# FASE 5 — FLUTTER: APP ADMIN (login único → múltiples dashboards)

## Paso 5.1 — main_admin.dart

Login único que redirige según el campo `dashboard` que devuelve el backend:
- `'foody_control'` → PanelFoodyScreen (super_admin)
- `'domiciliario'` → DashboardDomiciliarioScreen
- cualquier otro → PanelRestauranteScreen

## Paso 5.2 — Pantalla Login (L01)

```dart
// Pantalla simple:
// - Logo Foody centrado
// - Campo email
// - Campo contraseña (toggle mostrar/ocultar)
// - Botón "Ingresar"
// - Sin registro público (todos los usuarios los crea el admin)

// Al ingresar:
// 1. POST /auth/login
// 2. Guardar token en SharedPreferences
// 3. Leer respuesta.dashboard
// 4. Navegar a la pantalla correcta SIN que el usuario haga nada
```

## Paso 5.3 — Panel Restaurante (PanelRestauranteScreen)

**Construcción dinámica del menú según permisos:**

```dart
class MenuDinamico {
  static List<TabItem> construir(List<String> permisos) {
    final tabs = <TabItem>[];

    if (permisos.contains('ver_dashboard'))
      tabs.add(TabItem(icono: Icons.dashboard, label: 'Dashboard', ruta: '/dashboard'));
    if (permisos.contains('ver_pedidos'))
      tabs.add(TabItem(icono: Icons.receipt_long, label: 'Pedidos', ruta: '/pedidos'));
    if (permisos.contains('editar_productos'))
      tabs.add(TabItem(icono: Icons.restaurant_menu, label: 'Menú', ruta: '/menu'));
    if (permisos.contains('editar_stock'))
      tabs.add(TabItem(icono: Icons.inventory_2, label: 'Inventario', ruta: '/inventario'));
    if (permisos.contains('ver_caja'))
      tabs.add(TabItem(icono: Icons.point_of_sale, label: 'Caja', ruta: '/caja'));
    if (permisos.contains('gestionar_mesas'))
      tabs.add(TabItem(icono: Icons.table_restaurant, label: 'Mesas', ruta: '/mesas'));
    if (permisos.contains('ver_reportes'))
      tabs.add(TabItem(icono: Icons.bar_chart, label: 'Reportes', ruta: '/reportes'));
    if (permisos.contains('ver_alertas'))
      tabs.add(TabItem(icono: Icons.warning_amber, label: 'Alertas', ruta: '/alertas'));
    if (permisos.contains('gestionar_usuarios'))
      tabs.add(TabItem(icono: Icons.people, label: 'Usuarios', ruta: '/usuarios'));

    return tabs;
  }
}
```

## Paso 5.4 — Dashboard Admin (A02)

**Tarjetas resumen:**
- Ventas hoy
- Pedidos activos (en tiempo real)
- Pedidos completados hoy
- Alertas de riesgo pendientes

**Lista de pedidos activos en tiempo real** via Supabase Realtime.

## Paso 5.5 — Pantalla Pedidos Kanban

Columnas por estado (scroll horizontal):
- PENDIENTE / CONFIRMADO / EN COCINA / LISTO / EN CAMINO / ENTREGADO

Cada card muestra:
- Número de pedido
- Tipo (mesa/llevar/domicilio) con ícono
- Cliente o número de mesa
- Total
- **RELOJ EN TIEMPO REAL** desde que entró al estado (rojo si supera umbral de 15 min)

Actualización: Supabase Realtime. Cada vez que un pedido cambia de estado, se mueve de columna con animación.

## Paso 5.6 — Vista de Mesas (A_MESERO)

Grid de mesas con estado visual:
- 🟢 Verde: libre
- 🟡 Amarillo: ocupada
- 🟠 Naranja parpadeante: tiene pedido QR esperando aprobación
- 🔴 Rojo: pagando

Al tocar mesa con pedido pendiente: mostrar detalle con botones **Aprobar** / **Rechazar** (con selector de motivo obligatorio).

## Paso 5.7 — Panel Cajero (A_CAJERO)

Dos paneles en tablet, dos tabs en móvil:
- **Constructor de pedido:** categorías en tabs, productos en lista compacta, tocar para agregar
- **Carrito activo:** ítems, total, tipo, nombre cliente, método pago, botón confirmar

Si no hay caja abierta → mostrar pantalla de apertura de caja primero.

---

# FASE 6 — PYTHON PRINTER SERVER

## Estructura

```
foody_python_printer/
├── main.py             ← conecta WebSocket al backend NestJS
├── cola_impresion.py   ← cola local SQLite para reintentos si impresora falla
├── manejador.py        ← formatea e imprime tickets con python-escpos
├── config.py           ← IP backend, configuración impresoras
└── requirements.txt
```

## Paso 6.1 — requirements.txt

```
python-escpos==3.1
websocket-client==1.7.0
```

## Paso 6.2 — Lógica principal (main.py)

1. Conectar por WebSocket al backend NestJS en puerto 3001
2. Escuchar mensaje tipo `imprimir_ticket`
3. Payload incluye: `cocina_id`, `impresora_ip`, `datos_ticket`
4. Llamar a `manejador.py` para formatear e imprimir
5. Si impresora falla → guardar en cola SQLite local para reintento
6. Responder al backend: `{ exito: true/false }`

---

# FASE 7 — ORDEN DE IMPLEMENTACIÓN RECOMENDADO

Implementar en este orden exacto. No saltar fases.

## SPRINT 1 — Fundación (2 semanas)
```
☐ Crear estructura completa de carpetas
☐ Configurar Docker Compose con PostgreSQL
☐ Ejecutar todas las migraciones SQL en orden
☐ NestJS: main.ts, app.module.ts, database.service.ts
☐ NestJS: módulo Auth completo con JWT
☐ NestJS: todos los guards (Jwt, Rol, SuperAdmin, SuscripcionActiva, UsuarioActivo)
☐ Flutter: estructura de carpetas
☐ Flutter: colores, tema, tipografía
☐ Flutter: cliente Dio con interceptores
☐ Flutter: preferencias (SharedPreferences)
☐ Flutter: pantalla Login funcionando
```

## SPRINT 2 — App cliente: ciudades, restaurantes, menú (2 semanas)
```
☐ NestJS: módulo ciudades (GET /ciudades, GET /ciudades/:slug/restaurantes)
☐ NestJS: módulo restaurantes (GET /restaurantes/:id/sucursales)
☐ NestJS: módulo menú (GET /menu/:sucursal_id)
☐ NestJS: módulo dispositivos (POST /dispositivos/registrar)
☐ Flutter app cliente: Splash → device_id → ciudades
☐ Flutter app cliente: Lista de restaurantes con estados
☐ Flutter app cliente: Menú con categorías, tabs sticky, productos
☐ Flutter app cliente: Modal detalle producto con toppings y bebidas
☐ Flutter: carrito con Riverpod (estado local)
```

## SPRINT 3 — Pedidos y seguimiento (2 semanas)
```
☐ NestJS: módulo pedidos — POST /pedidos (transacción completa 20 pasos)
☐ NestJS: GET /pedidos/:id/estado (seguimiento público)
☐ NestJS: Supabase Realtime gateway (broadcast en tiempo real)
☐ Flutter: checkout para llevar
☐ Flutter: checkout domicilio completo
☐ Flutter: pantalla seguimiento con línea de tiempo
☐ Flutter: Supabase Realtime — actualización en tiempo real del estado
☐ Pruebas end-to-end del flujo completo de pedido
```

## SPRINT 4 — Panel admin básico (2 semanas)
```
☐ NestJS: GET /pedidos (lista para admin)
☐ NestJS: PATCH /pedidos/:id/estado (cambiar estado)
☐ Flutter admin: Dashboard con tarjetas resumen
☐ Flutter admin: Kanban de pedidos con reloj en tiempo real
☐ Flutter admin: Construcción dinámica del menú por permisos
☐ Flutter admin: Vista de mesas con estados
☐ Flutter admin: Aprobación de pedidos QR
```

## SPRINT 5 — Caja y productos (2 semanas)
```
☐ NestJS: módulo caja completo (abrir, cerrar, movimientos, retiro, gastos)
☐ NestJS: módulo productos/categorías/toppings/bebidas/combos (CRUD)
☐ Flutter admin: Panel cajero (constructor de pedido + carrito)
☐ Flutter admin: Gestión de caja (abrir, ver movimientos, cerrar)
☐ Flutter admin: CRUD de productos y categorías
```

## SPRINT 6 — Inventario (2 semanas)
```
☐ NestJS: módulo inventario completo (ingredientes, recetas, movimientos, compras)
☐ NestJS: cálculo automático de costos y actualización de costo_calculado en productos
☐ NestJS: descontar stock en transacción de pedido
☐ Flutter admin: gestión de ingredientes y stock
☐ Flutter admin: configurar recetas por producto
☐ Flutter admin: registro de compras
☐ Flutter admin: conteos físicos de inventario
```

## SPRINT 7 — Domiciliarios y notificaciones (2 semanas)
```
☐ NestJS: módulo domiciliarios independientes (registro, documentos, sesiones, GPS)
☐ NestJS: sistema de ofertas y dispatch automático (radio, tiempo expiración, reintentos)
☐ NestJS: módulo domiciliarios de planta
☐ NestJS: Firebase FCM service (push notifications)
☐ Flutter: App domiciliario de planta (pedidos asignados, confirmar entrega)
☐ Flutter: notificaciones push en todos los roles
☐ Flutter: mapa con tracking en tiempo real
```

## SPRINT 8 — Super Admin y suscripciones (1 semana)
```
☐ NestJS: todos los endpoints /super/* con SuperAdminGuard
☐ NestJS: SuscripcionActivaGuard aplicado a todos los endpoints del restaurante
☐ Flutter: Panel Foody (super_admin) — ciudades, restaurantes, suscripciones, usuarios, configuración
```

## SPRINT 9 — Reportes, alertas y facturación (2 semanas)
```
☐ NestJS: módulo reportes (financiero, productos, pedidos, inventario, domiciliarios)
☐ NestJS: sistema de alertas de riesgo (umbrales exactos según reglas de negocio)
☐ NestJS: módulo facturación (config fiscal, emisión, PDF)
☐ Flutter: pantallas de reportes
☐ Flutter: gestión de alertas
```

## SPRINT 10 — Servidor Python de impresión (1 semana)
```
☐ Python: servidor WebSocket que recibe órdenes del backend
☐ Python: formatear tickets por cocina (nombre plato, cantidad, observaciones, mesa/tipo)
☐ Python: cola SQLite para reintentos si impresora falla
☐ Python: conexión python-escpos a impresoras térmicas
☐ NestJS: WebSocket gateway para enviar al servidor Python
☐ Pruebas con impresora física
```

## SPRINT 11 — Pulido, pruebas y producción (2 semanas)
```
☐ Pruebas de carga en el endpoint POST /pedidos
☐ Verificar que TODOS los queries incluyen sucursal_id
☐ Revisar todos los guards en todos los endpoints
☐ Configurar Nginx como proxy inverso
☐ Configurar SSL con Let's Encrypt
☐ Variables de entorno de producción
☐ Configurar VPS Ubuntu 22.04
☐ Deploy con Docker Compose
☐ Configurar backups automáticos de PostgreSQL
☐ Pruebas en dispositivos físicos (Android + iPhone)
```

---

# RESUMEN DE ENDPOINTS POR MÓDULO

## Públicos (sin auth)
```
GET    /ciudades
GET    /ciudades/:slug/restaurantes
GET    /restaurantes/:id/sucursales
GET    /menu/:sucursal_id
GET    /menu/mesa/:qr_token
POST   /dispositivos/registrar
PATCH  /dispositivos/ciudad
POST   /pedidos
GET    /pedidos/:id/estado
GET    /promociones/:sucursal_id
POST   /promociones/:id/vista
POST   /domiciliarios/calificaciones
```

## Con auth (Bearer JWT)
```
POST   /auth/login
POST   /auth/renovar-token
GET    /auth/perfil

GET    /pedidos
GET    /pedidos/cocina/:cocina_id
PATCH  /pedidos/:id/estado
PATCH  /pedidos/:id/aprobar
PATCH  /pedidos/:id/rechazar
DELETE /pedidos/:id/items/:item_id

GET/POST/PATCH/DELETE  /mesas/:sucursal_id
GET    /mesas/:id/qr-pdf
POST   /mesas/transferir

GET/POST/PATCH/DELETE  /categorias
GET/POST/PATCH/DELETE  /productos
PATCH  /productos/:id/disponibilidad
GET    /productos/:id/precio-sugerido
POST/GET  /toppings, /bebidas, /combos

GET    /inventario/:sucursal_id
POST   /inventario
PATCH  /inventario/:id
POST   /inventario/compras
GET    /inventario/movimientos/:sucursal_id
POST/GET  /inventario/producto-ingredientes

POST   /caja/abrir
POST   /caja/cerrar
GET    /caja/activa/:sucursal_id
GET    /caja/:id/movimientos
POST   /caja/retiro-parcial
POST   /caja/gastos
POST   /caja/cuentas-por-cobrar
PATCH  /caja/cuentas-por-cobrar/:id/pagar

GET    /reportes/financiero
GET    /reportes/productos
GET    /reportes/pedidos
GET    /reportes/inventario
GET    /reportes/domiciliarios
```

## Super Admin (Bearer + rol super_admin)
```
GET/POST/PATCH   /super/ciudades
GET/POST/PATCH   /super/restaurantes
POST/PATCH       /super/restaurantes/:id/bloquear
GET/PATCH        /super/suscripciones
GET/POST/PATCH   /super/usuarios
GET/PATCH        /super/configuracion
GET              /super/estadisticas
GET/PATCH        /super/domiciliarios
```

---

# CÓDIGOS DE ERROR ESTÁNDAR

```
STOCK_INSUFICIENTE         → No hay ingredientes para el producto
PRODUCTO_NO_DISPONIBLE     → Producto marcado como no disponible
PRECIO_INVALIDO            → Precio enviado no coincide con BD
RESTAURANTE_CERRADO        → Fuera del horario de operación
MESA_NO_ENCONTRADA         → QR token inválido
CAJA_NO_ABIERTA            → Intento de operación sin turno activo
CAJA_YA_ABIERTA            → Intento de abrir caja cuando ya hay una activa
SIN_PERMISO                → El rol no tiene permiso para esta acción
TOKEN_EXPIRADO             → JWT expirado, renovar
PEDIDO_NO_MODIFICABLE      → El pedido está en estado que no permite cambios
DOMICILIARIO_NO_DISPONIBLE → Sin domiciliario en el radio configurado
RESTAURANTE_BLOQUEADO      → Suscripción bloqueada o vencida
SUPER_ADMIN_REQUERIDO      → Endpoint exclusivo de super_admin
USUARIO_INACTIVO           → Usuario deshabilitado
SUSCRIPCION_VENCIDA        → La suscripción venció
ROL_SIN_ACCESO_DASHBOARD   → Rol sin permiso para el dashboard solicitado
```

---

# REGLAS DE NEGOCIO CRÍTICAS PARA EL CÓDIGO

```
Tiempo mínimo para cancelar pedido:     2 minutos desde confirmación
Quién puede cancelar después de 2 min:  Solo admin o gerente
Tiempo aprobación mesera (QR):          3 minutos
Domiciliarios notificados simultáneo:   5 más cercanos
Tiempo expiración oferta domicilio:     60 segundos
Radio inicial búsqueda domiciliario:    3 km
Ampliación radio por intento fallido:   +2 km
Intentos máximos de búsqueda:          3 (radio final: 9 km)
Descuento sin aprobación adicional:     máximo 20%
Descuento que genera alerta:           mayor al 30%
Diferencia en caja que genera alerta:   mayor a $5.000 COP
Calificación mínima domiciliario:       3.5 estrellas (mínimo 10 entregas)
Comisión Foody por entrega:             15% del valor del domicilio
M�ximo ítems en carrito:               50
Período de datos tras bloqueo:         30 días
Período de prueba restaurante nuevo:   14 días
```

---

# CHECKLIST FINAL ANTES DE PRODUCCIÓN

```
☐ Todas las tablas con sucursal_id tienen índice en esa columna
☐ Todos los endpoints autenticados tienen los 5 guards aplicados en orden
☐ La transacción de pedido maneja BEGIN/COMMIT/ROLLBACK correctamente
☐ El stock jamás queda negativo (validación antes de descontar)
☐ auditoria_logs tiene REVOKE UPDATE, DELETE
☐ Las contraseñas se guardan con bcrypt (nunca en texto plano)
☐ El JWT_SECRET en producción es diferente al de desarrollo
☐ Los CORS están configurados correctamente para el dominio de producción
☐ Los archivos .env están en .gitignore
☐ Las imágenes van a Supabase Storage, no al servidor
☐ El servidor Python está en la red local del negocio (no expuesto a internet)
☐ Los backups de PostgreSQL están configurados y probados
☐ El SSL está activo en todos los dominios
☐ Se probó el flujo completo en dispositivo físico Android e iOS
☐ Se probó la impresión con impresora térmica real
```

---

*Documento generado para uso exclusivo de Cursor AI*
*Versión del proyecto: Foody v1.0 — Inicio de desarrollo*
*Base de referencia: Tu Cancha Fácil (patrones de providers, modelos, servicios Flutter)*
