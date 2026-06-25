# Endpoints del API — Foody
## Referencia sincronizada con controllers NestJS (2026-06-17)

Base URL: `/api/v1`  
Respuesta: `{ exito, datos, mensaje }` o `{ exito: false, error, mensaje }`

**Auth en tablas:** 🌐 público · **Bearer** JWT staff · **Bearer domi** domiciliario independiente · **super** solo `super_admin`

**Planes:** login y `GET /auth/perfil` devuelven `plan` y `modulos[]`. Rutas con módulo Pro/Enterprise usan `PlanFeaturesGuard` → error `PLAN_NO_INCLUYE_MODULO`.

---

## Autenticación

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| POST | /auth/login | 🌐 | Login staff |
| POST | /auth/login-domiciliario | 🌐 | Login domiciliario independiente |
| POST | /auth/registro-domiciliario | 🌐 | Registro independiente (rate limit) |
| GET | /auth/perfil | Bearer | Perfil, permisos, plan y módulos |

---

## Salud

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /salud | 🌐 | Health check |

---

## Ciudades y restaurantes (públicos)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /ciudades | 🌐 | Ciudades activas |
| GET | /ciudades/:slug/restaurantes | 🌐 | Restaurantes por ciudad |
| GET | /restaurantes/:id/sucursales | 🌐 | Sucursales de un restaurante |

---

## Sucursales (staff)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /sucursales/mi-restaurante | Bearer | Sucursales del restaurante del usuario |
| POST | /sucursales | Bearer | Crear sucursal |
| GET | /sucursales/:sucursalId/horarios | Bearer | Horarios de sucursal |
| PATCH | /sucursales/horarios/:horarioId | Bearer | Actualizar horario |

---

## Menú (público)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /menu/mesa/:qr_token | 🌐 | Menú + datos de mesa por QR |
| GET | /menu/:sucursal_id | 🌐 | Menú completo de sucursal |

---

## Dispositivos cliente

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| POST | /dispositivos/registrar | 🌐 | Registrar `device_id` / FCM (rate limit) |

---

## Geografía

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /geografia/buscar | 🌐 | Autocompletar dirección (Photon/OSM) |

---

## Dashboard

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /dashboard/resumen | Bearer | KPIs operativos de sucursal |

---

## Pedidos — cliente (público)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| POST | /pedidos | 🌐 | Crear pedido (rate limit) |
| GET | /pedidos/mios | 🌐 | Historial por `device_id` |
| GET | /pedidos/:id/estado | 🌐 | Seguimiento público |

---

## Pedidos — staff

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /pedidos | Bearer | Listar por `sucursal_id` |
| GET | /pedidos/mesa/:mesaId | Bearer | Pedidos activos de mesa + ítems |
| POST | /pedidos/mesa/:mesaId/cobrar | Bearer | Cobrar cuenta mesa → `pagado` + caja |
| POST | /pedidos/staff | Bearer | Crear pedido desde staff |
| POST | /pedidos/:id/items | Bearer | Agregar ítems a pedido abierto |
| DELETE | /pedidos/:id/items/:itemId | Bearer | Eliminar ítem (alerta si post-cocina) |
| PATCH | /pedidos/:id/estado | Bearer | Cambiar estado (máquina en `pedido-estados.ts`) |
| POST | /pedidos/:id/descuento | Bearer | Aplicar descuento |
| PATCH | /pedidos/:id/aprobar | Bearer | Aprobar pedido QR mesa |
| PATCH | /pedidos/:id/rechazar | Bearer | Rechazar pedido QR mesa |

---

## Mesas

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| POST | /mesas/asignar-turno | Bearer | Asignación masiva mesera por mesa |
| POST | /mesas/transferir | Bearer | Transferir pedido entre mesas |
| GET | /mesas/:id/qr | Bearer | URL/HTML QR de mesa |
| GET | /mesas/:sucursal_id | Bearer | Grid mesas con estado |
| POST | /mesas | Bearer | Crear mesa |
| PATCH | /mesas/:id | Bearer | Actualizar mesa |
| DELETE | /mesas/:id | Bearer | Desactivar mesa |

---

