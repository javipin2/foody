# Auditoría — Clientes / QR / autoservicio (Prompt 17)

> **Fecha:** 2026-08-06  
> **Alcance:** pedido por QR sin JWT mesero, anti-manipulación precios/productos, QR expirado / mesa reutilizada.  
> **Verificación:** `scripts/verificar-qr-cliente.ps1` (OK, exit 0).  
> Código: `menu.service.ts` · `pedidos-public.controller.ts` · `pedidos-crear.service.ts` · `pedidos-estado.service.ts` · `pedidos-qr-cron.service.ts`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| Flujo QR sin cuenta mesero | **Parcial** — cliente pide **sin JWT** → `pendiente_aprobacion`. **No** hay autoservicio que salte aprobación: hace falta staff+mesero para aprobar. |
| Manipular precios vía request | **No** — body `precio` se **ignora**; precio desde BD. Producto ajeno/off → rechazado. |
| QR expirado / mesa reusada | Token QR **permanente**. Mesa libre no invalida token. Varios clientes coexisten. Expiración dura de pedido: **cierre caja >30 min** (no cron continuo). |

---

## Flujo QR (sin JWT en el pedido)

```
GET /menu/mesa/:qr_token   (público)
POST /pedidos              (público, device_id)
  → estado = pendiente_aprobacion
  → stock_descontado = false
PATCH /pedidos/:id/aprobar (JWT + mesera_id)  ← mesero obligatorio
  → en_cocina + descuento stock
```

| Paso | ¿Mesero? |
|------|----------|
| Ver menú / crear pedido | No |
| Aprobar / cocina | **Sí** (admin asigna `mesera_id` o mesero con permiso) |

`scripts/verificar-self-service.ps1` = onboarding SaaS, **no** mesa sin mesero.

---

## Anti-manipulación

| Ataque | Resultado |
|--------|-----------|
| `precio: 1` en body | Ignorado → `precio_unitario` = catálogo (8000) |
| Producto otra sucursal / UUID fake | Rechazado |
| `disponible=false` | Rechazado |
| PATCH estado → `en_cocina` sin JWT | `NO_AUTORIZADO` |
| Aprobar sin JWT | `NO_AUTORIZADO` |

Comentario código: *“Precio autoritativo del servidor… no validamos tampering estricto”* — no hay error si difiere; simplemente se sobrescribe.

---

## QR / sesión / reutilización

| Escenario | Comportamiento |
|-----------|----------------|
| Token tras mesa `libre` | Sigue resolviendo menú |
| 2 devices mismo QR | Ambos pueden crear `pendiente_aprobacion` |
| Mesa `activa=false` | Menú QR → 404 |
| Token inventado | 404 |
| Pedido >30 min sin aprobar | Sigue pendiente; rechazo en **cierre de caja** (F-09) |
| Cron QR | Solo FCM/recordatorio 3/5 min — **no** auto-rechaza |
| Sesión Flutter | SharedPreferences **sin TTL** |

---

## Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **QR-FLOW-01** | ✅ | — | Menú+pedido públicos → `pendiente_aprobacion` | Script A |
| **QR-AUTO-01** | 🟡 | Media | No hay autoservicio sin aprobación mesero | Script A |
| **QR-PRICE-01** | ✅ | — | Precio body ignorado; BD manda | Script B |
| **QR-PROD-01** | ✅ | — | Producto off/ajeno rechazado | Script B |
| **QR-TOKEN-01** | ✅ | — | Token permanente; libre no invalida | Script C |
| **QR-MULTI-01** | ✅ | — | Varios pendientes mismo QR OK | Script C |
| **QR-EXP-01** | 🟡 | Baja | Sin auto-rechazo continuo; solo cierre caja >30m | Script C |
| **QR-MESA-ID-01** | ✅ | Media | `tipo=mesa` requiere `mesa_id`; servicio rechaza antes de consultas/escrituras | `PedidosCrearService.crear`; regresión cliente/staff/estimación |
| **R10** | 🟡 | — | (cross) Carrera stock 2 QR al aprobar | Aceptado |
| **RT-SEC-01** | 🟣 | — | (cross) Menú QR expone ids → canales RT | Realtime |

---

## Backlog remediación sugerido

1. ~~**QR-FIX-01** — Exigir `mesa_id` si `tipo=mesa` en `POST /pedidos` público.~~ ✅ Servicio compartido lo valida para pedidos de cliente, personal y estimación.
2. **QR-FIX-02** — (producto) Modo autoservicio opcional por sucursal que auto-apruebe o vaya directo a cocina.
3. **QR-FIX-03** — Cron opcional: auto-rechazar `pendiente_aprobacion` > N min (hoy solo cierre caja).
4. **QR-FIX-04** — Rotar/invalidar token al regenerar QR (si se quiere invalidar escaneos viejos).

---

## Verificación

```powershell
.\scripts\verificar-qr-cliente.ps1
# exit 0
```

