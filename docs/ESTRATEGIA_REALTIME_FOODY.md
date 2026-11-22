# Foody — Estrategia de eventos y Realtime

> **Rol:** Especialista sistemas distribuidos / eventos realtime  
> **Fecha:** 2026-06-12 (actualizado tras RT-1…RT-5)  
> **Base:** `RealtimeBroadcastService`, `FoodyRealtime`, migración 047, UI brechas jun-12

---

## 0. Resumen ejecutivo (jul-01)

| Fase | Estado | Notas |
|------|--------|-------|
| **RT-1** Cocina KDS | ✅ | `cocina_actualizada` desde `CocinasService`, `pedidos-items`, `pedidos-soporte`; `KdsScreen` RT + poll 60 s |
| **RT-2** Domiciliarios | ✅ | Canales planta/indep; dashboards RT + poll 60 s |
| **RT-3** Sheet mesa | ✅ | `MesaPedidosSheet` suscribe sucursal |
| **RT-4** Caja | ✅ | `caja_movimiento` en cobro mesa, pagos, apertura, retiro, gasto, devolución, cierre; `CajaAdminScreen` escucha |
| **RT-5** Debounce/coalesce | ✅ | `FoodyRealtime` 300 ms; evento `sucursal_actualizada` si lote mixto; re-emite eventos filtrados |
| **RT-7** Eventos recomendados | ✅ | `qr_aprobacion_urgente`, `catalogo_disponibilidad`, `event_id` UUID |
| **RT-8** Coherencia domi/caja/GPS | ✅ | `llamar_mesera`, `ubicacion_repartidor`, `oferta_expirada`, `pedido_desasignado`, dedup Flutter |
| **RT-9** Canal seguimiento opaco | ✅ | `seguimiento_token` + `pedido_{id}_{token}`; API estado con auth |
| **RT-6** FCM | ⏳ | Pospuesto — ver §10 |

**Próximo paso Realtime:** FCM (RT-6, Sprint 7). Ítems checklist opcionales (cron QR 3/5 min, KDS segunda estación, modo degradado §5.1) — no bloquean piloto.

---

## 1. Estado actual (inventario técnico)

### Infraestructura existente

| Componente | Ubicación | Notas |
|------------|-----------|-------|
| Emisor | `foody_backend/src/core/realtime/realtime-broadcast.service.ts` | Supabase **broadcast** con service key; `ack: false` |
| Cliente Flutter | `lib/core/realtime/foody_realtime.dart` | Solo escucha broadcast (no `postgres_changes`) |
| Fallback | — | Si `SUPABASE_URL/KEY` faltan, broadcast se desactiva **silenciosamente** |

### Eventos implementados hoy

| Evento | Canal | Emisor (quién dispara) | Receptor Flutter hoy |
|--------|-------|------------------------|----------------------|
| `pedido_actualizado` | `sucursal_{id}` | Pedidos (crear, estado, aprobar, ítems, cobrar…) | Kanban, mesas, sheet mesa |
| `mesas_actualizadas` | `sucursal_{id}` | MesasService; Pedidos agregar/cobrar | Grid mesas |
| `estado_actualizado` | `pedido_{id}_{seguimiento_token}` | Pedidos seguimiento | Seguimiento cliente (RT-9) |
| `cocina_actualizada` | `cocina_{id}` | CocinasService, pedidos-items, pedidos-soporte | KdsScreen |
| `caja_movimiento` | `sucursal_{id}` | CajaService, pedidos-pagos, pedidos-crear | CajaAdminScreen |
| `alerta_nueva` | `sucursal_{id}` | AlertasRiesgoService (parcial) | AlertasAdminScreen |
| `pedido_asignado` | `domiciliario_{userId}` | DomiciliariosService | Dashboard domi planta |
| `oferta_nueva` | `domiciliario_indep_{id}` | DispatchService | Dashboard domi independiente |

### Polling activo hoy (respaldo RT)

