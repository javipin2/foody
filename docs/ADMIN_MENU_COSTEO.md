# Admin — Menú, insumos y costeo (decisiones de producto)

> **Fuente de verdad** para la reorganización del panel administrador y el modelo de catálogo.  
> **Prioridad:** lo escrito aquí **reemplaza** planes anteriores que contradigan este doc.  
> **Estado:** 📅 Especificación cerrada · implementación UI en curso (S1+)  
> **Motor costeo:** `docs/MODULO_COSTEO.md` (fórmulas; Excel KYG solo referencia, **sin importar datos**)

**Última actualización:** 2026-06-08 — Caso rosquetes (productos con ítems de menú incluidos).

---

## 1. Orden del panel admin (cómo piensa un dueño)

| # | Sección en UI | Qué es | Ejemplo |
|---|---------------|--------|---------|
| 1 | **Menú** | Lo que **ve y pide el cliente** | Rosquete unitario, huevo frito, carne molida, hígado encebollado, café |
| 2 | **Insumos** (lista de mercado) | Lo que **se compra** y el **stock** | Harina, huevo crudo, carne, cebolla, bolsa, papel aluminio |
| 3 | **Costos y márgenes** | Cuánto **cuesta** cada ítem del menú y cuánto **se quiere ganar** | Receta del huevo + rosquetes incluidos → slider margen → precio sugerido |
| 4 | Operación | Pedidos, caja, cocina… | (sin cambio de alcance aquí) |

**Flutter = solo UI.** Precios finales, costos, márgenes y descuento de stock los calcula **NestJS**.

---

## 2. Menú — tipos de ítem (no todo es lo mismo)

### 2.1 Producto simple

- Se vende **solo**, con un precio (y opcionalmente precio distinto para llevar/domicilio — ver §5).
- Ejemplo: **Rosquete** vendido por unidad, cada uno con su precio en carta.

### 2.2 Producto con ítems de menú incluidos ⭐ (caso rosquetes)

Algunos platos **ya traen otros productos del menú** sin que el cliente arme un combo.

| Producto en carta | Precio | Incluye (automático) |
|-------------------|--------|----------------------|
| Rosquete (unidad) | Precio por rosquete | — (solo el rosquete) |
| Huevo frito | Precio del huevo | **1× rosquete** adicional |
| Carne molida | Precio del plato | **2× rosquetes** adicionales |
| Hígado encebollado | Precio del plato | **2× rosquetes** adicionales |

**Reglas de negocio:**

1. El cliente pide **un solo ítem** (ej. «Huevo frito»); el precio de la línea es el del **plato principal**, no se cobra el rosquete aparte.
2. En cocina/ticket debe verse claro: «Huevo frito + 1 rosquete» (o líneas hijas internas).
3. En **costeo**, el costo del plato = receta del plato + (cantidad × `costo_calculado` de cada producto incluido).
4. En **stock**, al vender el plato se descuenta inventario del plato **y** de cada producto incluido (expansión de recetas de rosquetes × cantidad).
5. Cantidades incluidas son **por configuración del admin** (1, 2, N), no las elige el cliente.

**No confundir con:**

| Concepto | Diferencia |
|----------|------------|
| **Combo** (`combos`) | Paquete promocional con **precio fijo** propio (ej. «Combo clásico»). El cliente elige el combo explícitamente. |
| **Topping** | Extra **opcional** con precio adicional (queso extra, etc.). |
| **Bebida vinculada** (`producto_bebidas`) | Patrón legacy para bebidas; el modelo objetivo es **generalizar** a «ítems de menú incluidos» (§3). |

### 2.3 Combos (mantener)

- Siguen siendo entidades aparte con `precio_fijo`.
- Costo = suma costos de ítems + empaques (`CosteoService`).

### 2.4 Toppings y bebidas

- Toppings: extras opcionales con precio.
- Bebidas: pueden seguir como catálogo aparte o como productos en categoría «Bebidas»; si un plato **incluye** una bebida, usar el mismo mecanismo de **ítems incluidos** (§3).

---

## 3. Modelo de datos objetivo — `producto_items_incluidos`

> **Pendiente de migración e implementación API/UI.** Sustituye la idea de solo `producto_bebidas` para casos como rosquetes.

```sql
-- Borrador — implementar en migración futura
CREATE TABLE producto_items_incluidos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal_id uuid NOT NULL REFERENCES sucursales(id),
  producto_id uuid NOT NULL REFERENCES productos(id),        -- plato que vendes (huevo)
  producto_incluido_id uuid NOT NULL REFERENCES productos(id), -- ítem del menú incluido (rosquete)
  cantidad numeric(12,3) NOT NULL DEFAULT 1,
  UNIQUE (producto_id, producto_incluido_id)
);
```

**Backend al confirmar pedido:**

1. Línea `pedido_items` del plato principal.
2. Expandir recetas: plato + N × receta de cada `producto_incluido_id`.
3. Costo línea: costo plato + Σ (cantidad × costo_calculado incluido) — calculado en NestJS.
4. KDS/impresión: mostrar componentes incluidos (configurable por sucursal).

**UI admin (Menú → editar producto):**

