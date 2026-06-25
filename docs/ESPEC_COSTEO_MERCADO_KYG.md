# Especificación — Mercado, Insumos y Costeo (basado en Excel KYG)

> **Documento maestro de implementación.** Derivado del análisis hoja por hoja de
> `INFRAESTRUCTURA/TABLA DE COSTEOS KYG.xlsx` (8 hojas, 2026-06-08).
> **Objetivo:** que un dueño de restaurante registre **lo que compra** (mercado),
> el sistema calcule **el precio por unidad/kilo real** y, a partir de eso, el
> **costo de cada subreceta, plato y bebida** — incluyendo mesa vs domicilio.
>
> **Relacionados (no contradecir):** `docs/MODULO_COSTEO.md` (fórmulas motor),
> `docs/ADMIN_MENU_COSTEO.md` (orden del panel), `INFRAESTRUCTURA/esquema_maestro_bd_v3.md`.
> **Reglas de oro Foody:** Flutter = solo UI. NestJS + PostgreSQL = todos los cálculos.

---

## 0. Resumen de 1 minuto

El Excel KYG es, en realidad, un **sistema de costeo profesional** con 4 capas encadenadas:

```
1) LISTA DE MERCADO  → cada insumo: precio de compra, peso bruto, peso neto, unidad
                       → deriva: costo por unidad y COSTO REAL por unidad (con merma)

2) SUBRECETAS        → mezclas (salsas, bases) hechas con insumos de mercado
                       → deriva: costo por gramo/ml de la subreceta

3) PLATOS            → usan insumos de mercado + subrecetas
                       → costo MESA y costo DOMICILIO (empaques + comisión + mano de obra)
                       → utilidad y margen por canal

4) BEBIDAS           → igual que platos (empaques de bebida)

(+ POPULARIDAD Mesa/Domicilio → análisis de ventas / ingeniería de menú — opcional)
```

**Lo que hoy falta en Foody** (ver §4 y §10):
- Insumo en **«modo mercado»**: capturar precio de compra + peso bruto + peso neto y que el
  sistema calcule el costo real por unidad (hoy se escribe el costo a mano).
- **Editar precio** de un insumo desde la lista (hoy solo «registrar compra» o crear).
- Plato/bebida con **% comisión de plataforma**, **% impuesto** y **mano de obra** por canal.
- Avisos cuando un costo depende de otro sin calcular (ej. plato incluye rosquete sin receta).

---

## 1. Análisis del Excel — hoja por hoja (estado real)

### 1.1 Hoja «Lista de mercado» (867 filas)

Columnas reales (A–I):

| Col | Encabezado | Significado | Cómo se obtiene |
|-----|-----------|-------------|-----------------|
| A | Proveedor | Dónde se compró (mercado, Éxito, Makro, "Que menú"…) | Manual |
| B | Insumos | Nombre del insumo | Manual |
| C | Precio de compra | Lo que pagó por la presentación | **Manual** |
| D | Peso bruto | Cantidad total de la presentación (con cáscara/empaque) | **Manual** |
| E | Peso neto | Cantidad **aprovechable** (sin merma) | **Manual** |
| F | Unidad de medida | `gr`, `ml`, `und` | **Manual** |
| G | Costo unidad | Costo por unidad bruta | `= C / D` |
| H | Factor de corrección | Cuánto se "encarece" por la merma | `= D / E` |
| I | **Costo real x unidad** | Costo por unidad **aprovechable** | `= G × H` ( = `C / E` ) |

**Ejemplos reales del archivo:**

| Insumo | Precio | Bruto | Neto | Und | Costo unidad (G) | Factor (H) | Costo real (I) |
|--------|-------:|------:|-----:|:---:|----------------:|-----------:|---------------:|
| comino | 8.000 | 500 | 500 | gr | 16 | 1.00 | **16** |
| carne | 30.000 | 1.000 | 900 | gr | 30 | 1.111 | **33,33** |
| pollo | 10.000 | 1.000 | 800 | gr | 10 | 1.25 | **12,50** |
| lechuga | 4.400 | 1.000 | 700 | gr | 4,4 | 1.428 | **6,29** |
| aceite | 6.000 | 1.000 | 950 | ml | 6 | 1.052 | **6,32** |
| mayonesa | 73.100 | 3.795 | 3.785 | gr | 19,26 | 1.003 | **19,31** |

