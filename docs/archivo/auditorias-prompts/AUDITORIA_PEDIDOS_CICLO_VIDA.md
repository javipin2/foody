# Auditoría — Pedidos ciclo de vida (Prompt 11)

## Validación integrada de canales y módulos — 2026-11-25

En un clon descartable de `foody_diseno_qa`, API Nest temporal `:3001` y `FOODY_QA_SIN_EFECTOS=1`, pasaron **6 suites / 44 pruebas**: `mesa`, `qr`, `domicilio`, `cocina`, `caja` y `casos-limite-28-30`. Cubren pedido público QR y protección de precio/mesa/pago, permisos de mesero, POS/caja, contactos y estados de domicilio, cierre de Cocina, protección despacho con líneas pendientes/no disponibles, cobro/devolución, cierre financiero y conciliación tickets/Caja/Analítica.

Se añadieron dos E2E staff: (1) dos solicitudes concurrentes a `POST /pedidos/staff` con igual clave crean un pedido y un solo recaudo (`saldo_sistema` sube una sola vez); reutilizarla con un payload distinto responde 409 `IDEMPOTENCY_KEY_REUSED`; (2) repetir la creación no duplica la línea ni el ticket de Cocina. El caso COC-PAID-KDS-01 también se incluyó en el lote: cobro excepcional con motivo, ticket visible, cierre posterior de Cocina y estado financiero `pagado`.

**Resultado:** 6 suites / 44 pruebas aprobadas; adicionalmente `pedidos-numeracion-concurrente.e2e-spec.ts` pasó 1/1: cuatro pedidos públicos simultáneos reciben números distintos. Cada lote corrió contra su clon descartable, que fue eliminado; QA original conservó 4 sedes. `:3001` quedó detenido; `:3000` PID 20152 sigue respondiendo y no se reinició; Tunnel/OAuth no cambiaron. La bandera de QA pausa Realtime, notificaciones, impresión y jobs; estos resultados prueban contrato y persistencia entre módulos, pero no entregabilidad de eventos, impresión física ni proveedores externos. Las pruebas manuales del flujo visual/autenticado del panel quedan pendientes.

## CLIENT-DOM-CONTACT-01 / E2E-CLEAN-TERMINAL-01 — contacto y limpieza QA (2026-11-24)

- **Hallazgo:** el checkout público admitía domicilio sin teléfono; Nest persistía `cliente_telefono = null`, aunque despacho necesita llamar al cliente. El nombre sí puede permanecer opcional para compra invitada.
- **Cambio:** Checkout valida teléfono requerido solo para domicilio y valida 7–15 dígitos, conserva formato internacional, enfoca el campo y lo guarda con autofill. `CrearPedidoDto` aplica el mismo requisito server-side; recogida, mesa y encargo conservan teléfono opcional.
- **Evidencia:** Flutter `validar_telefono_checkout_test.dart` 3/3; `crear-pedido.dto.spec.ts` 8/8; `qr.e2e-spec.ts` 4/4 contra Nest :3001 con `FOODY_QA_SIN_EFECTOS=1` y PostgreSQL `foody_diseno_qa`. El endpoint rechaza sin teléfono con 400; con `+57 (300) 123-4567` crea pedido y detalle conserva teléfono, sin nombre. Flutter analyzer focalizado sin issues; build Nest OK.
- **Hallazgo de QA:** antes del E2E, la base aislada tenía 63 domicilios `entregado`; el helper `limpiarPedidosActivos` los habría cancelado por no listarlos entre terminales. Ahora excluye `entregado` (y cancelado/rechazado/pagado). Tras la suite, los 63 entregados siguen intactos y los cuatro pedidos creados por QR quedaron cancelados como limpieza. API QA :3001 detenida.
- **Estado de despliegue:** Nest `dist` contiene la regla, pero el proceso principal PID 19492 inició antes de la compilación y no se reinició; el rechazo/aceptación real se verificó en QA aislada. Requiere activación coordinada antes de anunciar la validación API en el Tunnel.

## PED-POS-CAP-01 — cotización POS rechazada por capability faltante (2026-11-24)

- **Hallazgo observado:** la pantalla Nuevo pedido del Equipo podía crear un carrito, pero `/pedidos/estimar` devolvía 403 `No se pudo comprobar la posesión de este dispositivo`; el total quedaba como aproximado y Confirmar bloqueado.
- **Causa:** `PedidosRepository.estimarTotales` usaba el endpoint público, que exige que `device_id` tenga la capability registrada y presente `X-Foody-Device-Capability`. El repositorio enviaba el identificador sin registrar el dispositivo ni incluir el header. Checkout cliente sí seguía ese contrato.
- **Corrección:** el repositorio POS registra una vez el dispositivo con la capability, reutiliza el mismo valor secreto en la petición de estimación y conserva intacta la creación autenticada del pedido.
- **Verificación:** `pedidos_repository_test.dart` 5/5 comprueba registro, secreto de 64 caracteres hex, mismo `device_id` y header; `pedido_cajero_screen_test.dart` 17/17 cubre error de cotización, botón de confirmación, vacío y responsive. Flutter analyze en los cuatro archivos tocados: sin issues. En Equipo autenticado por Tunnel, agregar un producto mostró total servidor de **35.000 COP** y habilitó Confirmar; no se envió el pedido. El primer uso registró únicamente metadata técnica del dispositivo, no una venta ni movimiento de Caja.
- **UX asociada:** con carrito vacío se veía un error de cotización y un reintento deshabilitado. Ahora el texto guía a agregar productos y el reintento no aparece hasta que hay ítems.
- **Alcance restante:** la estimación pública sigue dependiendo de enrolamiento de dispositivo; pérdida/rotación de capability y XSS Web continúan como riesgo en `AUDITORIA_CLIENTES_QR.md`. La vista con carrito vacío se mantiene bloqueada para confirmar, correctamente.

## Revisión de aislamiento por sucursal y rol — 2026-11-24

- **Pedidos administrativos:** controladores resuelven lectura/escritura con `SucursalScopeService`; crear staff normaliza `sucursal_id` desde JWT y valida pertenencia corporativa. Detalle, consulta mesa, edición y cambios de estado reciben la sucursal validada. No se encontró en esta muestra que el cliente pueda imponer la sede ignorando el JWT.
- **Cocina:** KDS obtiene sede desde el JWT; estaciones se restringen por `cocina_id` para rol cocina. Operaciones por `item_id` validan que el ítem pertenezca a un pedido de la sede y que su estación corresponda a la asignada. Cambios que reciben el ID del ítem vuelven a pasar sede/estación al servicio.
- **Domiciliario independiente:** rutas operativas requieren JWT, rol/guard específico y enlazan sesiones/ofertas/pedidos al `usuario.sub`; el despacho administrativo valida la sucursal mediante `SucursalScopeService`.
- **Resultado:** la revisión estática de estas rutas no mostró una fuga cross-sucursal reproducible. Prueba nueva `sucursal-scope.service.spec.ts`: 4/4 (sede propia, hermana denegada a rol operativo, empresa distinta/inactiva denegada y sede hermana permitida con permiso corporativo). No es una prueba de penetración ni cubre todos los módulos. Faltan E2E negativos autenticados que intenten IDs de otra sede/tenant en pedidos, estación KDS, despacho y documentos de domiciliarios.
- **Riesgo de escala:** el modelo visible es por restaurante/sucursal en una base compartida; el aislamiento depende de scopes Nest y filtros SQL, no de RLS universal. Mantener el scope en la capa servidor, y agregar pruebas negativas de sede hermana y restaurante distinto antes de incorporar sectores o tenant isolation más fuerte.

## MES-GROUP-ACCOUNT-01 — cuenta de mesa unificada (2026-11-24)

- **Hallazgo reproducido:** `unirMesas` reasigna pedidos activos de secundarias al ID principal. `cobrarCuentaMesa` resolvía el grupo y cobraba pedidos de todas sus mesas, pero `listarActivosPorMesa` filtraba por el ID pulsado. Abrir una secundaria podía mostrar cero tickets/$0 o una cuenta parcial mientras Caja intentaba cobrar el total del grupo. El historial de abonos también omitía pagos registrados en otra mesa del grupo.
- **Corrección:** listado de tickets y pagos de cuenta usa el conjunto completo de IDs retornado para el grupo. La consulta del grupo al cobrar ahora limita por `sucursal_id` y `activa=true`, evitando resolver mesas fuera del contexto operativo.
- **Evidencia:** `pedidos-cuenta-mesa.service.spec.ts` 1/1; E2E `mesa.e2e-spec.ts` 3/3 en Nest `:3001` apuntando únicamente a `foody_diseno_qa`; `flutter test test/mesa_pedidos_sheet_test.dart` 9/9 (320–1440 px); `npm run build` OK. QA limpiada: 0 mesas agrupadas. API `:3000` salud HTTP 200, no reiniciada; Nest temporal detenido; Cloudflare Tunnel conservado.
- **UX/alcance:** la pantalla Flutter ya presenta total, tickets y nombres de mesas desde el payload; el defecto era de consulta/contrato, no de jerarquía visual. La definición actual es que al abrir cualquier mesa del grupo se presenta la cuenta unificada; no se implementó cobro independiente desde mesa secundaria.
- **Limitación restante:** historial de abonos mantiene su límite de 30 filas y no se añadieron asignaciones contables por ticket en `pagos_pedido`; ese tema ya está documentado por separado en `AUDITORIA_CAJA.md` (`FIN-MESA-SPLIT-TRACE-01`).

## MES-GROUP-FLATTEN-01 — unión de grupos de mesas existentes (2026-11-24)

- **Hallazgo reproducido:** la UI permite seleccionar mesas activas que ya tienen `mesa_grupo_id`. El endpoint reasignaba únicamente la secundaria elegida. Si se seleccionaba la raíz de otro grupo, las mesas que aún apuntaban a ella quedaban fuera de la nueva cuenta; una misma raíz podía además participar de dos vistas de grupo y producir subtotales incompatibles.
- **Corrección:** `unirMesas` serializa uniones por sucursal, recorre recursivamente las relaciones existentes (también tolera cadenas creadas por versiones previas), bloquea las filas resultantes por ID en orden estable y las asigna a la mesa principal solicitada. Los pedidos abiertos de todos esos IDs pasan a la raíz nueva dentro de la misma transacción. La auditoría devuelve los integrantes consolidados.
- **Evidencia:** `mesa.e2e-spec.ts` 4/4 en API aislada `:3001` + `foody_diseno_qa`; se probó grupo A+B, incorporación de A a C y lectura desde B con tres tickets/$24.000. `npm run build`, spec unitaria de consulta 1/1 y formato Prettier OK. QA restaurada (0 grupos; pedidos de prueba cancelados); instancia :3001 detenida.
- **Activación:** Nest `:3000` reiniciado con el `dist` nuevo; salud local y pública HTTP 200, Cliente/Equipo HTTP 200 y `cloudflared.exe` PID 11112 activo. No se tocaron configuración de Tunnel/OAuth, credenciales ni datos reales.
- **Límite:** la búsqueda recursiva y los locks solo cubren uniones simultáneas iniciadas por este endpoint; otros cambios de estado de mesa siguen sus propios locks/transacciones. No se midió concurrencia de unión con cambios operativos simultáneos.

## Revisión de canales de entrada — 2026-11-24

- **Cliente/QR:** `POST /pedidos` es público con limitación de frecuencia; QR carga `GET /menu/mesa/:token` y crea una orden `mesa` en `pendiente_aprobacion`. El backend recalcula precio desde catálogo; E2E QR 2/2 (creación pendiente de aprobación + intento de precio manipulado).
- **Checkout cliente:** `POST /pedidos/estimar` devuelve importes autoritativos antes de crear; checkout envía `device_id`, canal, ítems/opciones, preferencia de pago y, según canal, contacto/dirección/ubicación/factura/encargo. Para domicilio exige dirección no vacía y teléfono válido de 7–15 dígitos; nombre es opcional y se admiten direcciones manuales sin lat/lng. Sin ubicación, la tarifa se identifica como estimada. El DTO Nest aplica la misma exigencia de dirección y teléfono.
- **Equipo/administrador/mesero:** `POST /pedidos/staff` requiere `crear_pedido` y usa la sucursal resuelta del JWT. El mesero recibe turno de mesa y puede presentar cuenta (`pagando`) o cancelar; no puede marcar listo ni cobrar. E2E Mesa 2/2 en QA crea una cuenta mesero temporal, confirma alta/estado y rechaza esas dos acciones indebidas; usuario QA queda inactivo y pedido de prueba limpiado. POS separa domicilios con pago pendiente al recibir; recoger/mostrador admite pago mixto, validado contra cotización de Nest. Acciones de edición de líneas y estado vuelven a exigir permiso y sucursal; cobro y descuentos tienen permisos separados.
- **Cocina y siguientes módulos:** estado inicial decide descuento de stock y entrada a cocina; el servicio calcula subtotal/promoción/domicilio/IVA en transacción, crea líneas con cocina asignada, genera historial y luego notifica/encola impresión. Cocina puede devolverlo a listo; despacho domicilio espera cocina resuelta y línea disponible; caja registra al cobrar/entregar según tipo. Rutas y efectos están descritos en la matriz de esta auditoría y en `AUDITORIA_COCINA_KDS.md`.
- **Resolución `CLIENT-DOM-CONTACT-01` (2026-11-24):** el teléfono válido es obligatorio en Checkout público y en el DTO Nest solo para tipo `domicilio`; nombre permanece opcional para preservar compra invitada. El POS solicita nombre, teléfono y dirección como campos obligatorios de esa pantalla. Flutter validator 3/3 y Nest DTO 8/8; E2E QR/domicio 4/4 en PostgreSQL QA aislada comprobó rechazo del teléfono omitido y persistencia de número internacional formateado con nombre null. La API :3000 requiere activar el build que contiene la regla; no asumirlo por la salud del proceso.
- **Cobertura de esta ejecución:** `test/flujos/qr.e2e-spec.ts` 2/2 y `test/flujos/mesa.e2e-spec.ts` 2/2 contra API :3001 + PostgreSQL `foody_diseno_qa`; E2E Cocina 3/3 y KDS widget/analyzer registrados en `AUDITORIA_COCINA_KDS.md`. Horario QA restaurado a 08:00–22:00. Nota: una reejecución posterior omitió `E2E_HOST` y tocó solo el API principal para crear/desactivar un usuario sintético; no se insertaron pedidos ni caja ni se cancelaron órdenes según lectura de historial. Incidente `QA-HOST-01` en MASTER/AVANCE. API :3000/Tunnel siguen arriba.

## PED-STAFF-IDEM-01 — reintento de creación desde POS (2026-11-24)

- **Hallazgo comprobado:** Nest ya admite `idempotency_key` en `POST /pedidos/staff` mediante lock transaccional y tabla `pedidos_idempotencia`. El checkout cliente enviaba una clave estable por intento; `PedidosRepository.crearPedidoStaff` no la enviaba. Si commit terminaba y la respuesta se perdía por red/Tunnel, reintentar POS podía duplicar pedido y sus efectos en cocina/stock/caja.
- **Corrección:** POS mantiene una clave UUID mientras el intento de pedido nuevo no haya respondido exitosamente, la reusa al reintentar y la limpia tras éxito. Se reaprovecha el contrato existente, sin migración ni cambios comerciales. El endpoint específico de agregar líneas a un pedido no recibe esta clave.
- **Regresión:** `flutter test test/pedido_cajero_screen_test.dart` 13/13; el nuevo caso simula respuesta perdida y verifica que el reintento reusa la misma clave. Formateo Dart limpio. QA visual/autenticada pendiente.
- **Revalidación (2026-11-25):** el repositorio sí incluye `idempotency_key` en `POST /pedidos/staff`; el POS conserva la clave ante fallo, la rota si cambia el payload, y Nest la limita por `(sucursal_id, clave)` y compara huella antes de replay. Se agregó una prueba de transporte al repositorio. Flutter `pedidos_repository_test.dart` + `pedido_cajero_screen_test.dart`: 24/24; prueba focalizada de la huella Nest: 1 suite/2 pruebas; Prettier limpio. No se ejecutó E2E staff en este turno; la mutación integrada debe seguir corriéndose solo contra QA aislada.
- **Cerrado — PED-ITEM-IDEM-01 (2026-11-24):** `AgregarItemsPedidoDto` acepta `idempotency_key`; Nest persiste huella y resultado en `pedidos_items_idempotencia` dentro de la misma transacción que inserta ítems, y POS envía una clave estable por intento. Repetir payload retorna el resultado guardado sin duplicar ítems ni notificaciones; reutilizar clave con payload distinto responde 409. E2E en `casos-limite-28-30.e2e-spec.ts`; la clave de creación de pedidos entre sucursales/tenants se cubre por separado con `PED-KEY-SCOPE-01` y migración 091. Ver evidencia posterior de `PED-ITEM-IDEM-01`.

