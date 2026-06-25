# Guía cerebro — Costeo Foody (mercado → insumos → subrecetas → platos → incluidos)

> Documento maestro para entender **qué se conecta con qué, por qué y cuándo** en todo el sistema de costos.
> Úsalo paso a paso para verificar que tus datos y los cálculos cuadran.
> Relacionado: `docs/ESPEC_COSTEO_MERCADO_KYG.md`, `docs/MODULO_COSTEO.md`, `INFRAESTRUCTURA/FOODY_Guia_Costeo_v1.0.docx`.

**Regla de oro Foody:** Flutter **solo muestra**. Todos los cálculos reales (costo, food cost, margen, precio sugerido) los hace **NestJS + PostgreSQL**. Lo que ves en un diálogo como «vista previa» es una estimación visual; el valor que manda es el que devuelve el backend tras **Guardar** / **Recalcular**.

---

## 0. Las 5 piezas y cómo se enlazan

```
┌─────────────┐   precio_compra / peso_neto    ┌──────────────┐
│  MERCADO    │ ─────────────────────────────► │   INSUMO     │  costo_unitario_actual ($ por unidad_base)
│ (compra)    │                                │ (ingrediente)│  unidad_base: g | kg | ml | L | und | servicio
└─────────────┘                                └──────┬───────┘
                                                      │  se usa en (cantidad + unidad)
                          ┌───────────────────────────┼───────────────────────────┐
                          ▼                           ▼                            ▼
                   ┌─────────────┐            ┌──────────────┐             ┌──────────────┐
                   │  SUBRECETA  │            │   RECETA     │             │   EMPAQUE    │
                   │ (arroz,     │  costo_por │  del PLATO   │             │ (solo llevar)│
                   │  salsa…)    │  _unidad   │  (producto)  │             └──────────────┘
                   └──────┬──────┘ ─────────► └──────┬───────┘
                          │  se usa por gramo/ml/und │  produce
                          ▼                          ▼
                   (otra subreceta)          ┌──────────────┐   precio (lo pones tú)
                                             │   PRODUCTO   │ ─────────────────────────► food cost, margen, precio sugerido
                                             │  (plato menú)│   costo_calculado (lo calcula el sistema)
                                             └──────┬───────┘
                                                    │  puede incluir (sin cobrar aparte)
                                                    ▼
                                             ┌──────────────┐
                                             │ ITEMS        │  otro producto del menú × cantidad
                                             │ INCLUIDOS    │  (ej. hígado incluye 2× rosquete)
                                             └──────────────┘
```

| Pieza | Tabla BD | Qué es | Costo que aporta |
|-------|----------|--------|------------------|
| **Insumo** | `ingredientes` | Lo que compras (harina, aceite, gas, mano de obra) | `costo_unitario_actual` = $ por `unidad_base` |
| **Subreceta** | `recetas` (`tipo='subreceta'`) | Preparación intermedia reutilizable (arroz, salsa, masa) | `costo_por_unidad` = costo del lote ÷ `cantidad_resultado` |
| **Receta del plato** | `recetas` (`tipo='producto'`) + `receta_items` | Qué insumos/subrecetas usa un plato | suma de líneas × (1 + margen error) |
| **Producto** | `productos` | El plato del menú (lo que ve el cliente) | `costo_calculado` |
| **Incluidos** | `producto_items_incluidos` | Otros productos del menú que van gratis dentro del plato | costo del producto incluido × cantidad |

---

## 1. MERCADO → INSUMO  (de cuánto pagas a cuánto cuesta de verdad)

**Dónde:** pantalla **Insumos → Mercado** (diálogo crear/editar insumo).

**Dos modos de insumo:**

| Modo | Cuándo usarlo | Qué guardas | Cómo sale el costo |
|------|---------------|-------------|--------------------|
| **Mercado** | Lo compras y se gasta por peso/volumen/unidad | `precio_compra`, `peso_bruto`, `peso_neto`, `unidad_base` | `costo_unitario_actual = precio_compra / peso_neto` |
| **Solo costo** | No descuenta stock (gas, mano de obra, servicios) | `costo_unitario_actual` directo | Lo escribes tú |

**Fórmula mercado (igual al Excel KYG):**

```
costo_real (por unidad_base) = precio_compra / peso_neto
rendimiento_%               = (peso_neto / peso_bruto) × 100
factor_correccion (merma)   = peso_bruto / peso_neto
```

- `peso_bruto` = lo que compras (ej. 1000 g de cebolla con cáscara).
- `peso_neto` = lo aprovechable (ej. 850 g ya pelada).
- Si no hay merma, pon `peso_neto = peso_bruto` (rendimiento 100%).

