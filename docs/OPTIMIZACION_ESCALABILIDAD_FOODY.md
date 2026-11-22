# Foody — Optimización y escalabilidad (revisión orientada al proyecto)

> **Origen:** revisión de `INFRAESTRUCTURA/foody_optimizacion.docx` (recomendaciones generadas por Claude sobre el stack).
> **Fecha revisión:** 2026-06-24  
> **Referencias:** `MEMORIA.md`, `docs/AVANCE_PROYECTO.md`, `docs/ENTORNO_LOCAL.md`, `INFRAESTRUCTURA/endpoints_api_foody.md`

Este documento **corrige inconsistencias** del archivo original, indica **qué ya existe en Foody** y propone un **plan de implementación realista** respetando las reglas del proyecto: NestJS + PostgreSQL (`pg`), multi-tenant por **`sucursal_id`**, Flutter solo UI, respuestas `{ exito, datos, mensaje }`.

---

## Resumen ejecutivo

| Área | Veredicto | Acción |
|------|-----------|--------|
| Estabilidad (Docker + excepciones) | 🟡 Parcial | Docker dev OK; falta compose prod. Filtro global **ya existe** (mejor que el propuesto). |
| Almacenamiento imágenes (R2) | ⏳ Pendiente | Válido para producción; hoy solo hay `imagen_url` (texto), sin upload en NestJS. |
| Compresión Sharp | ⏳ Pendiente | Implementar **junto** al primer endpoint de subida. |
| Índices PostgreSQL | 🟡 Parcial | Pedidos indexados; faltan productos/mesas/usuarios y tablas de alto volumen. |
| Paginación | 🟡 Parcial | Varios listados usan `limite` fijo (ej. 100), no paginación estándar. |
| Caché menú | ✅ Hecho | `MenuCacheService` + `@nestjs/cache-manager` TTL 5 min (fase 1). Pendiente residual: ver `RECOMENDACIONES_IMPLEMENTACION.md`. |
| PM2 cluster | 📅 Planificado | Solo con 100+ restaurantes; requiere Redis y cuidado con cron/Realtime. |
| Logs + monitoreo | 🟡 Parcial | Health check existe; falta Winston/UptimeRobot en prod. |

**Próximo paso recomendado (antes de escalar):** índices faltantes + paginación en pedidos/reportes + pipeline de imágenes (Sharp + storage) cuando se active subida en admin.

---

## Correcciones críticas al documento original

Estas diferencias **no son opcionales**; aplicar el docx tal cual rompería o ignoraría la arquitectura Foody.

### 1. `restaurant_id` ≠ columna operativa

El documento original indexa y filtra por `restaurant_id` en `pedidos`, `productos`, `mesas` y `usuarios`.

**En Foody la unidad operativa es `sucursal_id`** (regla absoluta en `MEMORIA.md`). Un restaurante puede tener varias sucursales; menú, pedidos, caja, inventario y staff operan **por sucursal**.

| Tabla | Columna correcta para queries operativas | Notas |
|-------|------------------------------------------|-------|
| `pedidos` | `sucursal_id` | Ya indexado en migración `005_pedidos.sql` |
| `productos`, `categorias`, `mesas` | `sucursal_id` | Sin índice dedicado aún |
| `usuarios` | `sucursal_id` (+ a veces `restaurante_id` para cadena) | Staff puede ser por sede o cadena según rol |

**Índices incorrectos del docx (no ejecutar):**

```sql
-- ❌ INCORRECTO para Foody — estas columnas no existen o no son la clave operativa
CREATE INDEX idx_pedidos_restaurant ON pedidos(restaurant_id);
CREATE INDEX idx_productos_restaurant ON productos(restaurant_id);
```

**Índices correctos (ver sección 3):** usar `sucursal_id`.

---

### 2. Backend no usa el cliente Supabase para queries de negocio

El docx muestra paginación con `supabase.from('pedidos').select(...)`.

**Foody usa `DatabaseService` + `pg` Pool** con SQL parametrizado (`foody_backend/src/core/database/database.service.ts`). Toda propuesta de código debe adaptarse a ese patrón, no al SDK JS de Supabase en el API.

Supabase en Foody sirve para:
- **Auth** (staff OAuth/JWT bridge)
- **Storage** (imágenes, cuando se implemente upload)
- **Realtime** (broadcast vía backend, no escritura directa desde Flutter en tablas críticas)

