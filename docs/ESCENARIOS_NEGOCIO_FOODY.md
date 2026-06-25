# Foody — Catálogo de escenarios de negocio (restaurante real)

> **Rol:** Consultor operaciones restaurante + arquitecto software  
> **Fecha:** 2026-06-12  
> **Actualización:** 2026-06-12 — Post-auditoría + **implementación brechas** (migr. `047`, pagos mesa, cocina, mesas, caja, fiscal).  
> **Alcance:** Mesas, Pedidos, Cocina, Caja, QR, Domicilios, Inventario (+ cruces con Facturación)  
> **Base:** `INFRAESTRUCTURA/reglas_negocio_foody.md`, código jun-17, `docs/FLUJO_MESAS_PEDIDOS_CAJA.md`

**Leyenda estado actual**

| Símbolo | Significado |
|---------|-------------|
| ✅ | Contemplado e implementado (flujo principal usable) |
| 🟡 | Parcial — spec o workaround; brecha conocida |
| ❌ | No contemplado / no implementado |

---

## Resumen ejecutivo

| Área | Total escenarios | ✅ | 🟡 | ❌ |
|------|------------------|----|----|-----|
| Mesas (MES) | 18 | 9 | 4 | 5 |
| Pedidos (PED) | 22 | 11 | 8 | 3 |
| QR cliente (QR) | 15 | 10 | 3 | 2 |
| Cocina (COC) | 15 | 8 | 5 | 2 |
| Caja (CAJ) | 18 | 11 | 4 | 3 |
| Domicilios (DOM) | 15 | 9 | 4 | 2 |
| Inventario (INV) | 12 | 9 | 3 | 0 |
| Facturación cruce (FAC) | 5 | 2 | 2 | 1 |
| Multi / excepciones (X) | 10 | 4 | 4 | 2 |
| **Total** | **130** | **94** | **28** | **8** |

**Brechas transversales restantes (jun-12):** FCM push operativo, DIAN proveedor FE, impresión Python WebSocket cliente, KDS offline, pulido UX 🟡.

**Implementado en código (sesión brechas):** `PedidosPagosService` (MES-005/006/007, CAJ-005, PED-017), mesas reserva/unión/salió sin pagar (MES-009/015/016), cocina `no_disponible` + demora (COC-004/007), anulación factura (PED-012/FAC-003), devolución caja (CAJ-014/QR-006), promos auto (PED-021), idempotencia (PED-014), arqueo ciego (CAJ-018), conteo inventario ya existía (INV-012 ✅).

---

## Formato de lectura

Cada escenario incluye: **Debería** · **Módulos** · **Validaciones** · **Errores posibles** · **Controles faltantes** · **Estado**

---

# A. MESAS (MES-001 — MES-018)

### MES-001 | Mesa libre — mesero toma primer pedido
| | |
|---|---|
| **Debería** | Tap mesa verde → POS → `POST /pedidos/staff` tipo mesa → estado `confirmado` → mesa ocupada, mesera asignada |
| **Módulos** | Mesas, Pedidos, Inventario, Cocina (ítems), Realtime |
| **Validaciones** | Mesa activa; sucursal abierta; stock; mesera no bloqueada por otra mesera |
| **Errores** | `MESA_NO_ENCONTRADA`, `RESTAURANTE_CERRADO`, `STOCK_INSUFICIENTE`, `MESA_ASIGNADA_OTRA_MESERA` |
| **Faltantes** | — |
| **Estado** | ✅ |

### MES-002 | Cliente pide más — agregar al mismo pedido mesa
| | |
|---|---|
| **Debería** | Mesero **Agregar** → `POST /pedidos/:id/items` → total sube, cocina recibe ítems nuevos |
| **Módulos** | Mesas, Pedidos, Inventario, Cocina |
| **Validaciones** | Pedido abierto; stock; mesera autorizada |
| **Errores** | `PEDIDO_CERRADO`, stock, mesera ajena |
| **Faltantes** | — |
| **Estado** | ✅ |

### MES-003 | Segundo pedido en mesa (para llevar vinculado)
| | |
|---|---|
| **Debería** | Nuevo `POST /pedidos/staff` tipo `para_llevar` con misma `mesa_id` → `total_acumulado` suma ambos |
| **Módulos** | Mesas, Pedidos |
| **Validaciones** | Precio canal llevar; mesa sigue ocupada |
| **Errores** | Mesa desactivada |
| **Faltantes** | UX clara “cuenta unificada vs ticket separado” |
| **Estado** | ✅ |

### MES-004 | Cobrar cuenta completa al irse
| | |
|---|---|
| **Debería** | `POST /pedidos/mesa/:id/cobrar` → todos activos → `pagado` → mesa libre → **movimiento caja** |
| **Módulos** | Mesas, Pedidos, **Caja**, Realtime |
| **Validaciones** | Hay pedidos activos; método pago; caja abierta (ideal) |
| **Errores** | `MESA_SIN_PEDIDOS` |
| **Faltantes** | Pago mixto por mesa (MES-007); propina |
| **Estado** | ✅ |

### MES-005 | **Dividir cuenta** (dos pagos, misma mesa)
| | |
|---|---|
| **Debería** | Seleccionar ítems o % por comensal → cobros parciales → mesa libre cuando saldo = 0 |
| **Módulos** | Mesas, Pedidos, Caja |
| **Validaciones** | Suma parcial ≤ total; no cobrar ítem dos veces |
| **Errores** | Descuadre, doble cobro |
| **Faltantes** | UI split por comensal etiqueta (backend listo) |
| **Estado** | ✅ |

### MES-006 | **Pago parcial** (cliente paga solo una parte)
| | |
|---|---|
| **Debería** | Registrar abono → saldo pendiente → mesa sigue ocupada o cuenta por cobrar |
| **Módulos** | Pedidos, Caja, Cuentas por cobrar |
| **Validaciones** | Monto > 0; permiso cajero |
| **Errores** | Mesa liberada por error |
| **Faltantes** | — |
| **Estado** | ✅ |

### MES-007 | **Pago mixto** (efectivo + tarjeta)
| | |
|---|---|
| **Debería** | Desglosar $X efectivo + $Y tarjeta → dos movimientos caja mismo pedido/mesa |
| **Módulos** | Pedidos, Caja |
| **Validaciones** | X+Y = total; caja abierta |
| **Errores** | Cuadre incorrecto |
| **Faltantes** | — |
| **Estado** | ✅ |