> **Fecha:** 2026-08-06  
> **Alcance:** máquina de estados, transiciones inválidas vía API, efectos laterales (stock/caja/mesa/historial/impresión), edición post-cocina.  
> **Verificación:** `scripts/verificar-pedidos-ciclo-vida.ps1` (OK, exit 0).  
> Spec viva: [`FLUJO_ESTADOS_PEDIDOS.md`](FLUJO_ESTADOS_PEDIDOS.md) · Código: `pedido-estados.ts`, `pedidos-estado-command.service.ts`.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

## QR-SESSION-BIND-01 — vínculo entre QR de mesa y pedido público (2026-11-25)

- **Hallazgo:** `MesaQrEntradaScreen` iniciaba la sesión con token QR, pero navegaba a `/menu` sin ese dato. `MenuScreenFoody` volvía a activar la sesión con token nulo y `MesaSesionService.activar` podía borrar el valor persistido. A la vez, `PedidosClienteRepository` enviaba `mesa_id` sin `qr_token`, y el alta pública solo confirmaba que la mesa era de la sucursal; un cliente podía cambiar el ID y el backend no detectaba que no correspondía al QR escaneado.
- **Corrección:** la ruta del menú conserva token QR; menú restaura la sesión con el mismo token; el repositorio exige una sesión QR consistente para pedidos `mesa` y envía el token. Nest compara el token con la mesa dentro de la sucursal y rechaza discrepancias (`QR_MESA_NO_COINCIDE`). Staff mantiene su flujo autenticado. Cotización no exige token porque no crea pedido ni reserva mesa.
- **Verificación:** `qr.e2e-spec.ts` 6/6 en Nest :3001 con una base PostgreSQL clonada y descartable: incluye QR correcto, ID de mesa alterado rechazado y estimación sin token permitida. `mesa_sesion_service_test.dart` 1/1; `flutter analyze` focalizado sin issues; `npm run build` OK. Clon eliminado y base QA de origen intacta.
- **Activación y regresión:** Nest PID 10208; Cliente/Equipo Release publicados en :8081/:8080. Bundle cliente con guarda QR y API/sitios local+Tunnel HTTP 200; SHA-256 remoto/local coincide para `main.dart.js` en ambos flavors; Cloudflare PID 8940 activo. Regresión Nest completa 8/41 E2E y 51/128 unitarias; Flutter 276 aprobadas/5 omitidas y analyzer focalizado limpio. No se ejecutó pedido con mesa real en la base del negocio; queda aceptación visual/autenticada usando un QR de prueba.

---

## Resumen ejecutivo

| Pregunta | Respuesta corta |
|----------|-----------------|
| ¿Hay máquina de estados? | **Sí** — `TRANSICIONES_PEDIDO` + `transicionEstadoPermitida` + guards por `origen` en `PedidosEstadoCommandService` |
| ¿Se puede forzar transición inválida por API? | **No** vía `PATCH /pedidos/:id/estado` (DTO + máquina); `salio-sin-pagar` usa `PedidosEstadoCommandService`. El cobro completo exige cocina resuelta salvo admin/gerente con motivo; los abonos parciales pueden dejar el pedido en `pagando` mientras cocina continúa. |
| Ciclo mesa creado→cocina→cobrado→cerrado | **OK** — stock, historial, mesa, caja, `pagos_pedido`, items `cobrado` verificados en vivo |
| Edición tras enviado a cocina | **Permitida** hasta terminal (`pagado`/`entregado`/`cancelado`/`rechazado`); descuenta stock, reimprime, merma+alerta si ítem ya `preparando`/`listo` |

---

## Estados posibles (12)

Fuente: `foody_backend/src/modulos/pedidos/pedido-estados.ts`

| Estado | Terminal | Notas |
|--------|:--------:|-------|
| `pendiente_aprobacion` | | Solo mesa QR cliente |
| `pendiente` | | Cliente domi/llevar o domi staff |
| `confirmado` | | Legacy; UI = cocina |
| `en_cocina` | | Activa stock si no descontado |
| `listo` | | Dispara dispatch domicilio |
| `pagando` | | Solo mesa / para llevar |
| `asignado` | | Solo domicilio (dispatch/app) |
| `en_camino` | | Solo domicilio |
| `entregado` | ✓* | *Terminal operativo domicilio si cobrado |
| `pagado` | ✓ | Solo vía cobro / salió-sin-pagar |
| `cancelado` | ✓ | |
| `rechazado` | ✓ | QR / rechazo |

**BD:** `pedidos.estado` es `text` **sin CHECK** (`005_pedidos.sql`) — validación 100% NestJS.

---

## Transiciones válidas (`TRANSICIONES_PEDIDO`)

```
pendiente_aprobacion → en_cocina | rechazado | cancelado
pendiente            → en_cocina | cancelado
confirmado           → en_cocina | listo | pagando | cancelado
en_cocina            → listo | pagando | cancelado
listo                → pagando | entregado | cancelado
pagando              → entregado | cancelado
asignado             → en_camino | cancelado
en_camino            → entregado | cancelado
entregado|pagado|cancelado|rechazado → ∅
```

Reglas extra en `transicionEstadoPermitida`:

- `pagando` **prohibido** en `tipo=domicilio`
- `entregado` **prohibido** si no es domicilio (salón cierra con `pagado`)
- domicilio: `entregado` **solo** desde `en_camino`

Guards por origen (`PedidosEstadoCommandService.transicionPermitidaParaOrigen`):

| Origen | Regla |
|--------|-------|
| `kanban` | `transicionEstadoPermitida` |
| `cobro` | → `pagado`/`pagando` desde cualquier no-`cancelado`/`rechazado`/`pagado` |
| `cocina` | solo → `en_cocina`/`listo`; bloqueado si inmutable |
| `dispatch`/`domiciliario` | `listo→asignado`, `asignado→en_camino`, `en_camino→entregado` |
| `aprobacion_qr` | solo `pendiente_aprobacion→en_cocina` |
| `sistema` | QR expirado → `rechazado` o mapa Kanban |

---

## Endpoints que mutan estado

| Método | Ruta | Origen efectivo |
|--------|------|-----------------|
| PATCH | `/pedidos/:id/estado` | `kanban` |
| PATCH | `/pedidos/:id/aprobar` | `aprobacion_qr` |
| PATCH | `/pedidos/:id/rechazar` | vía Kanban a `rechazado` |
| POST | `/pedidos/:id/cobrar` · `/pedidos/mesa/:id/cobrar` | `cobro` |
| POST | `/pedidos/:id/cancelar` (público) | `kanban` cancelado |
| PATCH | `/cocina/items/:id/estado` | `cocina` (recalcula pedido) |
| POST | `/domiciliarios-planta/asignar` · ofertas | `domiciliario`/`dispatch` |
| PATCH | `/domiciliario/.../en-camino` · `confirmar-entrega` | `domiciliario` |
| POST | `/caja/cerrar` | `sistema` (QR expirados) |
| POST | `/mesas/:id/salio-sin-pagar` | `cobro` por `PedidosEstadoCommandService`; CxC y monto se actualizan dentro de la misma transacción |

---

## Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **PED-PREPAGO-01** | ✅ | Alta (cerrado) | Para llevar pagado al crear permanece `en_cocina` durante preparación; no bloquea cierre porque `SQL_WHERE_PEDIDO_OPERACION_ABIERTA` excluye el pedido con saldo cero. Cuando todos los ítems quedan resueltos, Cocina lo transiciona a `pagado`. Reintentar cobro responde `SIN_SALDO`, esperado. | `pedido-estados.ts`; `caja.service.ts`; `cocinas.service.ts`; E2E `casos-limite-28-30.e2e-spec.ts` |
| **PED-BYPASS-01** | ✅ | Media | `POST /mesas/:id/salio-sin-pagar` ahora usa `PedidosEstadoCommandService` (montos aparte; estado+historial en la puerta F-11). | `mesas.service.ts`; script D OK |
| **PED-COBRO-SKIP-01** | 🟡 | Media | Origen `cobro` permite `en_cocina`→`pagado` (salta `listo`/`pagando`). Intencional para caja, pero debilita la máquina Kanban. | `pedidos-estado-command.service.ts:111-116`; script B5 OK |
| **PED-EDIT-01** | 🟡 | Alta | Agregar/cambiar preparación desde `listo`/`pagando` reabre a `en_cocina`, y cambios reales de observación/toppings/cantidad reinician Cocina. Edición/borrado que baja el total por debajo de lo recibido exige devolución previa. Jest + PostgreSQL QA; aún no activado en runtime `:3000`. | `pedidos-items.service.ts`; Jest + E2E PostgreSQL |
| **PED-CHECK-01** | ✅ | Baja | CHECK de `pedidos.estado` incorporado en la migración 089; sigue siendo necesario aplicar migraciones al desplegar. | `foody_supabase/migrations/089_pedidos_estado_check_promo_fk.sql`; MASTER § Pedidos |
| **PED-DOC-01** | ✅ | Baja | Doc flujo mostraba `entregado` en salón; alineado al código 2026-08-06 | `FLUJO_ESTADOS_PEDIDOS.md` |
| **PED-API-DTO-01** | ✅ | — | `pagado` no está en `CambiarEstadoPedidoDto` → PATCH a `pagado` = 400 validación. | DTO + script B1 |
| **PED-INV-01** | ✅ | — | Transiciones inválidas Kanban rechazadas: `en_cocina→entregado`, `→asignado`, `pagando→entregado` mesa, `cancelado→en_cocina`, estado inventado. | Script B |
| **PED-FLOW-01** | ✅ | — | Ciclo mesa: crear→`en_cocina`(stock+historial+mesa ocupada)→`listo`→`pagando`(mesa)→cobrar→`pagado`(caja+pagos+items+mesa libre). | Script A HIST `en_cocina>listo>pagando>pagado` |

---

## Efectos laterales por paso (mesa staff)

| Paso | Stock | Caja | Mesa | Historial | Realtime / impresión |
|------|-------|------|------|-----------|----------------------|
| Crear staff → `en_cocina` | Descuenta (Tx) | No (mesa diferido) | `ocupada` | INSERT | Post: cocina+impresión |
| → `listo` | — | — | — | INSERT | Pedido RT |
| → `pagando` | — | — | `pagando` | INSERT | FCM mesera |
| Cobrar → `pagado` | — | Venta (Tx) | `libre` | INSERT | Pedido+mesas+caja RT |
| Cancelar post-cocina | Merma o restaurar | Reversa ventas | Libera | INSERT | RT |
| Agregar ítem post-cocina | Descuenta delta | — | — | Auditoría | Reimprime comanda |
| Eliminar ítem `preparando` | Merma | — | — | Alerta alto | Reimprime |

---

## Edición después de enviado a cocina (detalle)

`ESTADOS_PEDIDO_CERRADO` = `entregado|cancelado|rechazado|pagado`.

1. **Agregar ítems** (`POST /pedidos/:id/items`): permitido; si `stock_descontado`, descuenta al vuelo; notifica cocina (reimpresión).
2. **Editar cantidad/toppings** (`PATCH .../items/:itemId`): permitido; si cambia cantidad/toppings → `estado_cocina` vuelve a `pendiente`; `reimprimir=true` si pedido en cocina/listo.
3. **Eliminar** (`DELETE`): no permite último ítem; si ítem `preparando`/`listo` → alerta `item_eliminado_post_cocina` + merma (no restaura stock).
4. **Comensal** (`PATCH .../comensal`): no valida estado del pedido (solo etiqueta).

---

## Backlog remediación (orden)

1. **PED-FIX-01** — ✅ Cerrado: pedido prepago excluido del bloqueo de cierre mientras tiene saldo cero y pasa a `pagado` al terminar cocina; se conserva su estado operativo de preparación.
2. **PED-FIX-02** — ✅ Cerrado: `salio-sin-pagar` actualiza estado/historial por `PedidosEstadoCommandService`; monto y CxC siguen en la transacción.
3. **PED-FIX-04** — ✅ CHECK SQL incorporado (migración 089); verificar que el entorno destino aplicó la migración al desplegar.
4. **PED-FIX-05** — 🟡 Decisión de permisos pendiente: restringir edición de ítems durante `pagando` o exigir permiso específico; no cambiar sin validar operación/roles.

---

## Verificación

```text
.\scripts\verificar-pedidos-ciclo-vida.ps1
→ Verificacion pedidos ciclo de vida OK (exit 0)
```

Cobertura: ciclo mesa completo · 6+ transiciones inválidas · cobro salto · prepago bug · edición+merma+reimpresión · salió-sin-pagar · CHECK ausente.

**Gaps:** no se probó en esta etapa el cierre real de una caja QA con prepago en cocina ni click-through completo del Kanban en dispositivo; no ejecutar en datos reales. El flujo domicilio requiere prueba QA aislada tras activar el Nest actualizado.

**Consistencia cross-módulo (Prompt 29):** prepago alimenta gap caja↔reportes — ver **CONS-REP-OPEN-01** + **CONS-PROMO-ADD-01** en [`AUDITORIA_CONSISTENCIA_MODULOS.md`](AUDITORIA_CONSISTENCIA_MODULOS.md).

**Casos viernes (Prompt 30):** add post-`listo` = **VIE-01**; cobro pre-listo = **VIE-05/13** (decisión A/B/C) — [`AUDITORIA_CASOS_VIERNES.md`](AUDITORIA_CASOS_VIERNES.md).

---

## Revisión operativa ampliada (2026-11-23)

### Orígenes, sesión e identidad del cliente

- `POST /pedidos` y `POST /pedidos/estimar` son públicos y limitados por IP; estimar es de solo lectura. El DTO valida UUID de sede/producto, tipo, cantidades y dirección condicional.
- Cliente QR mesa crea `pendiente_aprobacion`; el personal debe aprobar y asignar mesero antes del descuento de inventario y el paso a cocina. Pedido de mesa staff inicia `en_cocina`; domicilio staff inicia `pendiente`; domicilio/llevar público inicia `pendiente`.
- `GET /pedidos/mios` requiere `device_id`; si Supabase valida el bearer, suma pedidos asociados a `cliente_auth_uid`. El historial se limita a 50 y ordena descendente. Token inválido cae explícitamente al modo anónimo por `device_id`.
- Consulta de estado exige coincidencia de `device_id` o token de seguimiento. Cancelar, llamar mesera y calificar se vinculan a `device_id`; la identidad Google no sustituye ese vínculo en esos comandos. Considerar UX de restauración/cambio de dispositivo para el flujo anónimo.
- Precios del pedido los calcula el backend a partir del catálogo; el precio mandado en cada línea no es autoridad. `idempotency_key` protege reintentos si el cliente la envía; no todos los flujos garantizan que la envíen.

### PED-COMBO-KDS-STOCK-01 — composición y preparación de combos

**Hallazgo de código:** `combo_items` acepta productos, bebidas y toppings; `PedidosCrearService` elige el primer producto como `productoPrincipalId` y crea una fila `pedido_items` por combo/unidad, asignada a la cocina de ese producto. `lineasInventario` añade solo los componentes de tipo producto. Los componentes base `bebida`/`topping` y las selecciones extra `comboDto.bebidas`/`comboDto.toppings` se guardan en el detalle/costo de venta, pero no entran en descuento/costo de inventario para el combo. El costo unitario de combo suma costos de productos y extras elegidos, pero no los costos de bebida/topping estáticos incluidos. Las consultas de `CocinasService.listarTickets()` y `ImpresionService.encolarPorPedidoInterno()` no seleccionan `pedido_item_toppings`, `pedido_item_bebidas` ni `combo_items`; por eso tampoco se muestran esos componentes. El producto principal es la única fila vinculada a cocina; el formulario no exige que componentes del combo compartan la misma cocina.

**Fixture demostrativo reproducible en fuente:** `foody_supabase/migrations/018_demo_combo.sql` define “Combo clásico”: hamburguesa (producto), papas (producto) y gaseosa (bebida). `012_seed_demo.sql` vincula ambos productos a cocina principal. Al crear ese combo el modelo comercial guarda un solo ticket asociado a hamburguesa; papas/gaseosa no aparecen en el ticket por SQL ni en la impresión, y el stock/costo de gaseosa no se expande. Es un contraejemplo de código/seed, no evidencia de venta real.

**Corrección requerida:** representar componentes de preparación con snapshot al confirmar el pedido, incluyendo estación/cocina, componente y cantidad, conservando una única línea de precio del combo para ventas/cobros. Incluir extras escogidos como instrucciones y consumo/costo. La política de reparto de componentes entre cocinas debe resolverse (preferir enrutamiento por componente; no asignar una cocina arbitraria); los estados de cada cocina deben agregarse sin duplicar el estado/cobro del combo. Revisar cancelación/restauración e idempotencia. Evitar arreglar solo el texto de ticket si los componentes siguen sin inventario/COGS o una cocina queda sin recibirlos.

