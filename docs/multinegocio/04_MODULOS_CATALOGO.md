# 04 — Catálogo de módulos (qué / por qué / dónde)

Cada fila es trabajo futuro. **No implementar ahora** — especificación para ejecución.

Convención de “dónde”:

- **BD:** `foody_supabase/migrations/`
- **API:** `foody_backend/src/...`
- **UI:** `lib/features/...`
- **Config:** `plan-features.config.ts` + futuro `modulos-por-tipo.config.ts`

---

## M0 — Fundación multi-vertical

### M0.1 `tipo_negocio` en negocio

| | |
|--|--|
| **Qué** | Columna `tipo_negocio` (+ opcional `subtipo`) en `restaurantes` |
| **Por qué** | El sistema debe saber qué módulos y textos aplicar |
| **Dónde BD** | Migración nueva: enum + `DEFAULT 'restaurante'` |
| **Dónde API** | Onboarding, `GET` perfil negocio, Super Admin |
| **Dónde UI** | Pantalla registro / primer login |
| **Aplica a** | Todos |

### M0.2 `MODULOS_POR_TIPO` + gate combinado

| | |
|--|--|
| **Qué** | Intersección plan ∩ tipo_negocio; ampliar `@RequiereModulo` / `PlanFeaturesGuard` |
| **Por qué** | Un retail Pro no debe abrir `/mesas` aunque el plan “incluya cocina” por legado |
| **Dónde** | `foody_backend/src/core/auth/`; respuesta login con `modulos_activos[]` |
| **UI** | Sidebar/nav filtra por `modulos_activos` (hoy solo mira plan/permisos) |
| **Aplica a** | Todos |

### M0.3 Diccionario de terminología

| | |
|--|--|
| **Qué** | API o asset JSON: etiquetas por `tipo_negocio` |
| **Por qué** | Misma pantalla, palabras distintas (“Menú” vs “Catálogo”) |
| **Dónde** | Backend config o `lib/core/i18n/terminologia_negocio.dart`; ver [`06_TERMINOLOGIA_UI.md`](06_TERMINOLOGIA_UI.md) |
| **Aplica a** | Todos |

### M0.4 Roles genéricos / alias

| | |
|--|--|
| **Qué** | Alias UI: mesero→“vendedor”, cocina→oculto; o roles `vendedor`, `tecnico` |
| **Por qué** | Staff de taller no se identifica como “mesero” |
| **Dónde** | `roles-food` / permisos; seeds por tipo |
| **Aplica a** | retail, servicios, general |

---

## M1 — Retail

### M1.1 Variantes de producto

| | |
|--|--|
| **Qué** | `producto_variantes` (atributos JSON o columnas talla/color), stock por variante |
| **Por qué** | Ropa/zapatos no se inventarian como un solo producto |
| **Dónde BD** | tablas nuevas; `pedido_items.variante_id` nullable |
| **Dónde API** | CRUD variantes; validar stock en confirmar venta |
| **Dónde UI** | Editor producto + POS elige variante |
| **Aplica a** | `retail` (y servicios si vende repuestos con talla) |

### M1.2 SKU y código de barras

| | |
|--|--|
| **Qué** | Campos `sku`, `codigo_barras`; búsqueda exacta; escáner cámara |
| **Por qué** | Velocidad en caja; menos error |
| **Dónde** | columnas + `GET .../buscar?barcode=`; Flutter (patrón QR existente) |
| **Aplica a** | retail, general, electrónica |

### M1.3 Series y garantía

| | |
|--|--|
| **Qué** | `producto_series` (núm. serie/IMEI), estado vendido, garantía hasta |
| **Por qué** | Celulares/electrodomésticos |
| **Dónde** | módulo inventario/catálogo; al vender marcar serie |
| **Aplica a** | retail electrónica; servicios (equipo cliente) |

### M1.4 POS mostrador retail

| | |
|--|--|
| **Qué** | UI cobro rápido: buscar → agregar → cobrar (sin mesa/KDS) |
| **Por qué** | Flujo mental de tienda ≠ restaurante |
| **Dónde UI** | feature `pos_mostrador` o modo de `pedidos` |
| **API** | reutilizar `POST /pedidos` tipo mostrador |
| **Aplica a** | retail, general |

### M1.5 Reportes retail

| | |
|--|--|
| **Qué** | Top SKU, rotación, margen por variante |
| **Por qué** | Dueño de ropa pregunta distinto que dueño de restaurante |
| **Dónde** | `reportes` / `analitica` endpoints + tabs |
| **Aplica a** | retail |