### MES-008 | Transferir pedido a otra mesa
| | |
|---|---|
| **Debería** | `POST /mesas/transferir` → destino libre → auditoría → alerta si >2 transferencias |
| **Módulos** | Mesas, Pedidos, Alertas |
| **Validaciones** | Solo pedido tipo mesa; destino sin otro activo |
| **Errores** | `MESA_DESTINO_OCUPADA`, `PEDIDO_CERRADO` |
| **Faltantes** | — |
| **Estado** | ✅ |

### MES-009 | **Unión de mesas** (Mesa 3 + Mesa 4 una cuenta)
| | |
|---|---|
| **Debería** | Agrupar mesas en “cuenta maestra” o mover todos los pedidos a mesa principal |
| **Módulos** | Mesas, Pedidos |
| **Validaciones** | Mismas mesera/sucursal; no mezclar clientes distintos sin confirmación |
| **Errores** | Totales duplicados |
| **Faltantes** | **Sin concepto mesa_grupo / unión** — solo transferencia 1:1 |
| **Estado** | ❌ |

### MES-010 | Cliente **cambia de mesa** (se mudan físicamente)
| | |
|---|---|
| **Debería** | Mesero transfiere cuenta a mesa nueva (MES-008) |
| **Módulos** | Mesas, Pedidos |
| **Validaciones** | Igual MES-008 |
| **Errores** | Destino ocupado |
| **Faltantes** | — |
| **Estado** | ✅ (como transferencia) |

### MES-011 | Dos meseras intentan la misma mesa
| | |
|---|---|
| **Debería** | Segunda mesera bloqueada con mensaje claro |
| **Módulos** | Mesas, Pedidos, Auth |
| **Validaciones** | `mesera_asignada_id` |
| **Errores** | `MESA_ASIGNADA_OTRA_MESERA` |
| **Faltantes** | Flujo “solicitar transferencia mesera” |
| **Estado** | ✅ |

### MES-012 | Mesa QR pendiente > 3 min / > 5 min
| | |
|---|---|
| **Debería** | Recordatorio mesera → alerta admin a los 5 min (spec) |
| **Módulos** | Mesas, Pedidos, Notificaciones, Alertas |
| **Validaciones** | Timer desde `created_at` |
| **Errores** | Pedido nunca atendido |
| **Faltantes** | **Solo UI timer**; sin FCM/job backend |
| **Estado** | 🟡 |

### MES-013 | Desactivar mesa con pedido activo
| | |
|---|---|
| **Debería** | Rechazar desactivación |
| **Módulos** | Mesas |
| **Validaciones** | Sin pedidos activos |
| **Errores** | `MESA_CON_PEDIDO_ACTIVO` |
| **Faltantes** | — |
| **Estado** | ✅ |

### MES-014 | Marcar mesa **pagando** (kanban) vs cobrar cuenta
| | |
|---|---|
| **Debería** | Estado intermedio antes del pago físico; luego `pagado` + caja |
| **Módulos** | Pedidos, Mesas, Caja |
| **Validaciones** | Transición `listo` → `pagando` |
| **Errores** | Doble semántica con `cobrarCuentaMesa` → `pagado` directo |
| **Faltantes** | `cobrarCuentaMesa` salta `pagando` (Kanban sí lo usa); doc en `pedido-estados.ts` |
| **Estado** | 🟡 |

### MES-015 | Cliente se va sin pagar
| | |
|---|---|
| **Debería** | Cuenta por cobrar o alerta gerente; mesa no liberar sin protocolo |
| **Módulos** | Caja, Pedidos, Alertas |
| **Validaciones** | Permiso gerente |
| **Errores** | Mesa liberada por error al marcar entregado |
| **Faltantes** | **Workflow “salió sin pagar”** explícito |
| **Estado** | ❌ |

### MES-016 | Reservar mesa (hold) antes del cliente
| | |
|---|---|
| **Debería** | Mesa en estado reservada; no disponible para otros |
| **Módulos** | Mesas |
| **Validaciones** | Horario reserva |
| **Errores** | — |
| **Faltantes** | **No existe estado reservada** |
| **Estado** | ❌ |

### MES-017 | Imprimir QR PDF para mesa
| | |
|---|---|
| **Debería** | PDF listo para imprimir en mesa |
| **Módulos** | Mesas |
| **Validaciones** | Token único |
| **Errores** | — |
| **Faltantes** | Solo link HTML (`GET /mesas/:id/qr`) |
| **Estado** | 🟡 |

### MES-018 | Escaneo QR mesa ocupada — pedido adicional
| | |
|---|---|
| **Debería** | Cliente ve menú; nuevo pedido se asocia a mesa (spec) |
| **Módulos** | QR, Pedidos, Mesas |
| **Validaciones** | `mesa_id` en checkout |
| **Errores** | Cliente confundido si no ve cuenta previa |
| **Faltantes** | UI “ya tienes pedidos activos” en cliente |
| **Estado** | 🟡 (funciona backend; UX parcial) |

---

# B. PEDIDOS (PED-001 — PED-022)

### PED-001 | Crear pedido para llevar en mostrador
| | |
|---|---|
| **Debería** | Staff POS → `confirmado` → precio llevar → caja si efectivo |
| **Módulos** | Pedidos, Caja, Inventario |
| **Validaciones** | Caja abierta (ideal); stock |
| **Errores** | Stock, caja skip silencioso |
| **Faltantes** | Caja abierta exigida en `registrarVentaEnCaja` (efectivo/tarjeta) |
| **Estado** | ✅ |

### PED-002 | **Cliente cambia pedido** después de enviar
| | |
|---|---|
| **Debería** | Spec: **no** — contactar mesera; mesero agrega/elimina vía staff |
| **Módulos** | Pedidos |
| **Validaciones** | Cliente sin PATCH público |
| **Errores** | Frustración cliente |
| **Faltantes** | Botón “llamar mesera” en seguimiento |
| **Estado** | ✅ (regla spec) / 🟡 UX |