---

### 3. Formato de respuestas y errores

El filtro propuesto devuelve `{ statusCode, message, timestamp }`.

**Foody ya tiene `HttpExceptionFilter`** (`foody_backend/src/compartido/filtros/http-exception.filter.ts`) registrado en `AppModule`, con:
- Errores: `{ exito: false, error, mensaje, detalles? }`
- Éxitos: `RespuestaInterceptor` → `{ exito, datos, mensaje }`
- Mapeo de códigos de negocio (`STOCK_INSUFICIENTE`, `PLAN_LIMITE_EXCEDIDO`, etc.)

**No reemplazar** por el filtro genérico del docx. Opcional: loguear stack trace en servidor para errores 500 (sin exponerlo al cliente).

---

### 4. Rutas y endpoints

| Docx original | Foody real |
|---------------|------------|
| `GET /health` | `GET /api/v1/salud` (incluye ping BD) + `GET /api/v1/health/realtime` |
| `GET menu/:restaurantId` | `GET /api/v1/menu/:sucursal_id` (y variantes mesa QR) |
| Prefijo API | Global prefix `api/v1` en `main.ts` |

Monitoreo externo (UptimeRobot): apuntar a `https://tu-dominio/api/v1/salud`.

---

### 5. Lo que el docx no menciona pero Foody ya tiene

| Capacidad | Ubicación |
|-----------|-----------|
| Rate limiting global | `RateLimitGuard` en `app.module.ts` |
| Interceptor de respuesta estándar | `RespuestaInterceptor` |
| Límites por plan (freemium) | `PlanFeaturesService` + guards |
| Índices pedidos | `idx_pedidos_sucursal_estado`, `idx_pedidos_sucursal_created` |
| Docker restart (dev DB) | `restart: unless-stopped` en `docker-compose.dev.yml` → servicio `db` |
| Realtime seguro | Broadcast NestJS → Supabase Realtime (cliente no escribe pedidos) |

---

## Análisis por propuesta

### 0. Estabilidad mínima

#### 0.1 Docker `restart: unless-stopped`

| | |
|---|---|
| **Propuesta** | Reinicio automático si NestJS/ contenedor muere. |
| **Estado Foody** | ✅ En Postgres dev (`docker-compose.dev.yml`). ⏳ Falta `docker-compose.prod.yml` con backend + Supabase stack. |
| **Corrección** | Al crear compose de producción en VPS Ubuntu, aplicar `restart: unless-stopped` a **todos** los servicios: `db`, Supabase (Kong, auth, rest, storage), `foody_backend`, impresión Python (futuro). |
| **Prioridad** | Alta — antes del primer cliente en prod. |
| **Sprint** | 11 (producción) |

#### 0.2 Global Exception Filter

| | |
|---|---|
| **Propuesta** | `AllExceptionsFilter` en `main.ts`. |
| **Estado Foody** | ✅ **Ya implementado** — `HttpExceptionFilter` vía `APP_FILTER`, más completo que el ejemplo del docx. |
| **Mejora opcional** | Añadir `Logger.error()` con stack en catch de errores no-HttpException; no cambiar contrato JSON al cliente. |
| **Prioridad** | Baja (mejora incremental). |

---

### 1. Cloudflare R2 — almacenamiento de imágenes

| | |
|---|---|
| **Propuesta** | Bucket S3-compatible, CDN, no llenar disco VPS. |
| **Estado Foody** | 🟡 Campos `imagen_url` en productos/categorías/combos/promos; **no hay** `FileInterceptor` ni módulo storage en NestJS. Supabase Storage está previsto en spec (`MEMORIA.md`, comentario en `main.dart`). |
| **Corrección / decisión** | **Opción A (rápida MVP prod):** Flutter sube a Supabase Storage (bucket público por sucursal), guarda URL en NestJS vía PATCH catálogo. **Opción B (escala 100+ rest.):** R2 + dominio `assets.foody.app` + NestJS genera URLs firmadas o sube vía `@aws-sdk/client-s3`. R2 **complementa** Supabase self-hosted liberando disco del VPS; no sustituye Auth/Realtime. |
| **Estructura de keys sugerida** | `{restaurante_id}/{sucursal_id}/productos/{producto_id}.webp` |
| **Prioridad** | Media — cuando admin permita subir foto (hoy muchas URLs son manuales o seed). |
| **Sprint** | 5–11 (catálogo admin + prod) |