**Verificación pendiente:** no se escribió ni consultó la BD demo en este hallazgo, no se ejecutó pedido real. Requiere unitarias del snapshot/cálculo, Nest build, widget KDS y prueba E2E en clone DB descartable: cotizar→crear→cada estación ve el componente→stock y COGS correctos→cancelar/restaurar→reintento idempotente.

**Avance 2026-11-26 (parcial, el hallazgo sigue abierto):** se añadió `componentes_snapshot` (migration 095) y se conectó a creación y agregado de combo, COGS/stock, reconstrucción para pedidos QR pendientes, representación KDS e impresión. Se conserva la línea única que contiene el precio del combo. 25 suites/78 pruebas backend de pedidos, cocina, impresión y guardia de catálogo pasan; Nest compila. La verificación pendiente original sigue aplicando: la cancelación sí restaura desde el ledger de movimientos tipo venta; el snapshot de composición aplica a consumo y revalidación de pedidos QR pendientes, no guarda recetas expandidas; un combo con productos de más de una cocina no tiene todavía ruta/estado por estación. Como guardia de seguridad, catálogo ahora impide crear uno y cotización/alta rechazan combos legados incompatibles o sin cocina, en lugar de ocultar componentes en otra estación. La migration no se ha aplicado y no se usó la API diaria ni la base demo.

### PED-KITCHEN-POSTCOMMIT-01 — entrega a KDS e impresión tras confirmar

Pedido, inventario, pagos/Caja, historial, mesa y factura borrador se escriben dentro de `DatabaseService.enTransaccion()`. Una vez confirmado el commit, `PedidosCrearService` publica actualizaciones y dispara `PedidosSoporteService.notificarCocinasPorPedido()` como promesa no esperada. El método consulta cocinas y luego pide a `ImpresionService` crear jobs. Si el lookup inicial falla, antes rechazaba sin solicitar impresión; el pedido y stock ya estaban confirmados. El KDS puede descubrir el pedido en su siguiente GET/polling, pero eso no creaba la comanda.

Se corrigió con manejo/log del fallo y un intento de impresión que sigue aun cuando el lookup KDS falle; fallos de Realtime por cocina se capturan por separado. No es una garantía durable de entrega de evento en caso de caída prolongada de la base o proceso: para eso haría falta outbox/reconciliación, que no se justifica sin evidencia de volumen/pérdidas. `pedidos-soporte-impresion.spec.ts` 2/2; pedidos+impresión 20 suites/68; Nest build OK; POS Flutter 20/20 y analyzer limpio. No se probó una impresora real ni se activó el build en API :3000.

## Revisión operativa KDS (2026-11-24)

## Revisión del tablero de pedidos (2026-11-24)

### ADM-03-LIMIT-01 — kanban omite pedidos activos posteriores a la fila 100

**Evidencia:** `PedidosKanbanWidget` llama `PedidosRepository.listarActivos()` sin `page`; el repositorio solicita `limit=100`. Nest solo pagina cuando llega `page` y valida `limit` con máximo 100. Sin paginar, `PedidosService.listarPorSucursal()` aplica `LIMIT 100 ORDER BY p.created_at DESC`, así que conserva los 100 más recientes, no el conjunto total. El panel calcula `Activos`, valor y tarjetas con esa misma lista. En cambio, la pestaña “Cerrados” sí tiene total y botón “Cargar más”.

**Impacto:** una sede que acumule más de 100 pedidos activos oculta los más antiguos del kanban; no se pueden encontrar ni procesar desde esa vista, aunque backend y detalle acepten esos pedidos. KPI/conteos y búsqueda aparentan cubrir todos los activos, pero solo describen los 100 más recientes. Puede causar demoras operativas y pedidos abandonados.

**Corrección (2026-11-24):** `PedidosRepository.listarActivosPaginado()` solicita página/límite y conserva total/meta; el tablero acumula páginas con deduplicación por ID, mantiene el conteo global y cambia el rótulo del valor a “Valor cargado” si falta cargar más. Hay CTA en grid, columnas y resultado vacío con búsqueda; los fallos de carga progresiva muestran reintento. Los filtros y orden se aplican a todas las páginas que ya se cargaron. La API actual ya soportaba esta paginación, por lo que no se modificó Nest ni requiere reiniciar :3000.

**Pruebas:** widget simula más de una página y verifica total 101, pedido antiguo, texto de progreso y KPI; prueba HTTP verifica `page`, `limit`, sede, mesera y el total reportado. Pedidos Kanban + repositorio: **9/9**; analyzer focalizado limpio. Se usa paginación por offset; si se insertan filas mientras se avanza, Realtime/refresh reinicia la lista, pero para concurrencia alta conviene migrar a cursor (keyset) estable.

**Estado:** corregido en interfaz; QA autenticada/móvil y conversión a cursor para tráfico concurrente siguen abiertas.

### ADM-01-LIMIT-02 — dashboard y búsqueda global heredan el límite de 100

**Evidencia:** `DashboardResumenWidget._cargar()` consulta `PedidosRepository.listarActivos()` y luego filtra en Flutter los domicilios atrasados; `mostrarBusquedaAdmin()` hace la misma lectura y busca el texto localmente. Ese método sólo envía `limit=100` sin `page` ni término de búsqueda. Nest ordena por `created_at DESC`, de modo que en sucursales con más de 100 activos las funciones derivadas sólo pueden encontrar los más recientes. Los KPI globales del endpoint de resumen se calculan por SQL y no dependen de esa lista.

**Impacto:** un domicilio viejo aún en ruta puede quedar fuera de la tarjeta de demora del dashboard, mientras el usuario ve métricas globales diferentes; la búsqueda global puede indicar que no hay coincidencias para un pedido anterior al centenar más reciente. No es adecuado “arreglarlo” cargando todas las páginas en cada dashboard (N peticiones, coste proporcional al volumen).

**Propuesta:** crear consultas Nest específicas y acotadas: búsqueda paginada `q` por número/cliente/mesa con scope de sucursal y estado, y bandeja/alerta de domicilios retrasados filtrada por fecha de último estado con límites explícitos. Mantener conteos agregados server-side; aplicar índices según `EXPLAIN` en BD de QA. Requiere QA aislada y ventana coordinada de recarga Nest para habilitar endpoint.

**Estado actualizado (2026-11-24):** corregido en fuente. Demoras del dashboard y búsqueda global consultan selectivamente al servidor bajo scope de sucursal; queda pendiente activar el nuevo backend mediante reinicio coordinado y validar con fixtures aislados. No se cargaron datos artificiales en producción ni se hicieron escrituras de negocio.

## Revisión operativa KDS (2026-11-24)

### KDS-GET-WRITE-01 — efecto lateral de alertas en lectura (corregido en fuente)

**Evidencia:** `CocinasService.listarTickets()` llama `evaluarDemorasEnCocina()` antes del `SELECT`. Para cada pedido con ítems `pendiente`/`preparando` de más de 20 minutos, el método llama `AlertasRiesgoService.registrar()` secuencialmente. `registrar()` abre una transacción; `registrarEnTransaccion()` consulta si existe alerta pendiente con deduplicación y, si no encuentra, inserta `alertas_riesgo` y publica Realtime tras commit.

**Impacto:** abrir/recargar una pantalla aparentemente de lectura puede escribir alertas. Un conjunto grande de atrasos puede abrir muchas transacciones en secuencia y prolongar la respuesta del KDS. Si se revisa una alerta mientras el ítem siga atrasado, un GET posterior puede generarla de nuevo. El filtro de duplicados por alerta pendiente limita, pero no elimina, este comportamiento.

**Observación runtime solo lectura:** Chrome mostró 105 tickets retrasados y varios temporizadores superiores a 3.790 horas con estado global “Cobrado”. El SELECT actual conserva pedidos globales `pagado` cuando aún tienen ítems de cocina sin resolver; esto contempla prepago antes de terminar cocina. La edad extrema podría ser test/legacy, fallo de transición o backlog real; no se puede inferir cuál solo con la UI. No se cambió pedido, ítem ni alerta deliberadamente. Debido al efecto lateral del GET, puede haberse insertado alguna alerta si el dedupe no encontró una pendiente; sin consulta a auditoría/BD no se determina el delta. No se intentará revertir por conjetura.

**Corrección:** `CocinasService.listarTickets()` ahora sólo valida la cocina y ejecuta el SELECT. `CocinasDemorasCronService` ejecuta evaluación cada cinco minutos (primera evaluación 15 s después del inicio), con `pg_advisory_lock` 9200009 para que una sola réplica lidere; excluye alertas todavía pendientes y limita el lote a 200 pedidos. `AlertasRiesgoService.registrarVariasEnTransaccion()` los registra en una transacción compartida, manteniendo deduplicación y hooks de Realtime posteriores al commit. Sin dependencia nueva.

**Pruebas:** tres suites nuevas, 4 casos: lectura KDS no registra alertas, cron genera el lote y respeta el límite, y el servicio registra varias en una sola transacción. Nest build OK; suite completa: **22 suites / 53 tests aprobados**. El proceso Nest :3000 no se reinició; el cambio no está activado en el API del Tunnel hasta una ventana de reinicio. Sin escrituras en BD de negocio por esta validación.

**Observación runtime previa:** Chrome mostró 105 tickets retrasados y varios temporizadores >3.790 h con estado global “Cobrado”. No se modificó pedido, ítem ni alerta deliberadamente. Como GET tenía efecto lateral, pudo haberse insertado una alerta si faltaba deduplicación; no se puede determinar el delta sin consultar BD/auditoría y no se intentará limpieza por conjetura. El SQL conserva pedidos globales `pagado` si aún quedan ítems de cocina sin resolver, regla que puede ser válida con prepago; clasificar los registros históricos antes de archivar/excluirlos.

**Aclaración de comparación de tenants (2026-11-25):** la cifra 105/117 se volvió a obtener usando la cuenta `cocina@foody.demo`, que consulta `Sede Centro`; no corresponde a la sesión autenticada de Chrome, que mostró `Sede principal` con `Cocina 0 / Listos 6`. Una consulta SQL de solo lectura encontró una sede principal con 6 pedidos y 20/20 líneas resueltas, y otras sedes con tickets en cocina. Por ello la discrepancia visual/API inicial fue una comparación de contextos distintos, no evidencia de conteo incorrecto del KDS. No se deben mezclar métricas entre tenants; cualquier conciliación de estados históricos debe filtrar explícitamente el tenant y sucursal exactos.

**Comportamiento a revisar:** una alerta que se marque revisada puede generarse de nuevo en el siguiente ciclo si el ítem permanece atrasado; esto respeta la deduplicación anterior (sólo pendientes), pero ahora el ritmo es de cinco minutos incluso si nadie abre el KDS. Definir cooldown/una-alerta-por-demora si el operador considera ruidosa la repetición. No se archivan alertas ni pedidos.

### Hallazgo corregido — `PED-ORIGIN-DOM-01`

**Antes:** `direccion_entrega` era opcional en `CrearPedidoDto`, aunque Checkout y POS la solicitan para domicilio. Un consumidor HTTP podía saltarse la validación Flutter y crear una entrega sin dirección.

**Cambio:** el DTO Nest ahora exige `direccion_entrega` no vacía solo si `tipo === 'domicilio'`. Se acepta dirección textual sin coordenadas; retiro/mesa no heredan el requisito. Specs de DTO cubren omisión, dirección manual, retiro y texto en blanco.

**Evidencia:** `pedidos-public.controller.ts` y rutas staff comparten `CrearPedidoDto`; `pedidos-crear.service.ts`; `crear-pedido.dto.spec.ts` (4 casos), `pedidos.controller.spec.ts` (6 casos). Jest focalizado: **10/10**; `npm run build`: OK. No se desplegó al proceso actual de :3000 ni se hizo smoke de escritura sobre datos reales.

### `PED-PRICE-UX-01` — tarifa estimada sin ubicación

`ZonasService.calcularCostoDomicilio` selecciona la zona de menor radio cuando no recibe coordenadas (`distancia_km: null`). Checkout mostraba «Costo domicilio» sin advertir que era una estimación, aunque dirección textual y entrega se permitían. La UI ahora muestra «Costo domicilio estimado (puede cambiar al confirmar la ubicación)» cuando la respuesta no contiene distancia; con distancia calculada conserva «Costo domicilio». No cambia la cotización ni requiere ubicación.

### `FIN-REC-OPEN-01` — divulgación de ventas versus caja

Finanzas y Centro de Análisis muestran una tarjeta informativa que aclara que el KPI puede incluir pedidos pendientes o impagos y no es el total recibido en caja. No se modificaron las fórmulas de ventas/utilidad ni se presentó una regla contable como decisión tomada. El informe de Reportes ya separaba «Tickets» de «Cobrado en caja».

**E2E financiero (2026-11-24):** caso `FIN-REC-OPEN-01` en `test/flujos/caja.e2e-spec.ts` crea una venta de mesa pendiente, completa cocina, cobra efectivo y compara el delta antes/después en `GET /reportes/financiero` y `GET /analitica/caja`. El total de tickets, movimientos netos de caja en ambos módulos coinciden con el total del pedido; el delta de la diferencia de cuadre es $0. Suite aislada completa: 8/8 suites, 17/17 pruebas. La prueba valida la ruta pagada y no resuelve la decisión de reconocimiento de pedidos sin cobrar ni domicilios.

### Caja, domicilio y definición de ingresos

- Suscripción SaaS de Foody, total vendido en productos, tarifa cobrada al cliente por domicilio, comisión Foody sobre esa tarifa y liquidación del domiciliario son conceptos distintos. Este flujo no encuentra comisión porcentual sobre subtotal de productos.
- `costo_domicilio` se guarda en el pedido; la caja de domicilio se registra al confirmar entrega, mientras mesa difiere el registro hasta cobrar. El despacho calcula una comisión Foody por defecto configurable aplicada al valor del domicilio y el saldo estimado del repartidor; la liquidación del domiciliario de planta e independiente sigue rutas/tablas distintas.
- `ReportesService.financiero` compara tickets (suma `pedidos.total`, puede incluir pedidos abiertos) con caja neta (ventas menos devoluciones). La diferencia es declarada esperable, pero el resumen llama `ventas_total` a los tickets; la interfaz debe mantener ambas magnitudes etiquetadas y no presentarlas como ingreso conciliado.
- `FinanzasService.snapshotPl` también suma `pedidos.total` para todo pedido salvo cancelado/rechazado, y resta costos de ítems + gastos registrados. Por tanto, un pedido pendiente de aprobación, en cocina o con saldo pendiente puede entrar a utilidad antes de realizarse/cobrarse. Analítica comparte el predicado de estados válidos; eso unifica consultas pero no resuelve el criterio contable.
- Domicilio a cuenta de domiciliario de planta crea CxC y registra caja al liquidar; el independiente tiene ganancias/comisión separadas en `ganancias_domiciliario`, con saldo `pagado=false`. No se pudo confirmar en este recorrido que toda liquidación de independientes genere un gasto/asiento financiero que afecte el P&L.
- En independiente, `ganancias_domiciliario` se inserta al aceptar la oferta, antes de la entrega. Cancelar cambia la asignación a `cancelado`, pero el resumen por sucursal suma esas ganancias y el `por_pagar` de entradas `pagado=false` sin filtrar asignación entregada/cancelada. **DOM-CANCEL-PAYOUT-01:** no se debe borrar ni revertir automáticamente hasta definir si hay pago por intento/recorrido cancelado; hoy puede quedar comisión Foody y saldo del domiciliario aunque la entrega no termine.
- **Decisión comercial pendiente:** confirmar si la comisión configurable sobre domicilio se mantiene en el modelo Free→Pro y quién soporta el cargo (cliente, establecimiento o repartidor). No confundirla con comisión sobre ventas ni con la suscripción mensual. Un cambio altera precio de checkout, margen y liquidación.
- **Decisión contable pendiente (`FIN-REC-OPEN-01`):** definir cuándo se reconoce una venta y el costo del servicio de domicilio en Rentabilidad: pedido confirmado, preparado, entregado o efectivamente pagado; definir tratamiento de abonos, impagos, devoluciones y saldo del domiciliario. Mantener métricas separadas de valor ordenado, ingreso cobrado y utilidad reconocida hasta tomar esa decisión.
- **Decisión de política pendiente (`DOM-CANCEL-PAYOUT-01`):** decidir compensación al domiciliario y comisión Foody cuando la oferta ya fue aceptada y el pedido se cancela antes/después de iniciar ruta. La implementación actual conserva la ganancia como pendiente.
- **Contacto del domicilio (`CLIENT-DOM-CONTACT-01`, resuelto en fuente):** Checkout público exige teléfono de contacto válido y Nest vuelve a validarlo; nombre es opcional. El POS requiere nombre/teléfono/dirección en su formulario. La activación del DTO en el proceso `:3000` se controla por separado; ver `MASTER_STATUS.md`.

