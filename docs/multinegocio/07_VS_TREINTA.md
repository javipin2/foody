# 07 — Vs Treinta (y similares): cómo ser “mucho mejor”

Referencia de mercado: **Treinta** (app CO para micro-negocios: ventas, gastos, fiados, inventario simple, catálogo). También Alegra/Siigo POS (más contable).

Este doc fija **qué copiar**, **qué superar** y **qué no perseguir**.

---

## 1. Qué hace bien Treinta (hay que igualar)

| Capacidad | Por qué importa | Estado Foody | Gap |
|-----------|-----------------|--------------|-----|
| Onboarding en minutos | Emprendedor no lee manuales | Self-service existe (comida) | Elegir rubro + plantilla |
| Plan gratis usable | Adquisición | `gratis` muy limitado (5 productos) | Recalibrar límites multi-negocio |
| Fiados claros | Cultura de “me deben” | CxC existe | UX + recordatorios |
| Gastos fáciles | Control mental del dueño | En caja | Botón 1-tap más visible |
| Catálogo / link | Vender por WhatsApp | Menú público comida | Generalizar |
| Lenguaje simple | No dice “sucursal KDS” | UI restaurante | Terminología por vertical |
| Sirve “cualquier negocio” a nivel básico | Percepción de producto | Solo comida | tipo_negocio + módulos |

---

## 2. Dónde Foody ya es (o será) superior

| Capacidad | Foody | Treinta típico | Mensaje de venta |
|-----------|-------|----------------|------------------|
| Backend serio / multi-tenant | Nest + Postgres + `sucursal_id` | App más liviana | “No se te mezclan las sedes ni los datos” |
| Caja con arqueo / coherencia | Flujo caja maduro | Más simple | “Cierras caja de verdad” |
| Multi-sucursal + roles | Implementado | Limitado o ausente | Cadenas chicas |
| Vertical comida profundo | KDS, mesas, costeo, domi | Genérico | Foody sigue siendo el mejor en comida |
| Inventario con movimientos/auditoría | Fuerte | Básico | “Sabes qué pasó con el stock” |
| Realtime / FCM | En producto | Variable | Operación en vivo |
| Costeo industrial (comida) | KYG | No | Diferenciador vertical comida |
| Domicilios propios | Sí | No comparable | Ahorro vs Rappi |
| SaaS cobro Wompi | En curso | — | Autoservicio |

**Promesa de marca multi-negocio:**  
“Tan fácil como Treinta para empezar; tan serio como un POS de verdad cuando creces.”

---

## 3. Qué NO intentar (para no morir)

| Tentación | Por qué no (aún) |
|-----------|------------------|
| Contabilidad DIAN completa como core | Ya es campo de Siigo/Alegra; DIAN en Foody está pausado |
| Ser ERP de fábrica | Fuera de PyME objetivo |
| 50 tipos de negocio con pantallas distintas | Solo 4 `tipo_negocio` + plantillas |
| Reescribir Foody con otro nombre ya | Primero piloto comida; branding paraguas después |
| Feature parity pixel-perfect con Treinta día 1 | Entregar verticales por fases |

---

## 4. Matriz competitiva (posicionamiento)

```text
                    Simple / micro
                         ▲
                         │  Treinta
                         │     ·
                         │         · Foody multi (objetivo)
                         │              ·
    Genérico ◄───────────┼───────────────► Especializado comida
                         │         Foody hoy
                         │              ·
                         │         Fudo / Toast-like
                         │
                         ▼
                    Complejo / caro
```

- **Hoy:** Foody = especializado comida, ya profundo.
- **Objetivo:** subir en el eje “sirve a más rubros” sin bajar la seriedad del núcleo.
- **No:** bajar a “solo libreta de gastos” y perder el foso comida.

---

## 5. Oferta comercial sugerida (multi-negocio)

Alinear con `docs/PLANES_SUSCRIPCION.md` cuando se ejecute:

| Plan | Rol | Incluye (idea) |
|------|-----|----------------|
| Gratis | Gancho | 1 sede, pocos productos/OT, ventas, fiado, gastos, reportes básicos |
| Básico | PyME | Más catálogo, usuarios, barcode, CxC, impresión |
| Pro | Crecimiento | Analítica, multi-sede, catálogo online, OT avanzadas |
| Enterprise | Cadenas | Límites altos, facturación, soporte |

Vertical comida puede seguir con add-ons percibidos (costeo, domiciliarios) aunque técnicamente sean módulos del mismo plan.

---

## 6. Criterios “mejor que Treinta” (checklist de producto)

Se puede decir “mejor” cuando existan **todos** estos:

1. [ ] Onboarding con tipo de negocio + plan gratis usable  
2. [ ] Venta + fiado + gasto en < 3 toques cada uno  
3. [ ] Inventario con movimientos auditables  
4. [ ] Retail: variantes + barcode en caja  
5. [ ] Servicios: OT + cotización + repuestos  
6. [ ] Link de catálogo + WhatsApp  
7. [ ] Multi-usuario con permisos  
8. [ ] Al menos un vertical “wow” (comida ya cuenta)  

Hasta entonces: posicionar Foody como **líder en comida** y multi-negocio como **roadmap público**, no como promesa de marketing prematura.