| Pantalla | Intervalo | Motivo |
|----------|-----------|--------|
| `KdsScreen` | 60 s | Respaldo si WebSocket cae |
| `DashboardDomiciliarioIndependienteScreen` | 60 s | Respaldo ofertas |
| `DashboardDomiciliarioScreen` (planta) | 60 s | Respaldo asignaciones |
| `PedidosKanbanWidget` | 30–60 s | `PollRealtimeRespaldo` (R9) |
| `MesasGridWidget` | 30–60 s | `PollRealtimeRespaldo` (R9) |
| `MesaPedidosSheet` | 30–60 s | `PollRealtimeRespaldo` (R9) |
| `CajaAdminScreen` | 30–60 s | `PollRealtimeRespaldo` (R9) |
| `AlertasAdminScreen` | 30–60 s | `PollRealtimeRespaldo` (R9) |
| `SeguimientoPedidoScreen` | 30–60 s | `PollRealtimeRespaldo` (R9) |
| Kanban reloj UI | 30 s | Solo reloj visual, no refetch |
| Grid mesas pulso QR | 800 ms | Animación UI, no datos |

### Hueco crítico (resuelto RT-1)

`CocinasService.cambiarEstadoItem` emite `cocina_actualizada` post-commit. KDS usa RT primario; poll 60 s solo como fallback híbrido (§7.1).

---

## 2. Taxonomía de latencia (criterio Foody)

| Clase | Latencia objetivo | Mecanismo |
|-------|-------------------|-----------|
| **RT-OBL** | < 2 s | Supabase broadcast (canal sucursal/pedido/domi/cocina) |
| **RT-REC** | < 5 s | Broadcast o poll corto (5–15 s) con RT como primario |
| **POLL** | 15–60 s | Timer + pull-to-refresh; aceptable en backoffice |
| **MANUAL** | Bajo demanda | RefreshIndicator; config admin, reportes históricos |

**Regla:** Todo evento **RT-OBL** debe tener **fallback POLL** si WebSocket cae (patrón híbrido ya usado en KDS).

**FCM (futuro Sprint 7):** Capa push para staff **sin pantalla abierta** — complementa broadcast, no lo reemplaza.

---

## 3. Catálogo de eventos por dominio

Formato: **Generador → Receptor | Prioridad | Tecnología | Riesgo si falla | Estado**

---

### 3.1 MESAS

| Evento | Generador | Receptor | Prioridad | Tecnología | Riesgo si falla | Estado |
|--------|-----------|----------|-----------|------------|-----------------|--------|
| QR pendiente en mesa (nuevo pedido mesa) | `POST /pedidos` cliente | Grid mesas, mesero | **RT-OBL** | `pedido_actualizado` sucursal | Mesera no ve naranja; demora >3 min | ✅ |
| Mesa ocupada/libre cambia | Cobrar mesa, cancelar, transferir | Grid mesas | **RT-OBL** | `mesas_actualizadas` | Doble asignación mesa, overbooking visual | ✅ |
| Total acumulado mesa cambia | agregarItems, nuevo pedido | `MesaPedidosSheet` | **RT-REC** | refetch on `pedido_actualizado` / coalesce | Mesero cobra total desactualizado | ✅ RT-3 |
| Timer urgencia QR 3/5 min | Job backend / tick | Grid + alertas admin | **RT-REC** | `qr_aprobacion_urgente` + FCM | Incumple spec negocio | ❌ solo UI local |
| CRUD mesa (admin) | MesasService | Grid admin | **POLL** | `mesas_actualizadas` | Bajo — admin puede F5 | ✅ |
| Mesera asignada cambia | Aprobar/confirmar staff | Grid mesero | **RT-REC** | refetch `mesas_actualizadas` | Mesera B intenta mesa de A | ✅ |

---

### 3.2 PEDIDOS

