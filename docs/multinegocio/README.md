# Multi-negocio Foody — índice de planificación

> **Estado:** 📅 Solo documentación / planeación. **No implementar** hasta cerrar go-live restaurante (P0).  
> **Objetivo de producto:** plataforma de gestión para emprendedores y PyMEs (estilo Treinta), con backend serio (NestJS + PostgreSQL) y verticales activables.  
> **Estado oficial del proyecto:** [`../MASTER_STATUS.md`](../MASTER_STATUS.md)  
> **Hub corto / fases:** [`../PLAN_MULTINEGOCIO_FOODY.md`](../PLAN_MULTINEGOCIO_FOODY.md)

## Cómo usar estos docs

| Momento | Qué leer |
|---------|----------|
| Entender la visión | [`01_VISION_Y_PRINCIPIOS.md`](01_VISION_Y_PRINCIPIOS.md) |
| Qué reutilizar vs qué construir | [`02_NUCLEO_VS_VERTICALES.md`](02_NUCLEO_VS_VERTICALES.md) |
| Qué negocio activa qué | [`03_TIPOS_DE_NEGOCIO.md`](03_TIPOS_DE_NEGOCIO.md) |
| Módulos: qué / por qué / dónde | [`04_MODULOS_CATALOGO.md`](04_MODULOS_CATALOGO.md) |
| Tablas, enums, migraciones futuras | [`05_MODELO_DATOS.md`](05_MODELO_DATOS.md) |
| Textos UI por rubro | [`06_TERMINOLOGIA_UI.md`](06_TERMINOLOGIA_UI.md) |
| Diferenciación vs Treinta / Siigo | [`07_VS_TREINTA.md`](07_VS_TREINTA.md) |
| Día 1 de ejecución | [`08_CHECKLIST_EJECUCION.md`](08_CHECKLIST_EJECUCION.md) |

## Reglas fijas (no negociables)

1. **Un solo repo** — no fork ni “Foody v2” (`.cursor/rules/foody-mismo-repositorio.mdc`).
2. **Flutter = solo UI** — lógica en NestJS.
3. **Núcleo compartido + módulos por vertical** — no un monolito de “if negocio == ropa” en cada pantalla sin `tipo_negocio` + módulos.
4. **No romper restaurante** — `DEFAULT 'restaurante'`; módulos comida se apagan, no se borran.
5. **No renombrar tablas** al inicio (`restaurantes`, `sucursales`) — capa de terminología en UI.

## Orden de ejecución (cuando toque)

0. Fundación (`tipo_negocio` + `MODULOS_POR_TIPO`)  
1. Retail (variantes, SKU, barcode)  
2. Catálogo online / WhatsApp  
3. Servicios / órdenes de trabajo  
4. Pulido (branding, reportes por vertical)

Detalle: [`08_CHECKLIST_EJECUCION.md`](08_CHECKLIST_EJECUCION.md).

## Última actualización

2026-07-26 — Paquete inicial completo de planificación multi-negocio.