### `DOM-PAY-BALANCE-01` — abono parcial y saldo al entregar

**Hallazgo:** las consultas de pedidos asignados a planta e independientes entregaban `total`, `costo_domicilio` y `metodo_pago`, pero omitían `monto_pagado`. Ambos paneles decidían abrir el selector de pago solo cuando `metodo_pago` era `pendiente` o nulo. Si el pedido tenía un abono y conservaba un método, se podía omitir el selector del saldo restante y reutilizar el método anterior sin confirmar con el repartidor. La regla de negocio del backend ya calculaba el saldo; la vista no recibía ese estado.

La tarjeta de planta mostraba `subtotal` como “Producto” y el `total` completo como “Total a cobrar”. Con promoción/descuento, `subtotal` no es el valor neto de productos; con abono, `total` tampoco es el importe pendiente.

**Cambio implementado:** ambos endpoints ahora incluyen `monto_pagado` y exponen `saldo_pendiente`, `requiere_cobro`, `producto_total`, `producto_pendiente` y `domicilio_pendiente`, calculados por el helper compartido `repartirCobroDomicilio`. Las apps abren el selector según la decisión booleana del servidor. La tarjeta presenta el total neto de producto y el saldo pendiente; la app de planta muestra el reparto exacto que va a cobrar y permite separar métodos como antes. En respuesta de API antigua, el copy evita afirmar que el subtotal es neto y conserva el comportamiento previo hasta actualizar Nest.

**Regla preservada:** abonos previos se aplican primero a productos y el remanente al domicilio; el domicilio ingresa a caja solo según la configuración de sucursal. No se alteró la imputación, comisión, caja, saldo o payout; tampoco se creó ni liquidó un pedido real.

**Evidencia automatizada:** helper: 5 casos; serialización de ambos servicios: 2 casos; tarjeta planta a 320 px: 1 caso; backend completo: 6 suites / 23 pruebas; Flutter completo: 158 aprobadas / 5 E2E de escritura omitidas; analyzer focalizado sin hallazgos; `npm run build` exitoso. Cliente/Equipo release se reconstruyeron y seis rutas locales/públicas dieron HTTP 200.

**Activación y QA pendientes:** el proceso Nest en `:3000` no se reinició; su endpoint puede seguir omitiendo los campos hasta reiniciar con el `dist` actual. El fallback conserva el flujo anterior mientras tanto. Tras reinicio, confirmar ambos perfiles con fixtures en BD QA aislada (abono parcial al producto, solo domicilio pendiente, pedido completo y método mixto). No se probó una entrega ni cobro con datos reales. Esto no resuelve `DOM-CANCEL-PAYOUT-01`.

### Próxima cobertura de ciclo completo

1. Recorrer UI de mesa QR a aprobación, KDS por ítem, despacho/aceptación, entrega, cobro y liquidación con una base QA aislada.
2. Cubrir acceso multi-sucursal/sesión de mesero y acciones Kanban por rol; `crear_pedido` en PATCH de estado aún es más amplio que una matriz por transición.
3. Comparar totales de pedido/caja/finanzas/analítica con fixtures que incluyan abonos, devolución, domicilio y propina.
4. Resolver obligatoriedad del nombre/teléfono de contacto del domicilio público (POS ya los exige) y cubrir contrato con pruebas.

### `COC-NODISP-DOM-01` — despacho con una línea no disponible

**Severidad: alta · estado: barrera técnica implementada en fuente y probada en unidad; activación/QA integrado pendiente. La política de pedido parcial sigue pendiente.**

- La política VIE-09 C trata `no_disponible` como resuelto: cuando ya no quedan ítems en otro estado, `cambiarEstadoItem()` mueve el pedido a `listo`.
- Si el pedido es domicilio, ese mismo cambio llama inmediatamente a `intentarDispatchDomicilioSiListo()`. Antes la asignación automática y manual solo dependían del tipo/estado y no comprobaban líneas `no_disponible`.
- El artículo sigue dentro de `pedido_items` y `pedidos.total`; por lo tanto el domiciliario puede recibir un pedido cuyo contenido y valor todavía incluyen un producto que cocina reportó faltante. La alerta al salón es asíncrona y no constituye una barrera de despacho.
- El personal puede retirar la línea después: `eliminarItemPedido()` recalcula subtotal, descuento, total e IVA y registra merma/alerta según el estado de cocina. `listo` no está en la lista de estados terminales de ese servicio. Sin embargo, el despacho automático puede haber ocurrido antes, así que esta corrección posterior no evita una asignación prematura.
- La fuente ahora usa `DispatchService.validarPedidoParaDespacho()` en dispatch automático, asignación manual a domiciliario de planta, creación de ofertas independientes, y de nuevo al aceptar una oferta independiente. La validación transaccional vuelve a leer y bloquear la fila de pedido antes de crear asignación/oferta, para reducir la carrera con un cambio concurrente.

**Riesgo funcional/económico:** despacho con producto no disponible y total que aún lo cobra; puede causar contacto de devolución, ajuste tardío y discrepancia entre lo que ve cliente, cocina, caja y domiciliario. En pedidos de mesa/recogida también existe una brecha de comunicación, pero no se dispara el despacho.

**Qué falta decidir:** si la línea no disponible se elimina/ajusta antes de cerrar preparación y despachar; si el pedido parcial puede seguir con confirmación del cliente; y cómo devolver o reasignar abonos ya asociados a la línea. VIE-09 C solo decidió fallo explícito + merma + alerta; no resolvió la autorización del cliente ni la liquidación comercial de la línea.

**Barrera aplicada:** no se cambia el estado `listo`, las líneas, totales, pagos, caja ni stock; los caminos cubiertos rechazan asignar/ofertar mientras exista una línea `no_disponible` y explican que se revise el pedido y se confirme el total. Esto evita despacho prematuro sin decidir qué hacer con el producto o el dinero.

**Evidencia:** `cocinas.service.ts` (`cambiarEstadoItem()` y `intentarDispatchDomicilioSiListo()`), `dispatch.service.ts` (`validarPedidoParaDespacho()`, `intentarDispatchAutomatico()` y creación de ofertas), `domiciliarios.service.ts` (`asignarPlanta()`/`reasignarPlanta()`), `domiciliarios-independientes.service.ts` (`responderOferta()`), `pedidos-items.service.ts` (`eliminarItemPedido()`) y `AUDITORIA_CASOS_VIERNES.md` VIE-09. Pruebas unitarias: 6/6 focalizadas; backend completo: 9 suites/29 pruebas y build OK. La reasignación de una entrega ya activa (`asignado`/`en_camino`) conserva su semántica de continuidad y no es una nueva oferta; necesita escenario operativo específico.

**QA integrada (2026-11-24):** con Nest temporal `127.0.0.1:3001` y PostgreSQL dedicado `foody_diseno_qa`, E2E creó domicilio con dos ítems, marcó uno `no_disponible` y el otro `listo`, comprobó que la orden queda `listo`, que la asignación manual de planta se rechaza y que el endpoint de búsqueda independiente retorna `datos.iniciado=false` con `PEDIDO_ITEMS_NO_DISPONIBLES`. La regresión secuencial completa pasó **8/8 suites, 16/16 pruebas**. La instancia temporal se detuvo; pedidos de prueba se cancelaron y se restauró el fixture a producto disponible, inventario demo 10.000 g y horario 08:00–22:00. No se reinició Nest :3000 ni se alteró Tunnel. La API principal no contiene aún la barrera hasta una activación coordinada. Sigue pendiente definir confirmación del cliente, eliminación/ajuste de línea, abonos y tratamiento de retiro/mesa.

### Contrato de contacto por origen — verificación adicional

- Checkout público valida dirección y teléfono para domicilio; el nombre se serializa como `null` si queda vacío. No fuerza mapa ni coordenadas, ya que la dirección textual está admitida y la tarifa puede cotizarse como estimada.
- POS solicita nombre, teléfono y dirección con `*` y bloquea el envío si alguno está vacío.
- El DTO Nest exige dirección no vacía y teléfono de 7–15 dígitos para domicilios; nombre es opcional. La validación se vuelve a aplicar en el límite HTTP, además de la validación visual de Flutter.
- La diferencia deliberada es que el formulario POS pide también un nombre, mientras que el canal público conserva el modo invitado. No se fuerza ubicación: la dirección manual continúa permitida y el precio de domicilio se comunica como estimado cuando no hay coordenadas.
- La regla quedó implementada y probada como `CLIENT-DOM-CONTACT-01`; Flutter 3/3, DTO Nest 8/8 y E2E en QA aislada 4/4. Estas pruebas no equivalen a revisar visualmente una sesión real ni acreditan que el proceso actualmente activo en `:3000` haya cargado el DTO nuevo.

### POS — pago mixto y total autoritativo (2026-11-23)

- **Recorrido inspeccionado:** `PedidoCajeroScreen._confirmarPedido()` → `PedidosRepository.crearPedidoStaff()` → `POST /pedidos/staff` → `PedidosCrearService.crear()` → validación y transacción PostgreSQL. No se envió un pedido real.
- Flutter habilita pago mixto solo para `para_llevar` y crea dos líneas de pago. El estimado mostrado en POS (`_totalVisual`) solo suma subtotales del carrito. No consulta el endpoint de estimación y, por tanto, no incluye promociones automáticas/código ni ajustes que Nest calcule. Nest vuelve a resolver precios, promociones y total, y calcula el IVA informativo por separado; para pagos mixtos exige que las líneas sumen el total autoritativo con tolerancia de 0,01 y rechaza la transacción si no coinciden. La UI no muestra antes del envío esta diferencia ni valida que ambos montos sean positivos y coincidan.
- **Efecto reproducible por lectura:** con una promoción automática aplicable a un pedido para llevar, el POS divide el total bruto y el backend exige la suma neta descontada; el rechazo ocurre únicamente al confirmar. También puede ocurrir si el usuario cambia el carrito luego de activar pago mixto, porque los montos editados no se recalculan.
- **Severidad:** media (fallo recuperable, sin escritura parcial porque el pedido y caja usan transacción; genera rechazo evitable y confusión operativa).
- **Recomendación:** pedir al backend la estimación autoritativa al variar carrito/canal; mantener estado de carga/error de cotización; validar pagos contra ese total y presentar la diferencia antes de habilitar confirmar. Nest mantiene la validación como autoridad. No duplicar cálculo de precios/promociones en Dart.
- **Reintento:** el DTO admite `idempotency_key`, pero `crearPedidoStaff()` no la incluye. `enviando` evita doble tap durante la petición, no garantiza idempotencia si el servidor confirma y la respuesta se pierde y el usuario vuelve a enviar. La solución segura requiere conservar la misma clave y exactamente el mismo payload hasta obtener resultado, o devolver/consultar el resultado por clave; una clave nueva en cada tap no evita duplicados.
- **Aislamiento de la clave:** `pedidos_idempotencia.clave` es globalmente única, sin `sucursal_id`; las búsquedas por clave no filtran por sede ni validan hash del payload. Al reutilizar una clave existente, la ruta pública devuelve id, total y `seguimiento_token` del pedido asociado. El cliente actual genera UUID v4 para Checkout, por lo que no se demuestra exposición práctica con ese flujo normal; sí queda una debilidad de contrato si otro cliente usa claves predecibles/reutilizadas o si una clave se comparte entre establecimientos. Corregir el diseño antes de ampliar reintentos: scope compuesto por tenant/sede + clave, verificar huella de petición, y limitar datos devueltos por la respuesta idempotente. No probar claves contra pedidos vivos.
- **Cadena y efectos confirmados por código:** Nest toma la conexión transaccional; calcula precios desde catálogo de la sucursal, valida disponibilidad, obtiene costo de domicilio/promos/IVA, valida y descuenta stock al crear solo si el estado activa cocina, inserta pedido e ítems, registra pagos y caja según canal/estado, actualiza saldo pagado, historial y mesa ocupada, luego emite avisos Realtime a pedidos/mesas/cocinas/caja después de la transacción. No se comprobó la entrega de cada broadcast en runtime ni un ciclo autenticado completo.
- **POS-TOTAL-DRIFT-01 (2026-11-26):** `PedidoCajeroScreen` bloquea si falta la estimación para un `para_llevar` cobrado, pero `PedidosRepository.crearPedidoStaff()` no envía el total cotizado al alta. `PedidosCrearService` vuelve a resolver el catálogo y recalcula dentro de la transacción. Pago mixto compara su suma con ese total y revierte si cambió; un único medio no tiene comparación contra lo que el operador vio, por lo que movimiento de Caja y `monto_pagado` toman el importe recién recalculado. Es riesgo de precio/cobro, no prueba de pérdida ni de desbalance ocurrido; no se ejecutó por canal porque requiere QA aislada. Propuesta: si negocio quiere exigir consentimiento explícito ante variación, agregar precondición `total_esperado` y conflicto anterior a escrituras; UI refresca el valor y exige una segunda acción, sin reintentar el cobro automáticamente.
- **Resultado de esta etapa:** hallazgo y propuesta documentados, sin cambios de código ni operaciones comerciales. El test E2E de confirmación real sigue pendiente por falta de BD QA aislada; no usar la BD demo/live para prueba de mutación.

### Resolución parcial POS — estimación de servidor y pago mixto (2026-11-23)

- `PedidosRepository.estimarTotales()` reutiliza los serializadores de productos y combos y consulta `POST /pedidos/estimar`; el endpoint solo calcula, no crea pedido ni escribe pagos/caja/stock.
- El POS solicita la estimación con debounce de 300 ms al cambiar carrito, canal, mesa o dirección. Ignora respuestas obsoletas si el usuario cambia de nuevo el pedido. Muestra el total estimado del backend y marca explícitamente el importe local como aproximado cuando no se pudo cotizar.
- Para pago mixto, ambos importes deben ser positivos y sumar el total del servidor (tolerancia de 0,01); mientras cotiza, si falla la cotización o hay discrepancia, se bloquea confirmar. La validación vuelve a ocurrir al pulsar confirmar. El servidor conserva la última palabra al crear.
- No se muestran controles de pago cuando el formulario agrega líneas a un pedido abierto: esa ruta llama `/pedidos/:id/items` y no procesa el payload de pago.
- **Validación:** Flutter focalizado POS 7/7 (incluye 320/390/820/1440 px, total autoritativo distinto del precio local, discrepancia de pagos y cargas paralelas); `flutter analyze --fatal-infos` de repositorio, pantalla y prueba: limpio. La solicitud directa de `POST /api/v1/pedidos/estimar` con un producto demo devolvió `exito=true`, total 2500 COP e IVA informativo de 399,16; no creó pedido ni modificó datos. El contrato existente de Nest no se cambió y el proceso API siguió activo.
- **Límites / pendientes:** no se creó un pedido real, no se probó promoción activa ni red lenta autenticada. Cada edición confirmada del carrito puede añadir una petición de cotización (debounce reduce ráfagas; no hay medición de latencia). El total puede cambiar entre cotización y confirmación; Nest debe mantener y mantiene la validación autoritativa. El alta staff aún no lleva idempotencia segura ante timeout/reintento; el riesgo de alcance global de la clave del flujo público continúa pendiente de diseño. No se marca completo el ciclo de pedido.

### QA E2E aislada — ciclo pedido/cocina/domicilio/caja (2026-11-23)

- **Destino:** PostgreSQL dedicado foody_diseno_qa, mapeado solo a 127.0.0.1:55494; API Nest temporal 127.0.0.1:3001. Supabase, Firebase y Wompi deshabilitados en el proceso QA. No se apuntó a supabase-db, :3000 ni a la BD del túnel.
- **Fixture:** al inicio faltaban domi@foody.demo y las recetas/ingredientes de Papas medianas; el producto estaba indisponible. Se aplicaron las semillas canónicas `019_domiciliario_demo.sql` y `031_paso1_demo_recetas.sql` solo a QA y se restauró el flag disponible conforme al seed 012.
- **Resultado anterior:** `npm run test:e2e -- --forceExit` → 7/7 suites, 14/14 pruebas: QR cliente/anti-tamper, mesa, caja/cobro, cocina KDS, domicilio, casos límite y salud. Esta ejecución precede la extensión actual del caso PED-PREPAGO-01 para probar cierre de caja; esa nueva aserción compila, pero aún no se ejecutó por el bloqueo automático del arranque de Nest QA descrito en `MASTER_STATUS.md`.
- **Observación de capacidad:** con pool QA = 3, las tareas periódicas que adquieren advisory lock y hacen trabajo adicional de BD ocuparon las conexiones disponibles y la API dejó de contestar; un health check superó 5 s. Con pool QA = 10, health contestó en 111 ms y la suite completa pasó en 4,333 ms. Es sensibilidad del harness con pool artificialmente bajo; no es medición p50/p95 ni evidencia de bloqueo del servicio real (cuyo requisito de producción exige pool >=25).
- **Integración auxiliar:** reintentos del procesador de impresión contra agente QA ausente 127.0.0.1:8765 generaron logs; no bloquearon el conjunto de pruebas. El harness debería poder apagar esta integración o usar una cola de impresión vacía.
- **Límites:** las pruebas sí escribieron pedidos, estados y movimientos en la base QA aislada. No prueban Wompi real, push FCM, hardware de impresora, carga concurrente ni conciliación financiera completa. No se modificó código de negocio ni la instancia :3000.