| Evento | Generador | Receptor | Prioridad | Tecnología | Riesgo si falla | Estado |
|--------|-----------|----------|-----------|------------|-----------------|--------|
| Nuevo pedido (cualquier tipo) | PedidosService.crear | Kanban, cocina (indirecto) | **RT-OBL** | `pedido_actualizado` | Pedido invisible en cocina/kanban | ✅ |
| Cambio estado pedido | cambiarEstado, aprobar, rechazar | Kanban, seguimiento cliente | **RT-OBL** | `pedido_actualizado` + `estado_actualizado` | Cliente/staff desincronizados | ✅ |
| Ítems agregados a pedido | agregarItems | Kanban, cocina, mesa sheet | **RT-OBL** | `pedido_actualizado` + `cocina_actualizada` | Cocina no prepara ítem nuevo | ✅ |
| Descuento aplicado | aplicarDescuento | Kanban, caja | **RT-REC** | `pedido_actualizado` | Total mostrado incorrecto | ✅ |
| Pedido cancelado/rechazado | cambiarEstado | Kanban, mesas, cliente | **RT-OBL** | broadcast + seguimiento | Stock/cocina fantasma | ✅ |
| Cobro cuenta mesa (pagado) | cobrarCuentaMesa | Kanban, grid mesas, caja | **RT-OBL** | `pedido_actualizado` + `mesas_actualizadas` + `caja_movimiento` | Mesa sigue ocupada en UI | ✅ |
| Columna Kanban drag | PATCH estado | Otros kanbans abiertos | **RT-OBL** | `pedido_actualizado` | Dos staff mueven mismo pedido | ✅ |
| Listado histórico / reportes | — | Admin reportes | **MANUAL** | GET bajo demanda | Ninguno operativo | ✅ diseño OK |

---

### 3.3 COCINA

| Evento | Generador | Receptor | Prioridad | Tecnología | Riesgo si falla | Estado |
|--------|-----------|----------|-----------|------------|-----------------|--------|
| **Ticket nuevo** en estación | crear/aprobar/agregarItems | KDS cocina | **RT-OBL** | `cocina_actualizada` canal `cocina_{id}` | Retraso comida, clientes esperan | ✅ RT-1 |
| Ítem → preparando | cambiarEstadoItem | KDS, mesero sheet | **RT-OBL** | `cocina_item_estado` | Mesero no sabe que empezaron | ✅ |
| Ítem → listo | cambiarEstadoItem | KDS, mesero, kanban | **RT-OBL** | `cocina_actualizada` + `pedido_actualizado` si pedido→listo | Comida fría en paso | ✅ |
| Pedido global → listo | CocinasService recálculo | Kanban, mesero | **RT-REC** | `pedido_actualizado` | — | ✅ |
| Ticket impreso (futuro) | Python printer ACK | KDS opcional | **RT-REC** | WebSocket local + opcional broadcast | Doble impresión | ❌ S10 |
| Demora > 20 min ticket | Job / KDS timer | KDS + alertas | **POLL** 60s + alerta batch | Cron alertas | SLA cocina incumplido | ❌ |
| Config cocinas/impresoras | Admin CRUD | KDS al reconectar | **MANUAL** | — | Bajo | ✅ |

---

### 3.4 QR (cliente)

| Evento | Generador | Receptor | Prioridad | Tecnología | Riesgo si falla | Estado |
|--------|-----------|----------|-----------|------------|-----------------|--------|
| Pedido QR enviado | POST público | Seguimiento cliente | **RT-OBL** | suscripción al abrir seguimiento | Cliente ansioso refresca | ✅ al estar en pantalla |
| Aprobado / rechazado mesera | aprobarMesa / rechazar | Seguimiento cliente | **RT-OBL** | `estado_actualizado` | Cliente no sabe si cocinan | ✅ |
| Estado cocina / listo | cambiarEstado / cocina | Seguimiento cliente | **RT-REC** | `estado_actualizado` (solo estado pedido, no ítem) | UX pobre “sigue en cocina” | 🟡 |
| Mis pedidos (historial) | — | Cliente lista | **MANUAL** | GET /pedidos/mios | Bajo | ✅ |
| Menú / precios | — | Cliente menú | **MANUAL** | GET al entrar | Precio desactualizado raro | ✅ OK |

---

### 3.5 DOMICILIOS