## Caja

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /caja/activa/:sucursal_id | Bearer | Caja abierta del turno |
| POST | /caja/abrir | Bearer | Abrir turno |
| POST | /caja/cerrar | Bearer | Cerrar turno |
| GET | /caja/cuentas-por-cobrar/:sucursal_id | Bearer | Fiados pendientes |
| POST | /caja/cuentas-por-cobrar | Bearer | Registrar fiado |
| PATCH | /caja/cuentas-por-cobrar/:id/pagar | Bearer | Cobrar fiado |
| GET | /caja/:caja_id/movimientos | Bearer | Movimientos del turno |
| POST | /caja/retiro-parcial | Bearer | Retiro parcial |
| POST | /caja/gastos | Bearer | Gasto operativo |

---

## Catálogo — categorías

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /categorias/:sucursal_id | Bearer | Listar |
| POST | /categorias | Bearer | Crear |
| PATCH | /categorias/:id | Bearer | Actualizar |
| DELETE | /categorias/:id | Bearer | Eliminar |

## Catálogo — productos

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /productos/sucursal/:sucursal_id | Bearer | Listar productos admin |
| POST | /productos | Bearer | Crear |
| PATCH | /productos/:id/disponibilidad | Bearer | Disponibilidad |
| POST | /productos/:id/toppings | Bearer | Vincular topping |
| POST | /productos/:id/bebidas | Bearer | Vincular bebida |
| GET | /productos/:id/items-incluidos | Bearer | Ítems incluidos (costeo) |
| PUT | /productos/:id/items-incluidos | Bearer | Configurar ítems incluidos |
| PATCH | /productos/:id | Bearer | Actualizar producto |

## Catálogo — toppings, bebidas, combos

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /toppings/:sucursal_id | Bearer | Listar toppings |
| POST | /toppings | Bearer | Crear topping |
| PATCH | /toppings/:id | Bearer | Actualizar topping |
| GET | /bebidas/:sucursal_id | Bearer | Listar bebidas |
| POST | /bebidas | Bearer | Crear bebida |
| PATCH | /bebidas/:id | Bearer | Actualizar bebida |
| GET | /combos/:sucursal_id | Bearer | Listar combos |
| POST | /combos | Bearer | Crear combo |
| PATCH | /combos/:id/disponibilidad | Bearer | Disponibilidad combo |

---

## Cocinas e impresoras (módulo `cocina`)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /cocinas/:sucursal_id | Bearer | CRUD cocinas |
| POST | /cocinas | Bearer | Crear cocina |
| PATCH | /cocinas/:id | Bearer | Actualizar |
| DELETE | /cocinas/:id | Bearer | Eliminar |
| GET | /impresoras/:sucursal_id | Bearer | Listar impresoras |
| POST | /impresoras | Bearer | Crear impresora |
| PATCH | /impresoras/:id | Bearer | Actualizar |
| DELETE | /impresoras/:id | Bearer | Eliminar |

## KDS cocina

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /cocina/cocinas | Bearer | Cocinas de la sucursal del usuario |
| GET | /cocina/tickets/:cocina_id | Bearer | Tickets KDS |
| PATCH | /cocina/items/:item_id/estado | Bearer | Estado ítem en cocina |

---

## Inventario (módulo `inventario`)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /inventario/hermanas/resumen | Bearer | Stock sucursales hermanas (lectura) |
| POST | /inventario/conteos/iniciar/:sucursal_id | Bearer | Iniciar conteo físico |
| POST | /inventario/conteos/:conteo_id/cerrar | Bearer | Cerrar conteo |
| GET | /inventario/movimientos/:sucursal_id | Bearer | Historial movimientos |
| GET | /inventario/costos/:sucursal_id | Bearer | Costos productos |
| GET | /inventario/producto-ingredientes/:producto_id | Bearer | Receta producto |
| POST | /inventario/producto-ingredientes | Bearer | Configurar receta |
| POST | /inventario/compras | Bearer | Registrar compra |
| GET | /inventario/:sucursal_id | Bearer | Ingredientes y stock |
| POST | /inventario | Bearer | Crear ingrediente |
| PATCH | /inventario/:id | Bearer | Actualizar ingrediente |

---

