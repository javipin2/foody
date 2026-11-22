# Checklist QA — Realtime (Supabase Broadcast)

> **Uso:** ejecutar con API + Supabase operativos. Credenciales demo: `admin@foody.demo` / `123456`.  
> **Script rápido:** `.\scripts\verificar-realtime.ps1` · **API viva:** `.\scripts\verificar-realtime-api.ps1` (incluye flujos §1-4)  
> **QA UI 2 pestañas:** `.\scripts\verificar-realtime-qa-manual.ps1` (guía) · `-Asistido` (dispara API y confirmas en pantalla)  
> **Prerequisito:** `GET /api/v1/salud` → `realtime.conectado: true`  
> **Leyenda OK:** ☑ API = emisor/coherencia verificados por script; ☑ UI = probado manualmente en pantalla.

---

## 0. Pre-vuelo

| # | Paso | Esperado | OK |
|---|------|----------|-----|
| 0.1 | `.\scripts\verificar-salud.ps1` | `realtime.conectado = true` | ☑ |
| 0.2 | `.\scripts\verificar-realtime.ps1` | Emisores backend + coalesce Dart | ☑ |
| 0.2b | `.\scripts\verificar-realtime-api.ps1` | Coherencia + auth seguimiento + flujos §1-4 API | ☑ |
| 0.3 | Panel admin: `RealtimeAvisoBanner` + RT conectado | Sin banner amarillo si salud OK | ☑ UI |

---

## 1. Canal `sucursal_{id}`

### 1.1 `pedido_actualizado`

| # | Rol | Acción | Receptor | Esperado (< 3 s) | OK |
|---|-----|--------|----------|----------------|-----|
| 1.1.1 | Cliente / cajero | Crear pedido mostrador | Kanban admin abierto | Nueva tarjeta sin F5 | ☑ UI |
| 1.1.2 | Cocina / admin | Mover pedido en kanban | Otro kanban misma sucursal | Columna actualizada | ☑ UI |
| 1.1.3 | Admin | Cobrar mesa (2+ pedidos) | Domiciliarios admin | Lista actualiza (coalesce mixto) | ☑ UI |

### 1.2 `mesas_actualizadas`

| # | Rol | Acción | Receptor | Esperado | OK |
|---|-----|--------|----------|----------|-----|
| 1.2.1 | Mesero | Aprobar QR mesa | Grid mesas | Color/estado mesa cambia | ☑ UI |
| 1.2.2 | Cajero | Cobrar mesa completa | Grid mesas | Mesa libre | ☐ |
| 1.2.3 | Admin | Crear/editar mesa | Grid mesas | Nueva mesa visible | ☐ |

### 1.3 `caja_movimiento`

| # | Rol | Acción | Receptor | Esperado | OK |
|---|-----|--------|----------|----------|-----|
| 1.3.1 | Cajero A | Abrir caja | Caja admin Cajero B | Panel B muestra caja abierta (< 60 s RT, < 30 s poll) | ☐ |
| 1.3.2 | Cajero | Registrar venta / cobro pedido | Caja admin | Movimiento nuevo en lista | ☐ |
| 1.3.3 | Cajero | Retiro parcial | Caja admin otra pestaña | Saldo/movimientos actualizados | ☑ UI |
| 1.3.4 | Cajero | Registrar gasto | Caja admin | Movimiento gasto visible | ☑ API |
| 1.3.5 | Cajero | Devolución | Caja admin | Movimiento devolución visible | ☑ API |
| 1.3.6 | Cajero | Cerrar caja | Caja admin B | B ve caja cerrada / sin activa | ☐ |

### 1.4 `qr_aprobacion_urgente`

| # | Rol | Acción | Receptor | Esperado | OK |
|---|-----|--------|----------|----------|-----|
| 1.4.1 | Cliente QR | Pedido mesa sin aprobar | Grid mesero | SnackBar naranja al crear | ☑ UI |
| 1.4.2 | — | Esperar ≥ 3 min sin aprobar | Grid mesero | SnackBar recordatorio cron | ☐ |
| 1.4.3 | — | Esperar ≥ 5 min sin aprobar | Grid mesero | Payload `nivel: urgente_5min` (devtools) | ☐ |

### 1.5 `llamar_mesera`

| # | Rol | Acción | Receptor | Esperado | OK |
|---|-----|--------|----------|----------|-----|
| 1.5.1 | Cliente seguimiento | Botón "Llamar mesera" | Grid mesero | SnackBar turquesa + grid refetch | ☑ UI |

### 1.6 `catalogo_disponibilidad`