> **Insight clave:** el "precio por kilo/gramo" que importa para costear **no** es el de la
> factura (peso bruto), sino el **costo real por unidad neta** (`C / E`), porque parte del
> producto se pierde (cáscara, hueso, recorte). Eso es exactamente lo que pide el usuario.

**Insumos especiales detectados:**
- Algunos insumos son en realidad **producto de una subreceta** (ej. `salsa maquia` con
  costo `7,98/gr`): su "costo real" viene de la hoja Subrecetas, no de una compra directa.
- Hay **mano de obra / servicios** embebidos como ítems (ej. `vendedor` a 1.000 c/u en
  domicilio) → en Foody = insumo **«solo costo»** (`descontar_stock = false`).
- Hay **empaques** (p3, servilletas, tenedores, envase, bolsa, sopero) → insumos `und`
  que solo aplican a domicilio/para llevar.

### 1.2 Hoja «Subrecetas» (bloques horizontales, ~13 columnas c/u)

Cada subreceta es un bloque independiente. Ej. `SALSA MAQUIA`:

| Campo | Valor ejemplo | Fórmula |
|-------|--------------|---------|
| Nombre | SALSA MAQUIA | — |
| Cantidad obtenida | 2.700 gr | Manual (rinde 2.700 g) |
| Margen de error | 0,05 (5%) | Manual |
| Insumos (líneas) | perejil, cebollín, pimentón… | Cantidad estándar + Costo real (de mercado) |
| Costo de producción línea | `= cantidad_estándar × costo_real` | |
| Costo total de insumos | 20.527,6 | `SUM(líneas)` |
| Margen de error ($) | 1.026,4 | `= total × 0,05` |
| **Costo total de producción** | 21.554 | `= total + margen` |
| **Costo por gramo** | 7,98 | `= costo_total_producción / cantidad_obtenida` |

> Ese `7,98/gr` es lo que después aparece como **"Costo real"** de `salsa maquia` cuando se
> usa dentro de un plato. **Es recursivo:** subreceta → insumo de otro plato/subreceta.

### 1.3 Hoja «Platos» (~20 platos, bloques de ~13 columnas)

Platos detectados: PECHUGA ASADA, CERDO ASADO, CARNE ASADA, CHURRASCO (POLLO/CERDO/RES),
ALITAS BBQ, COSTILLITAS BBQ, POLLO BROSTHER, POLLO ASADO, SANCOCHO DE MONDONGO,
EJECUTIVOS (varios), FRIJOLADA, ARROZ MIXTO, PIZZAS.

Estructura de cada plato:

| Sección | Campos | Fórmula |
|---------|--------|---------|
| Cabecera | Precio venta público, Precio domicilio | Manual |
| | Impuesto sobre la venta (%) | Manual (ej. 0 u 8%) |
| | Comisión plataforma (%) | Manual (ej. 30% domicilio) |
| | Precio bruto = `precio / (1 + impuesto)` | |
| | Cantidad a producir (1), Margen de error (5%) | Manual |
| Insumos | Cantidad estándar, Und, Costo real, Costo producción | `costo_prod = cant × costo_real` |
| Insumos de domicilio | empaques + `vendedor` (mano de obra) | Solo canal domicilio |
| **MESA** | Costo total ins. → + margen error → Costo total prod. | |
| | Utilidad bruta = `precio_bruto − costo_total_prod` | |
| | Margen ut. bruta = `utilidad / precio_bruto` | |
| **DOMICILIO** | Costo total ins. **+ empaques + valor comisión** | `valor_comisión = precio × %comisión` |
| | Utilidad y margen domicilio (igual fórmula con sus costos) | |

**Ejemplo PECHUGA ASADA (mesa):** precio venta 16.500, impuesto 0 → precio bruto 16.500;
costo total producción ≈ 7.197,8 → utilidad 9.302,2 → **margen 56,4%**.
**Domicilio:** mismo plato pero costo total prod ≈ 10.883,5 (empaques + comisión) →
utilidad 5.616,5 → **margen 34%**.

### 1.4 Hoja «Bebidas» (misma estructura que Platos)

Ej. bebida: precio mesa 4.000 (impuesto 8% → bruto 3.703,7), domicilio 5.500
(comisión 30% → valor comisión 1.650). Empaques: `vaso de cartón`, `tapa vaso`.

