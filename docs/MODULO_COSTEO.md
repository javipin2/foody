# Módulo de costeo industrial — Foody

> **Estado:** 🟡 Fase 1 motor implementada; UI admin en reorganización (`docs/ADMIN_MENU_COSTEO.md`)  
> **Fuente de negocio:** Fórmulas alineadas a `INFRAESTRUCTURA/TABLA DE COSTEOS KYG.xlsx` (**solo referencia**, sin importar datos)  
> **Decisiones menú + ítems incluidos (rosquetes):** `docs/ADMIN_MENU_COSTEO.md` — **prioridad** si hay conflicto con este archivo  
> **Base técnica existente:** Sprint 6 inventario (`foody_backend/src/modulos/inventario/`, `lib/features/inventario/`)  
> **Spec BD objetivo:** `INFRAESTRUCTURA/esquema_maestro_bd_v3.md` — Módulo 5 ERP Gastronómico  
> **Decisions log:** acordado en sesión 2026-06-07 (ver §2)

---

## 1. Resumen de 1 minuto

Foody ya tiene inventario básico (ingredientes, compras, recetas planas, `costo_calculado` simple). Este módulo **extiende** ese trabajo hacia un **motor de costeo industrial** alineado al Excel KYG y a la spec v3:

- Costo real con **merma/rendimiento**
- **Subrecetas** recursivas (teórico por defecto; producción en lote opcional)
- **Empaques domicilio** como costo extra sobre el costo base
- **Combos:** ganancia = `precio_fijo − suma(costos ítems) − empaques`
- **Alertas** de margen bajo (no auto-actualizar precios)
- **Multi-tenant:** cada sucursal su lista de mercado y recetas
- **Flutter = solo UI; NestJS = todos los cálculos**

**No replicar el Excel en la app** (layout horizontal, VLOOKUP). Migrar la **lógica** al backend.

---

## 2. Decisiones de producto (cerradas)

| Tema | Decisión |
|------|----------|
| Alcance | Multi-restaurante — cada sucursal carga/edita su costeo |
| Excel KYG | **Solo referencia** de fórmulas y procesos de costeo (merma, subrecetas, empaques). **No** importar datos del archivo; cada sucursal carga insumos/recetas manual en admin |
| Combos | Costo = **suma de `costo_calculado` de ítems** + empaques extra del combo |
| **Productos con ítems de menú incluidos** | Plato con precio propio que **arrastra** otros productos del menú (ej. huevo + 1 rosquete, carne + 2 rosquetes). Ver `docs/ADMIN_MENU_COSTEO.md` §2.2. Costo = receta plato + Σ(cantidad × costo_calculado incluido). **≠ combo.** |
| Ejecutivos / paquetes en carta | Si el cliente pide un solo ítem con incluidos → `producto_items_incluidos`. Si elige paquete con precio fijo → `combos`. |
| Bebidas incluidas | Mismo patrón que ítems incluidos (generalizar `producto_bebidas` → `producto_items_incluidos`) |
| Mesa vs domicilio | Un **costo base** + **empaques domicilio** extra (no dos recetas completas) |
| Margen de error | **Editable por receta** (Excel usa 5% por defecto) |
| Precio de venta | **Alerta** si margen baja; gerente decide; campo `precio_sugerido` informativo |
| Subrecetas | **Teórico por defecto**; flag opcional `usa_produccion_lote` por subreceta |
| Pedidos | **Sí** descontar inventario al confirmar (completar con subrecetas/empaques) |
| Fase 1 | Motor + UI manual — **sin** importar Excel (acuerdo producto 2026-06-08) |
| Permisos | Solo **admin** edita costeos; contador/otros roles en fases posteriores |

---

## 3. Qué cubre el Excel KYG (referencia de fórmulas — no importación)

> El archivo en `INFRAESTRUCTURA/TABLA DE COSTEOS KYG.xlsx` documenta **cómo** se calculan costos en el negocio de referencia. Foody replica la **lógica** en `CosteoService`; los datos reales los ingresa cada restaurante en la UI.