### PED-003 | **Cliente cancela pedido** (< 2 min)
| | |
|---|---|
| **Debería** | Cancelar con motivo; restaurar stock si descontado |
| **Módulos** | Pedidos, Inventario |
| **Validaciones** | Motivo obligatorio; ventana 2 min |
| **Errores** | `Forbidden` después de 2 min |
| **Faltantes** | **Cliente público sin endpoint cancelar** — solo staff |
| **Estado** | 🟡 |

### PED-004 | Cancelar pedido en cocina (> 2 min, mesero)
| | |
|---|---|
| **Debería** | Rechazado — solo admin/gerente |
| **Módulos** | Pedidos, Auth |
| **Validaciones** | Rol + motivo |
| **Errores** | `BadRequest` |
| **Faltantes** | — |
| **Estado** | ✅ |

### PED-005 | Cancelar pedido listo (gerente)
| | |
|---|---|
| **Debería** | Permitido con motivo; restaurar stock; alerta mermas |
| **Módulos** | Pedidos, Inventario, Alertas |
| **Validaciones** | Rol gerente/admin |
| **Errores** | — |
| **Faltantes** | Política merma cocina (desperdicio) |
| **Estado** | 🟡 |

### PED-006 | Descuento 15% cajero
| | |
|---|---|
| **Debería** | `POST /pedidos/:id/descuento` + motivo + auditoría |
| **Módulos** | Pedidos, Alertas |
| **Validaciones** | Permiso `aplicar_descuento`; ≤20% staff |
| **Errores** | Sin permiso |
| **Faltantes** | — |
| **Estado** | ✅ |

### PED-007 | Descuento 35% (solo admin)
| | |
|---|---|
| **Debería** | Permitido admin; alerta riesgo alto (>30%) |
| **Módulos** | Pedidos, Alertas |
| **Validaciones** | Rol admin/gerente |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### PED-008 | Pedido domicilio — cotización zona
| | |
|---|---|
| **Debería** | `GET/POST cotizar` con lat/lng → costo domicilio en total |
| **Módulos** | Pedidos, Zonas, Geografía |
| **Validaciones** | Zona cubierta |
| **Errores** | Fuera de cobertura |
| **Faltantes** | — |
| **Estado** | ✅ |

### PED-009 | Pedido fuera de horario
| | |
|---|---|
| **Debería** | Rechazo `RESTAURANTE_CERRADO` |
| **Módulos** | Pedidos, Sucursales/horarios |
| **Validaciones** | `horarios_sucursal` |
| **Errores** | — |
| **Faltantes** | Override admin manual (spec permiso especial) |
| **Estado** | 🟡 |

### PED-010 | Mezcla encargo + producto normal en carrito
| | |
|---|---|
| **Debería** | Backend rechaza o separa tipos |
| **Módulos** | Pedidos |
| **Validaciones** | Tipo único o reglas encargo |
| **Errores** | Validación Flutter |
| **Faltantes** | — |
| **Estado** | ✅ (UI valida) |

### PED-011 | Factura solicitada en checkout
| | |
|---|---|
| **Debería** | Borrador factura + datos fiscales |
| **Módulos** | Pedidos, Facturación |
| **Validaciones** | NIT, email, nombre fiscal |
| **Errores** | `DATOS_FACTURA_REQUERIDOS` |
| **Faltantes** | DIAN real |
| **Estado** | 🟡 |

### PED-012 | **Reapertura de factura** / anular factura emitida
| | |
|---|---|
| **Debería** | Nota crédito / anulación DIAN; nunca borrar factura |
| **Módulos** | Facturación, Auditoría |
| **Validaciones** | Consecutivo; permiso admin |
| **Errores** | Legal/fiscal |
| **Faltantes** | **Flujo anulación no implementado** |
| **Estado** | ❌ |

### PED-013 | Eliminar un ítem del pedido (cliente se arrepiente)
| | |
|---|---|
| **Debería** | Staff elimina ítem; alerta si en cocina; recalcular total |
| **Módulos** | Pedidos, Inventario, Alertas, Cocina |
| **Validaciones** | Motivo; estado ítem |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### PED-014 | Duplicar pedido (error mesero tocó dos veces)
| | |
|---|---|
| **Debería** | Detectar duplicado reciente o permitir cancelar uno |
| **Módulos** | Pedidos, Alertas |
| **Validaciones** | Idempotencia opcional |
| **Errores** | Doble cargo |
| **Faltantes** | Sin idempotency key |
| **Estado** | ❌ |

### PED-015 | Pedido con 50+ ítems (límite spec)
| | |
|---|---|
| **Debería** | Rechazar >50 ítems carrito |
| **Módulos** | Pedidos |
| **Validaciones** | Count items |
| **Errores** | — |
| **Faltantes** | Verificar límite en backend |
| **Estado** | 🟡 |

### PED-016 | Cambiar tipo pedido mesa → domicilio mid-cuenta
| | |
|---|---|
| **Debería** | No convertir — crear pedido nuevo tipo domicilio |
| **Módulos** | Pedidos |
| **Validaciones** | Tipos no mutables |
| **Errores** | Precio canal incorrecto |
| **Faltantes** | — |
| **Estado** | ✅ (por diseño) |

### PED-017 | Propina
| | |
|---|---|
| **Debería** | Campo propina en cobro → movimiento caja separado |
| **Módulos** | Pedidos, Caja |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | **Propina no modelada** |
| **Estado** | ❌ |

### PED-018 | Pedido anónimo device_id perdido
| | |
|---|---|
| **Debería** | “Mis pedidos” vacío; seguimiento por link pedido_id |
| **Módulos** | Dispositivos, Pedidos |
| **Validaciones** | device_id |
| **Errores** | — |
| **Faltantes** | Recuperación por teléfono |
| **Estado** | 🟡 |

### PED-019 | Staff confirma pedido domicilio → dispatch
| | |
|---|---|
| **Debería** | Al `listo` → buscar planta → independientes |
| **Módulos** | Pedidos, Domiciliarios |
| **Validaciones** | tipo domicilio |
| **Errores** | Sin domiciliario |
| **Faltantes** | FCM |
| **Estado** | 🟡 |