> ⚠️ **El error #1 más común está aquí: la `unidad_base`.**
> `costo_unitario_actual` siempre está expresado **por la unidad_base que elegiste**.
> Si guardas harina con `unidad_base = g`, el costo es **$ por gramo**.
> Si la guardas con `unidad_base = kg`, el costo es **$ por kilo**.
> Ejemplo real: harina a $3.000 el kilo →
>   - como **kg**: `costo_unitario_actual = 3000` ($3.000/kg) ✅
>   - como **g**:  `costo_unitario_actual = 3` ($3/g) ✅
>   - ❌ Poner `3000` con `unidad_base = g` significa **$3.000 por gramo** = $3.000.000/kg (1000× caro).

**✅ Verifica el insumo:** abre Insumos y para cada uno pregúntate:
«¿El número que veo es lo que cuesta **una** unidad_base?» (1 g, 1 ml, 1 und). Si dice `$5/g` para harina, está 1000× mal.

---

## 2. INSUMO → RECETA / SUBRECETA  (cuánto usas por plato/lote)

**Dónde:** receta del plato (Costos y márgenes → *Qué cuesta hacerlo*) o diálogo de subreceta.

Cada línea tiene **cantidad + unidad**. El sistema convierte la unidad de la línea a la `unidad_base` del insumo **antes** de multiplicar:

```
costo_linea = costo_unitario_actual × convertir(cantidad, unidad_linea → unidad_base)

convertir:  g↔kg (×1000 / ÷1000),  ml↔L (×1000 / ÷1000),  igual unidad = sin cambio
```

Ejemplo correcto (harina **kg**, $3.000/kg, receta pide **125 g**):

```
0,125 kg × 3.000 = $375     (no 125 × 3.000 = 375.000)
```

> 🔧 **Corregido en código (esta sesión):** las **vistas previas** de Flutter (receta del plato y diálogo de subreceta) hacían `cantidad × costo` **sin convertir** la unidad. Por eso veías líneas infladas (ej. $625 por harina). El backend **siempre** convirtió bien; el total real del plato era correcto, pero las líneas de la UI mentían. Ya quedó alineado (`lib/features/costeo/domain/unidad_costeo_util.dart`).
> Las unidades de cada línea **deben ser de la misma familia** que la `unidad_base` del insumo (g/kg o ml/L o la misma). Si no, el backend rechaza con `UNIDAD_INCOMPATIBLE`.

**✅ Verifica:** tras *Guardar receta*, el **Costo total de preparación** (pie) y la **suma de líneas** deben coincidir. Si no, hay una unidad mal puesta o falta **Recalcular**.

---

## 3. SUBRECETA  (el punto donde te trabaste con el rosquete)

Una subreceta es un **lote** que se cuesta una vez y luego se «jala» por gramo/ml/unidad en los platos.

```
costo_insumos        = suma de líneas de la subreceta (con conversión de unidad)
costo_con_margen     = costo_insumos × (1 + margen_error)      ← margen_error típico 5%
costo_por_unidad     = costo_con_margen / cantidad_resultado    ← ¡EL CAMPO CLAVE!
```

`cantidad_resultado` + `unidad_resultado` = **cuánto produce el lote** (ej. 2.700 g de arroz, o 20 und de rosquetes).

### Tu caso «rosquetes» — qué está pasando

En tu pantalla:
- Insumos del lote: aceite 150 ml, harina 125 g, queso 50 g → costo insumos ≈ **$1.225**
- `cantidad_resultado` = **1 und**
- → `costo_por_unidad` = 1.225 × 1,05 / **1** = **$1.286 por rosquete**

Eso dice: *«con 150 ml de aceite + 125 g de harina + 50 g de queso hago **UN solo** rosquete que cuesta $1.286»*. Y eso **no es lo que querías**.

**El problema NO es que no puedas hacer lotes grandes.** `cantidad_resultado` **no te obliga a cocinar todo junto**: es solo la base matemática para repartir el costo. Tú decides la proporción.

**Dos formas correctas de modelarlo (elige una):**

| Forma | `cantidad_resultado` | Cantidades de insumos | `costo_por_unidad` |
|-------|----------------------|------------------------|--------------------|
| **A — por unidad** | `1 und` | las de **UN** rosquete (ej. harina 12 g, aceite 8 ml…) | costo de 1 rosquete |
| **B — por lote (recomendada)** | `N und` (lo que rinde esa mezcla, ej. `20`) | las del **lote completo** (harina 125 g, aceite 150 ml…) | costo del lote ÷ N |