| Hoja | Contenido | Cantidad aprox. |
|------|-----------|-----------------|
| Lista de mercado | Proveedor, insumo, precio compra, peso bruto/neto, unidad, factor merma, costo real | ~187 insumos |
| Subrecetas | Preparaciones internas con rendimiento (gr/ml) y costo por unidad | ~40 |
| Platos | Receta + precio mesa/domicilio + empaques domicilio + márgenes | 20 |
| Bebidas | Misma estructura que platos (hoja preparada; datos escasos) | — |
| Popularidad Mesa/Domicilio | Simulador ventas × margen (planificación, no operación POS) | Fase 3 opcional |

**No cubre:** combos explícitos, toppings, todo el menú futuro, métodos FIFO/promedio avanzados.

### Procesos de costeo en el Excel (una sola fórmula, datos distintos)

| Proceso | Señal en Excel | `tipo_costeo` Foody |
|---------|----------------|---------------------|
| Por peso | Unidad `gr` | `peso` |
| Por pieza | Unidad `und` | `pieza` |
| Por volumen | Unidad `ml` | `peso` (unidad base ml) |
| Con merma | Factor H = bruto/neto (~65 insumos) | `rendimiento` + `rendimiento_porcentaje` |
| Subreceta en lote | Hoja Subrecetas → costo/und usado en plato | receta `tipo=subreceta` |
| Empaque domicilio | Bloque «Insumos de domicilio» en plato | `tipo_item=empaque` o receta canal |

---

## 4. Estado actual vs objetivo

### Implementado hoy (backend Fase 1)

| Pieza | Archivo / tabla | Notas |
|-------|-----------------|-------|
| Ingredientes CRUD | `inventario.service.ts`, `ingredientes` | Merma en `CosteoService` |
| Compras → cascada costo | `registrarCompra` + `recalcularSucursal` | — |
| Receta producto | `configurarRecetaProducto` | Ingrediente, subreceta, empaque |
| `CosteoService` | `foody_backend/src/modulos/costeo/` | Combos, `precio_sugerido`, alertas margen |
| Combos | `recalcularCombo` | `costo_calculado` en BD |
| Stock en pedido | `pedidos-inventario.service.ts` | Expande subrecetas; empaques en domicilio |
| UI admin costos | `inventario_admin_screen.dart` | **Reorganizar** según `ADMIN_MENU_COSTEO.md` |

### Pendiente (decisión producto 2026-06-08)

| Pieza | Descripción |
|-------|-------------|
| `producto_items_incluidos` | Huevo +1 rosquete, carne/hígado +2 rosquetes; costeo y stock en cascada |
| UI Menú ↔ Costos | Master-detail, slider margen, responsive |
| Precio local / para llevar | Campo opcional en producto + checkout |

### Objetivo del módulo

| Pieza | Descripción |
|-------|-------------|
| `CosteoService` | Motor central recursivo (NestJS) |
| Merma en costo unitario | `costo_real = costo_unitario × (100 / rendimiento_porcentaje)` |
| Subrecetas | Resolver `tipo_item=subreceta` → costo por gr/ml/und de subreceta |
| Empaques domicilio | Ítems extra en receta o líneas `empaque` sumadas al costo domicilio |
| Combos | `costo_combo`, `margen_combo`, alertas |
| `precio_sugerido` | `costo / (1 − margen_objetivo/100)` — solo sugerencia |
| Historial | `historial_costos_receta`, `margenes_venta` al vender |
| Alertas | `producto_margen_bajo`, `combo_margen_bajo`, `costo_ingrediente_subio` |

---

## 5. Fórmulas (backend — fuente de verdad)

Todas viven en **NestJS**. Flutter solo muestra resultados del API.

### 5.1 Ingrediente — costo unitario real

```
factor_merma     = peso_bruto / peso_neto   // equivalente Excel columna H
                 = 100 / rendimiento_porcentaje   // en BD

costo_por_unidad_base = precio_compra / cantidad_unidades_base_en_compra
costo_real            = costo_por_unidad_base × factor_merma
```