- Sección **«Incluye en el pedido»**: agregar producto del menú + cantidad (ej. Rosquete × 1).
- En **Costos**: vista unificada de receta + bloque de incluidos con costo readonly del API.

---

## 4. Insumos (lista de mercado + stock)

- Independiente del menú: harina, huevos, carne, empaques, etc.
- **Compra** actualiza `costo_unitario_actual` → cascada recalcula todos los platos y productos incluidos que dependan de esa receta.
- **Stock** y **movimientos**: compras, ventas (vía recetas expandidas), ajustes, conteo físico.

El dueño **no** edita el costo del huevo en la pantalla de costos línea a línea como precio fijo manual: el costo del insumo viene de la lista de mercado; en costos solo define **cantidades por porción** en la receta.

---

## 5. Costos y márgenes (vinculado al menú)

### Pantalla objetivo (master-detail)

1. Lista de **todos los productos del menú** (misma fuente que ve el cliente).
2. Al seleccionar uno (ej. Hamburguesa, Huevo frito):
   - **Receta** (insumos + subrecetas + empaques para llevar/domicilio).
   - **Ítems de menú incluidos** (si aplica: rosquetes × 1 o × 2).
   - **Costo total** (API).
   - **Precio de venta actual** (mesa/local; luego opcional para llevar).
   - **Slider margen objetivo %** → `precio_sugerido` (solo sugerencia).
   - Botón **«Aplicar precio sugerido al menú»** (gerente decide).

### Precio local vs para llevar

- Ejemplo salchipapa: **$20.000** en local, **$21.500** para llevar (empaque).
- El dueño puede poner **el mismo precio** en ambos canales.
- Costo llevar = costo base + empaques (`tipo_item=empaque` en receta); ya soportado en backend.

---

## 6. Caso de estudio — Restaurante de rosquetes

```
Menú cliente:
  Categoría «Rosquetes»     → Rosquete sencillo ($X c/u)
  Categoría «Platos»        → Huevo frito ($A, incluye 1 rosquete)
                            → Carne molida ($B, incluye 2 rosquetes)
                            → Hígado encebollado ($C, incluye 2 rosquetes)

Insumos:
  Rosquete: harina, levadura, … (receta por unidad)
  Huevo: huevo, aceite, … + (costo de 1 rosquete vía producto_items_incluidos)
  Carne: carne, cebolla, … + (2 × costo rosquete)

Pedido cliente: 1× Huevo frito
  → Cobra: precio huevo
  → Cocina: huevo + 1 rosquete
  → Stock: ingredientes huevo + ingredientes de 1 rosquete
```

---

## 7. UI / UX (admin)

| Requisito | Notas |
|-----------|--------|
| Intuitivo, menos «tosco» | Tarjetas, paneles laterales, menos `AlertDialog` anidados |
| Responsive | Móvil, tablet, escritorio — master-detail con `LayoutBuilder` |
| Colores Foody | `ColoresFoody`, Poppins + Inter |
| Vínculo Menú ↔ Costos | Desde producto: «Ver costos»; desde costos: «Editar en menú» |

---

## 8. Roadmap de implementación (sesiones)

| Sesión | Entregable |
|--------|------------|
| **S1** | Sidebar: Menú + Costos y márgenes; pantalla costos master-detail; enlace desde menú |
| **S2** | UI menú moderna + responsive |
| **S3** | Insumos como módulo propio (sacar de inventario monolítico) |
| **S4** | Slider margen + aplicar precio sugerido |
| **S5** | Migración `producto_items_incluidos` + API + UI «Incluye en el pedido» + pedidos/stock/costeo |
| **S6** | Precio local / para llevar en menú y checkout |

---

## 9. Qué NO hacer (acuerdos previos vigentes)

- **No** importar datos del Excel KYG (solo fórmulas de referencia).
- **No** calcular márgenes ni costos en Flutter.
- **No** duplicar apps ni carpetas paralelas (`foody-mismo-repositorio`).
- **No** modelar huevo+rosquete como combo si el cliente pide solo «huevo» — usar **ítems incluidos**.

---

## 10. Changelog de decisiones (usuario → doc)

| Fecha | Decisión |
|-------|----------|
| 2026-06-08 | Excel KYG solo referencia de fórmulas; sin importación. |
| 2026-06-08 | Orden admin: Menú → Insumos → Costos; UI moderna y responsive. |
| 2026-06-08 | Costos: lista productos menú, receta por producto, slider margen %, precio sugerido del API. |
| 2026-06-08 | Precio local vs llevar opcional (mismo precio permitido); empaques en costo llevar. |
| 2026-06-08 | **Productos con ítems de menú incluidos** (rosquetes): huevo +1 rosquete, carne/hígado +2 rosquetes; distinto de combos. Tabla objetivo `producto_items_incluidos`. |

---

## Referencias

- Motor y fórmulas: `docs/MODULO_COSTEO.md`
- Avance implementación: `docs/AVANCE_PROYECTO.md`
- Código menú admin: `lib/features/catalogo/presentation/menu_admin_screen.dart`
- Código costeo API: `foody_backend/src/modulos/costeo/`