Hoy mezclaste las dos: pusiste **cantidades de lote** con **`cantidad_resultado = 1`**. Por eso cada rosquete sale carísimo.

**Arreglo:** decide cuántos rosquetes salen realmente de 125 g de harina + 150 ml de aceite + 50 g de queso (pongamos **20**) y pon `cantidad_resultado = 20 und`. Entonces:

```
costo_por_unidad = 1.286 / 20 ≈ $64 por rosquete
```

Luego, en el plato que lleva rosquetes, agregas la subreceta **× 2 und** → suma ~$128. Eso sí cuadra.

> 💡 Regla mental: **las cantidades de insumos y `cantidad_resultado` describen el MISMO lote.** Si subes los insumos al doble, sube `cantidad_resultado` al doble: el costo por unidad no debe cambiar.

### ¿Subreceta, producto o incluido? (evita duplicar el rosquete)

Tienes **dos cosas** llamadas rosquete y eso confunde. Define cuál usas:

| Situación | Modela como | Por qué |
|-----------|-------------|---------|
| El rosquete **se vende solo** en el menú ($2.500) | **Producto** «Rosquete sencillo» con su receta | El cliente lo pide directo |
| El rosquete es una **masa/base** que entra en varios platos y nunca se vende solo | **Subreceta** | Se cuesta por unidad y se reutiliza |
| El plato (hígado) **trae rosquetes gratis** y el rosquete **ya existe como producto del menú** | **Items incluidos** (hígado incluye 2× «Rosquete sencillo») | Reusa el costo del producto, descuenta su stock |

⚠️ **No tengas a la vez** una subreceta «rosquetes» *y* un producto «Rosquete sencillo» representando lo mismo, salvo que de verdad sean cosas distintas. Decide uno y elimina el duplicado para que los costos no se crucen.

---

## 4. RECETA → PRODUCTO  (el costo del plato)

```
costo_receta        = (costo_ingredientes + costo_subrecetas) × (1 + margen_error)
costo_por_porcion   = costo_receta / rendimiento_porciones      ← normalmente 1
costo_calculado     = costo_por_porcion + costo_incluidos(base) ← lo que se guarda en productos
costo_domicilio     = costo_calculado + empaques                ← versión para llevar
```

- **Empaques** solo suman en domicilio/para llevar, no en consumo en sitio.
- `margen_error` de la receta cubre desperdicio fino (≈5%).

**✅ Verifica:** en *Costos y márgenes*, el **Costo total de preparación** del plato debe ser ≈ suma de sus líneas (ingredientes + subrecetas) + 5%.

---

## 5. PRODUCTO → PRECIO  (food cost, margen, precio sugerido)

Tú pones el **`precio`**. El sistema calcula el resto:

```
food_cost_%        = costo_calculado / precio × 100        ← cuánto del precio es costo
margen_%           = (precio − costo_calculado) / precio × 100
precio_sugerido    = costo_calculado / (1 − margen_objetivo)   ← para alcanzar el margen que quieres
```

Referencias sanas (restaurante): **food cost 25–35%**, margen 65–75%. Por eso el semáforo: verde <35%, naranja 35–50%, rojo >50%.

> Si ves **food cost 0,2%** o **margen 99,8%**, casi siempre significa que el **costo está mal (muy bajo)** porque falta receta o las unidades/cantidades están mal — no que tu plato sea oro puro.

---

## 6. ITEMS INCLUIDOS  (platos que arrastran otros productos)

`producto_items_incluidos`: el plato A incluye N unidades del producto B **sin cobrarlas aparte**.

```
costo_incluidos    = Σ ( costo_calculado(producto_incluido) × cantidad )
costo real del plato = costo preparación A + costo_incluidos
```

- Al **vender** A, el stock descuenta también los insumos de B (vía expansión de receta).
- **Requisito:** B debe existir como producto **y tener su receta costeada**; si B tiene `costo_calculado = 0`, no suma nada.
- Es **distinto de un combo**: el combo tiene precio propio y se arma con varios productos; el incluido es «gratis dentro de» un solo plato.

**✅ Verifica (caso hígado + 2 rosquetes):**
1. «Rosquete sencillo» tiene receta y `costo_calculado > 0`.
2. Hígado → tab *Qué va incluido* → Rosquete sencillo × 2.
3. *Costo real total* = preparación hígado + (costo rosquete × 2).

---

## 7. ¿CUÁNDO se recalcula cada cosa? (la cadena de propagación)