| Evento | Generador | Receptor | Prioridad | Tecnología | Riesgo si falla | Estado |
|--------|-----------|----------|-----------|------------|-----------------|--------|
| **Nueva asignación** planta | Admin / auto | App domiciliario planta | **RT-OBL** | `pedido_asignado` canal `domiciliario_{userId}` | Pedido no sale | ✅ RT-2 |
| Pedido → listo (dispatch) | cambiarEstado listo | Dispatch + independientes | **RT-OBL** | `oferta_nueva` + `pedido_actualizado` | Sin repartidor | ✅ |
| Oferta 60s a independiente | DispatchService | App independiente | **RT-OBL** | canal domiciliario + **FCM** (futuro) | Oferta expira sin ver | ✅ RT; FCM ⏳ |
| Independiente acepta/rechaza | responder oferta | Admin kanban, dispatch | **RT-REC** | `pedido_actualizado` sucursal | Re-dispatch lento | ✅ |
| En camino / entregado | domiciliario PATCH | Cliente seguimiento, kanban | **RT-OBL** | `estado_actualizado` + mapa poll | Cliente sin tracking | 🟡 estado sí; mapa poll |
| Ubicación GPS domiciliario | PATCH ubicación | Cliente mapa (futuro) | **POLL** 10–30s o WebSocket | GET ubicación | Mapa entrecortado | 🟡 aceptable POLL |
| Pago contra entrega al entregar | Staff/dom | Caja | **RT-REC** | `caja_movimiento` tras cobro | Venta no registrada | 🟡 según flujo cobro |

---

### 3.6 CAJA

| Evento | Generador | Receptor | Prioridad | Tecnología | Riesgo si falla | Estado |
|--------|-----------|----------|-----------|------------|-----------------|--------|
| Venta registrada | registrarVentaEnCaja | Panel caja movimientos | **RT-REC** | `caja_movimiento` sucursal | Cuadre en vivo incorrecto | ✅ RT-4 |
| Apertura / cierre caja | CajaService | Panel cajero | **RT-REC** | `caja_movimiento` | Segundo cajero intenta abrir | ✅ |
| Retiro / gasto | CajaService | Panel caja | **RT-REC** | `caja_movimiento` | Saldo mostrado viejo | ✅ |
| Arqueo diferencia > umbral | cerrar caja | Alertas admin | **POLL** post-cierre | Alertas batch | Aceptable | ✅ |
| Cobro mesa masivo | cobrarCuentaMesa | Caja | **RT-OBL** (contable) | `caja_movimiento` + pedido/mesas | Cuadre roto | ✅ |
| Fiado creado/pagado | CajaService | Admin caja | **MANUAL** | GET | Bajo | ✅ |

---

### 3.7 INVENTARIO

| Evento | Generador | Receptor | Prioridad | Tecnología | Riesgo si falla | Estado |
|--------|-----------|----------|-----------|------------|-----------------|--------|
| Stock bajo mínimo | descontarStock / ajuste | Admin inventario, banner | **POLL** 30–60s o alerta batch | Alertas job | Sigue vendiendo — backend bloquea | 🟡 alertas sí |
| Producto agotado (disponible=false) | inventario post-venta | Menú cliente | **RT-REC** | `catalogo_actualizado` sucursal | Cliente ve producto agotado al checkout | 🟡 falla en POST |
| Compra ingresada | inventario compra | Admin inventario | **MANUAL** | — | Bajo | ✅ |
| Impacto stock plato (admin) | GET costeo | Pantalla costeo | **MANUAL** | — | Bajo | ✅ |
| Traslado entre sedes | inventario traslados API | Panel hermanas / traslados | **RT-REC** | `sucursal_actualizada` o poll | Datos viejos | 🟡 poll manual; RT opcional |

---

## 4. Entregables solicitados

### 4.1 Eventos Realtime **obligatorios**

| # | Evento | Canal recomendado | Payload mínimo |
|---|--------|-------------------|----------------|
| 1 | Nuevo pedido / cambio estado | `sucursal_{id}` · `pedido_actualizado` | pedido_id, estado, tipo, mesa_id, numero_pedido |
| 2 | Mesa ocupación / liberación | `sucursal_{id}` · `mesas_actualizadas` | sucursal_id (refetch grid) |
| 3 | Seguimiento cliente | `pedido_{id}` · `estado_actualizado` | pedido_id, estado |
| 4 | **Ticket/ítem cocina nuevo o cambio** | `cocina_{cocina_id}` · `cocina_actualizada` | pedido_id, item_id, estado_cocina, cocina_id |
| 5 | **Asignación domiciliario planta** | `domiciliario_{usuario_id}` · `pedido_asignado` | pedido_id, direccion, total |
| 6 | **Oferta domiciliario independiente** | `domiciliario_{id}` · `oferta_nueva` | oferta_id, expira_at, pedido_id |
| 7 | **Cobro mesa / venta caja** (cuando exista) | `sucursal_{id}` · `caja_movimiento` | caja_id, monto, pedido_id |