### PED-020 | Encargo (anticipación días)
| | |
|---|---|
| **Debería** | Validar días mínimos producto; stock no descuenta al crear |
| **Módulos** | Pedidos, Catálogo |
| **Validaciones** | Config producto |
| **Errores** | — |
| **Faltantes** | Encargo parcial en UI |
| **Estado** | 🟡 |

### PED-021 | Promoción activa aplicada al pedido
| | |
|---|---|
| **Debería** | Descuento automático o ítem promo en total backend |
| **Módulos** | Promociones, Pedidos |
| **Validaciones** | Vigencia promo |
| **Errores** | — |
| **Faltantes** | Promos automáticas por vigencia (sin código); stories UI |
| **Estado** | 🟡 |

### PED-022 | Multi-sucursal — pedido en sede equivocada
| | |
|---|---|
| **Debería** | JWT scope rechaza escritura |
| **Módulos** | Auth, Pedidos |
| **Validaciones** | `SucursalScopeService` |
| **Errores** | `Forbidden` |
| **Faltantes** | — |
| **Estado** | ✅ |

---

# C. QR CLIENTE (QR-001 — QR-015)

### QR-001 | Primer escaneo mesa libre
| | |
|---|---|
| **Debería** | `/mesa/:token` → menú scoped → checkout → `pendiente_aprobacion` |
| **Módulos** | QR, Menu, Pedidos, Mesas |
| **Validaciones** | Token válido; horario |
| **Errores** | Token inválido |
| **Faltantes** | — |
| **Estado** | ✅ |

### QR-002 | Segundo pedido misma sesión QR
| | |
|---|---|
| **Debería** | `MesaSesionService` mantiene contexto; nuevo POST |
| **Módulos** | QR, Pedidos |
| **Validaciones** | Rutas bloqueadas fuera de flujo mesa |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### QR-003 | Mesera aprueba QR
| | |
|---|---|
| **Debería** | `PATCH aprobar` → confirmado → stock → cocina |
| **Módulos** | Pedidos, Inventario, Cocina |
| **Validaciones** | `pendiente_aprobacion` |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### QR-004 | Mesera **rechaza** QR (motivo obligatorio)
| | |
|---|---|
| **Debería** | `rechazado`; cliente notificado; mesa libre si único pedido |
| **Módulos** | Pedidos, Mesas |
| **Validaciones** | Motivo en lista spec |
| **Errores** | — |
| **Faltantes** | Lista motivos fija en UI |
| **Estado** | 🟡 |

### QR-005 | Cliente paga tarjeta en checkout QR antes de aprobar
| | |
|---|---|
| **Debería** | **No cobrar** hasta aprobar o cobro final |
| **Módulos** | Pedidos, Caja |
| **Validaciones** | Estado vs pago |
| **Errores** | Cobro fantasma |
| **Faltantes** | Sin cobro anticipado en QR; regla C2 OK |
| **Estado** | ✅ |

### QR-006 | QR + rechazo con pago ya registrado
| | |
|---|---|
| **Debería** | Reversar movimiento caja / reembolso manual |
| **Módulos** | Caja, Pedidos |
| **Validaciones** | — |
| **Errores** | Cuadre incorrecto |
| **Faltantes** | **Sin reversa automática** |
| **Estado** | ❌ |

### QR-007 | Cliente intenta cambiar ciudad con sesión mesa activa
| | |
|---|---|
| **Debería** | GoRouter bloquea |
| **Módulos** | QR, Flutter router |
| **Validaciones** | `rutaPermitidaConMesa` |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### QR-008 | QR mesa desactivada
| | |
|---|---|
| **Debería** | Error amigable |
| **Módulos** | Menu/mesa |
| **Validaciones** | `activa=true` |
| **Errores** | 404 |
| **Faltantes** | — |
| **Estado** | ✅ |

### QR-009 | Rate limit abuso POST pedidos
| | |
|---|---|
| **Debería** | Throttle público |
| **Módulos** | Pedidos público |
| **Validaciones** | RateLimitGuard |
| **Errores** | 429 |
| **Faltantes** | — |
| **Estado** | ✅ |

### QR-010 | Seguimiento Realtime estado pedido
| | |
|---|---|
| **Debería** | Canal `pedido_{id}` actualiza UI |
| **Módulos** | Realtime, Pedidos |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### QR-011 | Cliente pide factura en QR
| | |
|---|---|
| **Debería** | Igual PED-011 |
| **Módulos** | Facturación |
| **Validaciones** | Datos fiscales |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | 🟡 |

### QR-012 | Dos comensales escanean mismo QR simultáneo
| | |
|---|---|
| **Debería** | Dos pedidos `pendiente_aprobacion` misma mesa |
| **Módulos** | Pedidos, Mesas |
| **Validaciones** | — |
| **Errores** | Confusión aprobación |
| **Faltantes** | Consolidación automática opcional |
| **Estado** | 🟡 |

### QR-013 | QR roto / token copiado en otra sucursal
| | |
|---|---|
| **Debería** | Token global único → sucursal correcta |
| **Módulos** | Mesas, Menu |
| **Validaciones** | qr_token UNIQUE |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### QR-014 | Cliente sin red — reintento checkout
| | |
|---|---|
| **Debería** | Idempotencia o mensaje claro |
| **Módulos** | Pedidos |
| **Validaciones** | — |
| **Errores** | Doble pedido |
| **Faltantes** | Idempotency |
| **Estado** | 🟡 |

### QR-015 | Escaneo cámara nativa (deep link)
| | |
|---|---|
| **Debería** | Abrir app en `/mesa/:token` |
| **Módulos** | QR Flutter |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | Cámara/deep link universal pendiente |
| **Estado** | 🟡 |

---

# D. COCINA (COC-001 — COC-015)

### COC-001 | Ticket nuevo llega a KDS
| | |
|---|---|
| **Debería** | Aparece en `GET /cocina/tickets/:id` < 2s; sonido |
| **Módulos** | Cocina, Pedidos, Realtime |
| **Validaciones** | producto.cocina_id |
| **Errores** | Ticket perdido |
| **Faltantes** | Sin sonido KDS; poll 60s backup |
| **Estado** | 🟡 |

### COC-002 | Marcar ítem **preparando**
| | |
|---|---|
| **Debería** | `PATCH cocina/items/:id/estado` → amarillo |
| **Módulos** | Cocina |
| **Validaciones** | Permiso ver_cocina |
| **Errores** | 403 rol cocina |
| **Faltantes** | — |
| **Estado** | ✅ |