### Actualización ADM-01-LIMIT-02 (2026-11-24)

Se corrigió parcialmente el dashboard: el resumen Nest adjunta `domicilios_tardios`, máximo 8 elementos, filtrados por último estado (listos >8 min; asignados/en ruta >25 min; alta severidad ≥40 min), dentro de la consulta/cache existente. La UI prioriza ese campo, por lo que no solicita activos para derivar demoras cuando está disponible. Se conserva fallback top 100 para versiones antiguas. Pruebas nuevas verifican pedido antiguo visible sin llamada a activos y contrato SQL/cache. La búsqueda global todavía usa top 100 y queda abierta; requiere búsqueda server-side paginada y con scope.

La corrección es solo fuente: Nest :3000 no se reinició y el Tunnel aún entrega el resumen anterior. La pantalla remota continuará con fallback hasta un reinicio coordinado. No hubo escrituras de negocio.
### Cierre de búsqueda ADM-01-LIMIT-02 en fuente (2026-11-24)

La ruta global de pedidos activos acepta `q` validado (2–80 caracteres), aplica búsqueda parametrizada por número, nombre/teléfono de cliente y mesa, preserva sucursal y estado activo, y pagina con límite 6. El cliente deja de descargar el top 100, espera 250 ms tras escribir y consulta en servidor; mantiene resultados de módulos y mesas. Pruebas de contrato/repositorio y SQL verifican scope, parámetros, total y límite. Nest actual 24 suites/55 tests, build OK; Flutter 186 aprobadas/5 omitidas; analyzer focalizado sin issues.

**Estado:** resuelto en código fuente. Nest :3000 no se reinició para conservar el Tunnel en operación; la búsqueda nueva requiere activar backend en una ventana coordinada. Hasta ese reinicio, la interfaz publicada puede llamar a una API anterior. No se ejecutaron escrituras de negocio.
### UX de búsqueda administrativa — 2026-11-24

El buscador del panel conserva los mismos resultados y navegación, pero usa una paleta compacta cuyo alto depende del contenido y se limita según el viewport y el teclado. Incluye título y cierre accesible, texto de búsqueda, listas con títulos de grupos, truncamiento de datos largos, accesos rápidos, helper cuando el término tiene un carácter, error diferenciado y recuperación con reintento. La consulta de pedidos solo se lanza desde dos caracteres y mantiene debounce de 250 ms.

**Pruebas:** 7 casos de widget; tamaños 320/390/820/1440, consulta server-side con sucursal, reintento y umbral mínimo. La captura renderizada comprobó la altura compacta, pero el entorno del golden no cargó las fuentes de aplicación; se retiró el golden para no fijar una referencia tipográfica inválida. Falta QA visual autenticada en Chrome/dispositivo y confirmar con backend nuevo activo.

### PED-NUM-RACE-01 — numeración concurrente — 2026-11-24

`generarNumeroPedido()` usaba `COUNT(*) + 1` por sucursal/año sin coordinación. Varios canales pueden crear pedidos a la vez; dos transacciones podían devolver el mismo número legible (la tabla no declara unicidad por sucursal/número). La generación ahora toma `pg_advisory_xact_lock` por sucursal/año antes del conteo, dentro de la transacción de alta, y filtra por límites temporales del año en `America/Bogota` para hacer elegible el índice `(sucursal_id, created_at)`.

**Verificación:** nueva prueba del contrato asegura lock antes del conteo, clave por sucursal/año y rango Bogotá; suite de pedidos y `npm run build` OK. Se confirmó un único llamador (`PedidosCrearService`), compartido por altas públicas y staff. Después, con Nest compilado aislado en `127.0.0.1:3001` y PostgreSQL QA en `127.0.0.1:55494`, E2E completo secuencial: **8/8 suites, 15/15 pruebas**. El caso nuevo lanzó cuatro pedidos públicos simultáneos y comprobó cuatro números distintos. Las suites no deben correr en paralelo contra este fixture compartido: consumen stock de recetas y la limpieza de pedidos no repone inventario. Se repuso la semilla QA a 10.000 g, horario 08:00–22:00, y se detuvo nuestra instancia temporal :3001. La API :3000 no se reinició para conservar Tunnel; Cloudflare siguió activo. Esto comprueba serialización en la BD aislada, no estrés del runtime productivo. El conteo anual aún crece con el volumen; una secuencia por sucursal/año se difiere hasta tener métricas que la justifiquen; no se añadió tabla ni migración.

### ADM-PAY-TIMING-01 — momento de cobro visible por canal (2026-11-24)

En el POS staff, el mismo campo de método de pago aparecía para mesa, domicilio y para llevar sin decir cuándo se materializa el cobro. `PedidosCajaAuditoriaService.debeRegistrarVentaAlCrear()` difiere mesas y domicilios; para llevar con método cobrable registra el movimiento al crear. En la entrega hay dos rutas: el controlador del domiciliario rechaza `pendiente` (`COBRO_REQUERIDO`) y requiere que el repartidor indique cómo cobró; en cambio, `PedidosEstadoService`, al marcar manualmente `entregado` desde el flujo Admin, convierte `pendiente` en `efectivo` y registra el movimiento en Caja. Esta diferencia puede anotar efectivo no recibido si se confirma manualmente una orden sin cobro; queda como decisión comercial/operativa pendiente. La UI explica los tiempos y advierte el comportamiento de ambos caminos; el filtro global preserva ahora `COBRO_REQUERIDO` y devuelve un mensaje legible. No se alteraron las reglas de cobro ni el payload.

**Evidencia:** `lib/features/pedidos/presentation/pedido_cajero_screen.dart`; `lib/features/admin/presentation/widgets/pedidos_kanban_widget.dart`; `foody_backend/src/modulos/pedidos/pedidos-caja-auditoria.service.ts`; `foody_backend/src/modulos/pedidos/pedidos-estado.service.ts`; `foody_backend/src/modulos/domiciliarios/domiciliarios.service.ts`; `foody_backend/src/compartido/filtros/http-exception.filter.ts`; `test/pedido_cajero_screen_test.dart`; `test/pedidos_kanban_widget_test.dart`; `foody_backend/test/flujos/domicilio.e2e-spec.ts`. POS 11/11; Kanban 9 pruebas incluye advertencia, cancelación sin request y confirmación con request; Flutter global 208 aprobadas/5 omitidas; analyzer focalizado limpio; Nest 26 suites/57 tests; E2E domicilio 4/4 sobre PostgreSQL QA `foody_diseno_qa` y API temporal :3001. El E2E confirma tanto el rechazo del repartidor (`COBRO_REQUERIDO`) como que el cierre manual Admin convierte “Pendiente” en efectivo y registra movimiento en Caja. La advertencia en Admin mitiga el riesgo de acción accidental, pero la decisión sobre si el fallback a efectivo debe seguir existiendo permanece pendiente de producto; no se cambió backend ni payload.

### FIN-MESA-SPLIT-01 — asignación de pagos mixtos por ticket (2026-11-24)

**Hallazgo reproducido:** `cobrarCuentaMesa()` distribuía `monto_pagado` por todos los tickets activos, pero insertaba cada línea de `pagos` en Caja vinculada a `cobrados[0]` (o al primer ticket). `CajaMovimientosService.registrarVentaPedido()` limita la venta al total aún no registrado del pedido enlazado. Resultado: dos tickets podían quedar `pagado` aunque al segundo no se le registrara su parte del recaudo; la reversa y consulta de movimientos por ticket tampoco tenían vínculo correcto.

**Corrección:** en la misma transacción, cada línea de pago se recorre contra los saldos asignados por ticket, creando movimiento(s) con `pedido_id`, importe y método correspondientes. Si la suma de un pago no cabe en la distribución calculada (`DISTRIBUCION_COBRO_INVALIDA`) o Caja no confirma el registro (`MOVIMIENTO_CAJA_NO_REGISTRADO`), se aborta la transacción completa. No cambia el total cobrado, endpoint, permisos, política de propinas ni datos reales.

**Evidencia:** nuevo caso E2E en `foody_backend/test/flujos/caja.e2e-spec.ts` crea dos pedidos en una mesa, los lleva por cocina, paga efectivo y tarjeta, y valida que cada ticket tenga un movimiento por su total y método. Antes del fix la aserción no encontraba venta para uno de los tickets; después: E2E de Caja 4/4 y E2E completa 8/8 suites/20/20 sobre `foody_diseno_qa`; con la protección añadida, las 26 suites/57 pruebas unitarias y el E2E de Caja 4/4 vuelven a pasar; Nest `dist` inicia correctamente. Fixture QA restaurada a horario 08:00–22:00, ingrediente demo 10.000 g y producto disponible; API temporal :3001 detenida. El `:3000` aún no carga el cambio.

**FIN-TIP-01 — atribución corregida; decisión contable pendiente:** `propina` se registra en `pagos_pedido` y `propina_acumulada`, pero el movimiento de Caja recibe solo el monto de la venta. `CajaService.cerrar()` ahora calcula `propinas_turno` desde los pagos efectivamente registrados entre la apertura y el cierre del turno, en vez de usar la fecha de creación del pedido. El total sigue separado y no se suma al saldo de sistema ni al cuadre. E2E Caja en clon desechable pasó 8/8; la regresión creó el pedido antes de abrir la caja nueva, abonó $4.000 mediante efectivo/tarjeta con $600 de propina y pagó el saldo por transferencia con $800 de propina; cierre `propinas_turno=1400`, diferencia de caja cero. Falta definir si el efectivo esperado incluye propinas y si son pasivo por pagar, entrega directa o reparto por turno/persona; siguen pendientes pagos en turnos distintos y liquidación al personal.

### PED-POS-CAJA-GATE-01 — caja abierta como precondición del POS (2026-11-24)

**Comportamiento comprobado en fuente:** `PedidoCajeroScreen._confirmarPedido()` rechaza cualquier alta para Admin/Cajero cuando no hay caja abierta (`_cajaAbierta != true`), antes de validar tipo de pedido. Esto incluye pedidos de mesa y domicilio. `PedidosCajaAuditoriaService.debeRegistrarVentaAlCrear()` y el flujo de creación difieren el movimiento de caja para esos dos tipos; mesa se cobra después y domicilio al entregar. El modo Mesero evita el guard.

**Efecto operativo:** hoy no se puede capturar en el POS una mesa o domicilio cuando caja está cerrada aunque no vaya a registrarse dinero en ese momento. Puede ser una política deliberada para vincular toda operación a un turno, pero el mensaje “Abre la caja antes de registrar ventas” no explica por qué se impide registrar un pedido cuyo cobro está diferido. Separa claramente requisito de apertura de turno, registro de pedido y registro de recaudo antes de decidir si el guard se mantiene.

**Decisión pendiente:** confirmar si apertura de Caja es condición general para aceptar pedidos staff, o solo para transacciones que generan movimiento inmediato. Considerar cruce de turnos, trazabilidad de responsable, cierre con pedidos abiertos y cómo deben operar restaurante y domiciliario fuera del horario de caja. No se modificó el flujo ni se emitió una orden.

**Evidencia:** `lib/features/pedidos/presentation/pedido_cajero_screen.dart` (`_confirmarPedido`, guard inicial); `foody_backend/src/modulos/pedidos/pedidos-caja-auditoria.service.ts` (`debeRegistrarVentaAlCrear`); `foody_backend/src/modulos/pedidos/pedidos-crear.service.ts`. Revisión estática, sin mutaciones de negocio; requiere validación con usuario Admin/Cajero en entorno QA.

**Regresión POS/frontend (2026-11-24):** `flutter test --reporter compact` completo: 209 aprobadas, 5 omitidas por guard de QA mutadora, 0 fallidas. `flutter analyze --fatal-infos lib/features/pedidos/presentation/pedido_cajero_screen.dart`: limpio. La prueba completa no recorre una sesión real ni decide el requisito de Caja; la política `PED-POS-CAJA-GATE-01` sigue pendiente. Captura autenticada de Chrome no se pudo validar con la herramienta de escritorio: el AX expuso URLs de Foody, pero la imagen devuelta era la ventana Codex; no se usó para afirmar QA visual.

### PED-POS-REPLACE-PARTIAL-01 — reemplazo de producto con fallo parcial (2026-11-24)

**Hallazgo:** el POS agrega primero el producto nuevo al pedido existente y luego elimina el anterior mediante dos llamadas HTTP independientes. Si la segunda falla, ambos productos quedan en la orden. Antes, el bloque de error mostraba el fallo y el código inmediatamente mostraba además “Producto cambiado”, ocultando el resultado parcial.

**Corrección de interfaz:** ahora presenta un único aviso por 10 segundos que identifica el pedido, informa que se agregó el producto nuevo y que el anterior continúa, e indica revisar/corregir la orden. El callback de actualización se ejecuta antes del aviso. Un test fuerza la excepción de `eliminarItemPedido` y verifica que no se reporte éxito.

**Riesgo/límite:** las operaciones siguen siendo no atómicas. Una interrupción o error entre llamadas puede dejar ambas líneas; se recomienda evaluar un endpoint Nest que reemplace en una única transacción, considerando permisos, cocina, inventario, precio, Caja e idempotencia. No se modificó backend.

**Evidencia/verificación:** `lib/features/pedidos/presentation/pedido_cajero_screen.dart`, `test/pedido_cajero_screen_test.dart`; POS 12/12, Flutter global 214 aprobadas/5 omitidas/0 fallidas, analyzer focalizado limpio. Launcher recompiló Cliente/Equipo manteniendo Tunnel; homes local/público y health API local/pública HTTP 200. Bundles idénticos local↔público. Sin cambios Nest, OAuth, credenciales ni datos de negocio.

### FIN-SPLIT-OVERCHARGE-01 — split por ítem excedía saldo tras abono (2026-11-24)

**Severidad alta — dinero/caja. Hallazgo reproducido:** `cobrarCuentaMesa()` fijaba el valor de ítems con `SUM(cantidad * precio_unitario)`, omitiendo toppings y bebidas; no comprobaba si el monto seleccionado excedía el saldo pendiente de su pedido. Después de un abono, un split podía cobrar de nuevo el valor bruto de un ítem ya parcialmente cubierto, aceptar una suma mayor al saldo global y registrar el excedente en Caja aunque `monto_pagado` del pedido se limitara al total. La batería anterior `scripts/verificar-pagos-mesa.ps1` reprodujo el éxito indebido al dividir dos tickets tras un abono.

**Corrección:** `PedidosPagosService` ahora calcula el precio de línea con la expresión compartida `SQL_VENTA_LINEA_ITEM` (incluye toppings y bebidas), prorratea el descuento del pedido entre los ítems seleccionados y valida, por cada pedido, que el monto neto seleccionado no supere su saldo. Si lo excede devuelve `ITEMS_EXCEDEN_SALDO` antes de registrar pagos, estados o movimientos de Caja. La distribución, el movimiento de caja y los cambios de saldo permanecen dentro de la transacción existente; no se alteraron permisos, esquema ni reglas de propina.

**Regresión automatizada:** E2E `FIN-SPLIT-01` crea dos tickets, deja un abono de $4.000, intenta dividir ambos y confirma el rechazo; comprueba que la cuenta de movimientos de Caja no aumente, que el ticket que aún conserva saldo admita split y que el restante se pueda cerrar. `scripts/verificar-pagos-mesa.ps1` ahora prueba el ticket con saldo completo. Caja E2E 5/5; suite Nest E2E 8/8 suites, 22/22 pruebas; unitarias 26/26 suites, 57/57; `npm run build` correcto. Batería operativa `scripts/verificar-todos-e2e.ps1`: 9/9 scripts correctos sobre `foody_diseno_qa` y Nest `127.0.0.1:3001` con el build actual. QA limpiada al final; pruebas no tocaron `:3000`, Tunnel, OAuth, credenciales ni datos de negocio.

**Activación pendiente:** el proceso Nest de uso diario `:3000` sigue corriendo con el binario previo para preservar el Tunnel; esta corrección todavía no atiende tráfico de usuario hasta reiniciarlo coordinadamente. El split con combinaciones específicas de extras y descuento no se aisló como caso dedicado, aunque comparte la expresión/precio que el backend ya usa para la cuenta de mesa.

### PED-ITEM-IDEM-01 — reintentos al agregar líneas en POS (2026-11-24)

**Hallazgo:** `POST /pedidos/:id/items` no aceptaba clave idempotente. Si Nest confirmaba el cambio de líneas y la respuesta se perdía, el POS podía reintentar y duplicar líneas, descuentos de inventario y efectos de cocina.