Variables `.env` (si R2):

```env
R2_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET_NAME=foody-assets
R2_PUBLIC_URL=https://assets.tudominio.com
```

---

### 2. Compresión con Sharp (WebP)

| | |
|---|---|
| **Propuesta** | Redimensionar 800×800, WebP calidad 80, ~150–200 KB por plato. |
| **Estado Foody** | ⏳ No instalado (`sharp` no está en `package.json`). |
| **Corrección** | Integrar en **un solo servicio** `AlmacenamientoImagenesService`: `compress(buffer) → upload → return url`. Aplicar a productos, categorías, logos restaurante, stories promociones. |
| **Prioridad** | Media — mismo sprint que upload. |
| **Nota Flutter** | Cliente solo muestra URL; no comprimir en Dart (regla Flutter = solo UI). |

---

### 3. Índices PostgreSQL

| | |
|---|---|
| **Propuesta** | Índices en columnas de tenant + consultas frecuentes. |
| **Estado Foody** | 🟡 Pedidos OK; catálogo/mesas/usuarios sin índice explícito; otras tablas según crecimiento. |
| **Corrección** | Usar **`sucursal_id`**, no `restaurant_id`. |

**Ya existen (no duplicar):**

```sql
-- 005_pedidos.sql
CREATE INDEX idx_pedidos_sucursal_estado ON pedidos(sucursal_id, estado);
CREATE INDEX idx_pedidos_sucursal_created ON pedidos(sucursal_id, created_at DESC);
```

**Migración recomendada** (`foody_supabase/migrations/055_indices_rendimiento.sql`):

```sql
-- Catálogo y operación diaria
CREATE INDEX IF NOT EXISTS idx_productos_sucursal
  ON productos(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_productos_sucursal_categoria
  ON productos(sucursal_id, categoria_id);
CREATE INDEX IF NOT EXISTS idx_categorias_sucursal
  ON categorias(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_mesas_sucursal
  ON mesas(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_mesas_qr_token
  ON mesas(qr_token);  -- ya UNIQUE; índice explícito para JOIN menú QR

-- Staff y cadena
CREATE INDEX IF NOT EXISTS idx_usuarios_sucursal
  ON usuarios(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_restaurante
  ON usuarios(restaurante_id) WHERE restaurante_id IS NOT NULL;

-- Pedidos — ítems e historial (Kanban, KDS, reportes)
CREATE INDEX IF NOT EXISTS idx_pedido_items_pedido
  ON pedido_items(pedido_id);
CREATE INDEX IF NOT EXISTS idx_estados_pedido_historial_pedido
  ON estados_pedido_historial(pedido_id, fecha DESC);

-- Inventario y alertas (admin con muchos movimientos)
CREATE INDEX IF NOT EXISTS idx_movimientos_inventario_sucursal_fecha
  ON movimientos_inventario(sucursal_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inventario_items_sucursal
  ON inventario_items(sucursal_id);

-- Domicilio dispatch
CREATE INDEX IF NOT EXISTS idx_asignaciones_domicilio_pedido
  ON asignaciones_domicilio(pedido_id, asignado_at DESC);

-- Auditoría (solo INSERT; consultas por sucursal en reportes)
CREATE INDEX IF NOT EXISTS idx_auditoria_logs_sucursal_fecha
  ON auditoria_logs(sucursal_id, created_at DESC);
```

| **Prioridad** | Alta antes de 10k+ pedidos por sucursal o reportes lentos. |
| **Cuándo notar** | Kanban con historial largo, listados admin de inventario, super-admin estadísticas. |

---

### 4. Paginación en listados

| | |
|---|---|
| **Propuesta** | `page` + `limit` + `total` + `totalPages` en todos los listados. |
| **Estado Foody** | 🟡 `PedidosService.listarPorSucursal` usa `limite ?? 100` sin offset ni total. Similar en inventario (`limite = 50`), domiciliarios historial, etc. |
| **Corrección** | Patrón estándar Foody en NestJS + `pg`: |

