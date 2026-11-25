## 2026-11-25 — GEO-EXT-TIMEOUT-01 / DB-POOL-ACQUIRE-TIMEOUT-01 / WOMPI-EXT-TIMEOUT-01

`GeografiaService.buscarDirecciones()` cancela Photon a 5 s (504), traduce fallas upstream a 502, sin retry y sin cachear respuestas inválidas. `DatabaseService` limita a 5 s la espera por adquirir/abrir conexión del pool; configurable con `DB_POOL_CONNECT_TIMEOUT_MS`, sin cancelar SQL que ya empezó. Jest geografía 3/3, pool 2/2; Nest suite completa 63/63, 175/175, build OK. Faltan límites por sentencia e instrumentación de conexiones activas/en espera. Las cuatro llamadas Wompi siguen sin timeout: abortar `POST /v1/transactions` podría ocultar cobro aprobado. Guías oficiales documentan `reference` pero idempotencia encontrada aplica a payouts; sin confirmación para transacciones estándar. Primero reconciliar por webhook/referencia y bloquear un segundo cargo. Credenciales y llamadas Wompi intactas. API :3000 aún ejecuta artefacto anterior.

**CAJA-LOAD-80-01:** `CajaRepository.movimientos()` deja de recorrer todas las páginas del turno: solicita como máximo 2 páginas de 50, conserva el tope visible de 80 movimientos recientes y deja el saldo de cierre a cargo de backend. Repositorio + pantalla Caja 18/18; analyzer limpio.

**Regresión general Flutter:** `flutter test --no-pub` pasó 297 pruebas y omitió 5 E2E que requieren activación + BD aislada. `flutter analyze --no-pub` no encontró errores, pero devolvió exit 1 por 10 infos existentes (web `dart:html`, async `BuildContext` en registro OAuth y `DropdownButtonFormField.value` obsoleto). No se tocó OAuth.

## 2026-11-25 — DOMI-PAY-LEGACY-METHOD-01

Al liquidar CxC de domiciliario de planta, la API ya no sobrescribe `pedidos.metodo_pago` con `efectivo`: usa el primer `pagos_pedido.metodo_pago` del mismo pedido+sucursal, o efectivo como fallback. Los importes y pagos no cambian; el método mixto completo se conserva en `pagos_resumen`. El update valida también `sucursal_id`. Unitarias focalizadas 2/2, suite Nest completa 63/63 y 176/176, `npm run build` OK; parser PowerShell OK. Se amplió el verificador aislado con $2.000 transferencia y saldo liquidado en efectivo; no se ejecutó el E2E porque el control automático rechazó el comando compuesto para preparar clon + API temporal. :3000 inició 13:50 y su `dist` es de 17:46; activación y smoke real pendientes.

## 2026-11-25 — ORD-PAY-SUMMARY-01

**Verificación runtime/visual:** el PID 7584 que escucha en :3000 inició 13:50:31; tras rebuild Nest `dist/main.js` se actualizó a 16:52:42. Salud local y pública de API + Equipo/Cliente por Tunnel responden HTTP 200, pero el proceso está anterior al artefacto y no puede considerarse actualizado. `scripts/iniciar-backend-wsl.bat` se ejecutó con `FOODY_NOPAUSE=1`; detectó artefacto posterior, preservó el PID y terminó con exit 3 (guardado esperado). Reinicio controlado intentado sobre PID/command line verificados; el control de seguridad rechazó la detención, por lo que no se usó método alternativo. `flutter test --no-pub`: 295 aprobadas/5 omitidas; Nest unitarias 61 suites/169; build exit 0; prueba pedidos focalizada 12/12. cloudflared PID 8940 sigue activo; OAuth, credenciales y datos no fueron tocados. Desde Chrome autenticado se observó Pedidos a 502×680 y la navegación Configuración/Operación; el resto de las vistas y breakpoints continúa pendiente. Requiere activación coordinada y prueba autenticada completa.

**PED-RESP-STATUS-01:** la tira de estados de Pedidos, parcialmente visible en Chrome a 502 px, dispone de scroll horizontal y fade. `flutter test --no-pub test/pedidos_kanban_widget_test.dart`: 12/12; cubre 320/390/820/1440 px y recorre «Cobro / Ruta» con `ensureVisible`. La continuidad funcional queda verificada; no se confirmó defecto de alcance. Resto de QA visual por rol/dispositivo sigue abierto.

El detalle admin `GET /pedidos/:id/detalle` ahora deriva `pagos_resumen` por `(pedido_id, sucursal_id)`; `propina_recibida` se suma aparte. Flutter los etiqueta como registros históricos (“Pagos registrados” y “Propina registrada · aparte”), sin atribuir propina a un canal ni alterar `pedidos.metodo_pago`, el total, Caja o datos históricos. SQL lateral ejecutado READ ONLY en `foody_diseno_qa`; E2E autenticado en API `:3001`/clon desechable confirma abono mixto $2.500 efectivo + $1.500 tarjeta, cierre con transferencia $4.000, cuenta $8.000 y propina $1.400 aparte. La suite E2E Caja completa pasa 10/10. Esos datos permitieron trazar FDY-2026-1227 a la prueba `jest-mesa-varios-a`: la ruta de cobro asociaba los medios de toda la mesa al primer ticket, aunque Caja los distribuía por pedido. Corregido en `PedidosPagosService`: ambos libros se distribuyen por ticket, split de ítems mantiene enlaces por pedido y el historial de abonos de cuenta añade `numero_pedido` con JOIN bajo sucursal. La vista de mesa pasa 9/9 responsive (incluye 320 px, sin overflow) y analyzer focalizado limpio. La reversa en FDY-2026-1226 es correcta (ventas $3.000+$2.000 y devoluciones equivalentes); el detalle muestra pagos brutos, no el neto de devoluciones. QA histórico sin mutar; clon/API temporales retirados. Regresión global previa a este último ajuste: Nest unit 61/61 suites, 169/169; Flutter 295 aprobadas/5 omitidas; build Nest OK. Falta validar click-through navegador autenticado y activar el dist en runtime tras reinicio coordinado; `:3000`/Tunnel siguen intactos.

## 2026-11-25 — DOMI-PAY-DISPLAY-01

Hallazgo DOMI-FIADO-COVERAGE: `pedidos.metodo_pago` puede resumir como efectivo un cobro mixto. Las consultas activas planta/independiente e historial planta agrupan `pagos_pedido` por método, bajo `(pedido_id, sucursal_id)`; tarjetas e historial muestran cada importe. Fallback legacy si no hay registros, propina excluida. Nest focalizado 3/3 + build; Flutter 2/2. SQL read-only en QA: historial planta 44/44 con detalle; la instantánea tiene 63 pedidos mixtos con escalar discrepante, sin inferir prevalencia de producción. Pendiente activar dist :3000 y verificación autenticada por Tunnel.

## 2026-11-25 — DASH-PARALLEL-01

Inicio ya estaba preparado para cargar resumen, mesas, alertas e inventario en paralelo; agregué una regresión explícita porque la prueba existente no demostraba concurrencia. `flutter test --no-pub test/dashboard_resumen_widget_test.dart`: 10/10 responsive/funcional, y `dart analyze` de widget + prueba sin incidencias. El fallback de pedidos activos sigue serial detrás del resumen cuando el API no devuelve `domicilios_tardios`. Sin medición de waterfall real; no se reporta un ahorro temporal cuantificado. La auditoría punta a punta ya no describe las cinco esperas como estado vigente.

## 2026-11-25 — KDS-TENANT-COMPARISON-01

Se aclaró la lectura visual del KDS: Chrome autenticado mostró `Cocina 0 / Listos 6` en una sesión de `Sede principal`; la consulta API previa de 105 tickets/117 líneas usó la cuenta demo, cuyos registros corresponden a `Sede Centro`. No son la misma sede ni una comparación válida. La clasificación Flutter y Nest coincide en usar estado por ítem. Lectura SQL READ ONLY/ROLLBACK encontró seis pedidos con 20 ítems resueltos y ninguna línea pendiente; son registros antiguos. Después se publicó la mejora de antigüedad y Chrome autenticado confirmó los seis chips rojos (113–146 días); bootstrap local/Tunnel 200 y SHA coincidente. No se mutaron pedidos. La posible columna de cocina abierta reportada por otros datos históricos aún requiere confirmar tenant antes de actuar.

## 2026-11-25 — DOMI-FIADO-COVERAGE-01

`verificar-fiado-domiciliario.ps1 -CicloCompleto` completó dos ciclos en Nest `:3001` contra `foody_diseno_qa_codex_domi_20261125` con `FOODY_QA_SIN_EFECTOS=1`. Con `domicilio_ingresa_a_caja=false`: cuenta $13.000, CxC/liquidación $8.000, fila de pago y movimiento Caja $8.000. Con flag `true`: cuenta, CxC, fila de pago y movimiento Caja $13.000. Ambos pedidos quedaron entregados y la CxC del fixture pagada; el script restauró `permite_fiado_domiciliario`; el flag de Caja se restauró manualmente a false. SQL de solo lectura confirmó montos y métodos. Nest QA se detuvo, cero conexiones, clon eliminado; la QA persistente conserva 3 restaurantes y cero sesiones, API :3000/Tunnel intactos.

Pruebas unitarias relacionadas de cálculo, guards de despacho y permisos de domiciliario: 4 suites/16 pruebas. Reejecuté `cobro-domicilio.util.spec.ts` y `domiciliarios-saldo-pendiente.spec.ts`: 2 suites/7 pruebas; confirman que $40 abonados primero al producto dejan $50 de productos y $20 de domicilio pendientes en una cuenta de $110. Sigue pendiente E2E de ese saldo dentro de la entrega, método distinto para producto/domicilio y repetición de liquidación. El método agregado `pedidos.metodo_pago='efectivo'` no basta para representar inequívocamente el cargo externo y los métodos originales; no se cambió contabilidad ni se inventó método recibido.

## 2026-11-25 — COC-PRODUCT-KITCHEN-ROUTE-01: E2E producto → pedido → KDS

Se añadió `foody_backend/test/flujos/catalogo-cocina.e2e-spec.ts` para probar el cruce que faltaba: crear producto vendible con cocina predeterminada, verificar catálogo, crear pedido staff, encontrarlo en el ticket de esa cocina y resolver el ítem hasta `listo`. `npm test -- --runInBand src/modulos/catalogo/catalogo-producto-cocina.spec.ts src/modulos/cocinas/cocinas.service-disable.spec.ts`: 2 suites/11 pruebas; E2E focalizada en `:3001`: 1/1. Se ejecutó sobre clon `foody_diseno_qa_codex_catalogokds_20261125`, API con `FOODY_QA_SIN_EFECTOS=1`; las aserciones se ajustaron a los campos reales (`producto` en KDS, no `nombre`). API QA detenida; clon eliminado tras confirmar cero sesiones. `foody_diseno_qa` fuente conserva sus 3 restaurantes; API principal PID 7584 y Tunnel no se tocaron. `COC-PRODUCT-KITCHEN-ROUTE-01` se cierra; futuras líneas históricas sin cocina se inspeccionarán individualmente antes de cualquier reparación.

## 2026-11-25 — API-RUNTIME-FRESHNESS-01 / WEB-RELEASE-SAFE-01

Se confirmó con proceso/artefacto (no con el `version` de `/salud`, que sigue hard-coded en `2026-07-01`) que el Nest PID 10204 había arrancado a las 07:22 y el `dist` más nuevo se compiló después. `npm run build` terminó exit 0; se reemplazó solo ese proceso Foody y Nest arrancó como PID 7584 a la 13:50. `scripts/verificar-backend.bat` exit 0, salud local/pública HTTP 200. `scripts/iniciar-backend-wsl.bat` ahora compara StartTime del listener con mtime de `dist/main.js`; si el artefacto es posterior, informa build stale y preserva el proceso para cierre normal, en vez de declararlo listo.

Se detectaron bundles web anteriores a los cambios recientes. `servir-web-tunel-release.ps1` ahora compila Cliente/Equipo en staging mientras los sitios viejos siguen atendiendo, valida tres archivos básicos por flavor, detiene solo PIDs Python cuyo commandline apunta a `spa_http_server.py`, conserva backups y restaura/reinicia el anterior si la publicación falla. Sync de entorno reportó Flutter sin cambios; dominios y URL Wompi coinciden con config actual, sin tocar OAuth ni secretos. Build Cliente/Equipo OK; avisos Wasm/CupertinoIcons no bloqueantes. Publicación: SPA :8080 PID 21152, :8081 PID 19032; Tunnel Equipo/Cliente/API 200, FCM y manifest 200, recurso inexistente 404 local y público. El HTML público incluye los SHA cache-bust actuales de Equipo `391a7e...a92` y Cliente `227101...674e`; `cloudflared` PID 8940 quedó intacto. Se conservan los bundles previos como backups.

Validación funcional integral de la etapa previa sigue vigente: backend 59 suites/167, Flutter 294 aprobadas/5 E2E omitidas, flujo QA aislado 12/12 y Nest E2E 47/47. Limitación actual: no se hizo click-through autenticado sobre todas las pestañas en Chrome/dispositivos ni carga real multiusuario; esta publicación demuestra artefactos actuales servidos, no completa la auditoría integral. Propina: cuenta completa por separado de propina voluntaria; manejo en caja y atribución de medio mixto siguen pendientes.

## 2026-11-25 — QA-CROSS-ORCH-SAFETY-01 cierre y registro de incidente

Se validó el flujo cruzado en Nest `:3001` conectado exclusivamente al clon temporal `foody_diseno_qa_codex_flow_20261125` (copiado de `foody_diseno_qa`, 21 MB) con `FOODY_QA_SIN_EFECTOS=1`, sin FCM, realtime, storage, impresión automática, cron ni pasarela externa. La suite integrada terminó 12/12: registro Free, checkout bloqueado sin fila de pago, cola de impresión offline, domicilio/Cocina/despacho, cajero, inventario, copia/traslado de menú, mesero con turno, split/Caja, 5 pedidos QR concurrentes, coherencia Caja y fiado→CxC→liquidación. La suite Nest E2E adicional pasó 8 suites/47 pruebas. Se corrigieron verificadores que tenían `:3000`/`supabase-db` fijos, IDs de seed caducados, token QR omitido, API .NET no disponible en Windows PowerShell, test de reparto sin `productoTotal` y el paso de Cocina ahora obligatorio antes de `listo`. Se agregaron guardas de DB efímera al orquestador y los scripts mutadores; impresión en modo archivo no inicia el agente externo.

Incidente del primer intento: pese al valor de entorno, `verificar-self-service.ps1` y el reparador de impresora esquivaban el destino QA. El primero creó tenant `QA Self 1795629834` con pago pendiente/link de checkout sintético, sin `transaccion_wompi_id` ni cobro. Sus filas de restaurante, usuario, sucursal, cocina, zona, suscripción y pago fueron eliminadas por transacción exacta; lecturas posteriores confirmaron cero coincidencias. El segundo tocó la fila de impresora de demo de la base de uso diario y la dejó `tipo=archivo`, `ip_local=NULL`; este valor corresponde al modo piloto documentado. No conocemos el valor anterior, por eso se mantuvo el actual en vez de inferir uno. No se creó pedido de prueba en esa DB ni se alteraron asignaciones/jobs recientes. Todos los scripts de orquestación ya apuntan al clon y tienen guardas/preflight. `foody_diseno_qa` permanece intacta; el clon final se eliminó tras comprobar cero conexiones.

Parada ordenada de QA `:3001` terminada. El proceso principal :3000 y los servidores locales :8080/:8081 siguen escuchando; `https://foodyy.store`, `https://equipo.foodyy.store` y `https://api.foodyy.store/api/v1/salud` respondieron HTTP 200. No se tocó configuración, credenciales ni OAuth de Cloudflare/Google. **Decisión funcional confirmada:** total obligatorio se cobra completo; propina voluntaria queda separada y no reduce ni integra el total de la cuenta. Sigue pendiente decidir custodia/reparto/liquidación de efectivo de propina por canal.

## 2026-11-25 — RBAC-CAJA-WRITE-01

Hallazgo confirmado en `CajaController`: crear/pagar CxC, registrar gastos y devoluciones aceptaban solo `ver_caja`. Se creó `gestionar_caja` y la migración 094 ya está aplicada a la DB local activa; `verificar-migraciones-prod.ps1` confirmó los siete checks, incluido 4/4 roles. Abrir/cerrar/retiro conservan permisos específicos. Liquidación de domiciliario requiere `gestionar_domiciliarios` o `gestionar_caja`. Flutter recibe permisos de sesión desde ambos shells y oculta operaciones no permitidas; abrir sin `abrir_caja` muestra aviso. La DB activa tiene 0 overrides. E2E en clon con override completo `ver_caja` probó lectura y denegación 403 de escritura; admin pasa guard y llega a error DTO 400, sin registrar movimiento (2/2). En API :3000: lectura autenticada de cajero 200; POST inválido de gasto para cajero/admin 400, no 403. El clon se retiró; Tunnel y QA persistente intactos. Tests previos Nest controller/Domicilios 11/11, Caja Flutter 17/17 responsive y analyzer focalizado limpio.

## 2026-11-25 — Verificación global actual Backend + Flutter

Ejecutado sobre el checkout vigente: `npm test -- --runInBand` pasó 59 suites/167 pruebas; `npm run build` terminó correctamente. `flutter test --no-pub` pasó 294 pruebas; 5 escenarios E2E quedaron omitidos porque requieren habilitación explícita y una base aislada. `flutter analyze` terminó con código 1 por 10 hallazgos informativos: APIs web deprecated, `DropdownButtonFormField.value` deprecated y tres usos de `BuildContext` después de await en registro Google. No se modificó OAuth. El análisis reportó issues, no errores de compilación; el backend build y las pruebas pasan. El QA API :3001 y un clon desechable no estaban levantados, así que no se ejecutaron scripts E2E mutadores contra la base QA compartida. Nest :3000, servidores Equipo/Cliente y la ruta Tunnel no se reiniciaron ni alteraron en esta verificación.

## 2026-11-25 — DOMI-FIADO-COVERAGE-01 (registro inicial)

Este registro inicial precede a la E2E ampliada registrada al inicio del documento. En esta revisión se ejecutaron ambos valores del flag en clon aislado; restan abonos previos, conciliación del método mixto y protección ante liquidación repetida. Ver el registro inicial del 2026-11-25 y `AUDITORIA_DOMICILIOS.md`.

## 2026-11-25 — QA-CROSS-ORCH-SAFETY-01

La lectura de `verificar-flujo-cruzado-api.ps1` mostró que antes de sus casos modificaba horarios y ejecutaba un limpiador sobre la QA compartida. El orquestador ahora bloquea antes de cualquier efecto salvo API local :3001, contenedor QA designado y base con prefijo estricto `foody_diseno_qa_codex_*`; `limpiar-demo-qa.ps1` acepta esa forma de clon. Se ajustó la misma expresión de base en el ciclo de fiado. Parser validado; invocación controlada con `FOODY_QA_DATABASE=foody_diseno_qa` devolvió código 2 en la guarda, antes de acceso a API o mutación. No se creó clon ni se alteraron datos. Siguiente: provisionar clon desechable, arrancar Nest aislado y validar los ciclos de pedidos/domicilios de extremo a extremo.

## 2026-11-25 — DOM-TIP-DIRECT-01

Rastreo del contrato de entrega independiente: `ConfirmarEntregaDto` captura método del producto y del domicilio, pero no propina ni destinatario; `DomiciliariosIndependientesService.confirmarEntrega()` registra esas líneas con `pagos_pedido.propina=0`, y Flutter envía solo el medio. Una propina que se entregue directamente al repartidor queda fuera del ledger de Foody y no suma a Caja, tarifa, comisión ni ganancia calculada. No hay una regla del propietario que exija capturarla; registro/comprobante/reporte queda como decisión pendiente, sin inferir deuda o payout. Evidencia de fuente en `AUDITORIA_DOMICILIOS.md`.

## 2026-11-25 — Aclaración de propina voluntaria

El propietario reitera que la cuenta se cobra completa y la propina queda aparte del valor obligatorio. Se corrigió la memoria y el estado para no atribuirle una decisión sobre guardar propinas en efectivo dentro/fuera del cajón: su aclaración no determina custodia física, destinatario, reparto o liquidación. No se cambió código de aplicación ni datos; se añadió cobertura de widget para comprobar que en pago mixto los montos de los métodos suman el total estimado del pedido y la propina viaja en el campo separado, y que si el pago se difiere una propina ingresada no se envía ni persiste. `flutter test --no-pub test/pedido_cajero_screen_test.dart test/mesa_pedidos_sheet_test.dart`: 28/28; regresiones focalizadas nuevas: 2/2; Jest público/Caja: 6/6. En cobros mixtos el backend aún prorratea la propina por medios del pago de la cuenta, por lo que no acredita el medio real en que se recibió. No se ejecutó E2E con escritura contra la QA persistente. Referencias: `MEMORIA.md`, `docs/MASTER_STATUS.md`, `docs/archivo/auditorias-prompts/AUDITORIA_CUADRE_EFECTIVO.md`.

## 2026-11-25 — KDS-READY-AGE-01 y verificación visual del flujo

En la vista Equipo autenticada por Tunnel (11:26 COT) el Centro de operación muestra 9 pedidos abiertos, 26 alertas, una mesa “En cobro” y un domicilio “En camino” con antigüedad 113 d 9 h. El KDS muestra 0 en Cocina y 6 en Listos; consulta DB read-only/rollback, acotada a esa sede y esos tickets, confirma que los seis son >30 d (02-jul a 04-ago UTC). No se ejecutaron acciones de reimpresión, retorno a cocina ni cierre/transición, porque los registros no están clasificados por el propietario. Se actualiza la tarjeta “Listos” para presentar antigüedad desde `created_at`: ámbar >24 h, rojo >30 d; tooltip aclara que no es tiempo desde que quedó listo. KDS 17/17 responsive 320/390/820/1440, analyzer limpio. Release Equipo candidato compilado (SHA-256 `ab700bb24fdae4dfc8f1740b7fdb152086abfc7a13acd071dfcf80fd4e120001`). La revisión automática rechazó detener/reemplazar el servidor :8080 para publicar; verificación posterior confirmó Equipo local 200, Cliente local 200, Tunnel Equipo 200 y Cloudflared PID 8940 activo. Bundle público aún anterior; OAuth, CORS/WOMPI y API intactos. E2E con escrituras queda pendiente de entorno QA efímero verificado. Evidencia: `docs/archivo/auditorias-prompts/AUDITORIA_ESTADOS_OPERACION_STALE.md` y `docs/archivo/auditorias-prompts/AUDITORIA_COCINA_KDS.md`.

## 2026-11-25 — PERF-WEB-ASSET-01

Tres descargas `fetch` consecutivas al `main.dart.js` servido por Tunnel devolvieron HTTP 200 con Brotli; tamaño decodificado 6.960.485 bytes y latencias 1.677/586/495 ms (p50 586 ms, n=3). `cf-cache-status=REVALIDATED` en las tres. El release candidato de KDS pesa 6.961.504 bytes. Esto mide solo el asset desde este PC, no la inicialización Flutter, la waterfall autenticada, red móvil ni concurrencia. No se cambió caché ni CDN; medir navegación browser cold/warm antes de recomendar ajustes. Evidencia `docs/AUDITORIA_RENDIMIENTO_PUNTA_A_PUNTA.md`.

## 2026-11-25 — COC-PRODUCT-KITCHEN-ROUTE-01

Productos disponibles podían quedar sin cocina cuando la sede no tenía cocina activa; además, crear/editar no aseguraba que cocina y categoría fueran de la misma sede. Ese `cocina_id` se copia al pedido y KDS lo excluye mediante JOIN, dejando la línea sin transición ni despacho. Se añadió validación de referencias por sede, cocina activa requerida para vender/activar, protección de espejo de bebidas/copia de menú y bloqueo del formulario si no hay cocina. También se bloquea desactivar/eliminar cocinas con productos disponibles o pedidos pendientes. Nest 57/156 y build OK; Menú Flutter 15/15 en 320/390/820/1440, analyzer limpio. Consulta transaccional read-only en Supabase local y QA: 0 pedidos activos con línea no resuelta sin cocina. API :3000 no reiniciada, Tunnel ni datos alterados. La cocina del producto no repara líneas históricas ya copiadas al pedido. Evidencia `docs/archivo/auditorias-prompts/AUDITORIA_ENRUTAMIENTO_COCINA.md`.

## 2026-11-25 — CAJ-CASH-RECON-01

El saldo de Caja para arqueo se calculaba con todos los métodos de pago aunque el monto inicial y contado son efectivo físico. Ahora `saldo_sistema` y el cierre incluyen solo ventas/ingresos en efectivo, gastos/retiros y devoluciones en efectivo; tarjeta/transferencias quedan fuera y propinas voluntarias siguen aparte. Nest 55/55 suites, 145/145 pruebas, build OK; Caja Flutter 16/16 en 320/390/820/1440, analyzer limpio. Checkout público rechaza pagos y la regresión focalizada de ruta pública pasa 5/5. No se reinició API :3000 ni se tocaron datos; activar el cambio requiere reinicio coordinado. Pendiente confirmar disposición física de propina en efectivo y si prorratear propina por métodos de pago mixtos refleja lo que hace el cliente. Ver `docs/archivo/auditorias-prompts/AUDITORIA_CUADRE_EFECTIVO.md`.

## 2026-11-25 — DOM-ESTIMATE-LABEL-01

La vista de Domiciliarios ya no llama “Por pagar” a importes calculados al aceptar ofertas: la tarjeta y el resumen los presentan como ganancias estimadas. La ayuda aclara que pueden incluir pedidos cancelados y no confirman entrega ni pago. Sin cambio al cálculo, API o datos. `flutter test --no-pub test/domiciliarios_admin_screen_test.dart`: 8/8 (320/390/820/1440); `dart analyze` del archivo: sin incidencias. Aún no publicado ni verificado visualmente tras el cambio. El pago real, devengo y cancelaciones siguen pendientes de definición.

## 2026-11-25 — OPS-STALE-ORDERS-02 / DOM-STATE-RECON-01 / OPS-RUNTIME-STALE-01

Consulta de solo lectura encontró 15 pedidos operativos de más de 24 h, 14 de ellos >30 días; saldo aparente agregado $1.312.384 COP (sin clasificar como deuda real), 4/11 mesas activas ocupadas, 7 cajas abiertas >30 días en siete sedes (cuatro sin movimiento reciente) y dos sesiones de domiciliario activas >30 días. Un pedido domicilio `en_camino` mantiene asignación `asignado` pese a historial `asignado→en_camino`; el servicio actual cambia ambos dentro de una transacción. No se mutaron registros ni se identificó si son fixtures QA. PID 10204 arrancó 07:22 local, antes de modificación de `dist/main.js` a las 08:28: salud/rutas están arriba, pero el build reciente no queda probado en runtime. Ver `AUDITORIA_ESTADOS_OPERACION_STALE.md`.

## 2026-11-25 — IMP-QUEUE-CLASSIFY-01 / IMP-QUEUE-HEALTH-01

Auditoría de solo lectura clasificó 317 jobs de impresión en error: 316 `ECONNREFUSED` con los 10 intentos agotados y uno anómalo sin mensaje ni intentos; no hay pendientes. En las últimas 24 h hubo 3 fallos, dos asociados a pedidos ya pagados y uno domiciliario `asignado` cuyo pedido se creó en agosto. Salud profunda reporta degradado solo por el historial de errores mientras BD/Realtime/agente están conectados. `scripts/verificar-backend.bat` exit 0. No se reintentó ni cambió la BD. Sin prueba física ni auditoría por pedido no se puede determinar si se entregó cada comanda. Siguiente: conciliación manual segura; ver `docs/archivo/auditorias-prompts/AUDITORIA_IMPRESION_COLA.md`.

## 2026-11-25 — CAJ-OPEN-RECEIVABLE-01: domicilio entregado con saldo

El filtro operativo de pedidos ahora conserva entregas a domicilio con saldo pendiente; el dashboard las cuenta como abiertas y “Cerrados hoy” solo muestra entregas cubiertas. Kanban agrega “Entregados · por cobrar”; su tarjeta presenta el saldo y la acción existente de registro de pago requiere `cobrar_pedido`. El cierre de caja mantiene su bloqueo preventivo hasta cobrar y no se cambió ningún registro. Suite Flutter completa: 285 aprobadas/5 omitidas; analyzer tocado limpio. Nest completo: 55 suites/142 pruebas, `npm run build` y `npx tsc --noEmit` OK. Cliente/Equipo Release publicados por `scripts/servir-web-tunel-release.ps1`; seis URLs local/Tunnel (sitios + API) HTTP 200, bundles públicos con SHA-256 idéntico al build y `cloudflared.exe` PID 8940 activo. Solicitud para reiniciar PID 10204 fue bloqueada por revisión automática; API viva sigue en el build previo. Propina continúa voluntaria, aparte del total; no se guarda una sugerencia si se difiere el pago.

## 2026-11-25 — FLUTTER-ANALYZE-INFO-01: línea base global de analyzer

`flutter analyze --no-pub` global pasó de 22 a 10 infos; se corrigieron 12 avisos de estilo sin cambiar comportamiento en cleanup, overlay de paywall, subreceta e import de notificaciones. Las 285 pruebas Flutter/5 omitidas siguen pasando y analyzer focalizado de los cuatro archivos modificados queda limpio. Los 10 restantes: seis de `dart:html` en helpers web y cuatro de lifecycle/propiedad deprecated en `restaurante_registro_screen.dart`; no se tocó ese archivo por la restricción de no modificar OAuth. No hay errores ni warnings, aunque Flutter devuelve código 1 por infos.

**OPS-RUNTIME-02 (2026-11-25):** Nest compilado y reiniciado mediante `scripts/iniciar-backend-wsl.bat`; PID 10204 sirve `dist/main.js` en :3000. `scripts/verificar-backend.bat` exit 0. Salud local y pública 200; salud confirma Postgres y Realtime conectados. La ruta protegida de movimientos de Caja devuelve 401 sin sesión y, con admin demo más UUID inexistente, 404 `NO_ENCONTRADO` (ruta registrada). Finanzas autenticado devuelve `resumen`, `cuadre_caja` y `recaudo_periodo`. Cliente y Equipo local/Tunnel responden 200. Cloudflare Tunnel `cloudflared` PID 8940 permanece activo. Health global sigue degradado únicamente por 317 jobs históricos de impresión en `error` (0 pendientes; 0 enviados en 24 h); sin reintento masivo. No se cambiaron OAuth, credenciales, Tunnel ni datos de negocio.

# 2026-11-25 — IMP-AGENT-BACKLOG-01 / RT-HEALTH-01

Health de API :3000 (PID 20152): Postgres y Realtime responden. El agente Python `ws://127.0.0.1:8765` quedó iniciado en modo `archivo`; health confirmó ping conectado. Quedan 317 jobs históricos `error`, 0 pendientes y 0 enviados en últimas 24 h, por lo que health global se mantiene degradado. Nest unitarias impresión/Realtime 3/3 y prueba sintética aislada del agente aprobada en `:18765`. No reencolé ni cambié datos reales; el modo archivo no confirma impresión física. Los jobs terminales requieren clasificación y eventual reimpresión individual. API :3000 y Tunnel no se reiniciaron ni modificaron.

# 2026-11-25 — PED-FLOW-E2E-01 / PED-STAFF-IDEM-01/02

Se ejecutaron mesa, QR, domicilio, Cocina, Caja y casos límite en clon QA temporal: 6 suites/44 pruebas aprobadas. Dos pruebas nuevas confirman que replay concurrente POS crea un único pedido y recaudo, payload distinto da 409, y reintento no duplica línea/ticket KDS. También quedó probado cobro excepcional y cierre Cocina manteniendo pedido `pagado`. La instancia QA tuvo efectos externos apagados; por tanto no se certifican entregas Realtime, notificación ni impresión física. API :3001 se detuvo y clon se eliminó; QA fuente conserva 4 sedes. :3000 PID 20152 sigue activo sin reinicio; Tunnel intacto.

**PED-NUMBER-CONCURRENCY-01:** la suite de concurrencia pública pasó 1/1 en clon QA: cuatro creaciones simultáneas reciben números de pedido únicos. Clon descartado, QA original conserva 4 sedes; API :3000 saludable y sin reinicio.

# 2026-11-25 — FIN-DATE-01: añadir recaudo por fecha de movimiento

Reportes mantiene la lectura de cohorte por fecha del pedido y añade el neto de ventas menos devoluciones por `movimientos_caja.created_at`, dentro del rango local de Bogotá. El indicador puede incluir pedidos anteriores; propinas quedan aparte. UI explica ambas fechas y el PDF/CSV incorpora el recaudo del periodo. No se alteró Analítica, Caja ni datos. Reportes 8/8, export PDF/CSV 2/2, Nest helper/contrato 6/6, analyzer focalizado y `npm run build` OK. No se reinició API :3000 ni se tocó Tunnel/OAuth.

# 2026-11-25 — COC-PAID-KDS-01: prueba E2E aislada tras cobro excepcional

El escenario `VIE-05/13 [C]` pasó 1/1 contra Nest `dist` en API temporal :3001 conectada a clon descartable de `foody_diseno_qa`: abono parcial, rechazo al cajero por Cocina incompleta, cobro de admin con motivo, ticket visible para KDS, línea completada y estado financiero final `pagado`. Integraciones externas, cron, realtime e impresión se desactivaron con la bandera QA. API temporal detenida y clon retirado; la base fuente conserva sus 4 sucursales. :3000 PID 20152 y Tunnel no cambiaron; activación en el proceso existente sigue pendiente.

# 2026-11-25 — ANA-CASH-COHORT-UX-01: aclarar saldo vs cuadre de Caja

Análisis, Reportes y PDF/CSV ahora rotulan ventas de pedidos, cobros netos asociados y el saldo de esa cohorte. La explicación indica que cobros posteriores modifican el resultado y que no equivale al descuadre físico del turno; el cierre de caja sigue siendo su fuente. Se preservan cálculos. Flutter 13/13 (incluye Caja de Análisis a 320/390/820/1440 px), Nest 3/3 + build, analyzer limpio; sin mutaciones de datos. No se reinició :3000, por lo que la metadata backend compilada queda pendiente de activación; Tunnel se mantuvo intacto.

# 2026-11-25 — PED-STAFF-IDEM-01/02: reintento POS

Se comprobó que POS conserva la clave por operación, la cambia si cambia el payload y el repositorio la envía a `POST /pedidos/staff`; Nest liga el replay a huella y sucursal. Flutter repositorio+POS 24/24; prueba focalizada de huella Nest 1/2. No se ejecutó alta/replay E2E integrado en este turno; requiere API y PostgreSQL QA aislados. Sin pedidos comerciales ni cambios de backend productivo.

# 2026-11-25 — ANA-FILT-PROD-01 / FIN-TIP-REPORT-01

Revisión de Analítica/Caja: el texto histórico sobre `producto_ids` estaba obsoleto; la implementación suma únicamente las líneas de producto filtradas. Se agregó `analitica-filtro-producto.spec.ts`; prueba focalizada 1/1. La propina permanece fuera de ventas netas y utilidad, y Caja la presenta aparte. No se alteró código productivo, cálculos ni datos. Abierto: construir el reporte/liquidación de propina solo después de decidir beneficiario, asignación de pagos de mesa y política en cancelaciones.

# 2026-11-25 — FIN-TIP-UX-01: propina separada, clara en el cobro

En Caja de mesa y POS, el campo que se presenta al registrar un pago real ahora dice “Propina voluntaria” y “Aparte del total del pedido”. Sigue opcional y no altera el total de venta; no es el formulario previo del Checkout ni queda guardado antes de pagar. Widgets de POS+Mesa: 27/27; `dart analyze` focalizado limpio. Cliente/Equipo Release recompilados en sus carpetas servidas, versionados por hash y verificados local/Tunnel; los bundles incluyen el texto y el listener independiente. La política automática sigue bloqueando el reinicio del API activo, PID 20152 conserva el build anterior; no se tocó Tunnel/OAuth.

# 2026-11-25 — DOM-RT-INDEP-01 / DOM-LOCK-ORDER-01

La cancelación administrativa de un pedido independiente ahora cierra ofertas activas, transmite `pedido_desasignado` por canal privado y hace que la app del courier vuelva a consultar sus pedidos/sesión. Restaura disponibilidad solo cuando no queda otro pedido activo. Para evitar la carrera de dos ofertas/dispatches sobre un courier o pedido, la aceptación bloquea primero el pedido y luego la oferta, en el mismo orden que cancelación; el auto-dispatch de planta selecciona filas con `FOR UPDATE OF dp SKIP LOCKED`. Nest compila y las 52 suites/131 unitarias pasan; E2E domicilio 5/5 pasó antes del último cambio de orden, pero no pudo repetirse después porque el comando de creación de clon QA fue rechazado antes de ejecutarse. Ambos flavors se compilaron y publicaron en las carpetas servidas; SHA local/Tunnel coincide y bundles incluyen evento. No se tocó la BD QA persistente ni datos del negocio. La política de ejecución rechazó reiniciar Nest :3000, así que PID 20152 conserva el build anterior. Los seis destinos locales/Tunnel siguen respondiendo 200 y `cloudflared` activo. Próximo paso: repetir E2E en clon, reinicio API y comprobación realtime en sesión real. Sigue pendiente definición financiera de comisión de independiente cancelado y payout.

# 2026-11-25 — activación de FIN-TIP-CHECKOUT-01 / COC-KDS-IMMUTABLE-01

La regla de producto quedó confirmada: la propina voluntaria va aparte del valor de la venta. Checkout ya no pregunta ni envía propina antes del pago; la API ignora el campo legado `propina` tanto en pedidos públicos como en pedidos staff aún no cobrados. Una propina solo se conserva al registrar un pago real y se mantiene separada de `movimientos_caja`. En Cocina, intentar cambiar ítems de pedidos en cobro, despacho o terminal ahora recibe 409 antes de escrituras/efectos laterales. Verificación sobre clon recién creado: Cocina+caja+QR 24/24; Nest build y unitarias 51 suites/128; SQL de pedidos sintéticos sin cobro: acumulado 0, monto pagado 0, pagos 0. Checkout responsive 1/1 y analyzer focalizado limpio. La primera repetición en clon ya alterado falló por fixtures consumidos; el rerun limpio pasó. Clon retirado y `foody_diseno_qa` intacta. Backend reiniciado por el iniciador oficial con PID 20152. Rebuild Cliente/Equipo completado, seis destinos local/públicos HTTP 200 y SHA-256 del `main.dart.js` remoto coincide con cada build local (cliente `48743bf1…198b552`, equipo `3ce7a7c6…a1bcfe6`). No se editaron OAuth, configuración Cloudflare ni el Tunnel; API pública revalidada. Siguen abiertas la liquidación/destinatario de propina y la validación visual autenticada del KDS.

# 2026-11-25 — DASH-STATUS-UX-01: frescura visible en el Centro de operación

# 2026-11-25 — PERF-PEDIDO-CATALOGO-01: lecturas agrupadas al estimar pedidos

# 2026-11-25 — COC-KDS-IMMUTABLE-01 / FIN-TIP-CHECKOUT-01

**Cocina:** el endpoint cambiaba `pedido_items.estado_cocina` aun cuando su pedido estaba en `pagando`, `asignado`, `en_camino`, `entregado` o terminal. Ahora responde 409 `PEDIDO_COCINA_CERRADO` antes de actualizar ítem, crear alerta/merma, imprimir o desactivar el producto. E2E Cocina+caja+QR 24/24 en clon limpio: crea pedido, pasa ítem a preparando, pone el pedido en cobro e intenta marcar N/D; la línea sigue preparando.

**Propina:** decisión del negocio confirmada por el usuario: es voluntaria, queda fuera del total de productos y no se conserva la selección previa al pago. Checkout ya no solicita un monto antes de crear el pedido y comunica que cualquier propina se entrega aparte; Flutter dejó de enviarla. Nest ignora el campo `propina` legado en clientes públicos y en pedidos staff aún no cobrados; solo lo conserva en una creación POS con cobro real. SQL en clon QA confirmó ambos pedidos sin cobro con `propina_acumulada=0`, `monto_pagado=0` y cero filas `pagos_pedido`; el pago real conserva propina en `pagos_pedido` separada del movimiento de venta. Flutter responsive 1/1 y `dart analyze` sin issues; Nest build, 51 suites/128 unitarias y E2E Cocina+caja+QR 24/24. No se aplicó migración ni se tocaron datos persistentes. El clon se eliminó, `foody_diseno_qa` intacta, API :3000 PID 20152 y Tunnel API HTTP 200. No se migran valores históricos de `propina_acumulada`; falta definir reparto/liquidación y propina directa a domiciliarios.

Nest agrupaba consultas de productos, toppings, bebidas y combos durante estimación/creación de pedidos, quitando el patrón de una consulta por cada línea o extra. La API sigue calculando precios/totales y comprobando sede y disponibilidad; no se agregó caché. Build OK; regresión Nest: 51 suites/128 unitarias; E2E QR: 6/6 contra clon QA desechable. Benchmark repetible `scripts/perf/medir-estimacion-pedidos.cjs`, 12 solicitudes por tamaño: 1 línea p50 12,88 ms/p95 23,91 ms; 30 líneas p50 13,69 ms/p95 14,62 ms. Totales lineales verificados ($14.500 y $435.000). Medición local secuencial, sin Tunnel ni carga; no permite prometer capacidad. La sede-fixture no tiene combo disponible, por lo que no hubo medición de runtime con combo. Se mantuvo intacta la QA persistente y :3000; se elimina clon/proceso de prueba al limpiar.

El encabezado del dashboard ahora presenta el estado de carga/refresco como un indicador compacto y accesible: preparación, actualización en curso, actualización parcial o hora de captura. Explicita que el refresco automático ocurre cada 75 s; deja de insinuar que los datos son en vivo. La transición respeta `MediaQuery.disableAnimationsOf`, y colores, espaciado, radio y tipografía vienen del tema/tokens Foody. Sin cambio de endpoints, lógica de negocio o tráfico. Verificación: `flutter test test/dashboard_resumen_widget_test.dart` (9/9, 320/390/820/1440 px, carga parcial y refresco); `dart analyze lib/features/admin/presentation/widgets/dashboard_resumen_widget.dart` sin issues. Pendiente revisión visual autenticada en navegador.

# 2026-11-25 — PED-PAY-TRUST-01 / PED-STAFF-CASH-RBAC-01: separar preferencia y cobro real

# 2026-11-25 — FIN-PDF-UNICODE-01: tipografía correcta en informes PDF

Los exportadores PDF de Reportes y Centro de Análisis dependían de Helvetica y lanzaban el aviso «has no Unicode support» al generar reportes en español. Se añadieron Roboto regular/negrita al paquete de assets con su licencia Apache 2.0 y se configuró el tema PDF en ambos exportadores. Se actualizó `Table.fromTextArray` a `TableHelper.fromTextArray` en Análisis. Tests de exportación Reportes/Análisis 3/3; comprueban `%PDF` y que la fuente incrustada sea Roboto; analyzer focalizado limpio. Publicación verificada en Cliente y Equipo: las rutas de Tunnel sirven los assets Roboto y su SHA-256 coincide con cada build local; `main.dart.js` también coincide en ambos flavors.

# 2026-11-25 — QR-SESSION-BIND-01: preservar y validar QR de mesa

Se reprodujo que el ingreso QR llegaba a `/menu` sin conservar el token; además el cliente solo enviaba `mesa_id` y Nest no validaba la correspondencia. `MesaSesion.rutaMenu`, Router y menú ahora conservan el `qr_token`, el repositorio cliente lo adjunta al pedido y Nest valida token/mesa/sucursal para creación pública de tipo mesa (no afecta staff ni cotizaciones). E2E QR en clon aislado 6/6; regresión Nest completa 8/41 E2E + 51/128 unitarias; Flutter completo 276 aprobadas/5 omitidas; `mesa_sesion_service_test.dart` 1/1 y analyze focalizado limpio. Build web cliente/equipo publicado a :8081/:8080 con cache versionado; API Nest PID 10208. Cliente/Equipo/API local y Tunnel HTTP 200; SHA-256 remoto/local coincide para ambos bundles JS y Cliente contiene la guarda QR. Cloudflare PID 8940 activo, hash `.env` igual; clon temporal eliminado y QA base intacta. Falta aceptación visual autenticada con QR real. El analyzer global conserva 25 infos existentes y el Release imprime advertencia Wasm/Cupertino (build JS completó); auditar iconografía/fuentes antes de cerrar QA visual.

La prueba roja en clon QA confirmó que `POST /pedidos` público aceptaba un `pagos[]` desde un cliente (HTTP 201); la ruta podía usar esos importes para actualizar `monto_pagado` y pagos aunque no había pasarela ni confirmación de recaudo. El método seleccionado en Checkout (`efectivo`, `Nequi` o `tarjeta`) también podía activar asiento en Caja para recogida/encargo. En POS, crear para llevar con un solo método y propina dejaba `monto_pagado=0` porque la rama de propina omitía el cobro. Se corrigió en Nest: pago público declarado se rechaza, método cliente no genera recaudo, el POS exige el permiso `cobrar_pedido` para pagos y cobros implícitos, pago mixto solo aplica a `para_llevar`, y el cobro simple POS registra movimiento, fila `pagos_pedido`/propina y saldo pagado. El E2E de mesero prueba preferencia efectivo sin recaudo y pago mixto denegado (403); Caja prueba cobro + propina en turno (900; diferencia 0); Checkout rechaza el campo `pagos` y queda sin abono/movimiento. Evidencia roja/verde y alcance en `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`. Verificación: `npm run build` OK; `npm test -- --runInBand` 51 suites/128 pruebas; `npm run test:e2e -- --runInBand` 8 suites/40 pruebas. QA corrió con `FOODY_QA_SIN_EFECTOS=1` sobre clon desechable de `foody_diseno_qa`; Nest :3001 se detuvo y clon se eliminó. Se reinició con `scripts/iniciar-backend-wsl.bat`; el nuevo PID 9008 sirve build actual y la ruta de historial respondió `NO_ENCONTRADO` (404 de dominio) local/Tunnel, con salud y los dos sitios en HTTP 200. `cloudflared` PID 8940 permanece activo. No se cambió OAuth, credenciales ni datos de negocio. Sigue pendiente PED-TIP-REQUEST-01: una propina elegida en checkout queda guardada antes del cobro en `propina_acumulada`; definir/cubrir el estado “solicitada” separado de lo efectivamente recaudado.

## 2026-11-25 — RBAC-TENANT-01: prueba cross-tenant automatizada en clon

`scripts/verificar-idor-scope.ps1` ahora acepta modo opcional de dos tenants, bloqueado salvo que `FOODY_QA_DATABASE` tenga prefijo `foody_diseno_qa_codex_rbac_`, `FOODY_QA_CROSS_TENANT_ADMIN` sea `@qa.example` y se proporcione `FOODY_QA_CROSS_TENANT_BRANCH`. En el clon temporal, el propio script sembró un admin sintético copiando el hash demo dentro del clon, abrió una caja del tenant B, probó cierre desde admin A (403) y confirmó que siguió abierta. Las otras comprobaciones RBAC también pasaron. Prueba inicial encontró y corrigió el parseo del ID de caja (`POST /caja/abrir` puede devolver 201 sin `datos.id`; el script recupera la caja activa). Repetición completa: 10 verificaciones OK. Nest QA corrió con `FOODY_QA_SIN_EFECTOS=1` en :3001; luego se detuvo, el clon fue eliminado y la QA persistente quedó con 3 restaurantes/4 sedes/45 usuarios/35 cajas, igual que al inicio. :3000 PID 19492 y servicios del Tunnel permanecieron intactos.

## 2026-11-25 — OPS-RUNTIME-01: guarda de arranque ante API antigua

El proceso activo :3000 (PID 19492) responde salud, pero devuelve `404 Cannot GET` para `GET /api/v1/caja/pedidos/:id/movimientos`, que sí existe en el source/build actual. Causa: `scripts/verificar-backend.bat` no probaba esa ruta; además `iniciar-backend-wsl.bat` podía compilar y tratar de arrancar una segunda instancia sobre :3000 cuando la API no pasaba sus probes. Añadí la ruta a la matriz de verificación y una salida segura: si el puerto está ocupado y falla cualquier probe, el iniciador no compila, no intenta enlazar otra instancia y no mata el proceso; muestra cómo hacer un reinicio controlado. Prueba real contra el estado actual: verificador exit 1; iniciador muestra el error esperado y exit 1; PID 19492 sigue escuchando, no hay :3001 y cloudflared PID 8940 permanece activo. El fix evita un falso “ya está listo” y una colisión; la API actualizada todavía requiere reinicio controlado para publicar las rutas nuevas. Sin cambios a OAuth, secretos, Tunnel ni datos comerciales.

## 2026-11-25 — Revalidación RBAC en clon aislado

`verificar-idor-scope.ps1` pasó contra Nest QA `127.0.0.1:3001` y un clon temporal de `foody_diseno_qa` (`foody_diseno_qa_codex_rbac_20261125`) con servicios externos deshabilitados: reportes financiero, timeline de auditoría, configuración de caja y reportes de domiciliarios para sede ajena devolvieron 403; gerente costeo de su sede y admin reportes según la matriz devolvieron 200; cierre de caja de otra sede devolvió 403 y la verificación posterior confirmó que siguió `abierta`. API salud QA 200. Al finalizar se detuvo solo el PID QA 5348, se eliminó el clon y se verificó que la base QA original sigue presente, :3001 sin listener y API principal :3000 PID 19492 intacta. Sin cambios a Tunnel, OAuth, credenciales ni datos reales.

## 2026-11-24 — RBAC-TENANT-01 evidenciado: el cierre lee la caja bajo `FOR UPDATE`, autoriza con la sucursal real desde la fila y solo después expira QR, verifica operación abierta y escribe cierre/auditoría. Unitarias con `CajaService` + `SucursalScopeService` reales y `verificar-idor-scope.ps1` contra PostgreSQL QA: gerente Centro intenta caja Norte → 403; la caja permanece abierta. La prueba entre tenants distintos se realizó después en un clon QA el mismo día; ver la entrada “cierre de caja cross-tenant” abajo. No se tocó BD de negocio.
## 2026-11-24 — CLIENT-DEVICE-CAP-01 mitigado: secreto independiente de 256 bits por dispositivo en header; backend guarda SHA-256 y valida en tiempo constante. Migración aditiva 092 aplicada a BD local y QA aislada, sin alterar pedidos ni OAuth. Nest 7/7, Flutter 2/2, analyzer focalizado y build Nest OK. Web Cliente/Equipo y APK Cliente/Equipo Release reconstruidos; APK de 93,1 MB cada uno. Pruebas QA aislada: secreto válido permite historial vacío y cotización; secreto incorrecto devuelve 403; registro conflictivo no reemplaza el secreto original. CORS admite el header y Tunnel/API/frontends siguen HTTP 200. Pendientes: riesgo del primer enrolamiento legacy, XSS en almacenamiento Web, recuperación/rotación y actualización de APK en dispositivos. Ver `AUDITORIA_CLIENTES_QR.md`.
## 2026-11-24 — KDS “Todo listo” resiliente: la acción por lote comunica éxitos parciales, deja de enviar cambios tras el primer fallo, vuelve a cargar el ticket y permite reintentar pendientes. Widget KDS 11/11; Flutter global 210 aprobadas, 5 omitidas, 0 fallidas; analyzer focalizado limpio. Launcher scripts/iniciar1 completó builds release Cliente/Equipo; los seis endpoints local/público (Cliente, Equipo, API salud) HTTP 200; PID API :3000 7564 conservado y cloudflared ya activo. Sin cambios backend, OAuth, configuración ni datos. Build emitió avisos no bloqueantes sobre Wasm y fuente CupertinoIcons. QA autenticada/manual, impresora y dispositivo real siguen pendientes.

# Foody — avance del proyecto (documento vivo)

## 2026-11-25 — DOC-CONTACT-CONSISTENCY-01: cerrar contradicciones en auditoría de domicilios

Al contrastar la matriz del canal público con Flutter/Nest, los apartados históricos todavía describían teléfono opcional pese a que `CLIENT-DOM-CONTACT-01` estaba resuelto. La implementación exige teléfono válido de 7–15 dígitos en Checkout y DTO Nest para domicilio, nombre opcional; el POS solicita los tres datos de contacto/dirección. Reejecutado `flutter test --no-pub test/validar_telefono_checkout_test.dart` (3/3) y Jest DTO (1 suite/8 pruebas). Se actualizaron `AUDITORIA_PEDIDOS_CICLO_VIDA.md` para reflejar la regla actual y distinguir validación de fuente de activación runtime. Sin cambio de lógica, UI, OAuth, Tunnel ni datos.

## 2026-11-25 — COC-PAID-KDS-01: liberar líneas de Cocina tras cobro excepcional

Se reprodujo por lectura de contrato que una excepción admin/gerente podía cobrar con motivo un pedido de cocina incompleta, mientras el listado KDS lo mantenía visible y la escritura lo bloqueaba por `pagado` inmutable. Nest ahora permite avanzar solo líneas pendientes/preparando del pedido totalmente cobrado, no regresarlas a pendiente ni modificar estado/movimientos de pago. El widget KDS prueba chip «Cobrado» y acción; `kds_screen_test.dart` 15/15, analyzer focalizado limpio; Nest 2 suites/9 unitarias y `npm run build` OK. Se agregó el E2E de cierre a Cocina al caso límite existente, sin ejecución contra PostgreSQL porque `:3001` está apagado. Lectura de runtime: :3000 PID 20152 inició 04:25; `dist/main.js` nuevo 05:41; salud local y Tunnel 200 no demuestran código cargado. Activación/E2E QA aislado pendientes; ninguna configuración, secreto o dato de negocio cambió.

## 2026-11-25 — FIN-MESA-TIP-TRACE-01: atribución de propina en cuenta de mesa

En `PedidosPagosService.cobrarCuentaMesa()`, la propina acumulada se reparte entre tickets por el importe asignado, pero la fila de cada método de pago (incluida su fracción de propina) enlaza solo con `pedidoRef`. No se pierde el total cobrado, aunque un reporte por pedido puede atribuir propina al ticket representativo en vez de distribuirla como `propina_acumulada`. Se documentó el hallazgo en la auditoría de Caja; la solución depende del modelo aún pendiente para transacción mesa→tickets y reembolsos parciales. Sin cambio de código ni esquema.

## 2026-11-25 — FIN-TIP-CANCEL-01: propina cuando se cancela un pedido

El usuario aclara que el pedido se cobra por su valor completo; la propina es voluntaria y se registra aparte. La revisión de `PedidosEstadoService`, `CajaMovimientosService.revertirVentasPedido()` y `CajaService.cerrar()` encontró que cancelar revierte ventas por caja/método y deja intactas las propinas ya recibidas; el cierre las cuenta por turno usando `pagos_pedido.created_at`. El comportamiento conserva el registro de lo efectivamente cobrado, pero no permite saber si esa propina se devolvió al cliente o ya fue liquidada al personal. Decisión pendiente: tratamiento de propina en cancelación y método de registrar devolución/liquidación. Solo auditoría/documentación; sin cambios de lógica, credenciales o datos.

## 2026-11-25 — Revalidación focalizada COC-NODISP-CUSTOMER-01

Para evitar repetir la regresión global, corrí solo `test/flujos/cocina.e2e-spec.ts` contra Nest temporal en `127.0.0.1:3001` y PostgreSQL QA `foody_diseno_qa` con `FOODY_QA_SIN_EFECTOS=1`: 1 suite, 7/7 pruebas. Incluye pedido con línea marcada `no_disponible`, seguimiento mediante token que contiene nombre/cantidad y rechazo del despacho mientras el total no se ajusta. Preparé QA por URL explícita a la base de diseño; logs confirman Firebase, Wompi, impresión, Realtime y crons desactivados. Ejecuté `scripts/limpiar-demo-qa.ps1` (sin pedidos activos que cancelar; limpió 13 trabajos QA de impresión y anonimizó 1 device de prueba), luego cerré el proceso QA. Confirmación final: :3001 sin listener, API :3000 PID 10208, salud local/pública, Cliente, Equipo y Tunnel HTTP 200; `cloudflared` PID 8940 intacto. No se tocó BD de negocio, OAuth o credenciales. Quedan regla comercial de ajuste/reembolso y revisión visual autenticada.

## 2026-11-25 — FIN-GASTO-DATE-01: aclaración de periodos de gastos

La lectura cruzada de `AnaliticaService.caja()`, `rentabilidad()` y `FinanzasService` confirmó tres medidas distintas: libro de gastos por fecha de registro (`created_at`), P&L por fecha operativa (`fecha`) y egresos de Caja por `movimientos_caja`. Los gastos manuales retroactivos no escriben movimiento de caja. La interfaz ahora muestra “Fecha de registro” y explica que Rentabilidad filtra por fecha del gasto y que no todos los gastos afectan arqueo. Flutter `analitica_caja_screen_test.dart` 5/5 en 320/390/820/1440; analyzer focalizado sin issues. No se alteraron consultas ni importes; unificar el calendario financiero queda como decisión de producto/contabilidad.

## 2026-11-25 — FIN-TIP-01: atribución temporal de propinas

`CajaService.cerrar()` ahora suma `pagos_pedido.propina` por sucursal dentro de la ventana `cajas.apertura_at` → momento del cierre, eliminando el error de atribuir propinas según cuándo se creó el pedido. Prueba unitaria focalizada 2/2 y E2E Caja 8/8 en clon temporal: el pedido se creó antes de abrir la nueva caja, recibió abono mixto efectivo/tarjeta con propina $600 y pago final por transferencia con propina $800; cierre `propinas_turno=1400`, diferencia cero. Se actualizaron las auditorías de Caja, ciclo de vida e informe maestro. Siguen pendientes política sobre propina en efectivo, pasivo/reparto y liquidación al personal, más escenarios con abonos que crucen turnos. La base QA original no se usó para escrituras; el clon y Nest :3001 se retiraron. No se cambió la política ni se modificaron datos reales. El build fuente no se activó en :3000/Tunnel para conservar el servicio en ejecución.

## 2026-11-25 — Revalidación DOM-INDEP-SETTLE-01

Se recorrió de nuevo la ruta de comisión independiente: `responderOferta()` inserta `ganancias_domiciliario` al aceptar, calculada sobre `costo_domicilio`; el porcentaje se configura con `comision_domiciliario_porcentaje` y usa 15% de fallback. La fila nace con `pagado=false`. El API expone lecturas de ganancias/resumen, pero en `foody_backend/src` y Flutter no hay mutación de ese flag, ni pago/comprobante/salida de caja para el independiente. La etiqueta `Liquidar` y el endpoint `POST /domiciliarios-planta/liquidar/:id` corresponden únicamente a recaudar CxC en efectivo de repartidor de planta; escriben CxC, pago y movimiento de venta en caja (entrada de dinero a la sede), no payout.

Además, `SuperAdminService.estadisticas()` suma `comision_foody` creada hoy como `ingresos_foody_hoy`, aunque no acredita que Foody haya recibido esos fondos; el resumen de independientes calcula `por_pagar` sin excluir asignaciones canceladas. Evidencia estática contrastada en controller, servicios, migración 008 y UI. No se alteraron reglas ni datos: definir pagador, evento de devengo, trato de cancelaciones, pago parcial/medio/comprobante y asientos antes de implementar una liquidación.

**Revalidación de etiqueta e importe (2026-11-25):** `comision_domiciliario_porcentaje` se almacena como 15 y `ConfiguracionGlobalService` lo divide entre 100 antes de multiplicar `costo_domicilio`; confirma comisión de 15% del domicilio, no del subtotal de productos ni de la suscripción Foody. El campo API sigue llamándose `ingresos_foody_hoy`, pero la tarjeta ya se presenta correctamente como “Comisión estimada hoy” y dice que aceptar oferta no confirma recaudo. Prueba existente `flutter test --no-pub test/foody_control_kpi_test.dart`: 2/2; `flutter analyze --no-pub lib/features/admin/presentation/panel_foody_control_screen.dart test/foody_control_kpi_test.dart --fatal-infos`: limpio. Sin cambio de código.

## 2026-11-25 — Revalidación runtime Tunnel/Nest

Smoke de solo lectura: `http://127.0.0.1:3000/api/v1/salud`, salud por `https://api.foodyy.store`, `https://foodyy.store` y `https://equipo.foodyy.store` respondieron HTTP 200; `cloudflared` PID 8940 continúa activo. El proceso Nest PID 19492 inició 2026-11-24 19:30 y `foody_backend/dist/main.js` se compiló 2026-11-25 00:22. `curl.exe -sS -i` a `GET /api/v1/caja/pedidos/<uuid>/movimientos` sin sesión devuelve 404 `Cannot GET`, confirmando que la ruta nueva no está registrada por el proceso activo. No se reinició Nest ni se tocaron OAuth, `.env` o datos. Pendiente activación con la rutina de arranque habitual y verificación autenticada.

## 2026-11-25 — Reconciliación documental RBAC

Se cotejó la evidencia registrada del clon PostgreSQL QA del 2026-11-24: administrador del tenant A intentó cerrar una caja del tenant B, recibió HTTP 403 y un `SELECT` posterior confirmó que B seguía `abierta`. La implementación actual de `CajaService.cerrar()` consulta la caja bajo bloqueo y valida `fila.sucursal_id` antes de efectos. `AUDITORIA_RBAC.md`, `AUDITORIA_OWASP.md` y el roadmap aún presentaban esta prueba como pendiente y tenían obsoletos los estados de cobro mesero/cola global; se reconciliaron los estados y se aclaró que la prueba cross-tenant no está en el script reproducible y no se repitió hoy. Solo lectura/documentación: sin cambio de código, datos ni permisos.

**Refuerzo del verificador de Caja:** `scripts/verificar-idor-scope.ps1` ahora consulta la caja por su sede después del intento denegado y exige mismo ID + estado `abierta`, no solo HTTP 403. El parser de PowerShell pasó. El E2E no se ejecutó: en esta revisión no había listener QA en `:3001`; la prueba histórica cross-tenant sigue sin automatizarse.

## 2026-11-25 — COC-NODISP-CUSTOMER-01

El endpoint público de seguimiento devolvía estado general e historial, pero no las líneas que Cocina había marcado como no disponibles. En domicilios, Cocina puede resolver el ticket como `listo` mientras la barrera de despacho impide asignar/repartir; el cliente podía ver “listo” sin conocer el faltante. `PedidosService.obtenerEstadoPublico()` ahora devuelve `items_no_disponibles` (nombre y cantidad) dentro del pedido ya autorizado por token/capability; `SeguimientoPedidoScreen` presenta un aviso informativo que aclara que el total aún no se ajustó. No se toca precio, estado, cobro, despacho ni permiso.

Verificación: `npm test -- --runInBand` 50/50 suites, 127/127; `npm run build` OK; `scripts/verificar-e2e-jest.ps1 -ApiHost http://127.0.0.1:3001` 8/8 suites, 37/37 con `foody_diseno_qa`; Flutter widget responsive 5/5 (320/390/820/1440) y analyzer focalizado limpio. Fixture QA restaurado, Nest QA temporal detenido. Salud local y Tunnel 200; el Tunnel conserva proceso viejo y aún no sirve el cambio. Sin OAuth, credenciales ni datos de negocio modificados.

## 2026-11-25 — FIN-TIP-01: precisión de evidencia en auditoría

La revisión de `PedidosPagosService`, `PedidosCajaAuditoriaService`, migración 047 y `CajaService.cerrar()` confirma que el pago guarda propina y método/fecha en `pagos_pedido`, pero el movimiento de caja recibe solo el monto del pedido. El cuadre de cierre excluye propinas y `propinas_turno` se calcula por fecha de creación del pedido, no por momento/medio del pago. Esto puede desalinear el resumen del turno y la diferencia de caja según cómo el restaurante retenga o entregue las propinas. Se precisó el hallazgo en `AUDITORIA_CAJA.md`, `AUDITORIA_PEDIDOS_CICLO_VIDA.md` e `INFORME_MAESTRO_FOODY.md`. No se alteró código, política comercial ni datos. La decisión de reparto/pasivo y conciliación sigue pendiente; las variantes requieren pruebas en QA una vez definida.

## 2026-11-25 — AR-17 / NAV-PED-MOVEMENT-01

El detalle del pedido abre Caja conservando `pedido_id` (incluido en el deep link). Nest añade `GET /caja/pedidos/:pedido_id/movimientos`, protegido por `ver_caja` y scope de sede, con NotFound para pedidos ajenos; el DTO acepta `sucursal_id` junto a la paginación. Caja presenta movimientos ligados al pedido aunque pertenezcan a un turno cerrado o no haya turno abierto; montos/pagos no se mutan. Índice parcial de migración 093 aplicado únicamente a `foody_diseno_qa`. Validación: Nest 50 suites/127 pruebas unitarias, build OK; E2E oficial 8/8 suites y 37/37 pruebas, incluye creación, cobro, cierre de caja y consulta histórica; Flutter 269 aprobadas/5 omitidas/0 fallidas y analyzer focalizado limpio. El preparador `limpiar-demo-qa.ps1` ahora abre horarios solo en QA, evitando cierres nocturnos del fixture; BD QA restaurada, Nest QA :3001 detenido. Release candidato Equipo compilado sin publicar. El API público/local `:3000` todavía es anterior al build (PID 19492; inicio 2026-11-24 19:30, `dist/main.js` 23:37), por eso el endpoint responde 404 aunque salud responda 200; Cloudflare y sitios siguen 200. Falta activar el backend mediante la rutina de arranque permitida y verificar el endpoint autenticado en Tunnel. No se tocaron OAuth, credenciales ni movimientos comerciales.

## 2026-11-24 — CAT-AVAILABILITY-UX-01

Los controles de disponibilidad de Producto en tabla y tarjeta no informaban envío ni capturaban excepciones. Ahora usan un switch con Semantics/nombre del producto, bloqueo por ID y progreso; mantiene el listado durante la reconsulta. Un fallo conserva el estado no optimista e informa error con acción Reintentar. Widget `menu_admin_screen_test.dart` 13/13, analyzer pantalla/test limpio. Equipo Release publicado; HTTP local/Tunnel 200 y JS público (6.57 MB) igual por SHA-256 al build (`39c976…987735665`); `.env` hash conservado y Cloudflare PID 8940 activo. Sin cambios de backend ni datos.

## 2026-11-24 — UI-USR-DEACTIVATE-01

La tarjeta móvil y la tabla de Usuarios ejecutaban desactivación sin confirmación, aunque el efecto real es que Auth rechaza el acceso de una cuenta inactiva. Se añadió diálogo Foody con nombre y consecuencia; “Mantener activo” cancela sin llamada, “Desactivar acceso” conserva el PATCH existente, y reactivar continúa inmediato. Pruebas en 390/1440 verifican cancelación, llamada única y estado actualizado; total de la suite de Usuarios 6/6 y `flutter analyze` de pantalla/test sin incidencias. Equipo Release compilado y publicado; HTML local/Tunnel 200 y JS público SHA-256 idéntico al build (`885d5a…b759ffa`); `.env` hash sin cambio; `cloudflared` PID 8940 activo. No se cambiaron permisos, backend ni datos de negocio.

## 2026-11-24 — UI-INV-SELECTOR-01

Se contrastó DS-08 con el código: `InventarioSeccionSelector` ya cambia cinco tabs por un menú selector en compacto y conserva las pestañas en escritorio. Prueba `flutter test test/inventario_seccion_selector_test.dart --reporter expanded`: 6/6, incluye selección y 320/390 claro/oscuro + 820/1440. Roadmap y auditoría visual actualizados; F6-08 permanece parcial porque la reorganización en sub-nav de escritorio y aceptación visual autenticada siguen abiertas. No se modificó código de producto.

## 2026-11-24 — Runtime Nest aún no aplicado

Lectura del listener :3000: PID `19492`, iniciado 19:30, ejecuta `node -r dotenv/config dist/main.js`; el archivo `dist/main.js` es de 21:22:34. API local respondió `/api/v1/salud` HTTP 200, pero eso no acredita el build cargado. Un reinicio controlado fue rechazado por la política de ejecución antes de correr; proceso y Tunnel no se tocaron. `cloudflared` PID `8940` activo. Pendiente iniciar Nest por una vía permitida y comprobar el build nuevo; no modificar `.env`, OAuth, credenciales ni datos comerciales.

## 2026-11-24 — PED-WAITER-PAYMENT-01

En `PedidoCajeroScreen`, `modoMesero` no muestra controles de pago, pero el DTO recibía el valor inicial `efectivo`; el backend persiste el método enviado. Se inicializó `pendiente` solo para mesero, manteniendo el default `efectivo` para POS cajero. `flutter test test/pedido_cajero_screen_test.dart --reporter expanded`: 18/18; `flutter analyze` de los dos archivos: sin issues. Cliente y Equipo Release reconstruidos a candidatos, publicados y verificados por hash SHA-256 idéntico al servido. Cliente/Equipo/API salud local y Tunnel: seis respuestas HTTP 200; `cloudflared` PID 8940. Hash de `.env` igual antes/después; no se modificaron OAuth, credenciales ni datos de negocio. Aceptación visual autenticada pendiente.

## 2026-11-24 — QA-PRINT-BYPASS-01 / COC-CANCEL-NODISP-MERMA-01
La E2E de cancelación con línea no disponible pasó 1/1 sobre un clon QA aislado. Se corrigió una vía que permitía que `procesarCola()` intentara contactar la impresora aunque `FOODY_QA_SIN_EFECTOS=1`; ahora el procesamiento de cola y la verificación de conexión retornan sin I/O externo. Unitarias 2/2, build Nest y Prettier OK. Log QA confirmó “Procesamiento de impresión bloqueado en QA aislada”; el clon fue eliminado y :3001 detenido. `/salud` local y Tunnel 200, Cloudflare activo. La política de merma sobre líneas aún pendientes sigue sin definirse; el API :3000 aún no está activado con el build actualizado.

## 2026-11-24 — COC-DISPATCH-INCOMPLETE-01 E2E
Nueva E2E de domicilio incompleto pasó 1/1 en clon aislado: al crear pedido con ítem pendiente, Nest rechazó marcarlo globalmente `listo`; la asignación manual de planta respondió 400, y el dispatch independiente respondió `iniciado=false`, motivo `PEDIDO_NO_LISTO`. El detalle mantuvo estado `en_cocina`. Guard unitario de despacho 5/5. QA :3001 detenido y clon removido; API local/Tunnel health 200, Cloudflare activo. No activé el build en :3000.

## 2026-11-24 — PED-EDIT-01 E2E en pedido/abonos
Cuatro escenarios E2E pasaron en clon PostgreSQL QA: modificar observaciones tras `listo` reabre Cocina y marca la línea pendiente; reducir cantidad, eliminar o reemplazar un ítem cuando el nuevo total quedaría por debajo del abono devuelve 409. En los tres rechazos, el detalle posterior conserva el total de 16.000 COP, el abono de 15.000 COP y las dos líneas originales, comprobando rollback. QA detenido/eliminado; API local y Tunnel health 200. El proceso :3000 sigue pendiente de activar el build más reciente.

## 2026-11-24 — FIN-MIXED-REFUND-METHOD-01 E2E
Cancelación con abono mixto pasó 1/1 en clon PostgreSQL QA. La E2E compara movimientos originales y devoluciones por medio (efectivo/tarjeta), y valida que el total devuelto sea igual al abono, con conciliación neta en Caja. Clon eliminado y :3001 detenido; API local/Tunnel health 200, Cloudflare activo. :3000 aún requiere activar el build probado.

## 2026-11-24 — QA-FCM-BYPASS-01 y regresión completa
`NotificacionesService.procesarPendientes()` ya se bloquea al inicio en `FOODY_QA_SIN_EFECTOS=1`; no consulta cola, incrementa intentos ni llama FCM. Prueba dedicada 1/1, build Nest OK, suite unitaria completa 48 suites/123 tests. E2E completa 8/8 suites y 36/36 pruebas con clon temporal: logs confirmaron el bloqueo de FCM e impresión. Para la ejecución se restauró el stock demo porque la primera corrida de diagnóstico detectó la papa demo agotada en una copia simple; la batería necesita la preparación que hace `scripts/limpiar-demo-qa.ps1`. Clon y :3001 se eliminaron/detuvieron; salud local/Tunnel 200 y Cloudflare activo. El API :3000 no cargó este build.

## 2026-11-24 — regresión Flutter global y ciclo de vida UI
`flutter test --no-pub`: 254 aprobadas, 5 omitidas, 0 fallidas. `flutter analyze --no-pub`: sin errores/advertencias y 25 observaciones INFO; exit 1 por esas infos (deprecaciones/estilo y tres contextos async del registro OAuth, sin cambios a ese flujo). Se corrigieron los ocho avisos async en Foody Control y el sheet de edición de pedido, que pasan `dart analyze` individual sin issues; pruebas focalizadas panel/pedidos 8/8. Sigue pendiente aceptación visual autenticada en escritorio y móvil. La selección CUA se detuvo porque había dos ventanas Chrome con título idéntico.

## 2026-11-24 — builds web release candidatos
Cliente y Equipo compilaron a `build/web_cliente_candidate` y `build/web_equipo_candidate` (sin sobrescribir las carpetas publicadas). Los dos JS rondan 6,57 MB. Avisos no bloqueantes de Wasm y manifest de CupertinoIcons; no hay referencias directas a CupertinoIcons en `lib/`. Candidatos no publicados porque :3000 aún corre el proceso anterior y falta aceptación visual autenticada.

**Última actualización:** 2026-11-24 — RBAC-TENANT-01 validado con prueba unitaria, QA PostgreSQL autenticada cross-sucursal y clon QA cross-tenant: caja ajena → 403 y permanece abierta. `RBAC-GUARD-01/02/03`: borrar dispositivo requiere posesión, push web se limita al usuario y cola global exige `SuperAdminGuard`; suite focalizada 8/8. API `:3000` reiniciada al build de aquel corte (PID 19492), salud local/pública 200 y endpoint de cola sin sesión 401 local/Tunnel; Tunnel sigue arriba. Falta incorporar el caso cross-tenant al script reproducible y ampliar la matriz a otros módulos. Auditoría sigue abierta.

## 2026-11-24 — PED-POS-CAP-01 y estado vacío del POS

Se corrigió la estimación de pedidos de Equipo: antes la ruta pública `/pedidos/estimar` rechazaba el `device_id` sin capability y dejaba Confirmar bloqueado. `PedidosRepository` registra capability y adjunta el mismo header. Pruebas de repositorio 5/5 y POS 17/17; analyzer focalizado limpio. En Equipo autenticado por Tunnel, producto demo de 35.000 COP cotizó en servidor y habilitó Confirmar; no se confirmó ni guardó pedido. El primer uso actualizó solo metadata técnica del dispositivo. Carrito vacío ahora indica agregar productos y no muestra reintento. Build Cliente/Equipo release en curso; modo `tunel` y credenciales sin cambios.
## 2026-11-24 — Reejecución E2E y salud del entorno

Jest E2E QA: 8 suites/32 pruebas; scripts operativos: 9/9, incluido IDOR entre sucursales. Los fixtures QR/numeración envían la capability requerida y sus dispositivos sintéticos se anonimizan al cerrar; el runner prepara datos solo si confirma `localhost:3001`. Flutter: 248 aprobadas/5 omitidas/0 fallidas; `flutter analyze` global: 0 errores, 0 warnings y 33 infos. Se detuvieron API QA `:3001` e impresora temporal `:8765`; `:3000`, `:8080`, `:8081` y Tunnel permanecen activos. No cubierto: impresora/teléfono físicos, prueba de carga, aceptación visual autenticada y E2E entre tenants diferentes.
**Última actualización:** 2026-11-24 — **START-TUNNEL-1033-01:** los scripts ya no consideran saludable un `cloudflared` solo por existir; el launcher comprueba Cliente, Equipo y API públicas. El conector se reabrió usando `--token-file` en archivo temporal con ACL limitada al usuario actual. Verificación al cierre: los seis destinos local/público devolvieron HTTP 200. No se cambió `.env`, OAuth, credenciales ni datos comerciales. El token del túnel fue impreso accidentalmente en una salida de diagnóstico; queda pendiente su rotación autorizada, aunque el proceso actual no lo expone en argv. **DASH-LONG-DELAY-01:** el widget convierte minutos extensos a días+horas; prueba 9/9 y analyzer focalizado limpios; release visible confirmado. No se concluye la auditoría de todos los flujos.

**Actualización histórica (2026-11-24):** POS conserva la clave al reintentar la creación de un pedido (PED-STAFF-IDEM-01) y agregar líneas a un pedido abierto (PED-ITEM-IDEM-01). E2E confirma que un reintento igual no duplica y un payload distinto con la misma clave devuelve 409. QA visual autenticada sigue pendiente; sin cambios comerciales.
**Última actualización:** 2026-11-24 — Cliente/Equipo Release reconstruidos y publicados. El launcher falló en Windows PowerShell `-NoProfile` al resolver `Get-FileHash`; el publicador calcula ahora SHA-256 con .NET, ambos bundles cache-busted y byte a byte iguales local/Tunnel. BAT `scripts/iniciar1` exit 0; Cliente/Equipo/API salud local/público HTTP 200; API PID 14644, `cloudflared` PID 11112, `.env` sin cambios. Finanzas 9/9, Menú 10/10, Nest 29/66, Flutter 220/5 omitidas.
**Analítica — validación de estados en Rentabilidad (2026-11-24):** se verificó que el filtro compartido excluye cancelados/rechazados por defecto y permite estados explícitos; no se modifica lógica de producción. Prueba de regresión cubre ambos casos; build y unitarias Nest 29 suites/65 pruebas. API :3000 sincronizada con el build actual (PID 17080), local/pública HTTP 200; `cloudflared` PID 11112 y hash de `.env` intactos. Flutter global 219 aprobadas/5 omitidas; análisis global sin errores/warnings y 36 infos existentes.
**REP-DEFAULT-DATE-TZ-01 (2026-11-24):** rango por defecto en Reportes obtiene la fecha con `America/Bogota`, corrigiendo el desfase después de las 19:00 locales. Prueba controlada, build + unitarias Nest 29/66. API :3000 activada PID 14644; salud local/pública HTTP 200, `cloudflared` PID 11112 y `.env` intactos. Flutter global 220/5 omitidas.
**CAJ-REFUND-TRACE-01 (2026-11-24):** devolución manual registra monto/motivo como salida de efectivo sin vincular pedido o ítem; Caja neta la resta pero P&L mantiene los ingresos por pedido no cancelado. Falta decisión sobre reembolsos parciales, medio original, COGS y retorno a inventario/merma; hallazgo en `AUDITORIA_CAJA.md` y `AUDITORIA_REPORTES.md`. No se cambió el flujo ni se registraron pagos.
**MENU-LOAD-PARALLEL-01 (2026-11-24):** las colecciones base del catálogo/cocinas ya parten concurrentes y costeo carga después de presentar Menú; respuestas de una carga vieja no reemplazan la sede activa. Test `menu_admin_screen_test.dart` 10/10; suite Flutter 220/5 omitidas/0 fallidas; analyzer del módulo limpio. No se midieron milisegundos de red externa.
**Aislamiento por sede:** pedidos, KDS y domiciliarios revisados en controladores y filtros; prueba `SucursalScopeService` 4/4 (sede propia, sede hermana, otra empresa/inactiva y permiso corporativo). No se detectó fuga demostrable en el alcance; faltan pruebas E2E autenticadas entre tenants y módulos no revisados.
**FIN-FIXED-PARTIAL-BALANCE-01 (2026-11-24):** Finanzas ahora muestra el saldo del costo fijo mensual tras abonos parciales, filtrado por sede, origen fijo y fecha del mes. Unitaria Finanzas 2/2; SQL equivalente probado en PostgreSQL QA con fixtures temporales y transacción revertida; build OK. Se activó Nest en :3000; salud local/pública 200, Tunnel activo. Nómina y periodos históricos siguen sin cambios por requerir política contable.
**Próximo paso recomendado:** continuar trazabilidad de Pedidos → Cocina → Caja → Finanzas/Análisis; acordar archivo/revisión de tickets KDS antiguos y tratamiento contable FIN-TIP-01.

## 2026-11-24 — Activación Nest y verificación de acceso remoto

Tras `npm run build` y E2E en la instancia QA aislada, Nest de uso diario se reinició con `npm run start:prod` para activar en `:3000` los fixes de código revisados. Salud API local y `https://api.foodyy.store/api/v1/salud` respondieron HTTP 200; `https://equipo.foodyy.store/` y `https://foodyy.store/` respondieron HTTP 200. Cloudflared conservó el PID 11112 y los web servers locales siguieron activos. No se modificaron rutas/DNS, OAuth, credenciales ni datos de negocio.

## 2026-11-24 — FIN-SPLIT-OVERCHARGE-01: split no puede sobrepasar saldo

El split por ítem sumaba solo cantidad × precio base y no comprobaba el saldo de cada ticket tras un abono. Esto permitía aceptar un split que superaba lo pendiente y registrar el excedente en Caja. `PedidosPagosService` ahora reutiliza `SQL_VENTA_LINEA_ITEM` para incluir toppings/bebidas, distribuye el descuento proporcionalmente y rechaza si el valor neto de ítems de un ticket excede su saldo; el rechazo ocurre antes de cualquier escritura. El E2E `FIN-SPLIT-01` comprueba rechazo, cero movimientos nuevos en Caja, split válido en otro ticket y cierre del remanente. Unitarias 26/57, E2E Nest 8/22, `npm run build` y la batería `verificar-todos-e2e.ps1` 9/9 pasan en la base QA aislada. Se actualizó el script F-17 para intentar el ticket que aún conserva saldo. No se reinició Nest :3000 ni se alteraron Tunnel/OAuth/credenciales/datos comerciales; `:3000` aún no sirve el fix. QA operativa limpiada; proceso :3001 y agente de impresión temporal detenidos. Hallazgo y límite de extras+descuento dedicado en `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

## 2026-11-24 — Operaciones masivas KDS recuperables

COC-ALL-READY-UX-01 y COC-RETURN-UX-01: “Todo listo” y “Volver a cocina” evitan doble envío por ticket, hacen cambios secuenciales, paran al primer error, refrescan el ticket y comunican qué quedó aplicado. Si la reversión es parcial, la vista cambia a Cocina para que el pedido siga visible. Widget KDS 12/12; regresión Flutter 211 aprobadas/5 omitidas/0 fallidas; analyzer focalizado limpio. `scripts/iniciar1/iniciar-foody-subdominios.bat` reconstruyó Cliente/Equipo. Seis endpoints local/público (frontends y API salud) HTTP 200; ambos bundles públicos coinciden byte a byte con el build local: Cliente SHA-256 `3FEBF2CEA21595853506AAF7870DABC16C57A5E156865F181FA86C0E6D221239`, Equipo `9C8287E1883D2C2531D5E5D7AABE69F51A8E8ACC5ED2330000038930E6DB8297`. :3000 PID 7564 conservado, Tunnel activo. Sin cambios backend/OAuth/datos. No hay atomicidad todo-o-nada; QA autenticada y hardware físico siguen pendientes. Warnings de build Wasm/CupertinoIcons no bloquearon.

## 2026-11-24 — DOM-READ-PARALLEL-01: lecturas del resumen

La pantalla administrativa solicitaba `/domiciliarios-planta/liquidacion/:sucursal` y `/domiciliarios-planta/domicilios/:sucursal` en secuencia, pese a que son lecturas independientes. Ahora inicia ambas simultáneamente en la carga y al refrescar; elimina una ida y vuelta serial sin alterar contratos ni cálculos. Prueba con dos `Completer` demuestra que ambas peticiones comienzan antes de que termine alguna. Widget Domiciliarios 5/5; suite Flutter global 212 aprobadas/5 omitidas/0 fallidas; analyzer focalizado limpio. Build público exacto: Cliente SHA-256 `826DA39FBE0316C0D6560730A9B1B9CC4030FE490353C2734FDC06BED401D5DD`, Equipo `9A19FE5B17816DE729381A7CE1C34BB5EC3A23BF55FA0F31F3C5259BD1D8356E`. Seis endpoints local/público HTTP 200; Nest :3000 no reiniciado, cloudflared preservado. Beneficio verificado en concurrencia de solicitudes, no medido en milisegundos frente a red externa.

## 2026-11-24 — DOM-STALE-01: mantener el panel durante actualización

El polling/Reatime llamaba `_cargar()`, que reemplazaba todo el módulo por skeleton; un fallo posterior también sustituía datos previos con un error de página completa. Ahora solo la carga inicial usa skeleton; las actualizaciones preservan la lista y, si falla la red, muestran error no bloqueante con Reintentar. Prueba inyecta GET pendiente y fallo: el contenido anterior permanece visible antes y después. Domiciliarios 6/6; Flutter global 213 aprobadas/5 omitidas/0 fallidas; analyzer limpio. Rebuild por launcher, ambos JS públicos idénticos a local: Cliente SHA-256 `ED08B4FA24504C97944F904B638C318721C1BB5B972A69D46FC06A05724B48D6`, Equipo `F0BBE643FDD23C3184CAAB0ED12F0AC309CD9D8EB91300DE8EF6BD18E5EEABBA`. Seis endpoints HTTP 200; Nest :3000 PID 7564 y Tunnel intactos.

## 2026-11-24 — Validación de fallo de preparación en KDS

`COC-MOTIVO-UI-01` (bajo, corregido): el diálogo aceptaba motivo vacío aunque Nest lo rechazaba, provocando una solicitud fallida evitable. Ahora presenta el impacto operativo (alerta, posible merma si stock ya descontado y producto desactivado en el menú), valida motivo localmente y solo envía texto no vacío. Widget test confirma que confirmar vacío no llama al repositorio; cuatro anchos KDS cubiertos. Verificación adicional: E2E aislada Cocina 3/3 y analyzer focalizado limpio. Informe histórico `AUDITORIA_COCINA_KDS.md` reconciliado con prioridad/reimpresión ya existentes. Riesgos pendientes: restaurar línea no disponible requiere política de ajuste/consentimiento/stock; “Todo listo” guarda PATCH secuenciales; impresión térmica no probada. No se reinició API :3000 ni se tocó Tunnel/OAuth/datos de negocio.

## 2026-11-24 — RT-BANNER-01 y backlog antiguo KDS

La inspección visual autenticada encontró que el banner de salud Realtime exponía una `DioException` completa cuando la consulta fallaba. Se reemplazó el detalle técnico por mensajes seguros para tres casos (no configurado, desconectado, no verificable), preservando polling, reintento y ocultar aviso. `flutter test test/realtime_aviso_banner_test.dart`: 2/2; suite Flutter: 216 aprobadas/5 omitidas/0 fallidas; `dart analyze --fatal-infos` focalizado limpio. El análisis global sí reporta 37 hallazgos preexistentes en archivos ajenos a este cambio (36 infos y una advertencia de miembro no usado); se deja como deuda general del repo. Bundle Equipo release reconstruido y servido por `:8080`, con SHA-256 idéntico entre archivo y Tunnel: `600684D3F80E18F8A32BED4226AF1CD44D60E0C0D32511CE8BDB3A9E7A98B807`. Los seis endpoints local/público revisados respondieron HTTP 200. La inspección también vio tickets de antigüedad extrema que continúan accionables en Cocina; se documentó como riesgo y decisión pendiente de archivo/retención, sin alterar pedidos. No se cambió configuración de Realtime/OAuth, no se reinició Nest `:3000` ni se tocaron datos comerciales.

**Continuación KDS — KDS-TIME-01 y cache-busting (2026-11-24):** los tickets de más de 24 h muestran días + horas; prueba a 112 días comprueba `112d 3h`, conserva “Marcar listo” y no toca el estado. Una sesión autenticada seguía cargando un Flutter antiguo aunque el JS público coincidía con disco; se actualizó el publicador para añadir la huella SHA-256 a las URL del bootstrap y Dart JS. La vista por Tunnel mostró entonces `112d 3h`. Build Cliente/Equipo servido; SHA-256 Equipo local/Tunnel `42831E2BE7CF4882C072A7AD49C147AFE931792D77262D6FEA211F059A805442`. Se ejecutó de nuevo el iniciador exacto `scripts/iniciar1/iniciar-foody-subdominios.bat`: exit 0 con `-SkipBuild`, ambos sitios locales arriba, API salud HTTP 200 y Cloudflare existente. No se tocó Tunnel/OAuth/credenciales/pedidos y no se reinició Nest :3000. KDS 13/13; Flutter global 217/5 omitidas/0 fallidas; analyzer focalizado limpio. Falta clasificar backlog antiguo y probar impresora/dispositivo real.

## 2026-11-24 — Orígenes y validaciones de pedido

`PED-CHANNEL-01`: mapeadas las entradas QR, checkout público y equipo (admin/mesero/cajero) hasta sus reglas de pedido/stock/cocina. QR E2E 2/2 verifica creación en aprobación y precio no controlado por cliente; Mesa E2E 2/2 verifica mesero crea y presenta cuenta, pero no marca listo ni cobra. Checkout entrega usa estimación Nest y exige dirección; DTO acepta nombre/teléfono vacíos mientras que POS sí pide ambos. Se recomienda teléfono requerido para domicilio público, nombre opcional para invitado; contrato queda sin cambio hasta definir regla. Se corrigió la auditoría histórica: hay 12 estados de pedido y el CHECK está en migración 089, no en 005. Detalles y evidencia en `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

## 2026-11-24 — Precaución de host en E2E de Mesero

`QA-HOST-01`: una reejecución manual de `mesa.e2e-spec.ts` después de aplicar formato omitió `E2E_HOST`; el helper usó el default anterior `127.0.0.1:3000`. La prueba de creación falló antes de persistir el pedido. Consultas de solo lectura confirmaron cero filas de historial con motivo `QA e2e jest cleanup` en la ventana y ninguna apertura reciente de caja. Sí se creó y luego desactivó el usuario sintético `mesero-e2e-a25de2b6-fa52-4417-bb0b-aad0af8b54d5@qa.example` (`62bb4d80-3cc5-4628-99b5-c880a1497633`); queda inactivo en la BD principal porque no existe una baja física segura. No se hizo ninguna otra escritura sobre `:3000`. Mitigación: el helper ahora usa `:3001` por omisión y bloquea cualquier host no QA antes del setup salvo `FOODY_E2E_ALLOW_NON_QA=1`; su bloqueo de `:3000` se verificó con la suite Mesa y no ocurrió petición HTTP. API salud, sitios local/públicos y Tunnel siguieron 200. Las E2E válidas de Cocina, QR y Mesero/Mesa fueron a `:3001` + `foody_diseno_qa`.

## 2026-11-24 — Viewport web y comprobación responsive de Inicio

`web/index.html` no declaraba el viewport estándar. Se agregó `width=device-width, initial-scale=1.0`. HTML local y publicado por Cloudflare Tunnel incluyen el meta; `main.dart.js` local/público coincide por SHA-256 `6DDFE125A8BA9A0A30B0E7E591CED512BE42FCE0FA87D90B2D228CC1326CFB05`. Chrome autenticado mostró Inicio en lectura a 1920×1040 con sidebar completa, 931×1013 con rail compacta y viewport móvil emulado a 320×866: tarjetas en dos columnas, etiquetas envueltas y scroll vertical sin recorte horizontal visible. La emulación no sustituye prueba en teléfono físico; la revisión de otras vistas continúa pendiente.

## 2026-11-24 — Cobro de varios tickets en cuenta de mesa

`FIN-MESA-SPLIT-01`: se identificó en E2E que al cerrar una mesa con varios tickets se guardaba el pago íntegro en un único pedido de Caja; el límite por ticket podía dejar otros tickets pagados sin movimiento financiero asociado. Ahora cada línea (efectivo/tarjeta/transferencia/Nequi) se asigna de forma secuencial al saldo de cada ticket, conserva pedido y método en `movimientos_caja`, y aborta la transacción si queda saldo de pago sin distribuir. E2E caja 4/4, incluye dos tickets con pago mixto y coteja importe/método por pedido. Suite E2E completa aislada: 8 suites/20 pruebas; unitarias Nest 26/57; build Nest OK. Se restauraron horario de fixture 08:00–22:00, ingrediente demo 10.000 g y disponibilidad de producto; :3001 detenido y :3000/Tunnel intactos. `FIN-TIP-01` sigue abierto: el cobro guarda propina separada, pero Caja no la registra; falta decidir su tratamiento contable. Detalle en `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

## 2026-11-24 — Inicio diario del Tunnel comprobado

Se ejecutó el acceso directo `scripts/iniciar1/iniciar-foody-subdominios.bat` con pausa deshabilitada para automatización; terminó con código 0. API :3000 pasó salud y el entorno se mantuvo en modo `tunel`. El chequeo `-SkipBuild` halló el build Cliente ausente/desactualizado y lo compiló; Equipo ya estaba al día. Ambos SPA quedaron activos en :8080 y :8081, URLs locales/públicas respondieron HTTP 200 y los bundles `main.dart.js` local y público de cada sabor coincidieron. Salud API local/pública `exito=true`; `cloudflared` mantuvo PID 11112. La sincronización informó entorno Flutter sin cambios; una inspección previa de los valores objetivo confirmó que el launcher no necesitaba modificar claves CORS/CLIENT_WEB_URL/WOMPI y el script no modifica OAuth, tokens ni datos. Cloudflare añade al HTML público su beacon de Insights. Los avisos de compatibilidad Wasm y font CupertinoIcons no impidieron compilar. No se reinició Nest.

## 2026-11-23 — KPI de cancelaciones en Análisis

`ANA-CANCEL-DENOM-01`: el total “Pedidos” omite cancelados mientras la tasa de cancelación los cuenta en el denominador. Se añadieron `pedidos_cancelados` y `pedidos_total_cancelacion` al resumen Nest; Flutter expone `N de total pedidos` y, hasta que el Nest anterior se reinicie, muestra “Sobre pedidos del periodo” sin inventar un conteo. Chrome confirmó que el KPI de alertas corresponde a pendientes actuales de toda la sede aunque el filtro sea 7 días; no se cambió ese alcance ni sus datos. Backend 1/1 + build OK; Flutter 2/2 + analyzer focalizado limpio. Build Equipo release (`APP_FLAVOR=equipo`, `usarTunel=true`) terminado; los cinco destinos locales/públicos de Cliente, Equipo y salud API dieron HTTP 200; cloudflared PID 11112 activo. No se reinició API ni se tocó OAuth, Tunnel, configuración o datos. Siguiente: publicar el contador exacto en API :3000 mediante reinicio coordinado y continuar revisión de vistas de Análisis.

`NAV-RAIL-COMPACT-01` (verificado): la captura del panel, 931 px de ancho, cae en breakpoint tablet 720–1099 y por eso muestra rail de 72 px; el menú compacto agrega tooltip por grupo y subopciones con etiquetas. No hay pérdida de módulos. Sigue pendiente revisar una ventana desktop completa y un móvil real.

## 2026-11-23 — Carga progresiva y consultas bajo demanda de Análisis

`ANA-PARTIAL-LOAD-01` (severidad media, corregido): antes de este cambio, `AnaliticaScreen._cargarResumen` esperaba el endpoint principal y cuatro consultas complementarias; un fallo en cualquiera activaba el error global y ocultaba KPIs válidos. Separé la carga: al resolver el resumen se muestran los indicadores, y el resto usa estado de carga; fallos secundarios conservan la página, identifican los paneles faltantes y permiten reintentar. `AnaliticaScreen._tabLazy` también programaba una solicitud para cada hijo al construir `TabBarView`; ahora la pestaña solo obtiene datos al seleccionarse. Un contador de revisión impide que respuestas de otro periodo/sede reemplacen la consulta actual. Pruebas Flutter 4/4; `flutter analyze --fatal-infos` limpio en las cuatro fuentes/tests tocados; Nest test 1/1 + build. Build Equipo release actualizado y verificado con hashes idénticos local/Tunnel, ambos de 6.522.544 bytes; Cliente/Equipo local y público + API salud HTTP 200; cloudflared PID 11112 sigue activo. No se reinició Nest :3000, ni se tocaron OAuth, configuración o datos. El nuevo contrato de cancelaciones requiere activar la API en ventana coordinada; el UI antiguo muestra contexto genérico mientras tanto. El build JS pasó; el dry-run Wasm y el asset CupertinoIcons siguen dando advertencias no bloqueantes.

> **Estado consolidado del proyecto:** **`docs/MASTER_STATUS.md`** (fuente oficial única — implementado/pendiente/problemas/módulos).  
> Este archivo conserva detalle por sprint, changelog y **Referencias persistentes** (BD, env, endpoints).

> **Los agentes deben leer este archivo al inicio de cada sesión de implementación y actualizarlo al terminar.**
> Regla Cursor: `.cursor/rules/foody-avance-documentar.mdc`
> Especificación objetivo: `INFRAESTRUCTURA/GUIA_DESARROLLO_FOODY_CURSOR.md` (sprints 1–11).

## 2026-11-24 — Analítica de Caja: separar libro y movimientos

`gastos_total` ahora suma únicamente el libro de gastos agrupado por categoría; `gastos_movimientos_caja` expone por separado los egresos que participan en conciliación. La pantalla identifica ambas medidas y aclara el alcance del gráfico. Si la API anterior omite el nuevo campo, la UI presenta “Dato no disponible” en vez de un cero falso. Regresión backend 1/1; tests de pantalla 5/5; build Nest OK. Bundle Equipo regenerado y contiene el KPI/fallback; Equipo/Cliente local, Equipo por Tunnel y salud API pública respondieron HTTP 200. El proceso API `:3000` no se reinició y Cloudflare Tunnel permanece como estaba; activación de fórmula backend en runtime pendiente de ventana coordinada. No hubo escrituras ni cambios de OAuth/entorno. Sigue abierto `FIN-DATE-01` y la política de anulaciones/reembolsos.

**Fechas y pagos de obligaciones:** fecha de gastos predeterminada ahora se deriva explícitamente de `America/Bogota` en Finanzas y Caja. Evita que UTC/PostgreSQL desplace el día y, en cambio de mes, clasifique el registro en el periodo incorrecto. Pruebas de frontera, Finanzas, Caja y Analítica: 4 suites/5; build Nest OK. Auditoría detecta `FIN-PARTIAL-01`: un pago parcial aceptado oculta todo el saldo pendiente; el periodo opcional no participa en la consulta, y frecuencias de nómina no tienen ciclos modelados. Documentado sin alterar el cálculo hasta definir los compromisos/cadencia. Fuente compilada, pero API `:3000` no reiniciada; Tunnel intacto.

**Comisiones/pagos de independientes:** se comprobó que la comisión configurable (15% por defecto) y el saldo del repartidor se escriben al aceptar oferta, antes de confirmar entrega. Super Admin los agrega como `ingresos_foody_hoy`, aunque eso no acredita recaudo. Equipo muestra “Por pagar”, pero no existe escritura que cambie el flag `ganancias_domiciliario.pagado` ni ruta para liquidar, a diferencia del flujo de domiciliario de planta. Hallazgo `DOM-INDEP-SETTLE-01` registrado en Informe Maestro; no implementar payout hasta definir quién paga, fuente, devengo, cancelaciones y comprobante. Se alinearon las consultas del día de Super Admin a Bogotá: total backend de esta etapa 5 suites/6 y build Nest OK. No se reinició :3000 ni se alteró Tunnel/datos.
**DOM-INDEP-SETTLE-01 — UI aclaratoria (2026-11-24):** KPI “Ingresos Foody hoy” cambió a “Comisión estimada hoy” y añade que se registra al aceptar la oferta y no confirma recaudo. Cambio de presentación únicamente, con prueba widget; comisión, montos y pagos intactos.
En el resumen del restaurante, el contador previamente mostrado como “entregas” se presenta ahora como “asignaciones”, ya que se cuenta el registro creado al aceptar oferta y permanece incluso si luego se cancela. Se aclara además que el saldo no confirma ni una entrega finalizada ni el pago al repartidor. Prueba responsive existente ampliada para verificar estas etiquetas; no se alteró el query ni el contrato API.
**Verificación de entrega (2026-11-24):** Domiciliarios y Foody Control pasan 4/4 widgets; analyzer focalizado limpio. `flutter build web --release --dart-define=APP_FLAVOR=equipo -t lib/main.dart -o build/web_equipo` terminó OK. Bundle local y `https://equipo.foodyy.store/main.dart.js` iguales (`A2C5A719DC1EEE59965FD3C46E05081AE419F2EC9403297142D8DA5CFDD0207C`, 6.524.241 bytes); HTTP 200 y cloudflared PID 11112 activo. El dry-run Wasm y font CupertinoIcons siguen advirtiendo, no bloquearon JS release. No se reinició Nest :3000 ni se alteraron Tunnel, OAuth, secretos o datos.
Chrome mostró inicialmente textos previos por caché del service worker; recarga completa descargó la versión del bundle y verificó la nueva etiqueta/nota en `equipo.foodyy.store/admin/panel?seccion=domiciliarios` a 931×1013. Solo lectura de esa sección.

**Pedidos — ADM-03-LIMIT-01 (2026-11-24, corregido):** el Kanban ya consume activos paginados y ofrece “Cargar más” tanto en grid como en columnas. Indica total del servidor, cargados/total, marca con `+` las cifras por pestaña aún parciales y llama “Valor cargado” al subtotal mientras hay páginas pendientes; filtrar sin resultados permite ampliar la búsqueda a páginas anteriores. Deduplica IDs y reinicia al recibir refresco/realtime. Prueba Kanban con dos páginas (total 101) y contrato HTTP de query/meta; 9/9, analyzer limpio. Offset puede omitir filas si hay inserciones silenciosas entre páginas; eventos/realtime reinician, cursor/keyset es futura mejora de alto tráfico. Sin cambios Nest ni escrituras de negocio. QA autenticada y dispositivo móvil real pendientes. Ver `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.
Build posterior al cambio: `flutter test` global **184 aprobadas, 5 omitidas, 0 fallidas**; build Equipo release finalizó. `build/web_equipo/main.dart.js`, local `http://127.0.0.1:8080/main.dart.js` y público `https://equipo.foodyy.store/main.dart.js` coinciden SHA-256 `2AF3DA9D59D21FD1A966622D9A378C623F28E507107AEBAADA53EF00604DD162`, HTTP 200. cloudflared PID 11112 activo; Nest :3000 no reiniciado; túnel, OAuth y datos sin cambios.

**ADM-01-LIMIT-02 (2026-11-24, corregido en fuente; activación backend pendiente):** domicilios tardíos servidos desde consulta acotada del resumen, límite 8/umbrales coincidentes con UI; búsqueda global consulta Nest por número, cliente, teléfono o mesa (2–80 caracteres, 6 resultados, scope de sucursal y activos), debounce 250 ms. Query parametrizada y paginada, validación DTO; specs SQL y contrato Flutter. Nest 24 suites/55 tests, build OK; Flutter 186 aprobadas/5 omitidas; analyzer focalizado limpio. Nest :3000 sigue sin reiniciar, por lo que Tunnel mantiene API previa y la búsqueda nueva no queda activada hasta ventana coordinada. No se hicieron escrituras de negocio. Evidencia AUDITORIA_PEDIDOS_CICLO_VIDA.md.

## 2026-11-24 — Dashboard: lecturas parciales sin falsos vacíos

`DashboardResumenWidget` ejecuta cinco lecturas paralelas. Detecté que un error de una fuente dejaba su lista local vacía y el acordeón podía afirmar “sin alertas/mesas/stock”; durante el polling también sobrescribía un último resultado bueno. Ahora se conserva el dato de fuentes fallidas, se expone aviso con nombres de secciones y reintento, los acordeones distinguen error de vacío y los KPIs de resumen muestran “—” si no se pudo obtener su origen. Agregué contador de revisión para descartar respuesta tardía si el usuario cambia de sede durante las consultas. Pruebas responsive existentes + error parcial inicial, refresco con retención y carrera entre sedes: 7/7; analyzer focalizado limpio; `git diff --check` limpio. No se llamó API real ni se hicieron escrituras.
Build Equipo release final tras la guardia de sede: bundle local/Tunnel igual (`6DDFE125A8BA9A0A30B0E7E591CED512BE42FCE0FA87D90B2D228CC1326CFB05`, 6.526.661 bytes), URL pública HTTP 200. Chrome mostró Inicio a 931 px en modo solo lectura; cloudflared PID 11112 activo. Dry-run Wasm y font CupertinoIcons advierten, sin bloquear JS release.
Regresión completa de Flutter posterior al dashboard y demás cambios del panel: **180 aprobadas, 5 omitidas** por el guard de pruebas E2E con BD aislada; 0 fallidas. Las pruebas de PDF reportan warning de Helvetica sin Unicode, documentado previamente.

**Regresión amplia de la rama de trabajo (2026-11-24):** Flutter `flutter test` pasó con 170 pruebas y omitió 5 E2E por el guard de base aislada. Backend `npm test -- --runInBand` pasó 16 suites/44 pruebas. La base `foody-diseno-qa-db` está detenida y no hay API QA en :3001; la API :3000 está reservada al uso actual. No se lanzó otra E2E para evitar apuntar a datos de negocio ni se leyeron credenciales. Pendiente reconstruir el entorno aislado de forma autorizada y repetir ciclos completos autenticados; el conjunto unitario/widget no valida integraciones persistidas.

**Verificación de Tunnel al cierre:** `cloudflared.exe` (PID 11112) sigue activo; web cliente, panel de Equipo y salud API pública devolvieron HTTP 200. Puertos locales :8080, :8081 y :3000 en escucha.

**Última actualización:** 2026-11-23 — POS mantiene lectura paralela de menú/mesas/caja y ahora estima total con Nest para validar pago mixto; pruebas focalizadas 7/7 y analyzer limpio. Una lectura real a `POST /pedidos/estimar` respondió sin escritura. Suite completa Flutter de la etapa anterior: 158 aprobadas/5 E2E mutadoras omitidas. El iniciador `scripts/iniciar1` se ejecutó en etapa previa con exit 0; no se reinició API ni se alteró Tunnel/OAuth en esta actualización. El Nest vivo conserva cualquier código backend previo no reiniciado. Ciclo autenticado real, idempotencia staff, COC-NODISP-DOM-01 y política de pedido parcial/abonos siguen abiertos.
- **2026-11-23 — UX/RBAC usuarios:** etiqueta del permiso `crear_pedido` ahora dice «Crear y operar pedidos» y explica que también habilita edición de líneas y cambios FSM. Prueba abrió el formulario a 320×568 y detectó overflow del selector de rol en móvil; ambos selectores ahora usan ancho expandido. Widget test usuarios 4/4; regresión Flutter completa 160 aprobadas/5 E2E mutadoras omitidas; analyzer de los dos archivos tocados limpio. No cambió la matriz API: permisos separados por alta/edición/transición requieren decisión previa. Builds Cliente/Equipo regenerados directamente con flavor release y configuración túnel existente, sin ejecutar el sincronizador que escribe `.env`; cinco rutas locales/públicas dieron HTTP 200, bundle Equipo contiene el copy y API pública responde `exito=true`. Nest, Python SPA y cloudflared siguieron en ejecución; no se tocó OAuth, credenciales ni datos.
- **2026-11-23 — Barrera despacho por ítems no disponibles:** guardia `DispatchService.validarPedidoParaDespacho()` compartida por dispatch automático, asignación manual a planta, publicación de oferta y aceptación independiente; al aceptar se vuelve a validar dentro de transacción. 6 pruebas focalizadas; Nest 9 suites/29 y build OK. Sin mutaciones en BD ni reinicio del servicio :3000. Activación/QA autenticada requiere reinicio coordinado y BD aislada. La regla de cliente, línea y abonos sigue pendiente.
**Verificación ampliada de esta etapa:** Flutter 159 aprobadas/5 E2E mutadoras omitidas; Nest 6 suites/23 pruebas y build OK. `scripts/iniciar-foody-subdominios.bat rebuild` compiló y publicó Cliente/Equipo; seis rutas locales/públicas respondieron HTTP 200, API :3000 saludable y `cloudflared` ya activo. No se reinició Nest ni se modificó OAuth, credenciales o datos. La pestaña Chrome existente mostró un copy cacheado antiguo; el JS servido ya contiene el nuevo, requiere Ctrl+F5. El build web JS completó con avisos de dependencias WASM (no usado por el release normal) y de fuente CupertinoIcons no encontrada (sin referencia directa localizada en `lib/`).

**Auditoría autenticada de UI (2026-11-23):** Análisis, Pedidos, Domiciliarios y Caja consultados con rol administrador sin ejecutar operaciones. Análisis llamaba “Pedidos activos” a `pedidosRecientes.length` (endpoint limita a 15 filas por periodo); ahora rotula “Pedidos recientes”. La tarjeta “Ganancia est.” duplicaba el importe de margen bruto; se reemplazó por `cobertura_costo_pct`, y si no hay pedidos presenta “—”. Domiciliarios diferencia ahora “Fiado por cobrar” (C×C de planta) de “Pago a independientes” (pasivo a independientes), sin alterar cálculos. Alerta caja turno longevo aparece del backend; el banner ahora orienta a revisar pedidos, mesas y domicilios antes del cierre, aunque no enlaza cada bloqueo. No se cerró, arqueó ni cobró. Flutter análisis focalizado sin issues; pruebas focalizadas de Analítica/Domiciliarios/Caja y suite total 156 aprobadas/5 E2E mutadoras omitidas; `flutter analyze --fatal-infos` global conserva 55 issues (54 info + 1 warning, ninguno en archivos editados). Release Cliente/Equipo recompilado; seis URL locales/públicas HTTP 200 y bundles contienen copy final de Caja y Análisis. No reiniciar Nest ni tocar datos, túnel u OAuth. Detalle de evidencia en `docs/archivo/auditorias-prompts/AUDITORIA_REPORTES.md` y matriz frontend ADM-13/16.

**Revisión de Finanzas (2026-11-23):** la comparación de Finanzas provenía de `delta_utilidad_pct` pero se mostraba también en “Ventas netas”; se quitó de esa tarjeta y quedó en “Utilidad neta”. El KPI compartido ahora se acomoda en celdas estrechas. Se documentaron el P&L mixto (tickets aún no cobrados más gastos registrados), obligaciones pendientes excluidas hasta el pago y el uso de `pedido.created_at` para periodizar movimientos ligados a pedidos. `FIN-DATE-01` queda pendiente: cohorte del pedido o timestamp de cobro/devolución. Test focalizado Finanzas 7/7; suite Flutter 157 aprobadas/5 E2E mutadoras omitidas; analyzer focalizado sin issues. Cliente/Equipo recompilados y seis URLs locales/públicas HTTP 200. API/Tunnel no reiniciados; no hubo pagos ni cambios de reglas/datos. Ver detalle en `docs/archivo/auditorias-prompts/AUDITORIA_REPORTES.md`.

**Entrega y cobro domiciliario (2026-11-23):** `DOM-PAY-BALANCE-01` — planta e independientes ahora reciben por API el saldo pendiente y su reparto entre producto/domicilio; la selección de método se determina por el booleano del servidor, no por el método del abono anterior. La tarjeta informa el producto neto y saldo, evitando llamar al subtotal bruto o al total original “por cobrar”. Cálculo compartido preservado. Suite Nest 23/23 en 6 suites + build OK; Flutter 158 aprobadas/5 E2E omitidas; analyzer focalizado limpio. Release de Cliente/Equipo recompilado; seis URLs HTTP 200. Nest :3000 quedó en memoria sin reinicio: el nuevo contrato no queda activo hasta reiniciar. Probar ambos perfiles y escenarios de abono en BD aislada; no se cobraron pedidos reales. Ver detalle en `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.
**POS, creación manual (2026-11-23):** trazado sin escrituras desde carrito Flutter hasta `PedidosCrearService`: validación de catálogo/precio, promoción, IVA, stock, pagos/caja, mesa, historial y eventos. Hallazgo: pago mixto divide una suma visual sin consulta al estimador autoritativo; promoción o edición posterior del carrito puede hacer que Nest rechace la suma. El alta staff no manda clave de idempotencia, por lo que no cubre reenvío tras timeout. No se editó código ni se creó pedido; documentado con recomendación de consultar la estimación backend y conservar payload+clave para reintentos seguros. E2E de escritura requiere BD QA aislada.
**Rendimiento creación pedidos (2026-11-23):** lectura estática encontró consultas seriales por cada producto, combo, topping y bebida dentro de una transacción; los arrays anidados de extras no tienen máximo explícito. No se hizo benchmark, por lo que queda como riesgo a medir, no cuello de botella confirmado. Recomendada lectura por lote después de fijar límites de selección y medición p50/p95 aislada. Evidencia en `docs/AUDITORIA_RENDIMIENTO_PUNTA_A_PUNTA.md`.
**Idempotencia multi-tenant de pedidos (2026-11-23):** tabla/consultas de clave global no incluyen sede ni huella del payload; repetir una clave retorna también token de seguimiento. Checkout usa UUID v4 y no se reprodujo una exposición, pero hay riesgo de diseño si se amplían reintentos o se aceptan claves predecibles/reutilizadas. Pendiente definir clave compuesta por tenant+sede, huella y respuesta mínima antes de habilitar reintento staff. Ver `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**Rate limit multi-réplica (2026-11-23):** la auditoría encontró que `RateLimitGuard` atrapaba también su propia excepción HTTP 429 dentro del `catch` de PostgreSQL; cuando el contador compartido excedía el máximo, caía al mapa local por proceso. Se movió el rechazo fuera del bloque que captura fallos SQL y se agregaron specs para exceso (429), petición permitida y fallback solo si la BD falla. Pruebas focalizadas 6/6 y build Nest OK. La API viva :3000 no se reinició; la corrección está en el código, pendiente de activación/verificación mediante reinicio coordinado, sin cambiar Cloudflare Tunnel ni OAuth.

**Revisión de estado pedidos/caja y QA (2026-11-23):** se corrigieron referencias históricas obsoletas de PED-PREPAGO-01/PED-BYPASS-01: prepago con saldo cero no bloquea cierre, pero permanece en KDS hasta terminar; `salio-sin-pagar` registra estado/historial con `PedidosEstadoCommandService`. El informe de ciclo de vida tenía 2 bytes NUL que impedían buscarlo como texto; retirados sin alterar el contenido restante. Añadí al E2E el intento de cierre de caja QA antes de completar KDS; el spec pasa chequeo TypeScript, no se ejecutó aún contra API. El arranque QA requería leer la credencial interna del contenedor para construir DATABASE_URL y el control automático rechazó ese comando; no se usó :3000 para mutaciones. Contenedor QA detenido. Verificación pública: cliente, panel y salud API HTTP 200; cloudflared sigue activo.

**Chrome del panel — Caja (2026-11-23):** observación de solo lectura en `equipo.foodyy.store` a 930 px: rail compacto muestra grupos con popup/tooltip, y Caja distribuye KPIs, CxC y formulario de gasto; no se enviaron cobros, cierres ni gastos. Tras recompilar Equipo, verifiqué que :8080 y Tunnel entregan el mismo bundle con copy nuevo; la pestaña abierta conservó el bundle anterior hasta completar la navegación/recarga. Chrome finalmente muestra “Turno abierto hace 109 días y 19 h. Revisa pedidos, mesas y domicilios pendientes antes de cerrar.” No se tocaron CxC QA heredadas. Evidencia visual de 930 px en `docs/frontend/FOODY_PANEL_ADMIN_REDESIGN_MATRIX.md`.

**Próximo paso:** continuar vistas y subflujos administrativos con cobertura incompleta; hacer regresión autenticada sin mutar datos. Cloudflare Tunnel sigue siendo el entorno de referencia. Reevaluar VPS/deploy al terminar la app.

### Auditoría operativa de pedidos (2026-11-23)

- `PED-ORIGIN-DOM-01`: `CrearPedidoDto` exige dirección no vacía para `tipo=domicilio`, incluso en llamada directa API; retiro y mesa siguen sin necesitarla. Specs DTO+RBAC 10/10 y `npm run build` OK. El servicio en :3000 no se reinició; Tunnel sigue intacto y la corrección todavía no está activa en ese proceso.
- La revisión QR/cliente documentó modo anónimo por `device_id`, vinculación adicional al historial por `cliente_auth_uid` cuando bearer Supabase valida y límites de 50 pedidos. Comandos cancelar/llamar/calificar aún verifican `device_id`.
- Caja de domicilio se registra en confirmación de entrega; despacho calcula comisión configurada sobre `costo_domicilio`, que es distinta de suscripción SaaS y de comisión sobre productos. Decisión de quién paga el servicio de domicilio sigue pendiente.
- Checkout aclara tarifa de domicilio como estimada si la API no pudo calcular distancia, pues el servidor usa zona de radio menor para dirección ingresada sin ubicación. Solo cambia la comunicación visual.
- El build release de Cliente/Equipo detectó artefactos obsoletos y los regeneró sin cambios de configuración OAuth; los servidores :8080/:8081 y Tunnel se recuperaron y responden 200 local/público. El proceso API :3000 no se reinició.
- Abierta política `FIN-REC-OPEN-01`: Rentabilidad incluye pedidos pendientes si no están cancelados/rechazados; y `DOM-CANCEL-PAYOUT-01`: comisión/ganancia independiente nace al aceptar, permanece por pagar después de cancelar. No alterar saldos hasta definir si se compensa intento o se revierte.
- `COC-NODISP-DOM-01`: VIE-09 C resuelve el ticket cuando todos los ítems están `listo|no_disponible`; para domicilios eso puede disparar asignación inmediata, aunque el ítem y su precio siguen en el pedido. El salón puede eliminarlo y recalcular total/IVA, pero después del dispatch. Definir eliminación/confirmación del cliente y tratamiento de abonos antes de cambiar reglas. Evidencia y propuesta: `archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**COC-NODISP-DOM-01 — QA integrada (2026-11-24):** se añadió E2E que crea domicilio con dos líneas, reporta una como `no_disponible`, completa la otra, verifica pedido `listo` y comprueba que asignación manual de planta y dispatch independiente no crean despacho/oferta. La ruta de oferta devuelve `exito:true` con `datos.iniciado:false` y motivo `PEDIDO_ITEMS_NO_DISPONIBLES`; la asignación manual rechaza. `npm run test:e2e -- --runInBand`: 8/8 suites, 16/16 pruebas. El ensayo usa API :3001 y PostgreSQL QA aislada; fixture restaurado, pedidos de prueba cancelados y :3001 detenido. La API :3000/Tunnel no se tocó. La política sobre quitar/modificar línea, consentimiento del cliente, abonos y reembolsos permanece pendiente; activación live también pendiente. Detalle en `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**Mapas — zoom táctil (2026-11-24):** `MapaFoody` reutiliza ahora un grupo de zoom accesible con controles 48×48, tooltips/localización accesible y colores del `ColorScheme`, en lugar de botones de 36 px con blanco fijo. Shared por panel de zonas, selección de ubicación, seguimiento y mapas de domiciliarios; callbacks y funcionalidad conservados. `flutter test test/mapa_foody_test.dart test/zonas_admin_screen_test.dart`: 4/4; `flutter analyze --fatal-infos` en archivo y prueba sin hallazgos; `flutter test`: **204 aprobadas, 5 omitidas, 0 fallidas**. Impeccable detector: `[]`. No se generó nuevo bundle ni se modificó el Tunnel; falta revisar mapa real en tamaños compactos/desktop y acciones de ubicación en Chrome/dispositivo.

**Caja/Reportes/Análisis — conciliación E2E (2026-11-24):** nuevo caso crea pedido de mesa pendiente, completa cocina, cobra efectivo y compara antes/después los totales en `GET /reportes/financiero` y `GET /analitica/caja`. Incrementos de tickets y movimientos netos de caja coinciden con el total; delta de la diferencia de cuadre es $0 en ambos. Caso de caja 3/3 y E2E completo 8/8 suites, 17/17 pruebas, ejecutadas en API :3001 + BD QA dedicada. Pedido abierto de prueba cancelado; horario, producto e inventario demo restaurados; API temporal detenida. API :3000/Tunnel intactos. Esto cubre una venta pagada; la política de reconocimiento para pedidos sin cobrar, abonos, devoluciones y domicilio permanece pendiente. Ver `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.
- `CLIENT-DOM-CONTACT-01` (hallazgo inicial, resuelto en fuente 2026-11-24): Checkout y DTO exigen teléfono válido (7–15 dígitos) para domicilios; nombre opcional. Prueba E2E QA comprueba rechazo y persistencia; el proceso `:3000` requiere activar el build.
- `KDS-RT-AUTH-01`: admin/gerente tienen permiso `ver_cocina` y la navegación KDS lo ofrece, pero el login solo incluía canal HMAC para rol cocina con estación asignada. Ahora Flutter pide firma de la cocina elegida al endpoint autenticado y Nest valida permiso efectivo, asociación cocina↔sucursal activa y asignación exacta cuando el rol es cocina. `auth.service.spec.ts` 5/5; `cocinas_repository_test.dart` 2/2; KDS responsive 8/8; backend 16/16 + build; suite Flutter 152/5 omitidos. Build Cliente/Equipo servido, URL del nuevo endpoint presente en JS público y seis destinos HTTP 200. **Pendiente de activación:** el Nest de :3000 no se reinició, por lo que KDS aún debe probarse con la nueva respuesta firmada después de que Javier reinicie el API.
- Pruebas visuales de regresión aisladas: KDS + domiciliarios admin + POS + detalle/cobro de mesa **25/25** aprobadas, con viewports compactos y escritorio según cada suite. Usan repositorios falsos, no comprueban flujo autenticado ni efectos reales en backend/BD.
- `flutter analyze --fatal-infos` focalizado en KDS, domiciliarios, POS y detalle de mesa: sin hallazgos. `npm test -- --runInBand`: 3 suites/11 tests; `npm run build`: OK.
- Reejecución suite total Flutter: **150 aprobadas, 5 omitidas** (contratos E2E de escritura exigen BD aislada). Los omitidos no cuentan como evidencia de flujo completo.
- E2E API de domicilio no se ejecutó: `test/helpers/foody-e2e.ts` apunta por defecto a `127.0.0.1:3000`, y `beforeEach` cancela pedidos abiertos de la sede demo y abre caja; en este equipo :3000 es la API usada por el Tunnel y `docker-compose.dev.yml` solo presenta la Postgres de desarrollo, no una fixture aislada identificada. Las seis URLs locales/públicas de cliente, equipo y salud API dieron HTTP 200; no se reinició ningún servicio.
- Siguiente: pruebas de ciclo integral en BD QA aislada y conciliación con fixtures de caja/finanzas/reportes, sin escribir sobre la BD real.

### Auditoría de rendimiento (2026-11-22)

- Informe de auditoría y evidencia: [`AUDITORIA_RENDIMIENTO_PUNTA_A_PUNTA.md`](AUDITORIA_RENDIMIENTO_PUNTA_A_PUNTA.md); el script repetible de GET de baja intensidad está en `scripts/perf/medir-lecturas-tunel.ps1`.
- Prueba local calentada (3 repeticiones; concurrencia 1/3/5): `/salud` p50 3,0–3,2 ms; `/menu` p50 1,9 ms, 100% respuestas. Por túnel hubo respuestas exitosas de 0,4–0,6 s y fallos intermitentes hasta 6–15 s, incluso `/salud`. No representa tráfico desde red externa ni capacidad concurrente.
- En sesión visual Admin Demo se reprodujo error de canal firmado en Cocina y crash de Domiciliarios por importe PostgreSQL `numeric` recibido como `String`; ver causa y corrección propuesta en el informe. No se hicieron liquidaciones ni escrituras.
- Se ejecutó `verificar-perf-flutter.ps1 -SkipAnalyze`: OK con avisos de `Wrap` en Kanban y `FlutterImageCompress` sin uso detectado. No es profiling; heap/waterfall y prueba de red externa siguen pendientes.

### Últimos cambios (changelog)

- **2026-11-24:** **FIN-SPLIT-OVERCHARGE-01 / QA-E2E-OPS-01** — split por ítem ahora valida el saldo del ticket con precio de línea que incluye extras y descuento; E2E prueba rechazo sin movimiento Caja. Unitarias 26/57, E2E 8/22, scripts operativos 9/9 y build Nest OK en base/API QA aisladas. Se corrigió el harness P2 para PS moderno y seed sin sede/config global. :3000/Tunnel intactos; el proceso principal aún requiere reinicio. QA temporal/API :3001 y agente print cerrados; no se tocaron cuentas de producción/OAuth/datos negocio.
- **2026-11-23:** **AUTH-DEMO-DEBUG-ONLY-01** — Los correos/contraseña demo se exponían por tres vías release: sección de ayuda staff, mensaje de error 401 y campos precargados del login de repartidor independiente. Las tres quedan bajo `kDebugMode`; el mensaje de 401 en release es genérico. OAuth, endpoints, rutas y cuentas no se cambiaron. Test confirma ayuda demo en debug; analyze `--fatal-infos` focalizado sin hallazgos. Builds Cliente/Equipo regenerados y búsqueda de seis cadenas demo ausentes en ambos JS release. Localhost, hosts públicos y salud API HTTP 200; Tunnel activo.
- **2026-11-23:** **PERF-POS-READS-01 / START-TUNNEL-VERIFY-02** — En `PedidoCajeroScreen`, menú, mesas y caja son lecturas independientes: el POS las solicita en paralelo; se conserva el fallback que trata un fallo de consulta de caja como “sin caja”, y la pantalla sigue esperando el catálogo y mesas necesarios. Prueba con `Completer` confirma que las tres solicitudes arrancan antes de resolver alguna; `pedido_cajero_screen_test.dart`: 6/6; análisis focalizado limpio. Se ejecutó el acceso directo real `scripts/iniciar1/iniciar-foody-subdominios.bat` (exit 0): API :3000 saludable, Equipo :8080 y Cliente :8081, y hosts públicos de ambos sitios y API salud HTTP 200; Cloudflare ya estaba activo. Solo reinició servidores estáticos :8080/:8081; no se reinició Nest ni se tocaron OAuth, credenciales o datos. No se midió la reducción de latencia real por petición.
- **2026-11-23:** **POS-MIXED-QUOTE-01** — El POS consulta cotización de Nest tras editar carrito/canal/mesa/dirección (debounce 300 ms), muestra el importe servidor y valida pago mixto con dos montos positivos cuya suma coincida con tolerancia de 0,01. Cotización pendiente/fallida/no coincidente bloquea pago mixto; el alta usa validación final del servidor. No cambia el API ni registra datos. POS 7/7; `flutter analyze --fatal-infos` focalizado limpio; `POST /api/v1/pedidos/estimar` real con producto demo devolvió total 2500 COP, solo lectura. E2E autenticado con promoción y creación real pendiente en BD QA aislada. Idempotencia staff permanece abierta; no se midió latencia de la cotización.
- **2026-11-23:** **RBAC-PEDIDOS-01** — `PATCH /pedidos/:id/estado` exige `crear_pedido`, evitando que una cuenta con solo `ver_pedidos` mute estados. `PedidosEstadoService` conserva la limitación del mesero (`pagando`/`cancelado`) y validación de motivo/tiempo. Ambas rutas de cobro ya exigen `cobrar_pedido` (código + migration 082). `pedidos.controller.spec.ts`: 6 specs de `RolGuard` para acceso mesero/cajero y solo-lectura/escritura; backend `npm test -- --runInBand` y `npm run build` OK. El build nuevo arrancó aislado en :3001 con DB saludable; :3000 y Tunnel siguieron intactos. Pendiente: autorización granular por transición y smoke autenticado en BD QA.
- **2026-11-23:** **UX-ALERTAS-FLUJO-01** — `alertas_admin_screen_test.dart` verifica que el filtro envíe `soloPendientes=false`, que tocar una alerta navegue al `referencia_tipo/id` esperado y que marcar revisada actualice el estado y vacíe la bandeja de pendientes. Los cambios son pruebas con repositorio falso; no se llama al backend ni se evalúan reglas reales. Pruebas focalizadas 6/6, análisis Dart focalizado limpio; suite Flutter 150 aprobadas/5 E2E mutadoras omitidas. No requirió rebuild web: no cambió código de producción.
- **2026-11-23:** **UX-CAJA-MOV-RESP-01** — `caja_admin_screen.dart` limita el título de la cabecera de Movimientos para que conviva con el contador en anchos compactos. Se detectó con un overflow real de 7,5 px a 320 px. `caja_admin_screen_test.dart`: apertura y turno activo/saldos/vacío en 320/390/820/1440; 8/8 pasan. Mesas, detalle de mesa, Finanzas y Reportes focalizados pasan. Suite global 135 aprobadas/5 E2E mutadoras omitidas. Builds Cliente/Equipo release y cinco checks HTTP 200; túnel/OAuth sin cambios. No se dispararon acciones de escritura ni liquidaciones.
- **2026-11-23:** **UX-PLAN-CARDS-RESP-01** — `MejorarPlanScreen` acepta un `PagosRepository` opcional para aislar pruebas; por defecto instancia el repositorio habitual. La insignia de Pro cambia a `Wrap` y ya no desborda al estrecharse. `mejorar_plan_screen_test.dart`: estado Gratis y desplazamiento hasta Pro/Enterprise en 320/390/820/1440; 4/4 pasan. No se cambian precios, reglas ni checkout; no se inició pago. Analyze focalizado limpio; builds Cliente/Equipo release y cinco checks HTTP 200.
- **2026-11-23:** **UX-DASH-RESP-01** — `DashboardResumenWidget` permite repositorios opcionales para pruebas sin red y conserva los defaults de producción. Nueva prueba de Centro de operación con métricas sintéticas, cuatro secciones vacías y scroll en 320/390/820/1440; 4/4 pasa. Sin consulta de datos reales ni escritura. Analyze focalizado limpio; suite Flutter 143 aprobadas/5 contratos E2E mutadores omitidos.
- **2026-11-23:** **DART-ANALYZE-BASELINE-01** — Un análisis completo del workspace produce 56 diagnósticos de Dart, en mayoría informativos/depreciaciones; incluye `_convertirDiaSemana` sin uso en `lib/models/horario.dart:171`. No todos se atribuyen a este lote; quedan como deuda de calidad por limpiar en tandas. Las seis fuentes/test de Caja, Plan y dashboard del lote pasan análisis focalizado.
- **2026-11-23:** **UX-POS-PAYMENT-FIELD-RESP-01** — El campo de método de pago del carrito usa expansión horizontal para evitar overflow en el POS split de tablet (reproducido: RenderFlex +20 px a 820 px). `pedido_cajero_screen_test.dart` verifica vacío en 320/390/820/1440 y producto→detalle→carrito a 390 px con datos sintéticos. No se confirma pedido; análisis focalizado limpio; suite 148/5 skips. Cliente/Equipo release y cinco URLs (localhost, dominios y API salud) HTTP 200.
- **2026-11-23:** **UX-DOMI-NUMERIC-01** — Los importes de API (`num` o `String`) se convierten para presentación de KPIs, tarjetas y confirmación; pagos/cálculos siguen a cargo de backend y no se ejecutó liquidación real. Fixture usa texto en pruebas de 390/820/1440; analyze limpio, suite 131/5 skips. Build/túnel por refrescar.
- **2026-11-23:** **UX-INV-MERCADO-EMPTY-LAYOUT-01** — Agregada inyección opcional de repositorios a `InventarioAdminScreen` (defaults de producción sin cambio) para render sin red/datos reales. Mercado permite limpiar consulta/filtros; el vacío se desplaza con viewport corto. La prueba integrada encontró `Spacer` en tarjeta dentro de lista de alto intrínseco que causaba `RenderFlex` con `precio_compra`; reemplazado por espacio fijo. 7 pruebas de pantalla/selector, analyze limpio, suite 131/5 skips. Cliente/Equipo recompilados y dominios/API salud HTTP 200. Sin escrituras; túnel/OAuth no tocados. QA autenticada pendiente.
- **2026-11-23:** **UX-MENU-EMPTY-RECOVERY-01** — Si hay productos pero la búsqueda o filtro no encuentra coincidencias, la pantalla explica cómo recuperar la lista y resetea ambos filtros al pulsar «Limpiar búsqueda y filtros». Mantiene intacto el vacío inicial «Sin productos aún». Prueba móvil y responsive/precios 320/390/820/1440; analyze limpio; suite 130 aprobadas/5 E2E mutadoras omitidas. Builds release repuestos con el lanzador `scripts/iniciar1/iniciar-foody-subdominios.bat`; localhost Cliente/Equipo, dominios públicos y salud API HTTP 200. Sin persistencia/API, cambios a túnel o OAuth. QA autenticada y tema oscuro siguen pendientes.
- **2026-11-23:** **UX-INV-NAV-01 / INV-TAB-SYNC-01** — En anchos compactos, el scroll horizontal de cinco pestañas se sustituyó por selector con las cinco opciones accesibles y contexto «Sección n de 5»; `TabBar` permanece en anchos amplios y `TabBarView` sigue soportando swipe. El controlador ahora notifica al shell cuando cambia el índice para sincronizar resumen, botones de alta e historial con la sección actual. No se alteró consulta ni persistencia. Seis pruebas pasan en 320/390/820/1440 px (tema claro/oscuro compacto); análisis focalizado limpio. Suite general `flutter test`: 128 aprobadas, 5 E2E mutadoras omitidas. QA con sesión real de Inventario sigue pendiente.
- **2026-11-23:** **UX-PED-EMPTY-RECOVERY-01** — Pedidos distingue el estado vacío de búsqueda/canal sin coincidencias; “Limpiar filtros” restablece consulta, canal y tab inicial. Prueba focalizada 6/6, analyze limpio y suite general 129 aprobadas con 5 E2E mutadoras omitidas. El lanzador `scripts/iniciar1/iniciar-foody-subdominios.bat` recompiló Cliente/Equipo en release y verificó HTTP 200 en `localhost:8080/8081`, dominios públicos y API salud. Configuración del túnel permaneció sin cambios. No cambia servicios, pedidos, CORS ni OAuth. QA autenticada por rol sigue pendiente.
- **2026-11-23:** **UX-CONFIG-HUB-02** — el índice visual de Configuración ahora agrupa las opciones existentes en Negocio, Atención y entrega, Operación, y Equipo, con descripciones de tarea, jerarquía visual y conteos que salen de los permisos visibles. Medios de pago del restaurante se presenta como no disponible y separado de la suscripción Foody. No se añaden rutas ni se alteran APIs/permisos. 10 pruebas widget pasan para 320/390/820/1440 y tema claro/oscuro; se probó filtrado de permiso y navegación a la ruta canónica; análisis focalizado limpio. QA autenticada pendiente.
- **2026-11-23:** **START-TUNNEL-RECOVERY-01** — `iniciar1` fallaba porque un `)` literal en un `echo` cerraba el bloque condicional de CMD. El inicio de Cloudflare se movió después de comprobar los dos orígenes locales; el lanzador detecta builds obsoletos incluso cuando se pide `-SkipBuild` y la sincronización evita modificar `configuracion.dart`/`.env` cuando el contenido no cambia. La base `supabase-db` estaba detenida por un montaje de archivo/directorio; se inició el contenedor existente, sin `down`, recreación ni borrado de datos. Inicio reproducido de extremo a extremo; locales y hosts públicos de cliente, Equipo y salud API HTTP 200; Supabase healthy. Google OAuth y CORS no se cambiaron.
- **2026-11-23:** **UX-DASHBOARD-REFRESH-01 / PERF-DASHBOARD-READS-01** — Inicio actualiza resumen, mesas, pedidos, alertas e inventario en paralelo (antes serial) porque las lecturas son independientes; cada fallo sigue aislado para conservar resultados parciales. La actualización manual mantiene la última captura visible y muestra progreso en el control de refresco. `flutter analyze` del widget limpio; `flutter test`: 112 pasaron y 5 E2E mutadores se omitieron por defecto; build web release de ambos flavors OK. Falta QA autenticada visual por ancho/tema y medición instrumentada de latencia real del dashboard.
- **2026-11-23:** **QA-E2E-WRITE-GUARD-01** — `flutter test` ejecutó por defecto los contratos API contra `localhost:3000`, que no estaba aislado. El flujo dejó un solo pedido sintético (`flt-vie01`) en estado cancelado; no se detectaron pedidos reales modificados. Se añadió opt-in explícito en el grupo Flutter y `-PermitirEscrituras` en el lanzador, con destino de API parametrizable y nota de usar exclusivamente una BD QA aislada. La suite debe repetirse sin los contratos mutadores por defecto; no se vuelven a ejecutar E2E contra la API de uso actual.

- **2026-11-23:** **UX-AUDIT-MATRIX-01** — revisados el estado Git preexistente, el catálogo de 23 rutas internas del panel restaurante, los paneles de rol y las barras de pestañas visibles en código. Creada matriz inicial con subvistas, componentes/acciones y pruebas detectadas. Es una base de seguimiento, no una aprobación de las vistas; el inventario de cada formulario/diálogo y dependencias por acción aún no se cierra. No se revirtieron cambios previos ni se tocaron servicios/túnel.
- **2026-11-23:** **UX-AUDIT-INTERACTIONS-02** — ampliada inspección estática a navegación, módulos operativos, configuración, finanzas y Foody Control; la matriz registra callbacks/diálogos visibles y tareas UX/QA para cada área. No equivale a QA funcional autenticada; no se ejecutaron escrituras ni pruebas en esta actualización documental.

- **2026-11-23:** **UX-PREMIUM-RESP-02** — patrones de operación y estado vacío refinados con tokens de tema, tamaños compactos y objetivos táctiles mínimos; KPIs del Centro de Operación ganan iconografía semántica y altura uniforme, Inventario adapta superficies y texto al tema activo, Análisis reduce la barra de 8–10 tabs a selector bajo 720 px; motion respeta reducir animaciones. 117 pruebas pasan, detector Impeccable no reportó hallazgos ([]), web release compilada en `build/qa_ui_premium_20261123`. Dirección acordada: evolucionar a una estética premium nueva basada en las referencias; la cobertura por rol/tema/ancho y QA autenticado global siguen abiertas. Sin cambios de backend, infraestructura ni túnel.

- **2026-11-23:** **UX-MESA-DIALOGOS-RESP-01** — crear/renombrar/desactivar, transferencia, turnos, rechazo QR, CxC, eliminación de ítem, forzar cierre y etiqueta de comensal adoptan shells adaptables o listas con alto máximo. Crear/renombrar se probaron a 320/390 px con teclado. Esa prueba detectó `TextEditingController` dispuesto mientras la ruta seguía animándose; su liberación se difiere tras el cierre. `flutter test test/mesas_grid_widget_test.dart test/mesa_pedidos_sheet_test.dart` pasó y `dart analyze` de ambos archivos quedó limpio. Sin operaciones persistidas.
- **2026-11-23:** **UX-FIN-CRUD-RESP-01** — los cinco diálogos CRUD de Finanzas migran al shell Foody desplazable, los dropdowns usan API vigente y los controladores de formularios se liberan al terminar la transición. Widget tests: vista 320/390/820/1440 px y alta de gasto fijo/empleado a 320/390 px (incluido teclado simulado a 320); edición y pago quedaron convertidos y analizados, pero su apertura no quedó cubierta por una prueba de widget. Suite completa posterior: 111/111. Sin ejecutar operaciones reales.
- **2026-11-23:** **QA-REDISENO-111** — `flutter test`: 111/111; `flutter analyze`: 0 errores, 1 warning (`_convertirDiaSemana` sin uso en `lib/models/horario.dart`) y 55 infos preexistentes; `verificar-flutter-ui.ps1` pasó el analyze focalizado y detectó API local disponible, pero no reemplaza la QA manual autenticada.
- **2026-11-23:** **QA-WEB-BUNDLE-01** — `flutter build web --release --target lib/main.dart --output-dir build/qa_ui_final_20261123` terminó correctamente. El dry run opcional de Wasm reportó incompatibilidades de dependencias web (`dart:html`, integración USB, geolocator) y el build advirtió sobre `CupertinoIcons`; no impiden el bundle JS estándar. No se reemplazaron builds del túnel.
- **2026-11-23:** **QA-E2E-CONTRACT-01 / QA-APP-SMOKE-01** — la suite E2E estaba desalineada con VIE-01 (agregar ítems devuelve pedido a `en_cocina`) y trataba de cobrar sin completar estados de cocina; el fixture ahora usa cuenta de cocina y transiciones reales. Smoke test ahora monta `FoodyApp` dentro de `ProviderScope`. `flutter test`: 105/105 aprobadas. No se modificó backend ni reglas de negocio.

- **2026-11-22:** **UX-MESA-COBRO-RESP-01** — La matriz interactiva del diálogo de cobro halló un overflow de 18 px a 320 px; los selectores de medios de pago ahora se expanden y el OverflowBar de acciones prioriza layout vertical al no caber. Widget tests pasan en 320/390/820/1440. No se cobró nada; se añadieron guards `mounted` después de awaits en la recuperación de timeout/error. Análisis focalizado limpio.
- **2026-11-22:** **UX-MESA-UNIR-RESERVA-01** — La prueba de unión encontró overflow vertical de 308 px con cinco mesas; selección ahora tiene alto máximo, scroll y textos acotados, sin ejecutar la unión. Reserva usa `FoodyDialogoShell`; el shell descuenta el teclado para limitar altura, y el resumen/grilla de Mesas reduce su separación con viewport bajo. Formulario probado con teclado simulado a 320×568; Mesa grid test suite pasa. `dart analyze` deja un info preexistente por `DropdownButtonFormField.value` en ese archivo.
- **2026-11-22:** **UX-MESA-QR-01** — La prueba del QR detectó overflow inferior de 72 px a 320×568; el diálogo ahora limita el alto disponible y desplaza el contenido, incluidos QR/enlace y botones. Render con URL sintética pasa; PDF/impresión/compartir no se ejecutaron.
- **2026-11-22:** **UX-MESA-ADV-01** — La expansión de opciones de Mesa/CxC desbordaba 185 px en móvil por crecer dentro del pie fijo; ahora está dentro de una región con scroll y alto máximo. El diálogo “Cliente salió sin pagar” fue abierto y cancelado a 320×568; no se registró deuda.
- **2026-11-22:** **DX-TUNEL-SKIP-01 (solo local)** — `iniciar-foody-subdominios.bat` llama `servir-web-tunel-release.ps1 -SkipBuild`; sin `build/web_cliente`/`web_equipo` el script lanzaba y el día fallaba. Ahora, si faltan `index.html`, avisa y compila solo lo faltante. Verificado: rebuild cliente+equipo, `http://127.0.0.1:8080` y `:8081` → 200.
- **2026-11-22:** **UX-DOM-RESUMEN-01 / DOM-NUMERIC-01** — el resumen admin distingue comisión Foody y saldo pendiente a repartidores independientes; el repositorio normaliza los importes `numeric` que PostgreSQL serializa como texto antes de presentarlos. Reglas de cobro y resumen de independientes diferencian carga, error reintentable y vacío real. `dart analyze` focalizado limpio; los tests de repositorio y widget pasaron con importes decimales sintéticos y anchos 390/820/1440 px. Sin cambios Nest, datos ni reglas de liquidación; autenticación real y tema oscuro pendientes.
- **2026-11-22:** **UX-DASH-HIERARCHY-01** — los KPI navegables de Inicio indican visualmente que abren otra vista; acordeones de atención animan la expansión en 180 ms y respetan la preferencia del sistema para reducir movimiento. Destinos, umbrales y contenido no cambian. `dart analyze lib/features/admin/presentation/widgets/dashboard_resumen_widget.dart` sin issues; QA visual pendiente.
- **2026-11-22:** **UX-USR-TABLE-01** — Usuarios cambia a tabla compacta de escritorio (usuario, rol, estación, estado) y mantiene cards en compacto/tablet; el estado ahora tiene etiqueta además del indicador de color. Propietario y callbacks de edición/activación se conservan. `dart analyze` limpio; widget test pasa en 390/820/1440 px; QA autenticado/oscuro pendiente.
- **2026-11-22:** **UX-HOR-DIALOG-01** — Diálogos de edición y selección de hora se adaptan a viewport estrecho/bajo; edición permite desplazamiento cuando el espacio vertical no alcanza. `dart analyze` limpio; widget tests pasan en 320×568 y 390×844; no cambian las peticiones ni reglas de horario. QA con teclado real, sesión autenticada y tema oscuro pendiente.
- **2026-11-22:** **UX-SEDES-FORM-01** — Formularios de marca/nueva/editar sede y vista previa de imagen ahora limitan su contenido al viewport y permiten scroll vertical en móvil. Repositorio opcional solo para pruebas; endpoints, almacenamiento y acciones se conservan. `dart analyze` limpio; widget test de nueva sede pasa en 320×568 y 390×844. Edición, teclado real, imágenes y tema oscuro pendientes de QA manual.
- **2026-11-22:** **UX-ZONAS-FORM-01** — Formulario de anillos conserva presets, validación y preview; limita altura y ancho al viewport y permite desplazamiento para no recortar opciones en móviles pequeños. `dart analyze` limpio; widget tests pasan en 320×568 y 390×844. Mapa real, teclado, tema oscuro y sesión autenticada pendientes de QA.
- **2026-11-22:** **UX-COCINAS-DIALOG-01** — Diálogos de cocina e impresora ajustan sus contenidos al viewport; los selectores ahora usan ancho expandido y truncan nombres largos, evitando overflow móvil reproducido por widget test. `dart analyze` limpio; alta de cocina/impresora pasa en 320×568 y 390×844. No valida KDS realtime ni hardware físico.
- **2026-11-22:** **UX-ALERTAS-CARD-01** — Se agregó inyección opcional del repositorio para probar el render aislado; las tarjetas de alerta y badges resisten descripciones largas y tamaños 320/390/820/1440 sin excepciones. Filtros y acciones permanecen intactos; verificación no incluye sesión real, realtime ni tema oscuro.
- **2026-11-22:** **UX-FIN-TARJETAS-01** — Alertas e insights financieros calculan ancho de tarjeta desde el viewport (máximo 340 px), evitando que el ancho fijo exceda el contenido en móviles. Los dos repositorios son inyectables para render de prueba; `dart analyze` limpio y render con respuestas vacías pasa en 320/390/820/1440 px. No prueba CRUD ni datos financieros reales.
- **2026-11-22:** **UX-PROMO-FORM-01 / UX-REPORTES-VIEW-01** — Alta de Promociones limitada por alto/ancho del viewport, scrollable y con selector de producto expandido; Reportes cubierto por render vacío en 320/390/820/1440 con repositorios inyectables. Promociones pasa en 320×568 y 390×844. Reportes mantiene cuatro infos preexistentes por API obsoleta `Share.shareXFiles`; compartir y exportar reales no se probaron.
- **2026-11-22:** **UX-MENU-RESP-01 / UX-COSTEO-RESP-01** — Los selects de sede, categoría y cocina del Menú se expanden y truncan etiquetas largas; vista y alta de producto pasan en 320/390/820/1440 (el formulario en móvil). Costos y Márgenes: vista vacía conserva lista/CTA en 320/390/820/1440. `dart analyze` focalizado limpio; no se enviaron escrituras ni se probaron recetas/edición financiera real.
- **2026-11-22:** **UX-FORM-SHELL-02 / UX-INV-DIALOG-01** — Widget tests descubrieron que `AlertDialog` del shell común pedía medidas intrínsecas a `LayoutBuilder`; formularios largos fallaban y la subreceta podía desbordar con teclado. Se reemplazó por `Dialog` con scroll de contenido completo (incluye acciones), límite de alto y acciones que envuelven. Formularios Insumo/Subreceta pasan en 320/390 con teclado simulado; Menú revalidado, análisis limpio. Selectores de unidad/subreceta/traslado se expanden y truncan etiquetas. No se modificó persistencia.
- **2026-11-22:** Facturación interna conserva la opción de reintentar una emisión rechazada, evita solicitudes repetidas durante la emisión y actualiza la vista después de anular. El comprobante HTML adapta su ancho, expresa el estado correcto y preserva los caracteres de los datos fiscales como texto. En navegador, con cuenta Enterprise y Postgres aislado, se guardó configuración, se rechazó una anulación sin motivo y se confirmó la persistencia al anular y abrir la vista previa. Dos pruebas de widgets pasaron.
- **2026-11-22:** Caja e Inventario verificados contra NestJS y PostgreSQL aislados con datos sintéticos. Pasaron los dos escenarios E2E de Caja, el cobro de un fiado y el registro del conteo. Foody Control permite validar el alta de usuarios con contraseña inicial vacía, errores en los campos y reintento cuando falla la carga de sedes. Se comprobó el formulario en navegador, las altas de restaurante y cajero por API y respuestas 403 en acceso entre dos restaurantes y al intentar crear usuarios de plataforma desde una cuenta de restaurante.
- **2026-11-22:** En la API aislada, el alta de autoservicio asignó Free, permitió Inventario y bloqueó la tercera mesa, Analítica y Facturación. Con un cambio de plan sintético a Pro se habilitó Analítica y Facturación siguió reservada a Enterprise. El Pro vigente sigue a COP 100.000/mes, frente a los COP 50.000/mes definidos como objetivo comercial. La transición de suscripciones y el cobro por Wompi quedan fuera de esta comprobación.
- **2026-11-22:** **UX-CFG-VIEW-01** — `ConfiguracionAdminScreen` reorganizada en grupos Negocio/Servicio/Equipo, ancho máximo 1120, 1/2/3 columnas según ancho disponible y opciones por permisos. Navegación sigue usando callbacks/rutas existentes. `flutter analyze` focalizado en cuatro archivos: OK; faltan QA visual real en móvil/tablet/escritorio y modo claro/oscuro.
- **2026-11-22:** **QA-CFG-LOGIN-01** — flavor `equipo` sirvió Flutter web en `localhost:8083`; API `/salud` confirmó BD conectada, pero el login demo quedó en spinner tras enviar formulario. Se detuvo el servidor web de prueba; no se validó pantalla autenticada ni se cambiaron datos de negocio.
- **2026-11-22:** **ENV-TUNNEL-KEEP-01 / QA-ENV-REMOTE-01** — el founder reafirma `MODO=tunel` y `usarTunel=true`: aún no hay VPS y Cloudflare Tunnel permite usar Foody fuera de casa. El destino API público del preview local coincide con esa estrategia. Mantener como decisión aceptada hasta terminar la app; al cierre revisar VPS, deploy y configuración final.
- **2026-11-22:** **NAV-CFG-HUB-01 / DS-BASE-01** — agregado `ConfiguracionAdminScreen` como índice de pantallas de ajustes existentes; opciones filtradas por permisos. Se reorganizó el grupo Configuración sin retirar deep links ni añadir API. Guía visual documentada en `FRONTEND_DESIGN_AUDIT.md`; QA visual por rol pendiente.
- **2026-11-22:** **DS-REF-01** — registradas cuatro referencias aportadas por el usuario: dashboard SaaS oscuro, analítica móvil, dashboard tablet claro y tabla de inventario densa. Se especificó qué patrón adaptar por contexto y qué identidad/contenido ajeno no copiar. Rediseño vista por vista pendiente.
- **2026-11-22:** **QA-UI-REDISENO-01** — `flutter analyze` sobre 4 archivos tocados: sin issues. Análisis global: 65 infos + 1 warning previo (`lib/features/auth/data/auth_repository.dart:86`, `dead_null_aware_expression`). `verificar-ci.ps1`: 26 OK / 1 fallo por RLS ausente en `cobros_idempotencia`, `rate_limit_entries`, `usuario_permisos`; API/BD y módulos principales responden. La suite también encuentra `verificar-p2-pulido.ps1` roto al llamar `GetResponseStream` sobre `HttpResponseMessage`; salud local imprime agente de impresión offline y cola con 264 errores, por lo que no se pudo certificar impresión hardware.

- **2026-11-22:** **UX-INV-REDISENO-01** — hero azul oscuro con acento naranja, CTA escritorio y tabs con iconos y resumen derivado de datos existentes; guía redundante retirada. Sin cambios backend/API/modelos ni flujos. `dart analyze` sin incidencias; QA visual/manual pendiente.
- **2026-11-22:** **UX-INV-TRASLADOS-01** — formulario «Nuevo traslado» con shell de formulario compartido; cabecera adaptable, tarjetas de traslado con estado/acción claros y estados vacío/error/sin permiso mejorados. Solo UI; `dart analyze` limpio; QA manual pendiente.
- **2026-11-22:** **UX-INV-TABLA-01** — vista Mercado usa tabla densa en escritorio ancho siguiendo la referencia visual, grid en tablet y cards en compacto; filtros, costos/stock y menú de acciones existentes preservados. `dart analyze --fatal-infos` focalizado limpio; QA visual pendiente.
- **2026-11-22:** **UX-INV-MOV-01** — movimientos reorganizados como registro compacto con transición de stock destacada, metadatos secundarios y acceso preservado al insumo relacionado. Solo UI; análisis focalizado sin errores.
- **2026-11-22:** **DS-FORM-THEME-01** — shell común de formularios dejó de forzar blancos/grises; superficies, textos y bordes se derivan del tema Foody y los campos heredan el input theme global, extendiendo soporte claro/oscuro a 43 usos existentes.
- **2026-11-22:** **UX-SUBRECETA-THEME-01** — diálogo de subreceta ajustado para usar superficies y colores semánticos del tema en opción de stock, alerta de lote, filas de insumos y subtotal; no se altera cálculo ni guardado.
- **2026-11-22:** **UX-MENU-PRODUCTOS-01** — listado de productos presenta tabla compacta desde 1100 px y conserva tarjetas en móvil/tablet; incluye precio local/para llevar, cocina, estado de costeo, disponibilidad y acciones existentes. Menú de acciones compartido; sin cambios en repositorio/API/reglas; falta QA visual.
- **2026-11-22:** **UX-MENU-EXTRAS-01** — Toppings y Bebidas usan tabla compacta en escritorio ancho y conservan tarjetas en móvil/tablet; precio, costeo/margen, switch de disponibilidad y acceso a Costos preservados. `dart analyze` focalizado limpio; QA visual pendiente.
- **2026-11-22:** **UX-MENU-CAT-COMBOS-01** — gestión de Categorías usa diálogo responsive tema-aware; listado de Combos adopta tabla de escritorio y tarjetas compactas/tablet con contenido, precio, disponibilidad y carga de foto preservados. Análisis focalizado limpio; QA visual pendiente.
- **2026-11-22:** **UX-MENU-DIALOGOS-01** — asignar cocina y configurar toppings de plato ahora usan el shell de diálogo responsive Foody; el resumen de costo/precio usa superficies del tema. Análisis focalizado limpio; QA visual pendiente.
- **2026-11-22:** **UX-MENU-COPIAR-01** — diálogo de copiar menú adaptado a Foody con selección de sede agrupada y alcance explícito (incluye categorías/productos/toppings/bebidas; combos no se copian). Solo UI; análisis focalizado limpio.
- **2026-11-22:** **UX-FAC-LISTADO-01** — listado de facturas pasa a tabla en escritorio ancho y conserva tarjetas compactas; columnas estado, cliente, fecha, total y acciones existentes. `dart analyze` focalizado sin incidencias; QA visual pendiente.
- **2026-11-22:** **UX-FAC-FORM-01** — config fiscal, vista previa y anulación usan tema/shell compartido; vista previa tiene jerarquía de comprobante y motivo incluye ayuda visible. DIAN/elegibilidad fiscal no se modifican. `dart analyze` focalizado limpio.
- **2026-11-22:** **UX-CHECKOUT-01** — formulario de checkout limitado a 760 px en escritorio y centrado; tokens de entrada/selección/superficie/botones toman el tema activo y barra final se alinea al contenido. Solo UI; cálculo/envío permanecen backend-first. `dart analyze` limpio.
- **2026-11-22:** **UX-CARRITO-01** — lista, CTA fija y detalle de línea limitados a 760 px en escritorio; superficies, textos, controles y hoja inferior usan el tema activo. Swipe, stepper, extras y subtotal siguen intactos. `dart analyze` limpio.
- **2026-11-22:** Caja ajusta la composición al ancho del panel. Pedidos, Menú, Conteo/Subrecetas y diez vistas administrativas incorporan colores del tema activo. `dart analyze` focalizado: 0 errores y 0 advertencias, con cuatro avisos históricos de Reportes. API con BD conectada, inicio demo y lecturas de sedes y Caja verificadas.
- **2026-11-22:** El panel del restaurante incorpora navegación plegable, transiciones breves, barra superior adaptable, búsqueda inmediata y cargas que respetan el tema y la reducción de movimiento. Inicio carga por defecto después del login. El registro de notificaciones deja de bloquear el acceso y la espera del token al salir tiene límite. Se verificaron ingreso, cierre, Caja y navegación compacta con la compilación local de Equipo. Continúa la revisión de formularios y acciones por módulo.
- **2026-11-22:** El listado de Mesas valida la sede en el controlador. El contrato se comprobó en una instancia aislada de Nest con 400 para el valor inválido y 200 para el válido. No se reinició la API del túnel.
- **2026-11-22:** Los diálogos del panel adoptan el tema y movimiento compartidos. Conteo, fiado y anulación explican los datos inválidos dentro del formulario. Foody Control adapta navegación, carga y tema. Se comprobó en navegador la cancelación de formularios y en la API activa el 400 de Mesas.

- **2026-08-20:** **CAJ-TURNO / ANA-FILT-PROD / ANA-ESTADOS / COC-REIMP** — `horas_abierta` + alerta `caja_turno_longevo` (>12 h, sin auto-cierre) + banner caja; KPI/series con filtro ítem = `SQL_VENTA_LINEA_ITEM`; `estados` sin cancelados salvo `incluir_cancelados`; `POST /impresion/reimprimir` + botón KDS. Check: `verificar-lote-turno-ana-reimp.ps1`.
- **2026-08-19:** **Lote 🟡** — `tipo=mesa` exige `mesa_id`; descuento manual limpia `promocion_id`; DELETE promo SET NULL (mig 089); cancel domicilio libera sesión + cierra ofertas; ajuste stock alerta mínimo + movimientos con `usuario_id`; transfer copia mesera y UI cajero; filter no aplana detalle caja/códigos mesa; CHECK estados pedido. Check: `verificar-lote-amarillo.ps1` · `dart analyze` mesas_grid.
- **2026-08-11:** **VIRAL-FIX-01/03/04/05** — `REGISTRO_RESTAURANTE_ABIERTO` + cupo diario + max/min; `GET /auth/registro-estado`; UI waitlist; horarios/zona post-commit; `BCRYPT_ROUNDS`. Check: `verificar-viral-registro.ps1` OK (503 con ABIERTO=0) · Nest reiniciado · `dart analyze` auth OK.
- **2026-08-11:** **SEC-RLIMIT-03 + INFRA-EXT-UI-03** — `@RateLimitPublico` en `menu`/`ciudades`/`geografia`; SEC-RLIMIT-01 🟡 (`RATE_LIMIT_FORZAR`); KDS `_itemsEnVuelo`/`_conLockItem`; DK-COMPOSE-04 🟡 (archivos en árbol). Check: `verificar-sec-rlimit-kds.ps1` OK (429 con FORZAR=1) · Nest reiniciado · `dart analyze` kds 0 issues.
- **2026-08-11:** **AQ-CYCLE-04 + AQ-DUP-09 + DASH-CONS-COMP** — `PedidosRepository`/`PedidoAdminModel` → `features/pedidos/` (shim admin); `AnaliticaTokens` → `core/tema/` (shim analitica); KPI «Cerrados hoy»; CAP-INFRA nota réplicas en compose. Check: `verificar-aq-cycle-dup.ps1` OK · `dart analyze` paths OK · `GET /salud` OK.
- **2026-08-11:** **PERF-CACHE-02/03 + PERF-SQL-03 + API-VAL-02** — cache ciudades/restaurantes TTL 3 min; dashboard resumen TTL 30 s; top_productos_7d desde `pedidos`→items; ParseUUID en restaurantes/almacenamiento/facturación/categorías/inventario conteos/horarios. Check: `verificar-perf-cache-api-val.ps1` OK · Nest reiniciado.
- **2026-08-11:** **CONC-INV-LOCK-01 + INFRA-EXT-DOWN-01/02 + SEC-BAC sync** — `exigirIngrediente` `FOR UPDATE`; `ApiOfflineBanner` en panel; splash staff con diálogo Reintentar/Login si API caída (no entra a dashboard); SEC-BAC-03/04 reconfirmados ✅. Check: `verificar-conc-inv-infra-down.ps1` OK · Nest reiniciado · `dart analyze` paths 0 issues.
- **2026-08-11:** **CONS-COSTO-SNAPSHOT-01 + CONS-MARGEN-STALE-01** — editar cantidad actualiza `margenes_venta`; analítica invent./rentabilidad declara `fuentes_cogs` / `fuente_cogs` (snapshot vs costo actual). **CFG-GLOBAL-DEAD** reconfirmado ✅ (`verificar-f3-confianza.ps1` OK; docs auditoría sync). Check: `verificar-cons-costo-snapshot.ps1` OK · Nest reiniciado · `dart analyze` analitica (solo infos Share).
- **2026-08-11:** **CONS-CUADRE-SQL-01 + CONS-REP-OPEN-01 + CFG-POLIGONO-03** — script cuadre usa mismos filtros API (venta−devolución + coalesce fecha); API/`reportes` etiquetan Tickets vs Cobrado neto + `nota_universos`; mig `088` COMMENT depreca `zonas_cobertura.poligono`. Check: `verificar-cuadre-caja.ps1` OK (API=BD; diff tickets/caja esperable) · Nest reiniciado · `dart analyze` reportes (solo infos deprecados Share/Table).
- **2026-08-11:** **CFG-NOMBRE-MARCA-07** — `PATCH /sucursales/marca` con `nombre`/`telefono` + UI «Nombre / tel»; CFG-CACHE-MARCA-04 → 🟡 (listado ciudad sin caché Nest). Check: `scripts/verificar-cfg-nombre-marca.ps1` OK · Nest reiniciado · `dart analyze` sucursales 0 issues.
- **2026-08-11:** **CONS-PROMO-ADD-01 + CFG-PATCH-SUCURSAL-01** — add/delete/update ítems reaplica % promo (monto fijo topeado a subtotal); `PATCH /sucursales/:id` + UI «Editar sede». Check: `scripts/verificar-cons-promo-cfg-patch.ps1` OK · Nest reiniciado · `dart analyze` sucursales (warning unused local removido).
- **2026-08-11:** **RT-POLL/FALL + CONS-NODISP** — `PollRealtimeRespaldo` reevalúa RT cada ciclo (90s/30s); poll en menú cliente, POS, panel suscripción y domi planta; N/D cocina pone `productos.disponible=false` + invalida caché/RT catálogo (VIE-09 C merma intacta). Check: `scripts/verificar-rt-fall-poll.ps1` OK · Nest reiniciado · `dart analyze` paths OK (solo infos).
- **2026-08-11:** **Lote 🟣 abiertos** — FUZZ-LEN-01 `@MaxLength(80)` mesa; SEC-BAC-06 `gestionar_finanzas` (mig `087`) en mutaciones `/finanzas/*`; RT-ENV-01 una `SUPABASE_URL`; INFRA-EXT-TO-02 Dio `sendTimeout`; CAP-GROW-01/02 purga cron cola FCM (>14d) + auditoría (>90d); PERF-FL-MEM pulso mesas condicional + caja tope 80 en memoria. Sync MASTER: N1/DISK/LIFE/CAP-FL/DK-SEC/etc. Check: `scripts/verificar-lote-purpura-abiertos.ps1` OK · Nest reiniciado · mig 087 OK.
- **2026-08-11:** **DASH-*** — Inicio: poll 75s + «Actualizado HH:mm · no en vivo»; KPI Ventas→Reportes; KPI QR pendientes; top 7d `ORDER BY cantidad`; copy «Tendencia de la sede»; banner RT aclara Inicio. Check: `verificar-dashboard-general.ps1` OK · Nest `dist` reiniciado · `dart analyze` paths OK.
- **2026-08-11:** **Bloque D** — FL-STATE-01/02: `operacionSucursalProvider` (epoch pedidos + publicar caja); caja invalida al abrir/cerrar; mesas/kanban `ref.listen`. FL-WIDGET-01: `AsignarDomiciliarioSlot` extraído del kanban. AQ-SOLID-08: food cost/margen % desde API en receta/incluidos (sin `precio−costo` en KPIs). UTF-8 kanban reparado. Check: `verificar-bloque-d-flutter.ps1` OK · API `/salud` OK.
- **2026-08-11:** **AQ-SCALE-01 / PERF-POOL-01** — guard prod: `validarConfigProduccion()` ahora exige `DB_POOL_MAX` numérico y >=25 (evita fallback silencioso de pool 10). Smoke: `GET /api/v1/salud` OK tras reiniciar `start:prod`. Check: `GET /api/v1/salud` True.
- **2026-08-11:** **AQ-SCALE-02/05** — crons líder único con `pg_try_advisory_lock` + rate-limit multi-réplica vía Postgres (`rate_limit_entries`) y `RateLimitGuard` (fallback a Map si falla BD). Smoke: `GET /api/v1/salud` True + `scripts/verificar-rate-limit.ps1` devolvió `429` (OK).
- **2026-08-11:** **Huérfanos UI (Prompt 28) — HUER-REPO-03** — Finanzas: diálogo editar costo fijo conectado a `PATCH /finanzas/costos-fijos/:id`. Check: `dart analyze` finanzas; `verificar-huer-repo-03.ps1` (nuevo) OK.
- **2026-08-11:** **Huérfanos UI (Prompt 28) — D3** — KDS nota/observaciones (PATCH API), combos costeo cableados en Costos/Márgenes y badge «No disponible» ya no tiene `onTap: () {}`. Check: `verificar-huer-d3.ps1` OK · `dart analyze` touched paths OK.
- **2026-08-11:** **Huérfanos UI (Prompt 28) — HUER-CFG-01** — márgenes sede editables (`margen_objetivo_default`, `umbral_alerta_margen`) vía UI/`PATCH /sucursales/margenes/:sucursalId` + costeo usa fallback de sede. Check: `verificar-huer-cfg-01.ps1` OK · `flutter analyze` costeo OK.
- **2026-08-11:** **AQ-SCALE-03** — Menú: eliminadas N+1 de combos (1 query `combo_items` + agrupar por `combo_id`). Check: `scripts/verificar-menu-01.ps1` OK.
- **2026-08-11:** **AQ-SCALE-04 (parcial)** — Cache menú: single-flight por `sucursalId` + TTL 15 min (menos reconstrucciones por expiración). Smoke: `scripts/verificar-menu-01.ps1` OK.
- **2026-08-11:** **PERF-SQL-01** — dashboard “hoy”: `SQL_PEDIDO_ES_HOY` pasó a rango half-open (quita cast `created_at::date`). Check: `scripts/verificar-dashboard-general.ps1` OK.
- **2026-08-11:** **PERF-SQL-02 (parcial)** — dashboard `top_productos_7d` y reportes `/reportes/productos`: reemplazado `SQL_VENTA_LINEA_ITEM` correlacionado por joins a agregados (toppings/bebidas) sin romper consistencia. Check: `scripts/verificar-dashboard-general.ps1` + `scripts/verificar-reportes-analitica.ps1` OK.
- **2026-08-11:** **PERF-SQL-04** — reportes caja: `SQL_FECHA_CAJA_COALESCED_P2_P3` pasó de `COALESCE` a filtros `OR` (sargable). Check: `scripts/verificar-caja-coherencia.ps1` OK.
- **2026-08-11:** **DK-LOG / INF-DISK** — `docker-compose.prod.yml`: agregada rotación de logs (`json-file` max-size/max-file) para evitar crecimiento infinito en VPS. (No requiere VPS para verificar configuración)
- **2026-08-11:** **CAP local** — script `scripts/verificar-cap-local.ps1` OK: levantó 2do backend en `:3001` y probó `429` compartido alternando requests entre `:3000`/`:3001` (rate-limit en Postgres).
- **2026-08-11:** **Huérfanos UI — HUER-REPO-01** — depuración: retiro `InventarioRepository.costosProductos` (método muerto sin callers; duplica costeo). Check: `rg costosProductos(` solo definición + `flutter analyze inventario_repository.dart` OK.
- **2026-08-11:** **Huérfanos DB — HUER-DB-01/02** — deprecación documentada por falta de consumo: `presentaciones_compra` / `ajustes_stock` no aparecen en `foody_backend/src` ni en `lib/`. Check: `rg presentaciones_compra|ajustes_stock` no matches.
- **2026-08-11:** **Bloque D parcial** — HUER-HALF-01: facturación DIAN pausado ya no muestra “Resolución DIAN” en HTML/PDF (backend `FacturacionService`). Check: `verificar-huer-half-01.ps1` OK · `verificar-bloque-d-flutter.ps1`.
- **2026-08-11:** **USR-PERM-01b** — checklist solo plantilla del rol (mesero no ve `abrir_caja`); API rechaza permisos ajenos al rol; UI cobra exige `cobrar_pedido` (botón oculto / mensaje). Check: `verificar-usuario-permisos.ps1`.
- **2026-08-11:** **USR-PERM-01** — checklist de permisos **solo del usuario** editado/creado (no cambia el rol global). Mig `085_usuario_permisos.sql`; `AuthService.permisosEfectivos` (JWT/login); `permisos[]` en crear/actualizar; `GET /usuarios/:id/permisos`; catálogo + `permisos_disponibles`. UI Usuarios. Check: `verificar-usuario-permisos.ps1` OK · `dart analyze` usuarios OK.
- **2026-08-11:** **RBAC-MESERO-04 / RBAC-FIX-04** — `domiciliarios-planta` asignar/reasignar/dispatch/disponibles solo `@Permisos('gestionar_domiciliarios')` (sin OR `ver_pedidos`). Kanban: slot asignar + carga lista solo con ese permiso. Check: `verificar-rbac-mesero-04.ps1` OK. **Bloque C ✅**.
- **2026-08-11:** **API-PAGE** — `opcionesListado` + tope 200; usuarios/productos/insumos paginan con `?page=`; extras catálogo con LIMIT. Flutter sigue recibiendo array sin `page`. Check: `verificar-api-page.ps1` OK.
- **2026-08-10:** **UI Costos Stitch v2** — lista a pantalla completa (scroll único + FAB «ARMAR RECETA» móvil); detalle 2 columnas (preview+Estado Financiero | Mesa/Local+Incluidos+barra Aplicar a la carta); filas desktop con thumb/costo/precio sug.; resumen API +`imagen_url`/`categoria_nombre`/`receta_id`. Check: `dart analyze` costeo.
- **2026-08-10:** **UX-SHELL-01** — widget `SaasScrollableShell` (`NestedScrollView`): cabecera (títulos/KPIs/banners) scrollea; tabs quedan en body. Aplicado en Costos/Márgenes, Analítica, Menú, Insumos, Reportes, caja (respeta `ocultarCabecera`), usuarios, alertas, facturación, domiciliarios, zonas, horarios, sucursales, cocinas. Ya scrollables: Finanzas, Promociones. Check: `dart analyze` paths shell — 0 errors.
- **2026-08-10:** **UI Costos y Márgenes (Stitch)** — resumen Saludable/Margen bajo/Sin costear, margen global, pills Todos/Críticos/Saludables/Sin datos, badges de margen con glow, card Estado Financiero; tokens theme-aware. Lógica costeo intacta. Check: `dart analyze` costeo 0 errors.
- **2026-08-10:** **UI SaaS Insights+Finanzas** — kit `lib/core/saas_ui/` (tokens theme-aware, KPI, charts, filters, tables→cards, empty/alerts/insights); `TemaFoody.claro/oscuro` + `temaModeProvider` (SharedPreferences); toggle en AppBar panel; Analítica Resumen rediseñado (Personalizado `preset=rango`, dual-series vs anterior, heatmap horario, 9 filas); Finanzas hub (KPIs P&L, ingresos vs gastos, donut categorías, tablas CRUD, empty honestos presupuesto/proyección/facturas/flujo). Sin cambios Nest. Check: `dart analyze` paths 0 errors · `verificar-finanzas.ps1` OK · `GET /salud` exito.
- **2026-08-08:** **UX-PAYWALL-BLUR** — preview módulo bloqueado = esqueleto estático borroso (sin montar pantalla ni API) + card upgrade; búsqueda admin con candados. Check: `flutter analyze` OK.
- **2026-08-08:** **DOM-APP** — Shell NavigationBar (activos/historial|ofertas/ingresos/perfil); `TarjetaPedidoDomiciliario` (montos, método pago, tap mapa, sheet contacto WA/llamar); oferta con `ganancia_estimada` API; tab ingresos + filtros fechas; dispatch auto-retry post-expiración + intento vacío persiste radio; FCM/Kanban TTL dinámico. Doc `FRONTEND_DOMICILIARIO_APP.md`. HUER-API-DOM-01 ✅.
- **2026-08-08:** **Bloque D parcial** — FL-NAV-01: `mesas_grid` `push` cajero; FL-WIDGET-02: menú sin `watch` raíz del carrito (`Consumer`+`select`); PERF-FL-IMG: `memCacheWidth/Height` menú cliente + `cacheWidth` thumbs admin. Check: `flutter analyze` paths tocados.
- **2026-08-08:** **Bloque C parcial** — `salio-sin-pagar` usa `PedidosEstadoCommandService` (PED-BYPASS-01); `ParseUUIDPipe` en finanzas / domiciliarios-planta / super-admin; BN-CTRL-07 subtotal DTO; `verificar-ci.ps1 -Completo` incluye bn-* + rt-sec. Check: `verificar-bn-residuales` OK · ciclo-vida §D salio-sin-pagar OK (cobros A/C fallos ajenos previos).
- **2026-08-08:** **Bloque B / RT-SEC-01 ✅** — Topics staff `tipo_{id}_{hmac16}` (`realtime-topics.ts`); Nest emite solo firmados; login + `GET /auth/realtime-canales`; Flutter `realtime_canales` + `FoodyRealtime`. Catálogo/pedido públicos. B2: validador JWT corto en prod. B3: `RATE_LIMIT_FORZAR`. Check: `verificar-rt-sec.ps1` OK · `dart analyze` paths OK. **Re-login staff** tras deploy.
- **2026-08-08:** **F5 / Bloque A piloto ✅** — Founder confirmó pago sandbox → plan actualizado sin sync manual. Criterio A cerrado (waiver archivo + Wompi E2E + PC+túnel). Diferidos: térmica papel + VPS Ubuntu. Docs PRIORIDADES / CHECKLIST_F5 / MASTER / ROADMAP P0-06/07.
- **2026-08-08:** **Bloque A — sesión go-live** — Docker/Supabase/Nest + cloudflared + agente impresión archivo; `verificar-f5-golive` / `verificar-wompi-tunel` OK.
- **2026-08-08:** **PRIORIDADES_FOODY.md** — lista viva A→F consolidada.
- **2026-08-07:** **Residuales menores** — `GET /salud/completo`; `ParseUUIDPipe` en 15 controllers hot; `AprobarPedidoMesaDto` sin `= {}`; PIPE-04 documentado en `main.ts`. Check: `verificar-bn-residuales.ps1` OK (+ query-rest OK).
- **2026-08-07:** **Documentación cierre** — `docs/REMEDIACION_NEST_AUTH_2026-08-07.md`: implementado, scripts OK/FAIL gaps, § **Detalles a pulir**. MASTER + auditorías sincronizados.
- **2026-08-07:** **BN-DTO-01/02** — `RegistrarFcmDto` / `DesactivarFcmDto`; `verificar-bn-dto-fcm.ps1` OK. **BN-CTRL-02/03** — authz usuarios y gate traslados/hermanas bajados a services; `verificar-bn-ctrl-usuarios.ps1` + editar OK. **BN-EXC-18** documentado ✅ (job error auditable).
- **2026-08-07:** **BN-FIX-04 + BN-FIX-05** — `ValidarCodigoPromocionDto`, `BuscarGeografiaDto`; `@IsBoolean` en `CrearPedidoDto`; cron suscripciones retorna `renovaciones_fallos` (EXC-05). Check: `verificar-bn-dto-query.ps1` OK.
- **2026-08-07:** **BN-FIX-06 / BN-PIPE-03 / API-VAL-01** — `ValidationPipe({ whitelist, forbidNonWhitelisted, transform })` en `main.ts`. Props/query desconocidos → 400. Check: `verificar-bn-pipe-forbid.ps1` OK · auth-flow + bn-dto-inline OK.
- **2026-08-07:** **BN-FIX-01 / AQ-SOLID-03 / AQ-DUP-04** — `AlmacenamientoController` delgado (solo multer + scope); ownership SQL, UPDATE `imagen_url` e invalidación menú en `AlmacenamientoService.subirImagenEntidadCatalogo` (producto/promo/combo/categoría). Check: `verificar-bn-almacenamiento.ps1` OK.
- **2026-08-07:** **BN-FIX-03 + RT-SCRIPT-01** — DTOs class-validator BN-DTO-06…19 (pedidos/catálogo/cocina/domi/facturación) + `CotizarDomicilioDto` en query; `verificar-bn-dto-inline.ps1` OK. Script realtime lee `/health` (no `/salud`) para `realtime.conectado`. FL-LEAK-02 ya cubierto por `FoodyRealtime.liberarCanal` (doc sincronizado).
- **2026-08-07:** **AUTH-FLOW / AUTH-REV** — mig `084` (`usuarios`/`domiciliarios_independientes.token_version`); JWT claim `tv`; `UsuarioActivoGuard` rechaza mismatch (`SESION_REVOCADA`); `POST /auth/refresh` (re-emite sin bump) + `POST /auth/logout` (bump); password super-admin bumpea `tv`; Flutter: logout → API luego clear; Dio renueva si `JwtStaff.porExpirar` (30m) + **retry 1×** tras 401 (AUTH-FIX-04). Check: `verificar-auth-flow.ps1` OK · `dart analyze` auth paths OK · `jwt_staff_check` OK.
- **2026-08-07:** **FL-LEAK-01 + BN-DTO-03** — `try/finally` dispose TEC en diálogos inventario (compra/ajuste/lote/conteo); DTOs class-validator en `POST /dispositivos/registrar|vincular-auth` + body anonimizar. Check: `dart analyze` inventario OK · `verificar-f3-confianza.ps1` OK.
- **2026-08-07:** **VIE paquete 1C/2C/3C** — `pagado` exige cocina completa (`listo|no_disponible`) o admin/gerente+motivo; abono→`pagando` libre. Fallo prep `POST /cocina/items/:id/fallo-preparacion` → N/D + merma + alerta. Qty↓ en preparando/listo → `CANTIDAD_COCINA_INMUTABLE`. Check: `verificar-vie-politica.ps1` OK · Jest casos-limite+mesa+caja 7/7. Docs: CASOS_VIERNES + MASTER + INFORME.
- **2026-08-07:** **AQ-DUP-01 cierre** — `CosteoService.aplicarMovimientoStock` delega a `StockMovimientoService` (`tipo=produccion` + `produccion_id`); módulo `StockMovimientoModule` compartido (evita ciclo Costeo↔Inventario). Build OK. **Verificación API:** bloqueada — Docker/Postgres caído (`ECONNREFUSED :5432`); re-correr `verificar-produccion-lote.ps1` + `verificar-inventario-ciclo.ps1` cuando DB esté up.
- **2026-08-06:** **AUTH-WEB-01 (prod-risk)** — En `equipo.foodyy.store` (release) `flutter_secure_storage` lanzaba `MissingPluginException` al leer/guardar JWT → login correo y Google fallaban al persistir sesión (API OK). Fix: web usa SharedPreferences; móvil secure storage + fallback prefs. Rebuild `servir-web-tunel-release.ps1`. Ruido consolas: adblock (`ERR_BLOCKED_BY_CLIENT`), FCM push AbortError, Firebase Identity Toolkit `CONFIGURATION_NOT_FOUND` (**AUTH-FB-01**, no bloquea auth Nest/Supabase). Check: `verificar-f4-sesion.ps1` OK · login local `exito=true` · SPA :8080/túnel 200 · bundle sin canal secure_storage.
- **2026-08-06:** **UX producción en lote** — dos modos claros (stock al vender vs preparar lote); badge «Sin preparar» (no falso stock bajo); CTA Preparar lote; `Prep:` fuera de lista/alertas de insumos. Check: `verificar-produccion-lote.ps1` OK.
- **2026-08-06:** **Unidades receta/subreceta** — UI ya no fuerza `unidad_base` al guardar; selector g/kg o ml/L; backend convierte en costeo y en `expandirReceta` (stock). Check: `verificar-unidades-costeo.ps1` (250g de kg → costo 1050) OK · `dart analyze` paths sin errors.
- **2026-08-06:** **F7 AQ-DUP-01** — `StockMovimientoService` (UPDATE `ingredientes` + INSERT `movimientos_ingrediente`); callers: venta/restaurar/merma (PedidosInventario), ajuste/compra/conteo/traslados (Inventario). PedidosModule importa InventarioModule. Residual: `CosteoService.aplicarMovimientoStock` (`tipo=produccion`). Check: `verificar-inventario-ciclo.ps1` OK; `verificar-pedidos-ciclo-vida.ps1` stock OK (1 assert ajeno: items cobrados).
- **2026-08-06:** **Finanzas claro** — `GET /finanzas/resumen` (mes vs anterior, por pagar, consejos); UI panel ganancia/pérdida + tabs con conteo pendiente; diálogo pago monto/periodo; CTA a tab Rentabilidad; consejos en analitica. Check: `verificar-finanzas.ps1` OK · `dart analyze` sin errors.
- **2026-08-06:** **F7 AQ-CYCLE-01** — `PedidosDispatchHooksService`: PedidosModule ya no importa Domiciliarios; `DispatchService` se registra en `onModuleInit`. Check: `verificar-f7-deuda.ps1` + `verificar-flujo-domicilio.ps1` (auto-dispatch → asignado) OK.
- **2026-08-06:** **F7 — Deuda media (parcial)** — `ParseUUIDPipe` en menú/caja/pedidos/cocina (UUID basura→400); `FoodyRealtime.liberarCanal` + 9 pantallas; KDS botón Urgente + `marcarPrioridadItem`. Abiertos: AQ-DUP-01, AQ-CYCLE-01. Check: `verificar-f7-deuda.ps1` OK · `dart analyze` sin errors.
- **2026-08-06:** **F6 — Perf turno** — mig `083` (`idx_cajas_sucursal_estado`, `idx_movimientos_caja_*`); `GET /caja/:id/movimientos` paginado; Flutter loop páginas; DASH-TZ `(created_at AT TIME ZONE 'America/Bogota')`. Check: `verificar-f6-perf.ps1` OK · `dart analyze` caja_repository sin issues.
- **2026-08-06:** **F5 — Go-live P0 (parcial)** — BN-EXC-01/02: fallo fuente Wompi → `auditoria_logs` + `logger.error`; BN-EXC-18: encolar impresión deja job `error`; cron renovación cuenta fallos; `verificar-f5-golive.ps1` OK (aviso agente offline); checklist humano `CHECKLIST_F5_GOLIVE.md`. **No ✅** hasta térmica/Wompi dashboard/VPS.
- **2026-08-06:** **F4 — Sesión & totales** — JWT staff en `flutter_secure_storage` (+ migración prefs); `POST /pedidos/estimar` (mismo pricing que crear, sin INSERT); checkout muestra total servidor; sheets/badge = hint UI-only. Check: `verificar-f4-sesion.ps1` OK.
- **2026-08-06:** **F3 — Confianza Foody** — `ConfiguracionGlobalModule` carga `configuracion_global_foody` → umbrales/dispatch + `recargar()` tras super PATCH; tab Rentabilidad gated `ver_finanzas`; `DELETE anonimizar` posesión (`fcm_token`/auth) sin mutar `plataforma`; `prueba-web` `@Permisos('ver_dashboard')` + tokens propios. Check: `verificar-f3-confianza.ps1` OK · `dart analyze` 0 errors (4 infos Share deprecados).
- **2026-08-06:** **F2 — Política & stock** — permiso `cobrar_pedido` (admin/gerente/cajero); mesero 403 cobro + UI sin cobro; whitelist estados mesero (`pagando`/`cancelado`); cascade `sincronizarPorIngredienteEnTransaccion` en descontar/restaurar. Mig `082`. Check: `verificar-f2-politica.ps1` OK.
- **2026-08-06:** **F1 — Turno estable** — `onReconectado`+lifecycle en KDS/kanban/caja/mesas/sheet; `_cobrando`+`idempotency_key`; post-timeout GET; mig `081` (`uq_caja_abierta_sucursal` + `cobros_idempotencia`); caja insert+23505. Check: `verificar-f1-turno.ps1` OK · `dart analyze` sin errors en paths F1.
- **2026-08-06:** **F0 — Parar sangre** — IDOR `POST /caja/cerrar` scopea sucursal de la caja; prepago no bloquea cierre (`SQL_WHERE_PEDIDO_OPERACION_ABIERTA` + cocina→`pagado`); VIE-01 demote `listo`/`pagando`→`en_cocina`; COC-NODISP `no_disponible` resuelto. Checks: `verificar-idor-scope.ps1` · Jest casos-limite+cocina 6/6.
- **2026-08-06:** **Unificación docs** — `AUDITORIA_*.md` movidos a `archivo/auditorias-prompts/`; README hub corto; AGENTS + foody-avance apuntan a MASTER + INFORME_MAESTRO; qa-sesiones archivadas.
- **2026-08-06:** **Prompt 35 Informe maestro** — Consolida Prompts 01–34: inventario por severidad/módulo; fichas crítico/alto con archivo+causa+código+horas; plan F0–F8 por impacto restaurante (no por facilidad); §6 CAP/VIRAL como decisiones infra/$$ (no bugfix). Doc: `INFORME_MAESTRO_FOODY.md`.
- **2026-08-06:** **Prompt 34 Infra extremos** — Timeout Dio 15/45s mid-TX (COMMIT posible); doble cobro paralelo 1 OK/1 reject; mensajes offline OK; splash staff entra con API caída; resync = RT-RECON/LIFE. UI cobro mesa/kanban sin busy. IDs **INFRA-EXT-\***. Check: `verificar-infra-extremos.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_INFRA_EXTREMOS.md`.
- **2026-08-06:** **Prompt 33 E2E** — Jest/Supertest 7 suites / 14 tests (mesa, QR, domicilio, cocina, caja + casos límite 28–30: VIE-01, VIE-05/13, VIE-06, PED-PREPAGO-01, COC-NODISP-01). Flutter `test/e2e` 5/5 + wrapper `integration_test`. Scripts `verificar-e2e-jest.ps1` / `verificar-e2e-flutter.ps1`. Stub Hello World → `/salud`. Gaps: click-through UI, GH Actions seed. Docs: `archivo/auditorias-prompts/AUDITORIA_E2E_AUTOMATIZADO.md`.
- **2026-08-06:** **Auditoría Prompt 32** — Spike viral registros D1 500 / D2 5k / D3 20k / D4 40k. Flujo real: registro síncrono + bcrypt + TX (~13 inserts); sin OTP WhatsApp/MATIAS/FCM bienvenida. Falla primero: pool PG + CPU bcrypt (no externos). Roadmap escalado F0–F7 (waitlist→Redis→PgBouncer→Nest→PG dedicado). IDs **VIRAL-\*** + **VIRAL-FIX-01…08**. Docs: `archivo/auditorias-prompts/AUDITORIA_VIRAL_SPIKE.md`.
- **2026-08-06:** **Auditoría Prompt 31** — Capacity planning 100/500/1k/5k/10k. Vivo: Nest 1 proceso, `DB_POOL_MAX=25`, PG `max_connections=100` / `shared_buffers=128MB`, ~44 backends; techo ~8–20 RPS (PERF). Tablas: `notificaciones_pendientes` ~39k sin purge, `auditoria_logs` ~33k. Veredicto: 100 parcial piloto; 500+ no sin PgBouncer/PM2/Redis; 1k+ réplica+partición. WhatsApp/MATIAS no son carga (no impl.). IDs **CAP-\*** + **CAP-FIX-01…10**. Docs: `archivo/auditorias-prompts/AUDITORIA_CAPACITY_PLANNING.md`.
- **2026-08-06:** **Auditoría Prompt 30** — Casos viernes alta demanda (13). REGLA_CLARA: transfer, race, no reopen, snapshots, cola impresión, restart PG. BUG: **VIE-01** add con pedido `listo`; **VIE-12** reconnect; **VIE-QTY-01** qty↓ vs merma. DECISIÓN_PENDIENTE (A/B/C): **VIE-05** split/cobro vs cocina; **VIE-09** agotado mid-prep; **VIE-13** cobro pre-listo. Vivo: ciclo+meseros+promos+kds OK. Docs: `archivo/auditorias-prompts/AUDITORIA_CASOS_VIERNES.md`.
- **2026-08-06:** **Auditoría Prompt 29** — Consistencia entre módulos (6 rutas). NEW: **CONS-STOCK-CASCADE-01** (venta no cascadea hermanos), **CONS-PROMO-ADD-01**, **CONS-NODISP-STOCK-01**, **CONS-KDS-UI-01**, **CONS-REP-OPEN-01**, **CONS-COSTO-SNAPSHOT-01**. Reconfirmados PED-PREPAGO / COC-NODISP / CFG-GLOBAL-DEAD / RT-RECON / DASH-*. Vivo: caja-coherencia OK; KPI analítica=reportes 438175; cuadre diff 141k; inventario+promos OK; script coherencia ya no llama `/caja/estado`. Docs: `archivo/auditorias-prompts/AUDITORIA_CONSISTENCIA_MODULOS.md`.
- **2026-08-06:** **Auditoría Prompt 28** — Funcionalidad huérfana: cruce `MAPA_FOODY` ↔ Nest ↔ Flutter. Producto: KDS prioridad/obs, costeo combos, ganancias indep., badge No disponible, tab Rentabilidad sin `ver_finanzas`, CFG-GLOBAL-DEAD, márgenes sede, repos muertos, tablas schema-only. Ops health/impresión/webhook = intencional. Docs: `archivo/auditorias-prompts/AUDITORIA_FUNCIONALIDAD_HUERFANA.md` · MASTER § HUER-\*.
- **2026-08-06:** **NOC Foody** — `SUPERADMIN_FOODY_CONTROL.md` = Centro de Operaciones (visión 10 módulos). **Fase A esencial ahora:** home semáforo + KPI Gratis/Pro/Ultra + freemium kill switch + plan auditado + errores agrupados + asistente por reglas. B/C diferidas. No construir visión completa pre-go-live.
- **2026-08-06:** **Auditoría Prompt 27** — Fuzz inputs: 45 casos (auth/menú/pedidos/staff); **0 stack** al cliente; API viva; 6× UUID/path basura → `ERROR_INTERNO` 500 (envelope OK); mesas nombre 5k aceptado (run previo). IDs **FUZZ-STABLE/STACK/500/LEN/VAL** + **FUZZ-FIX-01…04**. Check: `verificar-fuzz-inputs.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_FUZZ_INPUTS.md`.
- **2026-08-06:** **Spec Foody Control** — Documento `docs/SUPERADMIN_FOODY_CONTROL.md`: KPI cuentas Gratis/Pro/Ultra; cambio plan con motivo; semáforo “¿escalar?” en lenguaje no técnico; incidentes inteligentes (INC-LOAD/ERR/FREE); cupos freemium + kill switch; API propuesta `/super/salud-operativa`. Backlog **SAC-KPI/PLAN/FREE/CAP/INC**. Base ya existente: `GET /super/estadisticas`, `PATCH /super/suscripciones`. Enlace en `docs/README.md` + MASTER §17.
- **2026-08-06:** **Auditoría Prompt 26** — Estrés/concurrencia: multi-tenant GET 60/60 OK; idempotency pedido OK; doble `en_cocina` serializado (FOR UPDATE + no-op); inventario LWW absoluto sin row lock; abrir caja TOCTOU (API-IDEM-03, race omitida si turno abierto); sostenido/pico ligeros 0 fail; mixto 100×3 p99~10s ≡ PERF-LOAD. IDs **CONC-MT/PED/INV/CAJ/LOAD** + **CONC-FIX-01…05**. Checks: `verificar-estres-concurrencia.ps1` · `estres-1000-usuarios.mjs`. Docs: `archivo/auditorias-prompts/AUDITORIA_ESTRES_CONCURRENCIA.md`.
- **2026-08-06:** **Auditoría Prompt 25** — OWASP: SQL parametrizado OK (`SqlParams`); BAC Prompt 06 reconfirmado (IDOR caja, cobro mesero, anonimizar, prueba-web) + finanzas `ver_finanzas` escribe; JWT fallback/DK-SEC; rate limit solo prod; RLS **74/74** FORCE (sin regresión post-080). Fix menor: `config/foody-entorno.env` → `.gitignore`. IDs **SEC-INJ/BAC/SECRET/RLIMIT/RLS** + **SEC-FIX-01…08**. Checks: `verificar-owasp.ps1` · `verificar-rls.ps1` · `verificar-idor-scope.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_OWASP.md`.
- **2026-08-06:** **Auditoría Prompt 24** — Performance Flutter: listas (caja shrinkWrap unbounded = peor path; cerrados/mis pedidos/movs inv OK); memoria turno (Realtime sin `removeChannel`, `_movimientos` crece); imágenes (lazy scroll sí, 0 `memCache*`, Nest sharp WebP≤800, `flutter_image_compress` sin uso). IDs **PERF-FL-LIST/MEM/IMG** + **PERF-FL-FIX-01…09**. Check: `scripts/verificar-perf-flutter.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_PERF_FLUTTER.md`.
- **2026-08-06:** **Auditoría Prompt 23** — Performance backend: EXPLAIN (Seq Scan `pedido_items`/`movimientos_caja`, `created_at::date`, SubPlan `SQL_VENTA_LINEA_ITEM`); caché solo menú; carga RunspacePool 10/50/200 → 0 fails pero p50 0.4s→7–10s (techo ~8–20 RPS, pool 25). IDs **PERF-SQL/IDX/CACHE/LOAD/POOL** + **PERF-FIX-01…09**. Check: `scripts/verificar-perf-backend.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_PERF_BACKEND.md`.
- **2026-08-06:** **Auditoría Prompt 22** — Config restaurante: horarios/zonas/fiscal/cocinas/fiado con UI; **sin** PATCH sede ni márgenes sede; marca sin nombre; `poligono` muerto. Propagación: sin reinicio Nest, sin RT config; horario bustea menú cache; plan guard lee BD. **CFG-GLOBAL-DEAD** (Alta): UI super edita umbrales/comisión/radios pero runtime = hardcode. Check: `scripts/verificar-config-restaurante.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_CONFIGURACION.md`.
- **2026-08-06:** **Auditoría Prompt 21** — Dashboard general: sin RT/poll ni hora «Actualizado»; sin cache Nest (SQL vivo); KPI Ventas→Caja; `pedidos_pendientes_qr` API-only; top «unidades» vs ORDER BY ventas; riesgo TZ `created_at::date` vs Bogota. Consistencia hoy OK: ventas_hoy=financiero=analítica **187200**. Gaps: **DASH-TZ-01**, **DASH-RT-01/02**, **DASH-ORPH-02**. Check: `scripts/verificar-dashboard-general.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_DASHBOARD.md`.
- **2026-08-06:** **Auditoría Prompt 20** — Reportes/analítica: financiero+resumen+top producto = SQL crudo (239200/22/800); filtros analítica AND; reportes solo fechas; 365d ~30ms (Seq Scan, 528 pedidos); umbrales `UMBRALES_ALERTA` = spec; batch ≠ stock/cuadre. Gaps: **ANA-FILT-PROD-01**, **ANA-PERF-01**, **REP-LINE-01**, **ANA-ESTADOS-01**. Check: `scripts/verificar-reportes-analitica.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_REPORTES.md` · `ALERTAS_AUTOMATICAS.md` actualizado.
- **2026-08-06:** **Auditoría Prompt 19** — Facturación: **0 refs MATIAS**; sin cola/reintentos/estados DIAN. Capa interna verificada: borrador→emitir (`FE-########`)→HTML; total factura=pedido; anular soft + stub NC; pedido `pagado` intacto; cancel pagado bloqueado. Gaps pospuestos: **FE-MATIAS-01**, **FE-QUEUE-01**, **FE-NC-01**, **FE-ITEMS-01**. Check: `scripts/verificar-facturacion-ciclo.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_FACTURACION.md`.
- **2026-08-06:** **Auditoría Prompt 18** — Promociones/precios: desactivar promo con pedido abierto **mantiene** descuento (snapshot); pedido nuevo rechaza código; cobro = total congelado. Cambio precio catálogo: ítems abiertos conservan `precio_unitario`; ítems nuevos toman precio actual; cobro mixto OK. Combo + promo **se apilan**; máx. 1 promo (auto = mejor). Gaps: **PROMO-STACK-01**, **PROMO-DEL-01**, **PROMO-MANUAL-01**. Check: `scripts/verificar-promociones-precios.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_PROMOCIONES.md` · MASTER § Promociones.
- **2026-08-06 / verificado 2026-11-23:** **Auditoría Prompt 17** — Clientes/QR: menú+`POST /pedidos` públicos → `pendiente_aprobacion` (sin JWT); **no** autoservicio sin mesero; precio body ignorado (BD); producto off/ajeno rechazado; token QR permanente tras mesa libre; multi-device OK; expiración dura solo cierre caja >30m. `QR-MESA-ID-01` quedó corregido: servicio requiere `mesa_id` para `tipo=mesa` en pedido público, personal y estimación, antes de consultar BD; regresión unitaria 3/3. El verificador manual ahora falla si una API acepta el payload y cancela el pedido inesperado como limpieza. Nest suite completa tras añadir el caso: 18 suites/48 pruebas; cotización contra el Nest activo :3000 rechazó el payload con HTTP 400 `MESA_REQUERIDA`, sin crear pedido. El verificador manual no se ejecutó por sus otras escrituras a BD QA. Pendientes: decisión de autoservicio **QR-AUTO-01** y expiración **QR-EXP-01**. Evidencia vigente en `archivo/auditorias-prompts/AUDITORIA_CLIENTES_QR.md` y MASTER § Mesas/QR.
- **2026-08-06:** **Auditoría Prompt 16** — Domicilios: ciclo `pendiente→…→entregado` con cobro al entregar (sin venta al crear); `listo→entregado` bloqueado; admin `ocupado` coherente; cancel mid-ruta solo admin (asignación `cancelado`, caja neto 0, merma). Gaps: **DOM-CANCEL-INDEP-01** (no restaura `disponible`), **DOM-CANCEL-OFERTA-01**, **DOM-EVID-01**. Check: `scripts/verificar-domicilios-ciclo.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_DOMICILIOS.md` · MASTER § Domiciliarios.
- **2026-08-06:** **Auditoría Prompt 15** — Meseros/mesas: asignación turno + bloqueo otra mesera; transfer pedido en curso (`FOR UPDATE`, historial); split = cobro parcial post-cocina (mismo pedido, **no** hijo); carrera 2 adds serializada sin lost update; sin columna `version`. Aceptados: **MES-SPLIT-HIJO-01**, **MES-XFER-MESERA-01**, **MES-XFER-UI-01**, **MES-MSG-01**. Check: `scripts/verificar-meseros-mesas.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_MESEROS_MESAS.md` · MASTER § Mesas.
- **2026-08-06:** **Auditoría Prompt 14** — Inventario: descuento **automático** al `en_cocina`/`confirmado` (`stock_descontado`; gap “solo manual” cerrado). Propagación plato→subreceta→insumo OK (script −100g Papa). Alerta `stock_minimo_alcanzado` (medio) → panel/RT, **sin FCM**. Ajuste `PATCH` registra `usuario_id`+motivo en `movimientos_ingrediente`, **no** en `auditoria_logs`; API/UI omiten quién. Aceptados: **INV-ALERT-FCM-01**, **INV-ALERT-AJUSTE-01**, **INV-AUD-01**. Check: `scripts/verificar-inventario-ciclo.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_INVENTARIO.md` · MASTER § Inventario.
- **2026-08-06:** **Auditoría Prompt 13** — Caja: sync cobro=`pedidos.total` (tope anti-doble); mixto efectivo+tarjeta = N movimientos; reapertura `pagado` bloqueada (correcto); cancel sin cobro no mueve caja / prepago → devolución; cierre con cuadre+alerta; arqueo ciego oculta saldo. Aceptados: **CAJ-DOM-IMPAGO-01** (domi parcial bloquea cierre), **CAJ-MSG-01**, **CAJ-TURNO-01**. Check: `scripts/verificar-caja-ciclo.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_CAJA.md` · MASTER § Caja.
- **2026-08-06:** **Auditoría Prompt 12** — Cocina/KDS: sync RT `cocina_{id}` + poll; pedido nuevo en tickets + `comanda_copia`; DELETE ítem staff post-prep OK (KDS lo pierde); cocina sin DELETE (solo `no_disponible`). Abiertos: **COC-NODISP-01** (ítem no_disponible impide pedido `listo`), **COC-UI-PRIO-01** (API prioridad sin UI). Parciales: **COC-CANCEL-01**, **COC-FSM-01**, **COC-REIMP-01**. OK: RT, FIFO+urgencia cliente, flujo todos-listo, reimpresión vía edición. Check: `scripts/verificar-kds.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_COCINA_KDS.md` · MASTER § Cocina/KDS.
- **2026-08-06:** **Auditoría Prompt 11** — Pedidos ciclo de vida: mapa 13 estados + `TRANSICIONES_PEDIDO` + puerta `PedidosEstadoCommandService`. API Kanban **no** fuerza inválidas (script OK). Ciclo mesa `en_cocina→listo→pagando→pagado` dispara stock/caja/mesa/historial. Edición post-cocina: stock+reimpresión+merma. Abiertos: **PED-PREPAGO-01** (para llevar efectivo cobra en crear pero queda `en_cocina` → bloquea cierre caja), **PED-BYPASS-01** (`salio-sin-pagar` UPDATE fuera del command), **PED-DOC-01**. Aceptados: **PED-COBRO-SKIP-01**, **PED-EDIT-01**, **PED-CHECK-01**. Check: `scripts/verificar-pedidos-ciclo-vida.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md` · MASTER § Pedidos ciclo.
- **2026-08-06:** **Auditoría Prompt 10 + fix** — Realtime: **`RT-CHAN-01` corregido** (`catalogo_disponibilidad` se emitía solo en `sucursal_{id}` pero el menú cliente y el POS escuchaban `sucursal_{id}_catalogo` → suscripción muerta, productos agotados no refrescaban; ahora emite en ambos topics). Abiertos: **`RT-SEC-01`** (canales no privados: con la anon key + `sucursal_id` público se escucha `caja_movimiento`/alertas → sube OPS-07), **`RT-RECON-01`** (el socket sí reconecta y re-une topics, pero broadcast no tiene replay y nada refetchea al volver), **`RT-POLL-01`** (intervalo de respaldo se fija una sola vez al abrir la pantalla), **`RT-FALL-01`** (menú cliente/POS/panel sin poll), **`RT-LIFE-01`** (sin refetch en `resumed`), **`RT-LEAK-01`** (9 pantallas exactas con `unsubscribe` sin `removeChannel`, agrava la reconexión ≡ FL-LEAK-02), **`RT-ENV-01`** (`SUPABASE_URL` 2× activa en `.env`: gana la última, la primera se ignora en silencio), **`RT-SCRIPT-01`** (`verificar-realtime.ps1:63` lee un campo de salud inexistente → aviso falso permanente). Comprobado OK: **`RT-ORPH-01`** sin eventos huérfanos ni oyentes sin emisor (el `ping` de `foody_health_check` es interno y correcto). Consistencia 2 dispositivos: BD converge (`FOR UPDATE` + máquina de estados), UI es convergencia eventual (ventana ≤90 s). Nuevo check `scripts/verificar-realtime-canales.js` (16/16 OK) — el `verificar-realtime.ps1` existente solo comparaba nombres de evento, no topics. Docs: `archivo/auditorias-prompts/AUDITORIA_REALTIME.md` · MASTER § Realtime.
- **2026-08-06:** **Control financiero** — migr. `080_finanzas_control.sql` (gastos libro único + `empleados` + permiso `ver_finanzas`); Nest `FinanzasModule` (`/finanzas/costos-fijos|empleados|gastos`); `GET /analitica/rentabilidad` (ventas − COGS − gastos = utilidad neta + punto equilibrio); Flutter `FinanzasAdminScreen` + tab Rentabilidad; `verificar-finanzas.ps1` OK (403 rol + arqueo intacto). Spec completa: **`docs/MODULO_FINANZAS.md`** (hecho/parcial/pendiente/recomendaciones). Docs MASTER §23.
- **2026-08-06:** **Auditoría Prompt 09** — Infra: sin Nginx en repo (edge=Tunnel); `foody-assets` público intencional; R2 backups no activos; tunnel PC foreground (WiFi riesgo); SSL=Cloudflare; disco sin presupuesto + logs sin tope. IDs **INF-NGX/R2/TUN/SSL/DISK** + **INF-FIX-01…07**. Docs: `archivo/auditorias-prompts/AUDITORIA_INFRA.md` · MASTER § Infra. Sin cambios de código.
- **2026-08-06:** **Auditoría Prompt 08** — Docker/env: prod compose Nest-only + HC + `unless-stopped`; sin logging rotation (disco Hetzner); JWT example bypassa validador; compose/Dockerfile untracked; sin `.dockerignore`. IDs **DK-COMPOSE/SEC/HC/RST/LOG** + **DK-FIX-01…07**. Docs: `archivo/auditorias-prompts/AUDITORIA_DOCKER_ENV.md` · MASTER § Docker. Sin cambios de código.
- **2026-08-06:** **Auditoría Prompt 07** — BD/Supabase: RLS 73/73 deny-all (sin policies tenant); índices gap caja/movimientos; FK producto→pedido_items NO ACTION (historial seguro); N+1 menú/clone/stock; backups scripts listos, cron VPS+R2 no activos. IDs **BD-RLS/IDX/FK/N1/BKP** + **BD-FIX-01…07**. Docs: `archivo/auditorias-prompts/AUDITORIA_BD_SUPABASE.md` · MASTER § BD. Sin cambios de código.
- **2026-08-06:** **Auditoría Prompt 06** — RBAC: `@Permisos` es OR; mesero cobra y cambia estados vía API (no módulo `/caja`); IDOR crítico cerrar caja por UUID ajeno; `anonimizar` público; `prueba-web` FCM global. IDs **RBAC-GUARD/MESERO/CAJA/TENANT** + **RBAC-FIX-01…07**. Docs: `archivo/auditorias-prompts/AUDITORIA_RBAC.md` · MASTER § RBAC. Sin cambios de código.
- **2026-08-06:** **Auditoría Prompt 05** — Auth/JWT: sin refresh/logout server; TTL 7d; `UsuarioActivoGuard` corta desactivados en el siguiente request; Flutter SharedPreferences (no secure); mid-action → login sin retry; WhatsApp OTP ausente. IDs **AUTH-FLOW/EXP/REV/STORE/OTP** + **AUTH-FIX-01…06**. Docs: `archivo/auditorias-prompts/AUDITORIA_AUTH_JWT.md` · MASTER § Auth. Sin cambios de código.
- **2026-08-05:** **Auditoría Prompt 04** — APIs REST: creates 200 (no 201), conflictos caja/cobro como 400, sin `ParseUUIDPipe`/`forbidNonWhitelisted`, paginación solo pedidos+movimientos inventario (caja/usuarios/catálogo unbounded), idempotencia fuerte en crear pedido + Wompi (débil en cobro/abrir caja), envelope `{exito}` consistente con aplanado de códigos. IDs **API-HTTP/VAL/PAGE/IDEM/FMT** + **API-FIX-01…06**. Docs: `archivo/auditorias-prompts/AUDITORIA_APIS_REST.md` · MASTER § APIs REST. Sin cambios de código.
- **2026-08-05:** **Auditoría Prompt 03** — Flutter estructura: estado (1 Riverpod + setState masivo), god screens (>1k LOC×15), `ref.watch(carrito)` rebuilda menú, leaks TEC inventario + Realtime sin `removeChannel`, `go('/admin/cajero')` rompe back-stack, 0 Dio en widgets (repos embebidos). IDs **FL-STATE/WIDGET/LEAK/NAV/API** + **FL-FIX-01…07**. Docs: `archivo/auditorias-prompts/AUDITORIA_FLUTTER_ESTRUCTURA.md` · MASTER § Flutter. Sin cambios de código.
- **2026-08-05:** **Auditoría Prompt 02** — NestJS estructura: módulos SRP (overlap métricas, god Pedidos/Auth, salud/health duplicado), controllers (almacenamiento SQL, authz en usuarios), DTOs (~19 bodies inline sin class-validator, CotizarDomicilioDto huérfano), catch billing Wompi/renovación silenciosos, ValidationPipe sin `forbidNonWhitelisted`. IDs **BN-MOD/CTRL/DTO/EXC/PIPE** + **BN-FIX-01…06**. Docs: `archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md` · MASTER § Backend NestJS. Sin cambios de código.
- **2026-08-05:** **Auditoría Prompt 01** — deuda estructural documentada: duplicación (stock paralelo, guards, crons DIY, math Flutter), ciclos Nest `pedidos↔domiciliarios` + Flutter admin↔pedidos/menu↔pedidos, violaciones Flutter=UI (carrito/costeo), acoplamiento hub pedidos, escala 50→500 (pool/N+1/rate-limit/crons), inconsistencias nombres. IDs **AQ-DUP/CYCLE/SOLID/COUPLE/SCALE/NAME** + backlog **AQ-FIX-01…07**. Docs: `archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md` · MASTER § Arquitectura/calidad · canvas Cursor. Sin cambios de código.
- **2026-08-05:** **MAPA_FOODY** — inventario vivo: módulos Nest (controllers/services/DTOs), pantallas Flutter por rol, endpoints `/api/v1`, 73 tablas + FKs (001–079), matriz tests (Jest casi vacío vs 58 `verificar-*.ps1`). Índice en `docs/README.md`.
- **2026-08-04:** **Icono app** — fuente `assets/logo_foody.png` (1024², fondo blanco) regenerado en Android/Windows/web PWA; adaptive bg `#FFFFFF`.
- **2026-08-04:** **Escanear mesa = solo cámara** — sin pegar URL/token (el QR de mesa basta); preview a pantalla completa también en web; fallback permiso. Maps JS: `loading=async` en `web/index.html`.
- **2026-08-04:** **Escanear mesa UX** — AppBar surface/ink; hero web; campo densificado; Pegar portapapeles + CTA ink; banner «Ya estás en mesa»; linterna + haptic al detectar. Sin cambios API.
- **2026-08-04:** **Historial cliente en la nube** — migración `079_cliente_auth_uid` (`dispositivos_cliente.auth_uid`, `pedidos.cliente_auth_uid`); `POST /dispositivos/vincular-auth`; `GET /pedidos/mios` acepta Bearer Supabase; crear pedido hereda uid; Flutter Google OAuth cliente (no staff) + banner en Mis pedidos; UX Analítica seguimiento/mis pedidos. `verificar-historial-cliente-auth.ps1` OK.
- **2026-08-04:** **Icono app Foody** — `assets/foody.png` vía `flutter_launcher_icons` en Android (mipmap + adaptive), Windows (`app_icon.ico` 256), web/PWA (`favicon` + Icon-192/512 + manifest Foody). Favicon/apple-touch en `web/index.html`.
- **2026-08-04:** **UX checkout cliente** — AppBar surface/ink + sede; tip datos; tipo/pago chips ink; campos densos; resumen card; CTA «Hacer pedido» ink. Lógica pedido/domicilio/promo intacta.
- **2026-08-04:** **Carrito detalle real** — `detalleIncluye`/`etiquetaTipo` en línea (snapshot al agregar); tap → sheet Incluye/extras/obs/subtotal; swipe elimina; Vaciar con confirm; `eliminarLinea`. Sin API.
- **2026-08-04:** **UX carrito cliente** — AppBar surface/ink; pasos pedido Analítica; cards densas + pill cantidad; CTA ink; tip cantidades. `FoodyPasosPedido` sin naranja/teal.
- **2026-08-04:** **UX menú cliente** — AppBar/chips/cards/CTA ink; tip «Toca +»; entrada staggered; botón + con rebote; snackbar «Ver» carrito; sheet producto/combo + upsell Analítica (precio animado, tip extras). Sin cambios API.
- **2026-08-04:** **UX sucursales cliente** — AppBar surface/ink + «Elegí una sede»; cards densas Analítica (anillo icono, CTA «Ver menú» ink); canvas + pull-to-refresh. Auto-nav sede única intacto.
- **2026-08-04:** **Estados premium** — `promocion_story_viewer`: long-press oculta chrome (barras/header/caption/CTA) + pausa; swipe down cierra (umbral + haptic); tiempo relativo (`created_at` → `2 h`). Sin cambios API.
- **2026-08-04:** **UX home lugares (cliente)** — AppBar surface/ink; estados anillo monocromo; búsqueda + cards sin gradiente naranja+teal; nav inferior ink. API/filtro intactos.
- **2026-08-04:** **UX elegir ciudad** — sin AppBar naranja; header Foody + título denso; tiles con icono/borde Analítica. Preferencia + FCM intactos. `dart analyze` 0 errores.
- **2026-08-04:** **UX splash cliente/equipo** — fondo neutro Analítica (sin gradiente naranja+teal); logo en card; spinner ink; animación suave. Lógica arranque intacta.
- **2026-08-04:** **UX registro repartidor** — card Analítica + espera ink; API intacta.
- **2026-08-04:** **UX Crear restaurante + login repartidor** — mismo shell Analítica que login staff (`AuthFormEstilo`); sin AppBar naranja; CTA ink; OAuth/ciudades/API intactos. `dart analyze` 0 errores.
- **2026-08-04:** **UX login staff** — canvas/gradiente sutil, card densa, marca ink, campos muted, CTA ink, Google outlined, demo en acordeón, links ink. Auth/OAuth/shake intactos. `dart analyze` 0 errores.
- **2026-08-04:** **UX chrome panel** — sidebar oscuro con activo/grupo/favoritos neutros (logo Foody solo en marca); AppBar surface/ink, chip sede outlined, iconos inkMuted, canvas Analítica. Navegación/favoritos intactos. `dart analyze` 0 errores.
- **2026-08-04:** **UX Pedidos (kanban/grid)** — header/KPI Activos+Total; chips canal + tabs estado ink; cards `AnaliticaTokens` con franja urgencia (≥8/≥15); CTA ink (Listo verde); columnas kanban ink. Realtime/filtros/API intactos. `dart analyze` 0 errores.
- **2026-08-04:** **Dashboard gráficos = Analítica** — reutiliza `AnaliticaChartCard` / `AnaliticaCharts` (línea con gradiente+tooltip, donut neutro, barras top). Sin API nueva.
- **2026-08-04:** **Dashboard operativo** — KPIs densos + acordeones por prioridad: Mesas demora (QR≥3 / cocina≥20 / cobro≥10), Domicilios planta tardíos, Stock bajo, Alertas top 8 (crítico→bajo). Gráficos estilo Analítica debajo. Sin API nueva (compone mesas/pedidos/inventario/alertas). `dart analyze` 0 errores.
- **2026-08-04:** **UX Config. cocinas e impresoras** — header + KPIs (sin impresora); dual Cocinas‖Impresoras ≥980; cards con badges/riesgo; menú «Añadir impresora» desde cocina; FoodyDialogo + dispose seguro. API intacta. `dart analyze` 0 errores.
- **2026-08-04:** **KDS Cocina | Listos** — dos pestañas arriba; al marcar Listo el ticket sale de Cocina y pasa a Listos (snackbar + Ver); Listos con «Volver a cocina»; sin mezclar pendientes y terminados. API intacta.
- **2026-08-04:** **UX Cocina en vivo (KDS)** — tickets sin alto fijo (Wrap + altura al contenido); urgencia por franja (10/20 min) + tiempo `1h 20m` (no todo rojo/`99+`); Listo grande + iconos secundarios; «Todo listo (N)» por ticket; barra activos/demorados; diálogo No disp. con dispose seguro. Lógica/Realtime intacta. `dart analyze` 0 errores.
- **2026-08-04:** **UX Gestionar repartidores** — KPIs; reglas≠liquidar/equipo; dual ≥980; CTA header; diálogo dispose seguro.
- **2026-08-04:** **UX Zonas domicilio (de verdad)** — no solo color: escritorio mapa‖lista (≥980); móvil mapa más bajo; leyenda + «Ubicación» sobre el mapa; anillos ordenados cerca→lejos; edición con chips km/precio. API intacta.
- **2026-08-04:** **UI Mis sucursales** — `sucursales_admin_screen`: canvas/tokens Analítica; marca con vista previa tipo app cliente; CTA ink, FoodyDialogo. Lógica marca/crear intacta.
- **2026-08-04:** **UI Mis sucursales** — `sucursales_admin_screen`: canvas/tokens Analítica; marca con vista previa tipo app cliente + tiles Portada/Logo (zoom, estado OK/Pendiente, subir/cambiar); CTA ink, FoodyDialogo. Lógica marca/crear intacta. `dart analyze` 0 errores.
- **2026-08-04:** **UI Horarios** — `horarios_admin_screen`: canvas/tokens Analítica, resumen cliente neutro, cards densas por día, switch ink, FoodyDialogo; edición por clic (lista por hora en punto, sin reloj). Lógica horarios intacta. `dart analyze` 0 errores.
- **2026-08-04:** **UI Usuarios** — `usuarios_admin_screen`: canvas/tokens Analítica, header denso, cards con iniciales + badges rol/cocina, switch ink, vacío/error, FoodyDialogo en crear/editar. Lógica staff intacta. `dart analyze` 0 errores.
- **2026-08-04:** **UI Alertas** — `alertas_admin_screen`: canvas/tokens Analítica, chip/CTA ink (sin naranja), cards densas con badges tipo/nivel (sin slugs crudos), vacío/error guiados, skeleton. Lógica listar/revisar/evaluar/Realtime intacta. `dart analyze` 0 errores.
- **2026-08-04:** **Mesas polish** — tarjetas sin wash de color (barra 3px + punto); KPIs neutros; `FoodyDialogo` (tema ink) en todos los modales de mesa/cuenta/cobro/comensal. Sin cambios API.
- **2026-08-04:** **UI Mesas (piso)** — `mesas_grid_widget` + `mesa_pedidos_sheet`: salón creativo (cards táctiles, CTA, filtros KPI, orden QR→ocupadas, banner semántico); sheet cuenta densificado. Sin cambios API/lógica. `dart analyze` 0 errores.
- **2026-08-04:** **UI Caja** — `caja_admin_screen`: canvas/tokens Analítica, header denso, apertura sin naranja, métricas/movimientos/CxC/acciones laterales, cerrar semántico. Lógica caja intacta. `dart analyze` 0 issues.
- **2026-08-04:** **UI Nuevo pedido** — `pedido_cajero_screen` + `OperacionTipoToggle`: canvas/tokens Analítica, header denso, chips ink, cards neutras, avisos semánticos, carrito + confirmar ink. Lógica POS/caja intacta. `dart analyze` 0 errores.
- **2026-08-04:** **UI Promociones** — `promociones_admin_screen`: canvas/tokens Analítica, header denso, vacío guiado, cards con badges (activa/video/24h/vistas), FAB ink, diálogo alineado. Sin cambios API. `dart analyze` 0 issues.
- **2026-08-04:** **UI Plan y pagos** — `mejorar_plan_screen`: canvas/tokens Analítica, header denso, suscripción con badge semántico, renovar ink, planes 3 columnas ≥980px, historial denso. Lógica Wompi/sync intacta. `dart analyze` 0 errores.
- **2026-08-04:** **UI Facturación** — `facturacion_admin_screen`: canvas/tokens, header denso, tabs, config agrupada (emisor / IVA / resolución), form responsive, lista facturas con badges emitida/borrador/anulada, acciones en ⋮. Sin cambios API. `dart analyze` 0 errores.
- **2026-08-03:** **UI Menú admin** — `menu_admin_screen`: canvas/tokens, búsqueda + chips (sin receta / bajo margen / no disponible), badges de riesgo (receta/cocina/margen), tabs Productos/Toppings/Bebidas/Combos, estados vacíos claros. Sin cambios API. `dart analyze` 0 errores.
- **2026-08-03:** **UI Costos y márgenes** — `costos_margenes_screen` + bloques/receta/incluidos: tokens Analítica, banners sin receta/bajo margen, tabs «Receta / Incluidos», guía de pasos en editor, Guardar primero + agregar secundario, lista densas responsive. Sin cambios API. `dart analyze` costeo: 0 issues.
- **2026-08-03:** **Wompi móvil seguro** — redirect HTTPS `GET /pagos/retorno-app` → `foody://plan` (Android intent + iOS scheme) con fallback web; al aprobar pago Realtime `suscripcion_actualizada`; panel/Mejorar plan refrescan perfil en resume + deep link (sin reiniciar app). `WOMPI_REDIRECT_URL` = bridge API; `WOMPI_EQUIPO_URL` = fallback.
- **2026-08-03:** **UI Insumos** — `inventario_admin_screen` + `stock_visual_widgets` + guía pasos: tokens Analítica, banner/alertas de riesgo (rojo/ámbar/verde), chips/tabs densos, tarjetas responsive (<520 stack), FAB compacto, movimientos/subrecetas/conteo alineados. Sin cambios API/lógica. `dart analyze` archivos tocados: 0 issues.
- **2026-08-03:** **Wompi pago prueba** — sandbox APPROVED activó `nitidoooo` → plan `pro` / `activa` hasta 2026-09-02 (pago `ee6cf4cf…`). UI mostraba Gratis porque `MejorarPlanScreen` usaba `widget.planActual` (sesión). Fix: `_planVista` desde API + `onPlanActualizado` si el plan subió. Webhook puede fallar por firma (`WOMPI_EVENT_KEY` ≠ Eventos del dashboard); sync/poll igualmente aprueba.
- **2026-08-03:** **UI Reportes** — alineado a Analítica (tokens/KPI/surfaces/charts/skeletons); lógica y API intactas. `dart analyze lib/features/reportes` 0 errores.
- **2026-08-03:** **UI Centro de Inteligencia** — rediseño visual completo de Analítica sin tocar repo/API/cálculos: header hero, KPI premium+sparklines, strip insights, skeletons shimmer, charts con tooltips/gradientes, filtros sheet, jerarquía Resumen. `dart analyze lib/features/analitica` 0 errores.
- **2026-08-03:** **Fase 0 VPS (PC+túnel)** — `DB_POOL_MAX=25`; Wompi redirect canónico + `verificar-wompi-tunel.ps1`; UptimeRobot exacto en `MONITOREO_SALUD.md`; backup Windows (`programar-backup-windows.ps1`); `verificar-listo-vps.ps1` OK; `PREPARACION_VPS.md` Fase 0/1; `setup-ubuntu-vps.sh` endurecido. Verificado: `/salud` público, backup 5.8MB, preflight exit 0.
- **2026-08-03:** **Arranque tunel endurecido** — `servir-web-tunel-release.ps1` verifica que **equipo :8080 y cliente :8081** escuchen (falla si no); sin depender de `Get-NetTCPConnection`. `iniciar-foody-subdominios.bat` usa `-SkipBuild` por defecto + chequeo API. Verificado: ambos puertos + URLs públicas 200.
- **2026-08-03:** **Config centralizada** — `config/foody-entorno.env` + `sincronizar-entorno.ps1` + `verificar-entorno.ps1`. CORS canónico (sin acumular puertos basura). Verificado: sync, round-trip puerto, modo local↔túnel, `/salud` local+público, orígenes foodyy/equipo 200.
- **2026-08-03:** **Cloudflare Tunnel** — diagnóstico: dominios/puertos fijos (no rotan); fallos = Flutter `:8080` apagado o `usarTunel=false`. `_escribir-configuracion-tunel` quirúrgico; `sincronizar-ip-movil` ya no borra hosts foodyy; `verificar-tunel-foodyy.ps1` + `iniciar-foody-foodyy-store.bat` + `iniciar-flutter-web-tunel.ps1`; doc `CLOUDFLARE_TUNNEL_FOODY.md`. Verificado: api.foodyy.store `/salud` OK; foodyy.store falla sin Flutter en `:8080`.
- **2026-08-01:** **OPT-04/05** — `cerrados-hoy` e inventario movimientos con `page`/`limit`; kanban e inventario «Cargar más»; auditoría timeline `LIMIT 500`; `PollRealtimeRespaldo` 90s/45s; KDS + domi independiente. `verificar-paginacion-ops.ps1` OK; analyze archivos tocados sin errores.
- **2026-08-01:** **OPS lote 1** — `backup-postgres.sh` + retención en `.ps1`; `docs/BACKUPS_FOODY.md`; migr. `078` FCM `intentos`/`abandonada` (máx 10); limpieza estados expirados (cron 6h + `POST /promociones/admin/limpiar-expiradas` + delete Storage al eliminar); `.env.example` `DB_POOL_MAX`/`FCM_MAX_INTENTOS`. Verificado: `verificar-ops-recomendaciones.ps1` **OK**.
- **2026-08-01:** **Recomendaciones → backlog** — `docs/RECOMENDACIONES_IMPLEMENTACION.md`: auditado lo recomendado (UX suscripción/ciudad/estados, pool, caché, índices ✅; backups auto, VPS, FCM tope, limpieza Storage, Wompi prod ⏳). Specs de implementación + orden. MASTER/README/AUDITORIA enlazados.
- **2026-08-01:** **Estados estilo WhatsApp** — Ciudad: un anillo por restaurante (`listarGruposStoriesCiudad`); al abrir, todos los estados del grupo. Menú sede: un anillo. Video ≤30s (`tipo_media`, migr. `077`, `POST /almacenamiento/video`, `video_player`). Admin: Foto | Video. Smoke: `valledupar` → 1 grupo / 2 promos; `/salud` OK; analyze promociones 0 errores.
- **2026-08-01:** **Toppings extras / bebidas producto** — Admin: diálogo checkboxes «Toppings del plato» (`GET/PUT /productos/:id/toppings`). Sheet: toppings como extras del ítem + bebidas como líneas producto. Migr. `076` elimina productos espejo de toppings. Bebidas siguen espejadas al crear.
- **2026-08-01:** **Extras/bebidas = productos** — Migr. `075` (`topping_origen_id`/`bebida_origen_id`); `CatalogoService` espeja al crear/actualizar; sheet producto/combo y POS cajero agregan líneas de producto (sin `pedido_item_toppings` en ese flujo). Cliente ve categorías Extras/Bebidas + cards al pedir un plato.
- **2026-07-31:** **Upsell menú (opción 1)** — `OpcionUpsellCard` / `SeccionUpsellOpciones` en detalle producto y combo; observaciones debajo; tip admin tab Bebidas; vacío chip Bebidas; migr. `074` relink toppings/bebidas a Rosquete/Papas/Huevo. Sin unificar catálogo extras→pedido.
- **2026-07-31:** **Stories polish + borrar estados** — Fix GoError CTA (`appNavigatorKey`); botón oval transparente + degradado inferior; `BoxFit.contain`; anillo gris visto (`PromocionVistosService`); `DELETE /promociones/:id` + menú Eliminar en admin. `flutter analyze` promociones: 0 issues; API rebuild + `/salud` OK.
- **2026-07-31:** **Cliente premium + estados WhatsApp** — AppBar contraste lugares; cards portada+logo; stories sin overflow + auto-avance/tap; CTA «Ir al producto»/`Ver menú`; nav sede única con `pushReplacement` (sin loop); menú deep-link `producto_id`; chips pastel. Backend: migr. `073` `producto_id` + default 24h; `GET/PATCH /sucursales/marca`; admin estados + marca. Migración aplicada en supabase-db · `nest build` OK.
- **2026-07-31:** **Cliente UX oleada A (CL-01…08)** — sin Acceso staff / AppBar duplicada; Agotado en menú; subtotal carrito con extras; sticky «Ver carrito»; `PedidoEstadoPill` mis-pedidos/seguimiento; stories CTA «Ver menú» + copy sin admin; `FoodyEstadoUi` restaurantes/seguimiento/mesa QR; checkout errores inline. Doc `FRONTEND_AUDITORIA_UX_CLIENTE.md`. `flutter analyze` archivos tocados: 0 errores (1 info previo async context).
- **2026-07-31:** **Auditoría UX cliente (solo doc)** — `docs/frontend/FRONTEND_AUDITORIA_UX_CLIENTE.md`: splash→seguimiento, promos/stories, QR/mesa; gap vs admin (`OperacionUi`, pills, breakpoints); backlog CL-01…23 (P0/P1/P2). Índice README frontend + ROADMAP. Sin tocar código.
- **2026-07-31:** **Pedidos Fase 1 — verify-docs** — confirmado en código: columnas por canal, cards/pills, `pedido_detalle_sheet`, POS domicilio real, `items_resumen`, tab Cerrados hoy; `verificar-pedidos-kanban.ps1` **OK** (activos+detalle+cerrados-hoy+aprobar); `flutter analyze` pedidos/kanban: 0 errores (6 infos `use_build_context_synchronously` previos). Plan Fase 2 (edición ítem) ya entregado aparte.
- **2026-07-31:** **Coherencia BI↔pedidos** — ranking/margen de analítica, reportes, dashboard y costeo usan `SQL_VENTA_LINEA_ITEM` (base + toppings×qty + bebidas), igual que cobro; cuenta mesa `subtotal_linea` alineado; filtros Analítica con `pendiente_aprobacion`/`confirmado`/`rechazado`; KPI activos dashboard +`pagando`/`asignado`. Script `verificar-coherencia-pedidos-analitica.ps1` OK (KPI ventas_netas ≈ reportes financiero).
- **2026-07-31:** **POS coherencia pedidos** — categoría Bebidas con producto vendible (migr. `072` + API); admin combo puede incluir productos+bebidas+toppings; POS abre `DetalleComboSheet` con extras de componentes; combos aceptan toppings/bebidas extra en DTO; **cambiar producto** = agregar primero → quitar viejo (también último ítem); DELETE ítem limpia FKs hijas (fix 500); sticky POS se limpia al volver a Pedidos. `verificar-pos-menu-cambiar.ps1` OK · `verificar-pedido-items.ps1` OK · `nest build` OK · analyze Flutter sin errores (infos previos).
- **2026-07-30:** **Pedidos Fase 2** — `PATCH /pedidos/:id/items/:itemId` (cantidad/toppings/nota, stock/totales, reset cocina + Copia N); `items_resumen` con `producto_id`/`topping_ids`; DELETE reimprime comanda; sheet `editar_pedido_item_sheet` + menú Editar/Cambiar/Quitar en detalle. `verificar-pedido-items.ps1` · `nest build` · analyze OK.
- **2026-07-30:** **Pedidos CTA + mesero + comanda** — `PATCH /pedidos/:id/aprobar` con `mesera_id` (admin obligatorio); `GET /usuarios/meseros-activos`; modal `asignar_mesero_sheet`; labels Confirmar/Listo/A cobrar/En camino; FCM `pedido_asignado_mesero` + `pedido_a_cobrar`; migr. `071` `comanda_copia` + pie ticket `Copia N`. `verificar-pedidos-kanban.ps1` OK · `nest build` OK · analyze Flutter OK.
- **2026-07-30:** **Pedidos UX (recomendado)** — vista default = pestañas de estado + grid responsive (kanban columnas solo toggle ≥720); card: cliente/mesa negrita → hora → `#pedido` secundario; `POST /domiciliarios-planta/reasignar` (pedido `asignado`/`en_camino`) + UI «Cambiar» en detalle; tab Cerrados. `verificar-pedidos-kanban.ps1` OK · `nest build` OK · analyze Flutter OK.
- **2026-07-30:** **UI Pedidos Fase 1** — columnas por canal (`pedido_columnas_por_canal`); cards ricas + pills; `pedido_detalle_sheet`; `GET /pedidos/cerrados-hoy` + `/:id/detalle` + `items_resumen` en listado; POS domicilio nombre/tel/dirección (sin mapa); propina en cobro llevar; `verificar-pedidos-kanban.ps1` OK. `nest build` OK · analyze Flutter OK.
- **2026-07-30:** **UI Analítica premium** — `GET /analitica/pedidos-recientes`; widgets KPI/chart/pill/tabla; Resumen hero; charts en Ventas (`por_categoria`)/Productos/Cocinas/Riesgo/Caja; polish Inventario/Domi/Sedes; `FoodyBreakpoints` grids. `nest build` OK · `verificar-analitica.ps1` OK · `dart analyze lib/features/analitica` sin errores.
- **2026-07-30:** **Cierre parciales MASTER** — POS: propina en para_llevar + diálogo CxC tras pago «Pendiente»; docs: menú/reportes/super/analítica/panel/multi promovidos a ✅; §20 producción actualizado (CI/RLS ya hechos).
- **2026-07-30:** **UX/responsive caja·POS** — `lib/core/layout/foody_breakpoints.dart`; split operación 900→720; sheet cobro mesa densificado (banner 1 línea, split/salio en avanzadas, ChoiceChips diálogo &lt;600); mesas grid 4@720 / 5@1100; doc RS-20 ✅.
- **2026-07-30:** **Analítica Fase 3** — `alertas_abiertas_lista` en resumen; riesgo `cocinas_prep_delta` + `categorias_caida` (con `comparar`); cron `cocina_prep_subida` / `caida_ventas_categoria`; UI Resumen→Riesgo. Sin xlsx nativo ni MV (YAGNI). `verificar-analitica.ps1` ampliado.
- **2026-07-30:** **Analítica Fase 2** — `GET /analitica/export` CSV UTF-8 BOM (Excel); `formato=xlsx` → mismo CSV; `adjuntarComparativaKpis` en ventas/productos/cocinas/inventario/domi/caja/riesgo; Flutter comparar en tabs + banner + rango custom + export CSV; `verificar-analitica.ps1` export+comparativa. `nest build` OK · `dart analyze lib/features/analitica` OK.
- **2026-07-29:** **Analítica Fase 1** — DTO/filtros SQL (`analitica-filtros.util`); UI sheet + charts + PDF (`analitica_filtros_sheet`, `analitica_export_foody`); duración historial; migr. `070`; distancia en asignaciones; alertas producto sin venta / mesero cancelación; script verificar multi-filtro. `dart analyze` OK · `nest build` OK. API viva no disponible en sesión (Supabase containers down; `foody_db` vacío).
- **2026-07-29:** **Plan Analítica/Reportes** — inventario Fase 0 + plan de extensión en `docs/PLAN_COMPLETAR_ANALITICA_REPORTES.md` (decisiones 1A·2A+B+C+D·3C·4C). Índice `docs/README.md` + ficha MASTER §21.
- **2026-07-26:** **NAV-DP** — FCM planta ≠ indep; redirect `/admin/panel`→domiciliario; cobro un sheet; sin mini-mapa; `DraggableScrollableSheet`; split ≥720; AppBar «Mi ruta»; `saldo_por_liquidar` + banner; copiar tel/dir web; snackbar asignación; tabs compactas; login hint. Doc `FRONTEND_AUDITORIA_NAV_DOMICILIARIO.md`. Analyze OK · `nest build` OK.
- **2026-07-26:** **F0 QA** — `verificar-flutter-ui` OK; FlujoApi **12/12**; RolesApi **38/38**; sesión `docs/archivo/qa-sesiones/2026-07-26.md`. UI manual click-through pendiente. Ajuste menor acciones Mesas (sin `SizedBox` fijo con Wrap).
- **2026-07-26:** **NAV-ADM2** — `pedido_id`/`ingrediente_id` en router+panel; alertas→pedido/insumo/costos; kanban lista &lt;720; `ocultarCabecera` operación; dismiss suscripción; KDS/POS/caja atajos; Reportes↔Analítica; CTAs cocinas/domi/promos/sucursales/usuarios; chips filtro estado; búsqueda max 720; banner mesas dismissible. Doc `FRONTEND_AUDITORIA_NAV_ADMIN2.md` (22/24; ADM2-06/24 diferidos). Analyze: solo infos previos.
- **2026-07-26:** **NAV-MS Mesero** — shell: refresh, nav≥720, `ocultarCabecera`; banner QR→Mesas; `onVerMesa`; lista móvil (kanban ≥720); CTA «Listo para cobrar» + cobro avanzado; sin cancelar/salió-sin-pagar; redirect panel→mesero; FCM `/admin/mesero?mesa_id&pedido_id`. Doc `FRONTEND_AUDITORIA_NAV_MESERO.md`.
- **2026-07-26:** **NAV-CK Cocina (KDS)** — Menú/Insumos/Costos N/A (`ver_cocina` solo). Timer `cocina_desde` (MIN ítem); cap 99+; rol cocina filtra estación + redirect `/admin/panel`→`/admin/cocina`; empty/error adaptativos; refresh sin full-spinner; icon CTAs móvil; badge Cobrado; estación en AppBar. Doc `FRONTEND_AUDITORIA_NAV_COCINA.md`.
- **2026-07-26:** **NAV-CJ Cajero** — headers únicos; sync caja→POS; auto tab Caja si bloqueado; filtro Por cobrar; sin QR/transfer/arqueo ciego; nav superior ≥720. Doc `FRONTEND_AUDITORIA_NAV_CAJERO.md`.
- **2026-07-26:** **Rol Cocina** — migr. `069_usuarios_cocina_id.sql` (`usuarios.cocina_id`); crear/editar staff con rol `cocina` + estación; JWT/`perfil` con `cocina_id`; KDS `/cocina/cocinas` filtra a su estación; tickets/ítems ajenos → 403. UI Usuarios: «Cocina (KDS)» + selector. Demo `cocina@foody.demo` → `cocina` + principal. Script `verificar-rol-cocina.ps1` OK.
- **2026-07-26:** **NAV-MG ✅** — nombre sede en sidebar (`ver_dashboard` → `mi-restaurante`); empty Menú sin copiar HQ; Costos→Insumos; CTA hermanas; copy Traslados; hermanas→Traslados; GuiaPasos Menú/Costos; docs `gerente` vs `gerente_cadena`. MG-08 YAGNI.
- **2026-07-26:** **NAV-MC Baja ✅ / ciclo cerrado** — `_barraCrear` tonal en toppings/bebidas/combos; Movimientos tap → Mercado+editar; Recalcular icono/label alineado; `inventario`→`insumos`. Doc auditoría 28/28.
- **2026-07-26:** **NAV-MC Alta+Media** — `_irCostosConProducto` + `?producto_id`; Costos sin auto-abrir primer plato; selector sede móvil; diálogo precios con costo/margen; Insumos→Costos (CTA + SnackBar); fade TabBars; empty/error Menú; badges extras; alerta→filtro bajo_stock. Doc `FRONTEND_AUDITORIA_NAV_MENU_COSTEO.md`. Analyze OK.
- **2026-07-26:** **Overflow móvil (~360–390px)** — trailing densos → precio en subtitle + Switch/⋮ (menú cliente/admin, promo, caja fiados, cocinas, usuarios, mesa sheet); grids POS/mesas 2 cols &lt;400px; FAB padding promo/sucursales/seguimiento; TabBar `isScrollable` costeo/popularidad/facturación/domi; `FoodyScrollHorizontalFade` en chips; KDS badges en `Wrap`. `flutter analyze` archivos tocados: solo infos previos.
- **2026-07-23:** **Recetas bebidas/toppings** — migr. `068_receta_bebidas_toppings.sql`; `configurarReceta`/`resumen`/`recalcular` con `tipo_entidad`; pedidos expanden extras al validar/descontar stock; Costos lista platos+bebidas+toppings; Menú atajo «Ver costos» en extras; `scripts/verificar-receta-extras.ps1` **8/8 OK**.
- **2026-07-22:** **Costos scroll único** — detalle plato = un `ListView` (sin Flexible+Expanded TabBarView → adiós bloque blanco); cabecera compacta/colapsable; stock e incluidos colapsables; paneles receta/incluidos con `scrollExterno`. Insumos: subtítulo más corto.
- **2026-07-22:** **Formularios Foody** — shell `lib/core/tema/foody_formulario.dart` (cards, métricas, campos adaptativos). Rediseño responsive: subreceta (fix overflow), insumo, compra/ajuste/producción/conteo, menú (producto/precios/combo/extras/categoría). Colores Foody, no tema externo.
- **2026-07-22:** **NAV-MC Alta 04–07** ✅ — crear insumo/empaque desde Costos; guía Orden recomendado colapsable; Subrecetas ⋮; badge Menú→Costos. Archivos: `receta_producto_panel`, `dialogo_insumo_form`, `costeo_ui_bloques`, `inventario_admin_screen`, `menu_admin_screen`.
- **2026-07-22:** **NAV-MC-01…03** ✅ — Costos móvil: editor receta `ListView` único (adiós overflow 96 px); back único contextual + breadcrumb solo PC (sin link duplicado); acciones header en ⋮ móvil + título `maxLines:1`. Archivos: `receta_producto_panel.dart`, `costos_margenes_screen.dart`. Nueva auditoría vivo `FRONTEND_AUDITORIA_NAV_MENU_COSTEO.md` (cadena insumos→subrecetas→menú, 19 ítems NAV-MC).
- **2026-07-22:** **NAV-ADM Baja** ✅ — breadcrumb/volver Costos↔Menú; empty+CTA zonas/sucursales; preview horarios; dialogs maxWidth 560; Mejorar plan solo banner (+ módulo bloqueado).
- **2026-07-22:** **NAV-ADM Media** ✅ (salvo 14/24) — AppBar móvil ⋮; búsqueda→pedido; KPIs mesas/reportes/pedidos; kanban default+ancho flex+Nuevo; caja movimiento→pedido; copy sidebar; factura Ver pedido+preview; alertas SnackBar+Wrap. Archivos: `panel_restaurante_screen`, `pedidos_kanban_widget`, `caja_admin_screen`, `facturacion_admin_screen`, `alertas_admin_screen`, dashboards, `menu_admin_item`.
- **2026-07-22:** **NAV-ADM Alta 01–06** ✅ — favoritos ★, sheet pedidos atajos, ⋮ mesas, banner QR Revisar, menú overflow móvil, Modo caja + Cobrar todo con monto.
- **2026-07-22:** **NAV-ADM-03** ✅ — ⋮ opciones mesa en grid admin (`mesas_grid_widget`).
- **2026-07-22:** **NAV-ADM-02** ✅ — atajos sheet Pedidos (cobrar mesa, caja, factura+emitir, KDS).
- **2026-07-22:** **NAV-ADM-01** ✅ — favoritos sidebar: ★ en tiles, bloque en rail tablet, ★ en popup grupos (`panel_sidebar_nav.dart`); AR-29 ✅.
- **2026-07-22:** **Nav admin (diagnóstico)** — Documento vivo `FRONTEND_AUDITORIA_NAV_ADMIN.md` con 24 ítems NAV-ADM-01…24.
- **2026-07-02:** DOM-UI — dashboard independiente inDriver (`MapaFoody`, `TarjetaOfertaInDriver`, `PanelEntregaActiva`, countdown 60s, múltiples ofertas, desconectar turno); planta activos mapa + chip GPS; `GET /domiciliarios/sesion/estado`; `scripts/verificar-ofertas-independiente.ps1` E2E OK.
- **2026-07-02:** AR-28 búsqueda admin (pedido #, mesa, módulo); navegación alertas mesa/caja; menú AppBar blanco; ciudades sin slug; `FoodyAsyncBody`; `verificar-foody-loc.ps1`; QA roles API 37/37.
- **2026-07-02:** Sprint 1 frontend — FF-01…06, `FoodyFormato`/`FoodyEstadoUi`/`mensajeErrorCliente`, splash Foody, carrito +/−; `verificar-flutter-ui.ps1` OK.
- **2026-07-02:** Arquitectura Flutter — `FRONTEND_FLUTTER_ARCHITECTURE.md` (6 god files &gt;1000 LOC, 1 provider Riverpod, estrategia FL-10…63, Fase 9).
- **2026-07-02:** UI/QA — cancelar pedido ≤2min (`created_at` API + seguimiento); banner cuenta unificada mesa QR + `total_pendiente_mesa`; scope mesa sin mis-pedidos/salir; cajero bloqueo tabs; mesero banner QR en tab Pedidos; repartidor chip GPS; `verificar-flutter-ui.ps1`; `docs/FACTURACION_ELECTRONICA_PAUSADA.md`; checklist actualizado.
- **2026-07-02:** Auditoría UI — `AbrirAppCliente` (flavor equipo → URL cliente); delete cocina/impresora; recalcular subreceta + historial producciones; doc `docs/archivo/auditorias-prompts/AUDITORIA_PANTALLAS_BOTONES.md`.
- **2026-07-02:** `verificar-qa-roles-api.ps1` (37 pasos API por rol); `Ensure-HorariosDemoAbiertos` + `Ensure-AsignacionDomiPlanta` en qa-helpers.
- **2026-07-01:** RT-QA UI — `scripts/verificar-realtime-qa-manual.ps1` (guia 2 pestanas + modo `-Asistido`); integrado en `verificar-qa-manual.ps1 -Realtime`.
- **2026-07-01:** RT-8b — dedup `event_id` en Flutter (`evento_dedup.dart`); `catalogo_disponibilidad` para toppings/bebidas; `scripts/verificar-realtime-api.ps1` (caja retiro, topping, desasign domi); QA detectó migración `055` faltante en BD local.
- **2026-07-01:** CAJ-021b — **fix doble resta al cancelar** (`revertirVentasPedido` borraba la venta **y** agregaba devolución, dejando la caja en −monto): ahora conserva la venta y registra una única devolución por el neto cobrado (`netoCobradoPedidoEnCaja`), así cancelar un para-llevar prepagado regresa la caja al saldo original. Fix SQL cierre caja: `pedidos.updated_at` → `created_at` (la columna no existe). Script cubre escenario para-llevar prepagado.
- **2026-07-01:** CAJ-021c — **ventas netas** (indicador «Ventas» ya no infla con pedidos cancelados): `total_ventas` de caja, `ventas_caja`/`por_metodo` en reportes y analítica ahora restan devoluciones (`SUM(venta) − SUM(devolucion)`), conservando ambos movimientos para auditoría. Chequeo de coherencia usa neto (`venta − devolucion ≤ total`). Meseras «Salió sin pagar» (`POST /mesas/:id/salio-sin-pagar` → CxC por saldo impago, pedido `pagado` solo por lo abonado, alerta `salio_sin_pagar`, libera mesa; sin venta en caja) verificado coherente.
- **2026-07-01:** QA manual — `verificar-flujo-cruzado-api.ps1` + `verificar-qa-manual.ps1 -FlujoApi` (12/12 checklist §4); sesion `docs/archivo/qa-sesiones/2026-07-01.md`; usuarios demo cajero/mesero documentados.
- **2026-07-01:** CAJ-020 — E2E `verificar-todos-e2e.ps1` **9/9 OK**; split ítem COALESCE; limpieza demo ampliada; reconciliar-cuadre-demo; fiado `-CicloCompleto`.
- **2026-07-01:** QA suite ampliada — inventario-menu, CxC, self-service, operación mesas, transferencia, multi-sucursal, receta-empaque, producción-lote OK; `verificar-carga-qr.ps1` reparado (ASCII, mesa demo, Start-Job); cuadre caja con diferencia histórica esperada (pedidos totales vs movimientos).
- **2026-07-01:** CAJ-019 — fixes auditoría pedidos/caja: `dto.pagos` respeta `debeRegistrarVentaAlCrear`; cancelar revierte ventas caja; descuento ajusta `monto_pagado` + devolución exceso; split ítem incluye toppings/bebidas y cap post-abono; tope idempotente `SUM(ventas)≤total`; API `mesera_nombre`/`monto_pagado`; abonos con `responsable_nombre`; filtro `mesera_id` en listado; Flutter: nota cocina, bloqueo sin caja, atribución mesa/kanban/KDS, cobrar para-llevar.
- **2026-07-01:** CAJ-018 — coherencia caja/pedidos: `debeRegistrarVentaAlCrear` excluye domicilio (caja solo al cobrar/entregar); para-llevar con método marca `monto_pagado=total`; domicilio→entregado vía Kanban registra saldo idempotente; `usuarioId` en todos los `registrarVentaEnCaja`; movimientos y fiados devuelven `responsable`; cobro mesa atribuye `pedido_id` correcto; UI caja muestra responsable+método; `scripts/reconciliar-caja-domicilios.ps1` + `scripts/verificar-caja-coherencia.ps1` (descuento OK con `factura_id`).
- **2026-07-01:** DOM-017 — contabilidad del domicilio: por defecto la caja registra **solo el producto** (`total − costo_domicilio`) y el domicilio queda fuera de caja, rastreado por domiciliario (`GET /domiciliarios-planta/domicilios/:sucursal_id`). Toggle `domicilio_ingresa_a_caja` por sucursal (`PATCH .../config-domicilio-caja/:sucursal_id`) para restaurantes que sí lo cobran. **Pago mixto** en la entrega (`metodo_pago_domicilio`: producto por transferencia, domicilio en efectivo). Desglose producto/domicilio en dashboard domiciliario. Aplica a planta e independiente y al fiado (el domi solo debe el producto). Migración `066`, util `repartirCobroDomicilio` + `scripts/verificar-cobro-domicilio.ps1`.
- **2026-07-01:** DOM-016 — fiado/liquidación de domiciliario de planta: método `pendiente_liquidacion` en entrega crea CxC ligada a `domiciliario_planta_id` (no toca caja); admin liquida a caja (efectivo) al recibir el dinero; toggle `permite_fiado_domiciliario` por sucursal. Migración `065`, `scripts/verificar-fiado-domiciliario.ps1`.
- **2026-07-01:** FCM producción dispatch — push planta al auto-asignar, staff si sin repartidor, independientes en oferta (`dispatch.service`, `pedidos-estado.service`).
- **2026-07-01:** PED-005 merma al cancelar pedido listo/en cocina (`pedidoRequiereMermaAlCancelar`, alerta `merma_cancelacion_pedido`).
- **2026-07-01:** PED-020 encargo — `fecha_entrega_deseada` DTO + date picker checkout (mín. 2 días) + validación `es_encargo`.
- **2026-07-01:** QR-012 — `qr_pendientes_count` en `mesas.service` + badge grid admin.
- **2026-07-01:** DOM-009 `GET /domiciliarios-planta/comisiones-independientes/:sucursal_id` + tarjeta payout admin.
- **2026-07-01:** DOM-002 RT — `domiciliarios_admin_screen` + `FoodyRealtime.suscribirSucursal`.
- **2026-07-01:** X-005 `scripts/verificar-carga-qr.ps1` (20 POST paralelos). X-001 cron suscripciones verificado ✅.
- **2026-07-01:** Escenarios negocio — 122 ✅ · 8 🟡 · 1 ❌ (restantes: DIAN PED-011/012, QR-011, FAC-003; impresión COC-008, X-009).
- **2026-07-01:** UX escenarios — timer QR grid (MES-012), tracking mapa domicilio RT (DOM-007), preview borrador FAC-001.
- **2026-07-01:** **F-17** — split bill: `ITEMS_EXCEDEN_SALDO`, FIFO abono, `verificar-pagos-mesa.ps1`; UX sheet mesa + banner QR MES-018.
- **2026-07-01:** P3-09 — auditoría docs: MASTER, MODULOS, AVANCE resumen, README, ROADMAP; tablas sprint históricas = referencia.
- **2026-07-01:** P3-06 parcial — `Dockerfile` bookworm-slim + `verificar-docker-prod.ps1` (build OK).
- **2026-07-01:** `docs/ESTRATEGIA_BACKEND_PRIMERO.md` — frontend pausado; prioridad API/BD/infra.
- **2026-07-01:** P3-04 — eliminados `pedido_service.dart`, `menu_catalog_service.dart`, `lib/providers/` (11 archivos), utils reserva legacy.
- **2026-07-01:** Fix `verificar-multi-sucursal.ps1` (em-dash rompía PowerShell en Windows).
- **2026-07-01:** Verificado `verificar-ci.ps1` 3/3 OK tras limpieza; `flutter analyze` sin errores en features/core.
- **2026-07-01:** P3-01 — `verificar-ci.ps1`, GitHub Actions, `docs/CI_E2E.md`. Verificado: `verificar-ci.ps1` 3/3 OK.
- **2026-07-01:** P2-19 `POST /inventario/traslados/:id/cancelar` + UI cancelar/recibir + `usuario_nombre` en listado.
- **2026-07-01:** P2-20 snackbar éxito en `_VistaConfig` panel super-admin.
- **2026-07-01:** P2-21/22 `ESCENARIOS_NEGOCIO_FOODY.md` — 82 ✅ · 47 🟡 · 1 ❌ (COC-015).
- **2026-07-01:** `scripts/iniciar-backend-wsl.bat` deja de arrancar NestJS en WSL (crash silencioso de `sharp` con `node_modules` de Windows). Ahora compila y ejecuta con Node en Windows; comprueba Docker y si la API ya responde.
- **2026-06-28:** P2-17 editar rol/permisos staff UI.

> **Checklist maestro para terminar el software:** **`docs/ROADMAP_TERMINAR_FOODY.md`** (P0→P3, 52 ítems accionables).

> **Registro irregularidades (checklist vivo):** `docs/REGISTRO_IRREGULARIDADES_FLUJOS.md` — **32/33 resueltos** (solo **R5** impresión física pendiente).
> **Auditoría E2E (histórico + trazado):** `docs/archivo/auditorias-prompts/AUDITORIA_FLUJOS_E2E.md` — estado vivo en REGISTRO + `MASTER_STATUS.md`.
> **Antigravity (archivado 2026-06-24):** `docs/archivo/*-antigravity.md` — fixes ya en código.
> **Auditoría arquitectura:** `docs/archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md` (Prompt 01, AQ-\*) · histórica jun-12: `docs/archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md` · analista jun-04: `docs/archivo/ANALISIS_SISTEMA.md`.
> **Flujos por rol (HTML):** `INFRAESTRUCTURA/foody_flujo_completo_pantallas.html` · mapa código `docs/MAPA_FLUJOS_PANTALLAS.md`.
> **Planes comerciales (básico/pro/enterprise):** 🟡 módulos + **límites numéricos** (sucursales/usuarios) — ver `docs/PLANES_SUSCRIPCION.md`.

---

## Resumen de 1 minuto (léelo primero)

> **Frontend en pausa.** Estado vivo: **`MASTER_STATUS.md`**. Prioridad: **`ESTRATEGIA_BACKEND_PRIMERO.md`**.

| Qué | Estado |
|-----|--------|
| **Backend NestJS** | ✅ 27 módulos · ~221 endpoints · guards + multi-sucursal |
| **PostgreSQL** | ✅ Migr. **001–064** · RLS exhaustivo (073 tablas) |
| **CI / QA API** | ✅ `verificar-ci.ps1` **5/5** (paso0 + rls + salud + P2 + multi-sucursal) |
| **Realtime broadcast** | ✅ Health `/health/realtime` · poll respaldo en cliente |
| **Impresión cocina** | 🟡 Cola + agente · modo archivo OK · falta hardware (P0-01) |
| **Wompi / suscripciones** | 🟡 Código F1–F7 + recurrente · falta webhook HTTPS prod |
| **Docker prod** | 🟡 `verificar-docker-prod.ps1` build OK · deploy VPS pendiente |
| **Legacy Flutter** | ✅ `lib/screens/` eliminado · paquete `reserva_canchas` sin renombrar |
| **Cliente / admin UI** | ✅ En código · **no se toca** hasta retomar frontend |

**Verificación rápida:** `.\scripts\verificar-ci.ps1`

> Detalle técnico (env, endpoints, changelog): secciones **Referencias persistentes** y **Últimos cambios** abajo.

### Pospuesto por acuerdo (no implementar salvo petición explícita del usuario)

| Tema | Sprint spec | Notas |
|------|-------------|--------|
| **FCM** / push notifications | 7 | ✅ Avanzado — cola + cron + eventos pedido/domi; requiere `FIREBASE_SERVICE_ACCOUNT_PATH` en backend |
| **DIAN** / factura electrónica real | 9–11 | Proveedor FE; hoy HTML borrador basta |
| **Servidor Python** impresión | 10 | WebSocket + tickets cocina — **gateway NestJS** ✅; falta escpos físico |
| **Import Excel KYG** | — | `TABLA DE COSTEOS KYG.xlsx` solo referencia de fórmulas; datos se cargan manual en admin |

---

## Leyenda de estados

| Símbolo | Significado |
|---------|-------------|
| ✅ Avanzado | Usable en dev; cubre el flujo principal del sprint |
| 🟡 Parcial | Funciona pero falta spec completa, UX legacy o post-commit |
| ⏳ Pendiente | No iniciado en código Foody |
| 🚫 Bloqueado | Depende de otro módulo/infra |
| 📅 Planificado | Previsto en sprint N; no tocar antes sin acuerdo |

---

## Resumen por sprint (guía oficial)

| Sprint | Tema | Estado global | Notas |
|--------|------|---------------|-------|
| 1 | Fundación (Docker, BD, Auth, Flutter core) | ✅ Avanzado | Ver detalle abajo |
| 2 | Cliente: ciudades, restaurantes, menú | ✅ Avanzado | Combos en menú cliente; toppings modal |
| 3 | Pedidos y seguimiento | 🟡 Parcial | POST transacción ampliada; sin FCM/post-commit impresión |
| 4 | Panel admin básico | ✅ Avanzado | Kanban+reloj+acciones; mesas QR; dashboard; falta solo módulos sidebar 5+ |
| 5 | Caja y productos CRUD | ✅ Avanzado | Combos incluidos |
| 7 | Domiciliarios (sin FCM aún) | 🟡 Parcial | Planta + dispatch independientes; falta FCM push realtime |
| 8 | Super Admin completo | 🟡 Avanzado | Foody Control UI + usuarios + metadata planes; falta **PlanFeaturesGuard**, vencimiento auto, guard tenant | 8 |
| 9 | Reportes y facturación | 🟡 Parcial | Reportes MVP; facturación borrador+emisión; falta PDF DIAN |
| 10 | Python impresión | ⏳ Pendiente | |
| 11 | Producción y pulido | ⏳ Pendiente | |

---

## Sprint 1 — Fundación

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| Estructura repo in-place | ✅ | `lib/main.dart`, `foody_backend/`, `foody_supabase/`, `lib/features/` | — | — | — |
| Migraciones SQL | ✅ | `001`–`016` + seeds demo | RLS exhaustivo en prod | Sprint 11 | 11 |
| NestJS core + respuesta API | ✅ | `DatabaseModule`, interceptores, filtros | — | — | — |
| Auth JWT + guards | ✅ | Jwt, Rol, SuperAdmin, Suscripción, Usuario activo | Aplicar SuscripcionActiva en todos los módulos | Revisión sprint 8 | 8 |
| Flutter: tema, Dio, go_router | ✅ | `TemaFoody`, `ClienteDio`, `AppRouter` | Renombrar paquete `reserva_canchas` | Refactor no bloqueante | 11 |
| Login staff | ✅ | `StaffLoginScreen`, `AuthRepository` | — | — | — |

---

## Sprint 2 — App cliente (catálogo)

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| API ciudades/restaurantes/menú | ✅ | Módulos NestJS + repos Flutter | — | — | — |
| device_id + dispositivos | ✅ | `DispositivoService`, `POST /dispositivos/registrar` | FCM token en cliente | Sprint 7 | 7 |
| Splash + preferencia ciudad | ✅ | `FoodySplashScreen`, `CiudadPreferenceService` | Deep link universal FCM | Sprint 7 | 7 |
| Flujo ciudades → sucursales | ✅ | Pantallas `*_foody.dart` + rutas | Animaciones legacy completas | Opcional | 11 |
| Menú con categorías y búsqueda | ✅ | `MenuScreenFoody` (chips, cards, Foody colors) | Tabs sticky idénticos a `menu_sede_screen` | Prioridad baja | 11 |
| Modal toppings/bebidas | ✅ | `DetalleProductoSheet` + API toppings/bebidas | — | — | — |
| Combos en menú cliente | ✅ | Sección Combos en `MenuScreenFoody` | Modal detalle combo | Prioridad baja | 11 |
| Carrito Riverpod | ✅ | `carrito_provider`, líneas con clave única | — | — | — |
| Legacy `menu_sede_screen` | ✅ | Eliminado P3-03 | — | — | — |
| Pedido mesa QR cliente | ✅ | `/mesa/:qrToken`, `GET /menu/mesa/:qr_token` | PDF QR impresión | Sprint 5 mesas admin | 5 |

**Archivos clave:** `lib/features/menu/`, `lib/features/ciudades/`, `lib/features/restaurantes/`, `lib/core/dispositivo/`.

---

## Sprint 3 — Pedidos y seguimiento

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| POST /pedidos transacción | 🟡 | Validación precios, horario, ítems, historial, **domicilio por zona**, inventario, caja, auditoría, **IVA en pedido**, borrador factura | Combos en INSERT; integración DIAN; 18 pasos MEMORIA al 100% | Spec ERP completa | 5–9 |
| Estados iniciales | ✅ | Mesa → `pendiente_aprobacion`; resto → `pendiente` | — | — | — |
| GET /pedidos/:id/estado | ✅ | Historial público | — | — | — |
| Checkout cliente | ✅ | Tipos para llevar/domicilio/**encargo**, dirección, **geo lat/lng + mapa**, cotización zona | — | — | — |
| Seguimiento cliente | 🟡 | Timeline + broadcast; **mis pedidos** por device_id | Push al cambiar estado | FCM sprint 7 | 7 |
| Promociones / historias | 🟡 | Admin publicar URL imagen; cliente stories en menú | Subir foto Storage | Bloque 5.6 | 5 |
| Realtime broadcast backend | ✅ | `RealtimeBroadcastService` + hooks pedidos/mesas; Flutter `FoodyRealtime` | Revisar en prod con RLS aplicado | Tras migración 028 | 4 |

**Archivos clave:** `foody_backend/src/modulos/pedidos/`, `lib/features/pedidos/`.

**Inventario en pedido:** valida al crear; **descuenta al confirmar/aprobar** (`stock_descontado`); restaura en cancel/rechazo. Solo productos con receta/incluidos/combos expanden ingredientes.

---

## Sprint 4 — Panel admin básico

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| GET/PATCH pedidos admin | ✅ | Lista con `estado_desde`, cambiar estado, aprobar/rechazar | — | — | — |
| Login → panel por rol | ✅ | Redirección dashboard en splash/login | App cocina separada | Un `main.dart` | 7 |
| Dashboard resumen | ✅ | Tarjetas + badge QR + tap → pedidos/mesas | Gráficos avanzados | Sprint 9 | 9 |
| Kanban pedidos | ✅ | Reloj 15 min rojo, acciones rápidas, broadcast Realtime, timer 30s | Asignar domiciliario en “listo” | Sprint 7 | 7 |
| Mesas | 🟡 | Grid, CRUD, QR, transferir; `mesera_asignada_id` en API; panel mesero tap libre → `PedidoCajeroScreen` | UI admin asignar mesas por turno; liberar mesa en todos los cierres | S4+ | Post-S1 |
| Panel mesero | 🟡 | `/admin/mesero`: mesas + kanban **5 columnas** (Por confirmar → Pagando) | Banner contador QR; S6 ciudad auto en QR | S5–S6 | 4 |
| Menú dinámico permisos | ✅ | `MenuAdminDinamico` por permisos JWT | Pantallas caja/menú CRUD/inventario | Sprint 5–6 | 5–6 |
| Cliente QR → pedido mesa | ✅ | `/mesa/:qrToken`, checkout `tipo=mesa` | Escaneo cámara nativo | Mejora UX | 11 |
| Módulos sidebar (caja, menú CRUD…) | ✅ | `CajaAdminScreen` (fiados), `MenuAdminScreen` | Panel cajero mesa selector | Mejora | 5 |

**Archivos clave:** `lib/features/admin/`, `lib/features/mesa/`, `foody_backend` pedidos/dashboard/mesas/menu.

---

## Sprint 5 — Caja y productos CRUD

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| NestJS módulo caja | ✅ | abrir, cerrar, movimientos, gastos, fiados crear/cobrar | — | — | — |
| NestJS catálogo admin | ✅ | categorías, productos, toppings, bebidas, combos | — | — | — |
| Flutter menú admin | ✅ | tabs Productos/Toppings/Bebidas/Combos | imágenes | 11 |
| Panel cajero constructor pedido | ✅ | `PedidoCajeroScreen` + sidebar «Nuevo pedido» | Mesa con selector QR | Mejora | 5 |

**Archivos:** `foody_backend/src/modulos/caja/`, `catalogo/`, `lib/features/caja/`, `lib/features/catalogo/`.

---

## Sprint 6 — Inventario

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| Descuento stock en pedido | ✅ | `validarStock` al crear con **`detalles`**; `descontarStock` al confirmar; diálogo Flutter `mostrarDialogoStockSiAplica` en checkout/cajero | — | — | — |
| NestJS inventario | ✅ | ingredientes, compras, movimientos, costos, receta, conteo cerrar | — | — | — |
| Flutter inventario admin | ✅ | tabs + compra/ajuste/receta/conteo (stock teórico en diálogo, `mensajeErrorHttp`) | — | — | — |
| Recalcular costo_calculado | 🟡 | `CosteoService` merma/subrecetas/combos + cascada compra/ajuste | UI subrecetas/empaques en configurar receta | Fase 1 restante | Fase 1 |

**Archivos:** `foody_backend/src/modulos/inventario/`, `lib/features/inventario/`.

---

## Módulo costeo industrial (Fase 1 — en curso)

> Spec completa: **`docs/MODULO_COSTEO.md`** · Excel referencia: `INFRAESTRUCTURA/TABLA DE COSTEOS KYG.xlsx`

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| Spec + decisiones producto | ✅ | `docs/MODULO_COSTEO.md` (fórmulas, fases, casos borde) | — | — | — |
| Motor `CosteoService` | ✅ | Merma, subrecetas recursivas, margen_error, cascada, empaques domicilio | — | — | — |
| Costo domicilio (empaques) | ✅ | `tipo_item=empaque`; descuento solo en pedido domicilio | — | — | — |
| Costeo combos (ganancia) | ✅ | `recalcularCombo`, alerta margen, tab Costos | — | — | — |
| Subrecetas KYG (Fase B) | ✅ | `POST/PATCH /costeo/subrecetas`, detalle, recalcular; `dialogo_subreceta_form.dart`; cascada a platos que usan la subreceta | Producción en lote (`usa_produccion_lote`) | Fase 2 | Fase 2 |
| Alertas margen / precio sugerido | ✅ | `precio_sugerido`, alertas, tab Costos con umbral | — | — | — |
| UI editor receta producto | ✅ | Ingrediente / subreceta / empaque en `InventarioAdminScreen` | — | — | — |
| Demo BD subreceta+empaque | ✅ | Migración `033` (carne preparada, caja/bolsa en hamburguesa) | — | — | — |
| API costeo | ✅ | `GET /costeo/resumen`, `GET /costeo/productos/:id/impacto-stock`, subrecetas CRUD+detalle+recalcular, `POST /costeo/recalcular`, combos | — | — | — |
| Migración BD | ✅ | `032_costeo_industrial.sql` | — | — | — |
| Productos con ítems de menú incluidos | ✅ Avanzado | Tabla `034_producto_items_incluidos.sql`; `GET/PUT /productos/:id/items-incluidos`; costeo + stock expandido; tab Incluye; KDS | Demo carne/hígado +2 rosquetes (seed opcional) | Sprint costeo |
| Precio local vs para llevar | ✅ Avanzado | Migración `035_precio_para_llevar.sql`; `precioVentaProducto()` en pedidos; admin `actualizarPreciosCanal`; menú/checkout/cajero usan canal | Precio sugerido llevar en Costos | S2 |
| Import Excel KYG | 🚫 No aplica | — | — | Solo referencia fórmulas | Acuerdo 2026-06-08 |
| Simulador popularidad | ⏳ | — | Hojas Excel Popularidad Mesa/Domicilio | Opcional | Fase 3 |

**Spec admin (menú, costos, incluidos):** `docs/ADMIN_MENU_COSTEO.md` — prioridad sobre UI legacy en Inventario.

**Archivos:** `foody_backend/src/modulos/costeo/`, `lib/features/catalogo/`, `lib/features/inventario/` (migrar UI a spec admin).

---

## Multi-sucursal (Alitas House Norte / Sur)

> **Spec:** `docs/MULTI_SUCURSAL.md` · Reglas: `INFRAESTRUCTURA/reglas_negocio_foody.md` § Multi-sucursal · Cursor: `.cursor/rules/foody-multi-sucursal.mdc`

| Ítem | Estado | Hecho | Falta | Por qué / cuándo |
|------|--------|-------|-------|------------------|
| Modelo documentado (aislamiento por sede) | ✅ Avanzado | `docs/MULTI_SUCURSAL.md`, `MEMORIA.md` roles, reglas negocio ampliadas | — | Acuerdo producto 2026-06-09 |
| Excepción inventario hermano (solo lectura) | ✅ Avanzado | Permiso `ver_inventario_otras_sucursales` (migr. `043`); `GET /inventario/hermanas/resumen`; `InventarioHermanasPanel` | — | Fase 1 |
| Guard API escritura = `sucursal_id` JWT | ✅ Avanzado | `SucursalScopeService` en inventario, pedidos, caja, dashboard, catálogo, facturación, mesas, **zonas**, **alertas** | — | Fase 2 |
| Selector sucursal en panel admin | ✅ Avanzado | Solo `gestionar_sucursales`; chip sede fija para admin de sucursal | — | Fase 1 |
| Traslados stock entre sedes | ✅ Avanzado | Backend traslados + `POST .../cancelar` + scope; UI cancelar/recibir + `usuario_nombre` | — | Fase 2 |
| Dashboard consolidado cadena | ⏳ Pendiente | — | Rol `gerente_cadena` + KPIs multi-sede | Fase 3 |

---

## Sprints 7–11 (pendientes)

| Sprint | Estado | Dependencias | Cuándo abordar |
|--------|--------|--------------|----------------|
| Multi-sucursal Fase 2 | ✅ Avanzado | Scope zonas/alertas/traslados; script `verificar-multi-sucursal.ps1` | Dashboard cadena | Fase 3 |
| 5 restante | 🟡 | Caja/catálogo base | cuentas-por-cobrar, panel cajero |
| 6 restante | ✅ | Inventario + UX stock/conteo | — | — |
| 7 Domiciliarios + FCM | ✅ Avanzado | Planta + dispatch + push ofertas + deep links |
| 8 Super Admin | 🟡 Avanzado | Cron vencimiento + **`LIMITES_POR_PLAN`** (sucursales/usuarios staff) | cobro recurrente | 8 |
| 9 Reportes/facturación | 🟡 | Reportes + borrador/emitir/anular + scope sucursal | PDF DIAN proveedor FE | 9–11 |
| 10 Impresión Python | 🟡 | Python WS MVP + **`ImpresionService`** NestJS (cola `impresion_cocina_jobs`) | python-escpos real | 10 |
| 11 Producción | ⏳ | Todo anterior | — |

---

## Deuda legacy (no duplicar)

| Qué | Estado | Acción cuando |
|-----|--------|----------------|
| `lib/screens/`, Provider, Firebase pedidos | ✅ Eliminado P3-03/04 | Ver `lib/legacy/README.md` |
| ~~`pedido_service.dart`~~ | ✅ Eliminado | Usar `PedidosClienteRepository` |
| Paquete `reserva_canchas` | 🟡 | Renombrar en P3-05 |
| ~~`menu_sede_screen.dart`~~ | ✅ Eliminado | `MenuScreenFoody` |

---

## Backend — módulos existentes

| Módulo | Estado |
|--------|--------|
| auth, salud, ciudades, restaurantes, menu, dispositivos | ✅ |
| pedidos (público + staff), dashboard, mesas, menu/mesa QR | ✅ |
| super-admin | ✅ |
| caja, catalogo | 🟡 |
| inventario | 🟡 |
| costeo | ✅ |
| domiciliarios (planta + independientes) | 🟡 |
| reportes | 🟡 |
| facturación | 🟡 |
| impresión | 🟡 |

---

## Flutter — features existentes

| Feature | Rutas / notas | Estado |
|---------|---------------|--------|
| splash | `/splash` | ✅ |
| ciudades / restaurantes / sucursales | `/cliente`, `/ciudades/...` | ✅ |
| menu + carrito + checkout + seguimiento | `/menu/...`, `/carrito/...`, `/checkout/...`, `/pedidos/.../seguimiento` | ✅ |
| mesa QR | `/mesa/:qrToken` | ✅ |
| auth staff | `/admin/login` | ✅ |
| panel restaurante / foody control | `/admin/panel`, `/admin/foody-control` | ✅ / 🟡 Avanzado |
| caja / catálogo / inventario admin | panel sidebar `caja`, `menu`, `inventario` | 🟡 |
| domiciliario app | `/admin/domiciliario` planta · `/domiciliario/independiente` | 🟡 |
| facturación admin | panel sidebar `facturacion` | 🟡 |

---

## Auditoría Antigravity (2026-06-24)

Sesión externa de QA/arquitectura. Documentos fuente (conservar como referencia):

| Documento | Contenido |
|-----------|-----------|
| `docs/archivo/auditoria_flujos_foody-antigravity.md` | 9 flujos E2E, matriz R1–R13 (archivado) |
| `docs/archivo/implementation_plan-antigravity.md` | Plan freemium + tickets (archivado) |
| `docs/archivo/walkthrough-antigravity.md` | Resumen sesión Antigravity (archivado) |
| `docs/archivo/inventario_sistema_foody-antigravity.md` | Snapshot código jun-24 (archivado) |

### Implementado en código (post-Antigravity)

| Ítem | Archivos | Estado |
|------|----------|--------|
| **Plan gratis freemium** — inventario, costeo, cocina, domi, reportes desde `gratis` (solo facturación = enterprise) | `plan-features.config.ts`, `plan_modulos.dart` | ✅ |
| **Límites numéricos plan gratis** — 1 sucursal, **2 staff**, **2 mesas**, **5 productos**, **5 ingredientes** | `plan-features.config.ts`, `PlanFeaturesService.assertLimite*` | ✅ |
| Validación al crear mesa / producto / ingrediente → `403 PLAN_LIMITE_EXCEDIDO` | `mesas.service.ts`, `catalogo.service.ts`, `inventario.service.ts` | ✅ |
| **R1** — No `entregado` en mesa con saldo pendiente | `pedidos-estado.service.ts` (`PAGO_REQUERIDO_PARA_LIBERAR_MESA`) | ✅ |
| **R4** — Ajuste manual stock→0 propaga `productos.disponible` (CTE recursivo subrecetas) | `catalogo-disponibilidad.service.ts` | ✅ |
| **R10** — `FOR UPDATE` stock/mesa en creación QR | `pedidos-crear.service.ts`, `pedidos-inventario.service.ts` | ✅ |
| **R3** — Domicilio: `entregado` solo desde `en_camino` | `pedido-estados.ts` (`transicionEstadoPermitida`) | ✅ Antigravity |
| **R6** — Transferencia mesa con `auditoria_logs` | `mesas.service.ts` | ✅ Antigravity |
| **R7** — `FOR UPDATE` mesas origen+destino en transferir | `mesas.service.ts` | ✅ Antigravity + liberar origen |
| **R8** — Auto-asignar planta libre al pasar a `listo` | `dispatch.service.ts` | ✅ 2026-06-24 |
| **R11** — KDS desmarca ítem → pedido `en_cocina` (no `confirmado`) | `cocinas.service.ts` | ✅ Antigravity |
| **R13** — Hard stop cierre caja con pedidos/mesas activas | `caja.service.ts` (`CAJA_CIERRE_OPERACION_ABIERTA`) | ✅ 2026-06-24 |
| Fix JWT plan obsoleto tras upgrade Wompi | `plan-features.guard.ts`, `auth.service.perfil` + token | ✅ |

### Riesgos detectados — aún pendientes

| ID | Riesgo | Prioridad | Cuándo |
|----|--------|-----------|--------|
| R2 | `estado_operativo` mesa puede desincronizarse en casos borde | P1 | Sprint mesas |
| R10 (parcial) | QR simultáneo en mesas distintas: stock valida al aprobar, no al crear `pendiente_aprobacion` | P2 | Sprint pedidos |

---

## Últimos cambios (changelog)

- **2026-11-24:** **UI-USR-DEACTIVATE-01** — desactivar acceso ahora requiere confirmación contextual; cancelar no escribe, activar sigue directo. Usuarios widget 6/6, analyzer limpio y Equipo Release publicado/verificado por hash a través del Tunnel.
- **2026-11-24:** **CAT-AVAILABILITY-UX-01** — disponibilidad Producto ahora comunica progreso y errores, permite reintentar; Menú widget 13/13, analyzer limpio y Equipo Release validado por SHA-256 público.
- **2026-11-24:** **PED-WAITER-PAYMENT-01** — modo mesero envía pago pendiente; POS 18/18 + analyzer limpio. Cliente/Equipo Release activados sin ejecutar sincronización de entorno: hashes públicos de `main.dart.js` coinciden con builds, seis destinos local/Tunnel HTTP 200, `.env` hash sin cambios y `cloudflared` activo.
- **2026-06-28:** **P2-17** — Staff: `GET /usuarios/catalogo-roles`, `PATCH /usuarios/:id` (nombre, rol, sucursal; sync `domiciliarios_planta`); diálogo **Editar** en `UsuariosAdminScreen` con chips de permisos read-only por rol; `verificar-usuarios-editar.ps1` OK.
- **2026-06-28:** **P2-16** — Reportes admin: export PDF (informe completo) y CSV/Excel vía `ReporteExportFoody` + menú descarga en `ReportesAdminScreen`; `verificar-reportes-export.ps1` OK.
- **2026-06-28:** **P2-15** — Dashboard admin: gráficos ventas 7d, mix canal hoy y top productos; `GET /dashboard/graficos`; `DashboardGraficosWidget`; `verificar-dashboard-graficos.ps1` OK.
- **2026-06-28:** **P2-14** — Editor receta: grupo empaques domicilio, desglose mesa vs llevar, botones rápidos por tipo, margen error % al guardar, badge empaque; `GET producto-ingredientes` incluye `costo_domicilio`; seed 033 con categoría empaque; `verificar-receta-empaque.ps1` OK.
- **2026-06-28:** **P2-13** — Simulador popularidad: ventas por canal mesa vs domicilio/llevar, clasificación ABC y matriz menú; `GET /costeo/popularidad/:sucursal_id`; icono insights en Costos; `verificar-popularidad.ps1` OK.
- **2026-06-28:** **P2-12** — Producción en lote: migr. `063_producciones_lote`, `POST/GET /costeo/producciones`, ingrediente preparado (`es_subreceta`), descuento insumos + stock lote, costo real; toggle en diálogo subreceta + botón registrar; `verificar-produccion-lote.ps1` OK.
- **2026-06-28:** **P2-10/11** — CxC: resumen API, alertas +7d, historial, cobro con método de pago; UI caja admin; `verificar-cxc.ps1`. Costos: precio sugerido canal llevar en `resumenSucursal` + panel detalle Flutter.
- **2026-06-28:** **P2-04** — Banner cuenta unificada vs tickets en `MesaPedidosSheet`; API `cuenta` en pedidos mesa; «Cobrar este ticket» + ayuda.
- **2026-06-28:** **P2-06/07/09** — `POST /pedidos/:id/llamar-mesera` + FCM; propina opcional checkout; cobro parcial mesa/caja → estado `pagando` + realtime. Backend reiniciado y `verificar-analitica.ps1` OK.
- **2026-06-24:** **P2 pulido** — PDF/compartir QR mesa; banner QR mesero; `POST /pedidos/:id/cancelar` + UI seguimiento cliente.
- **2026-06-24:** **P1-08 analítica QA** — `GET /analitica/comparativa-sedes`; tab «Sedes» corporativo; migr. `062`; `verificar-analitica.ps1`.
- **2026-06-24:** **P1-07 analítica tier Pro** — `ModuloPlan.analitica` en `plan-features.config.ts`; `@RequiereModulo('analitica')`; candado sidebar Flutter (`plan_modulos.dart`).
- **2026-06-24:** **P1-06 Flutter analítica** — `AnaliticaScreen` (8 tabs, presets, fl_chart); menú «Centro de Análisis» en panel Finanzas.
- **2026-06-24:** **P1-05 analítica F3** — `/inventario`, `/domiciliarios`, `/caja`, `/riesgo` (consumo, ranking domi, cuadre, alertas y umbrales).
- **2026-06-24:** **P1-04 analítica F2** — `GET /analitica/ventas`, `/productos`, `/cocinas` (series, rankings, cocinas con margen y tiempo prep).
- **2026-06-24:** **P1-03 analítica F1** — `AnaliticaModule` + `GET /analitica/resumen` (KPIs, presets, comparativa Δ%); migr. `061` `ver_analitica`; scope sucursal corporativo.
- **2026-06-24:** **P1-02 rol `gerente_cadena`** — Migración `060` (permisos = admin); `roles-food.ts` + `esCorporativo()`; checkout/renovar y avisos suscripción; crear usuario solo corporativo; `roles_foody.dart` en panel/usuarios/inventario.
- **2026-06-24:** **P1-01 dashboard consolidado** — `GET /dashboard/consolidado` (corporativo); KPIs cadena + desglose por sucursal; `DashboardConsolidadoWidget`.
- **2026-06-24:** **P1-15 FCM alertas riesgo** — Push nivel alto/crítico a admin/gerente; `TransactionHooksService` post-commit; deep link `/admin/panel?seccion=alertas`.
- **2026-06-24:** **P1-14 SuscripcionActivaGuard** — Auditoría controllers; `notificaciones` con guard; decorador `@OmitirSuscripcionActiva` en pagos/auth (checkout con plan vencido); código error `RESTAURANTE_BLOQUEADO`.
- **2026-06-24:** **P1-13 guard tenant `/super/*`** — `SuperAdminGuard` consulta BD: solo `super_admin` sin `restaurante_id` ni `sucursal_id`; errores `SUPER_ADMIN_REQUERIDO` / `SUPER_ADMIN_SIN_TENANT`.
- **2026-06-24:** **P1-12 documentos domiciliario** — `POST/GET /domiciliarios/documentos` (cedula frente/reverso, vehículo); registro devuelve JWT; `DomiciliarioDocumentosScreen`; Foody Control repartidores con preview y activación; FCM `domiciliario_cuenta_activa` / `domiciliario_documento_rechazado`.
- **2026-06-24:** **P1-10 cobro recurrente Wompi** — Tabla `fuentes_pago`; guarda `payment_source_id` tras pago; `POST /pagos/renovar` (cobro con fuente o checkout); cron renovación automática; UI renovación en `MejorarPlanScreen`.
- **2026-06-24:** **P1-09 paywall plan** — Interceptor `ClienteDio` (403 `PLAN_LIMITE_EXCEDIDO` / `PLAN_NO_INCLUYE_MODULO`); `PaywallLimitePlanDialog` → `/admin/mejorar-plan`; API expone `limite`/`actual` en filtro HTTP.
- **2026-06-24:** **P1-11 historial suscripción** — `GET /pagos/estado` devuelve `historial` (15 pagos); tarjeta estado + lista en `MejorarPlanScreen`.
- **2026-06-24:** **Impresión cocina sin hardware** — Modo `archivo`, reintentos cola, migr. `058`, `GET /health/impresion`, `GET /impresion/jobs`, ticket enriquecido, `docs/IMPRESION_RESTAURANTE.md`, `scripts/iniciar-impresora.ps1` + `verificar-impresion.ps1` (OK).
- **2026-06-24:** **`docs/ROADMAP_TERMINAR_FOODY.md`** — checklist maestro P0–P3 (52 ítems) para terminar el software punto por punto.
- **2026-06-24:** **QR cámara + FCM web deep link** — `EscanearQrMesaScreen` (`mobile_scanner` + entrada manual); ruta `/cliente/escanear-qr`; `RutaMesaUtil.tokenDesdeTextoQr`; `notificationclick` en `firebase-messaging-sw.js` + `fcm_click_web.dart`; retry navegación en `NavegadorFcmFoody`.
- **2026-06-24:** **Wompi prod-ready + F7 métricas** — Poll auto-activación plan tras pago; `sincronizar` sin TX si webhook aprobó; `metricasSelfService` en `GET /super/estadisticas`; KPIs en Foody Control; guía `docs/WOMPI_PRODUCCION.md`.
- **2026-06-24:** **GPS domiciliarios + seguimiento cliente** — `POST /domiciliario/ubicacion`; historial + Realtime; mapa cliente con repartidor; modal combo con imagen.
- **2026-06-24:** **Storage combos/categorías + R5 impresión** — endpoints imagen combo/categoría; admin menú gestión fotos; `foody_python_printer` con `python-escpos` (red :9100) + fallback archivo; jobs envían `impresora.ip_local`.
- **2026-06-24:** **Producto — brechas menú/promos/inventario** — Compra y cierre de conteo propagan disponibilidad al menú (`inventario.service.ts` + `CatalogoDisponibilidadService`); admin promos con `image_picker` → Storage (`POST /almacenamiento/promociones/:id/imagen`); `cached_network_image` en `menu_screen_foody.dart`; script `scripts/aplicar-migracion-supabase.ps1` (057 bucket).
- **2026-06-24:** **Optimización escalabilidad fase 1** — `056_indices_rendimiento.sql`; caché menú 5 min (`MenuCacheService` + invalidación catálogo); paginación opcional `GET /pedidos?page&limit`; `/salud` con `timestamp`; logs 500 en `HttpExceptionFilter`; `docker-compose.prod.yml` + `foody_backend/Dockerfile`; `DB_POOL_MAX`. Ver `docs/OPTIMIZACION_ESCALABILIDAD_FOODY.md`.
- **2026-06-24:** **OAuth Google web ✅** — `LaunchMode.platformDefault` (PKCE misma pestaña); mensajes `AuthException` legibles; limpia `?code=` tras retorno; backend `login-google` 401 con mensaje real. — `logout()` cierra JWT + Supabase + marcador OAuth; `cerrarSesionStaff` en todos los paneles (sin `/splash`); OAuth solo si hay marcador `foody_oauth_destino_staff` + `?code=` (evita re-login tras cerrar sesión); login no re-procesa sesión Supabase vieja; registro no re-ejecuta `loginGoogle` con token precargado; menú admin muestra error si falta `sucursalId` o falla crear categoría/producto.
- **2026-06-24:** **A-01…A-04 ✅ deuda transversal** — `PedidosInventarioService` vía DI; `CajaMovimientosService` única vía caja; `AuditoriaService.registrarEnTransaccion`; helpers `pedidoTerminalOperativo` + SQL fragmentos en `pedido-estados.ts`.
- **2026-06-24:** **R9 ✅ Realtime híbrido** — `PollRealtimeRespaldo` (30/60 s) en Kanban, mesas, sheet mesa, caja, alertas y seguimiento cliente; banner con reverificación; health check al arranque del backend.
- **2026-06-24:** **F-07 ✅ stock QR** — Reserva virtual de ingredientes en pedidos `pendiente_aprobacion`; re-validación al aprobar.
- **2026-06-24:** **F-11 ✅ estados centralizados** — `PedidosEstadoCommandService` único escritor con guards por origen.
- **2026-06-24:** **F-13 ✅ legacy confirmado** — Eliminada rama muerta en `pedidos-crear.service.ts`.
- **2026-06-24:** **F-09 ✅ QR expirado** — Al cerrar caja, pedidos `pendiente_aprobacion` >30 min → `rechazado` + alerta.
- **2026-06-24:** **F-15 ✅ mesa reservada** — Cliente QR no puede pedir en mesa `reservada` (`MESA_RESERVADA`).
- **2026-06-24:** **F-16 ✅ cancelar domi** — Asignación pasa a `cancelado` (migración `055`).
- **2026-06-24:** **F-08 ✅ factura borrador** — Sincroniza subtotal/IVA/total al agregar/eliminar ítems, descuento y antes de emitir.
- **2026-06-24:** **F-14 ✅ emitir factura** — Solo si pedido `pagado` o domicilio `entregado` sin saldo (`PEDIDO_NO_FACTURABLE`).
- **2026-06-24:** **F-10 ✅ cierre caja domi** — Bloqueo si hay `entregado` con saldo pendiente (`caja.service.ts`).
- **2026-06-24:** **F-04 ✅ para llevar sin cobro** — `entregado` bloqueado salvo domicilio en ruta; cierre = `POST .../cobrar` → `pagado`.
- **2026-06-24:** **F-05/F-06 ✅ cocina ↔ caja** — KDS muestra pedidos cobrados con ítems pendientes; cocina no regresa `pagando`/`pagado`.
- **2026-06-24:** **F-03 ✅ cobro domi independiente** — `confirmarEntrega` con `pagos_pedido` + caja; picker método pago en app independiente.
- **2026-06-24:** **F-02 ✅ dispatch KDS→domi** — `CocinasService.intentarDispatchDomicilioSiListo` + `DomiciliariosModule` en `CocinasModule`.
- **2026-06-24:** **F-01 ✅ salió sin pagar** — `MesasService.registrarSalidaSinPagar`: cierra pedidos activos (`pagado` + historial CxC), libera mesa(s) del grupo, broadcast Realtime; export `PedidosCuentaMesaService`.
- **2026-06-24:** **`docs/REGISTRO_IRREGULARIDADES_FLUJOS.md`** — checklist de 33 irregularidades (R1–R13 + F-01…F-16 + A-01…A-04) con simulación, archivos, corrección propuesta y orden P0; 11 ya resueltos en código.
- **2026-06-24:** **Cierre riesgos Antigravity** — R8 auto-asignación planta (`dispatch.service.ts`); R13 bloqueo cierre caja (`CAJA_CIERRE_OPERACION_ABIERTA`); transferir mesa libera origen + lock ambas mesas; alerta domi solo si no hubo asignación; Flutter `ManejoErrorPlan` + snack «Ver planes» al crear mesa.
- **2026-06-24:** **Antigravity integrado** — docs `*-antigravity.md`; plan freemium + límites gratis **2 mesas / 5 productos / 5 insumos / 2 staff**; bugs R1/R3/R4/R6/R7/R10/R11 en backend.
- **2026-06-24:** **OAuth Google staff móvil** — `GoogleOAuthStaffService` (redirect web `/admin/registro` vs `foody://login`); detección sesión en registro; chip «Cuenta Google conectada»; diálogo correo duplicado; `AndroidManifest` + `Info.plist` + script Supabase `foody://login`.
- **2026-06-24:** **Self-service F6 UI** — `MejorarPlanScreen` + `PagosRepository`; candados en sidebar (módulos Pro/Enterprise visibles con lock); `ModuloBloqueadoPlaceholder`; banner gratis/vencimiento con CTA; ruta `/admin/mejorar-plan`; ítem «Mejorar plan» en menú admin.
- **2026-06-24:** **Self-service F1–F3** — Migración `052_self_service_planes.sql` (plan `gratis`, OAuth en `usuarios`, `origen` en `restaurantes`); `OnboardingRestauranteService` compartido (super-admin + auth); `POST /auth/registro-restaurante` (rate limit 5/min) crea rest+sucursal+admin plan gratis; `POST /auth/login-google` (Supabase token→JWT); `plan-features.config.ts` tier `gratis` (3 staff, 1 sucursal); cron excluye plan gratis; Flutter `/admin/registro` + botón Google en login.
- **2026-06-24:** **Costeo UI fixes** — editor receta usa costo del backend (merma/rendimiento) coherente con margen/precio sugerido; diálogo margen muestra fórmula en vivo `costo÷(1−m%)`; `TabController` estable (pestaña «Qué va incluido» ya no expulsa); recarga silenciosa sin resetear pestañas; pestaña receta = solo receta (no suma incluidos).
- **2026-06-20:** **Spec módulo Analítica/BI** — `docs/MODULO_ANALITICA_BI.md` (Centro de Análisis: cocinas, inventario, domi, caja, riesgo, comparativas mes/rango; scope dueño vs admin; fórmulas; fases F1–F7). Solo documentación; extiende módulo `reportes`.
- **2026-06-19:** **QA E2E 4/4** — `scripts/verificar-todos-e2e.ps1` + `limpiar-demo-qa.ps1` (`Restaurar-InventarioDemo`); fixes: domiciliario ocupado ignora pedidos cancelados (`domiciliarios.service.ts`), libera asignación al cancelar pedido, scripts usan `pedido_id` en mesas y menú staff para disponibilidad.
- **2026-06-19:** **P4.2 + P5** — `GET /health/realtime`, banner admin Realtime, scripts `verificar-flujo-domicilio.ps1`, `verificar-inventario-menu.ps1`, `verificar-transferencia-mesa.ps1`, extensión `verificar-pagos-mesa.ps1`.
- **2026-06-19:** **P0–P3 auditoría E2E** — ver `docs/archivo/auditorias-prompts/AUDITORIA_FLUJOS_E2E.md` + `REGISTRO_IRREGULARIDADES_FLUJOS.md`.
- **2026-06-19:** **`docs/MODULOS_ESTADO.md`** — mapa vivo de 20 módulos (hecho/falta/prioridad/backlog); enlace desde resumen de `AVANCE_PROYECTO.md`.
- **2026-06-19:** **Multi-sucursal UI** — selector sede admin recarga mesas/pedidos/KDS (`KeyedSubtree`, `didUpdateWidget`).
- **2026-06-12:** **Módulo 2 FCM ✅** — Cola reintenta si Admin no listo; `NotificacionesCronService`; `GET /notificaciones/diagnostico`, `POST /prueba`; push pendiente/confirmado/cancelado + rutas deep link; tap notificación local; `POST /auth/desactivar-fcm`; `verificar-fcm.ps1`.
- **2026-06-19:** **Sprint 5 P0 pagos** — `POST /pedidos/:id/cobrar` (CAJ-005); `pagos[]` al crear staff para llevar; `pedido_id` en `pagos_pedido`; comensal `PATCH .../comensal`; UI mesa (saldo, abonos, etiqueta comensal); cajero pago mixto.
- **2026-06-19:** **Sprint 7 FCM** — `NavegadorFcmFoody` deep links al abrir notificación.
- **2026-06-19:** **Sprint 8** — `SuscripcionesCronService` marca `vencida` cada hora.
- **2026-06-19:** **Sprint 10 MVP** — `foody_python_printer/main.py` WebSocket simulado.
- **2026-06-19:** Script `verificar-pagos-mesa.ps1`; fix `sincronizar-ip-movil.ps1` encoding UTF8.
- **2026-06-12:** **Firebase dual-flavor** — `flutterfire configure` cliente+equipo; `google-services.json` en `src/cliente/` y `src/equipo/`; `firebase_options_*.dart`; `FirebaseInicializador`; APK release compilados OK.
- **2026-06-12:** **Dos apps (cliente + equipo)** — `equipo` = dueño + domiciliario + staff en un solo APK (`app.foody.equipo`); `cliente` separado; guards en `app_router`; doc `INFRAESTRUCTURA/foody_multi_app_flavors.md`.
- **2026-06-12:** **RT-5 debounce + backlog §10** — `FoodyRealtime`: coalesce 300 ms por sucursal (`sucursal_actualizada`); `docs/ESTRATEGIA_REALTIME_FOODY.md` actualizado (RT-1…RT-5 ✅, §10 pendiente global: FCM/DIAN/impresión, QA, promos Storage, resync escenarios).
- **2026-06-12:** **UI brechas escenarios** — Mesas (unir/reservar/salió sin pagar/cobro mixto), KDS `no_disponible`, caja devolución/arqueo ciego, traslados inventario, timeline auditoría, anular factura; migración `047` aplicada.
- **2026-06-17:** **Cuadre demo + I4** — `046_caja_cuadre_demo_cleanup.sql` (limpia ventas canceladas, backfill); reportes usan `COALESCE(p.created_at, m.created_at)` en cuadre; QA `verificar-cuadre-caja.ps1` → diferencia 0; `endpoints_api_foody.md` sincronizado (~170 rutas).
- **2026-06-12:** **Escenarios negocio sincronizados** — `docs/ESCENARIOS_NEGOCIO_FOODY.md`: 65→**73** ✅ tras auditoría (cobro mesa/caja, DELETE ítem, cuadre, promos código, PlanFeatures); matriz P0 actualizada; día «Sabor Urbano» corregido; roadmap §L.
- **2026-06-12:** **I1 refactor PedidosService (cierre)** — `PedidosItemsService` (`agregarItems`, `eliminarItemPedido`), `PedidosDescuentoService` (`aplicarDescuento`); `pedidos.service.ts` ~224 LOC fachada (listar, delegación); `npm run build` OK. Ver `docs/archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md` I1 ✅.
- **2026-06-12:** **Auditoría fases C–E** — Fase C: UI eliminar ítem en `MesaPedidosSheet`, Realtime sheet mesa, máquina estados `pagando`→`pagado` (`pedido-estados.ts`), admin **Turno mesas** (`POST /mesas/asignar-turno`). Fase D: `PlanFeaturesGuard` + `@RequiereModulo`, `plan`/`modulos` en login/perfil/JWT, sidebar filtra por plan; Realtime `caja_movimiento` + `alerta_nueva`. Fase E: `endpoints_api_foody.md`, `ANALISIS_SISTEMA.md` histórico, migración `045_demo_plan_pro.sql`. Ver `docs/archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md`.
- **2026-06-12:** **Auditoría RT-2 + C5 + I3** — Realtime: `pedido_asignado` (planta), `oferta_nueva` (independiente); Flutter dashboards suscritos + poll 60s. Promociones: migración `044` (`codigo`, `descuento_*`, `pedidos.promocion_id`); `GET /promociones/validar-codigo`; checkout con código. Mesas: `SucursalScopeService` en controller.
- **2026-06-12:** **Fix auditoría arquitectónica (Fase A + C4 + RT-1)** — C1: `cobrarCuentaMesa` → `movimientos_caja` + auditoría + exige caja abierta; C2: no venta caja en `pendiente_aprobacion` / mesa diferida + reversa al rechazar; M5: selector método pago en `MesaPedidosSheet`; C4: `DELETE /pedidos/:id/items/:itemId` + alerta `item_eliminado_post_cocina`; RT-1: `cocina_actualizada` + KDS suscrito (poll 60s backup). Ver `docs/archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md`.
- **2026-06-12:** **Firebase / identificador app** — `applicationId` y bundle iOS/macOS → `app.foody.cliente` (reemplaza `com.tucanchafacil.app` / `com.example.app`). Eliminado `google-services.json` legacy; `lib/firebase_options.dart` listo para `flutterfire configure` (proyecto `foody-pin2`).
- **2026-06-12:** **RT-7 Realtime** — Backend: `qr_aprobacion_urgente` al crear pedido QR; `catalogo_disponibilidad` al agotar/reactivar producto (venta, cancelación, admin). Flutter: listeners en `FoodyRealtime`, SnackBar/banner QR en mesas, refresh menú cliente y POS cajero.
- **2026-06-12:** **QA operación mesas API** — `scripts/verificar-operacion-mesas.ps1` (cajero sin turno + mesero con turno). Migración `042` `crear_pedido` para mesero aplicada en BD demo.
- **2026-06-12:** **Cajero sin turno de mesas** — Solo `mesero` asigna `mesera_asignada_id` al crear pedido mesa (`pedidos-crear.service.ts` + `rol` en JWT). Flutter: `MesasGridWidget.modoCajero` en panel cajero (pedir/cobrar sin bloqueo de mesera); mesero sigue con `modoMesero` + turno. Migración `049` limpia asignaciones erróneas al cajero.
- **2026-06-12:** **Estrategia Realtime distribuido** — `docs/ESTRATEGIA_REALTIME_FOODY.md`: inventario actual (3 eventos broadcast); RT obligatorio/recomendado/opcional por mesas/pedidos/cocina/QR/domi/caja/inventario; 10 riesgos concurrencia + 7 duplicación; canales objetivo; fases RT-1…RT-6; hueco crítico: `CocinasService` no emite RT.
- **2026-06-12:** **130 escenarios negocio restaurante** — `docs/ESCENARIOS_NEGOCIO_FOODY.md`: mesas/pedidos/cocina/caja/QR/domi/inventario; por escenario: debería/módulos/validaciones/errores/controles faltantes; 65✅ 39🟡 26❌; día simulado «Sabor Urbano».
- **2026-06-12:** **Auditoría mesas/pedidos/caja/roles** — `docs/FLUJO_MESAS_PEDIDOS_CAJA.md`: flujo spec vs código, 10 simulaciones reales, matriz conexiones (stock/costeo/caja), Realtime obligatorio (KDS/domiciliario faltan), checklist QA y roadmap brechas (caja cobro mesa, DELETE ítem, RT cocina).
- **2026-06-12:** **Cuenta acumulada por mesa** — Backend: `POST /pedidos/:id/items` (sumar ítems/combos a pedido abierto, recalcula total + stock); `POST /pedidos/mesa/:mesaId/cobrar` (todos los pedidos activos → `pagado`, libera mesa). Flutter: `MesaPedidosSheet` botones Agregar/Cobrar cuenta; mesero agrega consumo al pedido mesa o crea pedido llevar/domi vinculado a la misma mesa; `total_acumulado` en detalle mesa.
- **2026-06-11:** **Mapas OpenStreetMap (sin costo Google)** — Flutter: `lib/core/mapas/` (`MapaFoody`, `GeografiaRepository`, navegación Waze/Maps). Reemplazo Google en checkout, seguimiento, `MapaSeleccionUbicacion`. Backend: módulo `geografia` (`GET /geografia/buscar` → Photon + caché); zonas: `GET /zonas/sucursal/:id/configuracion-mapa`, `PATCH .../ubicacion`; pedidos domiciliario incluyen `lat`/`lng`. Admin `ZonasAdminScreen`: mapa con anillos de radio (km) y precio por zona.
- **2026-06-09:** **Rediseño UI operación** — `operacion_ui.dart` (tokens compartidos). **Pedidos:** vista grid por defecto + stats + búsqueda/filtros + toggle columnas. **Nuevo pedido:** layout POS menú+carrito, categorías, qty inline, tipo/mesa/pago sin diálogo. **Mesas:** tarjetas blancas + resumen libres/ocupadas/QR. **Caja:** métricas + movimientos + panel lateral gasto/cierre.
- **2026-06-09:** **Usuarios por sucursal (dueño corporativo)** — `UsuariosAdminScreen`: dropdown «Ver usuarios de la sede» + campo **Sucursal** en «Nuevo usuario»; aviso si solo hay una sede. Backend `usuarios.controller`: `SucursalScopeService` en listar/crear/cambiar estado (corporativo puede asignar otra sede del mismo restaurante).
- **2026-06-09:** **Multi-sucursal Fase 1 (código)** — `SucursalScopeService`; permiso `ver_inventario_otras_sucursales` (migr. `043`); scope en inventario/pedidos/caja/dashboard; `GET /inventario/hermanas/resumen`; Flutter `InventarioHermanasPanel` + selector sucursal solo corporativo (`gestionar_sucursales`).
- **2026-06-09:** **Multi-sucursal — spec y reglas** — `docs/MULTI_SUCURSAL.md` (modelo Alitas House: cada sede aislada; inventario cruzado solo lectura). Actualizado `reglas_negocio_foody.md`, `MEMORIA.md` (roles), `.cursor/rules/foody-multi-sucursal.mdc`, `foody-backend.mdc`, `AGENTS.md`. Brechas: dropdown sucursal sin restricción, API sin `SucursalScopeGuard`.
- **2026-06-09:** **Alerta `intento_pedido_sin_stock`** — Al fallar `validarStockDisponible` se inserta alerta (transacción aparte) con mensaje contextual: producto pedido, insumo faltante, ítems incluidos (ej. queso en 2× Rosquete del hígado). UI `AlertasAdminScreen` resalta tarjeta roja.
- **2026-06-09:** **UX stock admin + errores detallados** — Backend: `STOCK_INSUFICIENTE` con `detalles[]`; `GET /costeo/productos/:id/impacto-stock`; `PedidosInventarioService.detectarFaltasStock`. Flutter: `stock_visual_widgets.dart` (badges, barras, banner, tarjeta impacto); `InventarioAdminScreen` alertas visuales; `CostosMargenesScreen` tarjeta «puede vender / faltas»; `RecetaProductoPanel` «Venta descuenta X»; `ProductoItemsIncluidosPanel` aviso incluidos descuentan stock; checkout muestra insumo faltante (ej. queso en hígado→rosquetes).
- **2026-06-09:** **S6 QR ciudad/sucursal automática** — `GET /menu/mesa/:qr` devuelve `ciudad` + `restaurante` en `sucursal`; Flutter `MesaSesionService` guarda contexto, splash redirige al menú, `GoRouter` bloquea cambio de ciudad/sucursal; banner mesa con «Salir».
- **2026-06-09:** **Operación mesero S1+S3+S4+S5 (parcial)** — Backend: `PedidosInventarioService` valida al crear, descuenta al confirmar/aprobar, restaura stock cancel/rechazo; `aprobarMesa` asigna mesera y bloquea conflicto (`MESA_ASIGNADA_OTRA_MESERA`); migración `041`. Flutter: `PanelMeseroScreen` con `modoMesero` en grid (tap mesa libre → pedido staff) y kanban 5 columnas; `PedidoCajeroScreen.modoMesero`. Pendiente: aplicar `041`, S6 QR ciudad/sucursal auto, banner QR pendientes.
- **2026-06-09:** **Fix pedido cliente 400** — Backend: precio de venta siempre del servidor (`pedidos.service.ts`, ya no `PRECIO_INVALIDO`); filtro HTTP con mensajes de negocio. Flutter: `checkout_screen` usa `mensajeErrorHttp`, re-cotiza domicilio antes de confirmar; `pedidos_cliente_repository` omite campos `null`.
- **2026-06-09:** **A-MES-3 pedidos activos por mesa** — `GET /pedidos/mesa/:mesaId` (ítems + `estado_cocina` + total acumulado). Flutter: `MesaPedidosSheet` (expansible por pedido, colores cocina, marcar pagando, transferir).
- **2026-06-09:** **Mapa flujos — lote pendientes cliente/staff** — P02: `PromocionesCiudadStoriesBar` + `RestaurantesScreenFoody` (stories, búsqueda, cards). P06B: preview mapa checkout. P07: mapa destino + `tipo/lat/lng` en estado público. A-CAJ-3 descuento en `PedidoCajeroScreen`; A-CAJ-5 alerta arqueo >$5k. D-PL-2 tabs domiciliario planta; D-REG `/domiciliario/registro`. A-MES-2 timer QR 3/5 min. KDS sonido + alerta >20 min. Backend: `GET /promociones/ciudad/:slug/stories`, domiciliario historial/stats, `pedido_creado_at` en mesas.
- **2026-06-09:** **Flujos por rol (HTML → código)** — Mapa `docs/MAPA_FLUJOS_PANTALLAS.md`. Backend: `cajero`/`mesero` en `resolverDashboard`. Flutter: `/admin/cajero` (`PanelCajeroScreen`: apertura caja obligatoria + POS + tab caja), `/admin/mesero` (`PanelMeseroScreen`: mesas + kanban), `redireccion_staff.dart` unifica splash/login. Panel admin acepta `?seccion=` en ruta. — `docs/PLANES_SUSCRIPCION.md`: hoy `basico`/`pro`/`enterprise` solo se guardan en `suscripciones_restaurante` y se editan en Foody Control; **no restringen módulos**. Lo operativo es `estado` (`prueba`/`activa`/`vencida`/`bloqueada`) vía `SuscripcionActivaGuard`. Pendiente: matriz plan→features, guard por plan, vencimiento automático por `fecha_vencimiento`, UI upgrade en panel restaurante.
- **2026-06-09:** **Foody Control (superadmin) — UI y control operativo** — Rediseño `panel_foody_control_screen.dart` + `foody_control_ui.dart`: rail/drawer responsivo, KPIs, búsqueda, pull-to-refresh. Secciones: Resumen, Restaurantes, Planes, Usuarios, Ciudades, Config, Repartidores. Backend: `GET /super/restaurantes/:id/sucursales`, `fecha_vencimiento` en PATCH suscripción. Fix falso error al crear restaurante (timeout 90s, recuperación por nombre).
- **2026-06-09:** **Fix costos obsoletos en incluidos** — Backend recalcula siempre el producto incluido antes de sumarlo (`obtenerCostoUnitarioIncluido`, `listarItemsIncluidosProducto`); corrige $9 vs ~600+ en Rosquete×2. UI: pestaña receta aplica margen error 5%; incluidos muestran costo c/u × cantidad; una ecuación prep + incluidos = margen real.
- **2026-06-09:** **Fix desglose costos incluidos + receta** — `ProductoItemsIncluidosPanel`: total = `costo_calculado`, preparación = total − incluidos (ya no usa `costo_domicilio` ni doble cuenta). `RecetaProductoPanel`: pie usa suma de líneas (solo receta), no `costo_calculado` mezclado. Conversión unidades en líneas subreceta. Aviso en diálogo subreceta si `cantidad obtenida = 1` con lote grande.
- **2026-06-08:** **UX Costos e Insumos** — `costeo_ui_bloques.dart`; `CostosMargenesScreen` búsqueda/filtros + flujo «plato cliente → costeo» + margen en bottom sheet; `RecetaProductoPanel` resumen agrupado vs editar; `ProductoItemsIncluidosPanel` incluidos + costo real; `InventarioAdminScreen` guía pasos, chips, tarjetas, FAB.
- **2026-06-08:** **Armonía guía costeo v1.0** — Fix doble merma modo mercado (`costoLineaIngrediente`); `unidad-costeo.util.ts` (g/kg, ml/L); subrecetas anidadas en API + `dialogo_subreceta_form`; validación unidades en recetas; migración `040` umbral 35%; UI food cost semáforo + resumen «Recalcular todo».
- **2026-06-08:** **Fase B costeo KYG — Subrecetas** — `GET /costeo/subrecetas/detalle/:id`, `PATCH /costeo/subrecetas/:id`, `POST .../recalcular`; listado con costo_total y num_items; cascada a productos que referencian la subreceta; Flutter `dialogo_subreceta_form.dart` (cantidad obtenida, margen %, autocomplete insumos, KPI costo/gr, editar).
- **2026-06-08:** **Fase A costeo KYG — Lista de mercado** — Spec `docs/ESPEC_COSTEO_MERCADO_KYG.md`; migración `037` (proveedor, precio_compra, peso bruto/neto, categoria); `insumo-mercado.util.ts` deriva costo real (`precio/neto`); `PATCH /inventario/:id` ampliado + cascada recalcular; Flutter `dialogo_insumo_form.dart` (compra mercado vs solo costo, vista previa), tab «Lista de mercado», editar insumo.
- **2026-06-08:** **S6 precio_para_llevar** — Migración `035` (columna + demo hamburguesa 19500 llevar); DTOs catálogo; `menu.service` + `pedidos.service.precioVentaProducto()`; Flutter: `LineaCarrito.subtotalPara`, admin diálogo dual en `MenuAdminScreen`, KPI llevar en `CostosMargenesScreen`, hint en `MenuScreenFoody`, aviso checkout; `actualizarPreciosCanal` en repo admin.
- **2026-06-08:** **S5 producto_items_incluidos** — Migración `034` (tabla + demo Rosquete/Huevo frito); `CosteoService` suma costos incluidos y expande stock; `GET/PUT /productos/:id/items-incluidos`; tab **Incluye** en `CostosMargenesScreen` + `ProductoItemsIncluidosPanel`; KDS muestra líneas incluidas.
- **2026-06-08:** **S1 admin reorganizado (código)** — Sidebar: «Insumos» + «Costos y márgenes» (orden Menú → Insumos → Costos); `CostosMargenesScreen` master-detail responsive + slider `margen_objetivo` + aplicar precio sugerido; `RecetaProductoPanel` reutilizable; enlace «Ver costos» en `MenuAdminScreen`; tab Costos quitado de `InventarioAdminScreen`; backend `PATCH margen_objetivo` + `POST /costeo/productos/:id/recalcular`; repos `actualizarMargenObjetivo` / `recalcularProducto`.
- **2026-06-08:** **Admin menú y costeo (spec)** — `docs/ADMIN_MENU_COSTEO.md`: orden Menú → Insumos → Costos; UI responsive; slider margen; precio local/llevar; **productos con ítems de menú incluidos** (restaurante rosquetes: huevo +1 rosquete, carne/hígado +2); distinto de combos; tabla objetivo `producto_items_incluidos`. Actualizado `MODULO_COSTEO.md` (sin contradecir).
- **2026-06-08:** **Paso 3 Fase 1 cierre costeo** — DTO receta con `tipo_item` (ingrediente/subreceta/empaque); `GET /costeo/subrecetas`; tab **Subrecetas** + editor receta en Flutter; migración `033` (demo carne preparada, empaques domicilio en hamburguesa); scripts 026–033.
- **2026-06-08:** **Paso 3 costeo industrial Fase 1 (parcial)** — Migración `032_costeo_industrial.sql`; módulo NestJS `costeo` (`CosteoService`: merma, subrecetas recursivas, combos, `precio_sugerido`, alertas margen); API `GET /costeo/resumen`, `POST /costeo/recalcular`, `POST /costeo/subrecetas`; inventario delega costos y cascada post-compra; pedidos descuenta stock vía `expandirIngredientesProducto` (empaques en domicilio); Flutter tab Costos enriquecido (`CosteoRepository`, food cost, combos, recalcular); scripts migración 026–032.
- **2026-06-08:** **Paso 2 alertas automáticas** — `AlertasRiesgoService` centralizado; disparadores: transferencia mesa (>2), cancelaciones frecuentes, cuadre caja (>$5k), subida costo ingrediente (>15%), demora entrega (>2× estimado); refactor stock/descuento/dispatch; `POST /alertas/evaluar/:sucursal_id` (margen bajo 7d, caída ventas); doc `docs/ALERTAS_AUTOMATICAS.md`; Flutter botón «Evaluar reglas».
- **2026-06-08:** **Paso 1 cierre operativo pedidos** — Backend: costo combo = suma productos del combo (`pedidos.service.ts`); `POST /pedidos/staff` (mesa staff → `confirmado`, requiere `mesa_id`); estado Kanban `pagando` (listo→pagando→entregado en mesa/para llevar). Flutter: selector mesa en `PedidoCajeroScreen` vía staff API; columna Pagando en Kanban; `DomiciliariosAdminScreen` + menú sidebar. Migración `031_paso1_demo_recetas.sql` (recetas hamburguesa/papas para descuento stock).
- **2026-06-08:** **Paso 0 verificación base** — Docker/Supabase + backend `:3000`; script `scripts/verificar-paso0.ps1` (logins demo, rutas admin/cocina/domiciliario/super/cliente, migraciones 027–030); doc `docs/PASO0_VERIFICACION.md`. Resultado: **25 OK, 0 FALLO** (API). UI Flutter por rol pendiente checklist manual.
- **2026-06-07:** Documentación **módulo costeo industrial** — `docs/MODULO_COSTEO.md`: análisis Excel KYG (~187 insumos, 40 subrecetas, 20 platos), decisiones (multi-tenant, combos suma ítems, empaques domicilio, subrecetas teórico/lote opcional, alertas margen), fórmulas backend, migración `031` borrador, API/UI planificada, fases 1–3 y checklist de implementación.
- **2026-06-05:** Fix **Zonas de domicilio** admin — `NumberFormat` con `parsearNumero` (PostgreSQL `numeric` → String). **Horarios** — `GET /sucursales/:id/horarios`, `PATCH /sucursales/horarios/:id`, `HorariosAdminScreen` en panel. Migración `030_fix_demo_operacion.sql` (repartidor demo `activo`, dedupe `horarios_sucursal`).
- **2026-06-05:** Entorno local Windows+WSL — migraciones `026`–`029` en `supabase-db`; fix `028` (`movimientos_ingrediente`); backend recompilado con `ws` para Realtime; scripts `generar-env-backend.sh`, `puesta-a-punto-completa.bat`.
- **2026-06-04:** **Bloque 2 (dinero)** — IVA al crear pedido (`iva_porcentaje`/`iva_valor` desde config fiscal); módulo `zonas` (`GET /zonas/cotizar-domicilio`, CRUD `/zonas`); `POST /pedidos/:id/descuento` (≤20% staff, >20% admin/gerente, >30% alerta); reglas cancelación (motivo obligatorio, >2 min o en cocina solo admin/gerente). Flutter: `ZonasAdminScreen`, cotización en checkout, descuento en Kanban. Migración `027_bloque2_dinero.sql`.
- **2026-06-04:** Auditoría integral → `docs/archivo/ANALISIS_SISTEMA.md` (histórico).
- **2026-06-04:** **Bloque 1 (cocina)** — módulo NestJS `cocinas`: CRUD `/cocinas` y `/impresoras` (permiso `editar_productos`); KDS `/cocina/cocinas`, `/cocina/tickets/:id`, `PATCH /cocina/items/:id/estado` (permiso `ver_cocina`, recalcula estado del pedido). `auth.service` da `ver_cocina` y dashboard `cocina` a roles `cocina_*`. Flutter: `CocinasRepository`, `CocinasAdminScreen`, `KdsScreen` (`/admin/cocina` + sección panel), selector de cocina al crear/editar producto. Migración `026_cocinas_kds.sql` (permiso + impresora demo + `cocina@foody.demo`/123456).
- **2026-06-04:** Login demo — migraciones `022`+`025` en BD (super@foody.demo, repartidor@foody.demo); mensajes HTTP en staff login; id super sin conflicto con domi@foody.demo.
- **2026-06-04:** Fix 403 aprobar QR — permisos `aprobar_pedido_mesa` en BD (migración `024`); JWT recarga permisos desde BD en cada request; Flutter sincroniza `/auth/perfil` al abrir panel.
- **2026-06-04:** Fix build backend — import `DatabaseService` en `domiciliario-independiente.guard`; `QueryResultRow` en facturación; sin build el API queda sin POST/QR mesas (404). Banner en grid mesas + mensaje 404 con ruta.
- **2026-06-04:** Transferir mesa — `POST /mesas/transferir` (auditoría `transferencias_mesa`, alerta >2); Flutter tap mesa ocupada → elegir destino; `MesasRepository.transferir`.
- **2026-06-04:** Super Admin CRUD — `POST/PATCH /super/ciudades`, `PATCH /super/restaurantes/:id`; panel FAB ciudad + toggle activa; bloquear restaurante.
- **2026-06-04:** Seguimiento cliente — hora en timeline (`estados_pedido_historial.fecha`).
- **2026-06-04:** Legacy — `lib/legacy/README.md` (reglas limpieza; `features/` no importa `screens/`).
- **2026-06-04:** Mesas CRUD — `POST/PATCH/DELETE /mesas`, `GET /mesas/:id/qr`; Flutter FAB crear mesa, long-press QR/renombrar/desactivar; `MesasRepository`.
- **2026-06-04:** Super Admin — `/super/ciudades`, `suscripciones`, `domiciliarios`, `configuracion`; panel tabs; seed `super@foody.demo`; migración `023`.
- **2026-06-04:** Sprint 7 dispatch independientes — `DispatchService` (radio 3–9 km, ofertas 60s, alerta tras 3 intentos); `POST /auth/login-domiciliario`; endpoints `/domiciliarios/sesion/*`, `ofertas`, `pedidos`; auto-dispatch al pasar pedido domicilio a `listo` si no hay planta libre; Kanban «Buscar independiente»; Flutter login + dashboard repartidor; migración `022`.
- **2026-06-04:** Sprint 9 facturación — módulo NestJS `facturacion` (config, listar, emitir, HTML PDF); borrador en `POST /pedidos` si `requiere_factura`; migración `021`; Flutter checkout toggle + `FacturacionAdminScreen`; permisos `ver_facturacion` / `gestionar_facturacion`.
- **2026-06-03:** Sprint 9 usuarios — `GET/POST /usuarios`, `PATCH /usuarios/:id/estado`, `UsuariosAdminScreen` (gerente/cajero/mesero/domiciliario).
- **2026-06-03:** Fix 404 admin — verificación API desactualizada, mensajes HTTP amigables, carga parcial menú/caja.
- **2026-06-03:** Sprint 5–6 cierre — fiados caja, toppings/bebidas CRUD + vínculos, conteo físico inventario.
- **2026-06-03:** Sprint 5–6 UI — `PedidoCajeroScreen`, editar precio menú admin, editor receta en inventario; script backend recompila siempre.
- **2026-06-03:** Sprint 5–6 — módulos NestJS `caja`, `catalogo`, `inventario`; Flutter `CajaAdminScreen`, `MenuAdminScreen`, `InventarioAdminScreen`; panel admin wired; fix parseo movimientos caja y `cerrar` caja por `caja_id`.
- **2026-06-03:** Sección **Referencias persistentes** (reglas, variables, UUIDs demo, tablas BD, estados, endpoints, mapa código).
- **2026-06-03:** Sprint 4 — `GET /menu/mesa/:qr_token`, listado pedidos con `estado_desde`, dashboard con QR/alertas, Kanban con reloj y botones Confirmar/Aprobar, mesas con aprobar/rechazar, ruta `/mesa/:qrToken`, migración `017` permisos admin QR.
- **2026-06-03:** Regla `foody-avance-documentar.mdc` + este documento. Sprint 3: transacción pedidos ampliada, menú/toppings cliente, seguimiento Realtime.
- **2026-06-03 (sesión previa):** Kanban admin, pedidos API staff, flujo cliente MVP, migraciones y fundación NestJS/Flutter.

---

## No repetir (anti-redundancia)

- No crear segundo `main_foody.dart` ni app paralela.
- No reimplementar listas simples de menú/ciudades si `*_screen_foody.dart` ya existe — **extender**.
- No volver a conectar pedidos a Supabase/Firestore desde Flutter.
- No duplicar documentación de estado en `MEMORIA.md` — actualizar **solo** esta tabla/changelog.

---

## Cómo actualizar este archivo (checklist agente)

1. Cambiar **Última actualización** y, si aplica, **Sprint actual** / **Próximo paso**.
2. Ajustar filas de la tabla del sprint tocado (estado + hecho/falta/por qué/cuándo).
3. Añadir viñeta en **Últimos cambios** (fecha + qué archivos/módulos).
4. Si algo pasó a ✅, quitar tareas duplicadas en “Falta” de otros ítems relacionados.
5. Mantener **No repetir** al día si aparece código legacy nuevo.
6. Si tocaste BD, API o config → actualizar **Referencias persistentes** (UUIDs, endpoints, columnas).

---

# Referencias persistentes (contexto que no se debe olvidar)

## Reglas de oro (no negociables)

| # | Regla |
|---|--------|
| 1 | **Flutter = solo UI.** Cero cálculo de totales, IVA, stock, precios finales. |
| 2 | **Escritura crítica → NestJS**, no Supabase desde cliente (salvo Storage imágenes). |
| 3 | **`sucursal_id` en casi todo query** de datos de restaurante. |
| 4 | **Confirmar pedido = transacción atómica** en PostgreSQL. |
| 5 | **Stock se descuenta al confirmar pedido**, no al entregar. |
| 6 | **`auditoria_logs` solo INSERT** (inmutable). |
| 7 | **Impresoras solo vía Python local**, nunca desde Flutter. |
| 8 | **Cliente sin login** → `device_id` en `dispositivos_cliente`. |
| 9 | **Precios en `pedido_items` se copian** al crear (no referencia viva al producto). |
| 10 | **Un repo, un `main.dart`** — evolución in-place; no “Foody v2”. |
| 11 | **Multi-sucursal:** operación aislada por `sucursal_id`; no mezclar menú/stock/caja/pedidos entre sedes. Ver inventario otra sede = **solo lectura** (`docs/MULTI_SUCURSAL.md`). |

**Respuesta API (siempre):** `{ exito, datos?, mensaje? }` o `{ exito: false, error, mensaje }`.

**Guards (orden):** JwtAuth → UsuarioActivo → SuscripcionActiva → Rol → SuperAdmin (solo `/super/*`).

---

## Variables y entorno local

| Variable / constante | Valor dev (revisar si cambia IP WSL) | Archivo |
|---------------------|----------------------------------------|---------|
| `Configuracion.urlBackend` | Web: `http://localhost:3000/api/v1` · Móvil: `http://{ipWsl}:3000/api/v1` | `lib/core/constantes/configuracion.dart` |
| `Configuracion.urlSupabase` | Web: `http://localhost:8000` · Móvil: `http://{ipWsl}:8000` | idem |
| `Configuracion.ipWsl` | `192.168.227.118` (actualizar con `hostname -I` en WSL) | idem |
| `timeoutConexion` / `timeoutRespuesta` | 10 s / 30 s | idem |
| Postgres | `foody_db`, puerto `5432` (docker-compose.dev) | `docs/ENTORNO_LOCAL.md` |
| Scripts arranque | `scripts/iniciar-foody-dev.bat`, `iniciar-backend-wsl.bat` | raíz repo |

**Colores UI:** primario `#FF6B35`, secundario `#2EC4B6`, acento `#FFE66D` → `ColoresFoody` / `TemaFoody`.

**Paquete Dart actual:** `reserva_canchas` (legacy; imports siguen ese nombre).

**Entry point:** `lib/main.dart` · Rutas: `lib/core/rutas/app_router.dart`.

---

## Datos demo (UUIDs fijos — usar en pruebas)

| Entidad | ID / token |
|---------|------------|
| Ciudad Valledupar | `a0000000-0000-4000-8000-000000000001` · slug `valledupar` |
| Restaurante demo | `b0000000-0000-4000-8000-000000000001` |
| **Sucursal Centro** | `c0000000-0000-4000-8000-000000000001` |
| Cocina principal | `d0000000-0000-4000-8000-000000000001` |
| Producto hamburguesa | `f0000000-0000-4000-8000-000000000001` |
| Mesa 1 QR | `30000000-0000-4000-8000-000000000001` · token **`demo-mesa-1`** |
| Admin staff | `admin@foody.demo` / pass **`123456`** · user id `90000000-0000-4000-8000-000000000001` |
| Super admin | `super@foody.demo` / **`123456`** · migración `023` |
| Domiciliario planta demo | `domi@foody.demo` / **`123456`** · migración `019_domiciliario_demo.sql` |
| Domiciliario independiente demo | `repartidor@foody.demo` / **`123456`** · migración `022` |

Seed principal: `foody_supabase/migrations/012_seed_demo.sql` (+ `014`–`017` admin/pedidos).

---

## Jerarquía de datos (columna vertebral)

```
ciudades → restaurantes → sucursales (TODO cuelga de sucursal_id)
  ├── categorias → productos (+ receta_id opcional) → toppings/bebidas/combos
  ├── cocinas → impresoras
  ├── mesas (qr_token único)
  ├── pedidos → pedido_items → toppings/bebidas en línea
  ├── ingredientes → recetas → receta_items → movimientos_ingrediente
  ├── cajas → movimientos_caja
  └── usuarios (staff, JWT) — clientes NO en usuarios, solo dispositivos_cliente
```

---

## Estados del pedido (orden operativo)

| Estado | Cuándo |
|--------|--------|
| `pendiente_aprobacion` | Pedido **mesa** por QR; mesera debe aprobar |
| `pendiente` | Cliente para llevar/domicilio; restaurante debe **Confirmar** |
| `confirmado` | Aceptado; espera cocina |
| `en_cocina` | Preparación |
| `listo` | Listo para entregar/recoger |
| `en_camino` | Solo domicilio |
| `entregado` / `pagado` | Cierre / pago |
| `cancelado` / `rechazado` | Con motivo en historial |

**Historial:** tabla `estados_pedido_historial` (`estado_anterior`, `estado_nuevo`, `fecha`, `usuario_id`, `motivo`).  
**Reloj Kanban:** tiempo desde última fila donde `estado_nuevo = pedidos.estado` (campo API `estado_desde`).

**Constantes negocio (MEMORIA):** domicilio backend `5000` COP · reloj rojo Kanban **15 min** · comisión Foody domicilio **15%** (futuro).

---

## Tablas críticas (columnas que más se usan)

### `pedidos` (migración `005_pedidos.sql`)

| Columna | Notas |
|---------|--------|
| `id`, `sucursal_id` | Obligatorios en todo query staff |
| `mesa_id`, `device_id` | Mesa QR vs cliente anónimo |
| `stock_descontado`, `mesera_id`, `aprobado_at` | Migración `041`: inventario y mesera al aprobar |
| `numero_pedido`, `tipo` | `mesa` \| `para_llevar` \| `domicilio` \| `encargo` |
| `estado` | Ver tabla estados arriba |
| `subtotal`, `costo_domicilio`, `descuento`, `total` | Calculados en **backend** |
| `metodo_pago` | `efectivo` \| `tarjeta` \| `transferencia` \| `nequi` \| `pendiente` |
| `cliente_nombre`, `cliente_telefono`, `direccion_entrega`, `lat`, `lng` | |

### `pedido_items`

| Columna | Notas |
|---------|--------|
| `pedido_id`, `producto_id`, `cocina_id` | `cocina_id` copiado del producto al crear |
| `cantidad`, `precio_unitario`, `costo_unitario` | Precio/costo **congelados** en el pedido |
| `estado_cocina` | `pendiente` \| `preparando` \| `listo` (cocina app futura) |

### `productos` + menú

| Columna | Notas |
|---------|--------|
| `sucursal_id`, `categoria_id`, `cocina_id`, `precio`, `disponible` | Cliente solo ve `disponible=true` |
| `receta_id` | Si null → **no** descuenta inventario al pedir |
| Relaciones | `producto_toppings`, `producto_bebidas` |

### Inventario y costeo (migración `006_inventario.sql` + plan `031`)

| Tabla | Uso |
|-------|-----|
| `ingredientes` | `stock_actual`, `stock_minimo`, `costo_unitario_actual`, `tipo_costeo`, `rendimiento_porcentaje`, `sucursal_id` |
| `recetas` / `receta_items` | `tipo_item`: ingrediente \| subreceta \| empaque · ver extensión en `docs/MODULO_COSTEO.md` |
| `combos` / `combo_items` | `precio_fijo`; **plan:** `costo_calculado` = suma ítems |
| `movimientos_ingrediente` | `tipo`: compra \| venta \| ajuste \| merma \| … · `pedido_id` opcional |
| `margenes_venta` | Foto margen por línea al crear pedido |
| **Spec costeo** | `docs/MODULO_COSTEO.md` · Excel: `INFRAESTRUCTURA/TABLA DE COSTEOS KYG.xlsx` |

### Caja (migración `007_caja.sql`) — Sprint 5

| Tabla | Uso |
|-------|-----|
| `cajas` | `estado` abierta \| cerrada · una abierta por sucursal a la vez |
| `movimientos_caja` | `tipo`: venta \| retiro \| gasto \| ingreso_extra \| apertura |
| Al confirmar pedido con pago ≠ `pendiente` | INSERT venta si hay caja abierta (ya en `PedidosCajaAuditoriaService`) |

### Auth / staff

| Tabla | Notas |
|---------|--------|
| `usuarios` | `email`, `rol`, `sucursal_id`, `restaurante_id`, `activo`, `hash_contrasena` |
| `roles_permisos` | Lista permisos por rol; JWT lleva `permisos[]` |
| `dispositivos_cliente` | PK `device_id`; clientes públicos |
| `suscripciones_restaurante` | `estado` → guard `SuscripcionActivaGuard`. `plan` → **`PlanFeaturesGuard`** + límites numéricos. Ver `docs/PLANES_SUSCRIPCION.md`. |

### Otras

| Tabla | Notas |
|-------|--------|
| `mesas` | `qr_token` UNIQUE · pedido activo por LATERAL en API mesas |
| `auditoria_logs` | Solo INSERT · acción ej. `CREAR_PEDIDO` |
| `alertas_riesgo` | Dashboard cuenta `revisada=false` |
| `estados_pedido_historial` | Realtime + seguimiento cliente |

**Esquema completo:** `INFRAESTRUCTURA/esquema_maestro_bd_v3.md` · Migraciones: `foody_supabase/migrations/001`…`017`.

---

## Endpoints — implementados vs pendientes

### Públicos (sin JWT)

| Método | Ruta | Estado |
|--------|------|--------|
| POST | `/dispositivos/registrar` | ✅ |
| POST | `/dispositivos/vincular-auth` | ✅ Google/Supabase → device + reclama pedidos |
| GET | `/pedidos/mios?device_id=` | ✅ + Bearer opcional (auth_uid) |
| GET | `/menu/:sucursal_id` | ✅ |
| GET | `/menu/mesa/:qr_token` | ✅ |
| POST | `/pedidos` | ✅ transacción parcial |
| GET | `/pedidos/:id/estado` | ✅ |
| GET | `/zonas/cotizar-domicilio` | ✅ |
| GET | `/geografia/buscar?q=` | ✅ Photon OSM |

### Staff (Bearer JWT)

| Método | Ruta | Permiso típico | Estado |
|--------|------|----------------|--------|
| POST | `/auth/login` | — | ✅ |
| POST | `/auth/refresh` | JWT válido | ✅ AUTH-FLOW (mismo `tv`) |
| POST | `/auth/logout` | JWT | ✅ bumpea `token_version` |
| GET | `/auth/perfil` | JWT | ✅ |
| GET | `/dashboard/resumen` | `ver_dashboard` | ✅ |
| GET | `/pedidos` | `ver_pedidos` | ✅ |
| PATCH | `/pedidos/:id/estado` | `ver_pedidos` | ✅ |
| PATCH | `/pedidos/:id/aprobar` | `aprobar_pedido_mesa` | ✅ body opcional `mesera_id` (obligatorio si no es mesero) |
| PATCH | `/pedidos/:id/items/:itemId` | `crear_pedido` | ✅ cantidad/toppings/nota (Fase 2) |
| DELETE | `/pedidos/:id/items/:itemId` | `crear_pedido` | ✅ + reimpresión comanda |
| PATCH | `/pedidos/:id/rechazar` | `aprobar_pedido_mesa` | ✅ |
| POST | `/pedidos/:id/descuento` | `aplicar_descuento` | ✅ |
| CRUD | `/zonas` | `gestionar_sucursales` | ✅ |
| GET | `/zonas/sucursal/:id/configuracion-mapa` | `gestionar_sucursales` | ✅ |
| PATCH | `/zonas/sucursal/:id/ubicacion` | `gestionar_sucursales` | ✅ |
| GET | `/mesas/:sucursal_id` | `gestionar_mesas` | ✅ |
| POST | `/mesas` | `gestionar_mesas` | ✅ |
| PATCH | `/mesas/:id` | `gestionar_mesas` | ✅ |
| DELETE | `/mesas/:id` | `gestionar_mesas` | ✅ desactivar |
| GET | `/mesas/:id/qr` | `gestionar_mesas` | ✅ HTML + URL |
| POST | `/mesas/transferir` | `gestionar_mesas` | ✅ |
| GET | `/super/ciudades`, `/super/suscripciones`, `/super/domiciliarios`, `/super/configuracion` | super_admin | ✅ |
| POST | `/super/restaurantes` | super_admin | ✅ onboarding |
| GET | `/super/estadisticas` | super_admin | ✅ |
| GET/POST/PATCH | `/super/usuarios`, cambiar-contrasena, estado | super_admin | ✅ UI Foody Control |
| GET | `/super/restaurantes/:restauranteId/sucursales` | super_admin | ✅ selector usuario |
| PATCH | `/super/configuracion/:clave` | super_admin | ✅ |
| POST | `/super/domiciliarios/:id/aprobar-documento`, rechazar | super_admin | ✅ |
| GET/POST | `/sucursales/mi-restaurante`, `/sucursales` | `gestionar_sucursales` | ✅ |
| GET | `/sucursales/:sucursalId/horarios` | `gestionar_sucursales` | ✅ |
| PATCH | `/sucursales/horarios/:horarioId` | `gestionar_sucursales` | ✅ |
| POST | `/super/ciudades` | super_admin | ✅ |
| PATCH | `/super/ciudades/:id`, `/super/restaurantes/:id` | super_admin | ✅ |
| PATCH | `/super/suscripciones/:id` (plan, estado, `fecha_vencimiento`), `/super/domiciliarios/:id/estado` | super_admin | ✅ |
| GET | `/ciudades`, `/restaurantes/...` | público/staff | ✅ |
| POST/GET | `/caja/abrir`, `/caja/cerrar`, `/caja/activa/:id`, movimientos, gastos, retiro | `ver_caja` / `abrir_caja` | 🟡 |
| CRUD | `/categorias`, `/productos` (staff) | `editar_productos` | 🟡 |
| GET/POST/PATCH | `/inventario/...`, compras, receta producto, costos | `ver_inventario` / `editar_inventario` | 🟡 |
| GET | `/domiciliarios-planta/disponibles/:sucursal_id` | `gestionar_domiciliarios` | ✅ |
| GET | `/domiciliarios-planta/comisiones-independientes/:sucursal_id` | `gestionar_domiciliarios` | ✅ |
| GET | `/domiciliarios-planta/liquidacion/:sucursal_id` | `gestionar_domiciliarios` / `ver_caja` | ✅ |
| POST | `/domiciliarios-planta/liquidar/:domiciliario_planta_id` | `gestionar_domiciliarios` / `ver_caja` | ✅ |
| PATCH | `/domiciliarios-planta/config-fiado/:sucursal_id` | `gestionar_domiciliarios` | ✅ |
| POST | `/domiciliarios-planta/asignar` | `gestionar_domiciliarios` | ✅ |
| POST | `/domiciliarios-planta/reasignar` | `gestionar_domiciliarios` / `ver_pedidos` | ✅ |
| GET | `/domiciliario/pedidos-asignados` | `ver_pedidos` (planta) | ✅ |
| PATCH | `/domiciliario/pedidos/:id/en-camino`, `.../confirmar-entrega` | `ver_pedidos` (planta) | ✅ |
| POST | `/auth/login-domiciliario` | — | ✅ |
| POST | `/domiciliarios-planta/dispatch-independiente/:pedido_id` | `gestionar_domiciliarios` | ✅ |
| POST/GET/PATCH | `/domiciliarios/sesion/*`, `/ofertas-activas`, `/ofertas/:id/responder`, `/pedidos-activos`, `/pedidos/:id/*` | `domiciliario_independiente` | ✅ |
| GET | `/pedidos` (activos + `items_resumen`), `/pedidos/cerrados-hoy`, `/pedidos/:id/detalle` | `ver_pedidos` | ✅ kanban |
| GET | `/reportes/financiero`, `/productos`, `/pedidos` | `ver_reportes` | ✅ |
| GET | `/analitica/resumen`, `/ventas`, `/productos`, `/cocinas`, `/inventario`, `/domiciliarios`, `/caja`, `/riesgo`, `/export`, `/comparativa-sedes` | `ver_analitica` | ✅ |
| POST | `/impresion/reimprimir` | `ver_cocina` | ✅ COC-REIMP |
| GET | `/analitica/pedidos-recientes` | `ver_analitica` | ✅ dashboard Resumen |
| GET | `/analitica/rentabilidad` | `ver_finanzas` | ✅ P&L (ventas − COGS − gastos) |
| CRUD | `/finanzas/costos-fijos`, `/finanzas/empleados`, `/finanzas/gastos` | `ver_finanzas` | ✅ + pagar fijos/nómina |
| GET | `/alertas/:sucursal_id` | `ver_alertas` | ✅ |
| POST | `/alertas/evaluar/:sucursal_id` | `ver_alertas` | ✅ |
| PATCH | `/alertas/:id/revisar` | `ver_alertas` | ✅ |
| GET/POST | `/usuarios` | `gestionar_usuarios` | ✅ |
| GET | `/usuarios/meseros-activos` | `aprobar_pedido_mesa` / `ver_pedidos` / `gestionar_mesas` | ✅ picker QR |
| GET | `/usuarios/catalogo-roles` | `gestionar_usuarios` | ✅ P2-17 |
| PATCH | `/usuarios/:id` | `gestionar_usuarios` | ✅ P2-17 |
| PATCH | `/usuarios/:id/estado` | `gestionar_usuarios` | ✅ |
| GET | `/facturacion/config/:sucursal_id` | `ver_facturacion` | ✅ |
| POST | `/facturacion/config` | `gestionar_facturacion` | ✅ |
| GET | `/facturacion/facturas/:sucursal_id` | `ver_facturacion` | ✅ |
| POST | `/facturacion/emitir/:pedido_id` | `gestionar_facturacion` | ✅ |
| GET | `/facturacion/facturas/:id/pdf` | `ver_facturacion` | ✅ HTML preview |

### Pendientes (guía — no reimplementar si ya existe arriba)

| Área | Rutas objetivo | Sprint | Nota |
|------|----------------|--------|------|
| Super | PATCH config global | 8 | Editar `configuracion_global_foody` |
| ~~FCM push~~ | — | 7 | **Pospuesto** |
| ~~Facturación DIAN~~ | proveedor FE | 9–11 | **Pospuesto** |
| ~~Impresión Python~~ | WebSocket | 10 | **Pospuesto** |

**Lista maestra:** `INFRAESTRUCTURA/endpoints_api_foody.md`.

---

## Código — mapa rápido (dónde tocar qué)

| Capa | Ruta |
|------|------|
| Flutter features nuevas | `lib/features/<dominio>/` |
| Flutter legacy (no extender) | `lib/screens/`, `lib/providers/`, `pedido_service.dart` |
| Core Flutter | `lib/core/` (red, tema, rutas, sesión, dispositivo) |
| Backend módulo | `foody_backend/src/modulos/<nombre>/` (`facturacion/` Sprint 9) |
| Backend core | `foody_backend/src/core/auth`, `database` |
| SQL | `foody_supabase/migrations/` |
| Reglas Cursor | `.cursor/rules/foody-*.mdc` |

**Realtime Supabase (broadcast):** backend emite tras commit — canal `sucursal_{uuid}` eventos `pedido_actualizado` / `mesas_actualizadas`; canal `pedido_{uuid}` evento `estado_actualizado`. Cliente: `lib/core/realtime/foody_realtime.dart`. Requiere `SUPABASE_SERVICE_KEY` en backend y migración `028` (RLS bloquea `postgres_changes` anon). **Estrategia completa:** `docs/ESTRATEGIA_REALTIME_FOODY.md`.

### Continuidad visual admin — 2026-11-22

- Caja y Facturación reciben cobertura responsive reproducible: anchos 320/390/820/1440 px; listado de facturas probado en móvil y escritorio.
- Tarjeta de pedido del Kanban verificada a 280/320/390/820/1440 px. La prueba detectó un overflow del pie de número/tiempo/total; se corrigió permitiendo truncar el número de pedido.
- KDS verificado a 320/390/820/1440 px sin Supabase Realtime: overflow de pestaña corregido y la suscripción pasa a ser opcional, manteniendo polling como respaldo.
- Grilla de Mesas ahora usa el ancho de contenido efectivo para elegir columnas; widget test cubre móvil 320 px y tablet 820 px con panel de 520 px.
- El detalle MesaPedidosSheet usa tokens visuales del tema activo y pasa estados con cuenta a 320×568 y 390×844, en claro y oscuro.
- PedidosKanbanWidget pasa estado vacío en cuatro anchos y muestra un pedido activo con su acción primaria; la vista de columnas se ejercitó en escritorio/tablet. Se evita duplicar el prefijo “Mesa” en títulos.
- `CajaAdminScreen` acepta repositorio inyectado para pruebas de presentación; el comportamiento de negocio y endpoints permanecen iguales.
- `FoodyDialogoShell` desplaza contenido completo y evita restricciones intrínsecas incompatibles con `LayoutBuilder`; Insumo/Subreceta se validaron con teclado simulado.
- Validación focalizada: pruebas widget de Caja, Facturación, tarjeta Pedido, KDS, grilla/detalle de Mesas, Menú, Costos, Insumo y Subreceta aprobadas; análisis Dart limpio en Caja/Facturación/Pedido/KDS. Mesa conserva seis avisos informativos sobre deprecated fields, llaves y contexto async.
- La oleada global no está cerrada: quedan Pedidos/Kanban, Mesas/sheets, KDS, otros roles/vistas y QA visual con sesión real en claro/oscuro. Configuración Cloudflare Tunnel conservada.

---

## Errores API frecuentes (backend → Flutter muestra `mensaje`)

| Código | Significado |
|--------|-------------|
| `STOCK_INSUFICIENTE` | Receta/incluidos sin stock; respuesta incluye `detalles[]` (`nombre`, `necesita`, `disponible`, `unidad`) |
| `MESA_ASIGNADA_OTRA_MESERA` | Otra mesera ya atiende esa mesa |
| `PRODUCTO_NO_DISPONIBLE` | `disponible=false` |
| ~~`PRECIO_INVALIDO`~~ | Obsoleto: el backend usa precio de BD (canal mesa/llevar) |
| `RESTAURANTE_CERRADO` | Fuera de `horarios_sucursal` |
| `MESA_NO_ENCONTRADA` | `qr_token` inválido |
| `CAJA_NO_ABIERTA` | Futuro: operación caja sin turno |

---

## Decisiones ya tomadas (no reabrir sin motivo)

| Tema | Decisión |
|------|----------|
| BD | PostgreSQL Supabase self-hosted, no Firebase para negocio |
| Realtime | Supabase **broadcast** vía backend (service key); no `postgres_changes` anon |
| Cliente | Sin login; `device_id` |
| IVA | Incluido en precio menú |
| Impresión | Python local + WebSocket (futuro) |
| Base UI | Reutilizar pantallas legacy Cancha Fácil; datos NestJS |

- **2026-11-23 — QA E2E integral de pedidos:** PostgreSQL aislado foody_diseno_qa + Nest QA :3001; seeds oficiales 019/031 restaurados solo en QA.
pm run test:e2e -- --forceExit: 7/7 suites, 14/14 pruebas (QR, mesa, caja, cocina, domicilio, casos límite). Primer fixture no tenía domiciliario ni receta/stock; tras restaurarlo, pasó. DB_POOL_MAX=3 en el proceso de prueba agotó conexiones por tareas periódicas que conservan advisory lock mientras consultan BD; con 10 el health respondió en 111 ms. Este resultado no mide producción ni demuestra bloqueo en :3000; el efecto de impresora QA (127.0.0.1:8765 ausente) generó reintentos. Proceso y BD temporales se detienen al cerrar; Tunnel/OAuth/credenciales/BD negocio intactos.

- **2026-11-23 — FIN-TZ-01 / E2E reportes:** rangos de fecha compartidos ahora convierten límites YYYY-MM-DD con AT TIME ZONE America/Bogota; columna timestamp sigue indexable. PostgreSQL QA en UTC confirmó inclusión/exclusión exacta en medianoche local. Rutas autenticadas QA financiero/productos y Analítica resumen/ventas OK (9–17 ms en BD pequeña).
pm test: 10/32; E2E: 7/14; build OK. Se corrigió aislamiento del E2E COC-NODISP: el producto se restaura al finalizar el grupo, porque el caso apaga correctamente su catálogo y contaminaba tests siguientes. No se reinició Nest :3000; requiere reinicio controlado para activar la regla en el túnel; Cloudflare, OAuth, credenciales y BD negocio intactos.

- **2026-11-23 — Conciliación financiera QA:** consulta de lectura al periodo 1–23 nov: Finanzas P&L, Reportes tickets y SQL crudo en calendario Bogota coincidieron en 300.000 COP; delta 0. Reportes cobrado neto en caja 286.250 COP; el endpoint identifica universo distinto (tickets abiertos incluidos vs dinero recibido/devoluciones). Brecha 13.750 COP no se clasifica como error hasta la decisión FIN-DATE-01. No se consultó/modificó BD de negocio.

- **2026-11-23 — CLIENT-DEVICE-CAP-01:** trazado invitado/Google→device→pedido→historial/seguimiento. UUID v4 local se usa como credencial bearer en /pedidos/mios, estado/cancelación y llamadas; Google token válido vincula/reclama pedidos por ID, sin prueba extra de posesión. Condicionado a filtración del UUID; no es enumeración viable. Posible exposición de dirección/ubicación y recuperación del historial guest. Recomendado diseñar secreto de device/posesión y minimizar tracking tokens; decisión de producto/privacidad antes de alterar OAuth. Solo lectura de código; no se tocaron datos ni OAuth.

- **2026-11-23 — CAJ-TURNO-DURATION-UX:** Caja muestra turnos prolongados en días/horas y aconseja revisar pedidos/mesas/domicilios antes del cierre. Casos 14 h y 2635 h; widget 10/10 y analyzer focalizado limpio. Build Equipo `build/web_equipo` recompilado directamente con `usarTunel=true`; bundle local y Tunnel coinciden y Chrome confirmó el copy nuevo tras recargar. Cliente, panel y salud API públicos HTTP 200, cloudflared y servidores locales siguen activos. No se reinició API ni se ejecutó sincronización de entorno. Advertencias no bloqueantes del dry-run Wasm por dependencias JS heredadas y falta del asset CupertinoIcons; build web JS terminó con código 0.

- **2026-11-23 — POS-CAJA-ESTADO-01 / POS-UX-COPY-01:** fallo de `/caja/activa` se confundía con respuesta nula y mostraba falsamente “No hay caja abierta”. El POS ahora conserva el error diferenciado, ofrece reintentar y mantiene la confirmación bloqueada hasta tener estado confiable; sólo `null` sin error indica turno cerrado. Prueba intentó confirmar y verificó cero llamadas al repositorio de creación. Etiqueta de carrito corregida a “producto(s)” y cabecera adaptable. Regresión del POS 8/8 (incluye error+reintento y viewports 320/390/820/1440); `flutter analyze --fatal-infos` focalizado limpio. El backend ya exige caja al registrar ventas pagadas, validación autoritativa sin cambios. Build web Equipo actualizado directamente: texto verificado en el bundle local y público. Cliente, Equipo, API y puertos locales siguen en HTTP 200/listen; Tunnel activo. El build JS pasó con advertencias no bloqueantes de dry-run Wasm/dependencia CupertinoIcons. No hubo checkout ni escrituras reales.

- **2026-11-23 — PED-KANBAN-CERRADOS-01 / PED-KANBAN-KPI-01:** el GET de cerrados-hoy absorbía excepciones, confundiendo fallo con cero pedidos. Añadido loading/error/reintento; al fallar refresco/página secundaria, mantiene datos anteriores y muestra aviso y reintento. La suma de `pedido.total` activos se etiqueta “Valor en pedidos” y aclara en tooltip que no es dinero cobrado. Snack de transición usa etiquetas Foody (ej. “En cocina”) y se eliminó texto mal codificado. Widget 7/7 (4 anchos y error/reintento), analyzer focalizado limpio. Build Equipo release recompilado directamente con `usarTunel=true`, sin sincronizador: JS local y servido por Tunnel coincide en tamaño y contiene los textos nuevos; cliente, login Equipo y salud API públicos HTTP 200; :3000/:8080/:8081 y cloudflared activos. Avisos no bloqueantes de dry-run Wasm y CupertinoIcons; JS terminó correctamente. No se tocó OAuth, configuración ni datos de negocio; QA autenticada pendiente.
- **2026-11-23 — KDS-INITIAL-ERROR-01 / KDS-LIST-IMMUTABLE-01:** error en consulta inicial ya no se oculta como cocina vacía; muestra texto de error y reintentar. La lista devuelta por repository se copia antes del sort para tolerar colecciones inmutables. `kds_screen_test.dart` 9/9 (320/390/820/1440, card, error y recuperación), analyzer focalizado limpio. Build Equipo release directo correcto; bundle local y Tunnel HTTP 200, igual tamaño (6.517.822 bytes); cliente, login de Equipo y salud API 200; puertos :3000/:8080/:8081 y cloudflared activos. Sin reinicio Nest ni cambios de configuración/OAuth/datos. Smoke autenticado pendiente. Avisos Wasm/CupertinoIcons no bloquearon build JS.
- **2026-11-23 — DOM-PLANTA-ASSIGN-LOCK-01:** asignación/reasignación manual de planta toma `FOR UPDATE` sobre la fila del repartidor antes de comprobar pedidos activos; serializa concurrencia para no asignar al mismo repartidor desde dos solicitudes simultáneas a pedidos distintos. `domiciliarios-dispatch-guard.spec.ts` 2/2; `npm run build` Nest OK. No hubo requests operativos ni DB writes y no se reinició API viva. Falta E2E concurrente contra PostgreSQL aislado.
- **2026-11-23 — DOM-INDEP-OFFER-SIBLINGS-01:** aceptar una oferta cancela las ofertas activas hermanas y rechaza respuestas pendientes en la transacción; la consulta del repartidor filtra pedidos ya asignados/no listos y limpia ofertas obsoletas. `domiciliarios-independientes-dispatch-guard.spec.ts` 3/3; build Nest OK. No se reinició Nest ni hubo ofertas reales; E2E con dos sesiones y PostgreSQL aislado pendiente.
- **2026-11-23 — DOM-ASSIGN-SELECTOR-01:** cambios de disponibilidad invalidan/recargan opciones del Dropdown y la acción usa el valor vigente; evita asignar un repartidor que dejó de estar libre. `asignar_domiciliario_slot_test.dart` 1/1; analyzer focalizado limpio. Build Equipo directo actualizado, JS local/público 200 e iguales (6.518.046 bytes); salud API/login 200, puertos y cloudflared activos. Sin reinicio Nest ni cambios OAuth/config/datos.
- **2026-11-23 — FIN-DATE-01 UX / contexto de cuadre:** “Cobrado en caja (neto)” se entendía como dinero recibido dentro del rango; el SQL usa fecha de creación para movimientos vinculados a pedido y timestamp del movimiento si no tiene pedido. Reportes/Análisis ahora muestran etiquetas neutrales y la regla en pantalla; PDF y CSV llevan el contexto. Sin cambio de query, importes, datos u OAuth. Regresiones Flutter Reportes+Analítica 10/10 (incluye 320/390/820/1440), export CSV/PDF 2/2, Nest contrato 2/2 y build; `flutter analyze --fatal-infos` limpio en archivos tocados. Regresión completa posterior: Flutter 176 aprobadas/5 omitidas; Nest 19 suites/49 pruebas y build Nest OK. Build Equipo final; `main.dart.js` local/Tunnel SHA-256 `BA88921C9A33F379AF30733BA2CFCBFDC4EBB83DE86F1FE4CE3670092B681FF8` (6.523.729 bytes), incluye el KPI nuevo. `:8080`, Reportes público y salud API 200; cloudflared PID 11112. Nest `:3000` no reiniciado; fallback UI incluye la explicación con contrato anterior. Generación PDF pasa, aunque `pdf` emite un aviso genérico de Helvetica sin soporte Unicode (no reportó glifos omitidos en la versión final). La decisión financiera FIN-DATE-01 sigue pendiente y no se cambió la interpretación del periodo.
- **2026-11-24 — STARTUP-TUNNEL-PREFLIGHT:** el atajo `scripts/iniciar1` llega al BAT actual; `-SkipBuild` compila artefactos faltantes/desactualizados. Cliente y Equipo recompilados directamente y posteriores a fuentes; 8081/8080 local y público HTTP 200 con bundles del mismo tamaño; API salud/login y cloudflared activos. BAT completo no ejecutado porque reemplaza listeners y sincroniza entorno; no se tocaron OAuth, credenciales ni datos. Smoke de arranque completo pendiente en ventana controlada.
- **2026-11-23 — ANA-CANCEL-DENOM-01:** la inspección visual de Análisis mostró `Pedidos=9`, `Cancelaciones=81,3%` y `Alertas=478`. En fuente, pedidos de KPI excluye cancelados, mientras el porcentaje usa total de pedidos, incluidos cancelados/rechazados; la tarjeta no mostraba ese denominador. Nest expone ahora `pedidos_cancelados` y `pedidos_total_cancelacion`; Flutter muestra `N de total pedidos`, y con una API anterior aclara “Sobre pedidos del periodo” en vez de presentar ceros supuestos. La query de alertas cuenta pendientes actuales de la sede sin rango temporal, coherente con “Abiertas ahora”; 478 no se atribuye a los 7 días. Backend test 1/1 + build OK; Flutter test 2/2 y analyzer focalizado sin hallazgos. Chrome observó sin acciones de escritura; no se modificaron pedidos, alertas ni datos. Para que el endpoint actualizado entregue el denominador exacto en el Tunnel, falta reinicio coordinado del Nest :3000; Cloudflare no se modificó.
- **2026-11-23 — ANA-PARTIAL-LOAD-01 (cierre de regresión y publicación):** Flutter completo 173 aprobadas/5 omitidas; Nest 17 suites/45 pruebas aprobadas. `flutter analyze --fatal-infos` de los cuatro archivos de Analítica, sin hallazgos. Build Equipo Release termina correctamente; `main.dart.js` local y público devuelve el mismo SHA-256 (`CAF482275558DDC44A3FCB28B4CD335EB252E03171157A8A72430E4B504D7E39`, 6.522.567 bytes). Cliente/Equipo local y público y salud API devolvieron HTTP 200; `cloudflared` PID 11112 activo. Nest :3000 sigue sin reiniciar: el contrato de cancelaciones de backend requiere una ventana coordinada para activarse. El build web JS funciona; la prevalidación Wasm registra incompatibilidades de dependencias y hay una advertencia de asset CupertinoIcons, no bloqueantes para este build.

- **2026-11-24 — POS-GRID-DENSITY-01:** `PedidoCajeroScreen` decide columnas usando `LayoutBuilder` sobre el panel disponible y no el tamaño total de la ventana (que incluye carrito); tarjetas mantienen hasta 5 columnas y proporción 1,35, con 2 en móvil. Renderiza `imagenUrl` con `CachedNetworkImage` y fallback cuando falte/falle; ancho de decodificación limitado al tile. Regresiones de grid, imagen y barrera modal; `pedido_cajero_screen_test.dart` 10/10; `flutter analyze` focalizado limpio. `flutter test` global 182 aprobadas/5 E2E omitidas. Build Equipo Release termina correctamente (advertencias existentes Wasm dry-run/CupertinoIcons); bundle build/local :8080/Tunnel `main.dart.js` mismo SHA-256 `146C56F9C673F00F070ED8CE52E0C6C9AC1A1DA0A981C68F124FA3AE1B46F9FA`; :8080/Equipo público/salud API 200, `cloudflared` PID 11112. Chrome confirmó 5 columnas a 1920px; productos demo no tienen foto. No se enviaron pedidos. Hardware móvil y recorrido de otros flujos pendientes.
- **2026-11-24 — KDS-GET-WRITE-01 (corregido en fuente, sin activar en runtime):** `listarTickets()` ya no escribe. `CocinasDemorasCronService` evalúa cada cinco minutos, usa advisory lock `9200009`, filtra alertas pendientes y procesa hasta 200 pedidos por lote en una sola transacción vía `registrarVariasEnTransaccion()`. Tres specs/4 casos nuevos, Nest build OK; suite completa 22 suites/53 tests. No requiere dependencias nuevas. No se reinició el Nest :3000 que sirve Tunnel, por eso su GET sigue con binario anterior hasta ventana coordinada. La lectura previa de Chrome observó 105 tickets ≥20 min, varios de 3.790+ h y global “Cobrado”; no se tocaron pedidos. Pudo generarse alguna alerta; delta no verificable sin auditoría/BD, no se hará limpieza por conjetura. Backlog viejo y política de realerta después de revisión siguen abiertos. Ver `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.
- **2026-11-24 — regresión Flutter global:** `flutter test` completo terminó con 182 aprobadas y 5 omitidas (guards E2E requieren BD aislada); no hubo fallos. `git -c core.whitespace=cr-at-eol diff --check` pasó para el workspace en ese momento. Esto no cubre escritura E2E actual ni hardware móvil.
- **2026-11-24 — regresión NestJS global:** `npm test -- --runInBand` terminó con 19/19 suites y 49/49 pruebas aprobadas. Nest de :3000 no se reinició. No sustituye E2E autenticado actual en BD QA aislada.

**Verificación de continuación (2026-11-24):** Búsqueda global server-side y domicilios tardíos acotados corregidos en fuente. Nest 24 suites/55 tests, build OK; Flutter 186 aprobadas/5 omitidas; analyzer focalizado limpio y diff check limpio. Build Equipo 6.534.074 bytes; disco, :8080 y Tunnel SHA-256 idéntico `F23121F198A1ABBA7209B4F89CA5D52D3B6E4BF0F05760B3479801C0A14942EA`; ambos HTTP 200. cloudflared PID 11112, web :8080 y Nest :3000 (PID 7564) siguen activos; Nest no reiniciado, cambios API aún requieren activación coordinada. OAuth y datos de negocio sin cambios.
**Búsqueda global — UX responsive (2026-11-24):** el diálogo ahora se comporta como paleta de búsqueda de altura según contenido, acotada por viewport/teclado, con accesos rápidos, pedidos activos, mesas, módulos, límites de texto y resultados truncados con ellipsis. Los errores de pedidos/mesas se diferencian del vacío y ofrecen reintento; el servidor solo consulta pedidos desde dos caracteres. Prueba widget 7 casos (320/390/820/1440, búsqueda y scope, error/reintento, umbral); analyzer limpio. Build Equipo actualizado: `main.dart.js` 6.536.334 bytes y SHA-256 `CE7E986992F7E0ACB5906C37DA8295F8BD96C9909FF6E72B34BC0F1EEADAB8AD`, idéntico en disco, `:8080` y `https://equipo.foodyy.store`; local/público HTTP 200. API health HTTP 200; cloudflared PID 11112. Nest :3000 (PID 7564) permanece en ejecución con binario anterior, pendiente activación coordinada para que búsqueda/demoras server-side usen el código nuevo. No se modificó OAuth, credenciales ni datos.
**POS — accesibilidad de cantidades (2026-11-24):** los botones +/- del carrito ahora exponen 44×44 px de área táctil con icono compacto, tooltip y nombre semántico específico del producto. Prueba POS 10/10 confirma tamaño, label y cambio de cantidad; analyzer focalizado limpio. Regresión Flutter completa: 193 aprobadas, 5 omitidas por guard E2E de BD aislada. Build Equipo Release actualizado: 6.536.646 bytes, SHA-256 `5A5DCE7056D2439EDFB3AF16A6D1C69BE9990564FFEFC18E5DA97FF61ADE0AC8`, idéntico en disco, servidor :8080 y Tunnel `equipo.foodyy.store`. Cliente/Equipo local :8081/:8080, ambos públicos y API health respondieron HTTP 200; cloudflared PID 11112. El script de arranque no se ejecutó porque reemplaza los listeners activos; el estado actual de los sitios y API sí fue comprobado. OAuth, credenciales y datos sin cambios.
**Dashboard — KPI Alertas responsive (2026-11-24):** la última tarjeta deja de quedar angosta al final del wrap: pasa a franja horizontal de ancho completo en móvil y ocupa dos columnas en tablet; información y navegación permanecen. Widget dashboard 8/8 en 320/390/820/1440; analyzer focalizado limpio y Flutter global posterior 193 aprobadas/5 omitidas. Build Equipo vigente (incluye los controles táctiles POS): `main.dart.js` 6.537.994 bytes, SHA-256 `776643BDBE0042A3BD3496AD323907D012337CD64963D553FD46D974BE54B3A9`, idéntico en disco, :8080 y `equipo.foodyy.store`. Cliente/Equipo local y públicos y API health HTTP 200. El BAT de inicio no se volvió a ejecutar porque reemplaza listeners activos; los servicios existentes se verificaron sin parar el túnel. OAuth, credenciales y datos sin cambios.
**Pedidos — filtros por canal en móvil (2026-11-24):** los cuatro canales ya no hacen wrap y se recorren en una fila con fade; la fila de estado separada mantiene su interacción. Widget pedidos 8/8, incluidos 320/390/820/1440; analyzer limpio; regresión Flutter completa 193 aprobadas/5 omitidas. Build Equipo vigente (incluye POS/dashboard): 6.538.271 bytes, SHA-256 `21C90E666DB166C90EEFC41E1BD3605DB1CC94352DC4766AD59334A5F0E52421`, idéntico en artefacto, :8080 y Tunnel `equipo.foodyy.store`. Cliente/Equipo local, sitios públicos y API health HTTP 200; no se reinició Nest. El launcher no se volvió a ejecutar para no derribar servicios activos.
**Arranque diario — smoke posterior (2026-11-24):** se ejecutó `scripts/iniciar1/iniciar-foody-subdominios.bat` con la pausa deshabilitada. El launcher detectó Cliente desactualizado, reconstruyó `build/web_cliente` y terminó con ambos servidores arriba, sin el error anterior de archivo faltante. :8080 Equipo PID 18944 y :8081 Cliente PID 18876; Cloudflare PID 11112 y API Nest PID 7564 permanecieron activos. URLs locales/públicas Cliente y Equipo y health API: HTTP 200. Cliente release/Tunnel `6.538.285` bytes SHA `702F3FB36E4D5F93FD60C2154CBA37ADF781892B06806FB88F6DF325C98B3C7F`; Equipo release/Tunnel `6.538.271` bytes SHA `21C90E666DB166C90EEFC41E1BD3605DB1CC94352DC4766AD59334A5F0E52421`. `sincronizar-entorno.ps1` dijo “sin cambios”; no tocó OAuth, credenciales ni datos.
**Cocina/KDS — CTA táctil (2026-11-24):** tarjetas en layout estrecho ahora muestran “Marcar listo” como CTA de ancho completo; preparar, prioridad, nota y fallo quedan en otra fila y con hit-area mínima 48×48. `kds_screen_test.dart` 9/9 (320/390/820/1440) y analyzer focalizado limpio; Flutter global 193 aprobadas/5 omitidas. Build Equipo posterior: 6.538.679 bytes, SHA-256 `B6180EB15E17727974F7FE981CE5952AE672222FC8EEC94A1CC4692DD70C2668`, idéntico entre disco, :8080 y `equipo.foodyy.store`; cliente/equipo local/público y API health HTTP 200. El Nest :3000 no se reinició; código backend y flujo real de impresora aún requieren activación/prueba coordinada.
**Domiciliarios — cobertura mínima compacta (2026-11-24):** se agregó un escenario 320×640 a la prueba responsive existente, además de 390×844/820×1180/1440×1000; no produjo overflow ni cambios en la interfaz. `domiciliarios_admin_screen_test.dart` 4/4. Flutter global actualizado: 194 aprobadas/5 omitidas por fixture aislada/0 fallidas. El Equipo servido conserva build KDS previo y las cinco URLs de Cliente/Equipo/API siguen respondiendo 200. Pendiente validar perfiles/permisos y el flujo de payout contra decisión comercial.
**Shell Mesero/Cajero (2026-11-24):** ambos roles usan una barra compartida de navegación segmentada con selección visible, acciones semánticas accesibles sin duplicar nombre en screen reader, targets ≥56 px en móvil y versión compacta superior en desktop/tablet. AppBar y fondo usan `ColorScheme` del tema; lógica de navegación, focus, permisos y guard de apertura de Caja se conservan. Prueba compartida 2/2 (320/820), analyzer limpio; Flutter global posterior 196 aprobadas/5 omitidas/0 fallidas. Build Equipo release más reciente: 6.540.562 bytes, SHA-256 `97FD28C4C4FD334243DE2A9F0A78124743A3438EBDC7969B80DDF5EF9B4EFDC4`, idéntico en disco, :8080 y Tunnel; sitios locales/públicos Cliente y Equipo y health API HTTP 200. No se cambió OAuth ni lógica comercial. Falta navegar con sesiones reales de Cajero y Mesero.
**Análisis y Finanzas — visual claro/oscuro (2026-11-24):** superficies, KPIs, tarjetas de gráficos, pedidos recientes, insights y filtros respetan los tokens del tema; barras/líneas/pies y sus ejes/leyendas adaptan contraste. Los filtros seleccionados usan `primaryContainer`. Sin cambio de métricas, permisos, reglas financieras ni operaciones de pago. Suite analítica 12/12; Finanzas 8/8 (responsive 320/390/820/1440 y gráfico oscuro); analyzer limpio. Regresión global: **200 aprobadas/5 omitidas/0 fallidas**. Release Equipo: 6.542.144 bytes; SHA-256 `4FCAA258919916868B245D50A92D227DE3A6E41984817FF0A823B385F6EF1A5B`, coincide con :8080 y `equipo.foodyy.store`; Cliente público, Equipo local/público y API health HTTP 200; cloudflared PID 11112 activo. No se reinició Nest ni se alteró OAuth. Falta QA visual autenticada por pestaña/permiso, probar teclado/lectores y reconciliar Finanzas con datos de prueba.

**Pedidos — evitar colisión de número visible (2026-11-24):** `generarNumeroPedido()` usa lock transaccional por sucursal/año antes de `COUNT(*) + 1` y acota el conteo al año Bogotá. Prueba unitaria y build Nest pasan. Verificado en runtime aislado :3001 + BD QA con E2E completo secuencial: 8/8 suites, 15/15 pruebas; el caso concurrente creó cuatro pedidos públicos a la vez y obtuvo cuatro números diferentes. Se restauraron los datos de semilla QA (horarios 08:00–22:00 e inventario demo 10.000 g). No se reinició la API :3000 del Tunnel. No es prueba de estrés; secuencia dedicada queda diferida hasta que métricas de volumen la justifiquen. Detalle: `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**Alertas — tema oscuro (2026-11-24):** tarjetas y estados ahora usan sombras/tokens temáticos; severidad alta/crítica/media y revisión tienen tonos legibles en oscuro, y el spinner adopta `onPrimary`. `alertas_admin_screen_test.dart` 7/7; analyzer focalizado limpio; Flutter global 202/5 omitidas. Equipo Release recompilado con Alertas y Reportes (6.542.744 bytes; SHA-256 `694C31C487E5D65226BB08648E7B2D514F54750D78E06D7FE8856A1AAF8C04D4`); sitios locales/públicos Cliente/Equipo y API health HTTP 200; cloudflared PID 11112. No se modificó semántica ni OAuth. Falta QA autenticada con operador. Matriz: `docs/frontend/FOODY_PANEL_ADMIN_REDESIGN_MATRIX.md` (ADM-21).

**Reportes — contraste de filtros (2026-11-24):** los filtros de periodo usan `ColorScheme` para fondo, borde y texto en claro/oscuro. No cambian rangos, requests ni exportaciones. `reportes_admin_screen_test.dart` 6/6 con selector oscuro; analyzer focalizado limpio; suite Flutter global 202/5 omitidas. Build Equipo final 6.542.744 bytes; hash `694C31C487E5D65226BB08648E7B2D514F54750D78E06D7FE8856A1AAF8C04D4`. Matriz ADM-18: payloads/exportaciones y QA autenticada pendientes.

**Caja — navegación de aviso por turno largo (2026-11-24):** Admin dirige a Pedidos y Cajero a Mesas desde el aviso; widget responsive y análisis estático limpios. Flutter global: 206 aprobadas, 5 omitidas, 0 fallidas. Backend E2E aislado: 8/8 suites, 17/17 pruebas; una venta cobrada conserva igualdad entre delta de Caja, Reportes y Analítica (diferencia 0). Release web Equipo publicado sin reiniciar listeners, `main.dart.js` 6.543.993 bytes; SHA-256 disco/:8080/Tunnel `0A23264C478356E3BAFF70400E3E3E953E4785DBB0B0D2EEBECD9F839CBF5A60`. API :3000, Cliente/Equipo locales y ambos dominios públicos HTTP 200; cloudflared continúa. Se restauró QA y se detuvo API temporal :3001. No se tocó OAuth, credenciales ni datos reales. QA autenticada visual pendiente.

**Pedidos — semántica de cobro por canal (2026-11-24):** el POS distingue cobro inmediato para llevar, método previsto para cerrar mesa y método de domicilio. El E2E de domiciliarios confirma que la app del repartidor rechaza “Pendiente” (`COBRO_REQUERIDO`); el flujo manual de Admin lo convierte en efectivo y registra Caja. El Kanban pide confirmar expresamente que se recibió efectivo: cancelar no envía cambio de estado. Widget de confirmación/cancelación y E2E manual incluidos; suite de domicilios 4/4 en QA aislada. Flutter global 208 aprobadas/5 omitidas; analyzer focalizado limpio. La política de fallback permanece pendiente; sin cambio backend/payload. Bundle web Cliente/Equipo actualizado; Equipo 6.546.007 bytes, SHA-256 `DAED9D34A64676150D275522701496EB105608003C6BEA53702A4EF6AD48E7DA`, coincide en build, :8080 y Tunnel; ambos dominios y health API HTTP 200. API :3000 continúa sin reinicio.

**2026-11-24 — FIN-MESA-SPLIT-TRACE-01:** revisión estática encontró que cobros mixtos/unificados guardan una fila de pago por método con un solo `pedido_id` representativo y que `pedidos.metodo_pago` registra el primer método, aunque la cuenta se haya dividido entre efectivo/tarjeta. Los movimientos Caja continúan correctamente distribuidos por ticket y el historial visible usa `mesa_id`; no hay pérdida de caja actual demostrada. Riesgo futuro en comprobantes, devoluciones y consultas por pedido. Se documentó decisión pendiente entre transacción de mesa con asignaciones a tickets o líneas por ticket con transacción compartida. Sin cambios de esquema/datos. Ver `AUDITORIA_CAJA.md`.

**2026-11-24 — DOM-FIN-TRACE-01:** auditado código de cancelación y reportes del domiciliario independiente. La cancelación revierte caja del pedido, cancela asignación/ofertas activas y libera disponibilidad, pero las ganancias independientes quedan pendientes y el agregado de “por pagar” las incluye aunque la asignación esté cancelada. La comisión de Super Admin nace al aceptar oferta y es estimada, no recaudo conciliado. `total_entregas` también se incrementa al aceptar; su etiqueta se corrigió a “Ofertas aceptadas (histórico)”. No se encontró flujo para marcar/liquidar ganancias de independiente. Política de devengo, cancelación y pagador sigue abierta; no se tocaron saldos, historial ni reglas. Detalle en `AUDITORIA_REPORTES.md`.

**2026-11-24 — Smoke actual del arranque Tunnel:** iniciado por el atajo de `scripts/iniciar1`; los builds Cliente/Equipo estaban desactualizados, el launcher compiló ambos y mantuvo modo `tunel`. Proceso Cliente :8081 PID 11732, Equipo :8080 PID 19268; Nest :3000 PID 7564 y cloudflared PID 11112 continuaron activos. Los homes locales/públicos y salud API local/pública dieron HTTP 200; hashes locales/públicos de `main.dart.js` idénticos (Cliente `110F19081551B459C7C6FB11675AE05AE1226D469DF2225CB082599418997AD7`; Equipo `10B7E146B3E9E7B96305C4714C84039E5451B66829B143971E8C74D7A8D12C4C`). La sincronización indicó Flutter sin cambios; no se tocaron OAuth, secretos ni datos. Warnings Wasm y fuente Cupertino no impidieron los builds. La aplicación queda accesible por Tunnel con los bundles recién compilados.

**2026-11-24 — PED-POS-CAJA-GATE-01:** registrada discrepancia de flujo: el POS exige una Caja abierta al Admin/Cajero para todo pedido, pero contabilidad difiere movimientos de mesa y domicilio hasta cobro/entrega; el rol Mesero evita el guard. Puede ser política intencional de turno, así que no se quitó. Falta decidir su alcance y copy con perspectiva del restaurante. Revisión estática, sin mutaciones. Ver `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**2026-11-24 — Regresión Flutter y POS:** `flutter test --reporter compact` pasó 209 pruebas, 5 omitidas por guard de QA mutadora, 0 fallidas. Analyzer `--fatal-infos` focalizado en el POS no encontró incidencias. La pantalla exige caja abierta a Admin/Cajero incluso para mesa/domicilio cuyo movimiento se difiere; se dejó documentado como decisión de turno pendiente, sin cambiar el guard. No se completó QA visual autenticada porque la captura de ventana de Chrome devolvió Codex, aunque el árbol reportó URL Foody; no se toma como evidencia de imagen.

**2026-11-24 — PED-POS-REPLACE-ATOMIC-01:** reemplazar línea del pedido quedó en un endpoint Nest único y una transacción: agregar/quitar reutiliza reglas actuales, registra resultado idempotente y frena si la línea ya fue cobrada/asignada o el nuevo total exige reembolso. UI envía una sola llamada. Nest 37 suites/92 pruebas y build OK; Flutter global 237/5 E2E omitidas, POS+repo 20/20; analyzer focalizado limpio; build web release en QA aislada OK (warnings Wasm/iconos existentes). API :3000 no reiniciada; la corrección backend no está activa en runtime. Tunnel/OAuth/datos no se tocaron.

**2026-11-24 — FIN-PARTIAL-01 (verificación ampliada):** confirmado en código que un gasto parcial asociado a costo fijo o empleado suprime el pendiente de todo el mes, sin calcular saldo remanente ni consumir `periodo_desde/hasta`. El resumen también omite la cadencia diaria/semanal/quincenal al crear obligaciones de nómina. No se alteraron valores financieros: se requiere decidir semántica de sueldo base/frecuencia y un ledger de obligaciones por periodo para evitar deuda duplicada o invisibilizada. Evidencia detallada en `AUDITORIA_REPORTES.md`.

**2026-11-24 — MES-GROUP-ACCOUNT-01:** la cuenta abierta desde mesa secundaria unida podía aparecer vacía/incompleta, aunque la operación de cobro procesaba el grupo entero. Nest ahora carga tickets activos y abonos por todos los IDs del grupo; el resolver de cobro valida sucursal y mesas activas. Prueba unitaria 1/1, E2E Mesa 3/3 sobre `foody_diseno_qa` y API temporal `:3001`, Flutter `mesa_pedidos_sheet_test.dart` 9/9, build Nest correcto. Se limpiaron los pedidos de prueba y se desunieron las mesas QA usadas; API de prueba detenida. API `:3000` devolvió salud HTTP 200 y permaneció en PID 7564, con Tunnel intacto. Sin cambios OAuth, credenciales ni datos reales.

**2026-11-24 — MES-GROUP-FLATTEN-01:** el endpoint de unir mesas solo reasignaba los IDs elegidos, así que mover la raíz de un grupo dejaba integrantes apuntando a la raíz anterior. La consolidación ahora resuelve recursivamente la unión de todos los grupos involucrados y reubica sus pedidos activos en la mesa principal, serializando la operación por sucursal. E2E Mesa 4/4 sobre `foody_diseno_qa`; fixture restaurada (cero grupos) y API temporal `:3001` detenida. `npm run build` + unit spec 1/1 pasan. La API principal se reinició con el build actual (PID 4924); :3000 y los tres hostnames de Cloudflare respondieron HTTP 200; cloudflared PID 11112. OAuth, credenciales y datos comerciales intactos.

**2026-11-24 — DOM-DELIVERY-COUNT-LABEL-01:** `total_entregas` se incrementa al aceptar una oferta, incluso si después se cancela; Super Admin lo presentaba como entregas completadas. La etiqueta ahora dice “Ofertas aceptadas (histórico)”, que corresponde al dato persistido. Widget 2/2 y `flutter analyze` focalizado limpios. Sin cambios en comisiones ni pagos; cancelaciones y liquidaciones siguen pendientes de política comercial (`DOM-CANCEL-PAYOUT-01`).

## 2026-11-24 — Idempotencia y cierre de mesa agrupada

Se cubrió el reintento de agregar líneas a pedido abierto con clave idempotente persistida en la misma transacción; repetición igual no duplica líneas ni efectos, y payload distinto reutilizando clave se rechaza. También se corrigió liberar todas las mesas de un grupo cuando ya no queda pedido activo, mitigando bloqueo de cierre de Caja. Detalle/evidencia en `AUDITORIA_PEDIDOS_CICLO_VIDA.md`. QA E2E: 8/8 suites, 25/25; Flutter 223 aprobadas/5 omitidas; Nest build OK. La verificación unitaria Nest global está pendiente de resultado en esta sesión.

**Runtime del túnel y pruebas (2026-11-24):** se aplicó 090 (solo tabla nueva RLS) y reinició Nest para activar los fixes, sin cambiar registros de negocio. Backend unitario 30 suites/70 pruebas; E2E aislada 8/25; Flutter 223 aprobadas/5 omitidas. Launcher diario reconstruyó Cliente y Equipo; endpoints locales/públicos de ambas webs y API salud respondieron 200. Hash de cada bundle igual entre local y Tunnel; cloudflared activo PID 11112. QA temporal detenida/limpia. Ver detalle en `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**POS reintentos editables (2026-11-24):** la idempotencia conserva la clave para el mismo payload y rota si el usuario edita la operación luego de un fallo. POS 15/15, Flutter global 224/5 omitidas, analyzer focalizado limpio. Builds actualizados Cliente/Equipo; endpoints local/públicos 200 y SHA-256 coincidente. API :3000 PID 6860 y Tunnel PID 11112 activos. Sin pedido real de prueba.

## 2026-11-24 — PED-KEY-SCOPE-01 y smoke del runtime

La creación de pedidos ya consulta/reproduce idempotencia dentro de la sucursal y rechaza una clave usada con otro payload (409). Migración 091 aplicada a la BD diaria: 164 filas históricas vinculadas a su sucursal, PK compuesta y RLS forzada; no se modificaron pedidos ni pagos. Nest reiniciado PID 11708; cloudflared PID 11112. Smoke: API local/pública, web Equipo/Cliente local/pública HTTP 200; CORS preflight Equipo HTTP 204 con ACAO exacto. API QA :3001 detenida. Suite Nest unitaria 31/72, E2E 8/26, build OK en QA aislada. Detalle y limitación de revisión visual autenticada en `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**Addendum — arranque comprobado (2026-11-24):** ejecutado `scripts/iniciar1/iniciar-foody-subdominios.bat` con builds vigentes: exit 0; detectó API en :3000, modo `tunel`, conservó cloudflared (PID 11112), reinició Equipo :8080 (PID 3424) y Cliente :8081 (PID 4520). El launcher informó `main.dart.js` cliente de 6.552.311 bytes. Smoke posterior de los seis destinos local/públicos: todos HTTP 200. No necesitó reconstruir porque los builds existían y estaban al día; el camino de build faltante/desactualizado está definido en `servir-web-tunel-release.ps1`, aunque no se forzó una compilación destructiva solo para reproducir ese caso.

**COC-NODISP-COMMERCE-01 (2026-11-24):** auditoría de Cocina→Pedidos→Caja: una línea N/D puede dejar el pedido `listo` y el total original cobrable. Merma/off-menu y guard de despacho domicilio sí funcionan; falta resolver sustitución/ajuste/reembolso y conciliación de abonos, factura y Caja. E2E cocina aislada 3/3, sin mutaciones de datos comerciales; QA limpiada y :3001 detenido. Se corrigieron estados obsoletos COC-NODISP/CONS-NODISP-STOCK/CONS-KDS-UI y cascada de stock en la matriz de consistencia. Evidencia en `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**PED-DELETE-NODISP-STOCK-01 (2026-11-24):** al eliminar del pedido una línea N/D ya marcada como merma, el backend no restaura stock por error. E2E de Cocina compara inventario, total y renglones después de alta, N/D y eliminación. Cocina 4/4; Jest E2E 8/27; Nest unitarias 31/72; `verificar-todos-e2e.ps1` 9/9; Flutter pedidos/mesa/KDS 50/50; build Nest OK. QA limpiada, API temporal :3001 y agente de impresión :8765 detenidos. La política de ajuste/reembolso por producto no servido sigue abierta en COC-NODISP-COMMERCE-01.

**Activación posterior a PED-DELETE-NODISP-STOCK-01 (2026-11-24):** se reinició solo Nest diario para cargar el build corregido (PID 8284). API `:3000`, Cliente `:8081`, Equipo `:8080`, sus tres hostnames públicos y CORS preflight de Equipo: HTTP 200/204 con origen exacto. Cloudflare Tunnel sigue PID 11112. QA `:3001` y agente de impresión `:8765` están abajo; base QA sin pedidos activos y jobs temporales limpiados. No se tocaron OAuth, credenciales, rutas de túnel ni datos comerciales.

**ANA-FILT-PROD-01 — estado reconciliado (2026-11-24):** la matriz CONS todavía lo mostraba abierto, pero el servicio `consultarVentasKpi` ya usa `SQL_VENTA_LINEA_ITEM` al filtrar por producto/categoría/cocina y `AUDITORIA_REPORTES.md` ya registraba el fix. La suite integrada analítica pasó dentro de `verificar-todos-e2e.ps1` (9/9 scripts). Se cerró la discrepancia de documentación y se retiró `REP-FIX-01` del backlog, sin cambios de código.

**Aviso operativo N/D (2026-11-24):** antes del cobro, las vistas de detalle administrativo y cobro de mesa indican que los productos `no_disponible` siguen incluidos en el total y que el equipo debe validar el ajuste con el cliente. En cobro parcial por ítems, se cuentan solo los seleccionados. UI-only; sin cambios en precios, saldos, pagos o facturas. Pruebas Flutter de pedido/mesa 13/13 y analyzer focalizado sin issues. Release Cliente/Equipo recompilado con launcher exit 0; API y frontends local/Tunnel HTTP 200; cloudflared PID 11112 activo. No se cambió OAuth ni credenciales. Sigue pendiente la política comercial COC-NODISP-COMMERCE-01.

**Promociones — reconciliación documental (2026-11-24):** además de CONS-PROMO-ADD-01 (helper compartido para add/delete/update; QA integrada para add), se alinearon PROMO-DEL-01 (FK migración 089 con `ON DELETE SET NULL`) y PROMO-MANUAL-01 (descuento manual limpia `promocion_id`). Faltan decidir apilación promoción+combo y qué hacer con líneas nuevas en un pedido abierto tras desactivar su promoción; ampliar QA específica de editar/eliminar y desactivar→agregar. Sin cambios de código ni datos.

**FIN-TZ-ANALITICA-CAJA-01 (2026-11-24):** se corrigieron filtros de `gastos.created_at` y `cajas.cierre_at` para que sus fechas `timestamptz` respeten límites America/Bogota aun con PostgreSQL UTC. Analítica/Reportes/Finanzas 6 suites/11 pruebas; build Nest OK; cuatro límites de fecha probados en PostgreSQL QA de solo lectura. Sigue por definir la fecha para agrupar el libro de gastos (registro `created_at` vs fecha operativa `gastos.fecha`). Sin mutaciones de negocio.

**FIN-MIXED-REFUND-METHOD-01 (2026-11-24):** auditoría de código confirmó que reversa automática de un pedido con pago mixto suma el neto global, pero guarda una sola devolución con el método de `ventas.rows[0]` (query no ordenada). El importe total puede ser correcto mientras el desglose por método en Reportes/Analítica no lo sea. Política de reembolso parcial/por medio pendiente; no se alteró lógica ni datos.

**FIN-MIXED-REFUND-METHOD-01 — corrección en fuente (2026-11-24):** los movimientos automáticos de devolución ahora se distribuyen por caja y medio de pago con saldo pendiente; los centavos residuales se asignan con orden determinista. Unitarias 3/3 y build OK. Se añadió E2E de cancelación mixta, pero no ejecutada: QA :3001 estaba apagada y el control automático rechazó iniciar QA/reiniciar Nest :3000. `:3000` sigue sano pero ejecuta el proceso previo; cloudflared no se modificó.

**COC-CANCEL-NODISP-MERMA-01 (2026-11-24):** la cancelación en estado general `en_cocina` repetía el movimiento de merma para las líneas N/D que Cocina ya había registrado. La fuente ahora omite esas líneas al registrar merma de pedido; unitarias de inventario/Caja 4/4, build y compilación de E2E OK. E2E no ejecutada por API QA apagada; :3000 no reiniciado tras rechazo del control automático. Política de merma para líneas que aún están `pendiente` permanece por validar.
**2026-11-24 — PED-ENCARGO-QUOTE-DATE-01:** se corrigió el desacople de cotización en checkout: la estimación de un encargo puede ocurrir antes de que el cliente seleccione fecha; si la cotización sí tiene fecha, Nest la valida. Crear el pedido sigue exigiendo fecha y anticipación mínima. Jest focalizado 5/5; pendiente probar el flujo E2E con API actualizada. Sin cambios de datos de negocio, OAuth o Tunnel.

**2026-11-24 — PED-CLIENT-CANCEL-RACE-01:** cancelación cliente ahora revalida estado/antigüedad dentro de la transacción bloqueada; si el personal aceptó el pedido en la carrera, no se cancela. Unitaria 1/1. Build y runtime pendientes; sin mutaciones de datos/OAuth/Tunnel.

**Cierre de verificación PED-CLIENT-CANCEL-RACE-01 (2026-11-24):** verificación completa Nest: 34/34 suites, 79/79 pruebas; build OK. La ruta usa validación cliente dentro de FOR UPDATE, sin trasladar al cliente la restricción temporal genérica de staff. Runtime diario sigue sin activar los cambios de fuente.

**Verificación de arranque (2026-11-24):** el wrapper scripts/iniciar1/iniciar-foody-subdominios.bat delega al lanzador principal; builds Cliente/Equipo existen. Seis destinos (API salud, Cliente, Equipo, local y públicos) HTTP 200. Sin reiniciar procesos ni cambiar Tunnel/OAuth/credenciales/datos; el build backend de esta sesión requiere activación coordinada.

**2026-11-24 — DOM-EARNINGS-TRUTH-01:** historial independiente aclara que son ganancias estimadas (oferta aceptada), puede contener cancelaciones y no certifica pago; fila identifica estado de asignación. No se cambiaron montos, comisión ni liquidación. Flutter focalizado 22/22; analyzer limpio. Build release Equipo/QA autenticada pendiente.

**2026-11-24 — POS-COTIZACION-CASH-GUARD-01:** prevención de diferencia entre efectivo recibido y caja cuando falla cotización del POS. Bloquea el cobro inmediato hasta la cotización autoritativa y ofrece reintento; conserva canales diferidos. Widget POS 16/16, analyzer limpio y web release Equipo QA compilado; no afecta bundle remoto/runtime.

**COC-KDS-NULL-STATE-01 (2026-11-24):** se encontró que `estado_cocina` admite NULL y los predicados SQL `NOT IN` lo excluían de pendientes; se podía cerrar en caja un pedido con una línea en estado nulo. Guard de cocina/caja y consulta KDS ahora lo clasifican como pendiente. Prueba enfocada + KDS readonly 4/4; Nest 35 suites/83 pruebas, build y formato focalizado OK. No se modificó base de datos ni se reiniciaron API/Tunnel; la corrección aún requiere activación en runtime.

**PED-DISCOUNT-READY-CLOSE-01 (2026-11-24):** cuando descuento cubría el saldo de un pedido `listo`/`pagando` de salón, el servicio dejaba estado anterior. Ahora delega `pagado` en la máquina central solo con pago cubierto y estado listo/pagando; pedido en cocina sigue su ciclo y domicilio listo sigue a despacho. Suite Nest 36 suites/86 pruebas, build y formato OK; no se reinició API/Tunnel.
**FIN-DISCOUNT-REFUND-METHOD-01:** se documenta brecha: descuento posterior a pago inserta devolución con medio NULL y Reportes/Analítica la clasifican `sin_metodo`. Definir medio real de devolución y política de mezcla antes de ajustar contabilidad. No se cambian montos ni historial.

**Verificación extendida PED-DISCOUNT-READY-CLOSE-01:** cierre descuenta saldo, registra devolución, usa historial central, libera mesa cuando corresponde y notifica pedido/mesa; 3 escenarios cubiertos. Suite Nest 36/36 y 86/86, build y formato OK; runtime no reiniciado.

**KDS-LEGACY-STATE-UI-01 (2026-11-24):** se verificó manejo UI de estado cocina NULL como pendiente con acción normal; nueva regresión y KDS 14/14 (320/390/820/1440 px). No se completó inspección visual autenticada porque Chrome estaba en login; no se tocaron credenciales.

**NAV-ANL-01 (2026-11-24):** validada navegación de Análisis: selector compacto en 390 px, pestañas amplias en 1440 px y carga progresiva intacta. `analitica_screen_progressive_load_test.dart` 4/4. F4-03 cerrado; sub-nav Inventario sigue pendiente. No hubo cambios funcionales ni de datos; Chrome disponible permanece en login.

**PUSH-PERM-STATUS-01 (2026-11-24):** corregida la comparación Firebase web para leer `NotificationSettings.authorizationStatus`; evita tratar autorización válida como denegada. Sin solicitud de permisos, credenciales ni OAuth. Dart focalizado sin errores/warnings. Flutter completa 236 aprobadas/5 E2E omitidas. Analyzer global: 1 warning heredado del helper de semana sin uso y 35 infos.

**Smoke solo lectura 2026-11-24:** Cliente local/público, Equipo local/público y salud API local/pública 6/6 HTTP 200; Tunnel operativo en la observación. Sin reinicios ni publicación, por lo que correcciones recientes siguen pendientes de activación.

**DOMI-TOTAL-ENTREGAS-ACCEPT-01 (2026-11-24):** el contador del domiciliario independiente ya no suma al aceptar una oferta; suma al confirmar entrega, protegido por el estado `en_camino` y la transacción. No se recalculó histórico. Prueba focalizada 4/4, Nest 36/36 suites/87 pruebas, build/Prettier OK; sin reinicio de API/Tunnel.
**DOM-CANCEL-PAYOUT-01:** queda como decisión de negocio: el estimado se registra al aceptar y las cancelaciones pueden seguir listadas; no hay liquidación independiente. Decidir obligación, pagador, cancelación y medio antes de cambiar dinero.

**DOMI-LIQUIDACION-METODO-EXTERNO-01 (2026-11-24, auditoría):** entrega a cuenta registra CxC del producto (o saldo entero si domicilio entra a caja); liquidación cobra esa CxC, pero no registra el método real del componente de domicilio fuera de caja y deja `pedidos.metodo_pago='efectivo'` aunque el pago sea mixto. Caja no duplica ese componente externo. Decidir semántica de `pagos_pedido` y capturar el método real en entrega antes de corregir dinero; pruebas de ambos modos y mezcla pendientes. Evidencia: `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**PED-CANCEL-COPY-01 (2026-11-24):** se corrigió el diálogo Kanban que describía la reversa automática como “solo devuelve efectivo”. Ahora explica que Caja revierte los cobros registrados en su caja/medio de origen y que una reversa contable no confirma el reembolso electrónico del proveedor. La lógica permanece intacta. Pruebas focalizadas: reversa de Caja y widget de Kanban.

**PED-CANCEL-RBAC-01 (2026-11-24):** se ocultaron del detalle/tarjetas las transiciones si falta `crear_pedido`; aprobar/rechazar QR solo aparece con `aprobar_pedido_mesa`. Cancelar replica límites de rol/estado/2 min del servicio para perfiles no elevados. Detalle responsive 4/4, Kanban 12/12 (incluye solo lectura y cajero con pedido antiguo), analyzer limpio. `cancelar_pedido` existe en migración/roles/UI, pero no se consulta al autorizar transición; no se cambiaron privilegios. Definir si es permiso general, de excepción o redundante.

**COC-DISPATCH-INCOMPLETE-01 (2026-11-24):** se encontró que el estado general podía quedar `listo` por PATCH aunque faltaran ítems en Cocina; el gate de despacho solo revisaba no-disponibles. `DispatchService.validarPedidoParaDespacho()` ahora valida además que todas las líneas estén `listo` o `no_disponible`; NULL, pendiente y preparando bloquean dispatch, asignación de planta y oferta/aceptación independiente mediante la barrera compartida. Kanban muestra la explicación antes de ofrecer asignación. Nest 37 suites/93 pruebas + build; Flutter detalle/Kanban 16/16 y analyzer limpio. No E2E PostgreSQL ni reinicio de :3000; pendiente activar y demostrar el flujo con DB QA aislada.

**GLOB-ERROR-STATE-RESP-01 (2026-11-24):** estado de error compartido ahora es temático, limitado a 480 px y con acciones de 48 px; en móvil el reintento usa el ancho disponible. `flutter test test/foody_estado_ui_test.dart`: 8/8 (320/390/820/1440 px, claro/oscuro y acciones); `dart analyze` focalizado sin incidencias.

**START-TUNNEL-SMOKE-02 (2026-11-24):** ejecutado `scripts/iniciar1/iniciar-foody-subdominios.bat` con `FOODY_NOPAUSE=1`, exit 0. Detectó que los builds eran antiguos respecto a las fuentes, compiló release Cliente y Equipo (warnings no bloqueantes del dry-run Wasm y del asset CupertinoIcons), reemplazó únicamente listeners web :8080/:8081 y conservó API :3000 y Cloudflare Tunnel activo. Cliente/Equipo y salud API local/pública 6/6 HTTP 200; SHA-256 de cada `main.dart.js` local y del túnel coincide. El preflight confirmó que entorno Flutter, `CORS_ORIGEN`, `CLIENT_WEB_URL` y retornos Wompi ya coincidían; sincronizador informó Flutter sin cambios. OAuth y credenciales no se tocaron.

**MESAS-ROLE-CONSISTENCY-01 (2026-11-24):** comprobado que administrador, cajero y mesero usan `MesasGridWidget` y conservan variantes por rol. Suite de la grilla/formularios 10/10; analyzer focalizado limpio. F4-04 cerrado; no se tocó RBAC ni flujo de mesas.

**COC-DISPATCH-INCOMPLETE-01 — cierre del estado inconsistente (2026-11-24):** amplié el fix al origen: el comando central no permite `listo` si el pedido está vacío o hay líneas NULL/pendientes/preparando; bloquea antes de escribir estado e historial. Aplica a Kanban y Cocina automática; el error Nest se conserva como instrucción clara en Flutter. Jest 38/96, build Nest OK, Flutter error-contract 2/2. No reinicié :3000 ni ejecuté E2E PostgreSQL; activación runtime y E2E aislada siguen pendientes.

**PED-EDIT-01 (2026-11-24):** editar preparación de un pedido `listo`/`pagando` reabre `en_cocina`; cambiar observaciones también reinicia la línea si el texto cambia realmente. Edición y borrado bloquean reducciones que dejarían el total bajo el monto recibido, sin ejecutar reembolsos. Reemplazo mantiene su guard de sobrepago. Jest completo 39/101 y build Nest OK. Falta E2E PostgreSQL (incluido rollback) y activar en :3000.

**2026-11-24 — QA-E2E-ISOLATION-01:** intento controlado de API Nest aislada reveló que Firebase Admin toma ruta configurada desde el entorno del repo pese a valores vacíos del proceso. Se detuvo antes de correr pruebas; sin mutaciones de negocio/pagos. QA aislada: 0 fuentes Wompi activas y 0 candidatas. API/túnel `:3000` HTTP 200; QA `:3001` detenido. E2E PostgreSQL de PED-EDIT-01 y COC-DISPATCH-INCOMPLETE-01 sigue pendiente hasta poder desactivar con evidencia FCM y workers de fondo.

**2026-11-24 — E2E de cierre pedidos/Cocina/finanzas:** el switch `FOODY_QA_SIN_EFECTOS=1` permitió ejecutar una Nest aislada en :3001 sin cargar credenciales/proveedores ni workers externos. Unitarias 40/40 suites, 102/102; E2E API 8/8 suites, 32/32; batería 9/9 scripts; build OK. Se comprobaron rechazo de pedido incompleto, reapertura de Cocina al editar, rollback de reducción bajo abono y reversa mixta parcial. QA y agente de impresión detenidos; seis destinos local/Tunnel 200. No reinicié API :3000 ni publiqué cambios de backend; pendiente activación coordinada.

**2026-11-24 — QA E2E aislamiento externo ampliado:** `FOODY_QA_SIN_EFECTOS=1` anula carga de Firebase/Supabase (incluida Auth), Wompi y Photon, además de colas y crons. Dos pruebas verifican que no se leen claves/cuenta y que no hay llamada a Wompi. Build OK; unitarias 42/104; E2E 32/32; scripts funcionales 9/9. QA y agente temporal detenidos; seis rutas local/Tunnel HTTP 200, sin reiniciar API :3000.

## 2026-11-24 21:48 COT — Revalidación de runtime y túnel

API local/pública, Cliente local/público y Equipo local/público responden HTTP 200; `cloudflared.exe` PID 8940 sigue activo. La API :3000 (PID 19492) ejecuta `dist/main.js`, cuya última compilación es 21:22:34 COT, posterior al arranque del proceso: salud HTTP 200 no demuestra que las correcciones Nest compiladas estén cargadas. :3001 no tiene listener; el contenedor `foody-diseno-qa-db` continúa arriba en 55494, pero no se inició Nest QA. Sin reinicio/publicación ni escrituras de negocio.

## 2026-11-24 — RBAC-MT-READ-01 / MT-WRITE-ORDER-01: acceso cross-tenant

Se hicieron dos pruebas sobre clones temporales de `foody_diseno_qa`, con Nest QA en `127.0.0.1:3001` y `FOODY_QA_SIN_EFECTOS=1`. Primero, `admin@foody.demo` listó su sucursal (200) y recibió 403 con las sucursales de otros dos restaurantes. Luego, en otro clon, se habilitó a una cuenta admin sintética del tenant Free copiando únicamente el hash demo dentro de ese clon; ambos administradores listaron su propia sucursal y recibieron 403 al leer pedidos o intentar `POST /pedidos/staff` contra la sucursal ajena. El conteo de pedidos con IDs de prueba quedó en cero. Los dos clones se borraron, Nest QA se detuvo y se verificó que no quedaran conexiones. Esta sesión se extendió en un tercer clon a cierre de Caja cross-tenant: 403 y caja B siguió `abierta`, ver entrada siguiente. Sin cambios a la BD QA original, API :3000, OAuth, Cloudflare ni datos de negocio.

## 2026-11-24 — RBAC-TENANT-01: cierre de caja cross-tenant

En un tercer clon QA se abrió caja para el tenant Free con su cuenta sintética. El admin del restaurante demo intentó `POST /caja/cerrar` con el ID de esa caja y recibió HTTP 403. Un `SELECT` confirmó que la caja conservó estado `abierta`. Nest QA se detuvo; conexiones quedaron en cero y se eliminó el clon. Esta prueba cierra la evidencia E2E multi-tenant de autorización de cierre sin escribir en la BD original.
## 2026-11-24 — PED-POS-CAP-01 verificado y publicado: POS registra la capability del dispositivo al estimar `/pedidos/estimar`; repositorio 5/5, widget 17/17 y analyzer focalizado limpio. Equipo autenticado cotizó 35.000 COP sin crear pedido. Cliente/Equipo release local y por Tunnel coinciden en SHA-256; API local `/api/v1/health` y pública responden 200. OAuth, credenciales y datos comerciales intactos.

## 2026-11-24 — Verificación de deriva runtime/build Nest: PID 19492 inició a las 19:30; `dist/main.js` se compiló a las 19:32, así que el proceso vivo no cargó ese build. Salud local y Tunnel siguen 200, Cloudflare activo. Reinicio directo rechazado por política de ejecución; no se detuvo proceso. Pendiente activar runtime por mecanismo aprobado y verificar el flujo sin escrituras comerciales.

## 2026-11-24 — CLIENT-DOM-CONTACT-01 + E2E-CLEAN-TERMINAL-01: Checkout y DTO exigen teléfono válido de 7–15 dígitos solo para domicilio; nombre opcional. Flutter 3/3, prueba visual de layout base 4 anchos (320/390/820/1440), Nest DTO 8/8 y QR E2E 4/4 en QA aislada con servicios externos deshabilitados. La API rechazó solicitud sin teléfono y persistió el internacional formateado con nombre null. El limpiador QA ya excluye `entregado`; los 63 pedidos entregados se preservaron. Nest QA :3001 detenida; `dist` actualizado, API piloto :3000 anterior y requiere activación.

## 2026-11-24 — KITCHEN-PARALLEL-LOAD-01: la pantalla de cocinas solicitaba estaciones e impresoras en serie; al ser lecturas independientes por sede ahora se lanzan en paralelo. Test con respuestas pendientes confirma concurrencia. Cocinas 5/5 en 320/390/820/1440 px, analyzer focalizado limpio; Flutter global 264 aprobadas/5 omitidas/0 fallidas. Equipo Release reconstruido y publicado; candidato y carpeta servida tienen igual SHA-256, URLs locales/públicas 200, Cloudflare activo. No se modificó backend ni configuración.
## 2026-11-24 — CAT-PRICE-ACTION-01: la tabla Menú podía dejar el menú de acciones fuera del viewport a 1440 px. Se añadió un acceso directo accesible junto al nombre del producto; no cambió el endpoint ni el guardado. Menú 14/14, analyzer focalizado limpio; Flutter global 264 aprobadas/5 omitidas/0 fallidas. Equipo Release compilado y publicado en la carpeta local servida; URL local/Tunnel HTTP 200 y el bundle público contiene el nuevo texto. No se sincronizó entorno ni se tocó Nest, OAuth o datos comerciales.
## 2026-11-24 — QA-FULL-RECHECK-01: `npm test -- --runInBand` 48/48 suites y 123/123 pruebas, `npm run build` OK; `flutter test --no-pub` 264 aprobadas/5 omitidas/0 fallidas. `flutter analyze --no-pub` devolvió código 1 por 25 issues informativas (sin errors ni warnings); las vistas modificadas pasan análisis focalizado. Cliente, Equipo y API salud local/Tunnel: 6/6 HTTP 200; cloudflared PID 8940 activo. Nest PID 19492 arrancó 19:30 COT antes del build actual, así que salud HTTP no prueba que tenga cargado el `dist` recién compilado. No se reinició API ni se tocaron OAuth, `.env` o datos comerciales. Falta activar/verificar runtime y completar aceptación visual autenticada.
## 2026-11-24 — RBAC-UI-CAJA-01 / NAV-PED-MOVEMENT-01: el detalle de pedido solo ofrece «Ir a caja» a quien tiene `ver_caja`, alineado con la navegación/permiso del shell. Prueba detalle 5/5 incluye rol denegado y autorizado; Kanban 12/12; analyzer focalizado limpio; Flutter global 265 aprobadas/5 omitidas/0 fallidas. Equipo Release servido local/Tunnel (HTTP 200; SHA candidato/directorio coincide). AR-17 permanece parcial: esa acción abre Caja activa sin `pedido_id`, y el API lista movimientos por caja; falta un endpoint de solo lectura con scope y una vista que encuentre los movimientos del pedido histórico. No hubo escrituras financieras.


# 2026-11-25 — DOM-INDEP-SETTLE-TRACE-02

Se cubrió con prueba unitaria la confirmación de entrega de domiciliario independiente cuando hay abono previo y el pedido incluye productos + domicilio. Con pedido total 10.500, abono 2.000 y domicilio 2.500, el servicio registra el saldo de productos (6.000) y el de domicilio (2.500) con método independiente; Caja respeta el flag de sucursal, monto_pagado coincide con total y la propina queda en cero. domiciliarios-independientes-dispatch-guard.spec.ts pasó 6/6. El E2E `domicilio.e2e-spec.ts` pasó 6/6 sobre clon PostgreSQL desechable y Nest :3001 con efectos externos apagados. Incluye aceptación, ruta, entrega, total del pedido, Caja, ganancia pendiente y reconciliación por delta en Reportes/Analítica (ventas por total de pedido; recaudo/cobros por movimientos de Caja y domicilio conforme al flag). Se detuvo :3001, se eliminó únicamente el clon y `foody_diseno_qa` sigue intacta. Continúa pendiente la política de liquidación de ganancias; no se marcó ningún pago real.
# 2026-11-25 — WEB-START-FCM-ISOLATION-01 / OPS-STALE-ACTIVE-ORDERS-01

Tras publicar Equipo Release, `admin/login` local/público mostró pantalla blanca con `FormatException: Unexpected token '<'`. Se capturó el Future asíncrono de inicialización de Firebase Messaging para que fallo del registro push no se propague al arranque de UI. `dart analyze lib/main.dart` limpio; `servir-web-tunel-release.ps1 -SkipBuild` reconstruyó Cliente/Equipo y salió 0. Navegador confirmó login local, panel autenticado público y pantalla Domicilio con datos/reglas disponibles. Flutter domiciliarios 8/8; seis endpoints de salud/páginas local y Tunnel 200. El origen específico de la respuesta HTML no quedó identificado por falta de stack de la excepción; el manejo evita que tumbe el render. Sin cambios OAuth, credenciales, Tunnel ni registros comerciales.

En esa sesión visual el Centro de operación contó 9 activos y mostró mesa en cobro por 113 d 5 h y pedido `FDY-2026-0016` en ruta por 113 d 5 h; Domicilios indicó dos en ruta. Se documenta como observación pendiente: podrían ser datos QA/demo, pero no se comprobó; no se canceló, cerró ni editó nada. Revisar origen y política de depuración antes de cualquier mutación.
# Actualización 2026-11-25 — dashboard

Fuente corregida y verificada: serie de ventas del dashboard retorna 7 fechas calendario de Colombia con ceros para días vacíos; filtro/top de productos usa inicio local y fin exclusivo con zona horaria explícita. El KPI sigue siendo el total de alertas y el acordeón comunica su límite de 8. Tests focalizados backend 7/7, build Nest y widget responsive 9/9. Runtime activo :3000 es anterior y no se reinició; activación/prueba contra API/Tunnel pendiente. Sin cambios de datos, Cloudflare ni OAuth. Evidencia: `docs/archivo/auditorias-prompts/AUDITORIA_DASHBOARD_SERIE_7D.md`.

# Actualización 2026-11-25 — arranque web y KDS

El build Equipo que se sirve por :8080/Tunnel se recompiló y quedó publicado con captura local del Future FCM `getInitialMessage`; la misma sesión que fallaba volvió a abrir panel autenticado y KDS sin rechazo visible. SHA build/local/Tunnel `8E56BA20831F6466C4B6D6F8E4BA98D985E0ED3B4DCE21AD6668704988B0C3DE`; analyzer limpio. La confirmación de reimpresión se verificó en el KDS publicado y se canceló sin efecto. No hubo impresión real, OAuth, credenciales ni Cloudflare modificados. La API sigue stale y aún no sirve la corrección de gráfica 7 días. Evidencia `docs/archivo/auditorias-prompts/AUDITORIA_ARRANQUE_WEB.md`.

# Rendimiento — muestra API/Tunnel 2026-11-25

12 GET health pequeñas: localhost 200 p50 2 ms/p95 4 ms/máx 79; API Tunnel 200 p50 438/p95 520/máx 606. Web Equipo local 12x200 p50 2/p95 3/máx 65; Tunnel 4x200 p50 437/máx 709 ms (n=4, reporto max en vez de p95). ~430 ms de diferencia para estas respuestas pequeñas desde el PC. No mide endpoints con autenticación, navegador, móvil, SQL de operación ni carga concurrente; Nest seguía con versión anterior. Ver `docs/AUDITORIA_RENDIMIENTO_PUNTA_A_PUNTA.md`.

# Dashboard gráfico — actualización UX 2026-11-25

La serie con cero ventas ahora muestra estado vacío en vez de una gráfica plana; tarjetas de mix/top sin datos son compactas con icono (82 px). Pruebas 4/4 anchos y analítica caja 5/5; analyzer limpio. Build Equipo/Tunnel publicado con SHA `38D26D5FF5DDEFA293B826985114E890169CD1A34C55C9A2404040822812E6BD`; navegador confirmó el estado vacío compacto. Gráfica de ventas sigue con dos fechas porque Nest :3000 conserva artefacto anterior. Sin cambios funcionales ni datos. Evidencia `docs/archivo/auditorias-prompts/AUDITORIA_DASHBOARD_SERIE_7D.md`.


## 2026-11-25 — Runtime API stale y launcher

PID 10204 sigue en :3000 desde 07:22; dist/main.js fue actualizado a 09:14. Salud 200 continúa degradada por 317 errores históricos de impresión y la vista del dashboard confirma código previo. El iniciador oficial primero valida salud y salta a pi_ya_corre, sin rebuild/restart. El proceso Node es hijo del cmd que lo lanzó. El auto-review rechazó detener PID directamente, por lo que no se forzó reinicio alterno. Para activar la fuente actual, se requiere cerrar de forma normal el terminal propietario del backend y volver a ejecutar el iniciador. Tunnel y Equipo quedan arriba, no dependen de reiniciar Nest. Ver docs/archivo/auditorias-prompts/AUDITORIA_ESTADOS_OPERACION_STALE.md.

**2026-11-25 — WEB-ASSET-FALLBACK-FCM-01:** tras rebuild, `/firebase-messaging-sw.js` faltaba del artefacto aunque existe en `web/`; además el servidor SPA devolvía `index.html` HTTP 200 para cualquier recurso faltante. `servir-web-tunel-release.ps1` ahora copia recursos web raíz distintos de `index.html` al bundle; `spa_http_server.py` responde 404 para extensiones de recursos no encontrados. Build Cliente/Equipo exit 0; recurso local `application/javascript` HTTP 200; manifiesto `application/json` HTTP 200; asset inexistente HTTP 404; ruta `/admin/login` HTTP 200 con fallback. Cloudflare aún tenía caché antigua para la ruta FCM (max-age 4 h); con query cache-buster devolvió el JS nuevo (MISS). Al recargar el Chrome de la sesión autenticada, el panel Equipo renderizó y mostró el Centro de operación. No se cambió OAuth, Firebase credentials, configuración de Tunnel, API ni datos. Tests domiciliarios 8/8; analyzer focalizado limpio. La caché antigua de Cloudflare puede seguir sirviéndose a otros clientes hasta expirar; purgarla requeriría acción desde Cloudflare.

## Revalidación 2026-11-25 10:35 COT

Estado actual confirmado de forma read-only: PID 10204 sigue atendiendo :3000 desde 07:22; `foody_backend/dist/main.js` se actualizó a las 09:14; `/salud` devuelve `version=2026-07-01` y `base_datos=true`. :3001 no escucha. El equipo local :8080 da HTTP 200. La suite unitaria Nest sobre fuentes actuales pasó 55/55 suites y 144/144 pruebas (`npm test -- --runInBand --silent`).

No ejecuté `verificar-todos-e2e.ps1`: empieza cancelando pedidos activos y elimina trabajos de impresión en la base `foody_diseno_qa`. La base está en el contenedor dedicado `foody-diseno-qa-db` (21 MB), pero no hay confirmación del founder sobre el carácter desechable de todos sus datos. El intento de preparar una base temporal clonada y levantar Nest en :3001 fue rechazado por revisión automática; comprobación posterior confirmó que no se creó la base ni se inició :3001. No se tocó :3000, la QA persistente, Tunnel ni datos.

La activación del `dist` actual y E2E contra una copia aislada siguen pendientes. Esperar clasificación del founder antes de limpiar datos; para QA, habilitar un mecanismo autorizado de clon efímero con teardown validado.

## 2026-11-25 — Waterfall autenticado KDS

Chrome Network, una recarga cálida de la sesión KDS por Tunnel: 71 solicitudes acumuladas durante la observación; DOMContentLoaded 634 ms, Load 996 ms, 15,5 kB transferidos/16,8 MB de recursos (mayoría caché). `Finish` se contaminó por WebSocket Realtime persistente. Lecturas de API 216–268 ms y preflight 213–256 ms. Fuente: API banner sondea salud cada 20 s; banner Realtime cada 2 min; poll KDS revisa salud al programar el fallback de 90/30 s. Necesario separar tráfico inicial de operación continua y revisar coordinación, no afirmar 71 solicitudes de arranque. Una muestra warm no es p50/p95 ni capacidad. CORS no se tocó; revisar headers efectivos antes de valorar max-age. Evidencia ampliada en `docs/AUDITORIA_RENDIMIENTO_PUNTA_A_PUNTA.md`.

**2026-11-25 — PERF-CORS-PREFLIGHT-01:** DevTools y OPTIONS público identificaron OPTIONS repetidos de 213–256 ms y falta de `Access-Control-Max-Age`. Nest ahora configura `maxAge: 300`; build correcto. No se tocó OAuth, credenciales, allowlist, Tunnel ni Cloudflare. El API de Tunnel conserva proceso anterior y no se reinició; activación y verificación de header quedan pendientes del próximo reinicio normal. Ver `docs/AUDITORIA_RENDIMIENTO_PUNTA_A_PUNTA.md`.

**2026-11-25 — DOMI-FIADO-IDEMPOTENCIA-UNIT-01:** se agregó regresión de reintento: dos intentos sin CxC pendiente retornan `SIN_CUENTAS_PENDIENTES`, con `FOR UPDATE`, cero venta/caja. Nest 1/1. Falta replay sobre API+DB clon y escenario de abonos/métodos mixtos de domiciliario de planta. Propina sigue aparte de la cuenta obligatoria; custodia/reparto aún sin decisión. Ver `AUDITORIA_DOMICILIOS.md`.

**2026-11-25 — DOMI-FIADO-REPLAY-E2E-01:** script completo en clon QA confirmó entrega→CxC $8.000→liquidación→saldo cero→segundo POST HTTP 400 sin doble cobro. Restauró fiado a `false`; Nest QA apagada y clon eliminado (0 sesiones). Sin efectos externos; QA persistente, API pública y Tunnel sin cambios. Faltan concurrencia real, abono previo integrado de planta y método mixto en planta. Evidencia `AUDITORIA_DOMICILIOS.md`.

**2026-11-25 — DOMI-FLOW-PARTIAL-MIXED-01:** E2E API en clon: domicilio $13.000, abono $2.000 transferencia, producto contraentrega $6.000 efectivo, domicilio $5.000 Nequi fuera de Caja. Pedido queda pagado por $13.000, Caja registra $8.000 y SQL confirma los tres métodos. Se detecta campo resumen `pedidos.metodo_pago=efectivo` que no expresa el mix; evitar `mixto` en BD sin migración/contrato. E2E focalizado final 1/1; QA/Tunnel real intactos, API/clone temporales cerrados. Ver `AUDITORIA_DOMICILIOS.md`.

**2026-11-25 — REGRESIÓN:** Nest unit tests 60/60 suites, 168/168; build OK. Flutter 295 aprobadas/5 omitidas. `flutter analyze --no-pub` terminó exit 1 con 10 findings informativos: seis por API web `dart:html`/librerías web en tres archivos de notificaciones, tres usos de `BuildContext` tras gaps async y un `DropdownButtonFormField.value` deprecated. Sin diagnóstico de severidad `error`; no corregí la deuda en esta pasada porque las notificaciones y el registro de negocio requieren revisión de compatibilidad/regresión separada. E2E domicilios clon 7/7; QA API apagada y clon retirado.