Relacionados: `verificar-carga-qr.ps1`, `verificar-qa-roles-api.ps1` (aprobar con mesero).

**Gaps:** click-through Flutter escáner; regenerar QR en UI no ejercido.

## Sesión cliente, device y acceso al historial (2026-11-23)

### Recorrido observado en código

1. Cliente invitado obtiene `device_id` como UUID v4 y lo guarda en SharedPreferences; en Flutter Web queda en almacenamiento del origen. `POST /pedidos` acepta ese identificador y el backend lo guarda en pedido/dispositivo.
2. Cliente Google vuelve de Supabase OAuth con access token. Flutter envía `{device_id, access_token}` a `POST /dispositivos/vincular-auth`; Nest valida el access token consultando Supabase y asocia `auth_uid` al device. Reclama pedidos del mismo device cuyo `cliente_auth_uid` esté vacío o pertenezca a ese mismo `auth_uid`.
3. `GET /pedidos/mios` acepta `device_id` obligatorio. Con token válido une pedidos del device y del usuario Google; si el Bearer es inválido/expiró, cae a consulta por `device_id` anónimo. La respuesta contiene también `seguimiento_token` por pedido.
4. `GET /pedidos/:id/estado` autoriza por igualdad del `device_id` o por `seguimiento_token`; el detalle incluye dirección/coords y, cuando está en camino, ubicación actual disponible del repartidor. Cancelar, llamar mesera y calificar también se autorizan por `pedido_id + device_id`.

### Hallazgo `CLIENT-DEVICE-CAP-01` — identidad cliente basada en ID de dispositivo

`device_id` funcionaba como una **capability bearer**: quien lo conocía podía consultar historial/tokens y operar acciones autorizadas solo por ese ID. Mitigación implementada: el cliente genera un secreto aleatorio de 256 bits independiente del ID; Nest guarda solo SHA-256 y compara en tiempo constante. Historial, creación/cotización, cancelación, llamado a mesera, calificación y vínculo Google exigen `X-Foody-Device-Capability`; el estado individual aún acepta su token de seguimiento, que es compartible por pedido. IDs legacy sin hash se rechazan salvo durante el primer registro, que requiere prueba de posesión del secreto nuevo.

**Riesgos residuales:** al migrar, el primer registro de un dispositivo legacy aún puede reclamar su ID si este se filtró antes; no se puede distinguir al dueño legítimo sin un secreto preexistente. La copia Web usa almacenamiento del origen y puede exponerse ante XSS. No hay recuperación entre dispositivos si se pierde el secreto y no existe una ruta de recuperación segura. Los APK Cliente/Equipo y bundles Web se reconstruyeron; una versión móvil anterior no enviará el header requerido y debe actualizarse.

**Impacto antes de mitigación:** exposición de datos de pedido/dirección/seguimiento y reclamación de historial invitado; acciones limitadas de cancelación/calificación/atención si el pedido cumple reglas de negocio. Verificación negativa con ID aleatorio y secreto incorrecto devolvió 403; en BD QA aislada se probó registro, secreto válido, secreto incorrecto, persistencia del secreto original y cotización. No se consultó ni modificó información real de pedidos.

**Estado de implementación:** migración aditiva `092_dispositivo_capability.sql` aplicada a QA aislada y BD local; no modifica filas de pedidos ni credenciales. Dos suites Nest (7/7), test Flutter capability (2/2), analyzer focalizado y build Nest pasan. Se reconstruyeron bundles Web Cliente/Equipo y APK Cliente/Equipo (93,1 MB cada uno). No se modificó proveedor/configuración OAuth ni secretos. Falta decidir caducidad/rotación, recuperación segura, y cómo enrolar dispositivos legacy antes del primer registro.

**Evidencia de fuente:** `DispositivoService.obtenerDeviceId()`; `google_oauth_cliente_service.dart`; `DispositivosService.vincularAuth()`; `PedidosPublicController.listarMios/estado/cancelar/llamarMesera/calificar`; `PedidosService.listarPorDevice/obtenerEstadoPublico`; `PedidosEstadoService.cancelarPorCliente/llamarMesera/calificarDomicilio`. Relacionado: `AUTH-STORE-02`.

### Regresión QR-MESA-ID-01 (2026-11-23)

La validación de `PedidosCrearService.crear` se comparte por `POST /pedidos`, creación de personal y `POST /pedidos/estimar`; para `tipo=mesa` sin `mesa_id` devuelve `MESA_REQUERIDA` antes de consultar o mutar datos. `pedidos-crear-mesa-requerida.spec.ts` preserva los tres caminos (3/3). La regresión de la suite Nest completa pasa (18 suites/48 pruebas), y el build compila. Además, `POST http://127.0.0.1:3000/api/v1/pedidos/estimar` devolvió HTTP 400 con `MESA_REQUERIDA`; fue una cotización rechazada sin creación de pedido. El verificador manual completo no se ejecutó porque contiene otras escrituras a la BD QA.
