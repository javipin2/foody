# Foody → Plataforma multi-negocio (hub)

> **Objetivo:** evolucionar Foody (SaaS POS restaurantes) a una plataforma de gestión para **cualquier tipo de negocio**, con plan gratis — “Treinta, pero con backend serio”.
>
> **Principio:** un solo repo. Núcleo compartido; verticales = **módulos activables**.
>
> **Estado:** 📅 **Solo planificado / documentado.** No implementar hasta cerrar prioridad restaurante (P0).  
> **Especificación completa:** carpeta [`multinegocio/`](multinegocio/README.md)  
> **Estado oficial del proyecto:** [`MASTER_STATUS.md`](MASTER_STATUS.md)  
> **Última actualización:** 2026-07-26 — paquete docs `docs/multinegocio/` (visión, verticales, módulos, BD, terminología, vs Treinta, checklist).

---

## Leer la spec completa aquí

| Doc | Contenido |
|-----|-----------|
| [`multinegocio/README.md`](multinegocio/README.md) | Índice |
| [`01_VISION_Y_PRINCIPIOS.md`](multinegocio/01_VISION_Y_PRINCIPIOS.md) | Visión, capas, fuera de alcance |
| [`02_NUCLEO_VS_VERTICALES.md`](multinegocio/02_NUCLEO_VS_VERTICALES.md) | Qué reutilizar vs construir |
| [`03_TIPOS_DE_NEGOCIO.md`](multinegocio/03_TIPOS_DE_NEGOCIO.md) | Restaurante, retail, servicios, general + ejemplos |
| [`04_MODULOS_CATALOGO.md`](multinegocio/04_MODULOS_CATALOGO.md) | Qué / por qué / dónde por módulo |
| [`05_MODELO_DATOS.md`](multinegocio/05_MODELO_DATOS.md) | Tablas y columnas futuras |
| [`06_TERMINOLOGIA_UI.md`](multinegocio/06_TERMINOLOGIA_UI.md) | Textos y nav por rubro |
| [`07_VS_TREINTA.md`](multinegocio/07_VS_TREINTA.md) | Competencia y promesa “mejor” |
| [`08_CHECKLIST_EJECUCION.md`](multinegocio/08_CHECKLIST_EJECUCION.md) | Día 1 de código |

---

## Resumen ejecutivo (1 minuto)

**Sí hay base:** caja, ventas, inventario, fiado, multi-sede, staff, planes, reportes, auth SaaS.

**Específico de comida (apagable):** mesas, cocina/KDS, recetas/costeo, domiciliarios comida, toppings/combos.

**Falta construir:** `tipo_negocio` + gates; variantes/SKU/barcode (retail); órdenes de trabajo/cotizaciones (servicios); catálogo online genérico; clientes de primera clase; terminología UI.

**Orden:** Fase 0 → Retail → Catálogo → Servicios → Pulido.

**Ahora:** no codear esto; cerrar Foody comida.

---

## Fases (estado)

| Fase | Nombre | Estado |
|------|--------|--------|
| 0 | Fundación (`tipo_negocio`, módulos, terminología) | 📅 Documentado |
| 1 | Retail (variantes, barcode, POS) | 📅 Documentado |
| 1b | Clientes CRUD | 📅 Documentado |
| 2 | Servicios / OT | 📅 Documentado |
| 3 | Catálogo online + WhatsApp | 📅 Documentado |
| 4 | Pulido multivertical | 📅 Documentado |

Detalle de tareas: [`08_CHECKLIST_EJECUCION.md`](multinegocio/08_CHECKLIST_EJECUCION.md).

---

## Naming

- **Fase 0–3:** no renombrar tablas `restaurantes` / `sucursales`.  
- **Marketing:** posible marca paraguas más adelante; Foody sigue siendo el vertical comida.
