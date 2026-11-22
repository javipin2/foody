# 01 — Visión y principios

## Visión

Foody nace como **POS/gestión para comida**. La evolución natural es convertirse en una **plataforma multi-vertical** para emprendedores y PyMEs: el mismo “cerebro” (caja, stock, ventas, fiado, sedes, staff, suscripción) y **módulos encendidos según el tipo de negocio**.

Posicionamiento deseado:

- Como **Treinta**: simple, accesible, plan gratis, sirve a “cualquier negocio”.
- Mejor que Treinta en: **inventario serio**, multi-sucursal, roles, auditoría, realtime, caja coherente, reportes, y vertical comida **ya profundo** (KDS, mesas, costeo, domicilios).

Nombre de producto a futuro (marketing): se puede mantener “Foody” para comida y un **nombre paraguas** (ej. marca empresa) para retail/servicios — decisión comercial, no bloquea la arquitectura. En código, las tablas pueden seguir diciendo `restaurantes` años.

## Qué problema resolvemos (todos los rubros)

| Dolor del emprendedor | Capacidad del núcleo |
|----------------------|----------------------|
| No sé cuánto vendí hoy | Caja + reportes |
| Se me pierde la mercadería | Inventario + movimientos |
| Me deben y no llevo control | CxC / fiado |
| Varias sedes / varios empleados | Multi-sucursal + roles |
| Quiero vender por celular/WhatsApp | Catálogo público (Fase 3) |
| Cobro suscripción sin vendedor | Self-service + Wompi (ya existe) |

## Principios de diseño

### 1. Capas, no copias

```
┌─────────────────────────────────────────┐
│  UI Flutter (terminología + nav por     │
│  módulos activos del negocio)           │
├─────────────────────────────────────────┤
│  Verticales (opcionales)                │
│  mesas | cocina | recetas | OT |        │
│  variantes | series | agenda            │
├─────────────────────────────────────────┤
│  NÚCLEO (siempre)                       │
│  caja | ventas/pedidos | inventario     │
│  clientes/CxC | staff | sedes | SaaS    │
└─────────────────────────────────────────┘
```

### 2. Activación en dos ejes

Hoy solo existe eje **plan** (`@RequiereModulo` + `plan-features.config.ts`).

Futuro:

| Eje | Pregunta | Ejemplo |
|-----|----------|---------|
| `tipo_negocio` | ¿Este rubro necesita el módulo? | `servicios` → OT sí; `mesas` no |
| `plan` | ¿El plan lo paga? | `analitica` solo Pro+ |

**Regla:** módulo activo = permitido por `tipo_negocio` **Y** por `plan`.

### 3. Incremental y seguro

- Un vertical usable por fase.
- Migraciones con default que no rompa seeds ni clientes comida.
- Restaurante sigue siendo el vertical “completo” y de referencia.

### 4. Terminología ≠ esquema

En UI: “Catálogo”, “Ticket”, “Orden de servicio”.  
En BD: `productos`, `pedidos`, `ordenes_trabajo` (nueva).  
No reescribir todo el dominio a `negocios` en Fase 0.

## Fuera de alcance (explícito)

No intentar en la primera ola multi-negocio:

- Contabilidad completa / PUC (eso es Siigo/Alegra).
- Nómina formal con SSS, deducciones legales y bancos conciliados.
  *(Foody sí cubre nómina **simple**: sueldo base + frecuencia + registro de pagos en el módulo Finanzas del restaurante.)*
- Marketplace tipo Rappi para todos los rubros.
- ERP de manufactura compleja.
- Facturación DIAN como dependencia del vertical (sigue el plan fiscal del producto).

Foody multi-negocio = **operación del negocio** (vender, cobrar, stock, gente, citas/OT), no reemplazar contador.

## Criterio de éxito por fase

| Fase | “Listo” significa |
|------|-------------------|
| 0 | Onboarding elige tipo; UI oculta mesas/cocina en retail; API rechaza módulos apagados |
| 1 | Tienda de ropa vende por talla/color con stock correcto y barcode |
| 2 | Taller de aires crea OT, cotiza, usa repuestos del inventario, cobra |
| 3 | Link público de catálogo + WhatsApp sin app del comprador |
| 4 | Textos, reportes e impresión coherentes por vertical |

## Relación con el roadmap actual

**Prioridad actual del repo:** cerrar Foody restaurante (P0 impresión/VPS/Wompi).  
**Este paquete:** documentación lista para el día que se abra el sprint multi-negocio.  
No mezclar implementación multi-negocio con P0 restaurante.