```typescript
// DTO común: compartido/dto/paginacion.dto.ts
export class PaginacionDto {
  @IsOptional() @Type(() => Number) @Min(1) page?: number = 1;
  @IsOptional() @Type(() => Number) @Min(1) @Max(100) limit?: number = 20;
}

// SQL
const offset = (page - 1) * limit;
const filas = await this.database.consultar(
  `SELECT ... FROM pedidos WHERE sucursal_id = $1 ... ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
  [sucursalId, limit, offset],
);
const [{ count }] = await this.database.consultar(
  `SELECT COUNT(*)::int AS count FROM pedidos WHERE sucursal_id = $1 ...`,
  [sucursalId],
);
return { datos: filas, total: count, page, totalPages: Math.ceil(count / limit) };
```

Respuesta envuelta por interceptor: `{ exito: true, datos: { items, total, page, totalPages }, mensaje: null }`.

**Endpoints prioritarios:**

| Endpoint | Motivo |
|----------|--------|
| `GET /pedidos/:sucursal` | Kanban + historial |
| `GET /reportes/*` | Rangos largos |
| `GET /inventario/movimientos` | Alto volumen |
| `GET /auditoria` (futuro) | Compliance |
| Super-admin listados restaurantes/usuarios | Panel global |

| **Prioridad** | Media-alta antes de producción con clientes reales. |
| **Flutter** | Infinite scroll o paginador; **no** cargar 500 pedidos en memoria. |

---

### 5. Caché de respuestas frecuentes

| | |
|---|---|
| **Propuesta** | `@nestjs/cache-manager` en memoria; TTL 5 min en menú. |
| **Estado Foody** | ⏳ No implementado. Menú es lectura intensiva (`GET /menu/:sucursal_id`). |
| **Corrección** | Clave de caché: `menu:${sucursalId}` (no restaurantId). **Invalidar** en PATCH/POST/DELETE de catálogo (`catalogo.service.ts`). |
| **Redis** | Cuando PM2 cluster o múltiples instancias; hasta ~20 restaurantes, caché en memoria + invalidación explícita basta. |
| **Prioridad** | Media — con 20+ restaurantes activos o picos en hora almuerzo. |

Ejemplo alineado:

```typescript
@Injectable()
export class MenuService {
  constructor(
    private readonly db: DatabaseService,
    @Inject(CACHE_MANAGER) private cache: Cache,
  ) {}

  async obtenerMenu(sucursalId: string) {
    const key = `menu:${sucursalId}`;
    const cached = await this.cache.get(key);
    if (cached) return cached;
    const menu = await this.cargarMenuDesdeBd(sucursalId);
    await this.cache.set(key, menu, 300_000); // 5 min
    return menu;
  }
}
```

---

### 6. PM2 cluster mode

| | |
|---|---|
| **Propuesta** | `pm2-runtime start dist/main.js -i max` en Docker. |
| **Estado Foody** | ⏳ `start:prod` = `node dist/main.js` (un proceso). |
| **Corrección / riesgos Foody** | Con cluster: (1) caché en memoria inconsistente → **Redis obligatorio**; (2) crons (`SuscripcionesCronModule`, cola FCM) pueden ejecutarse N veces → un solo worker o `@nestjs/schedule` con lock; (3) WebSocket impresión/gateway → sticky sessions o proceso dedicado; (4) Realtime broadcast OK (stateless hacia Supabase). |
| **Prioridad** | Baja hasta saturación CPU sostenida (>70% un núcleo). |
| **Umbral docx** | 100+ restaurantes simultáneos — razonable como guía. |

---

### 7. Logs y monitoreo

| | |
|---|---|
| **Propuesta** | Winston + health + UptimeRobot. |
| **Estado Foody** | 🟡 `GET /api/v1/salud` verifica BD; `GET /api/v1/health/realtime` verifica Supabase Realtime. Sin Winston; logs = `console.log`. |
| **Corrección** | Mantener `/salud` como monitor principal. Añadir campo `timestamp` ISO en respuesta si UptimeRobot lo necesita. Winston opcional sprint 11; en VPS mínimo: redirigir stdout a archivo con rotación (`logrotate`). |
| **Prioridad** | Alta en prod (UptimeRobot gratis → alerta WhatsApp/email). |

Respuesta sugerida enriquecida:

```json
{
  "exito": true,
  "datos": {
    "api": "foody",
    "base_datos": true,
    "entorno": "produccion",
    "timestamp": "2026-06-24T12:00:00.000Z"
  }
}
```

---

## Hoja de ruta corregida (por etapa)

| Etapa | Restaurantes activos | Acciones Foody |
|-------|----------------------|----------------|
| **Hoy** | 1–20 (dev / primeros pilotos) | Estabilidad auth, flujos E2E, **no** PM2/Redis. Compose prod con `restart: unless-stopped`. |
| **Corto plazo** | 20–100 | Migración `055_indices_rendimiento.sql` + paginación pedidos/reportes + pipeline imágenes (Sharp + R2 o Supabase Storage) + caché menú en memoria. |
| **Mediano plazo** | 100–300 | PM2 cluster **solo con Redis** + revisión crons + UptimeRobot + logs estructurados. |
| **Largo plazo** | 300+ | VPS mayor o 2 nodos, load balancer Cloudflare, réplica lectura PostgreSQL (Supabase self-hosted), CDN assets. |

Alineación con sprints oficiales: estabilidad base → Sprint 11; rendimiento catálogo → Sprint 5; escala infra → post-Sprint 11 según métricas reales.

---

## Checklist de implementación (orden corregido)

### Esta semana — estabilidad y observabilidad

- [x] Crear `docker-compose.prod.yml` + `foody_backend/Dockerfile` con `restart: unless-stopped`
- [x] ~~Crear AllExceptionsFilter~~ — ya existe `HttpExceptionFilter` (+ log 500)
- [x] `GET /api/v1/salud` con `timestamp` para UptimeRobot
- [ ] Registrar UptimeRobot en producción (requiere URL pública del VPS)
- [x] Pool PostgreSQL configurable (`DB_POOL_MAX`)

### Antes de producción — rendimiento base

- [x] Migración `056_indices_rendimiento.sql` (aplicar en BD)
- [x] Paginación opcional en `GET /pedidos?page=&limit=` (Kanban sin cambios)
- [x] Caché menú 5 min + invalidación al editar catálogo
- [x] Endpoint upload imágenes + Sharp + **Supabase Storage** (`POST /almacenamiento/productos/:id/imagen`)

### Con 20+ restaurantes — caché

- [x] `@nestjs/cache-manager` en menú (TTL 5 min) — hecho en fase 1
- [ ] Medir hit rate; evaluar Redis si reinicios frecuentes

### Con 100+ restaurantes — escala

- [ ] Redis para caché compartida
- [ ] PM2 cluster con worker único para crons/notificaciones
- [ ] Upgrade VPS (CPU/RAM) según métricas
- [ ] CDN Cloudflare delante de assets estáticos e imágenes

### Con 300+ restaurantes — infraestructura seria

- [ ] Segundo VPS o instancia DB dedicada
- [ ] Load balancer + health checks
- [ ] Réplica lectura PostgreSQL para reportes/analítica (`docs/MODULO_ANALITICA_BI.md`)

---

## Lo que Foody debe optimizar además (no estaba en el docx)

Prioridades de negocio **antes** que escala horizontal:

1. **Cerrar R5 impresión** — gateway NestJS existe; falta Python/escpos (Sprint 10).
2. **Post-commit pedidos** — impresión y FCM tras confirmar (cola ya parcial en `notificaciones`).
3. **Consultas N+1** — revisar KDS y Kanban (JOINs vs múltiples round-trips).
4. **Pool PostgreSQL** — configurar `max` en `Pool` según RAM VPS cuando suba concurrencia.
5. **Flutter web** — lazy load imágenes menú (`cached_network_image`); no afecta backend pero sí percepción de velocidad.
6. **Plan freemium** — límites ya en backend; evitar queries pesadas en plan gratis (ej. no precalcular costeo industrial en listados).

---

## Referencias cruzadas

| Tema | Documento |
|------|-----------|
| Estado implementación | `docs/AVANCE_PROYECTO.md` |
| Multi-sucursal | `docs/MULTI_SUCURSAL.md` |
| Entorno VPS | `docs/ENTORNO_LOCAL.md` |
| Endpoints | `INFRAESTRUCTURA/endpoints_api_foody.md` |
| Esquema BD | `INFRAESTRUCTURA/esquema_maestro_bd_v3.md` |
| Doc original (sin corregir) | `INFRAESTRUCTURA/foody_optimizacion.docx` |

---

## Changelog

| Fecha | Cambio |
|-------|--------|
| 2026-06-24 | Implementación fase 1: migración `056_indices_rendimiento`, caché menú, paginación pedidos, salud+logs, docker prod. |
| 2026-06-24 | Revisión completa del docx Claude: corrección `sucursal_id`, estado actual Foody, índices SQL, checklist y roadmap alineados al repo. |