### 5.2 Línea de receta (ingrediente directo)

```
costo_linea = cantidad_en_receta × costo_real_ingrediente
```

### 5.3 Subreceta (modo teórico — default)

```
costo_total_subreceta = SUM(costos líneas ingredientes de la subreceta)
costo_con_margen      = costo_total_subreceta × (1 + margen_error_receta)
costo_por_unidad_resultado = costo_con_margen / cantidad_resultado   // ej. por gramo

costo_linea_en_plato = cantidad_usada × costo_por_unidad_resultado
```

### 5.4 Subreceta (modo producción en lote — opcional)

**Default recomendado:** modo teórico — al vender el plato se expanden insumos y se descuenta stock de mercado.

**Modo lote** (`usa_produccion_lote`): cocinas de antemano.

Al registrar producción (`POST /costeo/producciones`):

1. Descontar ingredientes de la subreceta del stock de mercado
2. Sumar `cantidad_producida` al stock del ingrediente-subreceta (`Prep:…`, `es_subreceta=true`)
3. Usar `costo_real_produccion / cantidad_producida` como costo unitario vigente
4. Al vender: descuenta solo `Prep:…` (no vuelve a tocar limón/azúcar)

`Prep:…` **no** aparece en lista de mercado ni en alertas de stock bajo (hasta que produzcas, el badge en subrecetas dice «Sin preparar», no «stock bajo»).

### 5.5 Plato — costo base y domicilio

```
costo_base     = SUM(costos líneas receta mesa) × (1 + margen_error_receta)
costo_domicilio = costo_base + SUM(costos líneas empaque domicilio)
```

### 5.6 Combo

```
costo_combo = Σ (producto.costo_calculado × cantidad)
            + Σ (bebida.costo_calculado × cantidad)      // si aplica
            + costo_empaques_combo
            + (subtotal × margen_error_combo si configurado)

ganancia_bruta    = precio_fijo − costo_combo
margen_porcentaje = ganancia_bruta / precio_fijo × 100
food_cost_%       = costo_combo / precio_fijo × 100
```

### 5.7 Producto con ítems de menú incluidos

> Spec: `docs/ADMIN_MENU_COSTEO.md` §2.2 y §3. Tabla objetivo: `producto_items_incluidos`.

```
costo_plato = costo_receta(plato)
            + Σ (cantidad_incluida × producto_incluido.costo_calculado)

-- Al vender: expandir receta del plato + recetas de cada incluido × cantidad
```

Ejemplo rosquetes: Huevo frito = costo(huevo) + 1 × costo(rosquete). Carne o hígado = costo(plato) + 2 × costo(rosquete).

### 5.8 Precio sugerido (informativo)

```
precio_sugerido = costo / (1 − margen_objetivo_sucursal / 100)
```

### 5.9 Al confirmar venta (histórico)

Insertar en `margenes_venta`: `precio_venta`, `costo_al_momento`, `food_cost_porcentaje`, `margen_bruto`, `margen_porcentaje`.

---

## 6. Modelo de datos — extensiones planificadas

Tablas que **ya existen** y se reutilizan: `ingredientes`, `presentaciones_compra`, `recetas`, `receta_items`, `costos_receta`, `combos`, `combo_items`, `productos`, `movimientos_ingrediente`, `producciones`.

### Migración propuesta `031_costeo_industrial.sql` (borrador)