### 1.5 Hojas «Hoja1», «Hoja2»

Vacías. Ignorar.

### 1.6 Hojas «Popularidad Mesa» / «Popularidad Domicilio»

Plantillas de **ingeniería de menú** (análisis ABC: qué tan popular y rentable es cada
plato). En el archivo están vacías (se llenan con ventas). **Opcional / Fase 3** — el
backend Foody ya tiene los datos de ventas para generarlas automáticamente.

---

## 2. Modelo conceptual objetivo (cómo lo piensa el dueño)

```
┌─────────────────────────────────────────────────────────────┐
│  SECCIÓN «MERCADO / INSUMOS»  (lo que compro)                 │
│  Por cada insumo registro:                                    │
│    proveedor · nombre · precio compra · peso bruto ·          │
│    peso neto · unidad                                         │
│  El sistema CALCULA y guarda:                                 │
│    costo_por_unidad      = precio / peso_bruto                │
│    factor_correccion     = peso_bruto / peso_neto             │
│    costo_real_unidad     = precio / peso_neto   ← se usa para costear │
└─────────────────────────────────────────────────────────────┘
            │ (costo_real_unidad)
            ▼
┌─────────────────────────────────────────────────────────────┐
│  SUBRECETAS  (mezclas: salsas, bases, marinados)             │
│   costo_total = Σ(cantidad × costo_real_unidad)              │
│   + margen_error %                                            │
│   costo_por_unidad_resultado = costo_total / cantidad_obtenida│
└─────────────────────────────────────────────────────────────┘
            │ (costo por gr/ml de la subreceta = otro "costo_real")
            ▼
┌─────────────────────────────────────────────────────────────┐
│  PLATOS / BEBIDAS                                             │
│   costo_mesa      = Σ insumos + subrecetas + margen_error     │
│   costo_domicilio = costo_mesa + empaques + mano_obra         │
│                     + comisión_plataforma                     │
│   utilidad   = precio_bruto − costo                           │
│   margen %   = utilidad / precio_bruto                        │
│   precio_bruto = precio_venta / (1 + impuesto)                │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Fórmulas (fuente de verdad — implementar en NestJS)

> Todas en backend. Flutter solo muestra strings ya formateados.

### 3.1 Insumo (modo mercado)

```
costo_por_unidad   = precio_compra / peso_bruto
factor_correccion  = peso_bruto / peso_neto              (≥ 1; si no hay merma = 1)
costo_real_unidad  = costo_por_unidad × factor_correccion   = precio_compra / peso_neto
rendimiento_pct    = (peso_neto / peso_bruto) × 100         (inverso del factor)
```

Equivalencia con BD actual: `costo_unitario_actual = costo_real_unidad`,
`rendimiento_porcentaje = rendimiento_pct`. (El motor ya aplica merma vía rendimiento.)

### 3.2 Subreceta

```
PARA cada línea:  costo_linea = cantidad_estandar × costo_real_unidad(insumo)
costo_total_insumos          = Σ costo_linea
costo_con_margen             = costo_total_insumos × (1 + margen_error)
costo_por_unidad_resultado   = costo_con_margen / cantidad_obtenida
```

### 3.3 Plato / Bebida — MESA

```
costo_insumos_mesa  = Σ (cantidad × costo_real_unidad | costo_por_unidad_resultado)
costo_mesa          = costo_insumos_mesa × (1 + margen_error)
precio_bruto_mesa   = precio_venta_mesa / (1 + impuesto_pct)
utilidad_mesa       = precio_bruto_mesa − costo_mesa
margen_mesa_pct     = utilidad_mesa / precio_bruto_mesa × 100
```

### 3.4 Plato / Bebida — DOMICILIO / PARA LLEVAR

```
costo_empaques      = Σ (cantidad × costo_real_unidad)   [insumos tipo empaque]
costo_mano_obra     = Σ (insumos «solo costo» del canal, ej. vendedor)
valor_comision      = precio_domicilio × comision_plataforma_pct
precio_bruto_dom    = precio_domicilio / (1 + impuesto_pct)
costo_domicilio     = costo_mesa + costo_empaques + costo_mano_obra + valor_comision
utilidad_dom        = precio_bruto_dom − costo_domicilio
margen_dom_pct      = utilidad_dom / precio_bruto_dom × 100
```

### 3.5 Producto con ítems de menú incluidos (rosquetes)

```
costo_incluidos     = Σ (cantidad × costo_calculado(producto_incluido))
costo_mesa_total    = costo_mesa + costo_incluidos
costo_dom_total     = costo_domicilio + costo_incluidos_domicilio
```

> Si `costo_calculado(producto_incluido)` es `NULL` (sin receta) → cuenta **0** y se debe
> **avisar** (ver §7.4). Orden correcto: costear primero el rosquete.

### 3.6 Precio sugerido (a partir de margen objetivo)

```
precio_sugerido = costo / (1 − margen_objetivo_pct / 100)
```

---

## 4. Cambios de base de datos (migraciones)

Estado actual (`006_inventario.sql` + 032/033/034/036):
- `ingredientes(unidad_base, tipo_costeo, rendimiento_porcentaje, costo_unitario_actual,
  stock_actual, stock_minimo, descontar_stock)` ✅
- `presentaciones_compra`, `compras_inventario`, `compra_items` ✅
- `recetas`, `receta_items(tipo_item ingrediente|subreceta|empaque)`, `costos_receta` ✅
- `producto_items_incluidos` ✅
- `productos(precio, precio_para_llevar, costo_calculado, costo_domicilio, precio_sugerido,
  margen_objetivo, receta_id)` ✅

### 4.1 Migración `037_insumo_modo_mercado.sql`

Guardar los campos crudos de la "lista de mercado" para poder recalcular y mostrar.

```sql
ALTER TABLE ingredientes
  ADD COLUMN IF NOT EXISTS proveedor text,
  ADD COLUMN IF NOT EXISTS precio_compra numeric(12,2),
  ADD COLUMN IF NOT EXISTS peso_bruto numeric(12,3),
  ADD COLUMN IF NOT EXISTS peso_neto numeric(12,3),
  ADD COLUMN IF NOT EXISTS categoria_insumo text
    CHECK (categoria_insumo IN ('alimento','empaque','mano_obra','servicio'))
    DEFAULT 'alimento';

