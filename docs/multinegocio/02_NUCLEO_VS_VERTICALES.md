# 02 — Núcleo vs verticales

Matriz de reutilización: qué ya existe en Foody y qué hay que añadir.

## Leyenda

| Símbolo | Significado |
|---------|-------------|
| ✅ | Existe y sirve tal cual (o con rename UI) |
| 🟡 | Existe pero hay que generalizar / parametrizar |
| 🔴 | No existe — construir |
| ⬛ | No aplica a ese vertical (se apaga) |

---

## A. Núcleo agnóstico (todos los negocios)

| Capacidad | Dónde está hoy | Estado | Notas para multi-negocio |
|-----------|----------------|--------|---------------------------|
| Caja abrir/cerrar, movimientos, gastos | `core/caja`, `movimientos_caja` | ✅ | Ya hay tipo gasto; UI “gastos del día” más visible |
| Ventas / tickets | `modulos/pedidos` | 🟡 | Pedido tipo mostrador existe; desacoplar lenguaje “pedido comida” |
| Inventario / stock | `modulos/inventario` | 🟡 | Hoy muy ligado a **insumos/recetas**; retail usa stock de **producto/variante** |
| Fiado / CxC | `cuentas_por_cobrar` | ✅ | Corazón tipo Treinta |
| Clientes | parcial en pedidos/CxC | 🟡 | Falta **CRUD clientes** de primera clase (teléfono, doc, historial) |
| Multi-sucursal | `sucursales`, scope | ✅ | Igual para cadenas de ropa o talleres |
| Staff + roles | `modulos/usuarios` | 🟡 | Roles “mesero/cocina” → alias o roles genéricos por vertical |
| Suscripción / planes / límites | `plan-features.config.ts` | 🟡 | Añadir límites: OT, variantes, SKUs |
| Reportes / dashboard / analítica | `reportes`, `analitica` | 🟡 | Métricas por vertical (top SKU vs top plato) |
| Auth, FCM, auditoría, storage, realtime | `core/*` | ✅ | |
| Self-service registro + Wompi | onboarding / pagos | 🟡 | Onboarding: elegir `tipo_negocio` |
| Impresión | `impresion` + Python | 🟡 | Plantillas: comanda vs recibo vs OT |

---

## B. Vertical comida (actual — se vuelve apagable)

| Capacidad | Dónde | En retail | En servicios | En general |
|-----------|-------|-----------|--------------|------------|
| Mesas + QR | `mesas` | ⬛ | ⬛ | ⬛ |
| Cocina / KDS | `cocinas` | ⬛ | ⬛ | ⬛ |
| Recetas / costeo KYG | costeo + ingredientes | ⬛ (opcional panadería) | ⬛ | ⬛ |
| Toppings / bebidas / combos | catálogo | ⬛ | ⬛ | 🟡 combos retail simples futuro |
| Domicilios comida | `domiciliarios` | 🟡 opcional “envíos” genérico Fase 4+ | 🟡 opcional visita técnica | 🟡 |
| Zonas domicilio | `zonas_domicilio` | ⬛→🟡 si envíos | ⬛ | ⬛ |
| Menú público cliente | `GET /menu/...` | → catálogo | → servicios publicados | → catálogo |

**Por qué apagar y no borrar:** el código y las tablas ya están; un negocio comida sigue usándolos. Retail simplemente no ve la nav ni pasa el guard.

---

## C. Vertical retail (ropa, calzado, joyas, electrónica, tienda)

| Capacidad | Estado | Por qué hace falta | Dónde ponerlo (futuro) |
|-----------|--------|--------------------|-------------------------|
| Variantes (talla, color, material) | 🔴 | Una “camisa” no es un stock; son N SKUs | BD `producto_variantes` + stock por variante; Nest `catalogo`/`inventario`; Flutter formulario producto |
| SKU interno | 🔴 | Identificar ítem en reportes y traslados | Columna `sku` en producto/variante |
| Código de barras / EAN | 🔴 | Cobro rápido en mostrador | Columna `codigo_barras` + búsqueda API + escáner Flutter (ya hay cámara QR mesas → reutilizar patrón) |
| Venta mostrador rápida | 🟡 | Flujo sin mesa/cocina | Reusar `pedidos` tipo mostrador; UI POS retail |
| Número de serie | 🔴 | Electrónica / celulares | `producto_series` |
| Garantía | 🔴 | Postventa | Campos en serie o tabla `garantias` |
| Precio compra / margen | 🟡 | Ya hay costeo platos; retail necesita costo unitario por SKU | Extender costo a variante sin motor KYG |
| Etiquetas / impresión barcode | 🔴 | Operación tienda | Plantilla impresión |

---

## D. Vertical servicios / reparaciones

| Capacidad | Estado | Por qué | Dónde (futuro) |
|-----------|--------|---------|----------------|
| Órdenes de trabajo (OT) | 🔴 | El “pedido” de un taller no es un ticket instantáneo | Módulo Nest `servicios` + tablas `ordenes_trabajo` |
| Estados OT | 🔴 | Recibido → diagnóstico → cotizado → aprobado → reparando → listo → entregado | Enum + kanban UI (patrón KDS/pedidos) |
| Cotización | 🔴 | Cliente aprueba antes de reparar | `cotizaciones` ligadas a OT |
| Mano de obra + repuestos | 🔴 | Facturar tiempo + piezas | Ítems OT: tipo `mano_obra` \| `repuesto` (repuesto → descuenta inventario) |
| Técnico asignado | 🔴 | Quién hace el trabajo | Reusar patrón asignación domiciliarios |
| Equipo del cliente | 🔴 | “Nevera XYZ serie…” | `equipos_cliente` o JSON en OT |
| Agenda / citas | 🔴 | Visitas a domicilio / turnos taller | `citas` (Fase 2b) |
| Anticipo / abonos | 🟡 | Ya hay abonos en CxC/pedidos | Ligar abonos a OT |

---

## E. Capacidades “Treinta-like” transversales

| Capacidad | Estado | Notas |
|-----------|--------|-------|
| Plan gratis usable | 🟡 | Existe `gratis` con límites muy bajos (5 productos); redefinir para multi-negocio |
| Gastos rápidos | 🟡 | Existe en caja; falta UX “agregar gasto” prominente |
| Recordatorios de cobro | 🔴 | Fiados vencidos + FCM/WhatsApp |
| Catálogo online + link | 🟡 | Menú público existe; generalizar a no-comida |
| Compartir WhatsApp | 🔴 | Deep link + mensaje plantilla |
| Notas / bitácora por cliente | 🔴 | Útil servicios y fiado |

---

## Resumen ejecutivo

| Bloque | % reutilizable hoy (aprox.) | Esfuerzo relativo |
|--------|----------------------------:|-------------------|
| Núcleo caja/ventas/CxC/sedes/SaaS | ~80% | Bajo (UI + gates) |
| Retail variantes/barcode | ~20% | Medio |
| Servicios OT | ~15% (patrones) | Alto |
| Catálogo online genérico | ~50% (menú público) | Medio |
| Terminología + onboarding | 0% (config) | Bajo–medio |

**Conclusión:** la base **sí** sostiene multi-negocio; el trabajo grande no es rehacer Foody, es **variantes + OT + tipo_negocio**.