## Costeo (módulo `costeo`)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /costeo/resumen/:sucursal_id | Bearer | Resumen costeo |
| GET | /costeo/subrecetas/:sucursal_id | Bearer | Listar subrecetas |
| GET | /costeo/subrecetas/detalle/:id | Bearer | Detalle subreceta |
| GET | /costeo/combos/:sucursal_id | Bearer | Combos en costeo |
| POST | /costeo/recalcular/:sucursal_id | Bearer | Recalcular sucursal |
| GET | /costeo/productos/:id/impacto-stock | Bearer | Impacto stock por plato |
| POST | /costeo/productos/:id/recalcular | Bearer | Recalcular producto |
| POST | /costeo/combos/:id/recalcular | Bearer | Recalcular combo |
| POST | /costeo/subrecetas | Bearer | Crear subreceta |
| PATCH | /costeo/subrecetas/:id | Bearer | Actualizar subreceta |
| POST | /costeo/subrecetas/:id/recalcular | Bearer | Recalcular subreceta |

---

## Zonas domicilio (módulo `zonas_domicilio`)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /zonas/cotizar-domicilio | 🌐 | Cotizar costo por lat/lng |
| GET | /zonas/sucursal/:sucursal_id/configuracion-mapa | Bearer | Config mapa admin |
| PATCH | /zonas/sucursal/:sucursal_id/ubicacion | Bearer | Ubicación sede |
| GET | /zonas/:sucursal_id | Bearer | Anillos de cobertura |
| POST | /zonas | Bearer | Crear zona |
| PATCH | /zonas/:id | Bearer | Actualizar zona |
| DELETE | /zonas/:id | Bearer | Desactivar zona |

---

## Promociones

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /promociones | 🌐 | Promociones activas (cliente) |
| GET | /promociones/ciudad/:slug/stories | 🌐 | Stories por ciudad |
| GET | /promociones/validar-codigo | 🌐 | Validar código en checkout |
| POST | /promociones/:id/vista | 🌐 | Registrar vista |
| GET | /promociones/admin/:sucursal_id | Bearer | Listado admin |
| POST | /promociones | Bearer | Crear promoción |
| PATCH | /promociones/:id | Bearer | Actualizar promoción |

---

## Facturación (módulo `facturacion`)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /facturacion/config/:sucursal_id | Bearer | Config fiscal |
| POST | /facturacion/config | Bearer | Guardar config |
| GET | /facturacion/facturas/:sucursal_id | Bearer | Listar facturas |
| POST | /facturacion/emitir/:pedido_id | Bearer | Emitir borrador/HTML |
| GET | /facturacion/facturas/:id/pdf | Bearer | Preview PDF/HTML |

---

## Alertas

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| POST | /alertas/evaluar/:sucursal_id | Bearer | Evaluar reglas batch |
| GET | /alertas/:sucursal_id | Bearer | Listar alertas |
| PATCH | /alertas/:id/revisar | Bearer | Marcar revisada |

---

## Reportes (módulo `reportes`)

Query: `?sucursal_id=&desde=YYYY-MM-DD&hasta=YYYY-MM-DD`

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /reportes/financiero | Bearer | Resumen + **`cuadre_caja`** (pedidos vs caja por fecha pedido) |
| GET | /reportes/productos | Bearer | Ranking productos |
| GET | /reportes/pedidos | Bearer | Por estado y por día |

**`cuadre_caja`:** `ventas_pedidos`, `ventas_movimientos_caja`, `diferencia`, `movimientos_venta`, `por_metodo_caja[]`.

---

## Usuarios staff

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /usuarios | Bearer | Listar por sucursal |
| POST | /usuarios | Bearer | Crear usuario |
| PATCH | /usuarios/:id/estado | Bearer | Activar/desactivar |

---

## Domiciliarios planta (admin)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /domiciliarios-planta/disponibles/:sucursal_id | Bearer | Disponibles |
| POST | /domiciliarios-planta/asignar | Bearer | Asignar a pedido |
| POST | /domiciliarios-planta/dispatch-independiente/:pedido_id | Bearer | Dispatch independientes |