COMMENT ON COLUMN ingredientes.precio_compra IS 'Precio pagado por la presentación (peso bruto)';
COMMENT ON COLUMN ingredientes.peso_bruto IS 'Cantidad total comprada (con merma)';
COMMENT ON COLUMN ingredientes.peso_neto IS 'Cantidad aprovechable; deriva costo real y rendimiento';
```

> El backend, al crear/editar en modo mercado, calcula:
> `costo_unitario_actual = precio_compra / peso_neto` y
> `rendimiento_porcentaje = peso_neto / peso_bruto × 100`.

### 4.2 Migración `038_receta_costeo_avanzado.sql`

Soporte de cantidad obtenida y margen de error en subrecetas/recetas.

```sql
ALTER TABLE recetas
  ADD COLUMN IF NOT EXISTS cantidad_obtenida numeric(12,3),   -- ej. 2700
  ADD COLUMN IF NOT EXISTS unidad_resultado text,             -- gr / ml / und
  ADD COLUMN IF NOT EXISTS margen_error numeric(5,4) DEFAULT 0.05;
```

> Verificar primero si 032/033 ya añadieron `cantidad_resultado`/`unidad_resultado`
> (ver `MODULO_COSTEO.md`). Si existen con otro nombre, **no duplicar**: ajustar el motor.

### 4.3 Migración `039_producto_canal_domicilio.sql`

Parámetros de venta por canal (impuesto, comisión, utilidad/margen calculados).

```sql
ALTER TABLE productos
  ADD COLUMN IF NOT EXISTS impuesto_pct numeric(5,4) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS comision_plataforma_pct numeric(5,4) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS utilidad_mesa numeric(12,2),
  ADD COLUMN IF NOT EXISTS margen_mesa_pct numeric(6,2),
  ADD COLUMN IF NOT EXISTS utilidad_domicilio numeric(12,2),
  ADD COLUMN IF NOT EXISTS margen_domicilio_pct numeric(6,2);