```sql
-- Productos
ALTER TABLE productos
  ADD COLUMN IF NOT EXISTS precio_sugerido numeric(12,2),
  ADD COLUMN IF NOT EXISTS costo_domicilio numeric(12,2),
  ADD COLUMN IF NOT EXISTS incluye_bebida_en_receta bool DEFAULT false,
  ADD COLUMN IF NOT EXISTS margen_objetivo numeric(5,2);  -- opcional por producto

-- Recetas
ALTER TABLE recetas
  ADD COLUMN IF NOT EXISTS tipo text DEFAULT 'producto'
    CHECK (tipo IN ('producto', 'subreceta', 'empaque')),
  ADD COLUMN IF NOT EXISTS margen_error numeric(5,4) DEFAULT 0.05,
  ADD COLUMN IF NOT EXISTS cantidad_resultado numeric(18,3),
  ADD COLUMN IF NOT EXISTS unidad_resultado text,
  ADD COLUMN IF NOT EXISTS usa_produccion_lote bool DEFAULT false,
  ADD COLUMN IF NOT EXISTS canal text DEFAULT 'mesa'
    CHECK (canal IN ('mesa', 'domicilio', 'ambos'));

-- Combos
ALTER TABLE combos
  ADD COLUMN IF NOT EXISTS costo_calculado numeric(12,2),
  ADD COLUMN IF NOT EXISTS margen_error numeric(5,4) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS costo_empaque_extra numeric(12,2) DEFAULT 0;

-- Costos receta (alinear con spec v3)
ALTER TABLE costos_receta
  ADD COLUMN IF NOT EXISTS sucursal_id uuid REFERENCES sucursales(id),
  ADD COLUMN IF NOT EXISTS costo_ingredientes numeric(12,2),
  ADD COLUMN IF NOT EXISTS costo_subrecetas numeric(12,2),
  ADD COLUMN IF NOT EXISTS costo_empaques numeric(12,2),
  ADD COLUMN IF NOT EXISTS costo_merma numeric(12,2),
  ADD COLUMN IF NOT EXISTS food_cost_porcentaje numeric(5,2);

-- Config sucursal
ALTER TABLE sucursales
  ADD COLUMN IF NOT EXISTS margen_objetivo_default numeric(5,2) DEFAULT 35,
  ADD COLUMN IF NOT EXISTS umbral_alerta_margen numeric(5,2) DEFAULT 25;
```

### Campos clave por entidad

| Entidad | Campos de costeo |
|---------|------------------|
| `ingredientes` | `tipo_costeo`, `rendimiento_porcentaje`, `costo_unitario_actual`, `es_subreceta` |
| `recetas` | `tipo`, `margen_error`, `cantidad_resultado`, `usa_produccion_lote` |
| `receta_items` | `tipo_item` (ingrediente \| subreceta \| empaque), `cantidad`, `unidad` |
| `productos` | `costo_calculado`, `costo_domicilio`, `precio_sugerido`, `receta_id` |
| `combos` | `precio_fijo`, `costo_calculado` |

---

## 7. API planificada (NestJS)

Extender módulo `inventario` o crear `foody_backend/src/modulos/costeo/`.

| Método | Ruta | Permiso | Descripción |
|--------|------|---------|-------------|
| GET | `/costeo/resumen/:sucursal_id` | `ver_inventario` | Dashboard: food cost, productos bajo margen, combos |
| GET | `/costeo/productos/:sucursal_id` | `ver_inventario` | Lista con costo_base, costo_domicilio, margen, precio_sugerido |
| GET | `/costeo/productos/:id/detalle` | `ver_inventario` | Desglose líneas de receta con costos |
| PATCH | `/costeo/productos/:id/margen-objetivo` | `editar_inventario` | Margen objetivo por producto |
| GET | `/costeo/combos/:sucursal_id` | `ver_inventario` | Combos con costo_calculado y margen |
| POST | `/costeo/combos/:id/recalcular` | `editar_inventario` | Forzar recálculo combo |
| POST | `/costeo/recetas` | `editar_inventario` | CRUD subreceta (ingredientes + rendimiento + margen_error) |
| GET | `/costeo/recetas/:id` | `ver_inventario` | Subreceta con costo por unidad resultado |
| POST | `/costeo/producciones` | `editar_inventario` | Registrar lote (solo si `usa_produccion_lote`) |
| POST | `/costeo/recalcular/:sucursal_id` | `editar_inventario` | Recalcular toda la sucursal (mantenimiento) |

