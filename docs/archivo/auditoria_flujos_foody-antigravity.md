# Auditoría QA y Arquitectura de Software: Flujos Extremo a Extremo (Foody)

Como QA Lead y Software Architect, he inspeccionado la arquitectura, base de datos, API y eventos de frontend/backend para los flujos especificados. Basado en la especificación actual y los últimos reportes de auditoría E2E, presento el análisis forense de cada flujo y la matriz de riesgos.

---

## 1. Análisis Detallado por Flujo

### 1.1 Cliente → QR → Mesero → Cocina → Caja
- **Pantalla origen**: `MesaQrEntradaScreen` (`/mesa/:qrToken`) → `MenuScreenFoody` → Checkout.
- **Endpoint**: `POST /pedidos` (cliente) → `PATCH /pedidos/:id/aprobar` (mesero) → `PATCH /cocina/items/:id/estado` (cocina) → `POST /pedidos/mesa/:id/cobrar` (caja).
- **Servicio**: `PedidosCrearService` → `PedidosEstadoService` → `CocinasService` → `PedidosPagosService`.
- **Base de datos**: `mesas`, `pedidos`, `pedido_items`, `ingredientes`, `estados_pedido_historial`, `pagos_pedido`, `movimientos_caja`.
- **Evento realtime**: `qr_aprobacion_urgente`, `pedido_actualizado`, `cocina_actualizada`, `mesas_actualizadas`, `caja_movimiento`.
- **Pantalla destino**: Grid de mesas (verde/libre).
- **Hallazgos / Riesgos**:
  - 🔴 **Race Condition de Stock (R10)**: Dos clientes en mesas distintas pueden escanear QR y enviar pedido al mismo tiempo sin saldo suficiente. El API de creación lo permite (`pendiente_aprobacion`), pero estallará al momento que el mesero intente aprobar (`STOCK_INSUFICIENTE`).
  - 🟠 **Estado Operativo Desincronizado (R2)**: La mesa se marca como ocupada de forma indirecta (LATERAL en BD). Si se libera mal, el estado visual choca con la BD.

### 1.2 Cliente → QR → Mesero → Cocina → Domiciliario
- **Pantalla origen / destino**: N/A (Flujo Inválido).
- **Hallazgos / Riesgos**:
  - 🔴 **Estado Imposible por Diseño**: El flujo de QR (escaneo de mesa física) fuerza un `tipo=mesa` y un `mesa_id`. Un pedido atado a una mesa física **nunca** debe pasar a manos de un domiciliario en el estado final (requeriría un `tipo=domicilio`). Es una desconexión semántica. Si el cliente de la mesa quiere algo para su casa, es el mesero quien debe agregar un sub-pedido `tipo=para_llevar` asociado a la misma cuenta, pero no un delivery externo.

### 1.3 Mesero → Pedido → Cocina
- **Pantalla origen**: `PedidoCajeroScreen` / `PanelMeseroScreen`.
- **Endpoint**: `POST /pedidos/staff` (tipo mesa o llevar).
- **Servicio**: `PedidosCrearService`.
- **Base de datos**: `pedidos`, `pedido_items`, descuenta de `inventario_items`.
- **Evento realtime**: `pedido_actualizado`.
- **Pantalla destino**: `KdsScreen` (Cocina).
- **Hallazgos / Riesgos**:
  - 🟡 **Dato Huérfano en Turno de Caja (R13 / Brecha de Caja)**: Si el mesero, sin tener turno de caja asignado, llega a ejecutar un cobro (si la UI lo permite de manera errónea), la BD lo registrará como `pagado` sin insertar el correspondiente `movimiento_caja`, descuadrando la contabilidad diaria.

### 1.4 Cocina → Pedido listo → Mesero
- **Pantalla origen**: `KdsScreen`.
- **Endpoint**: `PATCH /cocina/items/:id/estado` → `listo`.
- **Servicio**: `CocinasService.cambiarEstadoItem`.
- **Base de datos**: `pedido_items.estado_cocina`, `pedidos.estado`.
- **Evento realtime**: `cocina_actualizada`, `pedido_actualizado`.
- **Pantalla destino**: `MesasGridWidget` / Kanban (columna "Listo").
- **Hallazgos / Riesgos**:
  - 🟠 **Regresión Inesperada (R11)**: Si un cocinero desmarca por error un ítem de "listo" a "pendiente", el sistema puede regresar el pedido global al estado obsoleto `confirmado` en lugar de dejarlo en `en_cocina`, rompiendo la visibilidad del Kanban moderno.