**Hoy implementados:** 1–7 (obligatorios). **Pendiente recomendado:** eventos §4.2 y `event_id` en payload.

---

### 4.2 Eventos Realtime **recomendados**

| Evento | Motivo |
|--------|--------|
| `mesa_cuenta_actualizada` (mesa_id) | Sheet mesa abierto sin refetch completo |
| `pedido_items_cambiaron` | Kanban muestra conteo ítems sin GET pesado |
| `qr_aprobacion_urgente` | Cumplir spec 3/5 min sin FCM inicial |
| `alerta_nueva` | Dashboard admin badge |
| `catalogo_disponibilidad` | Ocultar producto agotado en menús abiertos |
| `kanban_solo_activos` debounce | Reducir tormenta de refetch |

---

### 4.3 Eventos **opcionales** (polling o manual basta)

| Evento | Intervalo / modo |
|--------|------------------|
| Reportes financiero/productos | Manual |
| Config fiscal, horarios, zonas admin | Manual al guardar |
| Super Admin Foody Control | Manual |
| Inventario hermanas (lectura) | Manual / 60 s |
| Reloj tiempo-en-estado kanban | Timer UI 30 s local |
| Promociones stories cliente | Manual al abrir ciudad |
| Versión app / splash | Una vez por sesión |
| Geocoding Photon | On demand |

---

## 5. Riesgos de concurrencia

| # | Escenario | Módulos | Qué puede pasar | Mitigación recomendada |
|---|-----------|---------|-----------------|------------------------|
| C1 | Dos meseras aprueban QR simultáneo | Mesas, Pedidos | Dos confirmaciones; una mesera “gana” | `FOR UPDATE` pedido ✅; UI optimistic lock |
| C2 | Kanban mueve estado mientras cocina marca listo | Pedidos, Cocina | Estado final impredecible | Máquina estados + version/updated_at check |
| C3 | Cobrar mesa + agregar ítem concurrente | Mesas, Pedidos | Cobro sin último ítem o ítem huérfano | Transacción cobro con lock mesa; rechazar agregar si `pagando` |
| C4 | Transferir mesa + cobrar en origen | Mesas | Cobro en mesa equivocada | Lock pedidos mesa origen en transferir ✅ |
| C5 | Dos cajeros — uno cierra, otro vende | Caja | Venta sin caja | Validar caja abierta en crear (hoy skip silencioso) |
| C6 | Dispatch + asignación manual domi | Domicilios | Doble domiciliario | Unique constraint asignación activa |
| C7 | Broadcast llega antes que commit BD | Realtime | UI refetch datos viejos | Emitir **post-commit** ✅; cliente debounce 300 ms |
| C8 | Múltiples tabs Flutter misma sucursal | Realtime | N refetch duplicados | Debounce + coalesce en `FoodyRealtime` |
| C9 | Stock última unidad — dos POST simultáneos | Inventario, Pedidos | Oversell | `FOR UPDATE` inventario en transacción ✅ |
| C10 | Cliente QR doble tap “Confirmar” | Pedidos | Dos pedidos | Idempotency-Key (futuro) |

---

## 6. Riesgos de duplicación

| # | Tipo | Origen | Efecto | Mitigación |
|---|------|--------|--------|------------|
| D1 | **Evento duplicado** | Broadcast sin ack; reintento backend | 2–3 refetch kanban | Debounce 300–500 ms; ignorar mismo pedido_id+estado+timestamp |
| D2 | **Handler duplicado** | `pedido_actualizado` y `mesas_actualizadas` mismo acto | Doble GET mesas+kanban | Unificar en “operacion_sucursal_cambiada” o coalesce |
| D3 | **Suscripción duplicada** | Rebuild widget sin unsubscribe | Memory leak / 2x eventos | dispose canal ✅ en grid/kanban |
| D4 | **Poll + RT simultáneo** | KDS 8s + futuro RT | Doble render ticket | Al recibir RT, reset timer poll; backoff |
| D5 | **movimientos_caja duplicados** | crear + agregarItems + cobrar (futuro) | Cuadre inflado | Idempotencia por pedido_id+tipo movimiento |
| D6 | **Notificación FCM + broadcast** | Mismo evento dos canales | Doble alerta sonora | Deduplicar por event_id UUID en cliente |
| D7 | **estado_actualizado + poll seguimiento** | Seguimiento hace GET tras RT | OK si idempotente | GET es idempotente ✅ |