| # | Rol | Acción | Receptor | Esperado | OK |
|---|-----|--------|----------|----------|-----|
| 1.6.1 | Admin | Agotar producto | Menú cliente abierto | Producto desaparece / no disponible | ☑ API* |
| 1.6.2 | Venta | Última unidad vendida | POS cajero abierto | Ítem agotado en catálogo | ☐ |

### 1.7 `alerta_nueva`

| # | Rol | Acción | Receptor | Esperado | OK |
|---|-----|--------|----------|----------|-----|
| 1.7.1 | Sistema | Descuento > umbral / cuadre caja | Alertas admin | Nueva fila sin F5 | ☐ |

---

## 2. Canal `pedido_{id}_{seguimiento_token}` (RT-9)

> Sin `token` en URL ni `device_id` del creador, `GET /pedidos/:id/estado` responde **403** y Flutter no suscribe RT.

### 2.1 `estado_actualizado`

| # | Rol | Acción | Receptor | Esperado | OK |
|---|-----|--------|----------|----------|-----|
| 2.1.1 | Mesero | Aprobar pedido QR | Cliente seguimiento | Estado "confirmado/en cocina" | ☑ UI |
| 2.1.2 | Cocina | Marcar listo | Cliente seguimiento | Estado actualizado | ☐ |

### 2.2 `ubicacion_repartidor`

| # | Rol | Acción | Receptor | Esperado | OK |
|---|-----|--------|----------|----------|-----|
| 2.2.1 | Domi planta | En camino + GPS activo | Cliente seguimiento mapa | Pin se mueve **sin** refetch completo | ☑ API* |
| 2.2.2 | Domi indep | Actualizar ubicación en entrega | Cliente seguimiento | Pin actualizado | ☐ |

---

## 3. Canal `cocina_{id}`

| # | Rol | Acción | Receptor | Esperado | OK |
|---|-----|--------|----------|----------|-----|
| 3.1 | Cajero/mesero | Crear pedido con ítems cocina | KDS | Ticket aparece | ☑ API* |
| 3.2 | KDS | Marcar ítem preparando/listo | KDS otra estación misma cocina | Ticket actualizado | ☐ |
| 3.3 | Mesero | Agregar ítem a pedido activo | KDS | Nuevo ítem en ticket | ☐ |

---

## 4. Domiciliarios

### 4.1 `pedido_asignado` — `domiciliario_{usuario_id}`

| # | Rol | Acción | Receptor | Esperado | OK |
|---|-----|--------|----------|----------|-----|
| 4.1.1 | Admin | Asignar domi planta | App domi planta | Pedido en lista sin F5 | ☑ API* |

### 4.2 `pedido_desasignado`

| # | Rol | Acción | Receptor | Esperado | OK |
|---|-----|--------|----------|----------|-----|
| 4.2.1 | Admin | Cancelar pedido asignado | App domi planta | Pedido desaparece de activos | ☑ API* |

### 4.3 `oferta_nueva` / `oferta_expirada` — `domiciliario_indep_{id}`

| # | Rol | Acción | Receptor | Esperado | OK |
|---|-----|--------|----------|----------|-----|
| 4.3.1 | Admin | Dispatch independientes | App indep | Oferta visible | ☐ |
| 4.3.2 | — | Esperar 60 s sin aceptar | App indep | Oferta desaparece (expirada) | ☐ |

---

## 5. Resiliencia (modo degradado)

| # | Escenario | Acción | Esperado | OK |
|---|-----------|--------|----------|-----|
| 5.1 | RT caído | Quitar `SUPABASE_SERVICE_KEY` backend, reiniciar API | Banner admin + poll 30 s mantiene datos | ☐ |
| 5.2 | Coalesce | Cobrar mesa con kanban + domi admin abiertos | Ambos paneles actualizan tras un solo burst | ☑ UI |
| 5.3 | Payload | Inspeccionar broadcast (devtools) | Cada payload incluye `event_id` + `emitido_at` | ☑ API |

---

## 6. Regresión conocida (no RT)

| # | Ítem | Notas |
|---|------|-------|
| 6.1 | FCM push | Cola stub — no sustituye broadcast |
| 6.2 | Impresión cocina | WebSocket Python — bus separado |
| 6.3 | Autorización canal pedido | RT-9: canal opaco + auth API — verificado en `verificar-realtime-api.ps1` | ☑ API |
| 6.4 | Migración `055` en BD | Estado `cancelado` en asignaciones domicilio | ☑ script + local |

---

*Actualizado: 2026-07-02 — QA UI asistido OK (`verificar-realtime-qa-manual.ps1 -Asistido`); RT-9 seguimiento_token; RT-8 coalesce.*
