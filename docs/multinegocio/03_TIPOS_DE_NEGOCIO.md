# 03 — Tipos de negocio (mapa completo)

Cada negocio real se mapea a un **`tipo_negocio`** (pocos valores en BD) y opcionalmente a un **`subtipo`** (solo UX / plantillas).

## Enum canónico (BD)

Propuesta estable (Fase 0):

```text
tipo_negocio:
  restaurante   — comida, bebidas, dark kitchen, food truck, café, panadería con receta
  retail        — productos físicos con variantes/SKU (ropa, calzado, joyas, ferretería, etc.)
  servicios     — OT, mano de obra, citas (reparaciones, belleza, consultoría ligera)
  general       — mixtos / kiosco / “Treinta base” (venta simple + fiado + gastos)
  mixtos        — (opcional Fase 4) retail + servicios; por ahora usar general + módulos manuales
```

**Default:** `restaurante` — no rompe datos actuales.

---

## Matriz: emprendimiento → tipo + módulos

### Comida (ya cubierto por Foody)

| Negocio ejemplo | tipo | Módulos ON | Módulos OFF |
|-----------------|------|------------|-------------|
| Restaurante con mesas | `restaurante` | mesas, cocina, recetas, inventario insumos, domicilio opcional | variantes retail, OT |
| Cocina oculta / solo domicilio | `restaurante` | cocina, recetas, domicilio, zonas | mesas (opcional apagar) |
| Food truck / ventana | `restaurante` | cocina o mostrador, recetas | mesas |
| Café / panadería | `restaurante` | recetas, mostrador; mesas opcional | — |
| Buñuelos / frituras / puesto | `restaurante` o `general` | si hay receta→restaurante; si solo “vende unidades”→general+inventario producto | mesas |
| Catering | `restaurante` + pedidos grandes | recetas, CxC | mesas día a día |

### Retail / productos

| Negocio ejemplo | tipo | Necesita sí o sí | Nice to have |
|-----------------|------|------------------|--------------|
| Ropa / boutique | `retail` | variantes talla/color, barcode, POS mostrador | tienda online |
| Zapatos | `retail` | variantes (número/color), barcode | series no |
| Joyas / bisutería | `retail` | SKU, fotos, stock unitario; a veces sin talla | serie/certificado |
| Celulares / electrónica | `retail` | serie, IMEI, garantía, barcode | OT postventa → activar módulo servicios |
| Electrodomésticos | `retail` | serie, garantía | servicio técnico |
| Ferretería / miscelánea | `retail` o `general` | SKU, barcode, muchos ítems | variantes simples |
| Papelería / cosméticos | `retail` | barcode, categorías | — |
| Tienda de barrio / agüita | `general` | venta rápida, fiado, gastos | variantes mínimas |
| Venta por catálogo / WhatsApp | `retail` + Fase 3 | catálogo link, fotos | pedidos online |

### Servicios / oficios

| Negocio ejemplo | tipo | Necesita sí o sí | Nice to have |
|-----------------|------|------------------|--------------|
| Reparación aires / neveras / lavadoras | `servicios` | OT, equipos, cotización, repuestos, técnico | agenda visitas |
| Reparación PCs / celulares | `servicios` | OT, series equipo, cotización | garantías |
| Plomería / electricidad | `servicios` | OT, citas, anticipos | zonas cobertura |
| Taller automotriz (ligero) | `servicios` | OT, repuestos | — |
| Lavandería / tintorería | `servicios` o `general` | tickets con estados (recibido→listo) | — |
| Belleza / barbería / spa | `servicios` | citas, servicios de catálogo (sin stock o stock productos) | retail de productos |
| Consultoría / clases / freelance | `servicios` o `general` | cotización, CxC, agenda | inventario mínimo |
| Mensajería / envíos propios | `general` + envíos | — | reutilizar ideas domiciliarios Fase 4+ |

### Mixtos (muy comunes)

| Caso | Cómo modelarlo |
|------|----------------|
| Taller que también vende repuestos | `servicios` + módulo retail (variantes) ON |
| Restaurante que vende merch | `restaurante` + productos sin receta (ya posible) o retail parcial Fase 4 |
| Salón que vende shampoo | `servicios` + catálogo productos |

**Regla práctica Fase 0–2:** un `tipo_negocio` primario + flags de módulos extra, no un enum infinito.

---

## Módulos por tipo (propuesta `MODULOS_POR_TIPO`)

Nombres orientativos (alinear con `ModuloPlan` existente y nuevos):

| Módulo | restaurante | retail | servicios | general |
|--------|:-----------:|:------:|:---------:|:-------:|
| inventario | ✅ | ✅ | ✅ (repuestos) | ✅ |
| costeo (KYG/recetas) | ✅ | ⬛ | ⬛ | ⬛ |
| cocina | ✅ | ⬛ | ⬛ | ⬛ |
| mesas | ✅ | ⬛ | ⬛ | ⬛ |
| domiciliarios | ✅ | ⬛* | ⬛* | ⬛* |
| zonas_domicilio | ✅ | ⬛ | ⬛ | ⬛ |
| reportes | ✅ | ✅ | ✅ | ✅ |
| analitica | ✅ | ✅ | ✅ | ✅ |
| facturacion | ✅ | ✅ | ✅ | ✅ |
| variantes_sku | ⬛ | ✅ | 🟡 | 🟡 |
| series_garantia | ⬛ | 🟡 | 🟡 | ⬛ |
| ordenes_trabajo | ⬛ | ⬛ | ✅ | ⬛ |
| agenda_citas | ⬛ | ⬛ | ✅ | 🟡 |
| catalogo_publico | ✅ (menú) | ✅ | 🟡 | ✅ |

\* Envios genéricos: Fase 4+ como módulo `envios` separado, no forzar domiciliarios comida.

Además: el **plan** puede restringir (ej. `analitica` solo Pro).

---

## Onboarding — pregunta al registrar

Texto UX sugerido:

1. “¿Qué tipo de negocio tienes?”
   - Comida / restaurante / cocina
   - Tienda / productos (ropa, celular, etc.)
   - Servicios / reparaciones / citas
   - Otro / varios (general)
2. Subtipo opcional (chips): “Ropa”, “Aires acondicionados”, … → solo plantilla de categorías demo y textos.
3. Se guarda `restaurantes.tipo_negocio` (+ `subtipo` texto nullable).

Endpoint a tocar: registro público / `auth/registro-restaurante` (y Super Admin onboarding).

---

## Qué NO crear como tipo aparte

Evitar enums como `joyeria`, `zapatos`, `aires` en BD.  
Eso se resuelve con:

- `tipo_negocio` = retail | servicios | …
- `subtipo` o plantilla de onboarding
- módulos ON/OFF

Menos migraciones, más claridad.