---

## 7. Estrategia completa de Realtime para Foody

### 7.1 Principios

1. **Backend emite, nunca postgres_changes en cliente** — RLS y seguridad; ya decidido en `FoodyRealtime` comentario.
2. **Post-commit only** — Realtime después de `COMMIT` transaccional.
3. **Canales por tenant** — Prefijo `sucursal_{uuid}`; nunca broadcast global.
4. **Híbrido RT + POLL** — RT obligatorio con fallback poll (KDS: RT primario, poll 60 s backup).
5. **FCM para “despertar”** — Broadcast para “actualizar pantalla abierta”; FCM para staff offline.
6. **Payload pequeño** — IDs + estado; cliente hace GET incremental (no enviar menú completo).
7. **Debounce en cliente** — 300 ms coalesce por sucursal.

### 7.2 Mapa de canales (objetivo)

```
sucursal_{sucursal_id}
  ├── pedido_actualizado      ✅
  ├── mesas_actualizadas      ✅
  ├── caja_movimiento         ✅
  ├── alerta_nueva            ✅ (emisor backend parcial — alertas batch)
  └── catalogo_actualizado    ⏳

pedido_{pedido_id}
  └── estado_actualizado      ✅

cocina_{cocina_id}
  └── cocina_actualizada      ✅

domiciliario_{usuario_id}
  ├── pedido_asignado         ✅
  └── oferta_nueva            — (canal `domiciliario_indep_{id}` para independientes)

Cliente Flutter: debounce 300 ms + `sucursal_actualizada` si lote mixto (RT-5).
```

### 7.3 Orden de implementación

| Fase | Trabajo | Estado |
|------|---------|--------|
| **RT-1** | `cocina_actualizada` + KDS | ✅ |
| **RT-2** | Canales domiciliario + dashboards | ✅ |
| **RT-3** | `MesaPedidosSheet` suscripción | ✅ |
| **RT-4** | `caja_movimiento` + panel caja | ✅ |
| **RT-5** | Debounce/coalesce `FoodyRealtime` | ✅ |
| **RT-6** | FCM paralelo (Sprint 7) | ⏳ pospuesto |
| **RT-7** | Eventos recomendados §4.2 | ✅ `qr_aprobacion_urgente`, `catalogo_disponibilidad` |
| **RT-8** | `event_id` UUID en broadcast backend | ⏳ |

### 7.4 Contrato evento estándar (propuesto)

```typescript
{
  evento: string;           // ej. pedido_actualizado
  event_id: string;         // UUID — deduplicación D6
  sucursal_id: string;
  entidad_tipo: 'pedido' | 'mesa' | 'cocina_item' | 'caja' | 'domicilio';
  entidad_id: string;
  accion: 'creado' | 'actualizado' | 'eliminado';
  estado?: string;
  metadata?: Record<string, unknown>;
  emitido_at: string;       // ISO
}
```

### 7.5 Fallback cuando Realtime falla

| Síntoma | Detección | Acción cliente |
|---------|-----------|----------------|
| Supabase no config en backend | Log warn | POLL agresivo 5 s en kanban/mesas |
| CHANNEL_ERROR Flutter | onError subscribe | Mostrar banner “modo sin tiempo real” + poll 10 s |
| Silencio > 60 s en KDS con pedidos activos | Heartbeat | Forzar refetch tickets |
| Staff cierra app | — | FCM (futuro) |

### 7.6 Qué NO hacer

- ❌ Exponer `postgres_changes` en tablas `pedidos` al cliente (riesgo C10 histórico en ANALISIS_SISTEMA).
- ❌ Calcular totales en evento Realtime — solo señal de refetch o patch IDs.
- ❌ Un solo canal global “foodie” — viola multi-sucursal.
- ❌ RT para reportes históricos o inventario admin — overkill.

---

## 8. Matriz resumen: RT vs POLL vs Manual