**Corrección:** contrato opcional `idempotency_key`, scoped por pedido; la huella SHA-256 cubre líneas y combos. Resultado y mutaciones se confirman en la misma transacción. Misma clave/mismo payload devuelve el resultado previo sin repetir efectos; misma clave/payload distinto devuelve HTTP 409. POS conserva clave durante errores/reintentos y genera otra al completar operación. Migración `090_pedidos_items_idempotencia.sql` aplicada solo en la BD QA aislada.

**Evidencia:** DTO 2/2; E2E dedicado comprueba primer agregado, replay sin duplicación y conflicto con payload distinto; suite E2E completa posterior 8/8 suites y 25/25 pruebas. Suite Flutter al último resultado 223 aprobadas, 5 omitidas, 0 fallidas; analyzer focalizado limpio; build Nest correcto. La suite unitaria completa está ejecutándose/pendiente de resultado final en esta sesión.

### MES-GROUP-RELEASE-01 — liberar todas las mesas agrupadas

**Hallazgo:** cerrar o cancelar el último ticket liberaba solo la mesa raíz. Mesas secundarias del mismo grupo quedaban `ocupada`/`pagando` sin pedidos activos y podían impedir el cierre de Caja.

**Corrección:** tras resolver la mesa raíz, el servicio bloquea los miembros del grupo en orden estable; busca pedidos activos para todo el conjunto y, si no existen, libera todos los miembros y limpia su asignación de mesero/grupo. Si aún existe un pedido activo, conserva la ocupación.

**Evidencia:** dos unitarias cubren grupo completo libre y grupo con ticket activo; E2E completa aislada 8/8 suites, 25/25 pruebas incluyendo `PED-PREPAGO-01` y cierre de Caja. Nest build correcto. Sin escritura en la BD diaria.

## 2026-11-24 — Activación y verificación del runtime diario

Actualización posterior a los apartados PED-ITEM-IDEM-01 y MES-GROUP-RELEASE-01: la suite unitaria completa Nest finalizó **30/30 suites, 70/70 pruebas**. La migración 090 se aplicó a la BD local principal; crea únicamente `pedidos_items_idempotencia` con RLS forzada, sin alterar filas comerciales. Se reinició Nest desde `dist` para activar código y migración: PID 6860; health local y público HTTP 200. Esto sustituye el estado anterior “activación pendiente”.

Launcher `scripts/iniciar1/iniciar-foody-subdominios.bat`: exit 0, builds Cliente y Equipo completados; los servidores estáticos quedaron arriba. Los seis destinos (Cliente/Equipo local y público + API local/pública) responden HTTP 200. SHA-256 local/público idéntico: Equipo `28fee41e8ced566db8435c1c91490eae9a086ada3effdaad2a9ec596382b8e7b`; Cliente `251de9632142296c7a3f2eb543b4f888acae2df7c4b5fb9b2b79c2f928ce1003`. Cloudflare Tunnel permanece activo (PID 11112). No se modificó OAuth, credenciales, DNS ni configuración del túnel.

QA E2E completa: **8/8 suites, 25/25 pruebas**, en DB dedicada y API temporal :3001; limpieza QA ejecutada y proceso temporal detenido. Flutter global al último resultado: **223 aprobadas, 5 omitidas, 0 fallidas**. Los avisos de compatibilidad Wasm y fuente CupertinoIcons no bloquearon los builds JS. La idempotencia y liberación de mesas están en runtime local diario; falta probar visualmente sesión autenticada contra producción/Tunnel y validar una operación de reintento real sin mutar pedidos comerciales.

### PED-STAFF-IDEM-02 — clave vinculada al contenido del reintento (2026-11-24)

La UI POS conserva la clave ante un error si el payload es el mismo, pero rota la clave si el usuario modifica carrito, mesa, canal, contacto, pago, propina o notas antes de volver a enviar. La huella se calcula sobre los campos operativos enviados y opciones del carrito; no incluye valores puramente visuales. Evita que un reintento modificado reciba como respuesta el pedido anterior o choque con la protección de payload de agregar líneas.

**Verificación:** POS 15/15, incluyendo retry idéntico y retry con carrito modificado; analyzer Flutter focalizado limpio; suite Flutter global **224 aprobadas/5 omitidas/0 fallidas**. Cliente/Equipo release reconstruidos y servidos; los seis endpoints local/públicos continúan HTTP 200. Hash Equipo local/Tunnel `b84b2c98114c0416b3e52f47b744e8a317bfe0a93cecf03fe6a67358fb4f3344`; Cliente `f9749983f2e7650c7931239c8450e379c748295b941f3143d95409190d4f22c3`. Nest PID 6860 y cloudflared PID 11112 activos. No se generó ningún pedido en la BD diaria.

### PED-KEY-SCOPE-01 — aislamiento de claves de creación (2026-11-24)

**Hallazgo alto:** la lectura previa de `pedidos_idempotencia` consultaba por `clave` global y la respuesta incluía ID, número, estado, total y token de seguimiento de la orden ya creada. Una clave reutilizada desde otra sucursal podía revelar el resultado de otro tenant. La tabla también tenía clave primaria global.

**Corrección:** las lecturas y el bloqueo consultan `(sucursal_id, clave)`; la huella SHA-256 del payload canónico impide reutilizar la misma clave con contenido distinto (HTTP 409); el pedido devuelto se vuelve a restringir a la sucursal. La migración `091_pedidos_idempotencia_scope_huella.sql` asigna sucursal a filas históricas desde `pedidos`, cambia la clave primaria a `(sucursal_id, clave)` y habilita/fuerza RLS. Las filas históricas se dejan con huella nula para permitir reintentos ya iniciados antes del despliegue.

**Evidencia y verificación:** antes de migrar, las 164 filas de la BD diaria tenían pedido asociado y ninguna clave repetida; tras la migración, 164/164 tienen sucursal y la nueva PK es compuesta. QA aislada `foody_diseno_qa`: utilitarias Nest 31 suites/72 pruebas; E2E completo 8 suites/26 pruebas, incluidas repetición idempotente, payload distinto y rechazo de reuso entre sucursales; `npm run build` correcto. API QA :3001 detenida y BD QA limpiada. Nest diario reiniciado (PID 11708). API local y pública, Equipo y Cliente local/público responden HTTP 200; preflight CORS del equipo HTTP 204 con `Access-Control-Allow-Origin: https://equipo.foodyy.store`. Cloudflare PID 11112 permanece activo. Sin escrituras en pedidos comerciales, OAuth ni credenciales.

**Consola web:** los errores observados de CORS y mixed content procedían de la pestaña con bundle viejo `28fee41…`; el bundle publicado actual es `b84b2…` y contiene las URLs HTTPS del API y Supabase por túnel. El preflight real confirmó la configuración CORS actual. El aviso FCM fue rechazo de permiso del perfil del navegador; el servicio captura el error y continúa sin token, por lo que no bloquea pedidos. No se cambió el permiso ni OAuth. La captura visual autenticada sigue sin validarse porque la automatización devolvió la ventana de Codex aunque el árbol accesible correspondía a Chrome; recargar la pestaña vieja con Ctrl+F5 permitirá obtener el bundle actual.

**Addendum — arranque comprobado (2026-11-24):** ejecutado `scripts/iniciar1/iniciar-foody-subdominios.bat` con builds vigentes: exit 0; detectó API en :3000, modo `tunel`, conservó cloudflared (PID 11112), reinició Equipo :8080 (PID 3424) y Cliente :8081 (PID 4520). El launcher informó `main.dart.js` cliente de 6.552.311 bytes. Smoke posterior de los seis destinos local/públicos: todos HTTP 200. No necesitó reconstruir porque los builds existían y estaban al día; el camino de build faltante/desactualizado está definido en `servir-web-tunel-release.ps1`, aunque no se forzó una compilación destructiva solo para reproducir ese caso.

### COC-NODISP-COMMERCE-01 — línea no disponible conserva el importe — abierto, alto (2026-11-24)

**Traza verificada:** `PATCH /cocina/items/:id/estado` marca `pedido_items.estado_cocina=no_disponible`, registra alerta/merma y desactiva el producto; al quedar resueltas las otras líneas, recalcula `pedidos.estado=listo`. No ajusta `subtotal`, `descuento`, `total`, `monto_pagado`, pagos ya asignados, factura borrador ni caja. En pedidos para recoger/mesa la ruta permite presentar y cobrar el total que todavía incluye el artículo no servido. Para domicilio, la validación de despacho bloquea el envío si hay ítems no disponibles, pero el pedido sí puede terminar en `listo`.

**Interacción relacionada:** `PedidosItemsService.eliminarItemPedido()` recalcula subtotal/descuento/total e IVA y sincroniza el borrador de factura, pero no actualiza monto ya cobrado ni genera reembolso. El error colateral de restaurar stock al borrar una línea `no_disponible` quedó corregido en `PED-DELETE-NODISP-STOCK-01`; la ruta sigue siendo administrativa y no resuelve sustitución ni compensación económica.

**Evidencia actual:** `foody_backend/src/modulos/cocinas/cocinas.service.ts` (transición, merma/catálogo y cierre); `foody_backend/src/modulos/pedidos/pedidos-items.service.ts` (`eliminarItemPedido`); `foody_backend/src/modulos/pedidos/pedidos-inventario.service.ts` (`registrarMermaLineaProducto` y `restaurarStockLineaProducto`); `foody_backend/test/flujos/cocina.e2e-spec.ts`. E2E cocina aislada 3/3 pasó. El caso N/D verifica que el pedido llegue a `listo` y el despacho se bloquee, pero no compara el valor original con el saldo de caja ni el tratamiento de un abono. La BD QA fue limpiada (1 pedido activo cancelado, 6 jobs de impresión retirados); API temporal :3001 detenida. Ningún pedido comercial fue alterado.

**No se cambia sin decisión comercial/contable:** decidir entre sustitución autorizada por cliente, eliminar/anular la línea con saldo actualizado, o conservar cobro y registrar compensación/devolución; precisar comportamiento para pedido ya pagado/abonado y para línea preparada que se desperdició. Implicaciones: Caja y pagos por ticket, factura/impuestos, inventario/merma, reportes de ventas/utilidad y app cliente. Mientras se define, el despacho de domicilio ya se bloquea, pero el cobro del canal mesa/recogida no tiene conciliación específica.

**Estado de datos:** se registró únicamente evidencia del código y suite QA; no se ejecutó mutación manual sobre datos de negocio. No se inventó una regla para el cobro o reembolso.

## PED-PAY-TRUST-01 / PED-STAFF-CASH-RBAC-01 — confirmar cobros en el servidor (2026-11-25)

### Hallazgo y reproducción

El endpoint público `POST /pedidos` recibía el mismo `CrearPedidoDto` que el POS, incluyendo `pagos[]`. Para un cliente esto permitía declarar un pago que no estaba respaldado por Wompi ni por confirmación del establecimiento. En pedidos `para_llevar`, el método (`efectivo`, `tarjeta` o `nequi`) también se usaba como si fuera un cobro: el servicio podía registrar el movimiento en Caja y marcar `monto_pagado=total`. En QR de mesa `pagos[]` podía actualizar pagos/saldo aunque el estado inicial fuera `pendiente_aprobacion` y por tanto no generaba el correspondiente movimiento de Caja.

En POS, `POST /pedidos/staff` solo exigía `crear_pedido`; la rama de `pagos[]` marcaba saldo pagado sin validar permiso de cobro. Además, un pedido `para_llevar` creado con un único método y propina caía en la rama que solo guardaba `propina_acumulada`, saltándose el movimiento de venta y el abono. La prueba roja E2E en la base clonada reprodujo HTTP 201 al intentar enviar `pagos[]` desde checkout y `monto_pagado=0` para la creación POS con propina.

### Corrección

- `PedidosPublicController.crear()` rechaza `pagos[]` con `PAGO_CLIENTE_NO_CONFIRMADO`; el método seleccionado por cliente queda como preferencia y no dispara caja ni marca recaudo.
- `PedidosController.crearStaff()` rechaza `pagos[]` si el JWT no incluye `cobrar_pedido`. `PedidosService` transporta el permiso al contexto del alta; el servicio solo registra un cobro implícito en la creación staff cuando el operador tiene ese permiso.
- `pagos[]` al crear se limita a `para_llevar` (mostrador/recogida), acorde al contrato documentado del DTO. El cobro POS de un solo método también registra `pagos_pedido`, usuario, propina y movimiento de Caja dentro de la transacción.
- El filtro HTTP preserva mensajes específicos para los dos rechazos de negocio.

### Verificación

Pruebas rojas previas: Checkout público con `pagos[]` recibió 201 (esperado 400); POS `para_llevar` con método efectivo + propina obtuvo `monto_pagado=0` (esperado total). Regresión verde en clon temporal `foody_diseno_qa_codex_public_payment`, Nest `:3001` con `FOODY_QA_SIN_EFECTOS=1`: E2E completo 8/8 suites y 40/40 pruebas; cubre rechazo de pago declarado, cliente con método elegido sin abono/movimiento, mesero sin `cobrar_pedido` sin cobro (y pago explícito 403), pago POS con propina $900, cierre `propinas_turno=900` y diferencia cero. `npm test -- --runInBand`: 51 suites/128 pruebas. `npm run build`: OK. Clon eliminado y QA persistente intacta. No se tocó :3000, Tunnel, OAuth, credenciales ni datos de negocio.

### PED-TIP-REQUEST-01 — Checkout desacoplado del recaudo (corregido; liquidación pendiente)

**Actualización 2026-11-25 — FIN-TIP-CHECKOUT-01:** decisión confirmada por el usuario: en Colombia la propina es voluntaria, no se agrega al total de productos y se mantiene separada; el monto digitado antes de crear un pedido era solo una sugerencia y no debía conservarse. Checkout retiró el campo previo a la creación y muestra una nota informativa; el repositorio cliente ya no envía `propina`. En Nest, para mantener compatibilidad con versiones anteriores, el pedido público ignora `dto.propina`; creación staff sigue guardando propina solo cuando acompaña un cobro confirmado. E2E QA envió deliberadamente `propina=2500` desde cliente: 2 pedidos sintéticos terminaron con `propina_acumulada=0`, `monto_pagado=0` y sin filas en `pagos_pedido`; cobros reales siguen guardando `pagos_pedido.propina` por separado de `movimientos_caja` y del total de venta. No se hizo migración ni se reescribieron pedidos históricos, porque `propina_acumulada` no permite distinguir solicitud antigua de propina ya cobrada. Queda pendiente definir beneficiario/reparto/liquidación, manejo cuando se entrega directamente a un domiciliario y la visualización del detalle de propinas reales.

### PED-DELETE-NODISP-STOCK-01 — no reponer stock de una línea con merma — ✅ corregido (2026-11-24)

**Hallazgo reproducido:** `eliminarItemPedido()` clasificaba `no_disponible` como línea “no en cocina” y llamaba `restaurarStockLineaProducto()`. Sin embargo, la transición a N/D ya había registrado la merma en el ledger. Borrar la línea podía devolver al inventario ingredientes de una preparación fallida/no servida como si fueran aprovechables.

**Corrección:** la eliminación conserva la restauración para líneas aún pendientes; las líneas `preparando`/`listo` continúan por la rama de merma; las líneas `no_disponible` ya mermeadas no generan una segunda merma ni una restauración. No cambia el total, caja ni pagos; la línea sigue recalculando subtotal, descuento, IVA y borrador de factura según la ruta existente.

**Verificación:** E2E nueva crea pedido con dos líneas, toma stock tras el alta, marca una línea N/D, la elimina y comprueba que el inventario no aumente y que el total/bloque de líneas se recalcule: `COC-NODISP-DELETE-STOCK-01`. Cocina E2E 4/4; Jest completo 8/8 suites, 27/27; unitarias 31/31 suites, 72/72; `npm run build` OK. Batería integrada `scripts/verificar-todos-e2e.ps1`: 9/9 scripts OK. Flutter relacionado: 50 pruebas OK (`pedido_detalle_sheet`, POS, Kanban, mesa, KDS). QA limpia: 0 pedidos activos al cierre, 4 jobs de impresión retirados; API :3001 y agente temporal :8765 detenidos. Nest diario y Tunnel permanecen activos.

**Límite:** esto no resuelve `COC-NODISP-COMMERCE-01`; si hubo abono/pago, remover la línea aún requiere una política de reembolso/compensación y reconciliación de caja/factura.

**Activación posterior a PED-DELETE-NODISP-STOCK-01 (2026-11-24):** se reinició solo Nest diario para cargar el build corregido (PID 8284). API `:3000`, Cliente `:8081`, Equipo `:8080`, sus tres hostnames públicos y CORS preflight de Equipo: HTTP 200/204 con origen exacto. Cloudflare Tunnel sigue PID 11112. QA `:3001` y agente de impresión `:8765` están abajo; base QA sin pedidos activos y jobs temporales limpiados. No se tocaron OAuth, credenciales, rutas de túnel ni datos comerciales.