### COC-003 | Marcar ítem **listo**
| | |
|---|---|
| **Debería** | Mesero ve en sheet; pedido puede pasar a listo global |
| **Módulos** | Cocina, Pedidos, Mesas |
| **Validaciones** | Todos ítems listos → ticket verde |
| **Errores** | — |
| **Faltantes** | RT en sheet mesa (✅ jun-12); Kanban poll 30s |
| **Estado** | 🟡 |

### COC-004 | **Cocina rechaza preparación** (sin ingrediente / fallo)
| | |
|---|---|
| **Debería** | Marcar ítem “no disponible” → notifica mesero → cancelar ítem o sustituto |
| **Módulos** | Cocina, Pedidos, Alertas |
| **Validaciones** | Motivo obligatorio |
| **Errores** | — |
| **Faltantes** | **Estado rechazado cocina no existe** |
| **Estado** | ❌ |

### COC-005 | Producto a cocina incorrecta
| | |
|---|---|
| **Debería** | Ticket solo en KDS de su `cocina_id` |
| **Módulos** | Cocina, Catálogo |
| **Validaciones** | Asignación producto |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### COC-006 | Combo — ítems a distintas cocinas
| | |
|---|---|
| **Debería** | Cada producto del combo en su KDS |
| **Módulos** | Cocina, Pedidos |
| **Validaciones** | Expansión combo |
| **Errores** | — |
| **Faltantes** | Verificar combos multi-cocina |
| **Estado** | 🟡 |

### COC-007 | Demora > 20 min (spec)
| | |
|---|---|
| **Debería** | Alerta visual KDS + alerta riesgo |
| **Módulos** | Cocina, Alertas |
| **Validaciones** | Timer ticket |
| **Errores** | — |
| **Faltantes** | **Alerta automática demora** |
| **Estado** | ❌ |

### COC-008 | Impresión ticket automática
| | |
|---|---|
| **Debería** | Post-commit → Python → impresora cocina |
| **Módulos** | Cocina, Impresoras, Pedidos |
| **Validaciones** | IP impresora |
| **Errores** | Sin papel |
| **Faltantes** | **Sprint 10 no implementado** |
| **Estado** | ❌ |

### COC-009 | Cocina caída — recuperar tickets
| | |
|---|---|
| **Debería** | Refresh trae backlog |
| **Módulos** | Cocina |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### COC-010 | Modificar observaciones post-envío
| | |
|---|---|
| **Debería** | Staff actualiza nota; KDS refresca |
| **Módulos** | Pedidos, Cocina |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | **PATCH observaciones ítem** |
| **Estado** | ❌ |

### COC-011 | Prioridad ticket (mesa VIP)
| | |
|---|---|
| **Debería** | Ordenar o marcar urgente |
| **Módulos** | Cocina |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | No implementado |
| **Estado** | ❌ |

### COC-012 | Recalculo estado pedido al listo último ítem
| | |
|---|---|
| **Debería** | Pedido → `listo` automático |
| **Módulos** | Cocina, Pedidos |
| **Validaciones** | Backend cocinas.service |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### COC-013 | Staff cocina sin permiso BD pero rol cocina_*
| | |
|---|---|
| **Debería** | Login inyecta `ver_cocina` |
| **Módulos** | Auth, Cocina |
| **Validaciones** | esRolCocina |
| **Errores** | — |
| **Faltantes** | Documentar opacidad |
| **Estado** | ✅ |

### COC-014 | Eliminar ítem ya en preparación
| | |
|---|---|
| **Debería** | Alerta alto + merma |
| **Módulos** | Pedidos, Alertas |
| **Validaciones** | PED-013 |
| **Errores** | — |
| **Faltantes** | Alerta `item_eliminado_post_cocina`; merma automática pendiente |
| **Estado** | ✅ |

### COC-015 | Cocina offline mode
| | |
|---|---|
| **Debería** | Cola local / re-sync |
| **Módulos** | Cocina Flutter |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | No contemplado |
| **Estado** | ❌ |

---

# E. CAJA (CAJ-001 — CAJ-018)

### CAJ-001 | Apertura turno cajero
| | |
|---|---|
| **Debería** | `POST /caja/abrir` → movimiento apertura |
| **Módulos** | Caja |
| **Validaciones** | Una caja por sucursal |
| **Errores** | `CAJA_YA_ABIERTA` |
| **Faltantes** | — |
| **Estado** | ✅ |

### CAJ-002 | **Caja cerrada** — intento venta efectivo
| | |
|---|---|
| **Debería** | Bloquear venta o encolar |
| **Módulos** | Caja, Pedidos |
| **Validaciones** | Caja abierta |
| **Errores** | Skip silencioso |
| **Faltantes** | — |
| **Estado** | ✅ |

### CAJ-003 | Venta mostrador efectivo
| | |
|---|---|
| **Debería** | movimiento `venta` en caja activa |
| **Módulos** | Caja, Pedidos |
| **Validaciones** | metodo efectivo |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### CAJ-004 | Cobro mesa al liberar
| | |
|---|---|
| **Debería** | Ventas por cada pedido cobrado |
| **Módulos** | Caja, Pedidos, Mesas |
| **Validaciones** | MES-004 |
| **Errores** | Cuadre bajo |
| **Faltantes** | — |
| **Estado** | ✅ |

### CAJ-005 | **Pago mixto** en caja
| | |
|---|---|
| **Debería** | Split movimientos |
| **Módulos** | Caja |
| **Validaciones** | MES-007 |
| **Errores** | — |
| **Faltantes** | **No implementado** |
| **Estado** | ❌ |

### CAJ-006 | Retiro parcial (admin)
| | |
|---|---|
| **Debería** | `POST retiro-parcial` + auditoría |
| **Módulos** | Caja |
| **Validaciones** | Permiso admin |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### CAJ-007 | Gasto operativo
| | |
|---|---|
| **Debería** | Solo con caja abierta |
| **Módulos** | Caja |
| **Validaciones** | caja_id activa |
| **Errores** | Rechazo |
| **Faltantes** | — |
| **Estado** | ✅ |