Endpoints existentes a **extender** (no duplicar):

- `PATCH /inventario/:id` → disparar recálculo en cascada con merma
- `POST /inventario/producto-ingredientes` → soportar subrecetas y empaques
- `GET /inventario/costos/:sucursal_id` → enriquecer con costo_domicilio y combos

---

## 8. Flutter — pantallas planificadas

Extender `lib/features/inventario/` (no crear app paralela).

| Pantalla / tab | Contenido |
|----------------|-----------|
| **Lista de mercado** (tab o sub-ruta) | Ingredientes: compra, merma %, costo real, presentaciones |
| **Subrecetas** | Editor tipo Excel: ingredientes, rinde X gr, margen error, costo/gr |
| **Receta plato** | Mejorar editor actual: ingredientes + subrecetas + flag bebida incluida |
| **Empaques domicilio** | Sección en receta o tab «Domicilio» por producto |
| **Márgenes** | Tabla productos + combos: costo, precio, margen %, food cost, precio sugerido, alertas |
| **Simulador popularidad** | **Fase 3** — opcional; no bloquea operación |

**Reglas UI:** sin fórmulas en Dart; botón «Aplicar precio sugerido» → `PATCH` producto vía catálogo.

---

## 9. Integración con pedidos e inventario

Al `POST /pedidos` (transacción existente):

1. Por cada ítem producto: descontar receta del plato + **ítems de menú incluidos** (`producto_items_incluidos`, pendiente) expandidos por cantidad
2. Si `tipo=domicilio` o para llevar: descontar empaques de la receta
3. Por cada combo: expandir `combo_items` y descontar recetas de cada componente + empaques combo
4. Insertar `margenes_venta` por línea con costo al momento
5. Si margen bajo umbral → alerta

Archivos a tocar: `pedidos-inventario.service.ts`, `pedidos.service.ts`, nuevo `costeo.service.ts`.

---

## 10. Casos borde documentados

| Caso | Riesgo | Solución |
|------|--------|----------|
| Combo con producto que ya incluye otros ítems de menú | Doble conteo en combo | Al armar combo, usar costo del ítem sin re-expandir incluidos, o flag en combo_item; ver `ADMIN_MENU_COSTEO.md` |
| Plato con ítems incluidos (rosquetes) | Confundir con combo | Usar `producto_items_incluidos`, no `combos` |
| Promo combo precio_fijo < costo | Margen negativo | Alerta `combo_margen_bajo`; no bloquear venta |
| Subreceta referenciada por nombre (Excel VLOOKUP) | Duplicados por typo | BD usa UUID; UI con autocomplete de ingredientes/subrecetas |
| Ingrediente sube >15% | Pérdida de margen silenciosa | Alerta `costo_ingrediente_subio` + recálculo cascada |
| Toppings en pedido | Margen real vs catálogo | Fase 2: costo topping en `margenes_venta` por línea |

---

## 11. Plan de implementación por fases

### Fase 1 — Motor + UI manual (prioridad acordada)

1. Migración `031_costeo_industrial.sql`
2. `CosteoService`: merma, subrecetas recursivas, margen_error por receta
3. Extender `configurarRecetaProducto` (subrecetas + empaques domicilio)
4. Cálculo combo (suma ítems + empaques)
5. `precio_sugerido` + alertas margen (sin auto-precio)
6. Flutter: tabs subrecetas + márgenes productos/combos
7. Completar descuento stock en pedido con expansión recetas

**Criterio de listo:** configurar un plato manualmente y obtener margen coherente con las fórmulas del Excel de referencia (tolerancia ±2% por redondeo).

### Fase 2 — Mejoras opcionales (sin import Excel)

- Producción en lote UI (`usa_produccion_lote`)
- FIFO / costo promedio ponderado
- Toppings en margen por pedido
- Rol contador (solo lectura reportes)

~~Fase 2 — Importación KYG~~ **Descartada:** no se importará el Excel; solo sirvió para definir fórmulas.

### Fase 3 — Opcional