### Aviso operativo mientras se decide la conciliación (2026-11-24)

En el panel administrativo, el detalle del pedido y el flujo de cobro de mesa muestran ahora una advertencia cuando hay unidades `no_disponible`: siguen incluidas en el total y el equipo debe confirmar el ajuste con el cliente antes de cobrar. En cobro por ítems, el aviso cuenta solo las líneas seleccionadas; en cuenta total, cuenta las unidades afectadas. Es visual y accesible; no cambia precios, saldo, pagos, facturas, inventario ni transiciones. La decisión contable/comercial continúa abierta en COC-NODISP-COMMERCE-01.

**Verificación:** pruebas Flutter de detalle y mesa pasan 13/13 en móvil, tablet y escritorio; analyzer focalizado sin issues. El launcher `scripts/iniciar1/iniciar-foody-subdominios.bat rebuild` terminó con exit 0; Cliente y Equipo se compilaron y sirvieron en :8081/:8080. API, dos frontends locales y los tres hostnames públicos respondieron HTTP 200. SHA-256 JS: Equipo `396f6d68ad71763ef74a474e27a2d3712b91e73fba742fb4957e3e2054db319e`, Cliente `f8c08e7c6ad82fd93b9189710e5059d3a2c4885658e0738e464abab42af23f02`. Cloudflared continúa PID 11112. No se ejecutaron cobros ni se alteraron datos de negocio; OAuth y credenciales no se modificaron.
### PED-ENCARGO-QUOTE-DATE-01 — cotización antes de elegir fecha (2026-11-24)

**Hallazgo:** el checkout solicita una fecha para confirmar un encargo, pero al entrar a la pantalla cotiza automáticamente vía `POST /pedidos/estimar` sin incluir `fecha_entrega_deseada`. `PedidosCrearService` aplicaba la validación de fecha antes de distinguir la estimación de la creación, por lo que una cotización normal de encargo fallaba y Flutter mostraba el total local aproximado como “Total estimado”.

**Corrección:** se omite la exigencia de fecha únicamente para estimaciones sin fecha. Si la cotización trae una fecha, esta se valida; la creación real sigue exigiendo fecha y anticipación mínima en Nest. Checkout conserva su validación antes de enviar.

**Evidencia:** unitarias de `pedidos-crear-mesa-requerida.spec.ts` 5/5 pasan, incluyendo estimación sin fecha y rechazo de creación sin fecha. No se ejecutó flujo E2E autenticado ni se activó el cambio en la API diaria; requiere QA runtime para confirmar precio autoritativo de encargo.


### PED-CLIENT-CANCEL-RACE-01 — cancelación concurrente con aceptación por el restaurante (2026-11-24)

**Hallazgo reproducible por inspección de concurrencia:** cancelar por cliente primero lee `estado` por `(pedido_id, device_id)` y valida que aún pueda cancelar; luego inicia otra transacción para cambiar estado. Si el restaurante mueve el pedido a `en_cocina` entre esas operaciones, la segunda ruta podía cancelar porque omitía el contexto/rol del cliente al aplicar la transición. La fila sí se bloquea con `FOR UPDATE`, pero la restricción original no se repetía bajo ese bloqueo.

**Corrección:** `cancelarPorCliente()` ahora pasa contexto `rol: cliente` a la transición. Dentro de la transacción, la validación vuelve a evaluar estado/antigüedad del registro bloqueado; un pedido ya en cocina se rechaza sin mutar caja, inventario, historial o asignaciones.

**Verificación:** regresión unitaria `pedidos-cancelacion-cliente-race.spec.ts` pasa 1/1: prelectura pendiente, lectura bloqueada `en_cocina` y rechazo antes de escribir. Build backend aún pendiente en esta actualización; API diaria no se reinició.

**Verificación ampliada PED-CLIENT-CANCEL-RACE-01 (2026-11-24):** la validación bloqueada usa `validarCancelacionCliente`, no la regla genérica para personal, conservando el comportamiento anterior: pendiente no tiene límite temporal del cliente; `confirmado` sí exige ≤2 minutos; `en_cocina` y estados posteriores se rechazan. Después del ajuste: Jest Nest completo 34/34 suites, 79/79 pruebas; `npm run build` OK; regresión race + encargo 6/6. El cambio permanece en fuente/build, sin reiniciar API diaria.

**Verificación final de esta pasada (2026-11-24):** al añadir la regresión de compatibilidad del límite temporal, Jest Nest completo queda en 34/34 suites y 80/80 pruebas; build y Prettier focalizado pasan. Smoke read-only posterior: API salud local/pública, Cliente y Equipo local/públicos responden HTTP 200. El atajo `scripts/iniciar1/iniciar-foody-subdominios.bat` es un wrapper al lanzador principal; hoy existen ambos `build/web_cliente/index.html` y `build/web_equipo/index.html`. No ejecuté reinicio (los seis destinos están sirviendo y el Tunnel debe conservarse); la fuente recién compilada no queda activa en :3000 hasta activación coordinada.

### POS-COTIZACION-CASH-GUARD-01 — no cobrar sobre una cotización local aproximada (2026-11-24)

**Hallazgo confirmado:** en POS para llevar, si `POST /pedidos/estimar` falla, la UI mantiene un total local aproximado pero permite confirmar. La creación recalcula el precio en Nest y, para efectivo/tarjeta/transferencia/Nequi, registra ese valor autoritativo en Caja en la misma transacción. Si el cajero recibió el aproximado local, dinero recibido y movimiento de caja podían diferir.

**Corrección:** el POS ahora bloquea el botón y guarda adicionalmente la regla en `_confirmarPedido()` cuando es una nueva venta para llevar con cobro inmediato y no existe cotización actual del servidor. La pantalla muestra reintento de cotización; al obtener total real permite continuar. No aplica a mesa, modo mesero, pago diferido ni agregar productos a un pedido existente. Nest sigue siendo la fuente del precio y no cambió su regla.

**Verificación:** `pedido_cajero_screen_test.dart` 16/16; analyzer focalizado sin issues. Build web release Equipo en `build/qa_pos_quote_20261124` exitoso; advertencias Wasm por dependencias existentes y aviso CupertinoIcons sin impedir build. No se sirvió el artefacto ni se reinició API/Tunnel; requiere publicación posterior cuando termine la oleada.

### DOMI-LIQUIDACION-METODO-EXTERNO-01 — método de cobro no conciliado en liquidación (2026-11-24)

**Evidencia:** migración `foody_supabase/migrations/065_fiado_domiciliario.sql` describe el dinero cobrado por el domiciliario como efectivo “en la calle” que entra a caja al liquidar. `confirmar-entrega.dto.ts` solo permite `metodo_pago = pendiente_liquidacion` para esta modalidad; no captura el método real recibido del cliente. En `DomiciliariosService.confirmarEntrega()`, al dejar a cuenta se crea CxC por el producto, o por el saldo completo si el domicilio entra a caja. Al liquidar, `liquidarDomiciliario()` registra en `pagos_pedido` y Caja el monto de CxC como efectivo. El hallazgo de 2026-11-24 observó que el scalar del pedido se sobrescribía a efectivo; esto quedó corregido luego por DOMI-PAY-LEGACY-METHOD-01: ahora `monto_pagado=total` y `metodo_pago` se reconstruye desde el primer pago cronológico del pedido+sucursal (fallback efectivo).

**Impacto comprobable:** con `domicilio_ingresa_a_caja=false`, el domicilio es ingreso del domiciliario y no forma parte de lo que rinde al restaurante. La venta de caja puede cuadrar porque la cuenta liquida solo el producto; no obstante, el libro `pagos_pedido` no conserva en esta ruta el medio por el que el cliente pagó el domicilio fuera de caja. El scalar actual conserva el primer medio cronológico, por lo que tampoco representa por sí solo pagos mixtos; consultar `pagos_resumen` para importes registrados. La interfaz de reportes/analítica de caja deriva importes de `movimientos_caja`; por eso no se debe sumar nuevamente el valor externo como ingreso del restaurante.

**Decisión pendiente DOMI-OFF-CAJA-TRACKING-01:** definir si `pagos_pedido` representa todos los pagos del cliente (incluidos los $5.000 que conserva el domiciliario) o solo recaudos/liquidaciones de Foody, y dónde registrar el método real del componente externo cuando se confirma `pendiente_liquidacion`. El E2E ahora cubre abono $2.000 transferencia, CxC de producto $6.000 liquidada en efectivo y repetición sin duplicación. No se modificaron reglas monetarias ni histórico porque inferir medio/destinatario sería una decisión contable. El componente fuera de Caja está asociado al pedido/asignación, pero no aparece como pago registrado; no sumarlo al recaudo de la sucursal sin resolver la decisión.

### PED-POS-REPLACE-ATOMIC-01 — reemplazo de ítem en una transacción (2026-11-24)

**Hallazgo confirmado:** POS agregaba el producto nuevo con `POST /pedidos/:id/items` y después borraba el anterior con `DELETE /pedidos/:id/items/:itemId`. Cada endpoint tenía su propia transacción; una falla de red/stock/merma en el segundo dejaba ambos productos. El aviso parcial mitigaba el falso éxito, pero no la inconsistencia operativa.

**Corrección:** el endpoint `POST /pedidos/:id/items/:itemId/reemplazar` bloquea el pedido, ejecuta los flujos existentes de alta y eliminación usando el mismo `PoolClient` y publica realtime solo después del commit. El request guarda resultado y huella compuesta en `pedidos_items_idempotencia`; un reintento idéntico devuelve el resultado, y reutilizar clave con otro reemplazo genera conflicto. Si la línea original figura cobrada o está asignada en `pago_pedido_items`, rechaza antes de mutar con `ITEM_REQUIERE_AJUSTE_COBRO`; si el nuevo total cae por debajo del monto abonado, revierte todo con `REEMPLAZO_REQUIERE_REEMBOLSO`. La política de reembolso no se infiere. Flutter envía una sola petición y conserva la clave al reintentar.

**Alcance funcional preservado:** sigue usando validaciones Nest de catálogo/stock, precio, cocina, costo, promoción, IVA, borrador de factura, merma/restauración, límites de pedido, sucursal y permiso `crear_pedido`; la eliminación impide dejar el pedido sin líneas. No toca OAuth, Tunnel ni datos existentes. Reemplazo de línea que ya se preparó conserva la política existente de alerta/merma.

**Verificación:** endpoint/repository y UI cubiertos; pruebas de orquestación comprueban mismo cliente transaccional, clave idempotente, replay sin mutaciones, bloqueo de una línea cobrada, reversión financiera necesaria y propagación de fallo sin publicar éxito. Regresión POS confirma una llamada. Nest completo 37/37 suites y 92/92 pruebas; Flutter completo 237 aprobadas y 5 E2E omitidas por exigir BD aislada; POS+repo 20/20; analyzer focalizado limpio. Build web release `build/qa_replace_atomic_20261124` exitoso. Warnings no bloqueantes: dry-run Wasm por dependencias heredadas (`dart:html`, `dart:js_util`) y fuente de iconos CupertinoIcons ausente. Build actualiza `foody_backend/dist`, pero API :3000/Tunnel no se reiniciaron; la corrección backend sigue sin activar en runtime.

### COC-KDS-NULL-STATE-01 — un estado de cocina nulo podía parecer resuelto (2026-11-24)

**Hallazgo confirmado por inspección de esquema y SQL:** `pedido_items.estado_cocina` tiene `DEFAULT 'pendiente'` pero no `NOT NULL` en `foody_supabase/migrations/005_pedidos.sql`. En PostgreSQL, `NULL NOT IN ('listo','no_disponible')` no es verdadero. Por ello, `pedidoCocinaCompleta()` podía contar una línea nula como resuelta y dejar que caja cerrara el pedido completo; además, las consultas KDS de órdenes ya pagadas y el recálculo de pendientes omitían tal línea.

**Corrección en fuente:** la validación de cierre cuenta `NULL` como incompleto; el cálculo de cocina lo mantiene pendiente, y la consulta de KDS conserva órdenes pagadas con líneas de estado nulo sin resolver. No cambia importes, inventario, permisos ni estados válidos. No se impuso restricción NOT NULL ni se migraron datos existentes.

**Verificación:** regresión unitaria nueva cubre incompleto nulo/desconocido, líneas resueltas y pedido vacío. Ejecución de pruebas/build y publicación de runtime pendientes en esta actualización.

**Verificación ampliada COC-KDS-NULL-STATE-01 (2026-11-24):** la regresión y prueba readonly KDS pasan 4/4; suite Nest completa 35/35 suites, 83/83 pruebas; `npm run build` y Prettier focalizado pasan. El build actualiza `foody_backend/dist`; no reinicié API :3000 ni Tunnel, de modo que el runtime todavía no tiene esta corrección.

### PED-DISCOUNT-READY-CLOSE-01 y FIN-DISCOUNT-REFUND-METHOD-01 (2026-11-24)

**Hallazgo PED confirmado:** `PedidosDescuentoService.aplicarDescuento()` recalculaba el total y reducía `monto_pagado`, pero devolvía el estado previo. Si un pedido de salón `listo`/`pagando` tenía abonos que cubrían el nuevo total, podía permanecer abierto pese a cocina completa y saldo cero. El usuario podía ver una cuenta ya cubierta como todavía pendiente, y el cierre/liberación de mesa no seguía el flujo terminal.

**Corrección:** cuando el descuento cubre el saldo y el pedido no domiciliario está `listo` o `pagando`, se delega el cambio a `PedidosEstadoCommandService` (`cobro → pagado`), que vuelve a validar cocina completa y registra historial en la misma transacción. Un pedido aún `en_cocina` no se adelanta; un domicilio `listo` permanece listo para despacho. El movimiento de devolución se conserva.

**FIN-DISCOUNT-REFUND-METHOD-01 — decisión contable pendiente:** si al reducir el total el negocio ya recibió más dinero del nuevo total, el descuento registra un movimiento `devolucion` con `metodo_pago = NULL` (`pedidos-descuento.service.ts`). Reportes y analítica agrupan los movimientos por método y convierten NULL en `sin_metodo`. Esto hace visible el egreso, pero no identifica el medio real usado para devolver el dinero ni distribuye el reembolso entre los medios originales. Antes de corregirlo hay que decidir si se devuelve por medios originales (incluido pago mixto), efectivo elegido por caja, o si la operación debe exigir selección del medio real; también precisar el tratamiento cuando el método de reembolso difiere del cobro. No se deben cambiar cifras históricas por inferencia.

**Verificación:** suite Nest completa 36/36 suites, 86/86 pruebas; build y Prettier focalizado OK. La prueba cubre el cierre de salón, conservación de `en_cocina` y despacho domicilio. La API diaria y el Tunnel no se reiniciaron; la fuente compilada aún no está activa en runtime.

**Extensión de PED-DISCOUNT-READY-CLOSE-01:** el cierre también ejecuta `liberarMesaSiSinPedidosActivos()` dentro de la misma transacción y publica actualización de mesa por realtime cuando el pedido pagado pertenece a una mesa. Si quedan otros pedidos activos en la mesa/grupo, la liberación los respeta.
**Verificación final:** suite Nest 36/36 suites, 86/86 pruebas; build y Prettier OK. Regresión confirma transición, devolución, liberación de mesa, notificación, conservación del flujo de cocina y continuidad del despacho domicilio. Runtime :3000/Tunnel no reiniciados.

**KDS — compatibilidad visual con datos legados:** se comprobó en `kds_screen.dart` que NULL/desconocido se normaliza visualmente a `pendiente`, queda en la columna Cocina y ofrece “Marcar listo”. Nueva regresión en `test/kds_screen_test.dart`; suite KDS responsive y acciones 14/14 en 320/390/820/1440 px. La sesión Chrome disponible está en `/admin/login`; no se automatizó ni solicitó autenticación, así que la inspección visual autenticada por rol sigue pendiente.

### PUSH-PERM-STATUS-01 — Firebase web compara el tipo de permiso incorrecto (2026-11-24)

`FirebaseMessaging.requestPermission()` devuelve `NotificationSettings`; la lógica de `_getToken()` comparaba ese objeto directamente con el enum `AuthorizationStatus`. Por tanto, incluso una respuesta autorizada se evaluaba como distinta y la app podía tratarla como denegada, omitir el token FCM y no registrar el canal web.

**Corrección:** comparar `permission.authorizationStatus` con `authorized` y `provisional`. No se llamó `requestPermission`, no se alteró la preferencia de navegador ni se tocó OAuth/credenciales.

**Verificación:** análisis Dart focalizado sin errores/warnings (permanece un info preexistente por import redundante). La suite Flutter completa pasó 236/236 pruebas no omitidas y 5 E2E omitidas por requerir DB aislada. El análisis global reporta un warning heredado (`Horario._convertirDiaSemana` sin uso) y 35 infos; no se modificó el helper legacy.