### 1.5 Cocina → Pedido listo → Domiciliario
- **Pantalla origen**: `KdsScreen`.
- **Endpoint**: Backend interno post-listo → `DispatchService.intentarDispatchAutomatico` o asignación manual.
- **Servicio**: `CocinasService` → `DispatchService` / `DomiciliariosService`.
- **Base de datos**: `asignaciones_domicilio`, `ofertas_pedido`.
- **Evento realtime**: `oferta_nueva`, `pedido_asignado`.
- **Pantalla destino**: App Domiciliario.
- **Hallazgos / Riesgos**:
  - 🔴 **Bypass del Flujo de Entrega (R3)**: En domicilios, el sistema permitía saltar del estado `listo` directamente a `entregado` sin pasar por `asignado` ni `en_camino`. Esto deja la entrega sin rastro de quién lo llevó.
  - 🟠 **Condición de Carrera en Dispatch (R8)**: El dispatch automático no procede si encuentra un domiciliario de planta libre (espera asignación manual). Si el admin olvida asignarlo en el Kanban, el pedido queda "listo" (frío) infinitamente sin disparar oferta a independientes.

### 1.6 Caja → Pago → Liberación de mesa
- **Pantalla origen**: `MesaPedidosSheet` (Panel Cajero).
- **Endpoint**: `POST /pedidos/mesa/:id/cobrar`.
- **Servicio**: `PedidosPagosService.cobrarCuentaMesa`.
- **Base de datos**: `pagos_pedido`, `movimientos_caja`, actualiza `mesas.mesera_asignada_id = null`.
- **Evento realtime**: `mesas_actualizadas`, `caja_movimiento`.
- **Pantalla destino**: `MesasGridWidget` (mesa libre).
- **Hallazgos / Riesgos**:
  - 🔴 **Mesa liberada con impago (R1)**: Existe una brecha operativa si se marca un pedido como "Entregado" a través de acciones rápidas del Kanban. Esto puede desencadenar la liberación de la mesa aunque el `monto_pagado` sea menor al total.

### 1.7 Inventario → Stock agotado → Menú
- **Pantalla origen**: Panel Admin Inventario.
- **Endpoint**: `PATCH /inventario/ingredientes/:id` (Ajuste manual) o Venta transaccional.
- **Servicio**: `InventarioService` / `PedidosInventarioService`.
- **Base de datos**: `ingredientes.stock_actual`, `productos.disponible`.
- **Evento realtime**: `catalogo_disponibilidad`.
- **Pantalla destino**: `MenuScreenFoody` (Cliente).
- **Hallazgos / Riesgos**:
  - 🔴 **Conexión Rota (R4)**: Si el stock llega a 0 por una venta, el menú se actualiza en tiempo real. PERO si el administrador hace un *ajuste manual* a 0 o se registra una merma manual, el módulo no propaga automáticamente el cambio hacia `productos.disponible`. Resultado: El cliente sigue viendo y pidiendo el plato agotado.

### 1.8 Admin → Transferencia de mesa
- **Pantalla origen**: `MesasGridWidget`.
- **Endpoint**: `POST /mesas/transferir`.
- **Servicio**: `MesasService.transferir`.
- **Base de datos**: `pedidos.mesa_id`, `transferencias_mesa`.
- **Evento realtime**: `mesas_actualizadas`.
- **Pantalla destino**: `MesasGridWidget`.
- **Hallazgos / Riesgos**:
  - 🟡 **Proceso sin Auditoría (R6)**: El traslado de mesa registra el salto en `transferencias_mesa`, pero escapa al log global de la compañía (`auditoria_logs`).
  - 🟡 **Race Condition sin Lock (R7)**: Si dos administradores transfieren distintos pedidos concurrentemente hacia la *misma mesa destino* aparentemente libre, al no tener `SELECT ... FOR UPDATE` en la transacción, el sistema acepta ambas, mezclando cuentas accidentalmente.