```

> `costo_domicilio` ya existe (empaques). Aquí se añade comisión + impuesto + resultados
> persistidos para mostrar en «Costos».

---

## 5. Sección «Mercado / Insumos» — especificación UI

Pantalla `InventarioAdminScreen`, tab **«Insumos»** (lista de mercado).

### 5.1 Lista

Cada insumo muestra: nombre · proveedor · **costo real por unidad** (`$/gr`, `$/kg`, `$/und`)
· stock · badge de categoría (Alimento / Empaque / Mano de obra).

Acciones por insumo (menú ⋮):
- **Editar** (nombre, proveedor, modo de costo) ← **NUEVO** (hoy no existe editar precio).
- **Registrar compra** (actualiza costo por promedio ponderado).
- **Ajustar stock** (conteo/merma).

### 5.2 Diálogo «Nuevo / Editar insumo» — 2 modos

**Modo A — Mercado (recomendado, replica el Excel):**

| Campo | Tipo | Ejemplo |
|-------|------|---------|
| Nombre | texto | cebolla blanca |
| Proveedor | texto (opcional) | mercado |
| Precio de compra | número | 3.200 |
| Peso bruto | número | 1.000 |
| Peso neto (aprovechable) | número | 900 |
| Unidad | selector gr / kg / ml / L / und | gr |

→ Bajo los campos, **vista previa en vivo** (calculada en cliente solo para mostrar, el
valor oficial lo confirma el backend al guardar):

```
Costo por unidad:  $3,56/gr      (precio / bruto)
Factor corrección: 1,11          (bruto / neto)
Costo real:        $3,56/gr      (precio / neto)   ← este se usa para costear
```

**Modo B — Solo costo (mano de obra / gas fijo):**

| Campo | Ejemplo |
|-------|---------|
| Nombre | mano de obra |
| Costo por plato | 1.000 |

→ `descontar_stock = false`, `categoria_insumo = 'mano_obra'`, sin peso ni stock.

### 5.3 Regla de "precio por kilo" intuitivo

Para evitar el problema del demo (`0,025/g`):
- Si el usuario elige unidad **kg** y peso en kg, el costo se muestra **$/kg**.
- Internamente se normaliza a la unidad base (g o ml) para recetas, pero la UI siempre
  muestra en la unidad que el usuario eligió.
- Recomendación de copy: «Pon el precio tal como lo compras (ej. bulto de papa 25 kg a
  $40.000)». El sistema saca el $/kg y el $/g solo.

---

## 6. Endpoints API (NestJS)

> Prefijo según `main.ts`. Respuestas `{ exito, datos, mensaje }`.

### 6.1 Insumos / Mercado

| Método | Ruta | Cuerpo / efecto |
|--------|------|-----------------|
| GET | `/inventario/:sucursal_id` | Lista insumos con `costo_unitario_actual`, `costo_real`, `proveedor`, `categoria_insumo` |
| POST | `/inventario` | Crear. Acepta **modo mercado** (`precio_compra`,`peso_bruto`,`peso_neto`,`unidad_base`) → backend deriva costo/rendimiento; o **modo solo costo** |
| PATCH | `/inventario/:id` | **Editar** insumo (nombre, proveedor, precio_compra, pesos, costo). Recalcula costo y dispara cascada |
| POST | `/inventario/:id/compra` | Registrar compra (promedio ponderado) |
| PATCH | `/inventario/:id/stock` | Ajuste / conteo |

> **PATCH editar es NUEVO.** Al cambiar `precio_compra`/`peso_neto`, el backend recalcula
> `costo_unitario_actual` y ejecuta `recalcularSucursal` (cascada a subrecetas y platos).

### 6.2 Subrecetas

| Método | Ruta | Efecto |
|--------|------|--------|
| GET | `/costeo/subrecetas/:sucursal_id` | Lista con `costo_por_unidad_resultado` |
| POST | `/costeo/subrecetas` | Crear/editar (nombre, cantidad_obtenida, unidad_resultado, margen_error, líneas) |
| POST | `/costeo/subrecetas/:id/recalcular` | Recalcular costo |

### 6.3 Platos / Bebidas (costeo)

| Método | Ruta | Efecto |
|--------|------|--------|
| GET | `/costeo/resumen/:sucursal_id` | Productos con costo_mesa, costo_domicilio, utilidad/margen por canal |
| POST | `/inventario/producto-ingredientes` | Guardar receta del producto (ingrediente/subreceta/empaque) |
| PATCH | `/productos/:id` | Precio mesa/llevar, impuesto_pct, comision_plataforma_pct, margen_objetivo |
| GET/PUT | `/productos/:id/items-incluidos` | Productos del menú incluidos (rosquetes) |
| POST | `/costeo/productos/:id/recalcular` | Recalcular un producto |
| POST | `/costeo/recalcular/:sucursal_id` | Recalcular toda la sucursal (cascada) |

---

## 7. Flujo de usuario (real, sin datos demo)

### 7.1 Preparar el restaurante (una vez)

1. **(Opcional) Borrar datos demo**: ejecutar limpieza o empezar sucursal vacía
   (ver §9). Así no aparecen «Carne molida (demo)» con precios falsos.
2. **Mercado → Insumos**: cargar la lista de compras tal como en el Excel.
   - Por cada insumo: precio de compra + peso bruto + peso neto + unidad.
   - Mano de obra, gas, domiciliario → **«solo costo»**.
   - Empaques (bolsa, envase, servilletas) → categoría **empaque**.

### 7.2 Subrecetas (si las hay: salsas, marinados, bases)

3. **Costos → Subrecetas → Nueva**:
   - Nombre, cantidad obtenida (ej. 2.700 gr), margen error 5%.
   - Líneas: insumo + cantidad. El costo real lo toma de Insumos.
   - Guardar → queda `costo por gramo` listo para usar en platos.

### 7.3 Platos y bebidas

4. **Menú → Nuevo producto**: nombre + precio mesa (+ precio llevar opcional).
5. **Costos → seleccionar producto → «Qué cuesta hacerlo»**:
   - Agregar líneas: escribir insumo (autocompletar) + cantidad.
   - Subrecetas: elegir «Preparación previa».
   - Empaques: marcar «Empaque solo si es para llevar».
   - Mano de obra del canal: insumo «solo costo».
   - Guardar receta.
6. **(Si aplica) «Qué va incluido»**: agregar productos del menú que van gratis
   (ej. Hígado → 2× Rosquete). *Requiere que el Rosquete ya esté costeado.*
7. **Cabecera de Costos**: ver costo mesa/domicilio, utilidad y margen por canal;
   ajustar **impuesto %**, **comisión plataforma %**, **margen objetivo** y, si se desea,
   **aplicar precio sugerido**.

### 7.4 Avisos de dependencia (NUEVO — evita errores reales)

- Plato incluye producto sin receta → **«Rosquete sin costeo: cuenta $0. Cárgale receta.»**
- Receta usa insumo con `costo = 0` → marcar la línea en ámbar.
- Subreceta sin `cantidad_obtenida` → no puede dividir → avisar.

---

## 8. Reglas de negocio (resumen ejecutable)

| Regla | Valor por defecto | Editable |
|-------|-------------------|----------|
| Margen de error subreceta/plato | 5% (0,05) | Sí |
| Impuesto sobre la venta | 0% (config fiscal por sucursal) | Sí |
| Comisión plataforma domicilio | 0% (ej. 30% si usa app) | Sí |
| Empaques | Solo cuentan en domicilio/para llevar | Por línea |
| Mano de obra | `descontar_stock = false` (no toca inventario) | — |
| Costo de incluidos | `costo_calculado` del producto incluido × cantidad | — |
| Precio sugerido | `costo / (1 − margen_objetivo)` | Solo sugerencia |
| Cliente (Flutter) | Nunca calcula precios/costos; solo muestra | — |

---

## 9. Datos demo — política

- Los seeds `031/033/034` insertan insumos «(demo)» con precios de prueba.
- **Para uso real:** crear script `scripts/limpiar-datos-demo.ps1` que borre/inactive
  insumos, recetas y productos marcados `(demo)` de la sucursal, o permitir crear una
  sucursal nueva vacía desde Super Admin.
- Regla: ningún precio se "auto-rellena"; todo viene de lo que el dueño carga en Mercado.

---

## 10. Plan de implementación por fases (checklist)

### Fase A — Mercado / Insumos (base del costeo)
- [x] Migración `037_insumo_modo_mercado.sql` (proveedor, precio_compra, peso_bruto/neto, categoria_insumo).
- [x] DTO crear/editar insumo con modo mercado; backend deriva costo_real y rendimiento (`insumo-mercado.util.ts`).
- [x] Endpoint `PATCH /inventario/:id` ampliado + cascada `recalcularSucursal`.
- [x] UI diálogo «Nuevo/Editar insumo» con 2 modos + vista previa costo real (`dialogo_insumo_form.dart`).
- [x] Acción «Editar» en la lista de insumos; tab renombrado «Lista de mercado».

### Fase B — Subrecetas completas
- [x] Migración `038` — **N/A** (columnas ya en `032_costeo_industrial.sql`: `cantidad_resultado`, `unidad_resultado`, `margen_error`).
- [x] Motor: costo por unidad de resultado con margen de error (`CosteoService.calcularReceta` tipo `subreceta`).
- [x] API: `GET /costeo/subrecetas/detalle/:id`, `PATCH /costeo/subrecetas/:id`, `POST /costeo/subrecetas/:id/recalcular`; listado con `costo_total`, `num_items`.
- [x] UI subreceta: `dialogo_subreceta_form.dart` (cantidad obtenida + margen % + vista previa costo/gr + editar).
- [x] **Subrecetas anidadas** — líneas `tipo_item=subreceta` en subrecetas (guía v1.0).
- [x] **Fix merma doble** — insumos modo mercado: `costo_unitario` = precio/neto sin re-aplicar rendimiento.
- [x] **Unidades** — `unidad-costeo.util.ts`; conversión g↔kg, ml↔L; validación al guardar recetas.
- [x] **UX guía** — semáforo food cost lista; resumen recalcular; umbral default 35% (`040`).

### Fase C — Platos/Bebidas por canal
- [ ] Migración `039` (impuesto_pct, comision_plataforma_pct, utilidad/margen mesa y domicilio).
- [ ] Motor: costo mesa vs domicilio (empaques + mano de obra + comisión), utilidad, margen, precio bruto.
- [ ] UI cabecera Costos: impuesto %, comisión %, KPIs utilidad y margen por canal.
- [ ] Avisos de dependencia (incluido sin costo, insumo en $0).

### Fase D — Limpieza demo + onboarding
- [ ] Script limpiar datos demo / sucursal vacía.
- [ ] Copys guía en cada pantalla (mercado → subrecetas → platos).

### Fase E — Popularidad (opcional)
- [ ] Reporte ABC mesa/domicilio desde ventas (auto, no manual).

---

## 11. Casos de prueba (validar contra el Excel)

| # | Caso | Entrada | Esperado |
|---|------|---------|----------|
| 1 | Costo real con merma | carne 30.000 / 1.000 br / 900 neto gr | costo_real = 33,33/gr |
| 2 | Sin merma | comino 8.000 / 500 / 500 gr | costo_real = 16/gr |
| 3 | Subreceta por gr | Salsa Maquia total 21.554 / 2.700 gr | 7,98/gr |
| 4 | Plato mesa | PECHUGA ASADA precio 16.500, costo 7.197,8 | margen ≈ 56,4% |
| 5 | Plato domicilio | PECHUGA + empaques + comisión, costo 10.883,5 | margen ≈ 34% |
| 6 | Bebida impuesto | precio 4.000, impuesto 8% | precio_bruto 3.703,7 |
| 7 | Incluido sin costo | Hígado + 2 rosquetes (rosquete sin receta) | costo +0 y **aviso** |
| 8 | Mano de obra | insumo «solo costo» 1.000 | suma costo, no descuenta stock |

---

## 12. Glosario

| Término | Significado |
|---------|-------------|
| Peso bruto | Lo que pesa/compras con merma incluida |
| Peso neto | Parte aprovechable tras limpiar/recortar |
| Factor de corrección | `bruto / neto`; ≥ 1; cuánto encarece la merma |
| Costo real por unidad | `precio / neto`; el que se usa para costear |
| Subreceta | Mezcla intermedia (salsa, base) usada en varios platos |
| Margen de error | Colchón % por desperdicio de producción |
| Comisión plataforma | % que cobra la app de domicilios |
| Precio bruto | Precio sin impuesto: `precio / (1 + impuesto)` |
| Utilidad bruta | `precio_bruto − costo` |
| Margen | `utilidad / precio_bruto` |

---

> **Siguiente paso recomendado:** implementar **Fase A** (Mercado / Insumos con modo
> mercado + editar), porque todo el costeo depende de tener bien el costo real por unidad.
> Luego B y C. Actualizar `docs/AVANCE_PROYECTO.md` al cerrar cada fase.