- Simulador popularidad (hojas Popularidad Mesa/Domicilio)
- Producción en lote UI
- FIFO / costo promedio ponderado
- Rol contador (solo lectura reportes)
- Toppings en margen por pedido

---

## 12. Permisos

| Acción | Rol Fase 1 |
|--------|------------|
| Ver costos y márgenes | `ver_inventario` (admin, gerente si se habilita después) |
| Editar ingredientes, recetas, subrecetas | `editar_inventario` (**solo admin** por ahora) |
| Aplicar precio sugerido al menú | `editar_productos` |
| Importar Excel | `editar_inventario` + admin |

---

## 13. Referencia Excel → Foody (mapeo)

| Excel | Foody |
|-------|-------|
| Lista de mercado / Insumos | `ingredientes` + `presentaciones_compra` |
| Factor corrección H | `rendimiento_porcentaje` (= 100/H×100) |
| Costo real I | `costo_unitario_actual` (ya con merma) |
| Hoja Subrecetas | `recetas` tipo `subreceta` |
| Cantidad obtenida I3 | `cantidad_resultado` |
| Margen error L6 | `recetas.margen_error` |
| Hoja Platos bloque B… | `productos` + `recetas` + `receta_items` |
| Insumos de domicilio F28+ | `receta_items` tipo `empaque` canal domicilio |
| Precio I2 / K2 | `productos.precio` (+ precio domicilio futuro si difiere) |
| Combo menú Foody | `combos` + suma costos (no existe en Excel) |

---

## 14. Archivos a crear/modificar (checklist dev)

### Backend

- [ ] `foody_backend/src/modulos/costeo/costeo.module.ts`
- [ ] `foody_backend/src/modulos/costeo/costeo.service.ts`
- [ ] `foody_backend/src/modulos/costeo/costeo.controller.ts`
- [ ] `foody_backend/src/modulos/costeo/dto/*.ts`
- [ ] Extender `inventario.service.ts` — delegar cálculo a `CosteoService`
- [ ] Extender `pedidos-inventario.service.ts`
- [ ] `foody_supabase/migrations/031_costeo_industrial.sql`

### Flutter

- [ ] `lib/features/inventario/data/costeo_repository.dart`
- [ ] `lib/features/inventario/presentation/costeo_margenes_screen.dart`
- [ ] `lib/features/inventario/presentation/subrecetas_admin_screen.dart`
- [ ] Extender `inventario_admin_screen.dart` — navegación a nuevas tabs
- [ ] `app_router.dart` — rutas si aplica

### Fase 2 (opcional)

- [ ] Producción en lote, FIFO, toppings en margen (ver §11)

### Documentación

- [x] `docs/MODULO_COSTEO.md` (este archivo)
- [ ] Actualizar `INFRAESTRUCTURA/endpoints_api_foody.md` al implementar
- [ ] Actualizar `docs/AVANCE_PROYECTO.md` al cerrar cada fase

---

## 15. Pruebas de aceptación (Fase 1)

1. Crear ingrediente «pollo» con rendimiento 80% → costo real > costo compra proporcional
2. Crear subreceta «Salsa maquia» con 3 ingredientes → `costo_por_gramo` calculado
3. Crear plato con subreceta + empaque domicilio → `costo_calculado` y `costo_domicilio` distintos
4. Crear combo 2 ítems → `costo_calculado` = suma; margen % correcto
5. Compra que sube pollo 20% → recálculo cascada platos + alerta
6. `POST /pedidos` → movimientos inventario coherentes con receta
7. Margen bajo umbral → alerta en panel admin

---

## 16. Enlaces

- Excel referencia: `INFRAESTRUCTURA/TABLA DE COSTEOS KYG.xlsx`
- Spec BD: `INFRAESTRUCTURA/esquema_maestro_bd_v3.md` (Módulo 5)
- Inventario actual: `foody_backend/src/modulos/inventario/inventario.service.ts`
- Avance vivo: `docs/AVANCE_PROYECTO.md`