## Domiciliario planta (app)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /domiciliario/pedidos-asignados | Bearer | Pedidos activos |
| PATCH | /domiciliario/pedidos/:id/en-camino | Bearer | En camino |
| PATCH | /domiciliario/pedidos/:id/confirmar-entrega | Bearer | Confirmar entrega |
| GET | /domiciliario/historial | Bearer | Historial |
| GET | /domiciliario/estadisticas | Bearer | Estadísticas |

## Domiciliarios independientes

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| POST | /domiciliarios/sesion/iniciar | Bearer domi | Iniciar turno |
| POST | /domiciliarios/sesion/ubicacion | Bearer domi | GPS |
| POST | /domiciliarios/sesion/cerrar | Bearer domi | Cerrar turno |
| GET | /domiciliarios/ofertas-activas | Bearer domi | Ofertas |
| POST | /domiciliarios/ofertas/:id/responder | Bearer domi | Aceptar/rechazar |
| GET | /domiciliarios/pedidos-activos | Bearer domi | Activos |
| PATCH | /domiciliarios/pedidos/:id/en-camino | Bearer domi | En camino |
| PATCH | /domiciliarios/pedidos/:id/confirmar-entrega | Bearer domi | Entregar |
| GET | /domiciliarios/ganancias | Bearer domi | Ganancias |

---

## Super Admin (`/super`)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | /super/resumen | super | KPIs plataforma |
| GET | /super/estadisticas | super | Estadísticas globales |
| GET | /super/ciudades | super | Ciudades |
| POST | /super/ciudades | super | Crear ciudad |
| PATCH | /super/ciudades/:id | super | Actualizar ciudad |
| GET | /super/restaurantes | super | Restaurantes |
| POST | /super/restaurantes | super | Crear restaurante |
| PATCH | /super/restaurantes/:id | super | Actualizar restaurante |
| GET | /super/restaurantes/:restauranteId/sucursales | super | Sucursales |
| GET | /super/suscripciones | super | Suscripciones |
| PATCH | /super/suscripciones/:id | super | Plan, estado, vencimiento |
| GET | /super/usuarios | super | Usuarios globales |
| POST | /super/usuarios | super | Crear usuario |
| PATCH | /super/usuarios/:id | super | Actualizar usuario |
| POST | /super/usuarios/:id/cambiar-contrasena | super | Cambiar contraseña |
| PATCH | /super/usuarios/:id/estado | super | Activar/desactivar |
| GET | /super/domiciliarios | super | Independientes |
| PATCH | /super/domiciliarios/:id/estado | super | Estado independiente |
| GET | /super/domiciliarios/documentos-pendientes | super | Docs pendientes |
| POST | /super/domiciliarios/:id/aprobar-documento | super | Aprobar doc |
| POST | /super/domiciliarios/:id/rechazar-documento | super | Rechazar doc |
| GET | /super/configuracion | super | Config global |
| PATCH | /super/configuracion/:clave | super | Actualizar config |

---

## Códigos de error frecuentes

| Código | Significado |
|--------|-------------|
| `STOCK_INSUFICIENTE` | Sin ingredientes |
| `PRODUCTO_NO_DISPONIBLE` | Producto no disponible |
| `RESTAURANTE_CERRADO` | Fuera de horario |
| `MESA_NO_ENCONTRADA` | Mesa/QR inválido |
| `CAJA_NO_ABIERTA` | Sin turno de caja abierto |
| `MESA_SIN_PEDIDOS` | Cobro mesa sin pedidos activos |
| `TRANSICION_ESTADO_INVALIDA` | Cambio de estado no permitido |
| `PLAN_NO_INCLUYE_MODULO` | Plan sin módulo requerido |
| `MESA_ASIGNADA_OTRA_MESERA` | Mesa de otra mesera |
| `PEDIDO_CERRADO` | No se pueden agregar ítems |

---

## Rutas eliminadas / no implementadas (spec legacy)

No usar en integraciones nuevas: `/pedidos/cocina/:id`, `/pedidos/items/:id/cocina-estado`, `/mesas/:id/qr-pdf`, `/reportes/inventario`, `/reportes/domiciliarios`, `/auditoria/:sucursal_id`, `PATCH /dispositivos/ciudad`, `/auth/renovar-token`, `/auth/logout`.