**Runtime/Tunnel smoke read-only (2026-11-24):** Cliente local/público, Equipo local/público y `/api/v1/salud` local/público respondieron HTTP 200 (6/6). Esto confirma disponibilidad en esta observación, no la activación de las correcciones compiladas ni estabilidad bajo carga. No se reiniciaron API, webs ni Tunnel.

### DOMI-TOTAL-ENTREGAS-ACCEPT-01 — aceptación contaba como entrega (2026-11-24)

**Hallazgo confirmado:** `responderOferta()` incrementaba `domiciliarios_independientes.total_entregas` al asignar una oferta, antes de que el pedido saliera a ruta o se entregara. La cancelación posterior no revertía el contador, por lo que estadísticas de Super Admin podían inflar las entregas reales.

**Corrección:** el incremento ahora ocurre en `confirmarEntrega()` después de validar que la asignación está `en_camino`, al registrar la asignación como `entregado`, dentro de la misma transacción. Reintentos no duplican porque la segunda llamada ya no encuentra una asignación `en_camino`. Una cancelación antes de entrega no aumenta el contador. No se recalcularon datos históricos.

**Verificación:** regresiones verifican que aceptación no ejecuta el incremento y entrega sí; domiciliarios focused 4/4; suite Nest 36/36 suites, 87/87 pruebas; build y Prettier focalizado OK. API/Tunnel no reiniciados; cambio no activo en runtime.

**Decisión separada DOM-CANCEL-PAYOUT-01:** el registro de comisión/ganancia independiente se crea al aceptar la oferta y puede quedar en historial si se cancela. El panel lo presenta como estimado y el código revisado no ofrece una liquidación de independientes. Falta decidir si aceptación genera comisión/obligación, si se revierte por cancelación y quién paga; no modificar montos/liquidación hasta definirlo.

### PED-CANCEL-REFUND-SEMANTICS-01 — reversa contable frente a reembolso externo (2026-11-24)

El cliente solo puede cancelar antes de cocina; un pedido `confirmado` tiene una ventana de dos minutos. El personal elevado sí puede cancelar en etapas posteriores, incluso `pagado`. En ese caso `PedidosEstadoService` registra la reversa en `movimientos_caja` por caja y método de origen, pone `pedidos.monto_pagado` en cero y continúa liberando mesa/asignación. No se encontró llamada a un proveedor de pago para reintegrar dinero de un pedido; la integración Wompi revisada procesa suscripciones. Por ello la reversa de Caja no debe comunicarse como reembolso ejecutado al cliente.

**Corrección UX PED-CANCEL-COPY-01:** el diálogo Kanban ahora distingue reversa contable de reembolso confirmado por el proveedor. No cambia los movimientos financieros. Verificación focalizada: widget Kanban 11/11, reversa Caja 3/3 y analyzer del widget sin issues.

**Decisión pendiente:** definir quién ejecuta y registra el reembolso externo de un pedido pagado, qué evidencia/estado conserva y cómo se evita duplicar una reversa manual en Caja. Hasta definirlo, cancelar un pedido pagado puede dejar el saldo interno en cero sin demostrar que el cliente recibió el dinero. No se probaron pagos ni se modificaron pedidos reales.

### PED-CANCEL-RBAC-01 — permiso de cancelación no alineado (2026-11-24)

La ruta `PATCH /pedidos/:id/estado` pide `crear_pedido` para todos los cambios, incluida la cancelación. `PedidosEstadoService` llama `validarCancelacion()` pero este recibe `_permisos` y no lo usa: la autorización especial se basa en rol (admin/gerente), etapa y límite temporal. En la migración 002, `cancelar_pedido` está asignado a admin/gerente y en Flutter aparece como permiso editable; una búsqueda del repo no encontró su uso efectivo en guard/controller/service. El detalle mostraba la acción a usuarios sin `crear_pedido`, que luego recibían rechazo del backend.

**Corrección UX:** tarjetas y detalle solo muestran las transiciones que habilitan los permisos exigidos por su endpoint (`crear_pedido` para cambios de estado; `aprobar_pedido_mesa` para confirmar/rechazar QR). Cancelar se oculta sin `crear_pedido` y replica las reglas backend para perfiles no elevados (estado bloqueado o más de 2 min). Tests responsive cubren 320, 390, 820 y 1440 px; Kanban prueba perfiles solo lectura y cajero con pedido antiguo. No se alteró autorización API.

**Decisión pendiente:** precisar si `cancelar_pedido` habilita cualquier cancelación, solo excepciones a ventana/etapa, o si es un permiso heredado a retirar. También aclarar el rol Mesero: la lógica permite cancelación temprana y los mensajes del servicio lo sugieren, aunque los permisos base 002 no asignan `cancelar_pedido`. No ajustar roles hasta cerrar esta matriz.

### COC-DISPATCH-INCOMPLETE-01 — pedido marcado listo con líneas sin resolver (2026-11-24)

**Hallazgo:** la ruta general de estados admite que un pedido `en_cocina` pase a `listo` manualmente, aun si algunas filas de Cocina siguen `pendiente`, `preparando` o `NULL`. El gate previo de despacho exigía tipo domicilio, estado listo, al menos una línea y ausencia de `no_disponible`; por eso permitía asignar un pedido incompleto marcado listo fuera del KDS.

**Corrección backend:** `DispatchService.validarPedidoParaDespacho()` también detecta cualquier línea que no esté en `listo` ni `no_disponible`. `no_disponible` mantiene su bloqueo separado para revisar total; `NULL`, `pendiente` y `preparando` dan `PEDIDO_COCINA_INCOMPLETA`. Como despacho automático, asignación de planta, creación de ofertas y aceptación independiente comparten el gate y revalidan con la fila del pedido bloqueada, la misma precondición cubre las cuatro rutas. Cocina también bloquea la fila de pedido al modificar el estado de una línea, serializando esa decisión con el despacho.

**Corrección UX:** para pedidos `listo` con líneas no resueltas, el detalle Kanban explica qué corregir y no enseña los controles de asignación. Domicilios ya asignados/en camino conservan la opción de reasignar.

**Verificación:** Nest completo 37 suites/93 pruebas, build OK; Flutter detalle/Kanban 16/16, analyzer de cambios limpio. No se ejecutó E2E sobre PostgreSQL en este corte. El binario del proceso API `:3000` no se reinició; el source/dist está corregido, pero no se puede afirmar que el Tunnel ya sirva este guard. Falta activar coordinadamente y probar cada puerta de despacho contra BD QA aislada.

#### Addendum — estado global `listo` también se valida (2026-11-24)

**Hallazgo adicional:** el gate de despacho impedía asignar un domicilio incompleto, pero el comando central todavía permitía que Kanban escribiera `pedidos.estado='listo'` cuando quedaban ítems pendientes, preparando, NULL o cuando no había ítems. El despacho quedaba protegido, pero el estado global era falso para panel, cocina, métricas y otros consumidores.

**Corrección:** `PedidosEstadoCommandService.aplicarEstadoEnTransaccion()` ahora llama `pedidoCocinaCompleta()` antes de cualquier transición a `listo`, tanto desde Kanban como desde el cambio automático de Cocina. La consulta exige al menos una línea y solo considera resueltos `listo`/`no_disponible`. Si no cumple, responde `COCINA_INCOMPLETA_PARA_LISTO` antes de actualizar el pedido o insertar historial. No se habilita un override administrativo; el único override existente continúa limitado a cierre cobrado `pagado` con rol/motivo, y no convierte el pedido en listo.

**Contrato de UI:** `mensajeErrorHttp()` ya extrae el campo `message` de respuestas Nest; se agregó una regresión que verifica que el usuario reciba la instrucción de volver a Cocina sin exponer el código interno.

**Verificación:** Jest completo 38 suites/96 pruebas; build Nest OK; Flutter `test/mensaje_error_http_test.dart` 2/2. El barrido de escrituras encuentra un solo `UPDATE pedidos SET estado`, en el comando central. No se ejecutó E2E PostgreSQL ni se reinició la API `:3000`; `dist` está actualizado pero el cambio requiere activación coordinada y verificación de extremo a extremo antes de declararlo activo.

### PED-EDIT-01 — edición de preparación y saldo de pedido (2026-11-24)

**Hallazgos:** al cambiar cantidad/toppings, la línea se reiniciaba a `pendiente` pero el pedido podía seguir en `listo` o `pagando`; un cambio real de observaciones no reiniciaba el estado de Cocina. Además, los endpoints directos de edición/eliminación recalculaban el total sin comprobar si ya se había recibido un monto mayor. El reemplazo transaccional sí tenía esa barrera, así que los canales podían terminar con resultados financieros distintos.

**Corrección:** las operaciones de agregar/editar usan `volverACocinaSiEsNecesario()` para transitar `listo`/`pagando` a `en_cocina` por el comando central, con historial y notificación en transacción. Una edición de observaciones solo reinicia Cocina si el valor realmente cambia. Editar o eliminar bloquea una reducción del total que dejaría `monto_pagado` por encima; no ejecuta reembolso. El endpoint de reemplazo conserva su código/mensaje específico y su validación final, sin pasar por el guard duplicado.

**Verificación:** Jest completo 39 suites/101 pruebas, incluidas transiciones desde `listo` y `pagando`, persistencia del estado final notificado, reducción con y sin sobrepago, y regresión del reemplazo; build Nest OK. No E2E PostgreSQL y no reinicio de `:3000`; requiere activación y escenarios integrados de edición, borrado, abono y devolución en DB QA aislada.

### Addendum — aislamiento para E2E en API de QA (2026-11-24)

La base Docker `foody_diseno_qa` está saludable en `127.0.0.1:55494`; una consulta de solo lectura encontró 0 fuentes Wompi activas y 0 renovaciones candidatas. Intenté arrancar Nest en `127.0.0.1:3001` con `DATABASE_URL` de esa base, claves Wompi vacías, Supabase/Realtime/Storage vacíos y modo de impresión `archivo`. El API enlazó correctamente a QA y nunca tocó `:3000`, pero `FcmService` inicializó Firebase Admin desde la ruta configurada por el entorno del repositorio, pese a que el proceso se lanzó con las variables de Firebase vacías. Detuve inmediatamente el proceso antes de ejecutar E2E; no se dispararon pagos ni se modificaron datos de negocio. Verifiqué después API local `:3000` y pública `api.foodyy.store` con HTTP 200, y `:3001` sin listener.

**Bloqueo E2E seguro:** no volver a levantar la aplicación completa hasta tener una forma comprobable de anular FCM y los demás workers de entorno (suscripciones, notificaciones, impresión, despacho, promociones, reservas y QR). Su inicialización puede leer `.env` y ejecutar efectos laterales contra servicios externos o cambiar datos QA. La base sigue aislada, pero ejecutar solamente con `DATABASE_URL` distinto no es una barrera suficiente. Los cambios PED-EDIT-01 y COC-DISPATCH-INCOMPLETE-01 permanecen validados por Jest/build, no por integración PostgreSQL; no se deben declarar activos en el runtime del túnel por los checks de salud.

### Cierre E2E PostgreSQL y QA aislada (2026-11-24)

El bloqueo descrito en `QA-E2E-ISOLATION-01` se resolvió con `FOODY_QA_SIN_EFECTOS=1`, opt-in sin efecto en operación normal. El modo omite acceso a credenciales Firebase/Supabase/Storage; desactiva crons de suscripción/notificaciones/QR/promociones/reservas/Cocina, cola automática de impresión y disparo/expiración automática de despacho. Los endpoints operativos siguen disponibles en la API QA; despacho automático queda cubierto con unitarias.

**Evidencia:** `npm run build` OK; Nest unitario **40 suites/102 pruebas**; Jest/Supertest PostgreSQL **8 suites/32 pruebas**; `scripts/verificar-todos-e2e.ps1` **9/9 scripts**. Se añadieron casos de pedido Cocina incompleta (400 sin cambiar estado), cambio de observaciones tras `listo` (estado vuelve a `en_cocina`, línea `pendiente`) y reducción bajo abono (409, transacción conserva cantidad 2, total 16.000 y abono 9.000). Se ajustaron los fixtures antiguos para completar las líneas antes de declarar `listo`; la prueba de reversa mixta opera con abono mientras `pagando`, porque cancelar `pagado` está prohibido por la máquina de estados. El script funcional de impresión usó agente en modo archivo y este se detuvo al terminar.

La base usada fue únicamente `foody_diseno_qa`; Wompi tenía cero fuentes activas/candidatas al iniciar. No se cambió política de pagos, usuarios, OAuth, credenciales o base de negocio. QA `:3001` quedó detenida. Cliente, Equipo y salud API local/público quedaron 6/6 HTTP 200. `:3000` no se reinició: las fuentes y `dist` están corregidos, pero la instancia del Tunnel sigue en el binario previo hasta su activación coordinada.

#### Addendum — bloqueo de integraciones externas (2026-11-24)

La auditoría del aislamiento encontró tres integraciones invocables por endpoint además de los cron: Google mediante Supabase Auth, Wompi y geocodificación Photon. Con `FOODY_QA_SIN_EFECTOS=1`, `SupabaseAuthService` no lee URL/llave ni construye cliente, Wompi rechaza antes de `fetch` aun si las claves están en `.env`, y Geografía falla cerrado sin consultar Photon. Unitarias de contrato cubren Wompi/Auth; build OK; **42/104 unitarias**, **8/32 E2E PostgreSQL**, **9/9 scripts funcionales**. Los destinos locales y públicos del Tunnel verificaron 6/6 HTTP 200 al finalizar; :3000 no se reinició.


### COC-NODISP-CUSTOMER-01 — informar al cliente (2026-11-25)

`PedidosService.obtenerEstadoPublico()` solo devolvía estado general, total e historial. Cuando Cocina marcaba una línea `no_disponible`, el cliente podía ver el pedido como `listo` sin saber qué producto no se iba a servir; en domicilio, además, el despacho quedaba bloqueado. El detalle interno ya advertía al personal que el importe seguía incluyendo la línea, pero ese dato no llegaba a Seguimiento.

Nest devuelve los nombres y cantidades no disponibles dentro de la consulta ya autorizada por token/capability; Flutter informa el faltante y que el total aún no se ha ajustado. Evidencia original: E2E Cocina token válido→línea/cantidad, Nest build + 50 suites/127 pruebas, Flutter aviso 5/5 responsive y analyzer focalizado limpio. Revalidación 2026-11-25: `cocina.e2e-spec.ts` 7/7 en Nest temporal :3001 + `foody_diseno_qa`; incluye el pedido end-to-end, GET por token y rechazo de despacho. Se limpió el fixture y se cerró QA. API :3000 PID 10208 registró la ruta (GET de ID inexistente responde error de dominio `NO_ENCONTRADO`); no se mutó dinero ni datos comerciales. La decisión de sustitución/eliminación/reembolso permanece en COC-NODISP-COMMERCE-01.
# Regresión E2E integrada — fixture RBAC resuelto — 2026-11-25

La primera ejecución identificó la colisión entre la identidad operativa de cajero y el perfil read-only que exige la prueba RBAC. Se corrigió el E2E para usar `cajero.sololectura.test@foody.demo` y el launcher protegido ahora restaura idempotentemente en el clon los grants fuente de todas las migraciones, retira overrides solo de Admin/cajero operativo en ese clon y genera el usuario read-only con permiso único `ver_caja`. El runner exige `FOODY_QA_DATABASE=foody_diseno_qa_codex_*`; rechaza correr esta preparación en el QA base. Verificación integral: **10/10 suites, 51/51 pruebas**. Se eliminó el clon y se detuvo Nest QA. Auditoría read-only posterior: QA fuente conserva 1.274 pedidos, 76 grants y 0 cuentas read-only sintéticas; faltaban cuatro grants de 094, no toda la matriz. `:3000` PID 7584 intacto; permisos comerciales sin cambios.

## Inspección operativa en Tunnel — cola visible (2026-11-25 23:21 COT)

Recorrido visual read-only en Equipo autenticado por Tunnel: Pedidos muestra 9 abiertos por $1.381.400; el filtro `Cobro / Ruta` muestra 8. Visibles: `#FDY-2026-0015` y `#FDY-2026-0014` para llevar, `Pagando`, edad 2947 h 55 min; `#FDY-2026-0016` domicilio, `En camino`, edad 2732 h 57 min y destino «Por confirmar». La vista marca antigüedad roja; los estados permanecen operables. No se inspeccionó ni ejecutó la acción «Entregado», no se infiere que el saldo mostrado sea deuda real y no se corrigieron/limpiaron filas. Hasta clasificar origen con historial, no reencolar ni cerrar estos registros. En ~500 px los chips de canales y estados se desplazan en horizontal con `FoodyScrollHorizontalFade`; el chip siguiente queda cortado, por lo que conviene hacer más perceptible el affordance.
