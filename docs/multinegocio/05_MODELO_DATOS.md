# 05 — Modelo de datos (propuesta futura)

> **No crear estas migraciones todavía.** Numeración ilustrativa; al ejecutar, usar el siguiente ID libre tras las migraciones actuales (`068+`).

Principios:

- `sucursal_id` en toda tabla operativa (regla Foody).
- Nullable hacia atrás: restaurante no usa `variante_id`.
- Default `tipo_negocio = 'restaurante'`.

---

## 1. Extensiones a tablas existentes

### `restaurantes`

| Columna | Tipo | Default | Para qué |
|---------|------|---------|----------|
| `tipo_negocio` | enum | `'restaurante'` | Vertical primario |
| `subtipo` | `text` nullable | null | Plantilla UX (“ropa”, “aires”) |
| `modulos_extra` | `text[]` o jsonb | `{}` | Encender retail en un taller, etc. |

### `productos` (catálogo)

| Columna | Tipo | Para qué |
|---------|------|----------|
| `sku` | text nullable | Identificador interno |
| `codigo_barras` | text nullable | EAN/UPC; único por sucursal o restaurante |
| `maneja_variantes` | boolean default false | Si true, stock vive en variantes |
| `maneja_series` | boolean default false | Electrónica |
| `precio_compra` | numeric nullable | Margen retail simple (sin KYG) |

Índice: `(sucursal_id, codigo_barras)` unique where not null.

### `pedido_items`

| Columna | Tipo | Para qué |
|---------|------|----------|
| `variante_id` | uuid nullable FK | Venta retail |
| `serie_id` | uuid nullable FK | Venta con serie |

### Roles / permisos

Nuevos permisos sugeridos: `gestionar_ordenes_trabajo`, `asignar_tecnico`, `gestionar_variantes`, `escanear_venta`.  
Roles alias: `tecnico`, `vendedor` (o mapear desde existentes).

---

## 2. Tablas nuevas — Retail

### `producto_variantes`

```text
id, producto_id, sucursal_id
sku, codigo_barras
atributos jsonb  -- {"talla":"M","color":"negro"}
precio_venta, precio_compra  -- o heredar producto + override
stock_actual, stock_minimo
activo, created_at, updated_at
```

**Por qué:** stock real en retail es por combinación de atributos.

### `producto_series`

```text
id, producto_id, variante_id nullable, sucursal_id
numero_serie, imei nullable
estado: en_stock | reservado | vendido | en_taller
pedido_item_id nullable, garantia_hasta date nullable
```

**Por qué:** trazabilidad unitaria.

---

## 3. Tablas nuevas — Clientes (transversal)

### `clientes`

```text
id, restaurante_id  -- clientes de la marca; opcional sucursal_origen
nombre, telefono, email, documento, notas
activo, created_at
```

Ligar: `pedidos.cliente_id`, `cuentas_por_cobrar.cliente_id`, `ordenes_trabajo.cliente_id`.

**Por qué:** hoy el cliente está fragmentado; Treinta gana aquí.

---

## 4. Tablas nuevas — Servicios

### `ordenes_trabajo`

```text
id, sucursal_id, cliente_id
codigo (OT-0001), estado
descripcion_falla, diagnostico
equipo_nombre, equipo_marca, equipo_serie  -- o FK equipos_cliente
tecnico_id nullable (usuarios)
cotizacion_id nullable
total_mano_obra, total_repuestos, total  -- calculados en backend
anticipo, saldo
fechas: recibido_at, prometido_at, entregado_at
created_at, updated_at
```

Estados sugeridos:

`recibido → en_diagnostico → cotizado → aprobado → en_reparacion → listo → entregado`  
(+ `cancelado`, `rechazado`)

### `orden_trabajo_items`

```text
id, orden_id, tipo: mano_obra | repuesto | otro
descripcion, cantidad, precio_unitario, subtotal
inventario_item_id o producto_id / variante_id nullable  -- si repuesto
```

### `cotizaciones` (opcional separada o embebida)

```text
id, orden_id, estado, total, enviada_at, respondida_at, nota_cliente
```

### `citas`

```text
id, sucursal_id, cliente_id, orden_id nullable
inicio, fin, titulo, estado, tecnico_id
```

### `equipos_cliente` (opcional)

```text
id, cliente_id, tipo, marca, modelo, serie, notas
```

---

## 5. Inventario: dos modos

| Modo | Quién | Cómo descuenta |
|------|-------|----------------|
| **Insumos + recetas** | restaurante | Ya existe (pedido → ingredientes) |
| **Stock de producto/variante** | retail / general | Al vender ítem, −stock variante |
| **Repuestos** | servicios | Ítem OT tipo repuesto → −stock |

No fusionar a la fuerza insumos con SKU retail en Fase 1: son conceptos distintos. Un negocio puede tener ambos a largo plazo (panadería: receta + venta de empaque).

---

## 6. Config y código (sin migración)

Archivo nuevo sugerido:

`foody_backend/src/core/auth/modulos-por-tipo.config.ts`

```typescript
// Ilustrativo — no existe aún
MODULOS_POR_TIPO = {
  restaurante: ['inventario','costeo','cocina','mesas',...],
  retail: ['inventario','variantes_sku','reportes',...],
  servicios: ['inventario','ordenes_trabajo','agenda_citas',...],
  general: ['inventario','reportes',...],
}
```

Login / `/me` debe devolver:

```json
{
  "tipo_negocio": "retail",
  "modulos_activos": ["inventario", "variantes_sku", "reportes"],
  "terminologia": { "catalogo": "Catálogo", "venta": "Venta", ... }
}
```

---

## 7. Qué no tocar al inicio

- Renombrar `restaurantes` → `negocios`
- Eliminar tablas `mesas` / `cocinas`
- Cambiar semántica de `pedidos` de restaurante existente
- Forzar `variante_id` NOT NULL

---

## 8. Checklist de migración (cuando se ejecute)

1. Enum + columnas `restaurantes` (default seguro)
2. Seed: todos los demo quedan `restaurante`
3. `productos` sku/barcode nullable
4. `producto_variantes` + alterar `pedido_items`
5. `clientes` + FKs graduales
6. `ordenes_trabajo*` 
7. Guards + tests `scripts/verificar-multinegocio-*.ps1`