| Dominio | RT-OBL | RT-REC | POLL | Manual |
|---------|--------|--------|------|--------|
| Mesas grid | QR nuevo, libre/ocupada | total sheet, mesera | CRUD admin | — |
| Pedidos kanban | todo estado activo | descuentos | — | histórico |
| Cocina KDS | tickets/ítems | impresión ACK | demora alert | config |
| QR cliente | aprobación/estado | sub-estado cocina | — | menú |
| Domicilios | asignación, oferta | acepta/rechaza | GPS mapa | historial |
| Caja | cobro/venta | movimientos live | — | cierre/arqueo |
| Inventario | — | agotado menú | bajo stock | compras, CRUD |

---

## 9. Referencias cruzadas

- Implementación actual: `foody_backend/src/core/realtime/`, `lib/core/realtime/foody_realtime.dart`
- Escenarios operativos: `docs/ESCENARIOS_NEGOCIO_FOODY.md`
- Arquitectura: `docs/archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md` §6
- FCM pospuesto: `docs/AVANCE_PROYECTO.md` «Pospuesto por acuerdo»
- Pendiente global producto: §10 abajo
- Catálogo escenarios (filas desactualizadas): `docs/ESCENARIOS_NEGOCIO_FOODY.md` — resync ⏳

---

## 10. Pendiente global del proyecto (fuera de Realtime core)

Documentado aquí para no perder el backlog acordado jun-12. **No bloquea** RT-1…RT-5 (ya hechos).

### 10.1 Integraciones pospuestas (sprint explícito)

| Tema | Estado | Qué existe hoy | Qué falta |
|------|--------|----------------|-----------|
| **FCM** push | ⏳ Sprint 7 | `NotificacionesService` → cola `notificaciones_pendientes` (stub) | Firebase Admin SDK, tokens dispositivo, envío real staff/cliente/domi |
| **DIAN** FE | ⏳ Sprint 9–11 | Facturación HTML borrador, anular local | Proveedor FE, CUFE, nota crédito legal |
| **Impresión Python** | ⏳ Sprint 10 | Tabla `impresion_cocina_jobs`, CRUD impresoras | Servidor WebSocket local, ACK ticket |
| **KDS offline** (COC-015) | ⏳ | KDS requiere red | Cola local + sync |

### 10.2 Producto / calidad 🟡

| Ítem | Falta | Cuándo |
|------|-------|--------|
| Restricciones por plan comercial | `PlanFeaturesGuard` solo metadata | `docs/PLANES_SUSCRIPCION.md` |
| Costeo Fase C (canal mesa/domicilio) | Precio sugerido por canal | Post-S6 |
| Multi-sucursal catálogo compartido | Solo inventario hermanas lectura | Fase 2 `docs/MULTI_SUCURSAL.md` |
| Legacy Firebase cleanup | Aislado en `lib/legacy/` | Continuo al migrar pantallas |
| **Promos stories** imágenes | URLs externas fallan CORS web | Subir a Supabase Storage |
| **QA manual** flujos nuevos | Sin evidencia E2E | Cobro mesa, mesas, KDS, caja, traslados, auditoría, anular factura |
| **Catálogo escenarios** | ~94✅ resumen pero filas ❌/🟡 desactualizadas | Resincronizar `ESCENARIOS_NEGOCIO_FOODY.md` con código |

### 10.3 Realtime — siguiente sprint (RT-7+)

| Ítem | Prioridad | Notas |
|------|-----------|-------|
| `qr_aprobacion_urgente` | Alta | ✅ emit al QR pendiente; banner + SnackBar en grid mesas |
| `catalogo_disponibilidad` | Media | ✅ stock/agotado + admin toggle; menú y POS refrescan |
| `event_id` UUID en payload | Media | Dedup D6 antes de FCM |
| Banner “modo sin tiempo real” | Baja | `CHANNEL_ERROR` → poll 10 s (§7.5) |
| `alerta_nueva` emisor consistente | Baja | Hoy alertas batch; badge admin ya escucha |

### 10.4 Migración / backend reciente (contexto)

- `047_escenarios_negocio_brechas.sql` aplicada — split/parcial caja, mesas unir/reservar, traslados, auditoría timeline, promos auto, idempotencia pedidos.
- UI Flutter brechas (jun-12): mesas, KDS `no_disponible`, caja devolución/arqueo ciego, traslados, timeline auditoría, anular factura.

---

*Documento vivo — RT-1…RT-5 implementados jun-12. Siguiente: RT-7 eventos recomendados + QA + integraciones §10.1.*
