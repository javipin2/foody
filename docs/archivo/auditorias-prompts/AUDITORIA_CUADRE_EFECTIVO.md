# Auditoría y corrección del arqueo de efectivo — 2026-11-25

## Hallazgo CAJ-CASH-RECON-01

La apertura de Caja solicita explícitamente monto inicial en efectivo y el cierre solicita “Monto contado”, pero `CajaService.obtenerActiva()` y `cerrar()` calculaban `saldo_sistema`/`monto_final_sistema` sumando ventas de todos los medios. En ventas de tarjeta o transferencia, el conteo físico del cajón podía aparecer como faltante aunque la operación estuviera conciliada por el medio electrónico. El query compartido también restaba devoluciones sin distinguir su medio.

## Corrección en fuente

- El efectivo esperado ahora suma apertura, ventas/ingresos extra en efectivo y resta retiros/gastos y devoluciones en efectivo.
- Tarjeta, transferencia, Nequi y otros medios no se mezclan con el efectivo esperado.
- Los movimientos con método de devolución sin clasificar (incluida la devolución generada por descuento con `metodo_pago = NULL`) no se imputan a efectivo por suposición; seguirán apareciendo como diferencia que requiere conciliación.
- Los KPI de ventas totales y los reportes por método permanecen sin cambios.
- Las propinas voluntarias siguen fuera de ventas y del saldo esperado; Caja las informa aparte.
- Flutter presenta “Efectivo esperado” y “Efectivo contado” para explicar qué se arquea.

## Verificación

- Nest focalizado: `caja-propinas-turno.spec.ts` 1/1.
- Nest completo: 55 suites, 145 pruebas aprobadas (incluye rechazo a registrar pago en Checkout público).
- `npm run build`: correcto.
- Flutter `caja_admin_screen_test.dart`: 16/16, incluyendo 320, 390, 820 y 1440 px.
- Dart analyzer de pantalla y prueba: sin incidencias.
- La primera corrida responsive encontró aserciones que dependían del rótulo viejo; se actualizaron y la repetición pasó completa.
- No se reinició Nest :3000 ni se alteraron pedidos, movimientos, OAuth, credenciales, Cloudflare o Tunnel. La API viva no refleja todavía este cálculo hasta una activación/reinicio coordinado.

## Política operativa confirmada por el propietario

La propina voluntaria se mantiene aparte del valor obligatorio de la cuenta; no se trata como venta ni se agrega al total que el cliente debe pagar. Por ello, el arqueo excluye propinas del saldo esperado y la interfaz de Caja las muestra separadas. El propietario confirmó esta separación respecto de la cuenta, pero no definió si una propina recibida en efectivo se guarda dentro o fuera del cajón operativo. No se conserva una sugerencia de propina cuando el cobro queda diferido y no se concreta.

**Verificación UI 2026-11-25:** regresión Flutter POS con cotización de $10.000, pago mixto ($6.000 efectivo + $4.000 tarjeta) y propina voluntaria de $2.500 verifica que `pagos[]` suma exactamente el total cotizado y `propina` se envía por separado; un segundo caso cambia a pago diferido y verifica que no se envíe la propina digitada. `pedido_cajero_screen_test.dart` + `mesa_pedidos_sheet_test.dart`: 28/28; regresiones nuevas: 2/2; Jest público/Caja: 6/6; analyzer del test POS limpio. No se ejecutó E2E que escriba en la BD QA persistente. El backend todavía prorratea propina por proporción de los métodos del pedido; esto no demuestra el canal real en que se recibió. La decisión de custodia del efectivo y liquidación sigue pendiente.

El método de devoluciones de descuento también permanece pendiente. El cálculo no presume que la devolución sin método fue en efectivo; antes de resolver esa política hay que capturar el medio realmente usado o conciliarlo manualmente.

## Propina y pagos mixtos

El total que valida `CrearPedido` es la suma de `pagos[].monto`, sin sumar la propina. El Checkout público no recoge una propina para diferirla y Nest rechaza `pagos[]` en la ruta pública antes de crear el pedido. POS y cobro de cuenta de mesa envían la propina dentro de una operación de pago real; Nest la guarda en `pagos_pedido.propina`, sin incorporarla a `pagos_pedido.monto` ni al total del pedido. En pagos mixtos, la versión actual distribuye técnicamente la propina proporcionalmente entre los medios usados para pagar el pedido. La UI no pregunta ni registra el canal independiente de la propina. Como la regla comercial confirmada es mantenerla aparte del cobro obligatorio, esta asignación proporcional no representa necesariamente el medio real en que se recibió; no altera ventas ni el arqueo de efectivo, pero puede falsear conciliación por método o liquidación. Pendiente: modelar/registrar el medio real de la propina solo si se requiere conciliación o liquidación por canal; hasta entonces tratar el total como importe separado sin atribución de medio.

La regresión unitaria `PedidosPublicController` valida que la ruta pública rechace un cuerpo con pago, incluso si incluye propina, antes de invocar la creación: 5/5 casos pasan. La prueba de flujo existente `caja.e2e-spec.ts` cubre POS pagado y un pedido diferido sin persistir propina, pero esa suite E2E no se ejecutó en esta etapa por el riesgo de limpieza de la base QA persistente.