---

## M2 — Servicios

### M2.1 Órdenes de trabajo

| | |
|--|--|
| **Qué** | Entidad OT con estados, cliente, descripción falla, equipo |
| **Por qué** | Unidad de trabajo del taller ≠ ticket de venta instantánea |
| **Dónde** | `foody_backend/src/modulos/servicios/`; tablas `ordenes_trabajo` |
| **UI** | Kanban OT (reutilizar patrones kanban pedidos) |
| **Aplica a** | `servicios` |

### M2.2 Cotizaciones

| | |
|--|--|
| **Qué** | Propuesta mano de obra + repuestos; estados borrador/enviada/aprobada/rechazada |
| **Por qué** | Cliente aprueba antes de gastar |
| **Dónde** | tablas `cotizaciones` / ítems; PDF o share |
| **Aplica a** | servicios (y opcional retail proyectos) |

### M2.3 Repuestos → inventario

| | |
|--|--|
| **Qué** | Al usar repuesto en OT, descontar stock (transacción) |
| **Por qué** | Misma regla Foody: backend descuenta, no Flutter |
| **Dónde** | servicio OT llama inventario (patrón `PedidosInventarioService`) |
| **Aplica a** | servicios |

### M2.4 Técnicos

| | |
|--|--|
| **Qué** | Asignar usuario rol técnico a OT; carga de trabajo |
| **Por qué** | Varios técnicos en un taller |
| **Dónde** | patrón similar a asignación domiciliario |
| **Aplica a** | servicios |

### M2.5 Agenda / citas

| | |
|--|--|
| **Qué** | Calendario: visita o turno |
| **Por qué** | Plomeros, belleza, visitas aire |
| **Dónde** | `citas` + UI calendario |
| **Aplica a** | servicios; opcional general |

### M2.6 Cobro OT

| | |
|--|--|
| **Qué** | Convertir OT aprobada/entregada en venta/caja o CxC |
| **Por qué** | Cerrar el ciclo dinero |
| **Dónde** | integrar `caja` + `cuentas_por_cobrar` |
| **Aplica a** | servicios |

---

## M3 — Canales (diferenciador vs Treinta)

### M3.1 Catálogo público genérico

| | |
|--|--|
| **Qué** | Generalizar menú público a catálogo por `sucursal_id` / slug |
| **Por qué** | Vender por link sin app |
| **Dónde** | endpoints menú → `/catalogo/...`; Flutter cliente o web ligera |
| **Aplica a** | retail, general, restaurante (ya), servicios (lista de servicios) |

### M3.2 WhatsApp share

| | |
|--|--|
| **Qué** | Botón “Compartir catálogo” con texto + URL |
| **Por qué** | Canal #1 del microempresario CO |
| **Dónde** | UI admin; deep link |
| **Aplica a** | todos |

### M3.3 Pedido desde catálogo no-comida

| | |
|--|--|
| **Qué** | Checkout adaptado (sin mesa; envío o pickup) |
| **Por qué** | Cerrar venta online simple |
| **Dónde** | reutilizar pedidos + flags |
| **Aplica a** | retail, general |

---

## M4 — Transversales “mejor que Treinta”

| ID | Qué | Por qué | Dónde |
|----|-----|---------|-------|
| M4.1 | CRUD **Clientes** de primera clase | Treinta vive de agenda de clientes | `modulos/clientes` |
| M4.2 | Recordatorio fiados (FCM/cron) | Cobrar de verdad | cron + FCM |
| M4.3 | Gastos UX 1-tap | Contabilidad mental del dueño | UI caja |
| M4.4 | Plantillas impresión por vertical | Ticket ≠ comanda ≠ OT | `impresion` |
| M4.5 | Plan `gratis` recalibrado | Adquisición multi-rubro | `LIMITES_POR_PLAN` + marketing |
| M4.6 | Bitácora / notas por cliente u OT | Historial servicio | tabla `notas` |

---

## Dependencias entre módulos

```text
M0 (tipo_negocio + gates)
 ├── M1 retail (variantes) ──┐
 │                          ├── M3 catálogo online
 └── M2 servicios (OT) ─────┘
         └── M2.5 agenda (después de OT básico)
 M4.1 clientes ── ayuda a M2 y CxC (hacer temprano si se puede)
```

**Orden recomendado:** M0 → M4.1 (clientes) → M1 → M3 → M2 → resto M4.