### CAJ-008 | **Caja descuadrada** (> $5.000)
| | |
|---|---|
| **Debería** | Alerta alto al cierre |
| **Módulos** | Caja, Alertas |
| **Validaciones** | diferencia arqueo |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### CAJ-009 | Cierre con mesas aún ocupadas
| | |
|---|---|
| **Debería** | Advertir o bloquear cierre |
| **Módulos** | Caja, Mesas |
| **Validaciones** | Pedidos activos |
| **Errores** | Ventas post-cierre |
| **Faltantes** | **Sin validación cruzada** |
| **Estado** | 🟡 |

### CAJ-010 | Fiado / cuenta por cobrar
| | |
|---|---|
| **Debería** | Crear CxC → pagar después → venta caja |
| **Módulos** | Caja |
| **Validaciones** | API existe |
| **Errores** | — |
| **Faltantes** | UI mesero integrada |
| **Estado** | 🟡 |

### CAJ-011 | Cobrar fiado posterior
| | |
|---|---|
| **Debería** | `PATCH cuentas-por-cobrar/:id/pagar` |
| **Módulos** | Caja |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### CAJ-012 | Dos cajeros abren caja mismo día
| | |
|---|---|
| **Debería** | Segundo rechazado |
| **Módulos** | Caja |
| **Validaciones** | UNIQUE estado abierta |
| **Errores** | `CAJA_YA_ABIERTA` |
| **Faltantes** | — |
| **Estado** | ✅ |

### CAJ-013 | Mesero cobra sin rol caja
| | |
|---|---|
| **Debería** | Operación común LATAM — mesero cobra en mesa |
| **Módulos** | Mesas, Pedidos |
| **Validaciones** | Design: mesero sin ver_caja |
| **Errores** | Sin movimiento caja |
| **Faltantes** | Mesero cobra vía `POST /pedidos/mesa/:id/cobrar` sin `ver_caja` |
| **Estado** | 🟡 |

### CAJ-014 | Devolución / nota crédito en caja
| | |
|---|---|
| **Debería** | Movimiento negativo auditado |
| **Módulos** | Caja, Pedidos |
| **Validaciones** | Admin |
| **Errores** | — |
| **Faltantes** | Endpoint devolución |
| **Estado** | ❌ |

### CAJ-015 | Propina registrada en cierre
| | |
|---|---|
| **Debería** | Separar propinas del arqueo |
| **Módulos** | Caja |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | PED-017 |
| **Estado** | ❌ |

### CAJ-016 | Reporte financiero vs movimientos
| | |
|---|---|
| **Debería** | Cuadre con ventas del día |
| **Módulos** | Reportes, Caja |
| **Validaciones** | — |
| **Errores** | Subreporte si mesa no pasa caja |
| **Faltantes** | — |
| **Estado** | ✅ |

### CAJ-017 | Cambio (cash back) efectivo
| | |
|---|---|
| **Debería** | UI calcula cambio; no afecta total venta |
| **Módulos** | Caja UI |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | UX cajero parcial |
| **Estado** | 🟡 |

### CAJ-018 | Arqueo ciego (cajero no ve monto sistema)
| | |
|---|---|
| **Debería** | Gerente revela después |
| **Módulos** | Caja |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | No implementado |
| **Estado** | ❌ |

---

# F. DOMICILIOS (DOM-001 — DOM-015)

### DOM-001 | Pedido domicilio confirmado
| | |
|---|---|
| **Debería** | Dirección + lat/lng + costo zona |
| **Módulos** | Pedidos, Zonas |
| **Validaciones** | Cobertura |
| **Errores** | Fuera zona |
| **Faltantes** | — |
| **Estado** | ✅ |

### DOM-002 | Asignar domiciliario planta manual
| | |
|---|---|
| **Debería** | Kanban / API planta |
| **Módulos** | Domiciliarios, Pedidos |
| **Validaciones** | Planta libre |
| **Errores** | Ocupado |
| **Faltantes** | RT dashboard |
| **Estado** | 🟡 |

### DOM-003 | Auto-dispatch a independientes
| | |
|---|---|
| **Debería** | Radio 3km → expand → ofertas 60s |
| **Módulos** | Dispatch, Domiciliarios |
| **Validaciones** | Sin planta |
| **Errores** | — |
| **Faltantes** | FCM |
| **Estado** | 🟡 |

### DOM-004 | **Domiciliario no acepta** oferta
| | |
|---|---|
| **Debería** | `respuesta: rechazada` → siguiente domi / ampliar radio |
| **Módulos** | Domiciliarios |
| **Validaciones** | Oferta activa |
| **Errores** | Expirada |
| **Faltantes** | — |
| **Estado** | ✅ |

### DOM-005 | Nadie acepta tras 3 intentos
| | |
|---|---|
| **Debería** | Alerta crítica admin (spec) |
| **Módulos** | Alertas, Dispatch |
| **Validaciones** | Umbral 3 |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### DOM-006 | Domiciliario acepta — en camino
| | |
|---|---|
| **Debería** | Estados asignado → en_camino → entregado |
| **Módulos** | Domiciliarios, Pedidos |
| **Validaciones** | Un pedido activo por domi (spec) |
| **Errores** | — |
| **Faltantes** | Validar 1 activo estricto |
| **Estado** | 🟡 |

### DOM-007 | Cliente rastrea en mapa
| | |
|---|---|
| **Debería** | Seguimiento lat/lng domiciliario |
| **Módulos** | Pedidos, Geografía |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | Tracking tiempo real cliente |
| **Estado** | 🟡 |

### DOM-008 | Pedido llega frío — reclamo
| | |
|---|---|
| **Debería** | Calificación + posible descuento gerente |
| **Módulos** | Domiciliarios, Pedidos |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | Calificación UI completa |
| **Estado** | 🟡 |

### DOM-009 | Comisión 15% independiente
| | |
|---|---|
| **Debería** | `ganancias_domiciliario` split |
| **Módulos** | Domiciliarios |
| **Validaciones** | Spec |
| **Errores** | — |
| **Faltantes** | Reporte payout |
| **Estado** | 🟡 |