El costo **no** se recalcula solo en cada pantalla; se dispara en estos momentos:

| Evento | Qué recalcula | Cascada |
|--------|---------------|---------|
| Guardar/editar **insumo** o registrar **compra** | costo del insumo | → todas las recetas/subrecetas que lo usan → productos → combos |
| Guardar **subreceta** | `costo_por_unidad` | → productos que la usan → combos |
| Guardar **receta** de un plato | `costo_calculado` del plato | → productos que lo incluyen → combos |
| Cambiar **items incluidos** | `costo_calculado` del plato | → combos |
| Botón **Recalcular todo** | toda la sucursal | subrecetas → productos → combos |

> Si tocaste datos por SQL o algo se ve desactualizado: pulsa **Recalcular todo**. Es la forma segura de re-sincronizar la cadena completa.

---

## 8. CHECKLIST de verificación (orden recomendado para esta sesión)

Hazlo en este orden; cada paso depende del anterior.

- [ ] **Paso 1 — Insumos.** Revisa cada insumo: `unidad_base` correcta y `costo_unitario_actual` = costo de **una** unidad_base. Sospecha de cualquier `$X/g` que parezca precio de kilo.
- [ ] **Paso 2 — Merma.** En insumos de mercado, `peso_neto ≤ peso_bruto` y reflejan la realidad (pelado/limpieza). Sin merma → neto = bruto.
- [ ] **Paso 3 — Subrecetas.** Para cada una: ¿las cantidades de insumos y `cantidad_resultado` describen **el mismo lote**? Corrige el rosquete: `cantidad_resultado` = nº real que rinde.
- [ ] **Paso 4 — Duplicados.** ¿Hay subreceta y producto representando lo mismo (rosquete)? Quédate con uno.
- [ ] **Paso 5 — Recetas de platos.** Cada plato tiene su receta; el costo total ≈ suma de líneas + 5%.
- [ ] **Paso 6 — Incluidos.** Los productos incluidos existen y tienen costo > 0.
- [ ] **Paso 7 — Recalcular todo.** Pulsa el botón y revisa el resumen.
- [ ] **Paso 8 — Cordura.** Food cost de cada plato entre ~20% y ~45%. Nada en 0% ni 100%.

---

## 9. Señales de que algo está mal (diagnóstico rápido)

| Síntoma | Causa probable | Dónde mirar |
|---------|----------------|-------------|
| Línea de receta inflada (×1000) | `unidad_base` del insumo vs unidad de la línea (g/kg) | Paso 1 |
| Food cost ~0% / margen ~100% | costo muy bajo: falta receta o cantidades mal | Pasos 3–5 |
| Subreceta carísima por unidad | `cantidad_resultado` = 1 con cantidades de lote | Paso 3 (tu rosquete) |
| Incluidos no suman | producto incluido sin receta (`costo_calculado = 0`) | Paso 6 |
| Cambié un insumo y el plato no cambió | falta propagar | Paso 7 (Recalcular todo) |
| `UNIDAD_INCOMPATIBLE` al guardar | unidad de línea de otra familia que la base | Paso 1 + receta |

---

## 10. Referencias de código (para el agente)

| Qué | Archivo |
|-----|---------|
| Fórmula mercado (precio/neto, merma) | `foody_backend/src/modulos/inventario/insumo-mercado.util.ts` |
| Conversión de unidades (backend) | `foody_backend/src/modulos/costeo/unidad-costeo.util.ts` |
| Conversión de unidades (Flutter, espejo) | `lib/features/costeo/domain/unidad_costeo_util.dart` |
| Cálculo de receta/subreceta/producto | `foody_backend/src/modulos/costeo/costeo.service.ts` (`calcularReceta`, `recalcularProducto`, `cantidadEnUnidadSubreceta`) |
| Resumen food cost/margen | `costeo.service.ts` → `resumenSucursal` |
| Receta del plato (UI) | `lib/features/costeo/presentation/widgets/receta_producto_panel.dart` |
| Subreceta (UI) | `lib/features/inventario/presentation/widgets/dialogo_subreceta_form.dart` |
| Incluidos (UI) | `lib/features/costeo/presentation/widgets/producto_items_incluidos_panel.dart` |

---

**Resumen en una frase:** el backend calcula bien; los problemas vienen de **(a)** unidades/precios mal cargados en Insumos y **(b)** `cantidad_resultado` de subrecetas que no coincide con las cantidades del lote. Esta sesión ya alineó las vistas previas de Flutter con el backend; el resto es verificar tus datos con el checklist del §8.
