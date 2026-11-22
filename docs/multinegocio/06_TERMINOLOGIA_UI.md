# 06 — Terminología UI por vertical

Misma pantalla / mismo código; **strings distintos** según `tipo_negocio` (y a veces módulo).

Fuente futura: respuesta API `terminologia` o mapa local en Flutter.  
No hardcodear “Menú” en features compartidas sin pasar por el diccionario.

---

## Diccionario base

| Clave | restaurante | retail | servicios | general |
|-------|-------------|--------|-----------|---------|
| `negocio` | Restaurante | Tienda | Taller / negocio | Negocio |
| `sede` | Sucursal | Sucursal / local | Sucursal / local | Sucursal |
| `catalogo` | Menú | Catálogo | Servicios y repuestos | Productos |
| `producto` | Plato / producto | Producto | Servicio o repuesto | Producto |
| `categoria` | Categoría | Categoría | Categoría | Categoría |
| `venta` | Pedido | Venta | Orden / cobro | Venta |
| `venta_plural` | Pedidos | Ventas | Órdenes | Ventas |
| `ticket` | Comanda / cuenta | Ticket / recibo | Orden de servicio | Recibo |
| `cliente_final` | Comensal / cliente | Cliente | Cliente | Cliente |
| `inventario` | Insumos / inventario | Inventario | Repuestos / inventario | Inventario |
| `stock_bajo` | Sin insumos / agotado | Agotado | Sin repuesto | Agotado |
| `caja` | Caja | Caja | Caja | Caja |
| `fiado` | Fiado | Fiado | Fiado / crédito | Fiado |
| `staff_vendedor` | Mesero | Vendedor | Recepción | Vendedor |
| `staff_ops` | Cocina | — (ocultar) | Técnico | — |
| `entrega` | Domicilio | Envío / recojo | Visita / entrega equipo | Envío |
| `panel` | Panel restaurante | Panel tienda | Panel taller | Panel |

---

## Navegación admin — qué mostrar

| Ítem nav | restaurante | retail | servicios | general |
|----------|:-----------:|:------:|:---------:|:-------:|
| Dashboard | ✅ | ✅ | ✅ | ✅ |
| Pedidos / Ventas | ✅ | ✅ (Ventas) | ✅ (cobros) | ✅ |
| Mesas | ✅ | ❌ | ❌ | ❌ |
| Cocina / KDS | ✅ | ❌ | ❌ | ❌ |
| Menú / Catálogo | ✅ | ✅ | ✅ | ✅ |
| Costeo / recetas | ✅ | ❌ | ❌ | ❌ |
| Inventario | ✅ | ✅ | ✅ | ✅ |
| Órdenes de trabajo | ❌ | ❌ | ✅ | ❌ |
| Agenda | ❌ | ❌ | ✅ | 🟡 |
| Domiciliarios | ✅ | ❌* | ❌* | ❌ |
| Caja | ✅ | ✅ | ✅ | ✅ |
| Fiados / CxC | ✅ | ✅ | ✅ | ✅ |
| Clientes | 🟡 | ✅ | ✅ | ✅ |
| Reportes | ✅ | ✅ | ✅ | ✅ |
| Usuarios | ✅ | ✅ | ✅ | ✅ |
| Plan / suscripción | ✅ | ✅ | ✅ | ✅ |

\* Hasta exista módulo `envios` genérico.

---

## Flujos de alta de “producto”

| Vertical | Campos del formulario | Notas |
|----------|----------------------|-------|
| restaurante | nombre, categoría, precios local/llevar, foto, receta, toppings | Ya existe |
| retail | nombre, categoría, foto, ¿variantes?, SKU, barcode, precio, costo, stock | Sin receta |
| servicios (catálogo de servicios) | nombre, duración estimada, precio mano de obra | Stock opcional |
| servicios (repuesto) | como retail simple | Ligado a OT |
| general | nombre, precio, stock, barcode opcional | Mínimo viable |

---

## Impresión — títulos de documento

| Documento | restaurante | retail | servicios |
|-----------|-------------|--------|-----------|
| Ticket venta | Comanda / cuenta | Recibo de venta | Recibo |
| Cocina | Ticket cocina | — | — |
| OT | — | — | Orden de trabajo |
| Cotización | — | Cotización (opcional) | Cotización |

---

## Implementación sugerida (Flutter)

```dart
// Ilustrativo — no existe aún
String t(TerminologiaDiccionario d, String clave) =>
  d.map[clave] ?? clave;
// Uso: Text(t(term, 'catalogo'))
```

Evitar `if (tipo == retail) Text('Catálogo') else Text('Menú')` espalcido: centralizar.

---

## Onboarding — copy

| tipo | Título | Subtítulo |
|------|--------|-----------|
| restaurante | Tu restaurante en orden | Mesas, cocina, costos y caja |
| retail | Tu tienda bajo control | Inventario, ventas y fiados |
| servicios | Tu taller organizado | Órdenes, cotizaciones y repuestos |
| general | Tu negocio claro | Ventas, gastos y cobros |