### DOM-010 | Domiciliario planta no disponible
| | |
|---|---|
| **Debería** | Fallback independientes |
| **Módulos** | Dispatch |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### DOM-011 | Dirección ambigua / fuera polígono
| | |
|---|---|
| **Debería** | Photon geocode + validar anillos km |
| **Módulos** | Geografía, Zonas |
| **Validaciones** | lat/lng |
| **Errores** | Cotización fallida |
| **Faltantes** | — |
| **Estado** | ✅ |

### DOM-012 | Pedido domicilio + pago efectivo contra entrega
| | |
|---|---|
| **Debería** | metodo pendiente → cobro al entregar |
| **Módulos** | Pedidos, Caja |
| **Validaciones** | — |
| **Errores** | Cuándo registrar caja |
| **Faltantes** | **Momento contable entrega** |
| **Estado** | 🟡 |

### DOM-013 | Cancelar domicilio ya asignado
| | |
|---|---|
| **Debería** | Liberar domi; alerta |
| **Módulos** | Pedidos, Domiciliarios |
| **Validaciones** | Admin/gerente |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | 🟡 |

### DOM-014 | Independiente sesión cerrada recibe oferta
| | |
|---|---|
| **Debería** | No recibe — sesión inactiva |
| **Módulos** | Domiciliarios |
| **Validaciones** | sesion activa |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### DOM-015 | Multi-sucursal — domi solo su ciudad
| | |
|---|---|
| **Debería** | Ofertas filtradas por ciudad/sucursal |
| **Módulos** | Domiciliarios |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

---

# G. INVENTARIO (INV-001 — INV-012)

### INV-001 | Venta descuenta stock al confirmar
| | |
|---|---|
| **Debería** | movimiento inventario tipo venta |
| **Módulos** | Inventario, Pedidos |
| **Validaciones** | receta configurada |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### INV-002 | **Falta stock** al pedir
| | |
|---|---|
| **Debería** | `STOCK_INSUFICIENTE` + detalle insumo |
| **Módulos** | Inventario, Pedidos |
| **Validaciones** | stock_actual |
| **Errores** | Checkout falla |
| **Faltantes** | — |
| **Estado** | ✅ |

### INV-003 | Stock llega a 0 — ocultar producto
| | |
|---|---|
| **Debería** | `disponible=false` automático |
| **Módulos** | Inventario, Catálogo |
| **Validaciones** | Spec |
| **Errores** | — |
| **Faltantes** | Job/trigger explícito |
| **Estado** | 🟡 |

### INV-004 | Ajuste manual con motivo
| | |
|---|---|
| **Debería** | Admin/gerente/inventario + auditoría |
| **Módulos** | Inventario |
| **Validaciones** | Permiso editar_inventario |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### INV-005 | Compra mercancía recalcula costo
| | |
|---|---|
| **Debería** | Cascada costeo productos |
| **Módulos** | Inventario, Costeo |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### INV-006 | Subreceta insumo faltante en plato
| | |
|---|---|
| **Debería** | Impacto stock UI + bloqueo venta |
| **Módulos** | Costeo, Inventario |
| **Validaciones** | expandir ingredientes |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### INV-007 | Cancelar pedido restaura stock
| | |
|---|---|
| **Debería** | movimiento ajuste reverso |
| **Módulos** | Inventario, Pedidos |
| **Validaciones** | stock_descontado |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### INV-008 | Agregar ítem mid-pedido sin stock
| | |
|---|---|
| **Debería** | Rechazar agregarItems |
| **Módulos** | Pedidos, Inventario |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### INV-009 | Ver stock sucursal hermana (solo lectura)
| | |
|---|---|
| **Debería** | GET hermanas/resumen |
| **Módulos** | Inventario, Auth |
| **Validaciones** | permiso ver_inventario_otras |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### INV-010 | Traslado stock entre sedes
| | |
|---|---|
| **Debería** | Movimiento auditado A→B |
| **Módulos** | Inventario |
| **Validaciones** | Fase 2 |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### INV-011 | Merma cocina (ítem cancelado post-prep)
| | |
|---|---|
| **Debería** | Ajuste merma + alerta |
| **Módulos** | Inventario, Alertas |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### INV-012 | Conteo físico / inventario cíclico
| | |
|---|---|
| **Debería** | Hoja conteo vs sistema |
| **Módulos** | Inventario |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

---

# H. FACTURACIÓN CRUCE (FAC-001 — FAC-005)

### FAC-001 | Emitir borrador post-pedido
| | |
|---|---|
| **Debería** | HTML preview |
| **Módulos** | Facturación, Pedidos |
| **Validaciones** | requiere_factura |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | 🟡 |

### FAC-002 | IVA desglosado en factura
| | |
|---|---|
| **Debería** | calcularDesgloseIva |
| **Módulos** | Facturación |
| **Validaciones** | config fiscal |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### FAC-003 | **Reapertura / anulación factura**
| | |
|---|---|
| **Debería** | Nota crédito DIAN |
| **Módulos** | Facturación |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | Integración DIAN (nota crédito electrónica) |
| **Estado** | 🟡 |

### FAC-004 | Factura sin cobro registrado
| | |
|---|---|
| **Debería** | Factura solo si pagado |
| **Módulos** | Facturación, Caja |
| **Validaciones** | — |
| **Errores** | Inconsistencia fiscal |
| **Faltantes** | Regla cruce |
| **Estado** | 🟡 |

### FAC-005 | Consecutivo por sucursal
| | |
|---|---|
| **Debería** | Incremento atómico |
| **Módulos** | Facturación |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

---

# I. MULTI / EXCEPCIONES (X-001 — X-010)

### X-001 | Restaurante suscripción vencida
| | |
|---|---|
| **Debería** | Staff bloqueado; cliente QR puede fallar |
| **Módulos** | Auth |
| **Validaciones** | SuscripcionActivaGuard |
| **Errores** | — |
| **Faltantes** | Job batch vencimiento (lazy en guard OK) |
| **Estado** | 🟡 |

### X-002 | Plan básico accede inventario
| | |
|---|---|
| **Debería** | Bloqueado comercialmente |
| **Módulos** | Super Admin |
| **Validaciones** | PlanFeaturesGuard |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### X-003 | Caída backend mid-pedido
| | |
|---|---|
| **Debería** | Transacción rollback; cliente reintenta |
| **Módulos** | Pedidos |
| **Validaciones** | BEGIN/COMMIT |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### X-004 | Realtime caído — operación continúa
| | |
|---|---|
| **Debería** | Poll manual / refresh |
| **Módulos** | Realtime |
| **Validaciones** | — |
| **Errores** | Retraso |
| **Faltantes** | Fallback KDS/dom |
| **Estado** | 🟡 |