### 1.9 Admin → Cierre de caja
- **Pantalla origen**: `PanelCajeroScreen`.
- **Endpoint**: `POST /caja/cerrar`.
- **Servicio**: `CajaService.cerrar`.
- **Base de datos**: `cajas`, `auditoria_logs`.
- **Evento realtime**: N/A (alerta batch opcional).
- **Pantalla destino**: Reportes financieros.
- **Hallazgos / Riesgos**:
  - 🟠 **Permisividad Temeraria (R13)**: Un cajero puede forzar el cierre de la caja aunque haya clientes sentados comiendo (mesas en estado `pagando`, `en_cocina`). El backend no realiza un "hard stop" ni validación que impida cerrar el turno con dinero flotante en el salón.

---

## 2. Matriz de Auditoría y Riesgos Detectados

| FLUJO | TABLAS | APIS | EVENTOS | RIESGOS DETECTADOS | ESTADO E2E |
|-------|--------|------|---------|---------------------|------------|
| **Cliente→QR→Mesero→Caja** | `mesas`, `pedidos`, `pedido_items`, `pagos_pedido`, `movimientos_caja` | `GET /menu/mesa/:token`<br>`POST /pedidos`<br>`PATCH /pedidos/:id/aprobar`<br>`POST /pedidos/mesa/:id/cobrar` | `qr_aprobacion_urgente`<br>`pedido_actualizado`<br>`cocina_actualizada`<br>`mesas_actualizadas`<br>`caja_movimiento` | **[P0]** Liberación de mesa sin cobro total.<br>**[P1]** `estado_operativo` desincronizado BD vs UI.<br>**[P2]** Race condition de stock QR. | 🟡 Parcial (Brechas UI/BD) |
| **Cliente→QR→Domi** | — | — | — | **[P0]** Estado imposible por diseño (Mesa ≠ Delivery). | 🚫 Bloqueado |
| **Mesero→Cocina** | `pedidos`, `pedido_items`, `inventario_items` | `POST /pedidos/staff` | `pedido_actualizado` | **[P2]** Ausencia de movimiento de caja si el flujo es defectuoso. | ✅ OK |
| **Cocina→Listo→Mesero** | `pedido_items`, `pedidos` | `PATCH /cocina/items/:id/estado` | `cocina_actualizada`<br>`pedido_actualizado` | **[P1]** KDS regresa estado global erróneo a `confirmado`. | 🟡 Riesgo Regresión |
| **Cocina→Listo→Domi** | `asignaciones_domicilio`, `ofertas_pedido` | Backend Dispatch | `oferta_nueva`<br>`pedido_asignado` | **[P0]** Salto de estados directo a entregado.<br>**[P1]** Pedidos atascados sin repartidor de planta. | 🟡 Riesgo Operativo |
| **Caja→Pago→Mesa libre** | `pagos_pedido`, `mesas` | `POST /pedidos/mesa/:id/cobrar` | `mesas_actualizadas`<br>`caja_movimiento` | **[P0]** Diferencia contable si se usa botón rápido sin pasar por pasarela de caja. | 🟡 Parcial |
| **Inventario→Menú** | `ingredientes`, `productos` | `PATCH /inventario/ingredientes/:id` | `catalogo_disponibilidad` | **[P0]** Ajustes manuales no desencadenan cascada de invisibilidad en el menú. | 🔴 Conexión Rota |
| **Admin→Transferir Mesa** | `transferencias_mesa` | `POST /mesas/transferir` | `mesas_actualizadas` | **[P2]** Race condition sin DB lock.<br>**[P2]** Bypass a tabla de `auditoria_logs`. | 🟡 Concurrencia |
| **Admin→Cierre Caja** | `cajas`, `movimientos_caja` | `POST /caja/cerrar` | N/A | **[P1]** Cierre permitido con comandas en curso en el salón. | 🟡 Validación Floja |

---

> **Dictamen como QA / Architect**: 
> La arquitectura del sistema soporta las complejidades de un entorno ERP Gastronómico (transacciones, bloqueos, scopes, etc.). Sin embargo, la seguridad operativa (evitar mermas económicas y fraudes) tiene vulnerabilidades (P0 y P1) en los límites transaccionales:
> 1. Ajustes manuales de inventario no propagan apagados del menú.
> 2. Liberación de mesas y domicilios que permiten by-pass sin validación del objeto de caja real (`monto_pagado`).
> 
> Es imperativo priorizar la ejecución de los tickets **P0.1 a P1.4** antes de pasar a producción.