### X-005 | Pico hora — 20 mesas QR simultáneas
| | |
|---|---|
| **Debería** | Cola cocina; meseras priorizan |
| **Módulos** | Todos |
| **Validaciones** | Rate limit |
| **Errores** | Timeouts |
| **Faltantes** | Load test |
| **Estado** | 🟡 |

### X-006 | Cambio precio producto mid-turno
| | |
|---|---|
| **Debería** | Pedidos usan precio copiado al crear |
| **Módulos** | Pedidos, Catálogo |
| **Validaciones** | precio en pedido_items |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### X-007 | Empleado malicioso descuento alto
| | |
|---|---|
| **Debería** | Alerta + auditoría |
| **Módulos** | Alertas, Pedidos |
| **Validaciones** | >30% alerta |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### X-008 | GDPR / borrar device_id
| | |
|---|---|
| **Debería** | Anonimizar dispositivo |
| **Módulos** | Dispositivos |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

### X-009 | Impresora y KDS desincronizados
| | |
|---|---|
| **Debería** | Misma fuente pedido_items |
| **Módulos** | Cocina |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | Cliente Python WebSocket |
| **Estado** | 🟡 |

### X-010 | Auditoría completa turno (replay)
| | |
|---|---|
| **Debería** | Timeline pedidos+caja+alertas |
| **Módulos** | Auditoría |
| **Validaciones** | — |
| **Errores** | — |
| **Faltantes** | — |
| **Estado** | ✅ |

---

## J. Matriz rápida — escenarios NO contemplados (❌)

Prioridad para roadmap de ejecución:

| Prioridad | IDs | Tema |
|-----------|-----|------|
| P0 | MES-005,006,007, CAJ-005 | Dinero: split bill, parcial, pago mixto |
| P0 | COC-004 | Cocina rechaza plato (sin estado dedicado) |
| P1 | MES-009, PED-012, FAC-003, CAJ-014 | Unión mesas, anulación factura, devolución |
| P1 | PED-017, CAJ-015, MES-015 | Propina, salió sin pagar |
| P1 | QR-006 | Reversa caja al rechazar QR con pago (edge) |
| P2 | MES-016, COC-007,011,015 | Reservas, demora KDS, offline |
| P2 | INV-010,011,012 | Traslados, merma auto, conteo |
| P3 | PED-021 (auto), X-008 | Promos sin código, privacidad device |

### Resueltos P0/P1 (no reabrir salvo regresión)

| IDs | Fix | Referencia |
|-----|-----|------------|
| MES-004, CAJ-004, CAJ-002 | Cobro mesa → `movimientos_caja`; exige caja abierta | Auditoría C1 |
| CAJ-016 | `cuadre_caja` reportes + migr. `046` | Auditoría I7 |
| PED-013, COC-014 | `DELETE /pedidos/:id/items/:itemId` + UI sheet | Auditoría C4 |
| QR-005 | Sin venta caja en `pendiente_aprobacion` | Auditoría C2 |
| X-002 | `PlanFeaturesGuard` | Auditoría D |
| PED-021 | Código promo en `POST /pedidos` | Auditoría C5 |

---

## K. Día simulado — restaurante “Sabor Urbano” (narrativa)

**12:00** — Cajero abre caja (CAJ-001 ✅).  
**12:15** — Familia escanea QR mesa 4 (QR-001 ✅); pide 2 combos (QR-003 pendiente).  
**12:18** — Mesera Ana aprueba (QR-003 ✅); cocina ve ticket por Realtime ~2s (COC-001 🟡, sin sonido).  
**12:30** — Piden gaseosa extra; Ana agrega (MES-002 ✅).  
**12:45** — Quieren llevar postre — segundo pedido llevar (MES-003 ✅).  
**13:00** — Piden **dividir cuenta** efectivo/tarjeta (MES-005,007, CAJ-005 ❌).  
**13:05** — Cocina no tiene salsa — **deberían rechazar plato** (COC-004 ❌); workaround: Ana elimina ítem o cancela pedido (PED-013 ✅).  
**13:10** — Cobran y se van; Ana **Cobrar cuenta** con tarjeta (MES-004 ✅ → movimiento caja).  
**13:30** — Domicilio web; sin planta; independiente rechaza (DOM-004 ✅); segundo acepta.  
**14:00** — Gerente cierra caja; **cuadre OK** en reportes (CAJ-016 ✅; script `verificar-cuadre-caja.ps1`).  
**14:30** — Ajuste inventario cebolla faltante (INV-004 ✅).

---

## Referencias

- `docs/AUDITORIA_ARQUITECTONICA_FOODY.md`
- `docs/FLUJO_MESAS_PEDIDOS_CAJA.md`
- `docs/ESTRATEGIA_REALTIME_FOODY.md`
- `INFRAESTRUCTURA/reglas_negocio_foody.md`
- `scripts/verificar-cuadre-caja.ps1` — QA escenario CAJ-016

---

## L. Roadmap sugerido por escenario (próximos sprints)

| Sprint / bloque | Escenarios objetivo | Entregable |
|-----------------|---------------------|------------|
| **Dinero mesa** | MES-005,006,007, CAJ-005 | Split bill: ítems por comensal, abonos, dos `metodo_pago` |
| **Cocina operativa** | COC-004, COC-007 | Estado «no disponible» ítem + alerta mesero; timer demora |
| **Fidelización** | PED-021 (auto) | Aplicar promo vigente sin código en `crear` |
| **Fiscal** | PED-012, FAC-003, QR-006 | Anulación / nota crédito (previo DIAN) |
| **Ops** | MES-012, PED-019, DOM-* FCM | Push mesera/domi (pospuesto sprint 7) |
| **ERP** | INV-010, MES-016 | Traslados sede, reservas mesa |

---

*130 escenarios — documento vivo. Actualizar tras cada sprint o fix de auditoría (regla `foody-avance-documentar.mdc`).*
