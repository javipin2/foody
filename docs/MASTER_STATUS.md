# Foody — MASTER STATUS (fuente oficial del proyecto)
**REPORTES-DOMI-DESGLOSE-01 (26-nov-2026):** Reportes mantiene el valor del pedido y expone `costo_domicilio` por tipo/día en API, panel, PDF y CSV; UI explica que es un componente del total, no ingreso reconocido del restaurante ni una cifra para sumar dos veces. Jest 4/4, GET E2E autenticado 1/1 en clon QA, Flutter 15/15 responsive, analyzer/build limpios. No cambió Caja/saldos; :3000 y Tunnel intactos.
**FIN-TIP-MIXED-ALLOC-01 — decisión aprobada (26-nov-2026):** propina fuera del total obligatorio; cuando el negocio la recibe, guardar su método propio, sin prorratear por los medios de la cuenta. Pago diferido no conserva la sugerencia. Implementación pendiente; investigar contrato, registro de pago, Caja/cierre por turno y conciliación antes de alterar el comportamiento. No migrar ni reinterpretar propinas históricas.
**SEC-DOMI-DOCS-PUBLIC-01 — abierto (26-nov-2026):** detectado que `foody-assets` es público y documentos personales históricos guardan URLs públicas. En fuente, cargas nuevas pasan a `foody-documentos-privados`, con enlaces firmados de 15 min; domiciliario y SuperAdmin resuelven rutas privadas al listar. Jest 6/6, E2E 2/2 contra Nest temporal :3002/clon QA y build OK: courier autorizado puede leer requisitos/documentos; Admin no puede leer ni cargar en endpoints reservados al courier; MIME/tipo inválidos responden 400; ruta privada se resuelve a URL firmada. Límite: Storage real desactivado en QA y el bucket privado no fue ejercitado; las filas/objetos legacy siguen públicos hasta una migración controlada. No se migró DB ni Storage diario ni se reinició :3000; :3002 detenida.
**PED-DOMI-GPS-OWNER-01 (26-nov-2026):** E2E valida `POST /domiciliario/ubicacion` (planta) y `/domiciliarios/sesion/ubicacion` (independiente): ubicación propia en `en_camino` da `registrado=true`; pedido ajeno da `false`. Planta focal 1/1 en QA :3001; independiente cubierto en E2E cancelación 1/1 en clon. Sin reinicio de :3000/:3001 ni cambio a Tunnel.
**PED-DOMI-SESSION-CLOSE-ACTIVE-01 (26-nov-2026, fallback recomendado aplicado):** sin respuesta a la consulta, se aplicó la opción recomendada por instrucción del propietario: impedir cierre con asignación `asignado/en_camino`. Nest bloquea aceptación concurrente y verifica la asignación dentro de transacción antes de cerrar sesión; Flutter no borra auth local cuando Nest rechaza. Unit 9/9, build Nest, analyzer focal y E2E temporal QA pasan. `domicilio.e2e-spec.ts --testNamePattern='cancela un pedido de independiente'`: 1 passed, 9 omitidas; verifica denegación con GPS operativo, cancelación mantiene sesión disponible y cierre posterior deja la sesión inactiva. La primera corrida reveló una expectativa de test incoherente tras el cierre; corregida y repetida. API :3002 usó exclusivamente clon QA y `FOODY_QA_SIN_EFECTOS=1`, y se detuvo; :3000 PID 16876, :3001 PID 2876 y Tunnel PID 17128 intactos; API pública salud 200. Sin cambios en DB diaria.
**DOMI-GANANCIAS-RESUMEN-100-01 (26-nov-2026, corregido en fuente y smoke QA):** resumen de ganancias/comisiones basado en `COUNT/SUM OVER()` del período completo; listado mantiene 100 filas recientes y Flutter informa ese límite. Unit 2/2, Nest build, Flutter 9/9 320–1440 px/claro-oscuro, analyzer y SQL QA (125 filas simuladas) OK. API temporal :3002/clon autenticada: resumen HTTP de 25 registros ($106.250/$18.750) coincide con agregado SQL independiente. Límite >100 probado sintéticamente, no con volumen real. :3002 detenida; no se activó :3000; Tunnel intacto.
**DOM-CANCEL-PAYOUT-01 (26-nov-2026, decisión confirmada):** ganancias de ofertas canceladas se conservan como historial y se excluyen de `por_pagar`. Fuente cambia únicamente el filtro del agregado administrativo; no altera filas ni liquida dinero. Build Nest + unidad 1/1 + E2E focal domicilio 1/1 en :3002/clon aislado; E2E conserva historial, excluye canceladas de `por_pagar` y prueba ownership GPS; Flutter Domiciliarios 10/10 responsive. :3000, :3001 y Tunnel intactos; instancia :3002 cerrada. No hay endpoint de liquidación real.


**PED-DOMI-ASSIGNMENT-OWNER-01 (26-nov-2026):** dos casos unitarios confirman que `marcarEnCamino` y `confirmarEntrega` requieren asignación del domiciliario autenticado y detienen pedido ajeno antes de mutar; `domiciliarios-dispatch-guard.spec.ts` 4/4. El E2E de éxito domicilio previo mantiene evidencia del flujo autorizado (9/9).

**PED-PLANTA-CANCEL-RELEASE-01 (26-nov-2026):** E2E QA focal 1/1 confirma que Admin puede cancelar un pedido de planta que ya está `en_camino`; desaparece de los activos del repartidor y vuelve `ocupado=false` en disponibilidad. Se verificó en API QA :3001; :3000 y Tunnel no se tocaron. La política financiera independiente no se incluye.

**PED-SUCURSAL-DOMI-SCOPE-01 (26-nov-2026):** pruebas `SucursalScopeService` + `DomiciliariosPlantaController` **14/14**: asignar, reasignar y dispatch independiente rechazan un gerente con permiso de gestión en sede hermana antes de llamar servicios. No hay E2E válida porque el gerente QA carece de ese permiso y los overrides no agregan permisos; intento de crear usuario sintético rechazado y transacción revertida, sin grants ni despacho mutados. :3000/Tunnel intactos.

**PED-CAJA-SUCURSAL-READ-01 (26-nov-2026):** QA :3001 confirmó aislamiento de Caja para gerente: caja activa, fiados y resumen de la sede propia 200; las tres lecturas de la sede hermana 403. Suite `sucursal-scope.e2e-spec.ts` 4/4, solo GET; sin cambios a movimientos, API :3000 ni Tunnel. Evidencia en handoff.
**PED-CAJA-SUCURSAL-WRITE-01 (26-nov-2026):** unit test con `SucursalScopeService` real confirma que apertura de Caja en una sede hermana se deniega antes de llamar a `CajaService.abrir`; controlador 15/15. No se envió POST al runtime para evitar escrituras accidentales. E2E HTTP de lectura entre sedes 4/4. Detalle y limitación en handoff.
**PED-CAJA-RBAC-MUTATIONS-01 (26-nov-2026):** rol Caja de solo lectura conserva consultas y recibe 403 en las siete rutas de escritura; E2E focal 3/3 (lectura, denegación de gastos y matriz completa). Cuerpos inválidos se detienen en el guard antes de controladores/servicios; sin movimientos ni mutación DB.

**Última actualización:** 2026-11-26 — Plan secuencial en `docs/HANDOFF_CODEX_FOODY.md`; tareas 1–5 y 11 de 12 cerradas (50% por cantidad, no ponderado); PED-CICLO-ORIGEN-01 sigue en curso. Se corrigió PED-CLIENT-CANCEL-ACTOR-01: cancelación pública daba 500 al insertar literal `cliente` en FK UUID; ahora el historial guarda actor nulo y motivo explícito. Build Nest; unitarias vínculo/sesión 13/13; E2E Caja 10/10, QR/cliente 7/7 + aprobación/rechazo QR + permiso rol cocina focal 3/3; QR completo 12/12; pedidos-admin RBAC 7/7; rutas admin de pedidos 4/4; auditoría financiera FIN-CONCILIACION-01 iniciada, sin cambios comerciales, domicilio 9/9 y scope entre sucursales 3/3; fix manual de entrega/assignment verificado en clon QA. START-TUNNEL-01 verificado con rebuild de Cliente/Equipo y healthchecks local+público 200; API :3000 PID 16876 y Tunnel PID 17128 preservados. QA :3001 PID 2876. DB diaria/runtime sin cambios; OAuth/credenciales/datos diarios intactos.
**UI-PEDIDOS-STATE-SCROLL-01 (26-nov-2026):** añadido indicador táctil accesible para navegar tabs del Kanban; 320/390/820/1440 pasan, suite widget 12/12 y analyzer focal limpio. Se corrigió el reinicio del scroll al ocultarse la flecha; el test recorre hasta “Cerrados” y valida reintento. Sin cambios backend/runtime.
**PED-RBAC-DOMI-LIQ-OR-01 — 🟡 fallback recomendado implementado (26-nov-2026):** `liquidar` requiere ambos permisos; `@Permisos` conserva OR. Backend 4 suites/28 + build; Flutter 10/10 + analyzer. HTTP/E2E del build nuevo en instancia temporal :3002/clon: Admin pasó guard a validación sin movimiento (400 con ID inexistente), cajero 403 al liquidar y 200 al leer resumen; E2E focal 1 suite/2 pruebas. :3000 y :3001 sin reinicio; :3002 detenido tras prueba.
**PED-KDS-STATION-RBAC-01 (26-nov-2026):** usuario Cocina queda restringido a su estación: no lista ni consulta tickets ni cambia estado de combo/línea, reporta no-disponibilidad, falla de preparación, observaciones o prioridad en línea de otra cocina; la E2E confirma que no se genera decisión cliente. Admin conserva acceso operativo. Prueba seleccionada `pedido-combo-decisiones.e2e-spec.ts`: 1 passed/12 skipped en QA :3001/clon; cleanup `afterAll` y query posterior confirma cero combos/cocinas temporales; Prettier OK. :3000 intacta.
**KDS-COMBO-STATE-MOTION-01 — 🟡 mejora UI verificada (26-nov-2026):** transiciones de `preparando` y espera de cliente usan color/tiempo semánticos existentes y se apagan con la preferencia `disableAnimations`. Tarea combo probada con sus acciones en 320/390/820/1440; KDS 22/22 y analyzer focalizado limpio. No altera reglas, contratos ni conexiones.
**ANALITICA-COHERENCIA-01 — avance 26-nov-2026:** Rentabilidad usa ventas cumplidas y COGS de las mismas líneas; domicilio `entregado`, salón/mostrador `pagado` como proxy hasta guardar entrega real. Cargo domicilio excluido del ingreso gerencial y separado. El propietario eligió estimación genérica de `iva_valor` con INC/IVA pendiente; validar con contador antes de uso contable. Fixture SQL/ROLLBACK QA: $121.848,74 venta reconocida, $50.000 COGS, $10.000 domicilio separado; también filtro de producto y recaudo: $50.000 cobros brutos - $8.000 devoluciones = $42.000 neto, fecha del movimiento. Panel/PDF distinguen valor pedidos, ventas cumplidas y recaudo. Jest 2 suites/4 tests, Nest build, Flutter 3/3 tests y analyzer limpios. :3000 no activada.
**Decisión tributaria del propietario (26-nov-2026):** conservar la estimación genérica en Analítica y mantener INC/IVA como clasificación pendiente. Límite: la implementación subyacente no es neutral; `FacturacionService` aún calcula con `aplica_iva`/`porcentaje_iva` y persiste `iva_valor`. No inferir ni presentar ese campo como impuesto fiscal confirmado; no se modificó configuración, factura ni cobros. Cualquier soporte fiscal requiere revisión con contador y alcance separado.
**DOM-CANCEL-PAYOUT-01 — evidencia vigente:** estimaciones canceladas siguen en historial individual y `ganancia_total`, pero se excluyen de `por_pagar`. E2E focal 1/1 en clon QA. No hay liquidación real.
**OPS-QA-DB-TARGET-01 resuelto:** el proceso padre de :3001 confirma `DATABASE_URL` al clon QA `foody_diseno_qa_codex_ledgerfull_20261126` vía Docker/WSL relay. Evidencia y resultado HTTP documentados en `docs/INFORME_MAESTRO_FOODY.md` y `docs/HANDOFF_CODEX_FOODY.md`.
**PERF-SQL-ANALITICA-01 — evidencia inicial QA 26-nov-2026:** EXPLAIN del SQL Rentabilidad 5 ejecuciones, 1.704 pedidos examinados/581 cumplidos: 15,019–17,322 ms (p50 15,693; p95 nearest-rank 17,322), seq scan de pedidos y lookups indexados en historial. Solo plan caliente local al clon; no justifica reescritura/índice por sí mismo. Sin carga, CPU/RAM/pool o activación diaria; informe actualizado.
**PED-RBAC-KITCHEN-ORDER-01 (26-nov-2026):** Cocina KDS autorizado 200; pedidos generales y Caja 403. Los endpoints generales de mutación de estado, agregar/reemplazar/editar/eliminar línea y asignar comensal reciben 403 (seis rutas probadas con IDs aleatorios, antes de acceso al servicio). Cajero: pedidos/Caja accesibles, KDS 403. `pedidos-admin.e2e-spec.ts` 7/7 en API QA :3001; no escribe pedidos ni pagos en los casos de permisos. :3000/Tunnel intactos.
**PED-RBAC-COURIER-BOUNDARY-01 (26-nov-2026):** domiciliario de planta consulta asignaciones; independiente consulta su sesión; el de planta recibe 403 en sesión independiente y el independiente recibe 403 en asignaciones de planta y Caja. `domicilio.e2e-spec.ts` 9/9 en QA. La matriz completa restante de mutaciones de línea/Caja/KDS sigue abierta.
**PED-RBAC-CAJA-GUARDS-02 (26-nov-2026):** `CajaController` cubre a nivel unitario los permisos requeridos para abrir/cerrar/retiro parcial: `ver_caja` no alcanza; permisos específicos sí. `caja.controller.spec.ts` 14/14. No ejecutó servicios ni escribió en QA. La integración E2E por rol para esas mutaciones sigue pendiente.
**PED-ITEM-STOCK-LEDGER-02 (26-nov-2026):** snapshots por línea guardan componentes/ingredientes/cantidad/costo. Edición de cantidad/toppings, eliminación, cancelación y combo manual compensan stock/merma desde el snapshot original, idempotentemente; no reexpanden receta vigente. Pagos vinculados bloquean mutaciones monetarias. Build Nest OK; pruebas focales 16/16 y 13/13; E2E en API QA :3001 + clon aislado: 2 suites/18 pruebas. Movimientos legacy sin snapshot se bloquean para evitar inferencias. Migration 099 no se aplicó a DB diaria ni se desplegó/reinició :3000.
**PED-CICLO-ORIGEN-01 — revisión (26-nov-2026; en curso):** rutas públicas, personal, KDS, Caja y domiciliarios contrastadas con máquina central. Unitarias 5 suites/22; E2E QA: domicilio 8/8, QR/mesa/mesero/replay POS 4/4, conciliación Caja/Reportes/Analítica 1/1, Caja completa 10/10, checkout público 2/2, sesión/seguimiento/aislamiento/cancelación cliente 7/7, aprobación Admin/gerente/mesero + rechazo; cajero/cocina 403, QR 12/12; pedidos-admin 5/5, y lecturas y escritura denegada entre sucursales 3/3. Se corrigió PED-CLIENT-CANCEL-ACTOR-01; Nest build OK. :3000 PID 16876, QA :3001 PID 2876 y Tunnel intactos; DB diaria sin cambios. Falta E2E de OAuth real cross-device (contrato unitario 13/13), matriz completa de permisos por rol aún abierta; asignación manual de entrega ya corregida en fuente/QA y conciliaciones fuera de escenarios probados; tarea sigue abierta.
**Actualización 26-nov-2026 — PED-COMBO-GUARDS-01 cerrada:** retiradas las guardas que bloqueaban cocina múltiple en `CatalogoService.crearCombo`, pedido nuevo/estimación en `PedidosCrearService` y agregado en `PedidosItemsService`. Cada tarea conserva la estación snapshot del componente; `pedido_items.cocina_id` sigue siendo la cocina principal por compatibilidad y la línea financiera/cobrable no se duplica. La política de componente sin estación mantiene fallback a cocina principal cuando existe; se conserva el rechazo si no hay ninguna estación asignada. Regresión contra API :3001/clon con combo de dos cocinas: se probó crear combo, estimar/crear pedido, agregar combo a pedido abierto, listar ticket por ambas cocinas y agregar estado `preparando`/`listo` hasta que ambas estaciones terminan. E2E focal **12/12**, Jest Catálogo **1/1**, Nest build OK. SQL confirmó cero combos/pedidos/cocinas temporales; se restauró cocina original del producto. :3000 PID 16876/Tunnel intactos; :3001 QA PID 20696, sólo clon aislado. Siguiente: PED-ITEM-STOCK-LEDGER-02.
**PED-ADMIN-MANUAL-DELIVERY-ASSIGNMENT-01 (🟡 corregido en fuente/QA, 2026-11-26):** al confirmar manualmente entrega, Admin cierra asignaciones activas en la misma transacción y recalcula disponibilidad del independiente. No duplica ganancias existentes ni las marca pagadas. Domicilio E2E 8/8 pasa planta e independiente, historial y ganancia no pagada; Nest build OK. API diaria :3000 no reiniciada. El clon mantiene 14 filas históricas incongruentes `en_camino`/pedido `entregado`; no se alteraron.

**PED-COMBO-IMPRESION-01 — verificación QA (26-nov-2026):** `ImpresionService` enruta las tareas activas a sus `cocina_id`, multiplica su cantidad por la cantidad vendida del combo y no imprime la línea padre cuando ya existen tareas. Reimpresión acepta `cocina_id`, devuelve error si no hay tareas de esa estación, y Cocina queda limitada por claim JWT. `CocinasService.listarTickets` agrega la cocina del ticket; notificación post-alta considera las estaciones de tareas combo. Nest build OK; Jest 3 suites/10 tests (incluye encolado por dos estaciones en mock, filtro, WebSocket falso y reintento); Flutter KDS/repositorio 24/24; E2E QA 8/8 verifica ticket real, autoencolado, reimpresión admin/cocina y rechazo 403 de otra estación. QA se mantuvo en clon con side effects desactivados; el seed solo permite una estación en E2E y no se probó hardware. PID :3001 QA actual 14168; :3000 PID 16876, Tunnel intacto. Task3 debe probar la integración multikitchen antes de retirar las guardas.

**Verificación PED-COMBO-APLICAR-01 (26-nov-2026):** API QA :3001 + clon designado: E2E 7/7: aceptación/rechazo/idempotencia, abono parcial con devolución exacta de $500 COP por Caja, conservación de otras líneas, IVA actualizado, ledger de stock/merma y rechazo de precio/stock obsoleto; Jest 12/12; build OK. La prueba detectó consulta SQL sobre `pedido_items.sucursal_id` (no existe) en el `dist` anterior y parámetros JSON sin tipo explícito; ambos corregidos en fuente/build. Cleanup QA elimina jobs de impresión asociados y SQL confirmó que no quedaron combos temporales ni pedidos de decisión. El seed solo tiene una cocina: multiestación real e impresión aún no probadas. `limpiar-demo-qa.ps1` restauró fixture/inventario y el SQL confirmó que no quedaron combos temporales ni decisiones QA. :3000, Tunnel y DB diaria intactos; tarea sigue en curso.

**PED-COMBO-APLICAR-01 — subpaso cotización vigente (2026-11-26):** una cotización ahora conserva el total base del pedido y aceptar exige que este no haya cambiado; el endpoint guarda también `respuesta_accion`. Previene confirmación de un total obsoleto por cambios concurrentes. Jest de decisiones 6/6 y build Nest OK. La aplicación transaccional de sustitución/rechazo sigue pendiente; no se reinició API :3000.

**Actualización PED-COMBO-KDS-STOCK-01 — respuesta y ledger (26-nov-2026):** tarea 4 tiene endpoints Nest y UI mesero para listar casos, cotizar reemplazo con versión y registrar aceptación explícita del nuevo total o cancelar solo el combo; aún no muta pedido/Caja/stock. El ledger de migration 097 captura cantidad/costo de ingredientes por componente desde el mismo desglose que origina el descuento, incluso al aprobar pedidos QR. La pausa conserva estado previo por estación; las tablas de decisión/tarea guardan IDs originales para mantener auditoría si se elimina la línea cobrable. Se añadió helper idempotente para devolución/merma/consumo desde ledger, aún sin integrar al caso de uso. Verificación: Nest build OK; 3 suites/20 pruebas focales y Flutter detalle/repositorio 15/15. Migrations 097/098 aplicadas solo al clon QA elegido. Falta aplicar de forma transaccional pedido, Caja, IVA/factura, inventario/merma y COGS. Sin reinicio :3000; Tunnel/OAuth intactos.

**Actualización PED-COMBO-KDS-STOCK-01 — KDS por tarea (26-nov-2026):** `CocinasService.listarTickets` une líneas normales con tareas combo y devuelve por tarea el ID propio, cocina, componente y plato padre; la línea financiera conserva `pedido_item_id`. `PATCH /cocina/combo-tareas/:tarea_id/estado` valida sucursal y cocina asignada, bloquea las filas del pedido/línea/tarea y agrega estados de todas las estaciones en el único `pedido_items.estado_cocina`; publica realtime y transición global como antes. Flutter KDS enruta acciones individuales y masivas por el endpoint correcto, muestra componente/plato asociado y no ofrece prioridad, notas ni “no disponible” para una tarea hasta completar el flujo de decisión del cliente. Nest build OK; Jest KDS 3 suites/5 tests; Flutter repositorio+KDS 21 tests; analyzer sin incidencias. Solo fuente/build y dobles de prueba: 097 no aplicada, no hubo prueba API→PostgreSQL, no reinicio :3000. Combo multi-cocina sigue bloqueado.

**Actualización PED-COMBO-KDS-STOCK-01 — pausa por componente (26-nov-2026):** `PATCH /cocina/combo-tareas/:tarea_id/no-disponible` exige motivo, valida estación/sucursal, bloquea pedido/línea/tarea, pausa las tareas hermanas pendientes/en preparación, registra una decisión pendiente con snapshot de precio/costo/nombre/tipo/plato padre y recalcula solo el estado de cocina de la línea. Una repetición del mismo evento conserva la misma decisión; otra incidencia para ese combo se rechaza mientras exista decisión abierta. Flutter explica que las demás estaciones esperan al mesero; el endpoint no registra merma, no apaga producto ni cobra/reembolsa. Invariante SQL: índice único permite una decisión pendiente por línea de combo. Nest: 3 suites/7 tests + build; Flutter repositorio+KDS 23/23 + analyzer limpio. API local y Tunnel salud HTTP 200; el smoke PATCH sin token responde 404 en ambos, evidencia de que el runtime activo aún no contiene esta ruta. 097 continúa sin aplicar; no se reinició :3000.

**Hallazgo de tarea 4 — respuesta de combo y ledger (26-nov-2026):** el pago por ítem solo se registra en `pago_pedido_items` para cobros explícitos por `item_ids` con un único método; los pagos habituales pueden quedar agregados al pedido. No debe inferirse una distribución de abonos por combo. `PedidosDescuentoService` sí tiene un precedente de ajuste transaccional neto con reembolso del excedente desde caja abierta, pero la política para rechazo de combo está pendiente de confirmación. El borrado normal de línea restaura con receta vigente del producto principal, no con el snapshot completo del combo; cancelar combo debe esperar al ledger de inventario por componente y no reutilizar esa reversa como exacta.

**Actualización PED-COMBO-KDS-STOCK-01 (26-nov-2026):** en cliente y POS los toppings del combo se agrupan por plato y su payload conserva el `producto_id` destinatario. Nest verifica pertenencia al combo y asociación vigente en `producto_toppings`; solo infiere para payload legacy si hay un plato único. Snapshot/tarea conserva plato padre y cocina, y la reposición de stock aplica el topping al producto snapshot correcto. Verificación: `npm run build`; Jest focal 3 suites/14 tests; Flutter cliente/POS/sheet 9 tests y analyzer limpio. Multi-cocina sigue bloqueada: KDS aún no consulta/actualiza `pedido_combo_tareas_cocina`; 097 sigue sin aplicar y :3000 no se reinició. Sin cambio en Tunnel, OAuth, credenciales ni DB diaria.

**Decisión añadida 2026-11-26 — PED-COMBO-KDS-STOCK-01:** componente no disponible pausa todas las estaciones de ese combo; el mesero pregunta al cliente. La sustitución exige comunicar el nuevo total y aceptación explícita; la diferencia se cobra/devuelve por Caja. Si rechaza, se cancela solo ese combo por Caja y siguen las demás líneas; propina separada. No desactivar globalmente el producto principal por falta de un componente. La implementación sigue pendiente; `pago_pedido_items` no guarda importes por línea, así que no se permite prorratear pagos por suposición. Sustitución legacy sin precio histórico fiable debe bloquearse.

**Avance PED-COMBO-KDS-STOCK-01 en fuente (26-nov-2026):** snapshots nuevos guardan precio unitario y cocina por componente; bebidas toman la cocina del producto espejo y toppings heredan la del plato al que están asociados. Migration `097_pedido_combo_kds_tareas.sql` agrega tareas y bitácora de decisiones; alta y agregado insertan una tarea por componente dentro de la transacción. Build Nest + 3 suites/18 pruebas focales; formulario admin de toppings permite seleccionar platos por categoría y servidor valida/persiste asociaciones. Flutter menu admin 16/16 + analyzer limpio. Multi-cocina sigue bloqueada y KDS aún no lista/muta tareas; faltan asociación de topping por componente combo, inventario/merma por tarea, decisión/Caja y QA aislada. 097 sin aplicar; no se migró DB diaria ni reinició :3000. Tunnel y salud local/pública 200.

**Corrección y avance de catálogo (26-nov-2026):** topping no tiene cocina propia ni se vende solo; se asocia a uno o varios platos mediante `producto_toppings`, y la preparación sigue la cocina del plato. El formulario de alta permite seleccionar varios productos con filtro por categoría; el backend valida sede, categoría activa y excluye bebidas, y persiste en una transacción. Menu Cliente ya filtra opciones por asociación. Pasabocas sí son vendibles solos y usarán la cocina asignada al producto en Catálogo; no hay todavía tipo/categoría específica. Bebidas de combos usan la cocina de su producto espejo y fallback a cocina principal. Validación actual: build Nest, 3 suites/18 pruebas focales; Flutter menu admin 16/16 + analyzer limpio. Salud local/pública 200, Tunnel activo. Sin reinicio de API o migración DB diaria; 097 sigue sin aplicar.

**PED-KITCHEN-POSTCOMMIT-01 (🟡 corregido en fuente; severidad media, 2026-11-26):** después de confirmar la transacción, la notificación de cocinas consultaba tickets y luego encolaba impresión desde una promesa no esperada por el creador. Si fallaba la primera consulta, no se intentaba crear el job de impresión y el rechazo podía quedar sin manejar. Ahora el fallo de consulta se registra, la impresión se intenta de todas formas y el fallo de publicación realtime se captura por cocina. La prueba focalizada cubre consulta fallida + intento de impresión y rechazo realtime + continuidad de impresión. Nest pedidos+impresión: 20 suites/68 pruebas; `npm run build` exit 0. Flutter POS: 20/20 y analyzer sin incidencias. API local y pública `/api/v1/salud` devolvieron 200; `:3000` continúa con PID 7584 y no se reinició, por lo que esto no acredita que el nuevo dist esté activo. Falta validar con impresora/agente real.

**PED-QUOTE-RACE-01 (🟡 corregido en Flutter; severidad media, 2026-11-26):** Checkout puede emitir varias solicitudes `POST /pedidos/estimar` cuando cambia carrito/tipo/promoción. Como las respuestas de red pueden llegar desordenadas, una respuesta anterior podía sobrescribir el total más reciente. Se añadió una revisión monotónica y solo se aplican resultado/error de la última solicitud vigente. La trazabilidad confirma que `PedidosCrearService` obtiene producto, combo, toppings y bebidas por `sucursal_id` y calcula subtotal, promoción, domicilio e impuestos desde Nest; los campos `precio` que envía Flutter no son fuente de precio. Pruebas: `flutter test --no-pub test/checkout_screen_responsive_test.dart` (1/1; 320/390/820/1440 px) y `dart analyze lib/features/pedidos/presentation/checkout_screen.dart` (sin issues). Pendiente verificar UX de cambio del catálogo entre cotización y envío, además de la suite autenticada de creación.

**POS-TOTAL-DRIFT-01 (🟡 corregido en fuente; severidad media, 2026-11-26):** altas staff cobradas de `para_llevar` requieren `total_esperado`; Nest compara el total autoritativo dentro de la transacción y devuelve `409 TOTAL_PEDIDO_CAMBIO` antes de crear pedido/pagos/Caja si difiere más de un centavo. El POS conserva carrito y forma de pago, refresca el total y exige nueva confirmación. La cotización se excluye de la huella idempotente para recuperar un pedido ya creado cuando se perdió la respuesta. Backend DTO + comparación + huella + precondición: 15 pruebas focales y build OK; Flutter POS 21/21 y repositorio+POS 27/27; analyzer limpio, incluidos envío del campo, conflicto y segundo intento. Falta E2E con cambio aislado de precio en BD QA. El API exige publicar una versión actualizada del panel junto al backend para cobros de mostrador. :3000 no reiniciada; Cloudflare/OAuth no tocados.

**PED-ITEM-PAY-ALLOC-01 (🟡 protecciones en fuente; severidad media, 2026-11-26):** reemplazo validaba cobro por línea, pero edición/eliminación directa solo protegía el saldo agregado del pedido. La eliminación borraba `pago_pedido_items`; una línea con pago asignado podía retirarse mientras otras líneas mantenían el total por encima del abono. Ahora borrar o cambiar cantidad/toppings consulta `estado_cobro` y asociación en la misma transacción, y devuelve `ITEM_REQUIERE_AJUSTE_COBRO` antes de mutar si ya hay cobro. Edición de notas se permite; mandar el mismo set de toppings no borra el snapshot de precio ni vuelve a tomar su precio vigente. La protección de consistencia de inventario y el avance de ledger por línea se separan en `PED-ITEM-STOCK-LEDGER-01`. Evidencia de pago: cobertura previa del módulo Pedidos 21 suites/76 pruebas; E2E pago por línea pendiente.

**PED-ITEM-STOCK-LEDGER-01 (🟡 parcial en fuente; severidad alta, 2026-11-26):** el alta normal descontaba inventario antes de insertar líneas y `movimientos_ingrediente` no conservaba una referencia a `pedido_item_id`. Migration `096_pedido_item_stock_ledger.sql` agrega FK nullable diferida con `ON DELETE SET NULL`, `stock_snapshot_version` y el tipo `devolucion`; altas nuevas y de ítems agregados preasignan UUIDs estables, movimientos nuevos de venta/merma reciben la referencia y aprobaciones QR reconstruyen IDs existentes. La cancelación ahora repone desde movimientos reales el saldo neto vendido por ingrediente, resta las devoluciones y ajustes históricos de devolución explícitos, y registra una compensación `devolucion`; repetir la rutina no devuelve el mismo saldo dos veces. Analítica de inventario informa el stock devuelto aparte, valorizado al costo actual, y no lo resta del consumo histórico. Verificación unitaria: **23 suites/85 pruebas** de analítica, pedidos e inventario; `npm run build` exit 0; test Flutter de carga progresiva de analítica 8/8 y analyzer sin incidencias. E2E: **12 suites/54 pruebas** pasaron contra API :3001 y clon QA con migraciones 095/096; incluye cancelación idempotente, ledger por línea, finanzas/Caja, mesa, cocina y domiciliarios. El clon QA se preparó con el fixture oficial de stock; API pública :3000 y DB diaria no se modificaron. Los movimientos históricos carecen de línea/receta fiable y no se rellenan por inferencia. Los guards de cambio de toppings y reducción individual siguen activos porque falta snapshot de consumo por línea y conciliación proporcional por ingrediente. Pendiente validar cambios de receta y combos de varias unidades.

**PED-COMBO-KDS-STOCK-01 (🟣 abierto; severidad alta, 2026-11-26):** se agregó `componentes_snapshot` con migration `095_combo_component_snapshot.sql`; altas nuevas tanto de pedido como de agregado guardan tipo, ID, nombre, cantidad y costo de cada componente base y extra. Ambos flujos agregan bebidas/toppings base y seleccionados al consumo de stock y al COGS; las solicitudes pendientes sin descuento usan costo snapshot como respaldo. La reconstrucción de líneas para revalidar/descontar pedidos pendientes usa componentes guardados; KDS/impresión muestran componentes del combo sin crear una segunda línea facturable. Pruebas focales backend: inventario snapshot + consulta KDS + guardia de cocina única (25 suites/78 pruebas), `npm run build` OK; `kds_screen_test.dart` 18/18 y analyzer KDS limpio. **No aplicar aún a la BD diaria:** migración no ejecutada, API :3000 no reiniciada y pruebas no E2E específicas de combo multiestación. La inspección confirmó que KDS filtra la única línea facturable por `pedido_items.cocina_id`, y usa su único `estado_cocina`; `componentes_snapshot` no conserva `cocina_id` ni hay tareas por estación. El catálogo bloquea nuevos combos multi-cocina y Nest bloquea cotizar/vender combos legados incompatibles. Hallazgo adicional: al marcar la línea como `no_disponible`, `CocinasService` llama `registrarMermaLineaProducto` solo con `pedido_items.producto_id` (producto principal), cuya receta se expande; no registra por ese camino la merma del resto de componentes del snapshot. También marca dicho producto principal `disponible=false` en toda la sucursal. Esto puede atribuir incompletamente desperdicio y afectar el producto individual aunque solo faltara una parte del combo. Definir si `no_disponible` significa combo completo o tarea/componente, y si se desactiva el componente, el combo o el producto principal. Para completar: snapshot de estación por componente, tareas de cocina separadas subordinadas a la única línea cobrable y estados agregados sin duplicar cobros, inventario o comandas. Resolver política funcional (sustitución aprobada, combo no disponible/cancelación y ajuste/reembolso por Caja). La devolución al cancelar usa el ledger tipo venta, no reexpande recetas actuales. Sin datos demo mutados.


**DOMI-ADDR-DISPATCH-01 (🟡 corregido en fuente, runtime pendiente; severidad media, 2026-11-25):** el DTO compartido aceptaba la dirección literal «Por confirmar» y la validación central usada por asignación manual, despacho automático y ofertas independientes no comprobaba la dirección. Ahora creación (Nest y POS) rechaza marcadores pendientes; despacho exige dirección no vacía/no marcador y sigue permitiendo direcciones escritas sin coordenadas. Evidencia histórica solo lectura: `AUDITORIA_DOMICILIOS.md`; pruebas domiciliarios 7 suites/27, DTO 17/17, POS 20/20 y `npm run build` OK. No se alteraron pedidos históricos ni se reinició API :3000, cuyo proceso sigue con dist anterior.

**CAJ-CXC-DOMI-ROUTE-01 (🟡 corregido en fuente, runtime pendiente; severidad media, 2026-11-25):** la lista general de Caja ofrecía «Cobrar» para CxC de domiciliarios. La ruta genérica marcaba la cuenta como pagada y creaba movimiento de Caja, sin insertar `pagos_pedido` ni actualizar `pedidos.monto_pagado`; el flujo especializado de Domiciliarios sí hace las tres cosas. Ahora el listado identifica esas cuentas, la UI dirige a liquidarlas desde Domiciliarios y el API genérico las rechaza. Jest Caja 7/7 suites, 16/16 pruebas; build y Flutter Caja 19/19 + analyzer limpio. Consulta `READ ONLY` de `foody_diseno_qa`: 0 CxC de domiciliarios en la instantánea; por tanto se confirma ruta peligrosa en código, pero no uso histórico en esa base. Sin mutaciones ni reinicio del :3000.

**DOMI-SETTLEMENT-VS-PAID-01 (🟡 decisión confirmada, severidad media, 26-nov-2026):** Javier confirmó separar el pago ya hecho por el cliente al domiciliario de la rendición de efectivo pendiente en Caja. En `pendiente_liquidacion`, la entrega reconocerá pagado al cliente y conservará CxC del courier; liquidar registrará únicamente la entrada de Caja y cierre de CxC, sin duplicar `pagos_pedido`. El domicilio seguirá fuera del ingreso de sede cuando `domicilio_ingresa_a_caja=false`. La fuente actual aún mezcla estados/importes; implementación y E2E de pedidos, Analítica y Caja pendientes en clon QA. No reinterpretar históricos ni tocar DB diaria. Detalle: `AUDITORIA_DOMICILIOS.md` y handoff.

**WOMPI-WEBHOOK-REFERENCE-01 (🟡 corregido en fuente, runtime pendiente, 2026-11-25):** los webhooks de renovaciones creadas con `POST /transactions` podían no asociarse al pago local: se buscaba por `payment_link_id`/`sku`, pero el cobro recurrente se crea con `reference`. Ahora el fallback resuelve `pagos_suscripcion.referencia_interna` solo entre pagos pendientes, conservando primero las rutas existentes de checkout. Prueba unitaria de webhook aprobado 1/1 y typecheck Nest sin emisión; no se hicieron llamadas al proveedor ni escrituras. Falta E2E con evento realista en clon QA y activar/verificar runtime bajo reinicio coordinado. Wompi documenta la referencia única en [Transacciones](https://docs.wompi.co/docs/colombia/transacciones/) y el flujo de eventos en [Eventos](https://docs.wompi.co/docs/colombia/eventos/).

**WOMPI-RENEWAL-CLAIM-01 (🟡 corregido en fuente, runtime pendiente, 2026-11-25):** las renovaciones manuales y el cron ahora serializan por fila de suscripción en una transacción; antes de crear un cobro revisan pagos pendientes/aprobados recientes y reservan la fuente solo si el último intento tiene más de 20 h. Tres unitarias cubren pago ya pendiente, intento reciente y reserva válida; 4/4 total junto a la prueba de webhook, typecheck Nest y typecheck de specs pasan. La pantalla ahora explica los motivos por los que se evita un cobro duplicado; Flutter de Plan y pagos 6/6 y analyzer limpio. No hubo llamadas a Wompi ni writes DB. Restan E2E aislada y runtime. El timeout seguro de los `POST /transactions` sigue abierto: una respuesta perdida aún necesita estado ambiguo duradero/reconciliación antes de expirar o reintentar.

**E2E-SUCURSAL-READ-01 (✅ cerrado, 2026-11-26):** en API QA :3001/clon, gerente sin permiso corporativo lista su sede (200) y recibe 403 al listar Pedidos y Cocinas de la sede hermana. E2E read-only 2/2; API :3000 y datos diarios intactos. La prueba valida estas lecturas, no todas las operaciones cross-sucursal.

**REP-ANALYTICS-PLAN-LINK-01 (✅ publicado, 2026-11-25):** el acceso a Análisis desde Reportes llevaba a la pantalla de bloqueo correctamente, pero el enlace no avisaba que el módulo requiere Pro. El CTA ahora muestra «Análisis · Pro» cuando `analitica` no está incluido en los módulos de sesión y «Análisis» cuando sí está disponible. No cambia permisos, navegación ni backend; Flutter reportes 11/11 y analyzer focalizado limpio. Rebuild Cliente/Equipo con publicador transaccional; local y Tunnel: Equipo, `/admin/login`, Cliente, FCM y salud API HTTP 200. El `main.dart.js` público de Equipo coincide por SHA-256 `40c011be143f821b8689498c18d823af922c0c24079b68be0b4b92b13b7645f6`. Cloudflare PID 8940 se mantuvo; no se tocó OAuth ni datos. Nest PID 7584 sigue con runtime anterior, no afecta este cambio Flutter.

**DOMI-MANUAL-PAY-LEDGER-01 (🟡 corrección en fuente, 2026-11-25):** cerrar manualmente un domicilio desde Admin registraba en Caja el importe de producto pendiente y actualizaba `pedidos.monto_pagado`, pero no insertaba el cobro equivalente en `pagos_pedido`; por eso el detalle mostraba un resumen de pagos vacío/incompleto. Ahora inserta la línea por el mismo `montoCaja` y método usado en Caja, dentro de la transacción, con propina cero; el E2E exige resumen y Caja coherentes. `npm run build` pasó (exit 0), 2 suites/6 pruebas unitarias cercanas aprobaron y `domicilio.e2e-spec.ts` pasó 7/7 con Nest QA :3001 + clon desechable. Clon y API QA retirados; verificación final: `:3001` sin listener, `:3000` conserva PID 7584. No se tocaron datos reales ni Tunnel. DOMI-OFF-CAJA-TRACKING-01 sigue siendo decisión contable separada; el dist corregido requiere activación posterior coordinada.

**E2E-QA-ROLE-FIXTURE-01 (✅ estabilizado, 2026-11-25):** el E2E RBAC usa ahora `cajero.sololectura.test@foody.demo`, creado exclusivamente en el clon desechable con override `ver_caja`; `cajero.test` queda con la plantilla operativa. `verificar-e2e-jest.ps1` lee de forma idempotente los grants `roles_permisos` de todas las migraciones, exige `FOODY_QA_DATABASE=foody_diseno_qa_codex_*` y prepara los dos perfiles solo en el clon. La suite completa pasó **10/10 suites, 51/51 pruebas**. Evidencia final de no impacto: el clon fue eliminado, `:3001` detenido, `:3000` PID 7584 intacto; consulta read-only a QA fuente da 1.274 pedidos, 76 grants antes de preparar el clon y 0 usuarios read-only de prueba. Rectificación de diagnóstico anterior: no eran 2 grants totales; faltaban los cuatro grants de la migración 094. No se alteró QA fuente ni datos comerciales.

**COST-RECIPE-STRUCT-01 (🟡 estructura aplicada en fuente; validación autenticada pendiente, 2026-11-25):** Costos y márgenes adopta la referencia del propietario: producto destacado, secuencia de cinco pasos, grupos plegables, resumen lateral en escritorio y apilado en móvil. En modo edición, Ingredientes queda abierto por defecto y Preparaciones/Empaques se pliegan en anchos compactos siguiendo el patrón de la referencia; escritorio conserva los tres grupos abiertos y el usuario puede alternarlos. Subtotales de edición son orientativos; costo/margen confirmados siguen viniendo del backend. Búsqueda y recuperación de lista mejoradas. **COST-RECIPE-LOAD-FAIL-01:** error al leer receta muestra reintento y bloquea guardar hasta respuesta válida; respuesta vacía confirmada sí inicia creación. **COST-RECIPE-EDIT-RESP-01:** selector, cantidad/unidad, resumen de costo y texto de stock ajustados para móviles. La prueba integrada encontró y corrigió además el overflow en la fila larga «Preparación [producto]» dentro del resumen de acompañamientos. El indicador activo de cinco pasos ahora sigue el escenario visible (ingredientes, empaques para llevar o incluidos), sin inventar progreso completado. Edición→guardado a través del `InventarioRepository` y serialización Dio probado con adaptador HTTP falso en 320/390/820/1440; 17/17 combinando flujo, acordeones, guardado, búsqueda, error y detalle integrado; analyzer limpio. El detalle propaga ahora `InventarioRepository` a la receta y `CatalogoAdminRepository` a incluidos. No se llamó a Nest ni se escribió en DB. Pendiente: producto real autenticado y persistencia/recálculo desde API; sin cambios de DB, pagos ni túnel.

**ANA-PNL-COMP-FILTER-01 (✅ corregido en fuente, 2026-11-25):** el COGS del período anterior en Rentabilidad se consultaba solo por sede/fecha/estado e ignoraba los filtros activos, aunque las ventas y el COGS actual sí se filtraban. Ahora usa el mismo constructor de rango/filtros y las mismas restricciones por línea. Prueba focalizada 3/3 y build Nest correcto. El proceso :3000 no se reinició; fuente corregida aún no verificada en runtime.

**ANA-PNL-EXP-SCOPE-01 (🟡 hallazgo documentado, 2026-11-25):** Rentabilidad aplica filtros de pedidos a ventas y COGS, pero resta gastos operativos completos de la sede/período; no hay regla de prorrateo de gastos entre pedidos/productos. La utilidad neta bajo filtros de pedido no equivale a utilidad neta atribuida al segmento. La UI ahora declara que los gastos no se prorratean. Decisión contable pendiente: mantener gastos globales y limitar interpretación segmentada a utilidad bruta, o definir y auditar un método de distribución antes de cambiar fórmula.

**Estado operativo 2026-11-25 (revalidado tras build):** puertos :3000/:8080/:8081 escuchan; Equipo y Cliente local/Tunnel devuelven HTTP 200; `GET /api/v1/salud` local y público da 200. Cloudflare PID 8940 activo. Nest PID 7584 arrancó 13:50:31 y `foody_backend/dist/main.js` se recompiló 18:53:56: el runtime sigue anterior al artefacto. No se reinició ni publicó nada. Tunnel, OAuth, credenciales y datos comerciales intactos. Activación del build y smoke autenticado siguen pendientes.

**API-RUNTIME-FRESHNESS-02 (P2, 🟣 abierto):** runtime stale confirmado con StartTime del PID 7584 (13:50:31) anterior a `dist/main.js` (18:53:56); salud local/pública responde HTTP 200, pero no demuestra qué código está cargado. `scripts/iniciar-backend-wsl.bat` probado con `FOODY_NOPAUSE=1`: detecta build posterior, conserva el proceso y termina con exit 3, sin crear segunda instancia. La detención controlada solicitada desde Codex fue rechazada por política de seguridad; no se intentó eludirla. Próximo paso: cierre normal desde la ventana de backend, ejecutar de nuevo el iniciador y verificar rutas autenticadas por Tunnel.

**PED-RESP-STATUS-01 (🟡 verificado):** la tira de estados de Pedidos que parece cortada en 502 px sí es desplazable: `PedidosKanbanWidget` envuelve `OperacionStatChip` en `SingleChildScrollView` horizontal con degradado indicativo; `pedidos_kanban_widget_test.dart` selecciona «Cobro / Ruta» tras `ensureVisible`. Suite focalizada 12/12 (320, 390, 820 y 1440 px); no se reprodujo pérdida de acceso ni overflow. Sigue pendiente revisar cues con lector de pantalla dentro de la auditoría general responsive.

**DOMI-PAY-DISPLAY-01 (fuente corregida, runtime pendiente):** apps de domiciliario de planta e independiente reciben `pagos_resumen` de `pagos_pedido`, agrupado por método y scoped por pedido+sucursal; sus tarjetas muestran método e importe por registro, y el historial de planta también presenta el desglose. Hay fallback al `metodo_pago` legacy sin registros. Propina excluida; sin cambios a saldo, cobro ni Caja. Nest focalizado 3/3, build OK y Flutter 2/2. SQL ejecutado con transacción read-only en `foody_diseno_qa`: 44/44 entregas de planta tienen detalle; en la instantánea QA, 63 pedidos tienen métodos mixtos y los 63 difieren del escalar heredado. No extrapolar esa prevalencia a producción. API :3000 sigue con dist anterior; falta activar y verificar autenticado.

**EXT-TIMEOUT-01 / DB-POOL-ACQUIRE-TIMEOUT-01:** Photon cancela a 5 s (504), upstream da 502, sin retries y cachea solo éxito. `pg.Pool` limita conexión/adquisición a 5 s por default, configurable; no limita sentencias ya iniciadas ni instrumenta cola. Nest específico geografía 3/3 + pool 2/2; suite 63/63 y 175/175 total, build OK. **WOMPI-EXT-TIMEOUT-01 (abierto):** cuatro llamadas Wompi sin timeout. La renovación ahora serializa cron/manual y bloquea intentos si hay pago reciente pendiente/aprobado; aún no se abortan cobros sin estado ambiguo persistente y conciliación de `reference`. Wompi documenta reference única y consulta por ID de transacción, pero no se presume idempotencia en `POST /v1/transactions` estándar.

**CAJA-LOAD-80-01:** Caja solicita como máximo 2 páginas para mostrar sus 80 movimientos recientes (antes podía pedir 50 en serie y luego descartar casi todo); el saldo de cierre sigue siendo calculado por backend. Repositorio + pantalla Caja: 18/18; analyzer limpio.

**DOMI-PAY-LEGACY-METHOD-01 / DOMI-FIADO-COVERAGE-01 (2026-11-25):** E2E real 1/1 en API QA :3001 + clon temporal. Flujo de pedido $13.000 (producto $8.000 + domicilio $5.000 fuera de Caja), abono de $2.000 transferencia, CxC de $6.000 y liquidación $6.000 efectivo; `metodo_pago=transferencia`, `pagos_resumen` conserva $2.000/$6.000, CxC `pagada`; segundo POST rechazado 400. SQL independiente confirma `monto_pagado=13.000`, pagos/Caja solo por $8.000; el domicilio externo $5.000 no aparece en `pagos_pedido`. La ruta `pendiente_liquidacion` no captura el medio recibido por ese domicilio. Se registra DOMI-OFF-CAJA-TRACKING-01 como decisión contable abierta, sin cambiar importes. `permite_fiado_domiciliario` restaurado a false; API QA y clon retirados, QA fuente sin pedido sintético. API Tunnel :3000 intacto PID 7584; no se confirma con dist actual.

**REGRESIÓN NEST (2026-11-25, 17:52):** suite completa revalidada tras DOMI-PAY-LEGACY-METHOD-01: 63/63 suites y 176/176 pruebas; build actualizado 17:46:22. El PID :3000 continúa iniciado 13:50:31.

**REGRESIÓN FLUTTER (2026-11-25, auditoría continua):** `flutter test --no-pub` pasó 297 pruebas; 5 pruebas E2E quedaron omitidas porque requieren activación explícita y BD aislada. `flutter analyze --no-pub` no reportó errores, pero terminó con 10 infos existentes: APIs web `dart:html` obsoletas, 3 advertencias `BuildContext` async en registro OAuth y un `DropdownButtonFormField.value` obsoleto. No se modificó OAuth; revisar esos avisos por separado.

**KDS-READY-AGE-01:** antigüedad de tickets listos publicada y verificada visualmente en Chrome autenticado; seis tickets >30 días observados sin clasificación y sin cambios. Registrar origen antes de depurarlos.

**DASH-PARALLEL-01:** Inicio carga resumen, mesas, alertas e inventario en paralelo; widget test 10/10 y analyzer focalizado limpio. Pedidos solo es fallback si el resumen no trae domicilios tardíos.

**PERF-CORS-PREFLIGHT-01:** Chrome KDS por Tunnel, captura warm única: DOMContentLoaded 634 ms, Load 996 ms, 71 solicitudes acumuladas, 15,5 kB transferidos/16,8 MB de recursos (mayoría caché). OPTIONS público carecía de `Access-Control-Max-Age`; QA con Nest compilado verificó 300 s y preservación de origen/credenciales. API pública :3000 aún sin header porque no fue reiniciada. Allowlist/OAuth intactos; falta verificación pública tras arranque normal. Muestra única no es p50/p95.

**FIN-TIP-MIXED-ALLOC-01 — decisión aprobada (26-nov-2026):** la propina no integra el monto obligatorio y se registra con método propio si se recibe; no se prorratea entre los métodos del consumo y no se conserva cuando el pago se difiere. Implementación y conciliación por turno aún pendientes; no migrar/reclasificar históricos.

**ORD-PAY-SUMMARY-01:** detalle administrativo de pedido expone `pagos_resumen` agrupado desde `pagos_pedido` por `(pedido_id, sucursal_id)` y `propina_recibida` aparte. API real verificada mediante E2E autenticado en Nest `:3001` + clon `foody_diseno_qa_codex_20261125_pay_summary`: abono $2.500 efectivo + $1.500 tarjeta; cuenta total $8.000; al completar por transferencia se conservan tres métodos y propina $1.400 separada. Unit/build y Flutter sheet responsive/analyzer pasan. API QA detenida y clon retirado. Falta click-through navegador autenticado y activar el dist de trabajo: el proceso actual :3000 (PID 7584, 13:50:31) es anterior al `dist/main.js` (16:27:45). API local/pública y web Cliente/Equipo siguen 200; cloudflared PID 8940 activo. Intento de reinicio controlado rechazado por control de seguridad, sin modificar el proceso.

**FIN-PAY-MULTITICKET-01:** `cobrarCuentaMesa` antes guardaba todos los medios de una cuenta con varios tickets bajo el primer pedido, mientras distribuía ventas de Caja por ticket. Ahora distribuye cada medio de pago y vincula los ítems de split por pedido. `GET /pedidos/mesa/:id` identifica con `numero_pedido` cada abono para que la UI no confunda filas separadas; el JOIN se limita a sucursal. Suite E2E Caja 10/10 en clon desechable y mesa sheet 9/9 responsive; analyzer limpio, clon/API QA retirados. `:3000` no reiniciado.

**FIN-PAY-RECONCILIATION-01:** lectura QA read-only trazó FDY-2026-1227 a `jest-mesa-varios-a`: los $8.000 en efectivo y $8.000 en tarjeta quedaron asociados al primer ticket aunque Caja repartió $8.000 a cada ticket de la mesa. Es un defecto reproducido en el código y corregido en FIN-PAY-MULTITICKET-01; filas QA históricas intactas. FDY-2026-1226 (`jest-caja-reversa-mixta`) conserva pagos históricos de $3.000+$2.000 y Caja registra devoluciones equivalentes de $3.000+$2.000: reversa correcta; el resumen del pedido muestra pagos brutos, no neto de devoluciones, que debe consultarse en Caja. La reconciliación integral de pedidos cancelados/domicilios sigue pendiente.

**DOMI-FIADO-COVERAGE-01:** además de los dos modos de domicilio en Caja ya probados, el ciclo de abono previo y liquidación pasó E2E 1/1 en clon desechable. El nuevo caso registra transferencia $2.000 + efectivo $6.000 a Caja y deja el domicilio de $5.000 fuera; CxC pagada, método escalar `transferencia`, replay HTTP 400. SQL mostró `monto_pagado=13.000` mientras pagos/Caja suman $8.000: la diferencia es el cargo retenido fuera de Caja, cuyo método no captura `pendiente_liquidacion`. DOMI-OFF-CAJA-TRACKING-01 queda abierto hasta decidir cómo representarlo sin mezclarlo con el recaudo de sucursal. Clon eliminado y QA fuente intacta; :3001 detenido.

**REGRESIÓN 2026-11-25 (revalidada 16:53):** Nest `npm test -- --runInBand` 61 suites/169 pruebas aprobadas; `npm run build` exit 0 y actualizó `dist/main.js` 16:52:42. Flutter `flutter test --no-pub`: 295 aprobadas/5 omitidas, 0 fallidas; suite `pedidos_kanban_widget_test.dart` 12/12. E2E Caja 10/10 y domicilio 7/7 en clones desechables (ejecuciones QA ya documentadas). El API vivo PID 7584 continúa anterior al artefacto aunque local/Tunnel den 200; no se reinició.

**AR-17 / NAV-PED-MOVEMENT-01 (2026-11-24):** el botón «Ir a caja» desde detalle de pedido ahora conserva `pedido_id` en la navegación y Caja presenta sus movimientos aun cuando el turno relacionado ya cerró. Nest expone `GET /caja/pedidos/:pedido_id/movimientos`, protegido por `ver_caja` y el scope operativo de sucursal; pedido/movimientos se filtran por sucursal, y un pedido fuera del scope responde como no encontrado. Índice parcial por `(sucursal_id, pedido_id, created_at DESC)` añadido en migración 093 y aplicado únicamente a `foody_diseno_qa`. Unitarias Nest 49 suites/125 pruebas y build OK; Flutter global 269 aprobadas/5 omitidas/0 fallidas, tests focalizados y analyzer limpios; candidato Web Equipo Release compilado sin publicar. El caso E2E de turno cerrado quedó escrito pero no ejecutado: :3001 no está escuchando. GET sin sesión al endpoint nuevo devolvió 404 tanto local como por API pública; Nest :3000 (PID 19492, inició 19:30) precede a `dist/main.js` (compilado 23:37), confirmando que el runtime no contiene el endpoint. La salud base sigue 200 y Cloudflare activo. No se crean ni modifican pagos. **Pendiente activar el nuevo build Nest en :3000 y verificar la ruta autenticada en Tunnel;** no se reinició API ni se alteraron OAuth, credenciales o movimientos reales.

**KITCHEN-PARALLEL-LOAD-01 (2026-11-24):** Cocinas esperaba primero el listado de estaciones y luego el de impresoras, aunque ambos GET dependen solo de la sede. La carga inicial ahora los ejecuta concurrentemente. Prueba con `Completer` confirma que ambos requests inician antes de recibir respuesta; `cocinas_admin_screen_test.dart` 5/5 cubre 320/390/820/1440 px y analyzer focalizado limpio. Equipo Release reconstruido/copíado en el directorio servido; hash candidato/local igual (`5DDA82…D6B795A51`), Equipo y JS del Tunnel HTTP 200, el bundle público conserva la acción explícita de precios y Cloudflare PID 8940 activo. Nest y reglas de negocio no cambiaron.

**RBAC-UI-CAJA-01 (2026-11-24):** el detalle ofrece “Ir a caja” solo con `ver_caja`; el resto de AR-17 quedó implementado y verificado en fuente en la entrada superior. La validación pública autenticada está pendiente de activación controlada de Nest.

**CAT-PRICE-ACTION-01 (2026-11-24):** la acción de precio en la tabla podía quedar fuera del viewport horizontal en escritorio. Se añadió un botón de edición explícito junto al nombre del producto, preservando el toque de fila/tarjeta y el guardado existente. Menú 14/14, analyzer focalizado limpio; Flutter global actualizado 261 aprobadas/5 omitidas/0 fallidas. Equipo Release candidato compilado y copiado a `build/web_equipo`; local y Tunnel 200, el bundle público contiene “Editar precios de” y el SHA local/candidato coincide (`531FCF…58FCEF35`). No se sincronizó configuración ni se tocó backend, OAuth o datos.

**QA-FULL-RECHECK-01 (2026-11-24):** reverificación global del código actual: `npm test -- --runInBand` 48/48 suites y 123/123 pruebas; `npm run build` OK. `flutter test --no-pub`: 265 aprobadas, 5 omitidas, 0 fallidas. `flutter analyze --no-pub` terminó con código 1 por 25 issues informativas (sin errores ni warnings); las vistas modificadas pasan análisis focalizado. Seis rutas locales/públicas de Cliente, Equipo y `/salud` devolvieron HTTP 200; `cloudflared` PID 8940 está activo. Nest PID 19492 arrancó 19:30 COT y el build actual se compiló después: HTTP 200 confirma disponibilidad, no que el proceso haya cargado el `dist` nuevo. No se reinició Nest ni se tocó OAuth, `.env` o datos comerciales. Pendiente: activar/verificar runtime backend y aceptación visual autenticada; las 5 pruebas omitidas no se contaron como aprobadas.

**CAT-AVAILABILITY-UX-01 (2026-11-24):** la disponibilidad de producto en Menú llamaba PATCH sin progreso ni captura de error. Si la red fallaba, no había confirmación visible ni reintento. Ahora tabla y tarjeta comparten un switch accesible, inhabilitado con indicador durante la operación; la fila permanece montada mientras refresca y el fallo muestra mensaje con “Reintentar”. No cambia endpoint ni regla del servidor. Widget Menú 13/13, analyzer focalizado limpio, Equipo Release publicado; JS público coincide por SHA-256 (`39c976…987735665`), HTML local/Tunnel 200, `.env` intacto y `cloudflared` PID 8940 activo.

**UI-USR-DEACTIVATE-01 (2026-11-24):** el toggle de Usuarios desactivaba de inmediato; el backend marca `activo=false` y Auth rechaza iniciar sesión para cuentas inactivas. Ahora desactivar pide confirmación contextual (quién pierde acceso y cómo reactivarlo); activar sigue inmediato. No cambian permisos ni endpoint. Widget tests móvil/escritorio, cancelación y confirmación: 6/6; analyzer focalizado limpio. Equipo Release compilado y publicado; HTML local/Tunnel 200 y JS público SHA-256 coincide con build (`885d5a…b759ffa`). Hash `.env` sin cambio; `cloudflared` PID 8940 activo.

**UI-INV-SELECTOR-01 (2026-11-24):** el roadmap describía el selector compacto de Inventario como pendiente, pero ya existe: móvil elige entre cinco áreas desde menú; escritorio conserva tabs. `flutter test test/inventario_seccion_selector_test.dart`: 6/6 en 320/390 claro/oscuro y 820/1440; F6-08 sigue parcial por propuesta de sub-nav en escritorio y QA visual autenticada pendientes. Sin cambios de código en esta revisión.

**PED-WAITER-PAYMENT-01 (2026-11-24):** corregido en Flutter: el formulario de mesero ocultaba los controles de cobro, pero enviaba `efectivo` por el valor inicial del POS; ahora envía `pendiente`. Prueba POS 18/18 y analyzer focalizado limpios. Cliente/Equipo Release reconstruidos y servidos; SHA-256 de `main.dart.js` coincide entre candidatos y carpetas activas. Seis URLs local/Tunnel (Cliente, Equipo, API salud) HTTP 200; `cloudflared` PID 8940 activo. Hash de `foody_backend/.env` sin cambio. POS cajero conserva su comportamiento. Aceptación visual autenticada sigue pendiente.

**Runtime Nest — deriva detectada (2026-11-24, comprobada 22:22 COT):** PID `19492` (`node -r dotenv/config dist/main.js`) arrancó a las 19:30; `foody_backend/dist/main.js` se compiló a las 21:22:34. Por tanto, el API HTTP 200 local/Tunnel no prueba que el proceso cargara el build actual. El intento de reinicio controlado fue rechazado por la política de ejecución antes de ejecutar comandos; no se detuvo ningún proceso ni se modificó `.env`. Cloudflare PID `8940` continúa activo. Pendiente activar Nest con el mecanismo de arranque permitido y volver a verificar salud/flujo sin escribir datos comerciales.

**COC-CANCEL-NODISP-MERMA-01 / QA-PRINT-BYPASS-01 (2026-11-24):** E2E de cancelación de pedido con línea no disponible pasó 1/1 en clon PostgreSQL QA recién restaurado. La prueba detectó que el drenaje de impresiones podía saltarse el modo sin efectos; ahora tanto el ping como el procesamiento de cola se bloquean cuando `FOODY_QA_SIN_EFECTOS=1`. Unitarias de impresión 2/2, build Nest y formato OK. Logs confirmaron bloqueo sin intento externo. QA :3001 y clon temporal detenidos/eliminados; API local y pública `/salud` 200 y `cloudflared` activo. La regla de merma para líneas aún pendientes sigue siendo decisión abierta; :3000 no se reinició.

**COC-DISPATCH-INCOMPLETE-01 (2026-11-24):** E2E 1/1 en clon PostgreSQL QA: pedido domicilio con ítem pendiente no pudo pasar a `listo`; asignación manual devolvió 400 y dispatch independiente devolvió `iniciado=false/PEDIDO_NO_LISTO`. Guard unitario de despacho 5/5. QA :3001 y clon detenidos/eliminados; salud local/Tunnel 200 y Cloudflare activo. El proceso :3000 sigue siendo anterior al build actual, por lo que la corrección de fuente aún no se considera activada en runtime.

**PED-EDIT-01 (2026-11-24):** E2E 4/4 en clon PostgreSQL QA: cambiar observaciones después de `listo` reabre Cocina; reducir cantidad, eliminar o reemplazar bajo el total ya abonado devuelve 409 y deja intactos total, saldo e ítems. Build no fue activado en :3000; el estado del runtime sigue documentado arriba.

**FIN-MIXED-REFUND-METHOD-01 (2026-11-24):** E2E 1/1 en clon QA confirmó que cancelar un pedido con abono mixto revierte efectivo y tarjeta en sus respectivos medios y mantiene conciliado el neto de caja. QA detenido/eliminado; local/Tunnel health 200 y `cloudflared` activo. El código probado no está activado en :3000.

**QA-FCM-BYPASS-01 (2026-11-24):** `NotificacionesService.procesarPendientes()` podía procesar/reintentar la cola en la misma petición aunque `FOODY_QA_SIN_EFECTOS=1`; FCM estaba desactivado, pero la prueba mutaba intentos. Ahora retorna antes de leer o escribir cola. Unitaria específica 1/1; Nest completo 48 suites/123 pruebas y build OK. E2E completa repetida con el guard nuevo: 8 suites/36 pruebas; logs mostraron impresora y FCM bloqueados en QA. Clon :3001 eliminado; salud local/Tunnel 200. El build sigue sin activarse en :3000.

**E2E suite completa — fixture (2026-11-24):** 8/8 suites y 36/36 pruebas pasaron con base QA clonada y stock demo restablecido. La primera pasada desde clon simple falló al agotarse la papa demo (stock 0), dejando claro que la suite requiere preparar inventario con `scripts/limpiar-demo-qa.ps1` o equivalente antes de correr; el original QA no se usó como destino de escritura. Clon temporal eliminado.

**Flutter UI regression (2026-11-24):** `flutter test --no-pub` global: 254 aprobadas, 5 omitidas, 0 fallidas. `flutter analyze --no-pub` no reportó errores ni advertencias; devolvió exit 1 por 25 issues informativas (deprecaciones/estilo y tres usos pendientes de `BuildContext` en el registro OAuth, que se preservó sin cambios). Se corrigieron ocho avisos async de Foody Control y edición de pedidos. No se hizo aceptación visual manual autenticada; CUA encontró dos ventanas Chrome con el mismo título y no seleccionó una ambiguamente.

**Web releases candidata — 2026-11-24:** Cliente y Equipo compilaron en release a `build/web_cliente_candidate` y `build/web_equipo_candidate`; JS de 6,57 MB en cada flavor. No se copiaron a las carpetas servidas ni se publicaron: el backend `:3000` todavía ejecuta el proceso anterior. Flutter mostró avisos no bloqueantes de compatibilidad WASM y ausencia de manifest CupertinoIcons; el código Foody no tiene referencias directas a esos iconos, falta inspección visual real.

**CLIENT-DOM-CONTACT-01 — resuelto en fuente (2026-11-24):** domicilio público exige teléfono no vacío con 7–15 dígitos; nombre sigue opcional y recoger/mesa/encargo no piden teléfono. La validación de checkout muestra error inline y Nest la vuelve a aplicar en DTO. Flutter 3/3, Nest DTO 8/8, QR E2E 4/4 en PostgreSQL QA aislada; la prueba confirma rechazo 400, aceptación del formato internacional, persistencia y nombre null. `dist` actualizado; el proceso `:3000` aún requiere activación (ver deriva arriba). OAuth y datos comerciales intactos.

**CLIENT-DEVICE-CAP-01 — mitigación aplicada (2026-11-24):** UUID público ya no basta para operar el historial invitado ni vincular Google. Cliente envía secreto aleatorio de 256 bits por `X-Foody-Device-Capability`; Nest conserva hash SHA-256 y compara en tiempo constante. Migración 092 aplicada en BD local + QA aislada; no se alteraron pedidos ni OAuth. Suites Nest 7/7, Flutter 2/2, analyzer focalizado limpio, build Nest OK; Web Cliente/Equipo y APK Cliente/Equipo Release reconstruidos (APK 93,1 MB c/u). CORS permite el header; rechazo probado 403 y flujo válido en QA. Riesgo residual: primer enrolamiento de device legacy, secreto Web expuesto ante XSS, sin recuperación si se pierde. Usuarios móviles deben instalar APK actualizado. Auditoría global abierta.

**PED-POS-CAP-01 — cotización de Nuevo pedido (2026-11-24):** `PedidosRepository.estimarTotales` omitía el enrolamiento/header de capability exigido por el endpoint público `/pedidos/estimar`; el POS daba 403 y bloqueaba Confirmar. Ahora registra el dispositivo y envía la misma capability. Repositorio 5/5, pantalla POS 17/17, analyzer focalizado sin issues. En Equipo por Tunnel, la cotización real mostró 35.000 COP y habilitó Confirmar; no se creó pedido ni movimiento de caja. El carrito vacío ahora explica que deben agregarse productos y oculta el reintento inútil. Cliente y Equipo release publicados; verificación local y por Tunnel: seis endpoints HTTP 200 y hashes SHA-256 idénticos local/público (Equipo `1ae9a8dc…5053596a3`, Cliente `b7cf1822…464e6503`). OAuth y credenciales no se modificaron.

**RBAC — cierre de caja y colas globales (2026-11-24):** `CajaService.cerrar` valida contra la sucursal real de la caja antes de cualquier mutación. Además de la prueba intrarestaurante documentada abajo, QA E2E en clon creó una caja para un tenant distinto, intentó cerrarla autenticado como admin del tenant demo y obtuvo 403; consulta posterior confirmó que siguió `abierta`. Se detuvo Nest QA y se borró el clon. `POST /notificaciones/procesar-cola` ahora exige `SuperAdminGuard`; `prueba-web` queda limitada a tokens del usuario con `RolGuard`. Suite focalizada 8/8 y build Nest OK. API `:3000` reiniciada (PID 19492), seis rutas locales/públicas HTTP 200, cola sin sesión 401 local/Tunnel; Cloudflare Tunnel conservado.

**E2E integral y verificación de arranque (2026-11-24):** Jest aislado 8 suites/32 pruebas y batería operativa 9/9; Flutter 248 aprobadas/5 omitidas/0 fallidas; analyzer global sin errores ni warnings, con 33 infos preexistentes. Fixtures invitados ya cumplen la capability de dispositivo y el runner resetea solo QA antes de Jest. `verificar-idor-scope.ps1` pasa en PostgreSQL QA; el gerente de Centro no puede cerrar caja de Norte (403), que continúa abierta. QA `:3001` e impresora temporal `:8765` detenidos; API `:3000` + frontends `:8080/:8081` siguen activos. Pendientes explícitos: impresora/dispositivo físicos, prueba de carga, aceptación visual autenticada, escenarios ausentes del seed y E2E entre tenants distintos.

> **Única fuente de verdad para el estado del producto.**  
> Consolidación inteligente de 34 documentos en `docs/`, 10 en `INFRAESTRUCTURA/`, `MEMORIA.md` y verificación contra código (2026-06-28).  
> **Mantener este archivo** al cerrar tareas. Specs técnicas detalladas siguen en `INFRAESTRUCTURA/`; procedimientos en `docs/ENTORNO_LOCAL.md`.

**Última actualización:** 2026-11-26 — Plan integral secuencial en `docs/HANDOFF_CODEX_FOODY.md`; tareas 1–3 cerradas y PED-COMBO-GUARDS-01 en curso. PED-COMBO-E2E-01 pasó 11/11 contra API QA :3001 y clon aislado: QR→asignación de mesero→KDS→Caja; POS/cajero y mesero; KDS/reimpresión contra cocina secundaria temporal; sustitución/rechazo, ledger y cancelación. Cleanup SQL verificó cero combos/pedidos/cocinas temporales. API :3000 PID 16876 no reiniciada; :3001 PID 14168 activa; health 200 con alertas de impresión conocidas. No se tocaron OAuth, credenciales, DB diaria ni hardware físico. Siguiente: retirar guardas de cocina única tras inventariar catálogo, estimación, alta/agregado y estado agregado.

**Actualización histórica (2026-11-24):** PED-STAFF-IDEM-01 hizo idempotente el reintento de crear pedidos desde POS. El agregado de líneas a un pedido abierto quedó idempotente después como PED-ITEM-IDEM-01; la E2E confirma que una repetición igual no duplica y que cambiar el payload con la misma clave devuelve 409. QA visual autenticada sigue pendiente.
**Última actualización:** 2026-11-26 — Plan integral secuencial en `docs/HANDOFF_CODEX_FOODY.md`; tareas 1–3 cerradas y PED-COMBO-GUARDS-01 en curso. PED-COMBO-E2E-01 pasó 11/11 contra API QA :3001 y clon aislado: QR→asignación de mesero→KDS→Caja; POS/cajero y mesero; KDS/reimpresión contra cocina secundaria temporal; sustitución/rechazo, ledger y cancelación. Cleanup SQL verificó cero combos/pedidos/cocinas temporales. API :3000 PID 16876 no reiniciada; :3001 PID 14168 activa; health 200 con alertas de impresión conocidas. No se tocaron OAuth, credenciales, DB diaria ni hardware físico. Siguiente: retirar guardas de cocina única tras inventariar catálogo, estimación, alta/agregado y estado agregado.
**Analítica — validación de estados en Rentabilidad (2026-11-24):** no se encontró defecto: `clausulasPedidos` ya excluye cancelados/rechazados por defecto y respeta selección explícita de estado. Prueba de regresión cubre ambos contratos; Nest build y unitarias 29 suites/65 pruebas. API :3000 sincronizada con el build actual en PID 17080; health local/pública HTTP 200, `cloudflared` PID 11112 y `.env` sin cambios. Flutter global 219 aprobadas/5 omitidas; análisis global 0 errores/warnings y 36 infos. QA autenticada pendiente.
**Reportes — REP-DEFAULT-DATE-TZ-01 (2026-11-24):** el rango API sin parámetros toma “hoy” con `America/Bogota`; antes, entre 19:00 y medianoche local, `toISOString()` podía adelantarlo al día UTC siguiente. Test con reloj controlado; build + unitarias Nest 29 suites/66 pruebas. Activado en API PID 14644; salud local/pública HTTP 200, Tunnel PID 11112 y `.env` sin cambios. Flutter global 220 aprobadas/5 omitidas.
**Caja/reportes — CAJ-REFUND-TRACE-01 (2026-11-24):** la devolución manual actual solo captura monto/motivo, se guarda como efectivo y no lleva ticket o artículo; Caja neta resta el movimiento, pero ventas y utilidad P&L siguen por pedido. Riesgo y decisión de política documentados en `AUDITORIA_CAJA.md` y `AUDITORIA_REPORTES.md`; no se cambió flujo/pago. Definir vínculo, medio, COGS y devolución a stock/merma antes de implementar.
**Menú — MENU-LOAD-PARALLEL-01 (2026-11-24):** las seis colecciones cargan en paralelo; costeo ya no bloquea la primera vista y respuestas antiguas se descartan. Test de concurrencia/costeo pasa; menú 10/10, Flutter global 220/5 omitidas, analyzer focalizado limpio. Sin cambios de contrato/backend.
**Aislamiento operativo:** revisión estática de controladores de pedidos, KDS y domiciliarios; `SucursalScopeService` tiene regresión negativa/positiva 4/4 para sede propia, sede hermana, empresa distinta/sede inactiva y permiso corporativo. No se encontró fuga reproducible en el alcance revisado; faltan E2E autenticados cross-tenant y revisar módulos fuera de este flujo.
**Finanzas — FIN-FIXED-PARTIAL-BALANCE-01 (2026-11-24):** saldo mensual de costos fijos descuenta abonos vinculados de la misma sucursal y origen. Unitarias 2/2; query equivalente probada en PostgreSQL QA temporal con `ROLLBACK`; build Nest OK; API :3000 activada y salud local/pública 200, Tunnel activo. Nómina y períodos históricos requieren política separada.
**Próximo paso recomendado:** continuar trazabilidad de Pedidos → Cocina → Caja → Finanzas/Análisis; decisiones abiertas: política de archivo/revisión de tickets KDS antiguos y tratamiento contable FIN-TIP-01.

**KDS — COC-ALL-READY-UX-01 (2026-11-24):** “Todo listo” informa resultado parcial por ítem; tras error detiene solicitudes posteriores, recarga el ticket y conserva pendientes reintentables. Widget 11/11; suite Flutter 210 aprobadas/5 omitidas/0 fallidas; analyzer focalizado limpio. Cliente/Equipo Release servidos por launcher, frontends local/público y salud API HTTP 200; :3000 PID 7564 y Tunnel conservados. Sin cambios Nest/OAuth/datos. Pendiente: evaluar atomicidad de API si operación exige todo-o-nada; QA autenticada, impresora/dispositivo real. Warnings de build Wasm/CupertinoIcons no bloquearon el build.
**Última consolidación:** 2026-11-24 — KDS: acciones masivas recuperables; Domiciliarios: lecturas paralelas y refresh sin perder datos previos ante error. Flutter global 213/5 omitidas. Builds Cliente/Equipo publicados por Tunnel, hashes coinciden exactamente y seis endpoints local/público HTTP 200; API :3000 y cloudflared conservados. QA autenticada/hardware sigue pendiente.
**Pedidos/Caja — FIN-SPLIT-OVERCHARGE-01 (2026-11-24):** corregido cobro dividido que podía superar el saldo tras un abono: suma precio de ítems con toppings/bebidas, prorratea descuento y valida el saldo por pedido antes de registrar. E2E cubre rechazo sin movimiento Caja, split válido y cierre; Nest E2E 8/8 suites, 22/22; unitarias 26/26 suites, 57/57; build OK. Batería operativa QA 9/9. Al corte original el cambio no estaba servido; reinicio verificado de `:3000` registrado en la actualización MES-GROUP-ACCOUNT-01. Detalle en `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.
**KDS — COC-ALL-READY-UX-01 / COC-RETURN-UX-01 (2026-11-24):** ambas operaciones por lote paran el envío ante el primer error, refrescan y comunican resultado parcial; reversión fallida vuelve a Cocina. Focalizada 12/12, Flutter 211 aprobadas/5 omitidas/0 fallidas, analyzer limpio. Sin cambios de backend/OAuth/datos. No es atómico; evaluar endpoint transaccional solo si el producto exige todo-o-nada.
**Domiciliarios — DOM-READ-PARALLEL-01 (2026-11-24):** dos consultas GET independientes del resumen ahora corren en paralelo (carga y refresh), quitando un RTT serial. Prueba de concurrencia por `Completer`; módulo 5/5, Flutter 212/5 omitidas, analyzer limpio. Rebuild Cliente/Equipo y comprobación exacta SHA-256 contra bundles públicos; seis endpoints HTTP 200. Sin cambios Nest/datos. No se midieron ms con red externa.
**Domiciliarios — DOM-STALE-01 (2026-11-24):** las recargas automáticas/manuales no vuelven a skeleton una vista ya cargada; un GET fallido conserva datos y ofrece reintento inline. Test de future pendiente + error; módulo 6/6, Flutter 213/5 omitidas, analyzer limpio. Release público exacto con SHA-256: Cliente `ED08B4FA24504C97944F904B638C318721C1BB5B972A69D46FC06A05724B48D6`, Equipo `F0BBE643FDD23C3184CAAB0ED12F0AC309CD9D8EB91300DE8EF6BD18E5EEABBA`. Sin cambios backend/OAuth/datos.
**QA-HOST-01 (2026-11-24, incidente controlado):** una reejecución manual de `mesa.e2e-spec.ts` tras formatear se hizo sin `E2E_HOST` y heredó el default anterior `127.0.0.1:3000`. La creación del pedido falló antes de insertar orden; consulta de solo lectura a `estados_pedido_historial` encontró 0 cancelaciones con motivo `QA e2e jest cleanup` en la ventana y `cajas` no muestra apertura reciente. El test alcanzó a crear y desactivar el usuario de prueba `mesero-e2e-a25de2b6-fa52-4417-bb0b-aad0af8b54d5@qa.example` (UUID `62bb4d80-3cc5-4628-99b5-c880a1497633`), actualmente inactivo; no se borró ni se hicieron más escrituras. **Mitigación aplicada y probada:** E2E ahora usa `:3001` por omisión y bloquea hosts distintos antes de ejecutar setup/escrituras, salvo opt-in explícito `FOODY_E2E_ALLOW_NON_QA=1`. `:3000`, Cloudflare y frontends siguieron respondiendo. Ver `AVANCE_PROYECTO.md` 2026-11-24.
**Cocina/KDS — COC-MOTIVO-UI-01 (2026-11-24):** el diálogo de fallo de preparación ahora valida el motivo antes de llamar la API y explica que la operación genera alerta, posible merma si el inventario se descontó y desactiva el producto en menú. E2E de Cocina aislada 3/3; widget tests KDS 10/10 (4 anchos), analyzer focalizado limpio. No se reinició `:3000`. Revisada coherencia de `no_disponible`, estados agregados entre estaciones y bloqueo de dispatch de domicilio. Pendientes de diseño/política: recuperar línea marcada por error, consentimiento/ajuste/abonos y atomicidad de “Todo listo” (una llamada por ítem).
**Pedidos — PED-CHANNEL-01 / CLIENT-DOM-CONTACT-01 (2026-11-24):** trazadas entrada QR, checkout invitado y POS/mesero/admin. QR crea mesa pendiente de aprobación y backend recalcula precio. E2E de domicilio confirma que Checkout y DTO exigen teléfono válido solo para domicilio; nombre opcional. Pruebas DTO 8/8, QR E2E 4/4; layout base del checkout sin overflow a 320/390/820/1440 px. Nest `:3000` aún debe activar el build actual. E2E Mesa 2/2 incluye mesero temporal que crea pedido y presenta cuenta, pero el backend bloquea “listo” y cobro; esta semántica de rol continúa pendiente. PED-CHECK-01 está protegido por migración 089.
**KDS / Realtime — RT-BANNER-01 / KDS-TIME-01 (2026-11-24):** el banner oculta excepciones Dio/detalles backend y conserva el polling. El badge presenta días+horas desde 24 h sin cambiar estados/acciones. Se detectó que el navegador autenticado conservaba un bundle viejo; el publicador ahora versiona bootstrap y JS por SHA-256. El KDS público confirmó `112d 3h`; el bundle local y Tunnel coinciden (`42831E2BE7CF4882C072A7AD49C147AFE931792D77262D6FEA211F059A805442`). KDS 13/13; Flutter global 217/5 omitidas/0 fallidas. Iniciador `scripts/iniciar1` probado con exit 0 y `-SkipBuild`; `MODO=tunel`, Cloudflare y API :3000 preservados. Tickets antiguos siguen accionables; política de archivo/revisión pendiente.
**Mesas/Pedidos/Caja — MES-GROUP-ACCOUNT-01 (2026-11-24):** al abrir una mesa secundaria unida, la cuenta listaba tickets/abonos solo de su ID, mientras Cobrar mesa resolvía todos los IDs del grupo. Corregido en Nest para consultar tickets y pagos en el grupo completo y limitar también la resolución del grupo de cobro por sucursal/mesas activas. Unit spec 1/1; E2E Mesa 3/3 en API temporal :3001 + `foody_diseno_qa`; Flutter `mesa_pedidos_sheet_test.dart` 9/9; build Nest OK. QA restaurada y sin grupos pendientes; :3001 detenido. API :3000 PID 7564 sigue saludable, Tunnel no reiniciado. La pantalla ya consume y presenta `cantidad_tickets`, `total_acumulado` y `mesa_grupo`; sin rediseño adicional requerido para corregir el contrato.
**Mesas — MES-GROUP-FLATTEN-01 (2026-11-24):** la unión aceptaba mesas que ya pertenecían a grupos y reasignaba solo el ID seleccionado; al mover la raíz quedaban miembros huérfanos y la cuenta podía solaparse/incompletarse. La transacción ahora recorre y aplana los grupos seleccionados hacia la mesa principal, bloquea uniones concurrentes por sucursal, bloquea filas en orden determinista y mueve los pedidos activos del conjunto completo. E2E Mesa 4/4 (incluye cuenta secundaria y unión de grupos); Nest build OK. API :3000 reiniciada a PID 4924; local/Tunnel API HTTP 200, Cliente/Equipo HTTP 200; cloudflared PID 11112. QA limpia: cero mesas agrupadas.
**Super Admin / Domiciliarios — DOM-DELIVERY-COUNT-LABEL-01 (2026-11-24):** `total_entregas` aumenta al aceptar oferta, no al completar entrega. La tarjeta ahora lo denomina “Ofertas aceptadas (histórico)”; no se recalculó el contador ni se cambió la política de pagos. Widget 2/2 y analyzer focalizado limpio. `DOM-CANCEL-PAYOUT-01` continúa pendiente.
**Caja / mesas — FIN-MESA-SPLIT-01 (2026-11-24):** E2E reprodujo que una mesa con dos tickets cobrados en un pago mixto podía marcar ambos pedidos pagados y dejar el movimiento Caja del segundo sin registrar, porque el cobro entero se asociaba al primer pedido y Caja limitaba por su total. `PedidosPagosService` ahora distribuye cada línea de pago entre los saldos asignados por ticket; una inconsistencia restante aborta la transacción. E2E caja 4/4 (incluye dos tickets, efectivo/tarjeta y monto+método correcto por pedido); suite E2E completa 8/8 suites, 20/20 pruebas; Nest unitario 26/26 suites, 57/57; `npm run build` OK. QA aislada restaurada (horario 08:00–22:00, ingrediente demo 10.000 g, producto disponible); proceso temporal :3001 detenido. API principal :3000 y Tunnel no se reiniciaron. `FIN-TIP-01` queda pendiente: las propinas se almacenan en pago/pedido pero no suman movimiento de Caja; definir separación contable y tratamiento de fondos antes de cambiarlo.
**Pedidos — numeración concurrente (2026-11-24):** el generador compartido público/staff usa lock transaccional por sucursal/año y acota el conteo al año Bogotá. Verificado en Nest aislado :3001 con BD `foody_diseno_qa`: E2E completo secuencial 8/8 suites y 15/15 pruebas, incluida una creación simultánea de cuatro pedidos públicos con números distintos. Semilla QA restaurada (horario 08:00–22:00, inventario demo 10.000 g); la API principal :3000 no se reinició. Tunnel se mantuvo operativo. No equivale a prueba de carga/estrés; el conteo anual creciente sigue siendo una limitación conocida y una secuencia dedicada se difiere hasta medir volumen.
**Caja/Reportes/Análisis — conciliación E2E (2026-11-24):** se probó una venta de mesa de punta a punta: pedido pendiente, cocina lista, cierre en caja y consulta de reporte. El incremento de `pedidos.total` coincidió con `movimientos_caja` en Reportes financieros y en Analítica de Caja; la variación de la diferencia de cuadre fue $0. E2E completo secuencial 8/8 suites, 17/17 pruebas con QA aislada. Esto valida venta pagada; no define reconocimiento de pedidos abiertos/impagos, abonos o cargos de domicilio. Nest :3000/Tunnel no se reiniciaron; datos de fixture restaurados.
**Mapas — zoom accesible y coherente con tema (2026-11-24):** los controles compartidos ahora tienen área táctil 48×48, tooltips “Acercar mapa”/“Alejar mapa”, color primario y superficie del tema en lugar de blanco fijo. Se aplican a cobertura, ubicación de sede, seguimiento y mapas de reparto; no cambia el centro, zoom, capas ni navegación del mapa. Pruebas 2/2 en 320×568 y 820×900; analyzer focalizado limpio; regresión Flutter completa 204 aprobadas/5 omitidas. `impeccable detect` sobre los archivos modificados: `[]`. Aún no se reconstruyó/publicó el bundle web; QA visual de mapas y gestos en Chrome/dispositivo sigue pendiente.
**Alertas — contraste oscuro (2026-11-24):** tarjetas usan sombras temáticas y niveles alto/crítico/medio y revisión usan tonos accesibles para oscuro; spinner adapta su color al botón. Suite del módulo 7/7 y `flutter analyze` limpios; Flutter global 202/5 omitidas. Equipo Release (incluye Reportes): 6.542.744 bytes, SHA-256 `694C31C487E5D65226BB08648E7B2D514F54750D78E06D7FE8856A1AAF8C04D4`; sitios locales y públicos Cliente/Equipo y API health responden HTTP 200; cloudflared PID 11112. No cambió la lógica de revisión/generación ni OAuth. QA autenticada y aprobación operativa siguen pendientes.
**Reportes — contraste de filtros (2026-11-24):** el periodo seleccionado/no seleccionado usa los tokens del tema. Prueba focalizada 6/6 y analyzer limpio. No cambia rangos, solicitudes ni exportaciones. El build Equipo que incluye este ajuste coincide con el hash indicado en la entrada ADM-21; QA de permisos y revisión manual de gráficas pendientes.
**Regresión Flutter más reciente (2026-11-24):** 202 aprobadas, 5 omitidas por guard E2E de BD aislada, 0 fallidas. Incluye Alertas y filtro de Reportes en tema oscuro, filtros de pedidos móviles, acciones táctiles KDS, panel de domiciliarios 320×640, navegación compartida por rol y Análisis/Finanzas responsive. No incluye escrituras reales contra datos de negocio ni dispositivo físico.
**Análisis y Finanzas — coherencia visual por tema (2026-11-24):** KPI, tarjetas de gráficas, superficies, pedidos recientes, insights, leyendas, filtros y gráficos ahora respetan tokens claro/oscuro; barras, pies, ejes y leyendas ganan contraste en oscuro. Sin cambio de métricas, fórmulas, permisos ni reglas de pago. Suite analítica focalizada 12/12; Finanzas 8/8 (incluye gráfico oscuro y formularios 320/390); `flutter analyze` limpio en ambos módulos. Equipo Release `build/web_equipo/main.dart.js`: 6.542.144 bytes, SHA-256 `4FCAA258919916868B245D50A92D227DE3A6E41984817FF0A823B385F6EF1A5B`, coincidente byte a byte en `:8080` y `equipo.foodyy.store`; Cliente público, Equipo local/público y API health HTTP 200; cloudflared PID 11112 activo. No se reinició Nest ni se tocó OAuth/configuración comercial/datos. QA visual autenticada, filtros con sesión, navegación por permisos y legibilidad a11y siguen pendientes.
**Shell operativo Cajero/Mesero (2026-11-24):** ambos paneles sustituyen la navegación M3 genérica por `OperacionRoleNavBar`: pills segmentadas con indicador activo, semántica sin anuncio duplicado, targets móviles ≥56 px, navegación superior compacta a ancho expandido y color tomado del tema en AppBar/fondo. Preserva los callbacks, acceso a pestañas y guard de caja existente. 2 pruebas responsive (320×640 y 820×900) + analyzer limpio. Bundle Equipo Release vigente: 6.540.562 bytes, SHA-256 `97FD28C4C4FD334243DE2A9F0A78124743A3438EBDC7969B80DDF5EF9B4EFDC4`, idéntico en build, :8080 y Tunnel `equipo.foodyy.store`. Cliente/Equipo locales y públicos y API health HTTP 200; cloudflared PID 11112 y Nest PID 7564 activos. Smoke autenticado por rol pendiente.
**Búsqueda global — UX responsive (2026-11-24):** la paleta de búsqueda se adapta al contenido y al teclado móvil, separa carga/error/vacío, permite reintentos, ofrece accesos rápidos y busca pedidos activos a partir de 2 caracteres. Siete pruebas widget cubren anchos 320/390/820/1440, scope de sucursal, error/reintento y umbral; analyzer focalizado limpio. Flutter global actualizado: 193 aprobadas, 5 omitidas por guard de BD E2E aislada. Build Equipo release 6.536.334 bytes; SHA-256 `CE7E986992F7E0ACB5906C37DA8295F8BD96C9909FF6E72B34BC0F1EEADAB8AD` coincide en artefacto, `:8080` y Tunnel; local/público HTTP 200. API health HTTP 200; cloudflared PID 11112. Nest :3000 (PID 7564) sigue con binario anterior: dashboard y búsqueda server-side del código actual requieren activación coordinada. OAuth y datos de negocio intactos. La validación autenticada y en dispositivos móviles de la nueva paleta continúa pendiente.
**POS — accesibilidad táctil (2026-11-24):** controles +/- del carrito pasaron de 22×22 a hit-area 44×44, conservando el ícono compacto; cada acción incluye tooltip, etiqueta semántica y key estable. Regresión del POS 10/10 y Flutter global 193 aprobadas/5 omitidas; analyzer focalizado limpio. Build Equipo 6.536.646 bytes y SHA-256 `5A5DCE7056D2439EDFB3AF16A6D1C69BE9990564FFEFC18E5DA97FF61ADE0AC8` coincide entre disco, :8080 y `equipo.foodyy.store`. :8080/:8081 locales, Equipo/Cliente públicos y health API HTTP 200; cloudflared PID 11112. Nest :3000 PID 7564 activo sin reinicio. Probar checkout autenticado y dispositivo táctil real aún pendiente.
**Dashboard — jerarquía KPI Alertas (2026-11-24):** la última tarjeta ahora ocupa el ancho disponible en 320/390 px y dos columnas en tablet 820 px. `dashboard_resumen_widget_test.dart` 8/8, cuatro tamaños; analyzer limpio. Regresión Flutter posterior: 193 aprobadas/5 omitidas por guard de BD E2E. Bundle Equipo vigente (incluye ajuste POS táctil): 6.537.994 bytes, SHA-256 `776643BDBE0042A3BD3496AD323907D012337CD64963D553FD46D974BE54B3A9`, idéntico en disco, `:8080` y Tunnel. Cliente/Equipo locales y públicos y health API HTTP 200; cloudflared PID 11112. Avisos de build no bloqueantes: dependencias actuales incompatibles con Wasm dry-run y fuente CupertinoIcons faltante.
**Pedidos — filtros de canal compactos (2026-11-24):** en viewport <720 px los filtros “Todos/Mesa/Domicilio/Para llevar” permanecen en una sola fila horizontal con fade; desktop conserva wrap. No se ocultaron opciones ni se alteraron filtros. `pedidos_kanban_widget_test.dart` 8/8, prueba de un renglón en 320/390 px y layouts 820/1440; analyzer limpio; Flutter global 193 aprobadas/5 omitidas. Build Equipo vigente incluye este cambio, dashboard y POS: 6.538.271 bytes, SHA-256 `21C90E666DB166C90EEFC41E1BD3605DB1CC94352DC4766AD59334A5F0E52421`, idéntico en disco, :8080 y Tunnel. :8080/:8081, sitios Cliente/Equipo públicos y health API HTTP 200; cloudflared activo.
**Cocina/KDS — prioridad táctil (2026-11-24):** en tarjetas estrechas el CTA principal ahora dice “Marcar listo” y ocupa la fila completa; acciones auxiliares quedan en otra línea. Acciones de cocina tienen hit-area ≥48×48. `kds_screen_test.dart` 9/9, cuatro anchos, verifica tamaño del CTA y “Preparando”; analyzer limpio; Flutter global posterior 194 aprobadas/5 omitidas. Equipo Release de esa publicación: 6.538.679 bytes y SHA-256 `B6180EB15E17727974F7FE981CE5952AE672222FC8EEC94A1CC4692DD70C2668`, igual entre build, :8080 y Tunnel; cliente/equipo local y público y API health HTTP 200. Avisos Wasm/CupertinoIcons preexistentes no bloquean el JS.
**Regresión Flutter integral (2026-11-24):** `flutter test` completo: 182 aprobadas, 5 omitidas por guard de BD E2E aislada; sin fallos. El conteo incluye nuevas pruebas POS responsive/modal; no sustituye pruebas E2E autenticadas ni móvil físico.
**Pedidos paginados — verificación (2026-11-24):** regresión completa posterior: **184 aprobadas, 5 omitidas, 0 fallidas**; las dos nuevas cubren paginado de activos y contrato HTTP. Bundle Equipo release local :8080 y Tunnel `equipo.foodyy.store` :8080 responden HTTP 200 y su `main.dart.js` coincide byte a byte con `build/web_equipo` (SHA-256 `2AF3DA9D59D21FD1A966622D9A378C623F28E507107AEBAADA53EF00604DD162`). cloudflared PID 11112 sigue activo; Nest :3000 no reiniciado.
**Regresión backend integral (2026-11-24):** `npm test -- --runInBand` en `foody_backend`: 22 suites/53 pruebas aprobadas. Incluye KDS GET read-only, evaluación de demoras en lote y paginación de pedidos. No prueba el comportamiento del proceso Nest que ya está corriendo en :3000 ni reemplaza E2E de BD aislada.
**POS — POS-GRID-DENSITY-01 (2026-11-24):** grilla de “Nuevo pedido” calcula 2–5 columnas desde el ancho real del panel de menú (antes tomaba solo un breakpoint de ventana y tarjetas altas de proporción 0,85); proporción de tarjeta 1,35. Usa `imagenUrl` con `CachedNetworkImage` cacheado; mantiene placeholder/error fallback, `memCacheWidth` limitado al ancho de tarjeta, y no añade dependencias. `pedido_cajero_screen_test.dart` 10/10; cubre 320/390/820/1440, 5 columnas en 1440, carga de widget de imagen y barrera modal que no activa productos subyacentes; analyzer limpio. Regresión Flutter global 182/182 aprobadas, 5 E2E omitidas. Build Equipo completado; :8080 y `equipo.foodyy.store` HTTP 200; `main.dart.js` local/build/público SHA-256 idéntico `146C56F9C673F00F070ED8CE52E0C6C9AC1A1DA0A981C68F124FA3AE1B46F9FA`; cloudflared PID 11112. Chrome confirmó la grilla de 5 columnas a 1920 px tras recarga fuerte; productos demo sin fotografías. El pedido real nunca se envió. Pendiente validar dispositivo físico y continuar rutas/modal POS.
**Pedidos — ADM-03-LIMIT-01 (2026-11-24, corregido en UI):** se añadió carga paginada de activos, acumulación/deduplicación, total global, progreso “Mostrando N de total”, conteos parciales marcados `+` y KPI “Valor cargado” mientras falten páginas. Disponible en grid y columnas; error con reintento y búsqueda sin coincidencias ofrecen cargar más. Pruebas widget + HTTP: 9/9; analyzer limpio. Se conserva offset pagination; inserciones concurrentes dependen de realtime/refresh para reiniciar la secuencia; cursor estable queda como evolución. Sin cambios Nest ni reinicio de :3000. QA autenticada/móvil pendiente. Detalle en `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.
**Pedidos — ADM-01-LIMIT-02 (2026-11-24, corregido en fuente):** Dashboard consume hasta 8 demoras selectivas del resumen Nest (listos >8 min; asignados/en ruta >25 min; alta severidad ≥40 min), sin leer el top 100. Búsqueda global solicita coincidencias activas server-side por número, cliente, teléfono o mesa, consulta de 2–80 caracteres, límite 6 y scope obligatorio de sucursal; debounce 250 ms. Specs verifican SQL parametrizado, sucursal/activos, conteo y contrato cliente. Suite Nest 24/55, build OK; Flutter 186/5 omitidas. **Nest :3000 no se reinició:** Tunnel todavía sirve backend antiguo; el cambio exige activación coordinada. Ver `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.
**Cocina — KDS-GET-WRITE-01 (2026-11-24, corregido en fuente; activación pendiente):** `GET /cocina/tickets/:cocinaId` ya no genera alertas. Un proceso Nest `CocinasDemorasCronService` busca hasta 200 pedidos retrasados por ciclo cada 5 min, excluye alertas aún pendientes, registra lote en una transacción y usa advisory lock `9200009` para líder único. Tres specs nuevas (GET read-only, cron, lote) y build backend OK; la suite completa pasa 22/22 suites, 53/53 pruebas. **Nest :3000 no se reinició**, por lo que el proceso expuesto por Tunnel aún requiere activación controlada. Chrome antes observó 105 tickets ≥20 min, varios >3.790 h, etiquetados “Cobrado”; no se tocó pedido/cocina. El GET previo pudo haber insertado alguna alerta sin delta verificable; no se hará limpieza inferida. Backlog histórico sigue sin clasificar. Una alerta revisada puede volver a generarse si el ticket sigue atrasado al siguiente ciclo (política heredada de dedupe pendiente únicamente); revisar si se requiere cooldown.
**Reportes/Análisis — FIN-DATE-01 UX (2026-11-23):** se reemplazó “Cobrado en caja” por “Movimientos netos de caja” y se aclara en UI y exports que movimientos ligados usan fecha de creación del pedido y movimientos sin pedido su propia fecha. No cambió SQL/importes; la decisión de agrupar por cohorte o fecha efectiva del dinero continúa pendiente. Flutter Reportes+Análisis 10/10, exports 2/2, Nest metadata 2/2 + build; analyzer focalizado limpio. Regresión completa vigente: Flutter 176 aprobadas/5 omitidas; Nest 19 suites/49 pruebas. Equipo release local/Tunnel idéntico por SHA-256 `BA88921C9A33F379AF30733BA2CFCBFDC4EBB83DE86F1FE4CE3670092B681FF8` (6.523.729 bytes); texto nuevo presente en bundle público. Equipo local, Reportes público y salud API HTTP 200; cloudflared PID 11112. Nest :3000 no reiniciado; UI tiene fallback de contexto para API anterior.
**Analítica — ANA-CANCEL-DENOM-01 (2026-11-23):** el KPI “Pedidos” excluye cancelados, pero `% cancelación` usa todos los pedidos del periodo; ambos aparecían juntos sin numerador/denominador. Backend ahora expone los conteos y la tarjeta presenta `cancelados de total`; con Nest antiguo muestra una nota explícita en vez de inventar `0 de 0`. Prueba backend 1/1, build Nest OK; Flutter widget 2/2 y analyzer focalizado limpio. Chrome mostró 9 pedidos válidos, 81,3% cancelaciones y 478 alertas abiertas; el total de alertas es acumulado sin revisar de la sede, no del rango de 7 días. Build Equipo release con `APP_FLAVOR=equipo` y `usarTunel=true`; local/public Cliente, Equipo y salud API respondieron HTTP 200; cloudflared sigue activo. No se alteraron datos ni se reinició Nest. Falta reinicio coordinado de :3000 para exponer los conteos exactos.
**Navegación — NAV-RAIL-COMPACT-01 (2026-11-24, verificado):** la captura de Análisis se tomó en ventana de 931 px; el breakpoint 720–1099 px activa deliberadamente una rail de 72 px. Cada icono abre grupo con `Tooltip` y opciones con texto; no es una vista sin nombre ni una ruta perdida. Chrome confirmó Inicio autenticado en lectura a 1920×1040 (sidebar completa y cinco tarjetas operativas distribuidas), 931×1013 (rail compacta; tarjetas reacomodadas en varias filas, sin recorte horizontal visible) y viewport emulado de 320×866 (hamburguesa, métricas en dos columnas, scroll vertical; etiquetas largas se parten en dos líneas sin recorte horizontal visible). La emulación no sustituye dispositivo físico. Falta recorrido de las demás secciones y QA móvil real.
**Analítica — ANA-PARTIAL-LOAD-01 (2026-11-23, severidad media, corregido):** la vista esperaba resumen + cuatro endpoints de apoyo antes de mostrar la página y cualquier fallo secundario ocultaba KPIs; además, `_tabLazy` programaba solicitudes para los hijos de `TabBarView`, incluidas pestañas no abiertas. El resumen ahora se presenta primero, los detalles muestran carga explícita y errores parciales con reintento; cada pestaña secundaria consulta al seleccionarse. Las revisiones de carga descartan respuestas viejas al cambiar sede/filtros. Pruebas focalizadas Flutter 4/4; regresión Flutter completa 173 aprobadas y 5 omitidas; Nest 17 suites/45 aprobadas; analyzer `--fatal-infos` limpio. Build Equipo release actualizado; cinco URL locales/públicas HTTP 200 y `main.dart.js` con SHA-256 idéntico local/Tunnel (6.522.567 bytes). Cloudflared PID 11112 activo; Nest :3000 no reiniciado.
**Actualización financiera (2026-11-24):** Analítica Caja separa gastos del libro y movimientos; compatibilidad Nest previo conserva “no disponible” cuando faltan campos. El build Nest actual se activó en :3000; Tunnel continúa operativo. Reconciliación por fecha de pedido/movimiento sigue pendiente (`FIN-DATE-01`).
**Finanzas — fecha y saldo parcial (2026-11-24):** fechas por defecto usan America/Bogota. Costos fijos ahora calculan saldo mensual tras abonos (`FIN-FIXED-PARTIAL-BALANCE-01`); nómina/ciclos queda pendiente (`FIN-PAYROLL-PERIOD-01`). Unitarias 2/2 del cambio, SQL equivalente en QA temporal con rollback, build Nest y API :3000 activada; Tunnel conservado.
**Independientes — comisión y payout (2026-11-24):** comisión 15% se registra al aceptar oferta, antes de entrega; Super Admin la cuenta en `ingresos_foody_hoy`, por lo que es estimada, no cobro confirmado. El panel muestra saldo “Por pagar”, pero no hay ruta que liquide ni cambie `ganancias_domiciliario.pagado`. Nuevo riesgo `DOM-INDEP-SETTLE-01`; quién paga, origen del dinero, evento de devengo, cancelaciones y comprobante requieren definición de negocio. Las consultas “hoy” del Super Admin se alinearon al rango local Bogotá. Backend 5 suites/6 pruebas + build OK; :3000 no reiniciada.
**DOM-INDEP-SETTLE-01 — claridad visual (2026-11-24):** el KPI de Super Admin ahora se titula “Comisión estimada hoy” y explica que se registra al aceptar una oferta y no confirma recaudo. No cambia montos, cálculo ni estados; se añadió prueba widget del texto.
**DOM-CANCEL-PAYOUT-01 — resumen operativo aclarado (2026-11-24):** la sección de domiciliarios ahora denomina “asignaciones” al conteo que el backend agrupa desde `ganancias_domiciliario` (creado al aceptar oferta), marca la comisión como estimada y aclara que saldo registrado no confirma entrega ni pago. El riesgo de compensación en cancelaciones y el payout siguen pendientes de decisión comercial.
Pruebas de UI: Domiciliarios responsive 3 viewports + KPI Foody Control (4/4); analyzer focalizado limpio. Web Equipo release compilada; `main.dart.js` local y por Tunnel comparten SHA-256 `A2C5A719DC1EEE59965FD3C46E05081AE419F2EC9403297142D8DA5CFDD0207C` (HTTP 200; 6.524.241 bytes). `cloudflared` PID 11112 activo. Solo warning del dry-run Wasm por dependencias y ausencia del font asset CupertinoIcons; salida JS termina OK. Sin reinicio de Nest, cambios de Tunnel/OAuth ni mutaciones de negocio.
**Inicio operativo — fallos parciales y cambio de sede (2026-11-24):** ante error de una de cinco lecturas paralelas, los acordeones distinguen consulta fallida de cero resultados; KPIs no presentan cero si falla su fuente. Un refresco fallido conserva valores/listas previos y muestra aviso de datos posiblemente desactualizados con reintento. Una revisión secuencial impide que una respuesta tardía de otra sede reemplace la sede seleccionada. Pruebas widget 7/7; analyzer focalizado limpio. Regresión `flutter test` completa: **180 aprobadas, 5 omitidas** por guard E2E de BD aislada. Bundle release local/Tunnel idéntico, SHA-256 `6DDFE125A8BA9A0A30B0E7E591CED512BE42FCE0FA87D90B2D228CC1326CFB05` (HTTP 200; 6.526.661 bytes); `cloudflared` PID 11112 activo. Chrome comprobó Inicio autenticado en modo solo lectura a 931 px; no se reinició Nest ni se modificó configuración.
**Web responsive — viewport (2026-11-24):** `web/index.html` carecía de `<meta name="viewport">`; se agregó `width=device-width, initial-scale=1.0` para que los navegadores móviles usen el ancho CSS del dispositivo. HTML local y público incluyen el meta y respondieron HTTP 200; `main.dart.js` local/Tunnel conserva SHA-256 idéntico al build vigente. Chrome autenticado en lectura mostró las tarjetas de Inicio en 2 columnas a 320×866 emulados, con scroll vertical, y en escritorio/ventana estrecha a 1920×1040 y 931×1013. Etiquetas como “Ventas hoy (cadena)” y “Alertas pendientes” envuelven líneas en 320 px; no se observó overflow horizontal. Emulación no equivale a prueba en dispositivo físico; las demás rutas siguen pendientes. Cloudflared PID 11112 sigue activo; no se reinició Nest ni se tocaron OAuth, configuración o datos.
**Arranque diario — launcher Tunnel (2026-11-24, ejecutado):** `scripts/iniciar1/iniciar-foody-subdominios.bat` terminó con exit 0. Salud Nest local OK; modo `tunel`/dominio/puertos ya coincidían, por lo que la sincronización no modificó `configuracion.dart` ni las claves de entorno que el launcher gestiona. `-SkipBuild` detectó `build/web_cliente` faltante/desactualizado, compiló Cliente y evitó el error anterior; Equipo ya estaba al día. Reinició los servidores estáticos de :8080/:8081 y dejó ambos HTTP 200; Cliente/Equipo públicos también HTTP 200 y `main.dart.js` local/público coincide en SHA-256. API local/pública `exito=true`; `cloudflared` siguió en PID 11112. El HTML público trae el script de Cloudflare Insights adicional, mientras que el HTML local de origen conserva el contenido generado. Advertencias Wasm y CupertinoIcons no bloquearon los builds. No se reinició Nest ni se alteraron OAuth, credenciales o datos de negocio.
**Regresión completa (2026-11-24):** `flutter test`: 170 aprobadas, 5 E2E omitidas por guard explícito de BD aislada. `foody_backend npm test -- --runInBand`: 16 suites/44 pruebas aprobadas. La nueva ejecución E2E no se hizo: `foody-diseno-qa-db` está detenida; :3001 no escucha y :3000 corresponde al servicio de uso. No usé ni muté la BD operativa ni accedí a credenciales para levantar QA. Los resultados unit/widget no sustituyen ciclo autenticado de extremo a extremo.
**Tunnel al cierre de regresión:** `cloudflared.exe` PID 11112 está corriendo; `foodyy.store`, `equipo.foodyy.store/admin/login` y `api.foodyy.store/api/v1/salud` respondieron HTTP 200. Puertos locales :8080, :8081 y :3000 siguen escuchando.
**Consolidación previa (2026-11-22):** Checkout público exige dirección para domicilio y muestra tarifa sin GPS como estimada; Finanzas/Analítica explican que ventas puede incluir pedidos abiertos. RBAC de Cocina/Realtime corregido en fuente: admin/gerente con `ver_cocina` ahora solicitan topic HMAC de la estación elegida y Nest valida permiso, cocina activa y sucursal; cinco pruebas backend y dos del repositorio, más KDS responsive. Backend 16/16 specs + build OK; Flutter 152 aprobadas/5 E2E mutadoras omitidas. Build de Equipo publicado localmente y por Tunnel; seis destinos locales/públicos responden 200 y el JS público contiene la ruta nueva. Cloudflare sigue operativo. Nest :3000 continúa en memoria con el código previo: falta reiniciarlo para activar el endpoint nuevo. El E2E de domicilio quedó verificado posteriormente en BD aislada QA el 2026-11-23 (7/7 suites). FIN-REC-OPEN-01, DOM-CANCEL-PAYOUT-01 y COC-NODISP-DOM-01 conservan decisiones contables/operativas pendientes. Cliente guest/Google usa `device_id` como capability para historial y seguimiento; `CLIENT-DEVICE-CAP-01` queda abierto hasta diseñar prueba de posesión sin romper el uso anónimo.
**QA integrada de pedidos (2026-11-23):** se levantó únicamente el contenedor preexistente `foody-diseno-qa-db` (PostgreSQL aislado en `127.0.0.1:55494`) y una instancia Nest temporal en `127.0.0.1:3001`, con servicios externos deshabilitados. La suite `npm run test:e2e -- --forceExit` pasó 7/7 suites y 14/14 pruebas: QR, mesa, caja, cocina, domicilio y casos límite. Para preparar el fixture se aplicaron las semillas oficiales 019 y 031 y se restauró `Papas medianas` al estado disponible del seed; las escrituras quedaron solo en `foody_diseno_qa`. Un primer arranque de QA con `DB_POOL_MAX=3` dejó tres conexiones ocupadas por tareas periódicas que ejecutan trabajo de BD bajo advisory lock y la API dejó de responder; con pool 10, `/salud` respondió en 111 ms y los E2E pasaron. Esto demuestra sensibilidad del entorno de prueba a un pool subdimensionado, no un bloqueo observado en la instancia del túnel. También se observaron reintentos de impresión hacia agente local ausente `127.0.0.1:8765`; no impidieron los E2E, pero el seed de QA no está aislado de esa integración. API `:3000`, Tunnel, OAuth, credenciales y BD de negocio no se modificaron.

**Verificación adicional (2026-11-23):** se contrastó en fuente que PED-PREPAGO-01 ya no bloquea cierre con saldo cero y que `salio-sin-pagar` usa la puerta de estado común. El informe de ciclo de vida tenía dos bytes NUL y estados históricos obsoletos; se limpiaron los bytes y se alinearon los hallazgos relacionados en auditorías de pedidos, caja y consistencia. Extendí el caso E2E para cerrar caja QA mientras el prepago sigue en cocina; TypeScript compila el spec. La ejecución nueva no se realizó: el control automático rechazó el comando propuesto para iniciar Nest QA, que requería leer la credencial interna del contenedor para crear `DATABASE_URL`; no se intentó otro mecanismo. El contenedor QA quedó detenido, no hubo escrituras de pedido/caja y :3000 siguió separado. Verificación de runtime al final: `foodyy.store`, `equipo.foodyy.store/admin/login` y `api.foodyy.store/api/v1/salud` devolvieron HTTP 200; cloudflared continuó activo.
**Caja UX / publicación (2026-11-23):** banner de turno ahora expresa duraciones largas en días y horas y orienta revisar operación pendiente antes del cierre; escenarios 14 h y 2635 h, widget 10/10 y `flutter analyze --fatal-infos` focalizado limpio. Build Equipo release directo en `build/web_equipo` OK; el bundle local y el servido por Tunnel contienen el copy nuevo, Chrome lo mostró tras actualizar la página. Cliente/panel/API Tunnel responden HTTP 200; :8080/:8081/:3000 y cloudflared siguen activos. No se ejecutó sincronizador ni se modificó OAuth, secretos o datos. El build informó incompatibilidades del dry-run Wasm y ausencia del asset CupertinoIcons; compilación web JS terminó correctamente.
**POS — estado de Caja no disponible (2026-11-23):** el POS confundía error de red/permisos al consultar `/caja/activa/:sucursal_id` con una respuesta nula (caja cerrada), mostrando CTA incorrecta. Se conserva carga paralela; el fallo ahora se representa como “No pudimos verificar”, tiene reintento y bloquea la confirmación mientras estado sea desconocido; test confirma que no se llama al repositorio de creación. Backend sigue siendo autoridad para registrar movimientos. Cabecera “1 producto / N productos” responsive. Pruebas POS 8/8 y analyzer focalizado limpios. Build Equipo publicado directamente con tunnel existente; bundle local/público actualizado, Cliente/Equipo/API HTTP 200, :3000/:8080/:8081 y cloudflared activos. No hubo checkout ni escrituras reales.
**Pedidos — estados y KPI (2026-11-23):** el tab virtual “Cerrados” descartaba fallos del endpoint y podía renderizar un falso vacío. Ahora tiene carga/error/reintento y conserva errores al refrescar o paginar con resultados previos. El KPI suma `total` de pedidos activos, no pagos recibidos: renombrado “Valor en pedidos” + tooltip explícito. Feedback de transición muestra etiqueta legible (p. ej. “En cocina”) en vez de estado técnico/cadena con mojibake. `pedidos_kanban_widget_test.dart` 7/7; `flutter analyze --fatal-infos` focalizado limpio. Build Equipo release recompilado directamente en `build/web_equipo` sin sincronizar entorno; el JS local y servido por Tunnel coincide en tamaño y contiene las etiquetas nuevas; cliente, login de Equipo y salud API públicos devolvieron HTTP 200, con :3000/:8080/:8081 y cloudflared activos. No se tocó OAuth, configuración, pedidos ni datos de negocio. El build JS terminó correctamente con avisos no bloqueantes del dry-run Wasm y asset CupertinoIcons. Aún no se ha validado en sesión autenticada.
**Cocina KDS — consulta inicial (2026-11-23):** la carga inicial de tickets era silenciosa y podía ocultar fallos detrás de una lista vacía; ahora muestra error/reintento. El KDS también ordenaba in-place la lista del repositorio; se copia antes de ordenar. Regresión responsive/error→reintento 9/9; analyzer focalizado limpio. Build Equipo release directo correcto; JS local y público HTTP 200 y con el mismo tamaño (6.517.822 bytes). Cliente, login Equipo y API salud públicos HTTP 200; :3000/:8080/:8081 y cloudflared activos. No se reinició Nest ni se tocó configuración/OAuth. Smoke autenticado en sesión real pendiente. Avisos build: dependencias heredadas incompatibles con dry-run Wasm y asset CupertinoIcons ausente; web JS terminó con código 0.

**Domicilios — asignación concurrente (2026-11-23):** asignar/reasignar domiciliario de planta validaba ocupación sin serializar por fila de repartidor, permitiendo que solicitudes simultáneas para pedidos distintos observaran disponibilidad obsoleta. Se añadió `SELECT ... FOR UPDATE` sobre la fila activa antes de consultar asignaciones; las transacciones concurrentes para el mismo repartidor se ordenan y la segunda vuelve a validar la ocupación. Prueba de servicio 2/2 y build Nest correcto. No se publicó/reinició :3000, no hubo mutaciones de BD ni solicitudes operativas. Falta prueba concurrente con PostgreSQL aislado y smoke autenticado; dispatch de independientes queda para auditoría separada.
**Domicilios — ofertas independientes (2026-11-23):** al aceptar un repartidor una oferta, otras ofertas activas del mismo pedido quedaban disponibles hasta expirar. La aceptación ahora cancela las ofertas hermanas y marca respuestas pendientes como rechazadas en la misma transacción; `ofertasActivas` omite pedidos no listos o ya asignados para limpiar también datos anteriores. Servicio 3/3 y build Nest OK. Falta E2E concurrente en PostgreSQL aislado y smoke autenticado con dos sesiones independientes; no se reinició la API viva ni hubo ofertas reales.
**Domicilios — selector de asignación (2026-11-23):** cuando realtime cambia la lista de repartidores libres, el formulario ahora vuelve a una selección vigente y “Asignar” envía ese ID. Se evita que un dropdown conserve selección removida o intente una asignación obsoleta. Widget 1/1 en cambio de disponibilidad y analyzer focalizado limpio. Build Equipo release recompilado directamente sin sincronizador; JS local y público HTTP 200, igual tamaño (6.518.046 bytes), y bundle incluye “Nuevo domiciliario”. Login Equipo y salud API 200; cloudflared y :3000/:8080/:8081 siguen activos. Sin reiniciar Nest ni tocar configuración/OAuth/datos. Avisos Wasm/CupertinoIcons no bloquearon JS.
**Arranque web del Tunnel (2026-11-24):** se trazó `scripts/iniciar1/LEEME.txt` → wrappers → `scripts/iniciar-foody-subdominios.bat` → `servir-web-tunel-release.ps1`. El error previamente compartido (falta `build/web_cliente` con `-SkipBuild`) corresponde a una versión que no coincide con el launcher actual: éste detecta artefactos faltantes/desactualizados y los compila. Cliente y Equipo quedaron recompilados directamente y más nuevos que el último cambio de fuente; bundles locales/públicos en 8081/8080 HTTP 200 e iguales en tamaño. API salud y panel públicos 200; Tunnel y puertos activos. No se ejecutó el relanzamiento completo: el script de serving sincroniza archivos de entorno y reemplaza los listeners actuales; OAuth, credenciales, secretos y datos no se tocaron. La salida del BAT completo queda pendiente de verificación en una ventana controlada.
**Arranque web — verificación real posterior (2026-11-24):** se ejecutó el atajo `scripts/iniciar1/iniciar-foody-subdominios.bat` con `FOODY_NOPAUSE=1`. Launcher detectó Cliente desactualizado, recompiló `web_cliente` sin el error previo de artefacto faltante y relanzó ambos servidores correctamente: Equipo PID 18944 en :8080 y Cliente PID 18876 en :8081. Cloudflared PID 11112 y Nest PID 7564 siguieron activos. Cliente/Equipo locales y públicos y API health HTTP 200. Build Cliente/Tunnel SHA `702F3FB36E4D5F93FD60C2154CBA37ADF781892B06806FB88F6DF325C98B3C7F` (6.538.285 bytes); Equipo/Tunnel SHA `21C90E666DB166C90EEFC41E1BD3605DB1CC94352DC4766AD59334A5F0E52421` (6.538.271 bytes). El log de sincronización informó “sin cambios”; no se modificaron OAuth, credenciales ni datos de negocio. Este smoke posterior reemplaza el estado “pendiente” de la entrada previa.
**Rangos locales de Reportes/Analítica (2026-11-23):** corregido `FIN-TZ-01`: SQL compartido convierte límites de fechas con `America/Bogota` en vez de heredar la TimeZone de PostgreSQL. QA PostgreSQL UTC probó límites diarios; Reportes financiero/productos y Analítica resumen/ventas respondieron correctamente. En lectura, P&L = tickets = SQL crudo (300.000 COP); caja neta fue 286.250 COP, diferencia esperable por universos y pendiente de FIN-DATE-01. Nest `:3000` no se reinició, por lo que la fuente/dist QA está lista y la activación queda pendiente de reinicio coordinado. `npm test -- --runInBand`: 10 suites/32 pruebas; E2E: 7/7 suites/14 pruebas; `npm run build` OK. La prueba de cocina restaura el producto seed mediante API al terminar, evitando contaminar mesa/QR.
**Actualización COC-NODISP-DOM-01 (2026-11-24):** barrera compartida en dispatch automático, asignación manual de planta, creación de ofertas y aceptación independiente. QA integrada en Nest :3001 + PostgreSQL `foody_diseno_qa`: flujo cocina→pedido `listo`→intento de asignación/oferta; ambas vías bloqueadas. E2E completo secuencial 8/8 suites, 16/16 pruebas; fixture restaurado (producto disponible, stock demo 10.000 g y horario 08:00–22:00). Nest :3000 no se reinició y Tunnel quedó activo; la barrera todavía no está cargada en ese proceso. La política comercial para ajustar/eliminar línea, aceptación parcial y abonos sigue pendiente.
**UX/RBAC de usuarios (2026-11-23):** `crear_pedido` se explica en UI como creación y operación (líneas/estados); a 320×568 el test detectó y validó fix de overflow del selector de rol. Flutter total 160 aprobadas/5 omitidas; analyzer focalizado limpio. Cliente/Equipo release reconstruidos usando configuración existente; cinco rutas locales/públicas HTTP 200 y bundle Equipo contiene el nuevo texto. API `:3000` y cloudflared siguen activos. No cambió permisos API ni OAuth/secretos/datos.
**Próxima prioridad:** definir reconocimiento de ventas/costo de delivery, compensación por pedido cancelado y disposición del producto faltante; probar ciclo pedido→cocina→domicilio→caja con BD QA aislada.
**Cierre técnico de la etapa 2026-11-23:** pago mixto del POS ahora compara contra `POST /pedidos/estimar`, sin escribir pedidos. Suite Flutter completa 159 aprobadas/5 E2E mutadoras omitidas; Nest 6 suites/23 pruebas + build. `iniciar-foody-subdominios.bat rebuild` reconstruyó Cliente y Equipo y conservó API :3000 y Tunnel; seis rutas locales/públicas dieron HTTP 200. El bundle servido incluye la recomendación actualizada de Caja; la pestaña Chrome observada aún mostraba copy anterior, por lo que requiere `Ctrl+F5`. Build JS normal OK; dry-run WASM avisa dependencias incompatibles, y falta fuente CupertinoIcons que no se detectó referenciada directamente en `lib/`. No se tocaron OAuth, credenciales ni datos de negocio.
**Verificación adicional (2026-11-23):** el iniciador real `scripts/iniciar1/iniciar-foody-subdominios.bat` completó con código 0: API, Equipo, Cliente y hosts públicos HTTP 200; Cloudflare ya estaba activo. El POS carga menú, mesas y caja en paralelo. Ayudas/prefills demo quedan solo en debug: búsquedas de seis cadenas negativas en ambos JS release. Suite Flutter completa 154 aprobadas/5 E2E mutadoras omitidas; 7 pruebas focalizadas del POS/login y análisis `--fatal-infos` limpio. No se reinició Nest ni se modificaron OAuth, credenciales o datos.
**Auditoría autenticada (2026-11-23):** se revisaron en lectura Análisis, Pedidos, Domiciliarios y Caja. Caja expone alerta de turno abierto longevo sin autocierre; el banner ahora orienta a revisar pedidos, mesas y domicilios antes del cierre, aunque no enlaza a cada pendiente. El backend bloquea por operación abierta o domicilio impago. No se cerró, arqueó ni cobró. En Análisis, “Pedidos activos” contaba la tabla reciente (máximo 15) y no estados operativos; la tarjeta ahora indica “Pedidos recientes”. “Ganancia est.” duplicaba el importe de margen bruto y ocultaba cobertura de costos; se reemplazó por la cobertura devuelta por API y el estado sin pedidos muestra “—”. “Fiado por cobrar” y “Pago a independientes” distinguen CxC de planta frente a pagos por liquidar; no se tocaron montos ni liquidaciones. Las pruebas UI focalizadas pasan, análisis `--fatal-infos` focalizado limpio y suite Flutter total 156 aprobadas/5 E2E mutadoras omitidas. El análisis global queda con 55 issues existentes (54 info + 1 warning, ninguno en archivos editados). Cliente/Equipo recompilados, seis rutas públicas/locales HTTP 200 y bundle Equipo confirma el copy final de Caja y Análisis. Pendiente: reconciliar métricas y cierre caja con datos QA aislados; Nest en memoria no se reinició.
**Revisión de Finanzas (2026-11-23):** se corrigió la variación porcentual de utilidad mal presentada también como variación de ventas y el overflow compacto del componente KPI. El snapshot financiero suma tickets válidos por fecha de creación (incluye pedidos pendientes/impagos), COGS por costo histórico y gastos registrados; obligaciones fijas/nómina sin pago se muestran como pendientes y todavía no se descuentan. El P&L necesita decisión sobre reconocimiento antes de cambiar fórmulas. Reportes/Analítica filtran movimientos ligados por fecha del pedido y los huérfanos por fecha del movimiento; queda `FIN-DATE-01` para definir si periodo de caja significa cohorte o flujo de dinero. Test Finanzas y suite completa: 157 aprobadas/5 E2E omitidas; analyzer focalizado limpio. Cliente/Equipo recompilados y seis rutas locales/públicas HTTP 200; API y Cloudflare no reiniciados. No se ejecutaron pagos ni escrituras reales. Evidencia y alcance: `docs/archivo/auditorias-prompts/AUDITORIA_REPORTES.md`.
**Entrega y cobro domiciliario (2026-11-23):** las apps de planta e independientes resolvían si pedir método al entregar mirando `metodo_pago`, aunque el backend ya admite abonos y calcula saldo. Se alinearon ambos listados para exponer saldo/reparto del helper servidor; selector y tarjeta usan ese estado, y tarjeta de planta deja de confundir subtotal bruto/total original con producto neto/saldo. No cambió imputación ni comisión y no se realizaron cobros. Backend 6 suites/23; Flutter 158/5 E2E omitidas; analyzer focalizado limpio; ambos release y seis rutas 200. El Nest vivo no se reinició, por lo que queda pendiente activar el nuevo contrato y probar flujos de abono con BD QA aislada. Evidencia: `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`, hallazgo `DOM-PAY-BALANCE-01`.
**POS y total de pago mixto (2026-11-23):** el hallazgo de discrepancia se corrigió en UI: el POS consulta `POST /pedidos/estimar` (debounce 300 ms), usa el total servidor y bloquea pago mixto cuando la cotización está pendiente/falla o los montos no son positivos y exactos. Flutter 7/7 y analyzer focalizado limpio; consulta directa API de estimación con producto demo devolvió total sin crear pedido ni escribir datos. El Nest sigue siendo autoridad en la creación final. No se creó pedido real. Pendientes: promoción activa y alta autenticada en BD QA aislada; idempotencia staff ante reintento/timeout y alcance multi-sede de las claves deben resolverse antes de ampliar retries. Cada cambio de carrito puede emitir una petición adicional; no se midió latencia. Ver `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md` y `docs/frontend/FOODY_PANEL_ADMIN_REDESIGN_MATRIX.md` (ADM-04).
**Rendimiento de alta de pedidos (2026-11-23):** evidencia estática adicional: Nest resuelve productos y cada extra mediante consultas `await` seriales dentro de la transacción; toppings/bebidas anidados no tienen tope explícito en el DTO. Es un riesgo de latencia/ocupación del pool en pedidos grandes, no una demora medida. Antes de optimizar, acordar límites de selección del catálogo; medir p50/p95 con BD QA y considerar lectura por lote conservando sucursal/disponibilidad. Detalle en `docs/AUDITORIA_RENDIMIENTO_PUNTA_A_PUNTA.md`.
**Idempotencia y aislamiento tenant (2026-11-23):** la clave de idempotencia de pedido tiene unicidad global, no se liga a sucursal ni a huella de payload; una repetición devuelve también el token de seguimiento asociado. Checkout actual usa UUID v4, así que se registra como riesgo de contrato/aislamiento condicionado a que se reutilice o adivine la clave, no como fuga reproducida. Diseñar alcance tenant+sede, verificación de payload y respuesta mínima antes de activar reintentos staff. Evidencia en `AUDITORIA_PEDIDOS_CICLO_VIDA.md`; no se consultaron pedidos vivos por clave.
**Doc cierre Nest/Auth:** [`REMEDIACION_NEST_AUTH_2026-08-07.md`](REMEDIACION_NEST_AUTH_2026-08-07.md)

---

## 📊 Resumen general del proyecto

| Métrica | Valor | Notas |
|---------|------:|-------|
| Módulos de negocio documentados | **23** | Ver fichas § Módulos |
| Módulos NestJS (`foody_backend/src/modulos/`) | **28** | incl. salud, pagos, almacenamiento, finanzas |
| Handlers HTTP (controllers) | **~221** | 37 archivos controller |
| Pantallas Flutter (`lib/features/`) | **37** | 26 carpetas feature |
| Pantallas legacy (`lib/screens/`) | **0** | Eliminado P3-03 (2026-07-01) |
| Migraciones SQL | **89** | `001`–`089` en `foody_supabase/migrations/` |
| Problemas abiertos (registro formal) | **1+AQ…+INF** | R5 · AQ…DK/INF-\* |
| Problemas resueltos (registro E2E/ops) | **31/32** | `REGISTRO_IRREGULARIDADES_FLUJOS.md` |
| Ítems roadmap pendientes | **4** | P0: 4 · P3: 1 (P3-06 VPS) |
| Escenarios negocio cubiertos | **123/131 ✅** | 1 ❌ (COC-015 offline) · 8 🟡 (DIAN/impresión) |

### Veredicto ejecutivo

Foody es un **POS multi-restaurante MVP avanzado (~74/100 arquitectura)** usable en demo y piloto controlado. La columna vertebral (pedido → stock → cocina → caja) está operativa. **No está listo para go-live masivo** sin: impresión física validada, RLS prod, VPS/Wompi prod, CI E2E y limpieza legacy.

**Stack fijo:** Flutter (solo UI) · NestJS + PostgreSQL · Supabase (Auth, Realtime broadcast, Storage) · FCM · Python impresión local.

---

## Leyenda de categorías

| Símbolo | Significado en este documento |
|---------|-------------------------------|
| ✅ | Implementado y funcional en dev |
| 🟡 | Implementado parcialmente |
| 🔴 | Pendiente (no existe o no usable) |
| 🔵 | Solo documentado / planificado, sin código |
| 🟣 | Problema detectado y **vigente** |
| 🟢 | Problema **resuelto** (con origen doc) |
| 🟠 | Mejora recomendada (no bloqueante) |

---

# ✅ Implementado

Funcionalidades que existen en código y cubren el flujo principal.

### Operación core
- Cliente: ciudad → restaurante → menú → carrito → checkout → seguimiento + **mis pedidos** (device_id + opcional Google) + **escaneo QR cámara**
- Pedido mesa QR: `/mesa/:qrToken`, aprobación mesero, cuenta acumulada, cobro, split por comensal
- Kanban pedidos por canal (mesa/llevar/domi), cards ricas, modal detalle, cerrados hoy
- Mesas: grid CRUD, QR, PDF/compartir, transferir, unir, reservar, turno mesas, panel mesero/cajero
- Caja: abrir/cerrar, movimientos, gastos, fiados, CxC avanzadas, arqueo ciego, cuadre en reportes, mensajes de error legibles al usuario
- Cocina: CRUD cocinas/impresoras, KDS por ítem, sonido, alerta >20 min
- Inventario: insumos, compras, ajustes, conteo, recetas, subrecetas, traslados, sync menú al cambiar stock
- Domiciliarios: planta + independientes, dispatch (auto-retry + radio), ofertas TTL config, GPS, documentos + app repartidor (ingresos/contacto/mapa)
- Zonas domicilio (Haversine/OSM), horarios sucursal, geografía Photon
- **Breakpoints operación unificados** (`FoodyBreakpoints` 720/1100) — POS/caja/costeo/mesas

### Admin / corporativo
- Panel admin con sidebar por permisos y plan; selector sede; multi-sucursal Fase 1–2 (**menú maestro / copiar sedes**)
- Dashboard sede + **consolidado cadena** + **gráficos** (`fl_chart`)
- Centro de Análisis — **Centro de Inteligencia** premium (SaaS UI kit, KPIs uniformes+sparklines, dual-series vs anterior, heatmap horario, preset Personalizado, insights/alertas, skeletons, fl_chart, FoodyBreakpoints); export PDF/CSV
- **ThemeMode** global Riverpod + SharedPreferences; toggle light/dark en AppBar panel admin (cliente queda light hasta pasada dedicada)
- Catálogo admin: productos, toppings, bebidas, combos, fotos Storage, precio local/llevar
- Costeo industrial: motor KYG, merma, empaques, subrecetas, producción lote, simulador ABC, editor receta P2-14, **recetas en bebidas/toppings (068)**
- Reportes: financiero, productos, pedidos, cuadre caja, **export PDF/CSV**
- Alertas automáticas + FCM nivel alto/crítico
- Usuarios staff: listar, crear, editar rol/nombre/sucursal, catálogo permisos por rol, activar/desactivar, rol `gerente_cadena`
- Super Admin → **Centro de Operaciones (NOC)** [`SUPERADMIN_FOODY_CONTROL.md`](SUPERADMIN_FOODY_CONTROL.md): ops base ✅ · **Fase A esencial** 📅 (KPI/semáforo/freemium/auditoría) · visión 10 módulos B/C
- FCM: cola, cron, web + móvil, deep link `notificationclick`

### SaaS / monetización (dev)
- Plan `gratis` + límites numéricos; `PlanFeaturesGuard` + paywall UI 403
- **UX-PAYWALL-BLUR ✅** — módulo fuera de plan: esqueleto estático difuminado + overlay CTA (0 API/Realtime); búsqueda admin lista candados
- Self-service F1–F7: registro público, Google OAuth, Wompi checkout/webhook, cobro recurrente, avisos vencimiento
- Auth JWT + guards (JWT → UsuarioActivo → Suscripción → Rol → SuperAdmin)

### Infra dev
- Docker Postgres dev, scripts `verificar-*`, Realtime broadcast + poll respaldo, health `/salud`
- Impresión: cola jobs, WebSocket agente Python, **modo archivo** sin hardware

---

# 🟡 Implementado parcialmente

| Área | Qué funciona | Qué falta |
|------|--------------|-----------|
| **Pedidos** | Transacción atómica, IVA, descuentos, propina POS+mesa, CxC desde «Pendiente» | DIAN real; impresión auto en prod; recibo cliente |
| **Mesas/QR** | Flujo completo demo | QA PDF QR en todos los dispositivos |
| **Cocina/impresión** | KDS + cola + agente | QA impresora térmica real (R5) |
| **Facturación** | Borrador HTML, emitir/anular | DIAN 🚫 pospuesto |
| **Self-service/Wompi** | F1–F7 + recurrente en código | Webhook HTTPS prod (P0-06/07) |
| **Producción/infra** | CI 5/5, RLS 064, Docker build, `/health` | Deploy VPS (P0-05) |

### Promovidos a ✅ (2026-07-30)
Menú admin · Reportes · Multi-sucursal · Usuarios staff · Super Admin → NOC Fase A 📅 · Analítica BI (~96%) · Panel breakpoints (FoodyBreakpoints / RS-20)

---

# 🔴 Pendiente

Ítems del roadmap y spec **sin implementación usable**.

### P0 — Go-live (residuales diferidos / cerrados piloto)
- P0-01 QA impresión térmica real — **diferido** (waiver archivo 2026-08-08)
- P0-05 API NestJS en VPS — **diferido** (piloto PC+túnel 2026-08-08)
- ~~P0-06 Webhook Wompi~~ ✅ dashboard 2026-08-08
- ~~P0-07 flujo pago sandbox~~ ✅ plan actualiza sin sync manual (founder 2026-08-08) · prod cuando Wompi apruebe cuenta

### P3 — Deuda técnica (2 abiertos; frontend pausado)
- P3-06 Deploy `docker-compose.prod.yml` en VPS (build local ✅)
- ~~P3-05, P3-08, P3-09~~ P3-09 ✅ · P3-05/08 pospuestos (Flutter)

### Otros pendientes técnicos
- Tokenización tarjeta Wompi (payment links no siempre guardan fuente)
- Email alertas críticas (opcional)
- Exigir 3 tipos documento aprobados antes activar domiciliario (mejora)
- KDS offline (🚫 pospuesto X-04)

---

# 🔵 Documentado pero no implementado

Ideas con spec escrita pero **sin código** o solo planificado.

| Tema | Documento origen | Estado |
|------|------------------|--------|
| Factura electrónica DIAN / proveedor FE | Sprint 9–11, X-01 | 🚫 pospuesto acuerdo comercial |
| Import Excel KYG costeos | `MODULO_COSTEO.md`, X-02 | 🚫 solo referencia fórmulas |
| App cocina APK separada | `foody-mismo-repositorio.mdc`, X-03 | Decisión: un `main.dart` |
| Google Maps en cliente | X-05 | Reemplazado por OSM + Photon ✅ |
| Vistas materializadas analítica F5 | `MODULO_ANALITICA_BI.md` | Planificado post-MVP |
| PM2 cluster + Redis | `OPTIMIZACION_ESCALABILIDAD_FOODY.md` | Solo con 100+ restaurantes |
| Menú maestro Fase 3 multi-sede | `MULTI_SUCURSAL.md` | Spec, sin UI |
| Restricciones tier Enterprise exclusivas (DIAN) | `PLANES_SUSCRIPCION.md` | Metadata; DIAN no existe |
| R2 Cloudflare imágenes prod | `OPTIMIZACION_ESCALABILIDAD_FOODY.md` | Pendiente primer pipeline prod |
| Winston + UptimeRobot | Optimización doc | Planificado prod |
| **Multi-negocio / tipo Treinta+** | [`multinegocio/`](multinegocio/README.md), [`PLAN_MULTINEGOCIO_FOODY.md`](PLAN_MULTINEGOCIO_FOODY.md) | 📅 Spec completa (visión, verticales, módulos, BD, UI, checklist). **No implementar** hasta post-P0 restaurante |

---

# 🟣 Problemas detectados (vigentes)

### Bugs / UX
| ID | Severidad | Problema | Estado |
|----|-----------|----------|--------|
| **R5** | Infra | Impresión física sin QA en hardware restaurante | 🟡 Código listo; falta validación |
| **R10** | Borde | Carrera stock entre 2 QR simultáneos — segundo falla al aprobar | 🟡 Aceptado por diseño |
| **KDS-RT-AUTH-01** | Alta | Admin/gerente con `ver_cocina` no recibían firma HMAC aunque la navegación y endpoints KDS lo autorizan | 🟡 Fuente corregida + tests 5/5; API :3000 requiere reinicio para activación y prueba autenticada |
| **Firebase web legacy** | Ruido | `CONFIGURATION_NOT_FOUND` en consola web (Tu Cancha Fácil) | 🟡 No bloquea Foody admin |
| **QA-E2E-CONTRACT-01** | Test | Los contratos Flutter intentaban cobrar con ítems de cocina pendientes y esperaban `listo` tras agregar ítems, contra VIE-01 documentado | ✅ Fixture recorre API de cocina; VIE-01 espera `en_cocina`; suite completa 111/111 |
| **UX-CAJA-MOV-RESP-01** | UX | Cabecera de Movimientos podía desbordar 7,5 px a 320 px al combinar texto y contador | ✅ Título acotado; apertura y turno activo pasan pruebas a 320/390/820/1440 |
| **UX-PLAN-CARDS-RESP-01** | UX | Etiqueta “Recomendado” del plan Pro desbordaba la fila del encabezado en 320 px | ✅ Insignia con salto de línea adaptable; prueba aislada a 320/390/820/1440, checkout sin ejecutar |
| **DART-ANALYZE-BASELINE-01** | Baja | `flutter analyze` repo-wide informa 56 diagnósticos (mayoría infos/deprecations; incluye helper sin uso en Horarios) | 🟣 Revisar y limpiar por grupos; las pantallas modificadas en este lote pasan análisis focalizado |
| **UX-POS-PAYMENT-FIELD-RESP-01** | UX | Dropdown Pago desbordaba 20 px a 820 px en el POS split | ✅ `isExpanded` usa el ancho del campo; test sintético 320/390/820/1440 |
| **UX-ALERTAS-FLUJO-01** | UX/Test | Las pruebas no confirmaban filtro, navegación al origen ni revisión de alertas | ✅ Cobertura con fake en memoria; suite global 150 aprobadas/5 E2E mutadoras omitidas |
| **RBAC-PEDIDOS-01** | Seguridad/API | Cobros y mutación de estado deben distinguirse de permiso de solo lectura | ✅ Cobros requieren `cobrar_pedido`; estado requiere `crear_pedido`; permisos granulares por transición siguen abiertos |

### Arquitectura / integración
| Problema | Detalle |
|----------|---------|
| Legacy dual path | ~~`lib/screens/`~~ eliminado P3-03; paquete `reserva_canchas` pendiente P3-05 |
| Paquete Dart `reserva_canchas` | Confusión onboarding; no bloquea runtime · **AQ-NAME-05** |
| RLS prod incompleto | ~~Migr. 064~~ ✅ local; aplicar en VPS con P0-05 |
| Wompi solo dev/local | Sin dominio HTTPS no hay monetización real |
| Paginación inconsistente | API pedidos pagina (`page`/`limit`); UI/reportes 🟡 — `RECOMENDACIONES_IMPLEMENTACION.md` OPT-04 |
| Caché menú | ✅ `MenuCacheService` TTL 15 min; 🟡 mejora thrash a escala (max ~200) · **AQ-SCALE-04** |
| Backups automáticos | Scripts ✅; cron+R2 en VPS 🟡 — `docs/BACKUPS_FOODY.md` |
| FCM reintentos infinitos | ✅ migr. `078` + abandono tras 10 intentos |
| Storage estados expirados | ✅ cron + `POST /promociones/admin/limpiar-expiradas` |

### Arquitectura / calidad (Prompt 01 — 2026-08-05)

> **Registro completo con IDs:** [`archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md`](archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md) (32 🟣/🟡 abiertos + 7 AQ-FIX).  
> Canvas: `canvases/arquitectura-calidad-codigo.canvas.tsx`. Predecesora jun-12 (C1–C5 ✅): `archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md`.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **AQ-DUP-01** | Alta | Stock duplicado: `InventarioService` vs `PedidosInventarioService` | ✅ `StockMovimientoService` (+ producción costeo 2026-08-07) |
| **AQ-CYCLE-01** | Alta | Ciclo Nest `pedidos ↔ domiciliarios` (`forwardRef`) | ✅ F7 hooks one-way |
| **AQ-SOLID-06/07** | Alta | Totales/precios calculados en Flutter (carrito, checkout, sheets) | ✅ F4 |
| **AQ-SOLID-08** | Alta | Fórmulas costeo Nest recalculadas en Dart | ✅ KPIs % desde API; preview líneas OK |
| **AQ-SCALE-01** | Prod | Pool PG default 10 (prod debe ≥25 documentado) | ✅ |
| **AQ-SCALE-02/05** | Prod | Crons líder único + rate-limit multi-réplica en Postgres (`rate_limit_entries`) | ✅ SQL compartido; 2026-11-23 se corrigió un `catch` que convertía el 429 en fallback local; spec 3 casos y build OK. Sin reiniciar :3000; verificar en la próxima ventana controlada. |
| **AQ-SCALE-03** | Media | N+1 menú combos (1 query combo_items + agrupar) | ✅ |
| **AQ-CYCLE-04** | Media | Pedidos staff + modelo en `features/pedidos/` (shim admin) | ✅ |
| **AQ-DUP-09** | Media | `AnaliticaTokens` en `core/tema/` (shim analitica) | ✅ |
| **AQ-SOLID-03** | Media | `AlmacenamientoController` con SQL + cache (controller gordo) | ✅ BN-FIX-01 |
| **AQ-DUP-04** | Media | Upload imagen ×4 copy-paste | ✅ `subirImagenEntidadCatalogo` |
| **AQ-NAME-05** | Baja | Package `reserva_canchas` (P3-05) | 🟣 |
| Controllers Nest delgados | — | Punto fuerte (almacenamiento ya delgado) | ✅ |
| Geografía/ciudades aislados | — | Bajo acoplamiento | ✅ |

**Backlog remediación (orden):** AQ-FIX-01 stock único → AQ-FIX-02 romper ciclo dispatch → ~~AQ-FIX-03 totales API~~ ✅ F4 → AQ-FIX-04 pool/cron/rate-limit → AQ-FIX-05…07 (Flutter ownership + tokens + batch SQL).

### Backend NestJS — estructura (Prompt 02 — 2026-08-05)

> **Registro completo con IDs:** [`archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md`](archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md) (BN-MOD/CTRL/DTO/EXC/PIPE + BN-FIX-01…06).  
> Solapes con Prompt 01: BN-CTRL-01 ≡ AQ-SOLID-03; god Pedidos ≈ AQ-SOLID-02.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **BN-CTRL-01** | Alta | `AlmacenamientoController` con SQL + UPDATE catálogo | ✅ service `subirImagenEntidadCatalogo` |
| **BN-DTO-03/04** | Alta | `POST /dispositivos/*` públicos sin DTO class-validator | ✅ DTOs `dispositivos.dto.ts` |
| **BN-EXC-01/02/05** | Alta | Fallos fuente Wompi / renovación | ✅ auditoria + log error + `renovaciones_fallos` |
| **BN-EXC-18** | Media | Encolado impresión tragado tras pedido OK | ✅ F5 parcial (job `error` en cola) |
| **BN-DTO-06…19** | Media | ~14 mutaciones staff con `@Body` inline | ✅ BN-FIX-03 |
| **BN-DTO-21/31** | Media | `CotizarDomicilioDto` huérfano | ✅ wired a `GET /zonas/cotizar-domicilio` |
| **BN-PIPE-03** | Media | ValidationPipe sin `forbidNonWhitelisted` | ✅ `main.ts` |
| **BN-DTO-01/02** | Media | Bodies FCM auth inline | ✅ `dto/fcm.dto.ts` |
| **BN-DTO-20/22/32** | Media | Query promo/geografía + bools CrearPedido | ✅ BN-FIX-04 |
| **BN-CTRL-02/03** | Media | Authz usuarios / traslados en controller | ✅ services |
| **BN-EXC-03/04** | Media | `pagos-recurrentes` TX/fuente parcial | ✅ throw sin source + error/`consulta_fallida` |
| **BN-DTO-23** | Media | Query timeline auditoría sin DTO | ✅ `TimelineAuditoriaDto` |
| **BN-DTO-24…27** | Baja–Media | Queries pedidos/costeo/upload/retorno-app | ✅ `verificar-bn-dto-query-rest.ps1` |
| **BN-DTO-28/33** | Baja | AprobarPedidoMesa · ParseUUIDPipe hot paths | ✅ `verificar-bn-residuales.ps1` |
| **BN-MOD-03** | Baja | `/salud` ligero · `/health` + `/salud/completo` profundo | 🟡 aceptado |
| **BN-PIPE-04** | Baja | enableImplicitConversion | 🟡 aceptado (`@Type` en DTOs) |
| **BN-MOD-05** | Media | SQL ventas reportes ↔ analitica ↔ dashboard | ✅ `compartido/sql/ventas-metricas.sql.ts` |
| Controllers delgados (mayoría) | — | Caja/mesas/pedidos/super-admin OK | ✅ |
| Filter + interceptor globales | — | `{exito,datos}` / errores unificados | ✅ |
| `core/caja` writer único | — | Frontera intencional | ✅ |

**Backlog remediación Nest (orden):** ~~BN-FIX-01…06~~ ✅ · ~~BN-DTO~~ ✅ · ~~BN-CTRL-02…12~~ ✅ · ~~BN-MOD-05~~ ✅ · ~~API-HTTP-01/02/04~~ ✅ · ~~API-PAGE~~ ✅ · ~~RBAC-MESERO-04 / RBAC-FIX-04~~ ✅. Lista: [`REMEDIACION_NEST_AUTH_2026-08-07.md`](REMEDIACION_NEST_AUTH_2026-08-07.md).

### Flutter — estructura (Prompt 03 — 2026-08-05)

> **Registro completo con IDs:** [`archivo/auditorias-prompts/AUDITORIA_FLUTTER_ESTRUCTURA.md`](archivo/auditorias-prompts/AUDITORIA_FLUTTER_ESTRUCTURA.md) (FL-STATE/WIDGET/LEAK/NAV/API + FL-FIX-01…07).  
> Solapes: FL-WIDGET-06 ≡ AQ-SOLID-06; F9-06 ≡ FL-STATE-01/02.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **FL-LEAK-01** | Alta | Diálogos inventario: TEC sin `dispose` | ✅ try/finally |
| **FL-STATE-01/02** | Alta | Riverpod solo carrito; sin estado compartido pedidos/mesas/caja | ✅ `operacionSucursalProvider` epoch |
| **FL-WIDGET-02** | Alta | `ref.watch(carrito)` rebuilda menú entero | ✅ `Consumer`+`select` barra |
| **FL-WIDGET-06** | Alta | Totales/precios calculados en UI (≡ AQ-SOLID-06) | ✅ F4 |
| **FL-NAV-01** | Alta | `go('/admin/cajero')` desde panel rompe back-stack | ✅ `push` mesas_grid |
| **FL-LEAK-02** | Media | Realtime `unsubscribe` sin `removeChannel` (~9 pantallas) | ✅ `FoodyRealtime.liberarCanal` |
| **FL-WIDGET-01** | Media | 15 pantallas/widgets >1k LOC (god screens) | 🟡 primer corte: `AsignarDomiciliarioSlot` |
| **FL-API-01** | — | Sin Dio crudo en widgets (repos OK) | ✅ |
| Paths GoRouter únicos | — | Sin rutas duplicadas | ✅ |

**Backlog remediación Flutter (orden):** FL-FIX-01 leaks inventario → FL-FIX-02 removeChannel → FL-FIX-03 select carrito → FL-FIX-04 nav cajero → FL-FIX-05 F9-06 Riverpod → FL-FIX-06 totales API → FL-FIX-07 split god screens.

### APIs REST — contrato HTTP (Prompt 04 — 2026-08-05)

> **Registro completo con IDs:** [`archivo/auditorias-prompts/AUDITORIA_APIS_REST.md`](archivo/auditorias-prompts/AUDITORIA_APIS_REST.md) (API-HTTP/VAL/PAGE/IDEM/FMT + API-FIX-01…06).  
> Solapes: API-VAL ≡ BN-DTO/PIPE; API-PAGE ≡ AQ-SCALE-07. Prefijo `API-*` ≠ `FL-API-*` (Flutter).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **API-HTTP-01/02** | Media | Creates 201 (pedidos/caja/usuarios/productos); conflictos caja/pedido → 409 | ✅ `verificar-api-http.ps1` |
| **API-VAL-02/03** | Alta | ParseUUID en rutas UUID residuales; DTOs públicos parcial | 🟡 |
| **API-PAGE-02** | Alta | Movimientos caja **sin** paginación (SELECT completo) | ✅ F6 |
| **API-PAGE-01/03/04** | Media | Pedidos opt-in; usuarios/catálogo/insumos con tope + page | ✅ `verificar-api-page.ps1` |
| **API-IDEM-02/03** | Alta | Cobro sin clave idempotencia; abrir caja TOCTOU | ✅ F1 |
| **API-IDEM-01/05** | — | Pedidos `idempotency_key` + Wompi replay OK | ✅ |
| **API-FMT-01** | — | Envelope `{ exito, datos\|error, mensaje }` global | ✅ |
| **API-FMT-06** | Media | Códigos 400 aplanados a `SOLICITUD_INVALIDA` | ✅ parcial (`CAJA_YA_CERRADA`/`PEDIDO_CERRADO`/`SIN_SALDO` preservados) |

**Backlog remediación API (orden):** API-FIX-01 paginación listas → ~~API-FIX-02 409~~ ✅ → API-FIX-03 idem cobro/caja → API-FIX-04 UUID+forbid → API-FIX-05 DTOs inline → ~~API-FIX-06 201 creates clave~~ ✅.

### Auth / JWT (Prompt 05 — 2026-08-06)

> **Registro completo con IDs:** [`archivo/auditorias-prompts/AUDITORIA_AUTH_JWT.md`](archivo/auditorias-prompts/AUDITORIA_AUTH_JWT.md) (AUTH-FLOW/EXP/REV/STORE/OTP + AUTH-FIX-01…06).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **AUTH-FLOW-01/02** | Alta | Refresh + logout server (`token_version` / claim `tv`) | ✅ |
| **AUTH-STORE-01** | Alta | JWT staff en SharedPreferences (no secure storage) | ✅ F4 |
| **AUTH-WEB-01** | Alta | Release web: `flutter_secure_storage` → MissingPluginException; login correo/Google no persistía JWT | ✅ prefs en `kIsWeb` + rebuild tunel |
| **AUTH-FB-01** | Baja | Consola: Identity Toolkit `CONFIGURATION_NOT_FOUND` (Firebase Auth no usado en staff; FCM/legacy) | 🟡 ruido; no bloquea Nest/Supabase login |
| **AUTH-REV-01** | — | Desactivar usuario → 401 en siguiente request (`UsuarioActivoGuard`) | ✅ |
| **AUTH-REV-02/03** | Media | Password/logout invalidan JWT vía `token_version` (mig `084`) | ✅ |
| **AUTH-EXP-01** | Media | Retry 1× tras refresh (AUTH-FIX-04); residual si JWT revocado | 🟡 **a pulir** |
| **AUTH-EXP-05** | Media | Refresh suave en Dio si `porExpirar` (ventana 30m); TTL default sigue 7d (`JWT_EXPIRACION`) | 🟡 **a pulir** (TTL prod) |
| **AUTH-OTP-01** | — | WhatsApp OTP **no implementado** | 🚫 / 📅 |
| **AUTH-FLOW-03/04** | — | Login roles + cliente `device_id` OK | ✅ |

**Backlog remediación auth (orden):** ~~AUTH-FIX-01~~ ✅ · ~~AUTH-FIX-03/04/05~~ ✅ · **a pulir:** AUTH-FIX-02 TTL corto prod (`JWT_EXPIRACION`) · AUTH-FLOW-05 re-emisión perfil · AUTH-FIX-06 OTP si producto. Detalle: [`REMEDIACION_NEST_AUTH_2026-08-07.md`](REMEDIACION_NEST_AUTH_2026-08-07.md) §3.2.

### RBAC — roles y permisos (Prompt 06 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_RBAC.md`](archivo/auditorias-prompts/AUDITORIA_RBAC.md) (RBAC-GUARD/MESERO/CAJA/TENANT + RBAC-FIX-01…07).  
> **Prod-risk abierto:** — (mesero cobro ✅ F2; IDOR caja ✅ F0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **RBAC-TENANT-01** | Crítica | `POST /caja/cerrar` cierra caja de otro restaurante por UUID | ✅ F0 |
| **RBAC-MESERO-01/02** | Alta | Mesero cobra (OR `ver_pedidos`/`crear_pedido`) | ✅ F2 |
| **RBAC-MESERO-03/04** | Alta/Media | `crear_pedido` también habilita edición de líneas y transiciones FSM; mesero queda limitado a `pagando`/`cancelado`; caja/admin pueden usar transiciones FSM | 🟡 UI ahora explica alcance; decisión sobre permisos separados pendiente / ✅ asignación domiciliario |
| **RBAC-GUARD-01/02/03** | Alta/Media | Posesión al anonimizar, push web propio y procesamiento global solo Super Admin | ✅; billing staff/job scopes parciales |
| **RBAC-MESERO-05** | — | Módulo `/caja/*` / catálogo / reportes bloqueados a mesero | ✅ |
| **RBAC-TENANT-02** | — | Spoof `sucursal_id` otro resto → 403 (scope) | ✅ |

**Backlog remediación RBAC (orden):** ~~RBAC-FIX-01 cerrar+sucursal~~ ✅ fuente + regresión unitaria; E2E cross-tenant pendiente → ~~RBAC-FIX-02 cobro permiso caja~~ ✅ → RBAC-FIX-03 estado/definir separación → ~~RBAC-FIX-04 domi~~ ✅ → ~~RBAC-FIX-05 anonimizar con prueba de posesión~~ ✅ → RBAC-FIX-06 billing staff / RBAC-FIX-07 escrituras y scopes de jobs.

### BD / Supabase self-hosted (Prompt 07 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_BD_SUPABASE.md`](archivo/auditorias-prompts/AUDITORIA_BD_SUPABASE.md) (BD-RLS/IDX/FK/N1/BKP + BD-FIX-01…07).  
> Solapes: N+1 ≡ AQ-FIX-07; backups ≡ OPS-02.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **BD-RLS-01** | — | RLS ENABLE+FORCE en 73/73 tablas (deny-all) | ✅ |
| **BD-RLS-02** | Media | Sin policies por tenant — aislamiento = NestJS | 🟡 |
| **BD-FK-01** | — | DELETE producto con pedidos históricos → FK bloquea (no CASCADE) | ✅ |
| **BD-IDX-01/02** | Alta | Faltan índices `cajas` / `movimientos_caja` | ✅ F6 |
| **BD-N1-01…03** | Alta | N+1 menú combos, clone, stock (≡ AQ-SCALE-03) | ✅ |
| **BD-BKP-01** | Prod | Backup auto VPS/cron+R2 **no activado** | 🟣 |

**Backlog remediación BD (orden):** BD-FIX-01 backups VPS → BD-FIX-02 índices caja → BD-FIX-03/04 N+1 batch → BD-FIX-05 doc rol PG → BD-FIX-06/07 soft-delete/combo FK.

### Docker / variables de entorno (Prompt 08 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_DOCKER_ENV.md`](archivo/auditorias-prompts/AUDITORIA_DOCKER_ENV.md) (DK-COMPOSE/SEC/HC/RST/LOG + DK-FIX-01…07).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **DK-LOG-01** | Prod | Rotación logs Docker (json-file max-size/max-file) aplicada en `docker-compose.prod.yml` | ✅ |
| **DK-SEC-03** | Prod | Validador prod rechaza JWT default / TTL largo (`validar-config-produccion`) | ✅ |
| **DK-COMPOSE-04** | Alta | Compose+Dockerfile **en workspace**; falta `git add` en commit | 🟡 |
| **DK-RST-01** | — | `restart: unless-stopped` OK | ✅ |
| **DK-HC-01/02** | — | Healthchecks Nest + Postgres dev OK | ✅ |
| **DK-COMPOSE-02** | — | Nest sin volumen (stateless) OK | ✅ |

**Backlog remediación Docker (orden):** DK-FIX-01 logging → DK-FIX-02 JWT gate → DK-FIX-03 commit+dockerignore → DK-FIX-04 bind localhost → DK-FIX-05 vols Supabase → DK-FIX-06/07 Dockerfile/CI.

### Infra Hetzner / Nginx / Cloudflare (Prompt 09 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_INFRA.md`](archivo/auditorias-prompts/AUDITORIA_INFRA.md) (INF-NGX/R2/TUN/SSL/DISK + INF-FIX-01…07).  
> Fase 0 = PC+Tunnel; VPS P0-05 abierto.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **INF-TUN-01/03** | Prod | WiFi/PC: tunnel foreground; VPS service no instalado | 🟣 |
| **INF-DISK-01/02** | Prod | Logs Docker con tope (≡ DK-LOG-01); presupuesto disco VPS sigue pendiente | 🟡 |
| **INF-NGX-01** | Alta | Nginx no en repo — edge = Cloudflare Tunnel (aceptado Fase 0) | 🟡 |
| **INF-R2-02/03** | Media | Storage write policies flojas; R2 backups no activado | 🟣 |
| **INF-SSL-01** | — | HTTPS Cloudflare (renovación automática CF) | ✅ |
| **INF-R2-01** | — | `foody-assets` público = intencional (menú) | 🟡 |

**Backlog remediación infra (orden):** INF-FIX-01 VPS+systemd tunnel → INF-FIX-02 logs/disco → INF-FIX-03 R2 privado → INF-FIX-04 plantilla Nginx → INF-FIX-05 Storage policies → INF-FIX-06/07 WiFi test + df.

### Realtime y sincronización (Prompt 10 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_REALTIME.md`](archivo/auditorias-prompts/AUDITORIA_REALTIME.md) (RT-CHAN/SEC/RECON/POLL/FALL/LIFE/LEAK/ENV/SCRIPT + RT-FIX-01…09).
> 16 pares emisor→oyente verificados en ejecución con `scripts/verificar-realtime-canales.js`.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **RT-CHAN-01** | Crítica | `catalogo_disponibilidad` emitido en `sucursal_{id}`; menú cliente y POS escuchaban `sucursal_{id}_catalogo` → suscripción muerta | ✅ |
| **RT-SEC-01** | Alta | Canales no privados: QR → UUID + anon oía caja | ✅ HMAC topics 2026-08-08 (`verificar-rt-sec.ps1`) |
| **RT-RECON-01** | Alta | Socket reconecta y re-une topics OK, pero broadcast sin replay y sin refetch al reconectar | ✅ F1 (refetch; sin replay) |
| **RT-POLL-01** | Media-Alta | Poll reevalúa salud RT cada ciclo (90s/30s) | ✅ |
| **RT-FALL-01** | Media | Poll en menú, POS, panel y domi planta | ✅ |
| **RT-LIFE-01** | Media | Refetch en `AppLifecycleState.resumed` pantallas ops (F1) | ✅ |
| **RT-LEAK-01** | Media | 9 pantallas exactas con `unsubscribe` sin `removeChannel`; agrava reconexión (≡ FL-LEAK-02 / AQ-SCALE-06) | ✅ F7 `FoodyRealtime.liberarCanal` |
| **RT-ENV-01** | Media | Una sola `SUPABASE_URL` en `.env` + nota en `.env.example` | ✅ |
| **RT-SCRIPT-01** | Baja | `verificar-realtime.ps1` leía `salud.datos.realtime` (campo solo en `/health`) | ✅ lee `/health` |
| **RT-ORPH-01** | — | Sin eventos huérfanos ni oyentes sin emisor | ✅ |
| Consistencia 2 dispositivos | — | BD converge (`FOR UPDATE` + máquina de estados); UI = convergencia eventual ≤90 s | 🟡 |

**Backlog remediación realtime (orden):** RT-FIX-01 canales privados/JWT → RT-FIX-02 refetch al reconectar → RT-FIX-03 poll adaptativo → RT-FIX-04 poll en menú/POS/panel → RT-FIX-05 refetch en `resumed` → RT-FIX-06 removeChannel → RT-FIX-07 `.env` → RT-FIX-08 script salud → RT-FIX-09 KDS incremental.

### Pedidos — ciclo de vida (Prompt 11 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`](archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md) (PED-PREPAGO/BYPASS/COBRO/EDIT/CHECK/DOC + PED-FIX-01…05).
> Verificado con `scripts/verificar-pedidos-ciclo-vida.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **PED-PREPAGO-01** | Alta | Pedido para llevar totalmente cobrado puede seguir `en_cocina` hasta que KDS resuelva ítems | ✅ F0: saldo cero excluido del bloqueo de cierre; cocina lo cierra como `pagado` al terminar |
| **PED-BYPASS-01** | Media | `salio-sin-pagar` UPDATE fuera de command FSM | ✅ 2026-08-08 vía `PedidosEstadoCommandService` |
| **PED-COBRO-SKIP-01** | Media | Origen `cobro` permite saltar a `pagado` desde `en_cocina` (intencional caja) | 🟡 aceptado |
| **PED-EDIT-01** | Media | Ítems editables post-cocina (hasta terminal); merma+alerta si ya preparando/listo | 🟡 aceptado |
| **PED-CHECK-01** | Baja | CHECK `pedidos.estado` (mig 089) | ✅ |
| **PED-DOC-01** | Baja | `FLUJO_ESTADOS_PEDIDOS.md` aún muestra `entregado` en salón | ✅ |
| **PED-INV-01** | — | PATCH Kanban rechaza transiciones inválidas | ✅ |
| **PED-FLOW-01** | — | Ciclo mesa `en_cocina→listo→pagando→pagado` stock/caja/mesa OK | ✅ |

**Backlog de pedidos:** PED-FIX-01 prepago y PED-FIX-02 salida sin pago cerrados; PED-FIX-04 CHECK SQL (migración 089) incorporado. PED-FIX-05 edición durante `pagando` requiere decisión de permisos/operación antes de restringir.

### Cocina / KDS (Prompt 12 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_COCINA_KDS.md`](archivo/auditorias-prompts/AUDITORIA_COCINA_KDS.md) (COC-NODISP/CANCEL/UI-PRIO/FSM/REIMP + COC-FIX-01…05).
> Verificado con `scripts/verificar-kds.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **COC-NODISP-01** | Alta | N/D ahora cuenta resuelto y permite `listo`; en domicilio el dispatch puede adelantarse al ajuste de la línea (ver COC-NODISP-DOM-01) | ✅ corrección original; seguimiento abierto |
| **COC-CANCEL-01** | Media | Cocina no puede DELETE ítem (404); cancelación real = DELETE staff + merma | 🟡 |
| **COC-UI-PRIO-01** | Media | API prioridad OK; Flutter KDS no llama ni muestra botón Urgente | ✅ F7 KDS + repo |
| **COC-FSM-01** | Baja | Sin máquina de estados en ítem (salto pendiente→listo OK) | 🟡 |
| **COC-REIMP-01** | Baja | `POST /impresion/reimprimir` + botón KDS (copia N; sin térmica física) | ✅ |
| **COC-RT-01** | — | Pedido nuevo → tickets KDS + comanda_copia + canal RT | ✅ |
| **COC-ORDER-01** | — | FIFO backend + sort urgencia/tiempo en Flutter | ✅ |
| **COC-FLOW-01** | — | Todos listo → pedido `listo` | ✅ |

**Backlog remediación cocina:** COC-FIX-01 no_disponible → COC-FIX-02 UI urgente/reimprimir → COC-FIX-03 UX cancelación cocina → COC-FIX-04 FSM ítem → COC-FIX-05 endpoint reimprimir.

### Caja (Prompt 13 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_CAJA.md`](archivo/auditorias-prompts/AUDITORIA_CAJA.md) (CAJ-SYNC/MIXTO/REOPEN/CANCEL/CIERRE/DOM + CAJ-FIX-01…03).
> Verificado con `scripts/verificar-caja-ciclo.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **CAJ-SYNC-01** | — | Cobro = `pedidos.total` en `movimientos_caja` (tope anti-doble) | ✅ |
| **CAJ-MIXTO-01** | — | Efectivo+tarjeta → N ventas + `pagos_pedido` | ✅ |
| **CAJ-REOPEN-01** | — | Pedido `pagado` no se reabre (correcto) | ✅ |
| **CAJ-CANCEL-01** | — | Cancel sin cobro no mueve caja; prepago → devolución = venta | ✅ |
| **CAJ-CIERRE-01** | — | Cuadre + alerta diferencia; bloqueo operación abierta | ✅ |
| **CAJ-DOM-IMPAGO-01** | Media | Domicilio entregado parcial bloquea cierre (by design; demo acumulaba 7) | 🟡 aceptado |
| **CAJ-MSG-01** | Baja | Filter conserva detalle de `CAJA_CIERRE_OPERACION_ABIERTA` | ✅ |
| **CAJ-TURNO-01** | Baja | `horas_abierta` + alerta `caja_turno_longevo` (>12 h, sin auto-cierre) + banner UI | ✅ |

**Backlog remediación caja:** CAJ-FIX-01 mensaje cierre detallado → CAJ-FIX-02 turno longevo → CAJ-FIX-03 UI bloqueadores de cierre.

### Inventario (Prompt 14 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_INVENTARIO.md`](archivo/auditorias-prompts/AUDITORIA_INVENTARIO.md) (INV-AUTO/PROP/ALERT/AUD + INV-FIX-01…03).
> Verificado con `scripts/verificar-inventario-ciclo.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **INV-AUTO-01** | — | Descuento automático al cocina; gap “solo manual” cerrado | ✅ |
| **INV-PROP-01** | — | Insumos←subreceta←plato propaga descuento | ✅ |
| **INV-ALERT-01** | — | `stock_minimo_alcanzado` tras venta ≤ mínimo | ✅ |
| **INV-ALERT-FCM-01** | Media | Stock bajo nivel medio → sin FCM (solo panel/RT) | 🟡 |
| **INV-ALERT-AJUSTE-01** | Baja | PATCH ajuste dispara `stock_minimo_alcanzado` | ✅ |
| **INV-AUD-01** | Media | Movimientos exponen `usuario_id` / `usuario_nombre` | ✅ |

**Backlog remediación inventario:** INV-FIX-01 exponer quién en movimientos → INV-FIX-02 FCM/nivel stock bajo → INV-FIX-03 alerta tras ajuste.

### Meseros / Mesas (Prompt 15 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_MESEROS_MESAS.md`](archivo/auditorias-prompts/AUDITORIA_MESEROS_MESAS.md) (MES-ASIG/XFER/SPLIT/RACE + MES-FIX-01…04).
> Verificado con `scripts/verificar-meseros-mesas.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **MES-ASIG-01** | — | Turno + bloqueo otra mesera | ✅ |
| **MES-XFER-01** | — | Transfer pedido activo + historial | ✅ |
| **MES-SPLIT-01** | — | Split cobro post-cocina (mismo pedido) | ✅ |
| **MES-RACE-01** | — | FOR UPDATE serializa adds concurrentes | ✅ |
| **MES-SPLIT-HIJO-01** | Media | No hay pedido hijo / mover ítems | 🟡 |
| **MES-XFER-MESERA-01** | Baja | Transfer copia mesera origen→destino | ✅ |
| **MES-XFER-UI-01** | Baja | Transfer UI admin+cajero (`cobrar_pedido`) | ✅ |
| **MES-MSG-01** | Baja | Códigos mesa preservados (no `SOLICITUD_INVALIDA`) | ✅ |

**Backlog remediación mesas:** MES-FIX-01 códigos error → MES-FIX-02 heredar mesera transfer → MES-FIX-03 pedido hijo (si producto) → MES-FIX-04 CTA mesero.

### Domicilios (Prompt 16 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_DOMICILIOS.md`](archivo/auditorias-prompts/AUDITORIA_DOMICILIOS.md) (DOM-FLOW/STATE/CANCEL + DOM-FIX-01…04).
> Verificado con `scripts/verificar-domicilios-ciclo.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **DOM-FLOW-01** | — | Flujo planta + cobro al entregar | ✅ |
| **DOM-SKIP-01** | — | Bloqueo `listo→entregado` | ✅ |
| **DOM-STATE-01** | — | `ocupado` admin coherente en ruta | ✅ |
| **DOM-CANCEL-01** | — | Admin cancela mid-ruta; asignación `cancelado` | ✅ |
| **DOM-CANCEL-WHO-01** | — | Cliente/domi no cancelan mid-ruta | ✅ |
| **DOM-CANCEL-INDEP-01** | Media | Cancel restaura `sesiones.disponible` indep | ✅ |
| **DOM-CANCEL-OFERTA-01** | Baja | Cancel cierra `ofertas_pedido` activas | ✅ |
| **DOM-EVID-01** | Baja | Sin foto/comprobante de entrega | 🟡 |

**Backlog remediación domicilios:** DOM-FIX-01 liberar sesión indep → DOM-FIX-02 ofertas → DOM-FIX-03 RT indep → DOM-FIX-04 evidencia (opcional).

### Clientes / QR (Prompt 17 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_CLIENTES_QR.md`](archivo/auditorias-prompts/AUDITORIA_CLIENTES_QR.md) (QR-FLOW/PRICE/TOKEN + QR-FIX-01…04).
> Verificado con `scripts/verificar-qr-cliente.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **QR-FLOW-01** | — | Pedido público QR → `pendiente_aprobacion` | ✅ |
| **QR-PRICE-01** | — | Precio body ignorado; BD manda | ✅ |
| **QR-PROD-01** | — | Producto off/ajeno rechazado | ✅ |
| **QR-TOKEN-01** | — | Token permanente; libre no invalida | ✅ |
| **QR-MULTI-01** | — | Varios pendientes mismo QR | ✅ |
| **QR-AUTO-01** | Media | No hay autoservicio sin aprobación mesero | 🟡 aceptado |
| **QR-MESA-ID-01** | Media | `tipo=mesa` sin `mesa_id` → 400 `MESA_REQUERIDA` | ✅ |
| **QR-EXP-01** | Baja | Sin auto-rechazo continuo (solo cierre caja >30m) | 🟡 |

**Verificación QR-MESA-ID-01 (2026-11-23):** Nest suite completa 18/18 suites y 48/48 tests; la regresión específica cubre pedido público, staff y estimación (3/3), todos rechazados antes de consultar BD. `POST /pedidos/estimar` contra el Nest activo :3000 devolvió HTTP 400 `MESA_REQUERIDA` sin crear pedido. `scripts/verificar-qr-cliente.ps1` actualizado para detectar aceptación como regresión; sintaxis PowerShell validada, pero no se ejecutó porque contiene otras escrituras QA.

**Backlog remediación QR:** ~~QR-FIX-01 exigir mesa_id~~ ✅ (validado para pedido público, staff y cotización; prueba `pedidos-crear-mesa-requerida.spec.ts` 3/3) → QR-FIX-02 autoservicio opcional → QR-FIX-03 auto-rechazo → QR-FIX-04 rotar token.

### Promociones / Precios (Prompt 18 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_PROMOCIONES.md`](archivo/auditorias-prompts/AUDITORIA_PROMOCIONES.md) (PROMO-SNAP/STACK + PRECIO-SNAP + PROMO-FIX-01…04).
> Verificado con `scripts/verificar-promociones-precios.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **PROMO-SNAP-01** | — | Desactivar promo no recalcula pedido abierto | ✅ |
| **PRECIO-SNAP-01** | — | Ítem abierto conserva precio; cobro = snapshot | ✅ |
| **PRECIO-ADD-01** | — | Ítem nuevo usa catálogo actual | ✅ |
| **PROMO-ONE-01** | — | Máx. 1 promo; auto elige la mejor | ✅ |
| **PROMO-STACK-01** | Media | Combo + promo se apilan (sin exclusión) | 🟡 |
| **PROMO-DEL-01** | Baja | DELETE promo: `ON DELETE SET NULL` en pedidos (mig 089) | ✅ |
| **PROMO-MANUAL-01** | Baja | Descuento manual limpia `promocion_id` | ✅ |

**Backlog de decisiones promos:** definir si combo excluye/apila promoción y si un pedido abierto conserva el beneficio en líneas agregadas tras desactivar la promo. PROMO-DEL-01 (`ON DELETE SET NULL`), PROMO-MANUAL-01 (limpieza de `promocion_id`) y CONS-PROMO-ADD-01 (recalcular al cambiar líneas) están resueltos en fuente; verificación integrada cubre agregar con promo activa, y falta ampliar delete/update y desactivar→agregar.

### Facturación DIAN/MATIAS (Prompt 19 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_FACTURACION.md`](archivo/auditorias-prompts/AUDITORIA_FACTURACION.md) + pausa [`FACTURACION_ELECTRONICA_PAUSADA.md`](FACTURACION_ELECTRONICA_PAUSADA.md).
> Verificado con `scripts/verificar-facturacion-ciclo.ps1` (exit 0 — capa local).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **FE-PAUSE-01** | — | Módulo DIAN/proveedor pausado X-01 | 🚫 |
| **FE-MATIAS-01** | Alta* | Cero integración MATIAS en repo | 🚫 |
| **FE-QUEUE-01** | Alta* | Sin cola/reintentos | 🚫 |
| **FE-ERR-01** | — | Errores locales (config/pagado) OK | ✅ |
| **FE-CONS-01** | — | total factura = total pedido | ✅ |
| **FE-ITEMS-01** | Media | Sin líneas de ítems en documento | 🟡 |
| **FE-NC-01** | Alta* | Nota crédito = stub; anular no toca pedido | 🚫 |

\*Al retomar go-live. Backlog: FE-FIX-01 cliente+estados → FE-FIX-02 cola → FE-FIX-03 ítems UBL → FE-FIX-04 NC real.

### Reportes / Analítica / Alertas (Prompt 20 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_REPORTES.md`](archivo/auditorias-prompts/AUDITORIA_REPORTES.md).  
> Verificado con `scripts/verificar-reportes-analitica.ps1` (exit 0 — API vs BD).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **REP-BD-01** | — | Financiero/resumen = SQL crudo | ✅ |
| **REP-LINE-01** | Baja | Header ticket vs ranking línea+extras | 🟡 |
| **ANA-FILT-01** | — | Filtros analítica AND combinables | ✅ |
| **ANA-FILT-PROD-01** | Media | Filtro producto/categoría/cocina: KPI y series = suma de líneas | ✅ |
| **REP-FILT-01** | Baja | Reportes solo fechas | 🟡 |
| **ANA-ESTADOS-01** | Media | `estados` omite cancelado/rechazado salvo `incluir_cancelados` | ✅ |
| **ANA-PERF-01** | Media | Demo OK; Seq Scan; sin MV; N+1 sedes | 🟡 |
| **ALT-UMB-01** | — | Umbrales = spec | ✅ |
| **ALT-BATCH-01** | — | Batch ≠ stock/cuadre (evento) | ✅ |
| **ALT-DOC-01** | Baja | Doc batch incompleto → actualizado | ✅ |

**Backlog:** ANA-FIX-01 carga 50k · ANA-FIX-02 comparativa sedes · ALT-FIX-01 E2E umbral vivo.

### Dashboard general (Prompt 21 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_DASHBOARD.md`](archivo/auditorias-prompts/AUDITORIA_DASHBOARD.md).  
> Verificado con `scripts/verificar-dashboard-general.ps1` (exit 0 — ventas_hoy = financiero = analítica 187200).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **DASH-RT-01** | Media | Sin Realtime/poll; snapshot hasta refresh | ✅ poll 75s Inicio |
| **DASH-RT-02** | Media | Banner RT puede hacer creer que Inicio también auto-refresca | ✅ copy banner + «no en vivo» |
| **DASH-FRESH-01** | Media | Sin hora «Actualizado»; Reportes sí | ✅ HH:mm en header |
| **DASH-CACHE-01** | — | Sin cache Nest; GET = SQL vivo | ✅ |
| **DASH-ORPH-01** | Baja | `pedidos_pendientes_qr` en API, no en UI KPI | ✅ KPI QR → Mesas |
| **DASH-ORPH-02** | Media | KPI Ventas hoy → Caja (debería Reportes/Analítica) | ✅ → Reportes |
| **DASH-ORPH-03** | Baja | Top «por unidades» pero ORDER BY ventas | ✅ ORDER BY cantidad |
| **DASH-ORPH-04** | Baja | Copy «misma lectura que Análisis» sin mismo endpoint | ✅ «Tendencia sede (7d)» |
| **DASH-CONS-01** | — | ventas_hoy = reportes = analítica (hoy demo) | ✅ |
| **DASH-TZ-01** | Media-Alta | `created_at::date` vs Bogota en resumen/mix (riesgo noche CO) | ✅ F6 |
| **DASH-CONS-TOP** | Baja | Top dash=$ vs reportes=cantidad | ✅ alineado cantidad |
| **DASH-CONS-COMP** | Baja | KPI etiquetado «Cerrados hoy» (≠ tickets financiero) | ✅ |
| **DASH-CONS-PERIOD** | Baja | Reportes default 7d vs KPI hoy | 🟡 |

**Backlog residual:** DASH-PERIOD (si aplica).

### Configuración restaurante (Prompt 22 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_CONFIGURACION.md`](archivo/auditorias-prompts/AUDITORIA_CONFIGURACION.md).  
> Verificado con `scripts/verificar-config-restaurante.ps1` (exit 0).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **CFG-GLOBAL-DEAD** | Alta | Runtime lee `configuracion_global_foody` (umbrales + dispatch) | ✅ F3 |
| **CFG-PATCH-SUCURSAL-01** | Media | `PATCH /sucursales/:id` + UI Editar sede (nombre/dir/tel/activa) | ✅ |
| **CFG-MARGEN-UI-02** | Media | Márgenes sede en BD sin UI/API write | ✅ |
| **CFG-NOMBRE-MARCA-07** | Baja | `PATCH /sucursales/marca` admite nombre/teléfono + UI | ✅ |
| **CFG-POLIGONO-03** | Baja | `poligono` deprecado (COMMENT mig 088); cobertura = Haversine | 🟡 |
| **CFG-CACHE-MARCA-04** | Baja | Listado ciudad SQL vivo (sin caché Nest que invalidar) | 🟡 |
| **CFG-HORARIO-CACHE-08** | — | Horario invalida menú cache | ✅ |
| **CFG-IVA-PEDIDO-09** | — | IVA fiscal vivo en create | ✅ |
| **CFG-PLAN-API-10** | — | Guard plan lee BD | ✅ |
| **CFG-PLAN-UI-11** | Baja | Sidebar tras upgrade via `perfil` | 🟡 |
| **CFG-PLAN-FACT** | Info | Fiscal 403 plan demo (enterprise) | 🟡 |
| **CFG-REALTIME-06** | Info | Sin RT config (pull) | 🟡 |

**Backlog:** (CFG-FIX-01 cerrado vía F3). Residual: CFG-PLAN-UI.

### Performance backend (Prompt 23 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_PERF_BACKEND.md`](archivo/auditorias-prompts/AUDITORIA_PERF_BACKEND.md).  
> EXPLAIN + `scripts/verificar-perf-backend.ps1` + RunspacePool 10/50/200 (0 fails; p50 degrada).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **PERF-IDX-01** | Alta | `movimientos_caja` solo PK; `idx_scan=0` (≡ BD-IDX-02) | ✅ F6 |
| **PERF-SQL-01** | Alta | `SQL_PEDIDO_ES_HOY` ahora usa rango half-open (sin `created_at::date`) | ✅ |
| **PERF-SQL-02** | Alta | `SQL_VENTA_LINEA_ITEM` correlacionado: optimizado en dashboard + reportes/productos; analítica y otros endpoints pueden seguir | 🟡 |
| **PERF-SQL-04** | Alta | reportes caja: `COALESCE` reemplazado por filtros `OR` (evita no-sargable) | ✅ |
| **PERF-LOAD-02/03** | Alta | p50 3.7–10 s a 50–200 conc.; techo ~8–20 RPS | 🟣 |
| **PERF-POOL-01** | Alta | Pool default 10 si falta `DB_POOL_MAX` (≡ AQ-SCALE-01) | ✅ |
| **PERF-N1-01** | Alta | Menú combos N+1 (≡ BD-N1-01 / AQ-SCALE-03) | ✅ |
| **PERF-CACHE-02/03** | Media | Ciudades TTL 3 min · dashboard resumen TTL 30 s | ✅ |
| **PERF-CACHE-05** | Alta | Cache in-memory max 200 (≡ AQ-SCALE-04) | 🟡 |
| **PERF-SQL-03** | Media | Top productos drive desde `pedidos` (idx sucursal) | ✅ |
| **PERF-LOAD-01** | — | 0 errores HTTP en 10/50/200 | ✅ |
| **PERF-CACHE-01** | — | Menú TTL 5 min funciona | ✅ |

**Backlog:** PERF-FIX-01 índices caja · PERF-FIX-02 rangos fecha · PERF-FIX-03 batch venta línea · PERF-FIX-04 batch combos · PERF-FIX-05/06 caché ciudades/dashboard · PERF-FIX-07 pool prod.

### Performance Flutter (Prompt 24 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_PERF_FLUTTER.md`](archivo/auditorias-prompts/AUDITORIA_PERF_FLUTTER.md).  
> Estático + `scripts/verificar-perf-flutter.ps1`. Gap: heap DevTools 8 h.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **PERF-FL-LIST-07** | Alta | Caja movimientos unbounded + shrinkWrap anidado | ✅ max 80 + viewport 420 |
| **PERF-FL-MEM-01** | Alta | Realtime `unsubscribe` sin `removeChannel` (~9 pantallas) ≡ FL-LEAK-02 | ✅ re-audit liberarCanal |
| **PERF-FL-IMG-01** | Alta | 0 `memCacheWidth`/`Height` en features | ✅ menú+admin+costeo/promo/sedes |
| **PERF-FL-LIST-01** | Media | Kanban grid = `Wrap` eager | ✅ `ListView.builder` por filas |
| **PERF-FL-LIST-05/08** | Media | Insumos/catálogo con tope/page API (≡ API-PAGE) | ✅ |
| **PERF-FL-MEM-03/05/06** | Media | Pulso mesas solo si hay ocupadas (1.2s); `_movimientos` tope 80 en memoria | ✅ |
| **PERF-FL-IMG-03/06** | Media | `flutter_image_compress` sin uso; admin `Image.network` | 🟡 `cacheWidth` admin |
| **PERF-FL-LIST-03/04/06/09** | — | Cerrados/mis pedidos/movs inv/mesas OK | ✅ |
| **PERF-FL-IMG-04** | — | Nest sharp WebP ≤800 en upload | ✅ |

**Backlog:** PERF-FL-FIX-01 paginar caja · FIX-02 removeChannel · FIX-03 memCache thumbs · FIX-04 kanban builder · FIX-05 dispose conteo.

### Seguridad OWASP (Prompt 25 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_OWASP.md`](archivo/auditorias-prompts/AUDITORIA_OWASP.md).  
> Checks: `verificar-owasp.ps1` · `verificar-rls.ps1` (74/74) · `verificar-idor-scope.ps1` OK.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **SEC-BAC-01** | Crítica | IDOR cerrar caja UUID ajeno ≡ RBAC-TENANT-01 | ✅ F0 |
| **SEC-BAC-02** | Alta | Mesero cobra vía OR ver_pedidos ≡ RBAC-MESERO | ✅ F2 |
| **SEC-BAC-03/04** | Alta | anonimizar con posesión · prueba-web `@Permisos` (F3) | ✅ |
| **SEC-SECRET-01/02** | Alta | JWT fallback / example ≡ DK-SEC (validador prod) | ✅ |
| **SEC-BAC-06** | Media | Mutaciones finanzas → `gestionar_finanzas` (mig 087) | ✅ |
| **SEC-RLIMIT-01** | Baja | RL NO-OP fuera prod (CI); `RATE_LIMIT_FORZAR=1` para QA | 🟡 |
| **SEC-RLIMIT-03** | Media | `@RateLimitPublico` en menú/ciudades/geografía | ✅ |
| **SEC-INJ-*** | — | Raw SQL parametrizado; `${suc}` = `$N` | ✅ |
| **SEC-RLS-01** | — | 74/74 RLS+FORCE (era 73; +empleados) | ✅ |
| **SEC-BAC-07** | — | Spoof sucursal_id otro resto → 403 | ✅ |
| **SEC-SECRET-03** | — | `config/foody-entorno.env` → `.gitignore` | ✅ |

**Backlog:** SEC-FIX-01…08 (caja IDOR → cobro → anonimizar → JWT → RL → finanzas).

### Estrés / concurrencia (Prompt 26 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_ESTRES_CONCURRENCIA.md`](archivo/auditorias-prompts/AUDITORIA_ESTRES_CONCURRENCIA.md).  
> Checks: `verificar-estres-concurrencia.ps1` (exit 0, aviso caja) · `estres-1000-usuarios.mjs` 100×3 + 10 writes.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **CONC-CAJ-ABRIR-01** | Alta | Abrir caja check-then-insert TOCTOU ≡ API-IDEM-03 | ✅ F1 |
| **CONC-LOAD-LAT-01** | Alta | Mixto 100×3 p99~10 s (cola Nest/pool) ≡ PERF-LOAD | 🟣 |
| **CONC-LOAD-POOL-01** | Alta | Techo pool/Nest single-process | 🟣 |
| **CONC-INV-LOCK-01** | Media | `exigirIngrediente` con `FOR UPDATE` | ✅ |
| **CONC-CAJ-COBRO-01** | Media | Cobro FOR UPDATE OK; sin idempotency key ≡ API-IDEM-02 | ✅ F1 |
| **CONC-MT-01/02** | — | Multi-sede lecturas 60/60 OK; dashboards 200 | ✅ |
| **CONC-PED-IDEM-01** | — | Idempotency 2× → 1 pedido | ✅ |
| **CONC-PED-EST-01** | — | Doble `en_cocina`: FOR UPDATE + no-op; stock 1× | ✅ |
| **CONC-INV-ABS-01** | — | 2 PATCH absolutos → LWW sin valor corrupto | ✅ |
| **CONC-LOAD-OK-01** | — | 0 errores HTTP sostenido/pico/writes lab | ✅ |

**Backlog:** CONC-FIX-01 unique caja abierta · FIX-02 FOR UPDATE ingredientes · FIX-03 PERF pool/índices · FIX-04 idem cobro.

### Fuzz inputs (Prompt 27 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_FUZZ_INPUTS.md`](archivo/auditorias-prompts/AUDITORIA_FUZZ_INPUTS.md).  
> Check: `verificar-fuzz-inputs.ps1` (45 casos, exit 0, avisos=6).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **FUZZ-500-UUID-01** | Media | UUID/path basura → 500 ERROR_INTERNO (debería 400) | ✅ F7 parcial `ParseUUIDPipe` menú/caja/pedidos/cocina |
| **FUZZ-LEN-01** | Media | `@MaxLength(80)` en nombre mesa (crear/actualizar) | ✅ |
| **FUZZ-PAGE-01** | Baja | `PaginacionQueryDto` Min(1)/Max(100); clamp listado | ✅ |
| **FUZZ-ANON-01** | — | anonimizar device junk → 200 ≡ SEC-BAC-03 | 🟡 |
| **FUZZ-STABLE-01** | — | API no cae post-fuzz | ✅ |
| **FUZZ-STACK-01** | — | 0 stack traces en respuesta cliente | ✅ |
| **FUZZ-ENVELOPE-01** | — | 5xx envelope genérico sin paths | ✅ |
| **FUZZ-VAL-01** | — | Bodies inválidos → 400 (login/pedidos/caja…) | ✅ |

**Backlog:** FUZZ-FIX-01 ParseUUIDPipe · FIX-02 MaxLength textos · FIX-03 clamp page · FIX-04 auth anonimizar.

### Funcionalidad huérfana (Prompt 28 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_FUNCIONALIDAD_HUERFANA.md`](archivo/auditorias-prompts/AUDITORIA_FUNCIONALIDAD_HUERFANA.md).  
> Base: [`MAPA_FOODY.md`](MAPA_FOODY.md). Método: cruce estático Nest ↔ Flutter (sin click-through dispositivo).

| ID | Sev | Hallazgo | Fix | Estado |
|----|-----|----------|-----|--------|
| **HUER-PERM-01** | Alta | Tab Rentabilidad sin gate `ver_finanzas` (API 403) | CONECTAR | ✅ F3 |
| **HUER-CFG-02** | Alta | Super edita `configuracion_global_foody` sin efecto runtime (= CFG-GLOBAL-DEAD) | COMPLETAR/OCULTAR | ✅ F3 |
| **HUER-HALF-01** | Alta | Facturación DIAN pausado sin claim legal (sin “Resolución DIAN” en HTML/PDF) | COMPLETAR | ✅ |
| **HUER-API-COC-01** | Media | `PATCH …/prioridad` sin UI KDS (= COC-UI-PRIO-01) | CONECTAR | ✅ F7 |
| **HUER-API-COC-02** | Media | `PATCH …/observaciones` KDS sin UI | CONECTAR/DEPRECATE | ✅ F7 |
| **HUER-API-COST-01/02** | Media | Costeo combos GET+recalcular sin Flutter | CONECTAR | ✅ |
| **HUER-API-DOM-01** | Media | `GET /domiciliarios/ganancias` sin UI indep. | UI_NUEVA | ✅ 2026-08-08 tab Ingresos |
| **HUER-UI-01** | Media | Badge «No disponible» `onTap: () {}` menú admin | OCULTAR/CONECTAR | ✅ |
| **HUER-REPO-03** | Media | `actualizarCostoFijo` con diálogo editar | COMPLETAR | ✅ |
| **HUER-CFG-01** | Media | Márgenes sede BD sin API/UI write (= CFG-MARGEN-UI-02) | UI_NUEVA | ✅ |
| **HUER-REPO-01** | Baja | `costosProductos` repo muerto | DEPRECATE | ✅ |
| **HUER-DB-01/02** | Baja | Tablas `presentaciones_compra` / `ajustes_stock` sin Nest | DEPRECATE | ✅ |
| **HUER-OPS-*** | — | health/impresión/notif/webhook | OPS intencional | ✅ N/A |

**Backlog fix:** COC prioridad → costeo combos → ganancias domi → limpia repos/legacy (PERM/CFG ✅ F3).

### Consistencia entre módulos (Prompt 29 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_CONSISTENCIA_MODULOS.md`](archivo/auditorias-prompts/AUDITORIA_CONSISTENCIA_MODULOS.md).  
> Rutas: Pedido→Cocina→Caja→Inv→Análisis · Meseros→Pedidos→Cocina · Promo→Pedido→Caja · Inv→Productos→Cocina · Caja→Reportes · Config→Todos.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **PED-PREPAGO-01** | Alta | Prepago permanece en flujo cocina; verificar cierre solo si saldo pendiente | ✅ F0 cerrado: saldo cero no bloquea; cocina termina en `pagado` |
| **COC-NODISP-01** | Alta | N/D cocina impide pedido `listo` | ✅ F0 |
| **CFG-GLOBAL-DEAD** | Alta | Config super → runtime vía `ConfiguracionGlobalService` | ✅ F3 |
| **CONS-STOCK-CASCADE-01** | Alta | Venta solo off el producto línea; hermanos con mismo insumo siguen on | ✅ F2 |
| **CONS-NODISP-STOCK-01** | Media | N/D cocina: merma (VIE-09 C) + `productos.disponible=false` + RT catálogo | ✅ |
| **CONS-KDS-UI-01** | Media | Pedido → `listo` cuando todos ítems `listo\|no_disponible` (COC-NODISP) | ✅ |
| **CONS-PROMO-ADD-01** | — | Add/delete/update ítems recalcula % promo (monto fijo limitado al subtotal) | ✅ |
| **CONS-REP-OPEN-01** | Media | Etiquetas tickets vs cobrado + `nota_universos` en API/UI | ✅ |
| **CONS-COSTO-SNAPSHOT-01** | Media | Canon: COGS=`pi.costo_unitario`; inv=`costo_actual`; ledger sync al editar qty | ✅ |
| **CONS-CUADRE-SQL-01** | Media | Script cuadre alineado a `ventas-metricas.sql` (neto+filtros) | ✅ |
| **CONS-SCRIPT-01** | Baja | Script coherencia llamaba `/caja/estado` 404 | ✅ fixed script |
| **RT-RECON-01** / **DASH-RT/TZ** | Alta/Media | UI desfasada entre pantallas | ✅ F1 refetch / ✅ F6 DASH-TZ |

**Checks:** salud OK · caja-coherencia OK · inventario-ciclo OK · promos OK · coherencia KPI 438175 · cuadre FAIL (esperado por universos).

### Viralización / spike de registros (Prompt 32 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_VIRAL_SPIKE.md`](archivo/auditorias-prompts/AUDITORIA_VIRAL_SPIKE.md).  
> Flujo real: `POST /auth/registro-restaurante` + TX multi-INSERT + bcrypt; **sin** OTP WhatsApp / MATIAS / FCM bienvenida Nest.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **VIRAL-CPU-01** | Prod | bcrypt rounds via `BCRYPT_ROUNDS` (8–12, default 10) | 🟡 |
| **VIRAL-POOL-01** | Prod | TX más corta (horarios/zona post-commit) · pool sigue techo | 🟡 |
| **VIRAL-SYNC-01** | Alta | Onboarding aún síncrono HTTP (sin cola pendientes) | 🟣 |
| **VIRAL-DEG-01** | Alta | Flag + cupo diario + max/min + UI waitlist | ✅ |
| **VIRAL-SIDE-01** | Prod | Cupo/flag mitiga spike; mismo nodo aún compartido | 🟡 |
| **VIRAL-RL-01** | Alta | RL IP + techo global `REGISTRO_MAX_POR_MINUTO` | 🟡 |
| **VIRAL-OTP/FE/FCM** | Info | OTP/MATIAS/bienvenida Nest no existen hoy | 🚫/🟡 |
| **VIRAL-META-01** | 📅 | Si OTP Meta: tier 250 falla Día 1 | 📅 |

**Línea tiempo:** D1 500 = degradación si burst · D2 5k = colapso onboarding+riesgo ops · D3–D4 20k–40k = outage.  
**Escalar primero:** waitlist/cola → Redis → PgBouncer → Nest réplicas → PG dedicado.  
**Roadmap F0–F7** en el doc (métricas + triggers).

**Backlog:** ~~FIX-01 flag/cupo~~ ✅ · FIX-02 cola pendientes · ~~FIX-03 defer horarios~~ ✅ · ~~FIX-04 RL global~~ 🟡 · ~~FIX-05 bcrypt rounds~~ 🟡 · FIX-06 runbook · FIX-07 OTP cola · FIX-08 pool separado.

### E2E automatizado (Prompt 33 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_E2E_AUTOMATIZADO.md`](archivo/auditorias-prompts/AUDITORIA_E2E_AUTOMATIZADO.md).  
> Jest/Supertest (API viva) + Flutter `test/e2e` + wrapper `integration_test`. Flujos: mesa, QR, domicilio, cocina, caja + VIE/CONS 28–30.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **E2E-SUITE-01** | — | 7 suites Jest (14) + 5 Flutter VM | ✅ |
| **E2E-STUB-01** | Baja | Stub Nest Hello World reemplazado por `/salud` | ✅ |
| **E2E-VIE-01-COV** | Alta | Regresión VIE-01 (expect `en_cocina` tras add) | ✅ F0 |
| **E2E-GAP-UI-01** | Media | Sin click-through pantallas Flutter | 🟣 |
| **E2E-FL-DEVICE-01** | Baja | `integration_test -d windows` necesita NuGet | 🟡 |
| **E2E-LIVE-01** | Info | Tests contra API viva (no Nest in-process) | 🟡 |
| **E2E-CI-01** | Media | GH Actions no corre Jest E2E (seed BD) | 🟣 |

**Checks:** `verificar-e2e-jest.ps1` ✅ · `verificar-e2e-flutter.ps1` ✅.

### Infra extremos (Prompt 34 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_INFRA_EXTREMOS.md`](archivo/auditorias-prompts/AUDITORIA_INFRA_EXTREMOS.md).  
> Timeout mid-TX · doble submit · API caída · reconexión/resync. Solapa API-IDEM / RT-RECON / VIE-12.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **INFRA-EXT-TO-01** | Alta | Timeout Dio mid-TX: Nest puede COMMIT; retry UX confusa | ✅ F1 (GET post-timeout) |
| **INFRA-EXT-TO-02** | Media | Dio `sendTimeout` (= `timeoutEnvio`) | ✅ |
| **INFRA-EXT-UI-01/02** | Media | Cobro mesa/kanban sin busy flag | ✅ F1 |
| **INFRA-EXT-UI-03** | Baja | KDS `_itemsEnVuelo` + `_conLockItem` (doble tap) | ✅ |
| **INFRA-EXT-DBL-01** | — | 2× cobrar paralelo → 1 OK / 1 reject | ✅ |
| **INFRA-EXT-DOWN-01/02** | Media | Banner API offline + splash no entra a panel si API caída | ✅ |
| **INFRA-EXT-SYNC-01** | Alta | Post-caída sin re-sync (= RT-RECON/LIFE, VIE-12) | ✅ F1 |
| **INFRA-EXT-MSG-01** | — | Mensajes timeout/conexión OK | ✅ |

**Vivo:** `verificar-infra-extremos.ps1` ✅ (doble cobro + host muerto ~2s).  
**Backlog:** FIX-01 GET tras timeout cobro · FIX-02 busy UI · API-FIX-03 · RT-FIX-02/05 · FIX-03 splash/salud · FIX-04 sendTimeout.

### Informe maestro (Prompt 35 — 2026-08-06)

> **Documento:** [`INFORME_MAESTRO_FOODY.md`](INFORME_MAESTRO_FOODY.md) — consolidación Prompts 01–34.  
> Plan F0–F8 por impacto ops restaurante; §6 CAP/VIRAL = decisiones infra/$$ (no bugfix).

| Fase | Foco | Horas ord. |
|------|------|------------|
| **F0** | ✅ IDOR caja · PED-PREPAGO · VIE-01 · COC-NODISP | 0 |
| **F1** | ✅ RT refetch · timeout cobro · busy UI · unique caja · idempotency | 0 |
| **F2** | ✅ cobrar_pedido · cascade stock · mesero ≠ listo | 0 |
| **F5** | Impresora + VPS + Wompi | 24–56 |
| **F8** | Escala/viral (§6) | plan $$ |

### Capacity planning / crecimiento masivo (Prompt 31 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_CAPACITY_PLANNING.md`](archivo/auditorias-prompts/AUDITORIA_CAPACITY_PLANNING.md).
> Baseline vivo: Nest **1 proceso**, `DB_POOL_MAX=25`, PG **`max_connections=100`** / `shared_buffers=128MB`, ~44 backends demo; techo lab ~8–20 RPS (PERF/CONC).

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **CAP-INFRA-01** | Prod | Piloto = 1 nodo; compose documenta réplicas (no PM2 obligatorio) | 🟡 |
| **CAP-POOL-01/02** | Prod | Pool Nest vía `DB_POOL_MAX` (≥25 doc); falta PgBouncer | 🟡 |
| **CAP-LOAD-01** | Alta | 200 conc → p50 7–10 s (≡ PERF-LOAD) | 🟣 |
| **CAP-CACHE-01** | Alta | Cache max 200 thrash (≡ AQ-SCALE-04) | 🟡 |
| **CAP-GROW-01** | Alta | Cron purga cola FCM enviada/abandonada >14d | ✅ |
| **CAP-GROW-02** | Media | Cron purga `auditoria_logs` >90d | ✅ |
| **CAP-SQL-01** | Alta | Cast fecha / COALESCE caja / SubPlan: parcial (PERF-SQL-01/04 ✅ · 02 🟡 · 03 abierto) | 🟡 |
| **CAP-MOD-01 / EP-01** | Alta | Caen primero dashboard/menú/reportes + cocina RT | 🟣 |
| **CAP-FL-01** | Media | Caja tope + kanban builder (≡ PERF-FL-LIST) | ✅ |
| **CAP-PROC-01 / FE-01** | Info | WhatsApp/MATIAS no cargan hoy (no impl.) | 🟡 |

**Veredicto escala:** 100 = piloto parcial · 500+ = no sin PgBouncer/PM2/Redis · 1k+ = réplica lectura + partición · 5k–10k = multi-nodo.

**Backlog:** CAP-FIX-01 índices/SQL · FIX-02 pool VPS · FIX-03 purge notif · FIX-04 retención auditoría · FIX-05 Redis · FIX-06 PM2 tras Redis · FIX-07 réplica · FIX-08 Flutter listas · FIX-09 partición · FIX-10 cola MATIAS/FCM.

### Casos viernes alta demanda (Prompt 30 — 2026-08-06)

> **Registro completo:** [`archivo/auditorias-prompts/AUDITORIA_CASOS_VIERNES.md`](archivo/auditorias-prompts/AUDITORIA_CASOS_VIERNES.md).  
> Perspectiva operador; **DECISIÓN_PENDIENTE** = no inventar regla (opciones A/B/C).

| ID | Clase | Sev | Hallazgo | Estado |
|----|-------|-----|----------|--------|
| **VIE-01** | BUG | Alta | Add ítems con pedido `listo` → estado no baja a `en_cocina` | ✅ F0 |
| **VIE-05** | REGLA | Alta | Abono libre; `pagado` solo cocina completa o admin+motivo (**C**) | ✅ |
| **VIE-09** | REGLA | Alta | Fallo prep → N/D + merma + alerta (**C**) | ✅ |
| **VIE-13** | REGLA | Alta | Misma política cobro que VIE-05 (**C**) | ✅ |
| **VIE-12** | BUG | Alta | Reconnect sin refetch (= RT-RECON) | ✅ F1 |
| **VIE-QTY-01** | REGLA | Media | Prohibir qty↓ en preparando/listo; DELETE+merma (**C**) | ✅ |
| **VIE-02/03/04** | REGLA | — | Off catálogo / transfer / race FOR UPDATE | ✅ |
| **VIE-06/07/08** | REGLA | — | No reopen pagado; snapshots precio/promo | ✅ |
| **VIE-10/11** | REGLA | — | Cola impresión + pedidos en PG sobreviven restart | ✅ |

**Vivo:** pedidos-ciclo · meseros · promos · kds OK.

### Documentación (meta-problemas)
| Contradicción | Documentos | Resolución |
|---------------|------------|------------|
| Empaques/subrecetas «faltan» | `MODULOS_ESTADO.md` §6 vs §9 | **✅ Resuelto** en código P2-14 |
| Self-service «faltan F1–F3» | `MODULO_SELF_SERVICE_PLANES.md` | **✅ F1–F7** en código |
| Paywall «⏳» | `PLANES_SUSCRIPCION.md` | **✅ P1-09** |
| 8 escenarios ❌ | `ESCENARIOS_NEGOCIO_FOODY.md` | **✅ P2-21/22** — 1❌ restante (COC-015) |
| Tablas sprint AVANCE | Histórico jun-06 | **Referencia**; resumen 1 min = estado vivo |

---

# 🟢 Problemas resueltos

Problemas documentados que **ya están corregidos** en código.

| ID / Tema | Origen doc | Resolución |
|-----------|------------|------------|
| R1 Mesa liberada sin cobro | `archivo/auditorias-prompts/AUDITORIA_FLUJOS_E2E.md`, `REGISTRO_*` | 2026-06-19 — bloqueo `entregado` en mesa |
| R2 `estado_operativo` desincronizado | Idem | 2026-06-19 — sync en crear/cobro |
| R3 Domicilio `listo`→`entregado` sin repartidor | Idem | 2026-06-19 |
| R4 Ajuste inventario no propagaba menú | Idem | 2026-06-19 — `CatalogoDisponibilidadService` |
| R6 Transferencia sin auditoría | Idem | 2026-06-24 |
| R7 Race transferencia mesa | Idem | 2026-06-24 — `FOR UPDATE` |
| R8 Dispatch no auto-asignaba planta | Idem | 2026-06-24 |
| R9 Realtime silencioso sin env | Idem | 2026-06-24 — health + poll respaldo |
| R11 KDS regresaba a `confirmado` | Idem | 2026-06-19 / F-06 2026-06-24 |
| R12 Cobro domicilio al entregar | Idem | 2026-06-24 |
| R13 Cierre caja con operación abierta | Idem | 2026-06-24 — `CAJA_CIERRE_OPERACION_ABIERTA` |
| F01–F16 Auditoría operativa 2026-06-24 | `REGISTRO_IRREGULARIDADES_FLUJOS.md` | 15/15 ✅ |
| A01–A04 Deuda transversal backend | Idem | 4/4 ✅ |
| C1–C5 Críticos arquitectura | `archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md` | 2026-06-12 |
| I1–I7 Importantes arquitectura | Idem | Mayoría ✅; FCM/impresión eran ⏳, ahora 🟡 |
| Cobro mesa sin `movimientos_caja` | `ANALISIS_SISTEMA.md` | C1 auditoría ✅ |
| Sin KDS / sin cocinas CRUD | `ANALISIS_SISTEMA.md`, `PLAN_COMPLETAR_FOODY.md` | Bloque 1 ✅ migr. 026 |
| IVA siempre 0 | `ANALISIS_SISTEMA.md` | Bloque 2 ✅ migr. 027 |
| POST /mesas 401 ruido consola | Sesión 2026-06-28 | Probe → `GET /salud` |
| QR mesa congela web (LayoutBuilder) | Sesión 2026-06-28 | `Dialog` + `SizedBox` fijo en `_mostrarQr` |
| DioException crudo al cerrar caja | Sesión 2026-06-28 | `mostrarErrorSnackBar` + filtro HTTP preserva `CAJA_*` |
| Antigravity P0 bugs freemium | `walkthrough-antigravity.md` | 2026-06-24 |

---

# 🟠 Mejoras recomendadas (priorizadas)

> Spec completa: **`docs/RECOMENDACIONES_IMPLEMENTACION.md`** (matriz ✅/🟡/⏳).

### Alta — antes de go-live
1. ~~**OPS-05** UptimeRobot~~ ✅ monitor Up (2026-08-03)
2. ~~**OPS-03** Webhook Wompi~~ ✅ dashboard + pago sandbox E2E (2026-08-08)
3. **OPS-01 / P0-05** Comprar VPS + Fase 1 (`PREPARACION_VPS.md`) · cron R2 — **diferido**; piloto PC+túnel OK

### Media — backend / escala
4. **OPS-02** Cron + R2 en VPS (scripts listos; Windows Task Scheduler ya activo)
5. ~~OPT-04/05~~ ✅ paginación UI + poll RT

### Baja / pausado
6. **P3-05** Rename paquete · **P3-08** Animaciones
7. Winston · ~~Realtime JWT (OPS-07)~~ ✅ HMAC topics · Redis/R2 CDN (📅 100+ sedes)

> FCM-02, STOR-01, OPT-04, OPT-05 ✅ (2026-08-01). Spec: `RECOMENDACIONES_IMPLEMENTACION.md`.

---

# 📌 Estado de cada módulo

## 1. Cliente (pedir + historial)
| Campo | Valor |
|-------|-------|
| **Objetivo** | Descubrir restaurante, pedir (sin cuenta o con Google), seguir e historial |
| **Estado** | ✅ ~92% |
| **Implementado** | Ciudad, menú, carrito, checkout, seguimiento, mis pedidos (device_id + Google → `auth_uid`), QR mesa, escanear (Analítica + pegar + sesión activa), promos, domicilio+mapa, cancelar, llamar mesera |

| **Faltante** | Click-through Google en dispositivo real (redirect Supabase) |
| **Dependencias** | API pública, `device_id`, Realtime, Supabase Auth Google |
| **Riesgos** | Legacy Firebase en web (ruido consola) |

## 2. Pedidos y checkout
| Campo | Valor |
|-------|-------|
| **Objetivo** | Crear y gestionar pedidos con integridad financiera y stock |
| **Estado** | 🟡 ~90% |
| **Implementado** | POST atómico, IVA, zonas, descuentos, estados v2, propina, split, cobro, **Fase 2: PATCH ítem + Cambiar producto (agregar→quitar, también último ítem)**, combos con toppings/bebidas extra, POS menú con bebidas vendibles, CTA avance + mesero + Copia N, tabs+grid, reasignar domi, items_resumen, fiado CxC, **UX kanban/grid Analítica** (KPIs, chips/tabs ink, cards urgencia, CTA ink/Listo verde) |
| **Faltante** | DIAN; impresión auto prod; recibo cliente; DnD kanban / propina multi-mesero |
| **Dependencias** | Inventario, caja, mesas, cocina |
| **Riesgos** | R10 carrera stock QR (aceptado) · cierre en `pagado` ocurre al resolver cocina; prueba específica de cierre de caja con prepago aún pendiente en QA |

## 3. Mesas y QR
| Campo | Valor |
|-------|-------|
| **Objetivo** | Gestión piso, QR cliente, cobro cuenta |
| **Estado** | 🟡 ~90% |
| **Implementado** | Grid, CRUD, QR+PDF, transferir, unir, reservar, turno, aprobación, split; pedido público QR → `pendiente_aprobacion`; precio server-side |
| **Faltante** | Autoservicio sin mesero (no existe); `mesa_id` obligatorio en QR; auto-rechazo continuo; rotar token |
| **Dependencias** | Pedidos, Realtime, FCM |
| **Riesgos** | Bajo · **QR-MESA-ID-01** · **QR-AUTO-01** · cross **RT-SEC-01** / **R10** |

## 4. Panel admin y multi-sucursal
| Campo | Valor |
|-------|-------|
| **Objetivo** | Operación staff por sede y cadena |
| **Estado** | ✅ ~90% |
| **Implementado** | Sidebar permisos/plan, selector sede, scope API, dashboard consolidado, gráficos, `gerente_cadena`, búsqueda + favoritos, **FoodyBreakpoints / RS-20**, **UI Horarios + Mis sucursales alineadas a Analítica** |
| **Faltante** | Discoverability favoritos (affordance) — menor |
| **Dependencias** | Auth, sucursal scope |
| **Riesgos** | Bajo |
| **Nav UX** | Ciclo 1 NAV-ADM ✅ · ciclo 2 **NAV-ADM2** 22/24 ✅ · breakpoints ADM2-06/24 ✅ |

## 5. Caja
| Campo | Valor |
|-------|-------|
| **Objetivo** | Turno caja, movimientos, fiados, cierre |
| **Estado** | ✅ ~95% |
| **Implementado** | Abrir/cerrar, gastos de turno, fiados, CxC, arqueo ciego, cuadre reportes, bloqueo cierre operación abierta, UX errores, CAJ-019, **CAJ-021**, pagos mixtos N movimientos, tope venta≤total pedido |
| **Faltante** | Mensaje cierre detallado (CAJ-MSG-01); alerta turno longevo |
| **Dependencias** | Pedidos pagos |
| **Riesgos** | Bajo · **CAJ-DOM-IMPAGO-01** (domicilio entregado parcial bloquea cierre deliberadamente); prueba aislada de caja requerida tras cambios del proceso Nest |

## 6. Menú / catálogo admin
| Campo | Valor |
|-------|-------|
| **Objetivo** | CRUD productos, precios canal, fotos |
| **Estado** | ✅ ~95% |
| **Implementado** | CRUD completo, fotos Storage, precio llevar, selector cocina, enlace costos, **copiar menú entre sedes (P2-18)**; **UI Menú alineada a Centro de Inteligencia** (filtros riesgo, tokens, responsive) |
| **Faltante** | — |
| **Dependencias** | Catálogo NestJS, Storage |
| **Riesgos** | Bajo |

## 7. Cocina / KDS / impresoras
| Campo | Valor |
|-------|-------|
| **Objetivo** | Preparación cocina + tickets impresos |
| **Estado** | 🟡 ~78% |
| **Implementado** | CRUD, KDS ítem, cola impresión, agente Python, modo archivo, RT `cocina_{id}`, prioridad API `[URGENTE]`, `comanda_copia` |
| **Faltante** | **QA hardware R5** · UI urgente/reimprimir · fix `no_disponible`→pedido listo |
| **Dependencias** | Pedidos, impresoras BD |
| **Riesgos** | **COC-NODISP-01** pedido trabado · **Alto** sin impresión física (R5) |

## 8. Inventario
| Campo | Valor |
|-------|-------|
| **Objetivo** | Stock, compras, recetas, sync menú |
| **Estado** | ✅ ~95% |
| **Implementado** | Descuento **automático** al cocina (`stock_descontado`); expansión subrecetas; insumos/compras/ajustes/conteo/traslados; alerta `stock_minimo_alcanzado`; sync catálogo; UI Insumos Analítica |
| **Faltante** | `usuario_id` en API/UI movimientos (INV-AUD-01); FCM stock bajo opcional; alerta tras ajuste manual |
| **Dependencias** | Costeo, pedidos |
| **Riesgos** | Bajo · **INV-AUD-01** (quién no visible en UI) |

## 9. Costeo industrial (KYG)
| Campo | Valor |
|-------|-------|
| **Objetivo** | Costos, márgenes, precios sugeridos |
| **Estado** | ✅ ~90% |
| **Implementado** | Motor costos, empaques, subrecetas, lote, ABC, editor P2-14, **recetas bebidas/toppings + descuento stock (068)**; **UI Costos alineada a Centro de Inteligencia** (intuitividad + riesgo + responsive) |
| **Faltante** | Import Excel 🚫 pospuesto |
| **Dependencias** | Inventario |
| **Riesgos** | Bajo |

## 10. Domiciliarios
| Campo | Valor |
|-------|-------|
| **Objetivo** | Entrega planta e independientes |
| **Estado** | ✅ ~90% |
| **Implementado** | Dispatch auto/manual + auto-retry/radio, ofertas TTL config, GPS, FCM, cobro al entregar, fiado CxC; **app repartidor** (NavigationBar, tarjeta contacto/mapa, ingresos+filtros, ganancia API); resumen admin separa comisión Foody de pendiente a independientes y normaliza `numeric` serializado como texto |
| **Faltante** | Cancel mid-ruta no libera sesión indep / ofertas; evidencia foto; E2E hardware; 3 docs obligatorios |
| **Dependencias** | Pedidos, FCM, Storage |
| **Riesgos** | Bajo · **DOM-CANCEL-INDEP-01** · cross **CAJ-DOM-IMPAGO-01** |

## 11. Zonas / mapas / horarios
| Campo | Valor |
|-------|-------|
| **Objetivo** | Cobertura domicilio y horarios operación |
| **Estado** | ✅ ~95% |
| **Implementado** | Anillos km, mapa OSM, cotización API, horarios CRUD, Photon |
| **Faltante** | — |
| **Dependencias** | Sucursales |
| **Riesgos** | Bajo |

## 12. Promociones
| Campo | Valor |
|-------|-------|
| **Objetivo** | Marketing y descuentos |
| **Estado** | ✅ ~90% |
| **Implementado** | Stories, código checkout, snapshot descuento al crear, DELETE; precio ítem congelado; 1 promo/pedido |
| **Faltante** | Anti-stack combo↔promo; DELETE con pedidos FK; limpia `promocion_id` en descuento manual |
| **Dependencias** | Storage, pedidos |
| **Riesgos** | Bajo · **PROMO-STACK-01** (combo+promo se apilan) |

## 13. Reportes
| Campo | Valor |
|-------|-------|
| **Objetivo** | Informes financieros y operativos |
| **Estado** | ✅ ~96% |
| **Implementado** | Financiero, productos, pedidos, cuadre caja, **export PDF/CSV**; **UI alineada a Centro de Inteligencia**; cifras = BD (`verificar-reportes-analitica.ps1`) |
| **Faltante** | Filtros ricos (viven en Analítica); smoke visual dispositivo |
| **Dependencias** | Caja, pedidos |
| **Riesgos** | Bajo · **REP-LINE-01** |
| **Audit** | `archivo/auditorias-prompts/AUDITORIA_REPORTES.md` |

## 14. Facturación
| Campo | Valor |
|-------|-------|
| **Objetivo** | Factura fiscal Colombia |
| **Estado** | 🟡 ~30% · 🚫 DIAN/MATIAS pausados (X-01) |
| **Implementado** | Config fiscal, borrador, emitir número local, HTML, anular soft; total=pedido; plan enterprise |
| **Faltante** | Cliente MATIAS/FE, cola/reintentos, CUFE/XML, nota crédito real, líneas ítems |
| **Dependencias** | Acuerdo comercial + proveedor |
| **Riesgos** | Legal prod sin FE · **FE-NC-01** stub |

## 15. Alertas
| Campo | Valor |
|-------|-------|
| **Objetivo** | Riesgos operativos automáticos |
| **Estado** | ✅ ~90% |
| **Implementado** | Reglas batch + evento; umbrales `UMBRALES_ALERTA` verificados; FCM alto/crítico; UI admin |
| **Faltante** | Email opcional; E2E umbral con datos sintéticos (ALT-FIX-01) |
| **Dependencias** | FCM, transacciones |
| **Riesgos** | Bajo · **ALT-UMB-01** ✅ |

## 16. Usuarios staff
| Campo | Valor |
|-------|-------|
| **Objetivo** | Gestión equipo restaurante |
| **Estado** | ✅ ~95% |
| **Implementado** | CRUD, editar rol/nombre/sucursal, catálogo permisos, gerente_cadena; **checklist permisos por usuario** (mig `085` `usuario_permisos`; JWT merge; create/edit UI); UI Centro de Inteligencia; tabla compacta de escritorio y tarjetas adaptables para móvil/tablet, estado activo explícito |
| **Faltante** | — |
| **Dependencias** | Auth, límites plan |
| **Riesgos** | Bajo |

## 17. Super Admin (Foody Control → NOC)
| Campo | Valor |
|-------|-------|
| **Objetivo** | Centro de Operaciones de plataforma: *«¿Cómo está Foody?»* |
| **Estado** | 🟡 ops base ~75% · **Fase A NOC** 📅 · visión 10 módulos diferida B/C |
| **Implementado** | 7 secciones, onboarding, docs domiciliarios, guards, PATCH config UI, estadísticas + planes, PATCH suscripción |
| **Faltante** | [`SUPERADMIN_FOODY_CONTROL.md`](SUPERADMIN_FOODY_CONTROL.md) **§3 Fase A:** home semáforo, KPI Gratis/Pro/Ultra, freemium kill switch, plan+motivo auditado, errores agrupados, asistente reglas (**SAC-***) |
| **Dependencias** | Auth super_admin · `/health` · perf |
| **Riesgos** | Alto lanzar freemium viral sin SAC-FREE-01; no construir visión completa pre-go-live |

## 18. FCM / notificaciones
| Campo | Valor |
|-------|-------|
| **Objetivo** | Push operativos y comerciales |
| **Estado** | ✅ ~90% |
| **Implementado** | Cola, cron, web+móvil, deep links |
| **Faltante** | — |
| **Dependencias** | Firebase SA backend |
| **Riesgos** | Bajo |

## 19. Impresión Python
| Campo | Valor |
|-------|-------|
| **Objetivo** | Tickets cocina en impresora local |
| **Estado** | 🟡 ~70% |
| **Implementado** | Jobs, WS, escpos, modo archivo, scripts |
| **Faltante** | QA hardware R5 |
| **Dependencias** | Cocinas, red local |
| **Riesgos** | **Alto** operación cocina sin ticket físico |

## 20. Producción / calidad / legacy
| Campo | Valor |
|-------|-------|
| **Objetivo** | Go-live stores y escala |
| **Estado** | 🟡 ~35% |
| **Implementado** | Scripts verificación, CI 5/5, RLS migr. 064, Docker prod compose, legacy screens eliminados |
| **Faltante** | Deploy VPS; rename paquete Flutter (P3-05 pausado); animaciones (P3-08 pausado) |
| **Dependencias** | VPS, proceso QA |
| **Riesgos** | **Alto** si se publica sin P3 |

## 21. Centro de Análisis (BI)
| Campo | Valor |
|-------|-------|
| **Objetivo** | KPIs dueño/admin tier Pro |
| **Estado** | ✅ ~98% |
| **Implementado** | Endpoints + filtros AND + PDF/CSV + comparativa + `pedidos-recientes` + **UI Centro de Inteligencia premium** (`lib/core/saas_ui/`, preset Personalizado, dual-series, heatmap, KPIs uniformes); KPIs = BD; **tab Rentabilidad** |
| **Faltante** | XLSX / MV (YAGNI); ranking meseros/clientes (empty honestos hasta API); smoke visual; carga 50k (ANA-FIX-01) |
| **Dependencias** | Reportes, pedidos, inventario data, §23 Finanzas |
| **Riesgos** | Bajo · **ANA-PERF-01** |
| **Audit** | `archivo/auditorias-prompts/AUDITORIA_REPORTES.md` · `scripts/verificar-reportes-analitica.ps1` |

## 22. Self-service / onboarding / planes
| Campo | Valor |
|-------|-------|
| **Objetivo** | Registro autónomo y monetización |
| **Estado** | 🟡 ~80% |
| **Implementado** | F1–F7 código, freemium, Wompi dev, recurrente; **UI Plan y pagos** (tokens Analítica, planes responsive) |
| **Faltante** | Prod HTTPS webhook/redirect |
| **Dependencias** | VPS, Wompi dashboard |
| **Riesgos** | **Alto** ingresos SaaS sin prod |

## 23. Finanzas (gastos fijos + nómina + P&L)
| Campo | Valor |
|-------|-------|
| **Objetivo** | Control de egresos del local y rentabilidad neta |
| **Estado** | ✅ ~90% UI / ~85% datos |
| **Implementado** | Migr. `080`; `empleados`; libro `gastos`; CRUD `/finanzas/*`; **`GET /finanzas/resumen`**; `GET /analitica/rentabilidad`; **hub UI premium** (KPIs, ingresos vs gastos, donut categorías, tablas SaaS, empty honestos presupuesto/proyección/facturas/flujo bancario); `verificar-finanzas.ps1` · Spec: [`docs/MODULO_FINANZAS.md`](MODULO_FINANZAS.md) |
| **Faltante** | API presupuesto / proyección 12m / flujo caja bancario; export P&L CSV; smoke UI dispositivo; recordatorios cron; nómina formal SSS 🚫 |
| **Dependencias** | Caja (gastos de turno), costeo/pedidos (snapshot `costo_unitario`), Analítica |
| **Riesgos** | Bajo si se respeta: pagos fijos/nómina/manual **no** tocan `movimientos_caja` |

---

# 🗂 Historial y documentos reemplazados

Cuando dos fuentes trataban el mismo tema, **prevalece la fecha más reciente verificada en código**.

| Tema | Documento vigente | Reemplaza / obsoleto |
|------|-------------------|----------------------|
| Estado proyecto | **Este `MASTER_STATUS.md`** | Fragmentos status en `AVANCE`, `MODULOS_ESTADO`, `PLAN_COMPLETAR` |
| Checklist accionable | `ROADMAP_TERMINAR_FOODY.md` | `PLAN_COMPLETAR_FOODY.md` (jun-04) |
| Problemas E2E | `REGISTRO_IRREGULARIDADES_FLUJOS.md` | Resumen ejecutivo `archivo/auditorias-prompts/AUDITORIA_FLUJOS_E2E.md` (jun-19, no actualizado) |
| Arquitectura | **`archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md`** (P01) + **`archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md`** (P02) + **`archivo/auditorias-prompts/AUDITORIA_FLUTTER_ESTRUCTURA.md`** (P03) + `MEMORIA.md` | `archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md` (jun-12) · `archivo/ANALISIS_SISTEMA.md` |
| Planes SaaS | `PLANES_SUSCRIPCION.md` | §2 `MODULO_SELF_SERVICE_PLANES.md` (marca F1–F7 ✅) |
| Self-service fases | Roadmap P1-09–11 + código | `MODULO_SELF_SERVICE_PLANES.md` §2 tabla «Falta» |
| Sesión Antigravity | Changelog en ROADMAP | `walkthrough-antigravity.md`, `implementation_plan-antigravity.md` |
| Inventario código jun-24 | Este MASTER + grep código | `inventario_sistema_foody-antigravity.md` (snapshot) |
| Escenarios negocio | Código + migr. 047 | `ESCENARIOS_NEGOCIO_FOODY.md` contadores jun-12 |
| Optimización | `OPTIMIZACION_ESCALABILIDAD_FOODY.md` | `foody_optimizacion.docx` (corregido en doc MD) |

### Changelog MASTER_STATUS

| Fecha | Cambio |
|-------|--------|
| 2026-11-23 | **RBAC-PEDIDOS-01** — endurecido el guard del PATCH de estado: exige `crear_pedido` (asignado por seeds a admin/gerente/cajero/mesero), no solo `ver_pedidos`; servicio conserva límite del mesero. Specs guard para ambas rutas de cobro y cambio de estado: 6/6; build Nest OK. Build actualizado arrancó aislado en :3001 con DB saludable; :3000/túnel intactos. Permisos granulares por transición pendientes |
| 2026-11-23 | **UX-ALERTAS-FLUJO-01** — Alertas verifica filtro de pendientes/todas, deep link por tipo/ID y acción de revisar con repositorio falso; 6 pruebas, sin mutaciones API. Suite global 150/5 skips; QA autenticada y tema oscuro siguen pendientes |
| 2026-11-22 | **DX-TUNEL-SKIP-01** ✅ — `iniciar-foody-subdominios.bat` usaba `-SkipBuild` sin `build/web_cliente`/`web_equipo` → FAIL. Fix: `servir-web-tunel-release.ps1` compila lo faltante; rebuild OK; SPA :8080/:8081 HTTP 200 |
| 2026-11-22 | **ENV-TUNNEL-KEEP-01** — decisión del founder: conservar `MODO=tunel` / `usarTunel=true` porque no hay VPS y Tunnel permite probar fuera de casa; revisar infraestructura al terminar la app |
| 2026-11-22 | **QA-ENV-REMOTE-01 🟡 aceptado** — Flutter local apunta a `hostApi` público por `usarTunel=true`; el founder confirma que el túnel es el entorno de prueba intencional hasta tener VPS y terminar la app. Un intento QA inició un POST demo sin respuesta visible; conservarlo registrado y revisar credenciales de prueba al cierre de QA |
| 2026-11-22 | **QA-CFG-LOGIN-01** — app Flutter web local disponible y API saludable; login demo se queda cargando tras envío, impide QA visual autenticado de Configuración; sin escrituras de negocio |
| 2026-11-22 | **UX-CFG-VIEW-01** — pantalla Configuración agrupada por tarea, ancho acotado y 1/2/3 columnas responsivas; análisis focalizado Dart sin issues; QA visual/temas pendiente |
| 2026-11-22 | **UX-INV-TRASLADOS-01** — panel de traslados y formulario responsive con estados vacíos/error/permiso, análisis focalizado Dart sin issues; QA visual pendiente |
| 2026-11-22 | **UX-INV-TABLA-01** — listado Mercado con tabla compacta en escritorio, grid tablet y tarjetas móvil; filtros y acciones existentes conservados; análisis focalizado sin issues |
| 2026-11-22 | **UX-INV-MOV-01** — historial de movimientos con transición de stock priorizada y fila táctil adaptable; análisis focalizado sin errores |
| 2026-11-22 | **DS-FORM-THEME-01** — formularios compartidos ahora derivan superficies y tipografía del tema, evitando blancos forzados en modo oscuro |
| 2026-11-22 | **UX-SUBRECETA-THEME-01** — editor de subreceta migra sus superficies/alertas a colores del tema; lógica intacta |
| 2026-11-22 | **UX-MENU-PRODUCTOS-01** — Productos del Menú con tabla desktop tema-aware y tarjetas compactas/tablet; acciones existentes preservadas, análisis focalizado pendiente |
| 2026-11-22 | **UX-MENU-EXTRAS-01** — Toppings/Bebidas con tabla desde 1100 px y tarjetas móvil/tablet; precio, costeo y disponibilidad preservados; análisis focalizado limpio |
| 2026-11-22 | **UX-MENU-CAT-COMBOS-01** — gestión de Categorías con diálogo responsive tema-aware y Combos con tabla desktop/cards compacto; análisis focalizado limpio |
| 2026-11-22 | **UX-MENU-DIALOGOS-01** — asignación de cocina/toppings y resumen precio/costo usan diálogo Foody y superficies adaptables al tema; análisis focalizado limpio |
| 2026-11-22 | **UX-MENU-COPIAR-01** — diálogo de copiar menú muestra sede origen y alcance confirmado en servicio Nest; análisis focalizado limpio |
| 2026-11-22 | **UX-FAC-LISTADO-01** — Facturación usa tabla de escritorio y tarjetas compacto; acciones existentes compartidas; análisis focalizado limpio |
| 2026-11-22 | **UX-FAC-FORM-01** — config/preview/anulación con colores tema-aware y diálogo de comprobante; reglas fiscales intactas; análisis limpio |
| 2026-11-22 | **UX-CHECKOUT-01** — checkout centrado hasta 760 px, controles tema-aware y barra alineada; backend sigue siendo autoridad; análisis limpio |
| 2026-11-22 | **UX-CARRITO-01** — carrito y detalle de línea responsivos/tema-aware hasta 760 px; interacciones actuales preservadas; análisis limpio |
| 2026-11-22 | **Diseño de operación y administración** — Caja adapta columnas al espacio real. Pedidos, Menú, Subrecetas, Conteo y diez vistas administrativas adoptan colores del tema. Análisis sin errores ni advertencias. API de Caja y sedes comprobada con sesión demo. Revisión visual integral pendiente. |
| 2026-11-22 | **Navegación y estados del panel** — barra lateral plegable, barra superior por sección, transiciones, búsqueda y cargas adaptables. Ingreso normal dirige a Inicio, el registro de notificaciones continúa en segundo plano y el cierre acota la espera del token. Verificados ingreso/cierre demo, búsqueda, Caja y Configuración móvil. |
| 2026-11-22 | **Validación de sede en Mesas** — identificador inválido era HTTP 500. El controlador compilado devuelve 400 en la prueba aislada y conserva 200 para una sede válida. Falta aplicar el nuevo binario en la API del túnel. |
| 2026-11-22 | **Ventanas operativas y Foody Control** — tema y movimiento compartidos, corrección de validación de conteo, fiado y anulación. Verificados en navegador los casos de fiado y conteo inválidos, confirmación de cobro sin registrar y navegación de plataforma. Mesas devuelve 400 en la API activa. |
| 2026-11-22 | **NAV-CFG-HUB-01 / DS-BASE-01** — configuración admin agrupada por tarea, índice de opciones con permisos, `?seccion=` preservado; dirección visual documentada en FRONTEND_DESIGN_AUDIT; QA por rol pendiente |
| 2026-11-22 | **DS-REF-01** — cuatro referencias visuales del usuario clasificadas por dispositivo/tarea; registradas en FRONTEND_DESIGN_AUDIT como guía contextual, no plantilla global |
| 2026-11-22 | **QA-UI-REDISENO-01** — análisis puntual de 4 Dart: sin issues; análisis global: 1 warning previo en `auth_repository.dart:86`; puerta `verificar-ci.ps1`: 26 OK / 1 fallo por tablas sin RLS (`cobros_idempotencia`, `rate_limit_entries`, `usuario_permisos`), y `verificar-p2-pulido.ps1` falla en su lectura de respuesta HTTP (`GetResponseStream` inexistente) |
| 2026-11-22 | **UX-INV-REDISENO-01** — hero azul oscuro/naranja, resumen con datos actuales, CTA escritorio y tabs con iconos; `dart analyze` sin incidencias; QA visual manual pendiente |
| 2026-11-22 | **UX-USR-TABLE-01 / UX-HOR-DIALOG-01** — tabla compacta Usuarios ≥1100 px con cards adaptables y estado textual; diálogos Horarios acotados al viewport y con contenido desplazable; pruebas de widget/análisis limpios; QA de sesión real, tema oscuro y teclado pendiente |
| 2026-11-22 | **UX-SEDES-FORM-01** — diálogos de Sedes limitados al viewport y desplazables, cubriendo crear/editar/brand/preview; test responsive básico y análisis limpio; faltan teclado, edición y tema oscuro en sesión real |
| 2026-11-22 | **UX-ZONAS-FORM-01** — diálogo de anillo limitado al viewport con scroll; prueba en móvil compacto y análisis limpios; mapa real, teclado y tema oscuro pendientes |
| 2026-11-22 | **UX-COCINAS-DIALOG-01** — alta de cocina/impresora adaptable; test halló y corrigió overflow de selectores en móvil; test responsive y análisis limpios; KDS realtime/hardware no verificados |
| 2026-11-22 | **UX-ALERTAS-CARD-01** — datos largos y tarjetas verificados en compacto/tablet/desktop; sin cambios en filtros, acciones o realtime; autenticación/tema oscuro pendientes |
| 2026-11-22 | **UX-FIN-TARJETAS-01** — alertas e insights ajustan su ancho al viewport; render en 4 anchos y análisis limpios; CRUD y datos reales no forman parte de la prueba |
| 2026-11-22 | **UX-PROMO-FORM-01 / UX-REPORTES-VIEW-01** — alta de Promociones responde a viewport y Reportes renderiza en 4 anchos con datos vacíos; Reportes conserva avisos deprecados de share_plus que no se migraron en este pase |
| 2026-11-22 | **UX-MENU-RESP-01 / UX-COSTEO-RESP-01** — selects Menú adaptados para etiquetas largas; vistas Menú/Costos y alta de producto pasan tamaños móvil/tablet/escritorio; recetas/datos reales y tema oscuro siguen pendientes |
| 2026-11-22 | **UX-FORM-SHELL-02 / UX-INV-DIALOG-01** — diálogo común sin medición intrínseca, scroll de toda la forma y acciones adaptables; Insumo/Subreceta con teclado simulado y Menú revalidados; viewport 320/390 pasa |
| 2026-08-20 | **Lote 🟡** — CAJ-TURNO alerta+UI; ANA-FILT-PROD/ESTADOS; COC-REIMP endpoint+KDS; `verificar-lote-turno-ana-reimp.ps1` |
| 2026-08-19 | **Lote 🟡 bugs** — QR-MESA-ID, PROMO-MANUAL/DEL, DOM-CANCEL indep+oferta, INV-AJUSTE/AUD, MES-XFER/MSG, CAJ-MSG, PED-CHECK mig 089; `verificar-lote-amarillo.ps1` |
| 2026-08-11 | **VIRAL-DEG/SIDE/RL/CPU/POOL** — flag+cupo+max/min; GET registro-estado; UI waitlist; defer horarios; BCRYPT_ROUNDS; RBAC-MESERO assign sync ✅; `verificar-viral-registro.ps1` OK |
| 2026-08-11 | **SEC-RLIMIT-03 + INFRA-EXT-UI-03** — RL menú/ciudades/geo; KDS lock ítem; SEC-RLIMIT-01 🟡 FORZAR; DK-COMPOSE-04 🟡 workspace; `verificar-sec-rlimit-kds.ps1` OK |
| 2026-08-08 | **PRIORIDADES_FOODY.md** — lista viva A→F (go-live → seguridad → Nest → Flutter → escala → pospuesto); README + MASTER enlazan |
| 2026-08-07 | **Residuales menores** — `/salud/completo`; ParseUUIDPipe mesas/catálogo/…; aprobar sin `= {}`; PIPE-04 doc; `verificar-bn-residuales.ps1` OK |
| 2026-08-07 | **BN-DTO-24…27** — DTOs listar pedidos/cerrados, impacto-stock, upload imagen/video, retorno-app; `verificar-bn-dto-query-rest.ps1` OK |
| 2026-08-07 | **BN-DTO-23 + BN-EXC-03/04** — `TimelineAuditoriaDto`; recurrentes throw sin source + `consulta_fallida`; `verificar-bn-dto-auditoria.ps1` OK |
| 2026-08-07 | **Doc remediación Nest/Auth** — `REMEDIACION_NEST_AUTH_2026-08-07.md` (cerrado + evidencia + **a pulir** + gaps QA); MASTER/AVANCE/auditorías enlazados |
| 2026-08-07 | **BN-DTO-01/02 + BN-CTRL-02/03 + BN-EXC-18** — FCM DTOs; authz usuarios/traslados→service; impresión encola con job error; scripts `verificar-bn-dto-fcm` / `verificar-bn-ctrl-usuarios` OK |
| 2026-08-07 | **BN-FIX-04/05** — query DTOs `validar-codigo` + `geografia/buscar`; `@IsBoolean` en CrearPedido; cron expone `renovaciones_fallos`; `verificar-bn-dto-query.ps1` OK |
| 2026-08-07 | **BN-FIX-06** — `forbidNonWhitelisted: true` en ValidationPipe; `verificar-bn-pipe-forbid.ps1` OK (login/disponibilidad/cotizar) |
| 2026-08-07 | **BN-FIX-01** — SQL/ownership/UPDATE imagen → `AlmacenamientoService.subirImagenEntidadCatalogo` (cierra AQ-SOLID-03 / AQ-DUP-04); `verificar-bn-almacenamiento.ps1` OK |
| 2026-08-07 | **BN-FIX-03 + RT-SCRIPT-01** — DTOs inline 06…19 + CotizarDomicilioDto; `verificar-bn-dto-inline.ps1`; realtime script → `/health` |
| 2026-08-07 | **AUTH-FLOW** — mig `084` `token_version`; claim JWT `tv`; `POST /auth/refresh` + `/auth/logout`; password bump; Flutter logout server + refresh Dio; `verificar-auth-flow.ps1` OK |
| 2026-08-11 | **DASH-*** — FRESH/RT poll 75s + «Actualizado»; ORPH Ventas→Reportes, KPI QR, top cantidad, copy tendencia; Nest reiniciado; `verificar-dashboard-general.ps1` OK |
| 2026-08-11 | **Bloque D** — FL-STATE-01/02 `operacionSucursalProvider`; FL-WIDGET-01 slot domiciliario; AQ-SOLID-08 KPIs costeo API; HUER/PERF previos; `verificar-bloque-d-flutter.ps1` OK |
| 2026-08-11 | **Bloque D parcial** — HUER-HALF-01 Facturas internas (DIAN UI oculta); PERF-FL-LIST caja+kanban; PERF-FL-IMG residual; PERF-FL-MEM audit; `verificar-bloque-d-flutter.ps1` OK |
| 2026-08-11 | **USR-PERM-01b** — checklist = plantilla del rol; API rechaza perms ajenos; UI cobrar gated por `cobrar_pedido` |
| 2026-08-11 | **USR-PERM-01** — permisos por usuario (no plantilla rol): mig `085`, `permisosEfectivos`, POST/PATCH `permisos[]`, GET `:id/permisos`, checklist Usuarios; `verificar-usuario-permisos.ps1` OK |
| 2026-08-11 | **Bloque C cerrado** — RBAC-MESERO-04 / RBAC-FIX-04: solo `gestionar_domiciliarios` en planta asignar/reasignar/dispatch/disponibles; kanban oculta UI; `verificar-rbac-mesero-04.ps1` OK |
| 2026-08-11 | **Bloque C Nest** — +API-PAGE (tope 200 / page opt-in usuarios·productos·insumos). Check `verificar-api-page.ps1`. Resta RBAC-MESERO-04 |
| 2026-08-11 | **Bloque C Nest** — BN-MOD-05 `ventas-metricas.sql.ts`; BN-CTRL-04/05/10–12 services; API-HTTP 201+409. Checks: `verificar-bn-mod-05` · `verificar-bn-ctrl-04` · `verificar-api-http` OK. Resta: API-PAGE |
| 2026-08-10 | **UX-COSTEO-STITCH-02** — lista full-page + detalle 2 col Stitch; FAB ARMAR RECETA; API resumen +imagen/categoría; analyze OK |
| 2026-08-10 | **UX-SHELL-01** — `SaasScrollableShell` en Costos, Analítica, Menú, Insumos, Reportes + caja/usuarios/alertas/facturación/domiciliarios/zonas/horarios/sucursales/cocinas; Finanzas/Promociones ya ListView; `dart analyze` 0 errors |
| 2026-08-10 | **UI SaaS Insights+Finanzas** — `lib/core/saas_ui/` + ThemeMode Riverpod (toggle AppBar admin); Analítica Resumen 9 filas (Personalizado, dual-series, heatmap); Finanzas hub KPIs/charts/tablas + empty honestos; `dart analyze` 0 errors; `verificar-finanzas.ps1` OK; `/salud` OK |
| 2026-08-08 | **Bloque C parcial** — PED-BYPASS-01 (salio-sin-pagar→EstadoCommand); ParseUUIDPipe finanzas/domi/super; BN-CTRL-07; `verificar-ci -Completo` orquesta bn+rt-sec; residuales+CxC OK |
| 2026-08-08 | **Bloque B / RT-SEC-01 ✅** — topics staff HMAC; login `realtime_canales`; anon no oye caja; `verificar-rt-sec.ps1` OK; JWT prod validator + RATE_LIMIT_FORZAR |
| 2026-08-08 | **F5 / Bloque A piloto ✅** — pago sandbox Wompi → plan activo (founder); waiver archivo; PC+túnel; siguiente = Bloque B RT-SEC |
| 2026-08-08 | **Bloque A decisiones** — waiver impresión archivo; webhook Wompi+eventos ✅; piloto PC+túnel; upgrade paths térmica/VPS documentados |
| 2026-08-08 | **Bloque A smoke** — Docker/Supabase/Nest up; túnel CF (530→OK); agente impresión archivo `:8765`; `verificar-f5-golive` + `verificar-wompi-tunel` OK; C-05/C-06 humanos abiertos |
| 2026-08-07 | **FL-LEAK-01 + BN-DTO-03** — dispose TEC inventario; DTOs públicos dispositivos; `verificar-f3-confianza.ps1` OK |
| 2026-08-07 | **AQ-DUP-01 cierre** — costeo producción usa `StockMovimientoService` (+ `produccion_id`); `StockMovimientoModule` sin ciclo Nest |
| 2026-08-06 | **UX subrecetas/lote** — modos stock al vender vs preparar; sin falso stock bajo Prep; CTA Preparar lote |
| 2026-08-06 | **Costeo unidades** — UI permite g/kg y ml/L en receta/subreceta; `expandirReceta` convierte a `unidad_base` al descontar stock; `verificar-unidades-costeo.ps1` OK |
| 2026-08-06 | **F7 AQ-DUP-01** — `StockMovimientoService`; PedidosInventario + Inventario (ajuste/compra/conteo/traslado) escriben por el mismo núcleo; `verificar-inventario-ciclo.ps1` OK |
| 2026-08-06 | **Finanzas claro** — `GET /finanzas/resumen`; consejos P&L; pago editable; CTA→Rentabilidad; `verificar-finanzas.ps1` OK |
| 2026-08-06 | **F7 AQ-CYCLE** — `PedidosDispatchHooksService`; Pedidos no importa Domiciliarios; auto-dispatch OK (`verificar-flujo-domicilio.ps1`); AQ-DUP sigue MULTI_DAY |
| 2026-08-06 | **F7 parcial** — `ParseUUIDPipe` hot paths; `FoodyRealtime.liberarCanal` ×9; KDS Urgente; `verificar-f7-deuda.ps1` OK; AQ-DUP/CYCLE abiertos |
| 2026-08-06 | **F6 cerrado** — mig `083` índices caja/movimientos; paginación movs; DASH-TZ Bogota; `verificar-f6-perf.ps1` OK |
| 2026-08-06 | **F5 parcial** — BN-EXC Wompi/impresión; `verificar-f5-golive.ps1`; `CHECKLIST_F5_GOLIVE.md` |
| 2026-08-06 | **AUTH-WEB-01** — login staff roto en `equipo.foodyy.store` (MissingPluginException secure_storage); web→prefs; `servir-web-tunel-release` + `verificar-f4-sesion` OK |
| 2026-08-06 | **F4 cerrado** — JWT `flutter_secure_storage`; `POST /pedidos/estimar`; checkout total servidor; `verificar-f4-sesion.ps1` OK |
| 2026-08-06 | **F3 cerrado** — CFG global runtime (`ConfiguracionGlobalModule`); HUER-PERM tab Rentabilidad; anonimizar posesión + fix plataforma; `prueba-web` `ver_dashboard`; `verificar-f3-confianza.ps1` OK |
| 2026-08-06 | **F2 cerrado** — `cobrar_pedido` mig `082`; cascade `sincronizarPorIngrediente`; mesero estados whitelist; `verificar-f2-politica.ps1` OK |
| 2026-08-06 | **F1 cerrado** — RT refetch (KDS/kanban/caja/mesas); busy+idempotency cobro; unique caja; mig `081`; `verificar-f1-turno.ps1` OK |
| 2026-08-06 | **F0 cerrado** — RBAC-TENANT-01 (cerrar caja scope), PED-PREPAGO-01 (SQL + cocina→pagado), VIE-01 (demote add), COC-NODISP-01 (N/D resuelto); Jest 6/6 + `verificar-idor-scope.ps1` |
| 2026-08-06 | **Unificación docs** — `AUDITORIA_*.md` → `archivo/auditorias-prompts/`; `qa-sesiones/` archivadas; hub `README.md` corto; cola = `INFORME_MAESTRO_FOODY.md` |
| 2026-08-06 | **Prompt 35 Informe maestro** — consolidación 01–34; F0–F8 por impacto ops; § CAP/VIRAL aparte; `INFORME_MAESTRO_FOODY.md` |
| 2026-08-06 | **Prompt 34 Infra extremos** — timeout mid-TX, doble cobro (1/1 OK), API caída, resync=RT-RECON; `archivo/auditorias-prompts/AUDITORIA_INFRA_EXTREMOS.md` + `verificar-infra-extremos.ps1` |
| 2026-08-06 | **Prompt 33 E2E automatizado** — Jest 14 + Flutter 5; VIE-01/COC-NODISP/PED-PREPAGO; `archivo/auditorias-prompts/AUDITORIA_E2E_AUTOMATIZADO.md` + `verificar-e2e-*.ps1` |
| 2026-08-06 | **Prompt 32 Viral spike** — D1–D4 500→40k registros; VIRAL-\*; waitlist+cola primero; `archivo/auditorias-prompts/AUDITORIA_VIRAL_SPIKE.md` |
| 2026-08-06 | **Prompt 31 Capacity planning** — 100→10k sedes; CAP-\*; pool PG 100 / Nest 25; `archivo/auditorias-prompts/AUDITORIA_CAPACITY_PLANNING.md` |
| 2026-08-06 | **NOC Foody** — spec a Centro de Operaciones; Fase A esencial vs visión 10 módulos; §17 |
| 2026-08-06 | **Spec Foody Control (SAC-*)** — `SUPERADMIN_FOODY_CONTROL.md`: KPI Gratis/Pro/Ultra, semáforo escala, incidentes, cupo freemium; §17 → 🟡 |
| 2026-08-06 | **Prompt 30 Casos viernes** — 13 escenarios ops; VIE-01/05/09/12/13; decisiones A/B/C sin inventar; `archivo/auditorias-prompts/AUDITORIA_CASOS_VIERNES.md` |
| 2026-08-06 | **Prompt 29 Consistencia módulos** — 6 rutas de datos; NEW CONS-STOCK/PROMO-ADD/NODISP-STOCK/KDS-UI/REP-OPEN; reconfirm PED-PREPAGO+COC-NODISP+CFG-GLOBAL-DEAD; `archivo/auditorias-prompts/AUDITORIA_CONSISTENCIA_MODULOS.md` |
| 2026-08-06 | **Prompt 28 Funcionalidad huérfana** — ~12 huérfanos producto (KDS prio, costeo combos, ganancias, PERM rentabilidad, CFG-GLOBAL-DEAD); ops OK; `archivo/auditorias-prompts/AUDITORIA_FUNCIONALIDAD_HUERFANA.md` |
| 2026-08-06 | **Prompt 27 Fuzz inputs** — 45 payloads; 0 stack/0 down; UUID→500; mesas 5k; `archivo/auditorias-prompts/AUDITORIA_FUZZ_INPUTS.md` + `verificar-fuzz-inputs.ps1` |
| 2026-08-06 | **Prompt 26 Estrés/concurrencia** — multi-sede OK; races pedido/inv; caja TOCTOU; carga p99~10s; `archivo/auditorias-prompts/AUDITORIA_ESTRES_CONCURRENCIA.md` + `verificar-estres-concurrencia.ps1` |
| 2026-08-06 | **Prompt 25 OWASP** — injection OK; BAC Prompt 06 vivo + finanzas; JWT/DK-SEC; RL prod-only; RLS 74/74; `archivo/auditorias-prompts/AUDITORIA_OWASP.md` + `verificar-owasp.ps1`; gitignore entorno |
| 2026-08-06 | **Prompt 24 PERF Flutter** — listas/memoria/imágenes; `archivo/auditorias-prompts/AUDITORIA_PERF_FLUTTER.md` + `verificar-perf-flutter.ps1`; gaps LIST-07 / MEM-01 / IMG-01 |
| 2026-08-06 | **Prompt 23 PERF backend** — EXPLAIN queries; caché menú-only; carga 10/50/200; `archivo/auditorias-prompts/AUDITORIA_PERF_BACKEND.md` + `verificar-perf-backend.ps1`; gaps PERF-IDX/SQL/LOAD/CACHE |
| 2026-08-06 | **Prompt 22 Config restaurante** — BD↔UI; propagación; multi-rol; `archivo/auditorias-prompts/AUDITORIA_CONFIGURACION.md` + `verificar-config-restaurante.ps1`; **CFG-GLOBAL-DEAD** |
| 2026-08-06 | **Prompt 21 Dashboard** — frescura/huérfanos/consistencia vs reportes; `archivo/auditorias-prompts/AUDITORIA_DASHBOARD.md` + `verificar-dashboard-general.ps1`; gaps DASH-TZ / DASH-RT / DASH-ORPH |
| 2026-08-06 | **Prompt 20 Reportes/Analítica** — cifras=BD; filtros AND; umbrales alertas; `archivo/auditorias-prompts/AUDITORIA_REPORTES.md` + `verificar-reportes-analitica.ps1`; gaps ANA-FILT-PROD / ANA-PERF |
| 2026-08-06 | **§23 Finanzas** — gastos fijos + nómina simple + P&L (`080`, `/finanzas/*`, tab Rentabilidad, `verificar-finanzas.ps1`) |
| 2026-08-06 | **Prompt 09 doc** — `archivo/auditorias-prompts/AUDITORIA_INFRA.md` (Nginx ausente, R2/Storage, Tunnel WiFi, SSL CF, disco); § Infra en problemas vigentes |
| 2026-08-06 | **Prompt 08 doc** — `archivo/auditorias-prompts/AUDITORIA_DOCKER_ENV.md` (compose, secretos, HC, restart, logs); § Docker/env en problemas vigentes |
| 2026-08-06 | **Prompt 07 doc** — `archivo/auditorias-prompts/AUDITORIA_BD_SUPABASE.md` (RLS deny-all, índices, FKs, N+1, backups OPS-02); § BD en problemas vigentes |
| 2026-08-06 | **Prompt 06 doc** — `archivo/auditorias-prompts/AUDITORIA_RBAC.md` (RBAC-\* IDOR caja + mesero cobro + guards); § RBAC en problemas vigentes |
| 2026-08-06 | **Prompt 05 doc** — `archivo/auditorias-prompts/AUDITORIA_AUTH_JWT.md` (AUTH-FLOW/EXP/REV/STORE/OTP + AUTH-FIX-01…06); § Auth/JWT en problemas vigentes |
| 2026-08-05 | **Prompt 04 doc** — `archivo/auditorias-prompts/AUDITORIA_APIS_REST.md` (API-HTTP/VAL/PAGE/IDEM/FMT + API-FIX-01…06); § APIs REST en problemas vigentes |
| 2026-08-05 | **Prompt 03 doc** — `archivo/auditorias-prompts/AUDITORIA_FLUTTER_ESTRUCTURA.md` (FL-\* estado/widgets/leaks/nav/API + FL-FIX-01…07); § Flutter estructura en problemas vigentes |
| 2026-08-05 | **Prompt 02 doc** — `archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md` (BN-\* módulos/controllers/DTOs/excepciones/pipes + BN-FIX-01…06); § Backend NestJS en problemas vigentes |
| 2026-08-05 | **Prompt 01 doc** — `archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md` (AQ-\* duplicación/ciclos/SOLID/acoplamiento/escala/nombres + AQ-FIX-01…07); § Arquitectura/calidad en problemas vigentes |
| 2026-08-04 | **UX checkout cliente** — AppBar/chips/campos/CTA ink; tip; resumen densificado |
| 2026-08-04 | **Carrito detalle** — tap desglose (incluye/extras), swipe borrar, Vaciar; snapshot línea |
| 2026-08-04 | **Icono app** — `assets/logo_foody.png` en APK Android, Windows `.ico`, PWA/web |
| 2026-08-04 | **Icono Foody** — `assets/foody.png` en APK Android, Windows `.ico`, PWA/web (favicon + Icon-192/512 + manifest) |
| 2026-08-04 | **UX carrito cliente** — AppBar/pasos/cards/CTA ink; FoodyPasosPedido neutro |
| 2026-08-04 | **UX menú cliente** — ink + tip pedido, + rebote, snackbar Ver, sheets Analítica |
| 2026-08-04 | **UX sucursales cliente** — AppBar/cards Analítica, CTA Ver menú ink; sede única intacta |
| 2026-08-04 | **Estados premium** — hold oculta chrome, swipe-down cierra, tiempo `created_at` |
| 2026-08-04 | **UX home lugares** — AppBar/nav/cards/estados ink; placeholders sin arcoíris |
| 2026-08-04 | **UX elegir ciudad** — header denso ink, tiles Analítica; preferencia/FCM intactos |
| 2026-08-04 | **UX splash** — canvas neutro Analítica (sin naranja+teal); logo en card; arranque intacto |
| 2026-08-04 | **UX registro repartidor** — Analítica/ink + pantalla espera |
| 2026-08-04 | **UX auth** — registro restaurante + login repartidor Analítica/ink; `AuthFormEstilo` compartido |
| 2026-08-04 | **UX login staff** — sin AppBar naranja; card Analítica, CTA ink, demo colapsable; OAuth/auth intactos |
| 2026-08-04 | **UX chrome panel** — sidebar oscuro activo neutro (sin naranja); AppBar/sede/iconos ink + canvas Analítica; rutas intactas |
| 2026-08-04 | **UX Pedidos** — kanban/grid Analítica: KPIs Activos/Total, chips/tabs ink, cards franja urgencia + CTA ink (Listo verde); Realtime/API intactos |
| 2026-08-04 | **UX KDS** — tickets altura contenido, urgencia franja+tiempo real, Listo primario, Todo listo, grid Wrap responsive |
| 2026-08-04 | **UX Repartidores** — KPIs, config≠operación, liquidar primario, dual ≥980, diálogo dispose seguro; no solo tokens |
| 2026-08-04 | **UX Zonas domicilio** — layout dual ≥980, mapa con leyenda+ubicación, edición con presets km/precio, timeline cerca→lejos, atajos vacío; no solo tokens |
| 2026-08-04 | **UI Zonas domicilio** — tokens Analítica, mapa + anillos densos, CTA ink, FoodyDialogo; lógica intacta |
| 2026-08-04 | **UI Mis sucursales** — tokens Analítica, marca + sedes densas, CTA ink, FoodyDialogo; lógica intacta |
| 2026-08-04 | **Escanear mesa UX** — Analítica + Pegar + banner sesión mesa + linterna/haptic; sin API |
| 2026-08-04 | **Historial cliente + Google** — `079` auth_uid; `POST /dispositivos/vincular-auth`; `GET /pedidos/mios` con Bearer; Mis pedidos + Seguimiento Analítica; script `verificar-historial-cliente-auth.ps1` |
| 2026-08-04 | **UI Horarios** — tokens Analítica, resumen cliente neutro, cards densas + switch ink, FoodyDialogo; lógica intacta |
| 2026-08-04 | **UI Usuarios** — tokens Analítica, cards densas + badges rol, CTA/switch ink, FoodyDialogo; lógica staff intacta |
| 2026-08-04 | **UI Alertas** — tokens Analítica, chip/CTA ink, cards + badges tipo/nivel (sin slugs), vacío/error guiados; lógica intacta |
| 2026-08-04 | **Mesas polish** — cards minimal (barra/punto), KPIs neutros, `FoodyDialogo` en modales cobro/comensal/cuenta |
| 2026-08-04 | **UI Mesas piso** — cards táctiles + CTA, filtros KPI, orden urgencia QR, sheet cuenta densificado; lógica intacta |
| 2026-08-04 | **UI Caja** — tokens Analítica, apertura ink, turno activo + movimientos/CxC laterales; lógica intacta |
| 2026-08-04 | **UI Nuevo pedido** — tokens Analítica, chips/toggle ink, cards neutras, carrito + confirmar; lógica POS intacta |
| 2026-08-04 | **UI Promociones** — tokens Analítica, vacío guiado, cards densas + badges, FAB ink; sin cambios API |
| 2026-08-04 | **UI Plan y pagos** — tokens Analítica, header denso, suscripción semántica, planes 3 col ≥980, historial; Wompi intacto |
| 2026-08-04 | **UI Facturación** — tokens Analítica, config en secciones (emisor/IVA/DIAN), facturas densas + estados semánticos, responsive; sin cambios API |
| 2026-08-03 | **UI Menú admin** — tokens Analítica, filtros sin receta/margen/no disponible, cards densas + riesgo, tabs; sin cambios API |
| 2026-08-03 | **UI Costos y márgenes** — tokens Analítica, riesgo (sin receta/bajo margen), editor más guiado, tabs claros, responsive; sin cambios API |
| 2026-08-03 | **UI Insumos** — misma línea visual que Analítica/Reportes (tokens, banner riesgo, cards densas + responsive); sin cambios API |
| 2026-08-03 | **UI Reportes** — misma línea visual que Analítica (header, KPIs, surfaces, tendencia, skeletons); sin cambios API |
| 2026-08-03 | **UI Centro de Inteligencia** — rediseño solo presentación (`lib/features/analitica/`): header hero, KPIs+sparklines, insights, skeletons, charts premium, filtros sheet; sin cambios API/lógica |
| 2026-08-01 | **OPT-04/05** — paginación cerrados-hoy + movimientos inventario + UI «Cargar más»; poll RT 90/45s; KDS/domi independiente; techo auditoría 500; `verificar-paginacion-ops.ps1` OK |
| 2026-08-01 | **OPS lote 1** — backup.sh+retención (`BACKUPS_FOODY.md`); FCM-02 (`078` intentos/abandonada); STOR-01 limpieza estados; `verificar-ops-recomendaciones.ps1` OK |
| 2026-08-01 | **Gap recomendaciones** — `docs/RECOMENDACIONES_IMPLEMENTACION.md`: 12✅ / 6🟡 / 8⏳ / 3📅; specs OPS-01/02, FCM-02, STOR-01; corregido «caché menú ausente» |
| 2026-08-01 | **Estados WhatsApp** — 1 anillo por restaurante; viewer multi-clip; video ≤30s (`077`, `POST /almacenamiento/video`, `tipo_media`); admin Foto/Video |
| 2026-07-31 | **DX puertos Flutter** — `flutter-run-flavor.ps1 -LiberarPuerto`; regla `foody-riesgos-produccion.mdc` (dartvm≠prod); doc ESTRATEGIA/ENTORNO |
| 2026-08-01 | **Toppings ≠ bebidas** — toppings solo extras (`PUT /productos/:id/toppings` + checkboxes admin); bebidas siguen producto; migr. `076` borra espejo topping→producto |
| 2026-08-01 | **Extras = productos** — migr. `075` espejo topping/bebida→producto; sheet/cajero agregan líneas de producto (no adicionales); crear topping/bebida publica en menú |
| 2026-07-31 | **Upsell menú** — cards horizontales toppings/bebidas en detalle producto/combo; hint admin Bebidas (extra ≠ producto); vacío categoría Bebidas; migr. `074` relink extras demo |
| 2026-07-31 | **Stories polish + DELETE** — CTA oval transparente; media `contain`; anillo gris visto local; nav CTA vía `appNavigatorKey`; `DELETE /promociones/:id` + admin Eliminar |
| 2026-07-31 | **Cliente premium + estados** — stories WhatsApp (24h, producto, auto-avance); AppBar/cards lugares; nav sede única estable; `073` + marca `PATCH /sucursales/marca`; admin logo/portada y producto en estado |
| 2026-07-31 | **Cliente UX oleada A** — CL-01…08 implementados (staff oculto, agotado, sticky carrito, pills, subtotal extras, stories CTA, FoodyEstadoUi, checkout inline); doc auditoría actualizado |
| 2026-07-31 | **Auditoría UX cliente** — `docs/frontend/FRONTEND_AUDITORIA_UX_CLIENTE.md` (todas las ventanas + promos); backlog CL-01…23; sin código |
| 2026-07-31 | **F0 UI** — Docker+API; Flujo 12/12; Roles 38/38 (aprobar QR=mesero); guion `qa-sesiones/2026-07-31-f0-ui.md`; Chrome `:8080`/`:8081` listos |
| 2026-07-31 | **Pedidos Fase 1 verify-docs** — `verificar-pedidos-kanban.ps1` OK; analyze pedidos/kanban sin errores; plan columnas/cards/modal/domicilio/cerrados confirmado en código |
| 2026-07-31 | **Coherencia pedidos↔BI** — `SQL_VENTA_LINEA_ITEM` en analítica/reportes/dashboard/costeo/cuenta mesa/cobro; filtros analítica con estados QR/confirmado/rechazado; dashboard activos incluye `pagando`/`asignado`; `verificar-coherencia-pedidos-analitica.ps1` |
| 2026-07-31 | **POS coherencia** — bebidas en menú crear pedido; combos admin/POS con toppings+bebidas; cambiar producto estable (DELETE limpia FKs); `verificar-pos-menu-cambiar.ps1` |
| 2026-07-30 | **Pedidos Fase 2** — `PATCH /pedidos/:id/items/:itemId`; UI Editar/Cambiar producto; `topping_ids` en resumen; DELETE reimprime; `verificar-pedido-items.ps1` |
| 2026-07-30 | **Pedidos CTA** — confirmar QR con mesero (`mesera_id`), modal UI, FCM mesero; comanda `Copia N` (migr. 071); CTA Listo/A cobrar/En camino en tarjeta |
| 2026-07-30 | **Pedidos UX** — default tabs+grid (sin scroll lateral); card cliente/hora/#; `POST /domiciliarios-planta/reasignar` + UI Cambiar; script kanban OK |
| 2026-07-30 | **UI Pedidos Fase 1** — columnas por canal, cards+pills, modal detalle, `items_resumen`, `cerrados-hoy`, POS domicilio real; script `verificar-pedidos-kanban.ps1` |
| 2026-07-30 | **UI Analítica premium** — Resumen dashboard (KPIs+charts+tabla pedidos+pills); `GET /analitica/pedidos-recientes`; charts tabs; FoodyBreakpoints; `verificar-analitica` OK |
| 2026-07-30 | **Cierre 🟡 parciales** — propina POS llevar + CxC al «Pendiente»; MASTER: menú/reportes/multi/usuarios/super/analítica/panel → ✅; producción §20 alinea CI/RLS |
| 2026-07-30 | **UX/responsive operación** — `FoodyBreakpoints` (split 720); cobro mesa compacto; mesas 4/5 cols; RS-20 ✅ |
| 2026-07-30 | **Analítica Fase 3** — lista alertas en resumen; Δ prep + caída categoría en riesgo/cron; UI; script OK |
| 2026-07-30 | **Analítica Fase 2** — `GET /analitica/export` CSV; comparativa KPIs en tabs (no resumen); Flutter export CSV + rango comparar custom; script verificar ampliado |
| 2026-07-30 | **QA sesión completa Analítica** — Supabase-db + migr.070 + API :3000; `verificar-analitica.ps1` OK; probe shapes Q1–Q3 + inventario fix `bajoMinimo` params; reportes-export OK; analyze Flutter OK. Regla nueva `foody-sesion-completa-antes-entregar.mdc` |
| 2026-07-29 | **Analítica Fase 1** — filtros combinables API+UI, gráficas, export PDF Análisis, `duracion_estado_anterior_seg`, migr. 070 distancia_km, alertas `producto_sin_venta`/`mesero_cancelacion_alta`; plan doc actualizado. QA API viva pendiente (Supabase down) |
| 2026-07-29 | **Plan Analítica/Reportes** — `docs/PLAN_COMPLETAR_ANALITICA_REPORTES.md` (filtros solo Análisis, datos duración/distancia/segmento cliente, export híbrido, 3 fases); §21 → 🟡 plan documentado; sin código |
| 2026-07-31 | **F0 UI** — Docker+API arrancados; Flujo 12/12; Roles 38/38 (fix aprobar QR=mesero); guion `qa-sesiones/2026-07-31-f0-ui.md`; Chrome `:8080`/`:8081` |
| 2026-07-26 | **NAV-DP** — Domi planta: FCM+redirect, cobro 1 sheet, sheet arrastrable, split ≥720, «Mi ruta», saldo liquidar, copy web; doc `FRONTEND_AUDITORIA_NAV_DOMICILIARIO.md` |
| 2026-07-26 | **F0 QA** — FlujoApi 12/12 + RolesApi 38/38 + CI; sesión `docs/archivo/qa-sesiones/2026-07-26.md`; click-through UI pendiente |
| 2026-07-26 | **NAV-ADM2** — deep-link `pedido_id`/`ingrediente_id`, kanban móvil, alertas→pedido/insumo/costos, cabeceras operación, cross-links Reportes↔Analítica/KDS/promos/domi/sucursales/usuarios; doc `FRONTEND_AUDITORIA_NAV_ADMIN2.md` (22/24; 06/24 diferidos) |
| 2026-07-26 | **Multi-negocio (docs)** — paquete `docs/multinegocio/` + hub `PLAN_MULTINEGOCIO_FOODY.md`; fila en § Documentado; sin código |
| 2026-06-28 | **P2-17** — editar rol/nombre/sucursal staff; `GET /usuarios/catalogo-roles`, `PATCH /usuarios/:id`; UI permisos read-only; `verificar-usuarios-editar.ps1` |
| 2026-06-28 | **P2-16** — export PDF/CSV reportes admin; script `verificar-reportes-export.ps1` |

---

# Mantenimiento de este documento

**Al cerrar cualquier tarea:**

1. Mover ítem entre ✅ / 🟡 / 🔴 en la sección correspondiente.
2. Actualizar ficha del módulo (%, faltante).
3. Si resuelves un 🟣 → mover a 🟢 con fecha.
4. Ajustar contadores del resumen general.
5. Añadir viñeta al changelog.
6. Actualizar checkbox en `ROADMAP_TERMINAR_FOODY.md` (checklist operativo).

**No duplicar aquí:** variables de entorno, UUIDs seed, listado completo endpoints — usar `docs/AVANCE_PROYECTO.md` § Referencias persistentes o `INFRAESTRUCTURA/endpoints_api_foody.md` hasta migrarlos a anexo único.

---

# Documentos que pueden archivarse

**Hecho 2026-06-28** — ver `docs/archivo/README.md`.

| Documento | Ubicación actual |
|-----------|------------------|
| `ANALISIS_SISTEMA.md` | `docs/archivo/` |
| `PLAN_COMPLETAR_FOODY.md` | `docs/archivo/` |
| `auditoria_flujos_foody-antigravity.md` | `docs/archivo/` |
| `walkthrough-antigravity.md` | `docs/archivo/` |
| `implementation_plan-antigravity.md` | `docs/archivo/` |
| `inventario_sistema_foody-antigravity.md` | `docs/archivo/` |
| `AUDITORIA_FLUJOS_E2E.md` | `docs/archivo/auditorias-prompts/` |

### Reducir rol (mantener como referencia, no como status)

| Documento | Rol restante |
|-----------|--------------|
| `docs/AVANCE_PROYECTO.md` | Referencias persistentes (BD, env, endpoints) hasta anexo único |
| `docs/MODULOS_ESTADO.md` | Plantilla por módulo — **sincronizar desde MASTER** o deprecar |
| `docs/REGISTRO_IRREGULARIDADES_FLUJOS.md` | Solo mientras quede R5 abierto; luego archivar |
| `docs/ESCENARIOS_NEGOCIO_FOODY.md` | Catálogo QA tras P2-21/22 |
| `archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md` | Informe arquitectura jun-12 (mayoría resuelto) |
| `archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md` | **Prompt 01 (2026-08-05)** — deuda estructural AQ-\*; mantener vivo al cerrar fixes |
| `archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md` | **Prompt 02 (2026-08-05)** — NestJS módulos/controllers/DTOs/excepciones/pipes (BN-\*) |
| `archivo/auditorias-prompts/AUDITORIA_FLUTTER_ESTRUCTURA.md` | **Prompt 03 (2026-08-05)** — Flutter estado/widgets/leaks/nav/API (FL-\*) |
| `archivo/auditorias-prompts/AUDITORIA_APIS_REST.md` | **Prompt 04 (2026-08-05)** — contrato REST HTTP/validación/paginación/idempotencia (API-\*) |
| `archivo/auditorias-prompts/AUDITORIA_AUTH_JWT.md` | **Prompt 05 (2026-08-06)** — auth/JWT login/refresh/revocación/storage/OTP (AUTH-\*) |
| `archivo/auditorias-prompts/AUDITORIA_RBAC.md` | **Prompt 06 (2026-08-06)** — roles/permisos, mesero escalada, IDOR multi-tenant (RBAC-\*) |
| `archivo/auditorias-prompts/AUDITORIA_BD_SUPABASE.md` | **Prompt 07 (2026-08-06)** — RLS, índices, FKs, N+1, backups (BD-\*) |
| `archivo/auditorias-prompts/AUDITORIA_DOCKER_ENV.md` | **Prompt 08 (2026-08-06)** — Docker compose, secretos, healthchecks, logs (DK-\*) |
| `archivo/auditorias-prompts/AUDITORIA_INFRA.md` | **Prompt 09 (2026-08-06)** — Hetzner/Nginx/Cloudflare Tunnel/R2/disco (INF-\*) |
| `archivo/auditorias-prompts/AUDITORIA_REPORTES.md` | **Prompt 20 (2026-08-06)** — Reportes/analítica vs BD + alertas (REP-/ANA-/ALT-\*) |
| `archivo/auditorias-prompts/AUDITORIA_DASHBOARD.md` | **Prompt 21 (2026-08-06)** — Dashboard frescura/huérfanos/consistencia (DASH-\*) |
| `archivo/auditorias-prompts/AUDITORIA_CONFIGURACION.md` | **Prompt 22 (2026-08-06)** — Config restaurante BD↔UI/propagación (CFG-\*; CFG-GLOBAL-DEAD) |
| `archivo/auditorias-prompts/AUDITORIA_PERF_BACKEND.md` | **Prompt 23 (2026-08-06)** — Performance backend: EXPLAIN, caché, carga (PERF-\*) |
| `archivo/auditorias-prompts/AUDITORIA_PERF_FLUTTER.md` | **Prompt 24 (2026-08-06)** — Performance Flutter: listas, memoria 8h, imágenes (PERF-FL-\*) |
| `archivo/auditorias-prompts/AUDITORIA_OWASP.md` | **Prompt 25 (2026-08-06)** — OWASP: injection, BAC, secretos, rate limit, RLS (SEC-\*) |
| `archivo/auditorias-prompts/AUDITORIA_ESTRES_CONCURRENCIA.md` | **Prompt 26 (2026-08-06)** — Estrés/concurrencia: multi-sede, races, carga (CONC-\*) |
| `archivo/auditorias-prompts/AUDITORIA_FUZZ_INPUTS.md` | **Prompt 27 (2026-08-06)** — Fuzz inputs: inválidos/largos/stack (FUZZ-\*) |
| `archivo/auditorias-prompts/AUDITORIA_FUNCIONALIDAD_HUERFANA.md` | **Prompt 28 (2026-08-06)** — Funcionalidad huérfana API↔UI↔BD (HUER-\*) |
| `archivo/auditorias-prompts/AUDITORIA_CONSISTENCIA_MODULOS.md` | **Prompt 29 (2026-08-06)** — Consistencia entre módulos (CONS-\*) |
| `archivo/auditorias-prompts/AUDITORIA_CASOS_VIERNES.md` | **Prompt 30 (2026-08-06)** — Casos viernes alta demanda (VIE-\*) |
| `archivo/auditorias-prompts/AUDITORIA_CAPACITY_PLANNING.md` | **Prompt 31 (2026-08-06)** — Capacity planning 100→10k (CAP-\*) |
| `archivo/auditorias-prompts/AUDITORIA_VIRAL_SPIKE.md` | **Prompt 32 (2026-08-06)** — Spike viral registros D1–D4 (VIRAL-\*) |
| `archivo/auditorias-prompts/AUDITORIA_E2E_AUTOMATIZADO.md` | **Prompt 33 (2026-08-06)** — E2E Jest + Flutter 5 flujos + VIE/CONS (E2E-\*) |
| `archivo/auditorias-prompts/AUDITORIA_INFRA_EXTREMOS.md` | **Prompt 34 (2026-08-06)** — Timeout/doble submit/API caída/resync (INFRA-EXT-\*) |
| `docs/INFORME_MAESTRO_FOODY.md` | **Prompt 35 (2026-08-06)** — Consolidación hallazgos + plan F0–F8 + § escala/viral |

### Mantener sin archivar (spec / procedimiento, no status)

- `INFRAESTRUCTURA/*` — especificación objetivo
- `MEMORIA.md` — contexto permanente
- `docs/ENTORNO_LOCAL.md`, `docs/MOVIL_RED_LOCAL.md` — operación dev
- `docs/ROADMAP_TERMINAR_FOODY.md` — checklist accionable P0–P3
- `docs/frontend/` — suite `FRONTEND_*.md` (roadmap, **FRONTEND_AUDITORIA_NAV_ADMIN.md** + **ADMIN2**, NAV-MC/CJ/CK/MS, auditorías UX/diseño/producto/arquitectura, F0–F10)
- `docs/MODULO_*.md`, `docs/MULTI_SUCURSAL.md`, `docs/FLUJO_*.md` — diseño funcional
- `docs/WOMPI_PRODUCCION.md`, `docs/IMPRESION_RESTAURANTE.md`, `docs/FCM_FOODY.md` — guías integración
- `AGENTS.md` — instrucciones agentes (apuntar a MASTER_STATUS como status)

---

*Fin del documento maestro.*

**Verificación de continuación (2026-11-24):** Búsqueda global server-side y domicilios tardíos acotados corregidos en fuente. Nest 24 suites/55 tests, build OK; Flutter 186 aprobadas/5 omitidas; analyzer focalizado limpio y diff check limpio. Build Equipo 6.534.074 bytes; disco, :8080 y Tunnel SHA-256 idéntico `F23121F198A1ABBA7209B4F89CA5D52D3B6E4BF0F05760B3479801C0A14942EA`; ambos HTTP 200. cloudflared PID 11112, web :8080 y Nest :3000 (PID 7564) siguen activos; Nest no reiniciado, cambios API aún requieren activación coordinada. OAuth y datos de negocio sin cambios.

**Caja — navegación de aviso por turno largo (2026-11-24):** el aviso ahora lleva al contexto operativo adecuado: Admin → Pedidos y Cajero → Mesas. Verificado con pruebas responsive del widget y callback; no cierra turnos ni cambia reglas financieras. Matriz ADM-14. La corrida integral aislada del backend dio 8/8 suites y 17/17 pruebas; el flujo de venta pagada concilia el delta de Caja con Reportes y Analítica (diferencia 0). Release web Equipo actualizado y servido por :8080/Tunnel: `main.dart.js` 6.543.993 bytes, SHA-256 `0A23264C478356E3BAFF70400E3E3E953E4785DBB0B0D2EEBECD9F839CBF5A60`, idéntico en disco, local y público. API principal :3000, webs :8080/:8081 y ambos dominios públicos siguen HTTP 200; cloudflared activo. El entorno QA se limpió/restauró y la API temporal :3001 se detuvo. La revisión visual autenticada del CTA aún queda pendiente. El build reportó limitaciones del dry-run WASM por APIs web legacy y aviso de fuente Cupertino ausente; compilación JS release terminó correctamente.

**Pedidos — momento de cobro por canal (2026-11-24):** POS distingue cobro inmediato para llevar, método previsto al cerrar mesa y cobro a la entrega. El domiciliario recibe `COBRO_REQUERIDO` si intenta confirmar con “Pendiente”, mientras que Admin al marcar manualmente `entregado` hace fallback a efectivo y lo registra en Caja. Kanban advierte este efecto y exige confirmación explícita antes de llamar al API; cancelar no cambia el pedido. Se preservaron regla, payload y backend; filtro HTTP conserva el error específico. POS 11/11; Kanban 9 pruebas con cobertura responsive y confirmación/cancelación; Flutter global 208 aprobadas/5 omitidas; Nest 26 suites/57 pruebas; E2E domicilio 4/4 en BD QA aislada, incluido el movimiento manual efectivo en Caja. Riesgo/decisión pendiente: decidir si el fallback manual a efectivo debe mantenerse o exigir método de pago explícito. Release Equipo/Cliente actualizado; `main.dart.js` Equipo 6.546.007 bytes, SHA-256 `DAED9D34A64676150D275522701496EB105608003C6BEA53702A4EF6AD48E7DA`, idéntico en disco, :8080 y Tunnel; ambos sitios y health API HTTP 200. Cloudflare PID 11112 activo; API :3000 no reiniciada; QA :3001 detenida. Seed QA horario e inventario demo restaurados. Detalle: `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**FIN-MESA-SPLIT-TRACE-01 (2026-11-24):** revisión estática posterior a FIN-MESA-SPLIT-01: `pagos_pedido` de una cuenta unificada conserva `mesa_id` pero solo un `pedido_id` representativo; el método singular de cada ticket pagado conserva el primer método, no el mix. Movimientos de caja sí quedan asignados por ticket y el historial actual de mesa se consulta por mesa, así que no se detectó pérdida en Caja actual; queda riesgo para recibos/devoluciones/reportes por ticket. Modelo de asignación transacción→tickets pendiente, sin cambio de esquema/datos. Ver `AUDITORIA_CAJA.md`.

**DOM-FIN-TRACE-01 (2026-11-24):** cotejo del flujo de independientes con reportes: la cancelación revierte caja/cancela asignación, ofertas y libera sesión, pero conserva `ganancias_domiciliario.pagado=false`; el agregado `por_pagar` incluye esas filas sin filtrar estado de asignación. No es un pago demostrado ni se corrige sin decidir devengo por intento/entrega y política de cancelación. `total_entregas` se incrementaba al aceptar; la etiqueta actual fue corregida a “Ofertas aceptadas (histórico)” por `DOM-DELIVERY-COUNT-LABEL-01`. No se encontró endpoint/UI de liquidación del independiente. Separar estimación Foody, recaudo real de comisión y pasivo del repartidor. Evidencia y decisión pendiente en `AUDITORIA_REPORTES.md`; auditoría de estado/efecto adicional en `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**PED-CANCEL-COPY-01 (2026-11-24):** el diálogo de cancelar en Kanban decía que Foody “solo devuelve efectivo”, aunque `revertirVentasPedido()` contabiliza reversas para cada medio y caja de origen. Se aclaró que la reversa contable no confirma que el proveedor haya ejecutado un reembolso electrónico. Sin cambios de lógica de pagos, API, datos ni OAuth. Verificación: prueba unitaria existente de reversa 3/3 y widget Kanban focalizado.
**PED-CANCEL-REFUND-SEMANTICS-01 (2026-11-24):** personal elevado puede cancelar pedidos ya pagados; backend crea reversa en Caja y pone `monto_pagado=0`, pero no se encontró ejecución de reembolso al proveedor para pedidos (Wompi revisado corresponde a suscripciones). Decisión pendiente: responsable/evidencia/estado del reintegro y conciliación con caja, evitando doble devolución manual. Detalle en `AUDITORIA_PEDIDOS_CICLO_VIDA.md`; no se alteraron pagos.
**PED-CANCEL-RBAC-01 (2026-11-24):** detalle y tarjetas Kanban ahora ocultan acciones de transición si falta `crear_pedido`; aprobar/rechazar QR se limita a `aprobar_pedido_mesa`. Cancelar también replica en UI los límites de rol/estado/2 min del backend para perfiles no elevados. El detalle reutiliza el repositorio del Kanban. Read-only y cajero con pedido antiguo sin CTA; detalle 4/4 y Kanban 12/12, analyzer limpio. Hallazgo adicional: `cancelar_pedido` está definido y asignado a admin/gerente pero no se usa en backend ni UI; el servicio recibe permisos sin usarlos. Requiere decisión sobre el alcance del permiso dedicado antes de cambiar autorizaciones.
**COC-DISPATCH-INCOMPLETE-01 (2026-11-24):** PATCH de estado podía dejar un domicilio en `listo` con líneas `pendiente`/`preparando`; el gate compartido de despacho solo rechazaba `no_disponible`. `DispatchService.validarPedidoParaDespacho()` ahora bloquea líneas con estado distinto de `listo`/`no_disponible` (NULL incluido) y da una instrucción de volver a Cocina. Kanban ya muestra esa causa en el detalle y no presenta controles de asignación mientras la preparación esté incompleta. La barrera se usa en dispatch automático, asignación de planta, creación/aceptación de oferta independiente. Nest completo 37 suites/93 pruebas y build OK; Flutter detalle/Kanban 16/16, analyzer limpio. API :3000 no reiniciada, por lo que falta activación y E2E con DB QA.

**Arranque Tunnel — smoke actual (2026-11-24):** desde `scripts/iniciar1/iniciar-foody-subdominios.bat` con `FOODY_NOPAUSE=1`, launcher detectó ambos bundles desactualizados, compiló Cliente/Equipo release y reemplazó solo los servidores estáticos. Cliente :8081 PID 11732; Equipo :8080 PID 19268; API :3000 PID 7564 y `cloudflared` PID 11112 conservaron sus procesos. Las seis URL locales/públicas (home Cliente/Equipo y health API) dieron HTTP 200; JS de cada app local y público coincide SHA-256: Cliente `110F19081551B459C7C6FB11675AE05AE1226D469DF2225CB082599418997AD7` (6.546.632 caracteres) y Equipo `10B7E146B3E9E7B96305C4714C84039E5451B66829B143971E8C74D7A8D12C4C` (6.546.618 caracteres). `sincronizar-entorno.ps1` informó Flutter sin cambios; CORS/URLs de retorno ya coincidían antes de correr. No se reinició Nest ni Cloudflare, no se modificaron OAuth, secretos ni datos. Flutter reportó advertencias no bloqueantes de Wasm (dependencias `dart:html`/`dart:js_util`) y de fuente `CupertinoIcons` ausente; ambos builds JavaScript terminaron con exit 0. La salida pública añade Cloudflare Insights en HTML; la verificación byte a byte fue sobre `main.dart.js`.

**PED-POS-CAJA-GATE-01 (2026-11-24):** el guard de `PedidoCajeroScreen._confirmarPedido()` exige caja abierta a Admin/Cajero para cualquier tipo antes de revisar si se hará un cobro. El backend difiere el movimiento de mesa hasta cobrar y de domicilio hasta entregar; Mesero no pasa por ese guard. Puede ser regla de pertenencia a turno, pero el copy no aclara por qué se bloquea la toma del pedido. Decidir si abrir caja es precondición universal del pedido o solo del recaudo inmediato; considerar cruce de turnos y cierre de órdenes abiertas. Sin cambios de código/datos. `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**Regresión Flutter posterior al build (2026-11-24):** suite completa 209 aprobadas, 5 omitidas (QA mutadora), 0 fallidas; analyzer focalizado de `pedido_cajero_screen.dart` limpio con `--fatal-infos`. Esta suite no verifica autenticación real ni define el guard universal de Caja en POS (`PED-POS-CAJA-GATE-01`). La inspección visual Chrome sigue pendiente: CUA reportó el árbol de pestaña Foody, pero la captura correspondió a Codex y no sirve como evidencia visual. No se cambiaron datos ni lógica del POS.
**PED-POS-REPLACE-ATOMIC-01 (2026-11-24):** reemplazo usa `POST /pedidos/:id/items/:itemId/reemplazar`, agrega/quita con un `PoolClient`, persiste resultado idempotente y bloquea líneas ya cobradas/asignadas o reembolso implícito. POS ejecuta una sola solicitud. Nest 37 suites/92 pruebas, build OK; Flutter global 237 aprobadas/5 E2E omitidas, POS+repo 20/20; analyzer focalizado limpio; build web release en QA aislada exitoso (warnings Wasm/iconos no bloqueantes). No reinicié API :3000/Tunnel; fuente/build requiere activación coordinada.
**FIN-PAYROLL-PERIOD-01 (2026-11-24):** pendiente definir obligación por ciclo, vencimientos y saldo para frecuencias diaria/semanal/quincenal/mensual. El saldo parcial de costos fijos quedó corregido por FIN-FIXED-PARTIAL-BALANCE-01; no modificar nómina sin definición y conciliación histórica.

## 2026-11-24 — Idempotencia POS y liberación de mesas agrupadas

`PED-ITEM-IDEM-01`: se añadió clave idempotente al endpoint de agregar líneas. Replay con mismo payload devuelve el resultado previo, payload diferente con la misma clave da 409. Clave y resultado se guardan atómicamente con las líneas, inventario y transiciones. Migración 090 aplicada únicamente a `foody_diseno_qa`; API diaria aún requiere activación del build actual. E2E completa QA: 8 suites/25 pruebas; Flutter global 223 aprobadas/5 omitidas; backend unitario completo en espera de lectura del proceso de esta sesión.

`MES-GROUP-RELEASE-01`: al cerrar el último pedido de una mesa agrupada, libera todos los miembros solo si ninguno conserva pedidos activos. Evita estado ocupado residual que bloqueaba cierre de Caja. Unitarias focalizadas + E2E completo QA (incluido cierre de Caja) pasan; build Nest OK. Documentación detallada: `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

Los checks y las pruebas mutadoras se limitaron a PostgreSQL `foody_diseno_qa` / Nest :3001. El launcher diario se ejecutó en modo `tunel` y reconstruye actualmente Cliente/Equipo; no se modificaron OAuth, credenciales ni configuración de servicios.

**Activación diaria verificada (2026-11-24):** migración 090 (tabla idempotencia de agregar ítems, RLS forzada) aplicada a BD local; Nest reiniciado PID 6860. La prueba E2E real de retry se agregó después: misma clave/payload retorna el resultado sin duplicar y otro payload devuelve 409; ver PED-ITEM-IDEM-01. En aquel corte: unitarias Nest 30/70, E2E aislada 8/25 y Flutter 223 aprobadas/5 omitidas. Launcher diario reconstruyó Cliente/Equipo; seis endpoints local/públicos HTTP 200 y hashes local/Tunnel coincidentes. OAuth, DNS, secretos y datos de negocio intactos. QA visual autenticada sigue pendiente.

**PED-STAFF-IDEM-02 (2026-11-24):** además de retener la clave para un retry idéntico, el POS calcula una huella del payload. Si carrito/canal/mesa/contacto/pago/propina/nota cambia tras fallo, usa clave nueva; evita recuperar por accidente el pedido asociado a un intento anterior. POS 15/15, analyzer focalizado limpio, Flutter global 224 aprobadas/5 omitidas. Cliente/Equipo publicados y hashes exactos local/Tunnel; seis endpoints HTTP 200. API activa PID 6860, Tunnel PID 11112; sin mutaciones de pedidos.

## Actualización de runtime y aislamiento de pedidos — 2026-11-24

**PED-KEY-SCOPE-01 — resuelto:** claves idempotentes de alta de pedido aisladas por sucursal y huella SHA-256 de payload; migración 091 activa y RLS forzada. Evidencia, riesgos de compatibilidad de filas históricas y pruebas: `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`. Nest diario PID 11708; cloudflared PID 11112. API local/pública, Cliente y Equipo local/público HTTP 200; CORS equipo HTTP 204 y origen permitido coincide. El QA :3001 está detenido. No se alteró OAuth ni se crearon pedidos comerciales.

**Observación navegador:** errores de CORS/mixed content revisados correspondían a una pestaña con bundle anterior; el bundle publicado actual usa endpoints HTTPS por Tunnel. Notificaciones FCM no obtienen token cuando Chrome mantiene permiso denegado, pero ese error se captura y no bloquea operación. QA visual autenticada pendiente; referencia completa en auditoría de pedidos.

**Próximo paso recomendado:** continuar la trazabilidad de los flujos operativos desde la UI autenticada, refrescando primero la pestaña de Equipo para cargar el bundle actual.

**Addendum — arranque comprobado (2026-11-24):** ejecutado `scripts/iniciar1/iniciar-foody-subdominios.bat` con builds vigentes: exit 0; detectó API en :3000, modo `tunel`, conservó cloudflared (PID 11112), reinició Equipo :8080 (PID 3424) y Cliente :8081 (PID 4520). El launcher informó `main.dart.js` cliente de 6.552.311 bytes. Smoke posterior de los seis destinos local/públicos: todos HTTP 200. No necesitó reconstruir porque los builds existían y estaban al día; el camino de build faltante/desactualizado está definido en `servir-web-tunel-release.ps1`, aunque no se forzó una compilación destructiva solo para reproducir ese caso.

**COC-NODISP-COMMERCE-01 — abierto, alto (2026-11-24):** cuando Cocina marca una línea no disponible, el pedido puede pasar a `listo` sin recalcular total, abonos, pagos, factura ni Caja; el despacho a domicilio sí se bloquea. La merma se registra y el producto se desactiva. La operación administrativa de borrar línea recalcula importes, pero no resuelve sobrepago/reembolso, así que la política de sustitución/ajuste debe decidirse antes de modificar dinero. E2E cocina QA 3/3; el test no cubre saldo/cobros, verificado como brecha. Detalle y evidencia en `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`. Matriz de consistencia corregida: COC-NODISP y cascada de stock están resueltos en código; no confundir con esta brecha comercial abierta.

**PED-DELETE-NODISP-STOCK-01 — ✅ corregido (media, 2026-11-24):** eliminar una línea `no_disponible` ya no repone stock después de que Cocina registró la merma. E2E QA valida inventario tras alta→N/D→borrado; batería integrada 9/9, Jest E2E 27/27, Nest unitarias 72/72, Flutter relacionado 50/50. Sin cambio a total/caja/reembolso. QA limpia y :3001/:8765 apagados. Ver `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**Activación posterior a PED-DELETE-NODISP-STOCK-01 (2026-11-24):** se reinició solo Nest diario para cargar el build corregido (PID 8284). API `:3000`, Cliente `:8081`, Equipo `:8080`, sus tres hostnames públicos y CORS preflight de Equipo: HTTP 200/204 con origen exacto. Cloudflare Tunnel sigue PID 11112. QA `:3001` y agente de impresión `:8765` están abajo; base QA sin pedidos activos y jobs temporales limpiados. No se tocaron OAuth, credenciales, rutas de túnel ni datos comerciales.

**ANA-FILT-PROD-01 — confirmado ✅ (2026-11-24):** KPI/series con filtro producto/categoría/cocina se calculan desde líneas del pedido (`analitica.service.ts:133-177`). Matrix y backlog ya alineados; batería completa incluye verificación analítica. No se requirió cambio de código.

**Aviso N/D previo a cobro (2026-11-24):** detalle administrativo del pedido y flujo de cobro de mesa presentan una advertencia cuando las unidades `no_disponible` siguen incluidas en el total; cobro por ítems filtra el conteo a lo seleccionado. Cambio solo de presentación, sin modificar importes ni reglas. Flutter detalle/mesa 13/13 y analyzer focalizado limpio. Build release Equipo/Cliente con launcher exit 0; URLs locales y públicas + API HTTP 200; cloudflared PID 11112 activo. La conciliación comercial permanece abierta en COC-NODISP-COMMERCE-01. Sin cambios OAuth/credenciales ni datos comerciales.

**Consistencia documental de promociones (2026-11-24):** se reconciliaron las referencias históricas de CONS-PROMO-ADD-01, PROMO-DEL-01 y PROMO-MANUAL-01 con el código/migración actuales: las tres están resueltas. El helper de líneas se comparte entre agregar, eliminar y actualizar; la regresión integrada registrada cubre agregar. Siguen abiertas las reglas de apilación combo+promo y de modificar líneas de un pedido cuando su promoción ya fue desactivada. No hubo cambio de código.

**FIN-TZ-ANALITICA-CAJA-01 (2026-11-24):** Analítica Caja usaba límites `::timestamptz` dependientes de PostgreSQL para `gastos.created_at` y `cajas.cierre_at`. Ahora usa el rango compartido America/Bogota. Analítica/Reportes/Finanzas 6 suites/11 pruebas, build OK y consulta de límites verificada en PostgreSQL QA UTC. Pendiente separado: decidir si el libro/reportes de gastos agrupa por `gastos.fecha` o por `created_at`; no se alteró esa regla.

**Caja / Reportes — FIN-MIXED-REFUND-METHOD-01 (2026-11-24):** en cancelaciones con cobro mixto la reversa agrupa el neto total en un movimiento con el método de la primera fila; Reportes/Analítica desglosan por método. Total general puede cuadrar con clasificación errónea. Regla de devolución mixta/parcial pendiente; sin cambio contable. Ver `AUDITORIA_CAJA.md`.

**Actualización — FIN-MIXED-REFUND-METHOD-01 (2026-11-24):** fuente y `dist` ahora registran la reversa por caja/método de origen; el total neto del reembolso se conserva. Unitaria 3/3 y build OK; E2E agregada sin ejecución. La API :3000 sigue usando el proceso anterior porque el control automático rechazó reiniciarlo; no se alteró el proceso ni el Tunnel.

**Cocina / Inventario — COC-CANCEL-NODISP-MERMA-01 (2026-11-24):** cancelación de pedido en cocina repetía la merma de líneas `no_disponible`, ya contabilizada por la acción de Cocina. La fuente ahora las excluye al registrar merma global; unitarias 4/4 combinadas y build OK. E2E añadida, no ejecutada; el API :3000 sigue con proceso anterior porque el reinicio fue rechazado por control automático. Sigue por definir si líneas aún pendientes al entrar el pedido a cocina deben tratarse como merma al cancelar.
**PED-ENCARGO-QUOTE-DATE-01 (2026-11-24):** Checkout cotizaba encargos antes de elegir fecha; Nest rechazaba la estimación y Flutter caía al total local. La cotización sin fecha ahora se permite, valida fecha si se envía y mantiene fecha obligatoria en creación real. Unitaria 5/5; runtime diario/E2E aún pendientes.

**PED-CLIENT-CANCEL-RACE-01 (2026-11-24):** se cerró el hueco de concurrencia entre validar cancelación del cliente y transición del pedido: la transacción con FOR UPDATE vuelve a aplicar las restricciones con rol cliente. Regresión 1/1 pasa; API diaria sin reinicio.

**Aclaración PED-CLIENT-CANCEL-RACE-01 (2026-11-24):** bajo bloqueo se invoca la regla específica del cliente (pendiente sin límite temporal; confirmado ≤2 min; en cocina bloqueado), evitando alterar semántica. Jest total 34/34 suites, 79/79 pruebas y build OK; runtime diario no reiniciado.

**Verificación integrada pedidos/arranque (2026-11-24):** Nest unitario completo 34 suites/80 pruebas, build OK. Smoke read-only a salud API local/pública y web Cliente/Equipo local/pública: 6/6 HTTP 200. El atajo scripts/iniciar1 delega al launcher principal; existen ambos builds web. Sin reinicio para preservar la sesión activa de Cloudflare; fuente compilada aún requiere activación coordinada en :3000.

**DOM-EARNINGS-TRUTH-01 (2026-11-24):** el panel del domiciliario independiente rotula las cifras como estimación calculada al aceptar, advierte que puede incluir cancelaciones/no confirma pago y muestra estado de asignación. Backend solo añade el campo de estado por fila; importes/reglas intactos. Widget 8/8 (4 anchos × claro/oscuro), Admin domiciliarios 14/14, analyzer limpio; bundle Equipo no publicado. DOM-CANCEL-PAYOUT-01 pendiente de decisión.

**POS-COTIZACION-CASH-GUARD-01 (2026-11-24):** nueva venta para llevar con cobro inmediato ya no permite usar un precio local aproximado si falla /pedidos/estimar; reintenta y cobra únicamente tras total de servidor. No afecta mesa, mesero, pago diferido ni agregar líneas. Flutter POS 16/16, analyzer limpio, build release Equipo QA OK (advertencias Wasm/dependencias y CupertinoIcons preexistentes). Artefacto QA no publicado; API/Tunnel no reiniciados.

**COC-KDS-NULL-STATE-01 (2026-11-24):** el esquema permite `pedido_items.estado_cocina` nulo, y SQL `NOT IN` no lo considera pendiente; caja podía interpretarlo como resuelto. La fuente ahora trata NULL como pendiente en el guard de cobro, recálculo y consulta KDS. Regresión + KDS readonly 4/4; Nest total 35/35 suites y 83/83 pruebas; build y Prettier focalizado OK. Sin migración ni cambios de datos. No se reinició API :3000 ni Tunnel; el runtime aún requiere activación.

**PED-DISCOUNT-READY-CLOSE-01 (2026-11-24):** un descuento que cubría el saldo de pedido de salón listo podía dejarlo en `listo`/`pagando`. La fuente ahora cierra a `pagado` vía máquina central e historial cuando el nuevo saldo queda cubierto; no adelanta pedidos `en_cocina` ni interrumpe despacho domicilio. Nest 36/36 suites y 86/86 pruebas; build/formato OK. Sin reinicio de API/Tunnel.
**FIN-DISCOUNT-REFUND-METHOD-01 (decisión pendiente):** reembolso automático por descuento guarda método NULL; Reportes/Analítica lo agrupan como `sin_metodo`. Definir si se devuelve por medios originales, medio real seleccionado o si se solicita elección (incluidos pagos mixtos). Sin ajuste por conjetura.

**Cierre operativo PED-DISCOUNT-READY-CLOSE-01:** transición a `pagado` también libera la mesa solo si no quedan pedidos activos y emite evento de mesa; Nest 36/36 suites, 86/86 pruebas, build y Prettier OK. API/Tunnel no reiniciados.

**KDS-LEGACY-STATE-UI-01 (2026-11-24):** test de estado de cocina nulo confirma ticket en Cocina y acción “Marcar listo”; suite KDS 14/14 en breakpoints móviles/tablet/escritorio. Chrome solo mostró login; sin autenticación ni cambios de credenciales. Falta QA visual autenticada por rol.

**Analítica responsive NAV-ANL-01 (2026-11-24):** se verificó selector único para anchos <720 px y TabBar en escritorio, ambos ligados al mismo controlador para preservar deep links y permisos. Tests de pantalla 4/4; casos de navegación 390/1440 px. QA visual con sesión autenticada pendiente.

**PUSH-PERM-STATUS-01 (2026-11-24):** Firebase web entrega `NotificationSettings`, pero el cliente comparaba el objeto con `AuthorizationStatus`; una autorización válida podía impedir obtener/registrar el token. Ahora se lee `authorizationStatus`. Dart focalizado sin errores/warnings; sin activar permisos ni cambiar OAuth/credenciales. Flutter total 236 aprobadas/5 E2E omitidas. El análisis global conserva 1 warning legacy y 35 infos.

**Smoke de disponibilidad 2026-11-24:** API salud, Equipo y Cliente local/público 6/6 HTTP 200. No reinicié ni reconstruí el runtime; lo compilado en fuente/dist aún no queda activo por este smoke.

**DOMI-TOTAL-ENTREGAS-ACCEPT-01 (2026-11-24):** `total_entregas` se incrementaba al aceptar oferta y sobrevivía a cancelación. Ahora incrementa solo al confirmar entrega dentro de la misma transacción que cierra la asignación. Regresión aceptación/entrega, Nest 36/36 suites y 87/87 pruebas, build/Prettier OK. Sin actualización de datos históricos ni reinicio de runtime.
**DOM-CANCEL-PAYOUT-01:** la comisión/ganancia se crea al aceptar y puede permanecer si hay cancelación; panel la llama estimada y no se encontró liquidación de independientes. Definir devengo/pagador/cancelaciones antes de tocar liquidación.

**DOMI-LIQUIDACION-METODO-EXTERNO-01 (hallazgo 2026-11-24; E2E agregado 2026-11-25):** el ciclo con abono y replay ya está probado en clon; la liquidación de CxC crea efectivo en Caja y el scalar conserva el primer pago cronológico. SQL: `monto_pagado=13.000` frente a pagos/Caja $8.000, porque la tarifa $5.000 quedó fuera de Caja y no se registra en `pagos_pedido` en `pendiente_liquidacion`. Método/destinatario/ledger de ese componente quedan como DOMI-OFF-CAJA-TRACKING-01; no suponer efectivo ni sumar a Caja. Detalle: `docs/archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md`.

**GLOB-ERROR-STATE-RESP-01 + START-TUNNEL-SMOKE-02 (2026-11-24):** se refinó el estado de error compartido con superficie temática, ancho máximo y acciones táctiles de 48 px; F5-03 continúa parcial. `foody_estado_ui_test.dart` 8/8 y analyzer limpio. El launcher `scripts/iniciar1/iniciar-foody-subdominios.bat` terminó exit 0, compiló Cliente y Equipo, reinició solo servidores web y conservó API y `cloudflared`. Seis destinos local/públicos (Cliente, Equipo, API salud) HTTP 200 y SHA-256 de ambos bundles locales coincide con el público. Preflight confirmó sin cambios en URLs, CORS ni URLs de retorno; no se alteró OAuth, credenciales ni datos.

**F4-04 MESAS-ROLE-CONSISTENCY-01 (2026-11-24):** confirmado que panel admin, cajero y mesero reutilizan `MesasGridWidget`; las diferencias son parámetros de modo/acciones del rol. `mesas_grid_widget_test.dart` 10/10 y analyzer de los tres paneles/widget limpio. Sin cambio de permisos ni operaciones.

**COC-DISPATCH-INCOMPLETE-01 addendum (2026-11-24):** la barrera de despacho ya protegía al repartidor, pero el estado global todavía podía quedar falso. `PedidosEstadoCommandService` ahora exige al menos un ítem y todas las líneas resueltas (`listo`/`no_disponible`) antes de escribir estado `listo` desde Kanban o Cocina automática; si falla no actualiza pedido ni historial. Contrato de error Nest→Flutter probado. Jest completo 38 suites/96 pruebas, build OK; fuente/dist actualizados. `:3000` no se reinició y falta E2E PostgreSQL QA aislada.

**PED-EDIT-01 addendum (2026-11-24):** modificar una línea `listo` podía devolverla a `pendiente` mientras el pedido seguía listo; cambiar observaciones no reiniciaba Cocina. Ahora cambios reales de cantidad/toppings/observaciones reabren `listo`/`pagando` a `en_cocina` por el comando e historial central, y la notificación usa el estado resultante. También se bloquea una reducción por debajo de `monto_pagado` en edición/eliminación; reemplazo conserva su guard específico; sin reembolso automático. Jest 39 suites/101 pruebas y build Nest OK. `:3000` no reiniciado; falta E2E DB QA para comprobar rollback y flujo financiero.

**QA-E2E-ISOLATION-01 (2026-11-24):** intento de iniciar API aislada `127.0.0.1:3001` contra `foody_diseno_qa` evidenció que Nest aún inicializa Firebase Admin desde la ruta del entorno del repositorio aunque variables Firebase se pasen vacías. Se detuvo antes de E2E; no hubo pagos ni escrituras de negocio. QA reporta 0 fuentes Wompi activas / 0 candidatas de renovación; API local y pública `:3000` responden HTTP 200 y QA `:3001` quedó detenido. No ejecutar E2E vía API completa hasta contar con aislamiento comprobable de FCM y workers externos.

**2026-11-24 — QA-E2E-ISOLATION-01 resuelto:** agregué el switch opt-in `FOODY_QA_SIN_EFECTOS=1`. En QA Nest omite credenciales/clients Firebase, Supabase y Storage, crons de suscripciones, notificaciones, QR, promociones, reservas, demoras de Cocina y cola de impresión, además del expirador y el auto despacho. La aplicación normal no cambia con la variable ausente. Con ese aislamiento: Jest unitario 40/40 suites, 102/102; E2E API 8/8 suites, 32/32; batería funcional amplia 9/9 scripts; build OK. E2E verificó Cocina incompleta, edición tras listo y guard de abono/total con rollback conservando total, cantidad y saldo. `:3001` y el agente de impresión quedaron detenidos; cliente/equipo/API local y público 6/6 HTTP 200. `:3000` no se reinició, así que estas correcciones aún necesitan activación coordinada para llegar al Tunnel.

**2026-11-24 — QA E2E: última verificación de aislamiento externo:** también quedaron bloqueados en `FOODY_QA_SIN_EFECTOS=1` Wompi, Supabase Auth y Photon. Tests de contrato comprueban que Wompi no hace solicitudes aunque haya claves y Supabase Auth no crea cliente ni lee config. Resultado final: `npm run build` OK; Nest 42 suites/104; PostgreSQL E2E 8 suites/32; scripts funcionales 9/9. QA :3001 y agente impresión detenidos; seis destinos local/Tunnel HTTP 200. :3000 sigue sin reinicio/publicación.

**Runtime diario confirmado (2026-11-24 21:48 COT):** API :3000 PID 19492 sirve `dist/main.js`, compilado 21:22:34; el proceso inició antes de esa compilación y por tanto no prueba los cambios Nest recientes. API local/pública, Cliente local/público y Equipo local/público responden HTTP 200; `cloudflared.exe` PID 8940 sigue activo. :3001 no tiene listener. El contenedor persistente `foody-diseno-qa-db` está arriba en puerto 55494, pero no hay API QA conectada; no confundirlo con una E2E activa ni ejecutar fixtures contra él sin clonar/confirmar destino. No se reinició la API ni se publicaron builds.

**RBAC-MT-READ-01 / MT-WRITE-ORDER-01 (2026-11-24):** en dos clones temporales de `foody_diseno_qa`, API Nest aislada :3001 (`FOODY_QA_SIN_EFECTOS=1`), el admin demo y un admin sintético de otro tenant obtuvieron HTTP 200 al listar su propia sucursal y HTTP 403 al listar o intentar crear pedidos en la sucursal ajena, en ambos sentidos. Para habilitar el login sintético, se copió el hash de la contraseña demo solo dentro del segundo clon; nunca se cambió el QA original. Un `SELECT` posterior confirmó 0 pedidos con los IDs de prueba. Ambos clones se eliminaron y :3001 se detuvo. Sigue pendiente probar autorización de cierre de caja cross-tenant por API; la cobertura actual `RBAC-TENANT-01` prueba caja de sucursal hermana dentro de un mismo restaurante. Sin cambios de datos de negocio, OAuth o Tunnel.

**FIN-PAY-RECONCILIATION-01 addendum (2026-11-25):** el detalle de pedido agrega devoluciones de Caja con vínculo verificable por `pedido_id` + `sucursal_id` y calcula recaudo neto únicamente con ventas de Caja menos devoluciones enlazadas. No mezcla canales de `pagos_pedido`; la UI advierte que devoluciones sin pedido se concilian aparte y mantiene propina separada. Jest focalizado 1/1, build Nest OK; detalle Flutter 5/5 en 320/390/820/1440, analyzer focalizado limpio. No reinicio de API ni escritura de datos. Resta auditar estados/canales y decisión de reconocimiento financiero.

**COST-RECIPE-VISUAL-QA-01 (🟡 pendiente, 2026-11-25):** verificación final manual de Costos y márgenes con sesión autenticada no realizada: ambas ventanas Chrome de «Foody Equipo» estaban minimizadas y la interfaz de control no pudo activarlas. Esto no es un fallo funcional observado. Referencia estructural confirmada: producto destacado, cinco etapas, grupos plegables y resumen claro responsive. Revalidación local: `flutter test --no-pub test/costos_margenes_screen_test.dart test/costeo_flujo_receta_test.dart` 17/17; `flutter analyze --no-pub` sobre 6 archivos (pantalla, widgets y pruebas) sin issues. Pendiente solo abrir/revisar la pantalla con Chrome visible y receta real autenticada; pruebas fake no verifican persistencia/API real.

**FIN-PAYROLL-FREQUENCY-01 (🟡 hallazgo financiero abierto, 2026-11-25):** los DTO aceptan diario/semanal/quincenal/mensual y pagos guardan periodo_desde/hasta, pero FinanzasService.resumen() excluye al empleado si existe cualquier gasto origen='nomina' en el mes calendario, sin sumar pagos ni revisar período. Evidencia: finanzas.service.ts cerca de líneas 337–390 (pago con períodos opcionales) y 535–548 (NOT EXISTS por fecha mensual); DTO crear-empleado.dto.ts limita frecuencia a cuatro valores. Un abono parcial o pago de primera quincena puede ocultar el saldo/la siguiente obligación. No se cambió fórmula. Decisión pendiente: acordar si sueldo_base representa monto por período o mensual y cómo derivar períodos/vencimientos; luego mostrar saldo pagado/restante y permitir varios pagos por ciclo sin duplicar obligación. Riesgo: administrador cree que nómina quedó pagada cuando solo registró un abono.
**OPS-RUNTIME-STALE-01 verificación vigente (2026-11-25 21:43 COT):** Nest PID 7584 inició 13:50:31; foody_backend/dist/main.js tuvo última escritura 20:55:17 y el fuente pedidos-estado.service.ts 20:51:41. Por tanto, /api/v1/salud HTTP 200 prueba disponibilidad pero no activa/reconoce estos artefactos posteriores. API local y pública devuelven exito=true con timestamps UTC separados por 1 s y versión reportada 2026-07-01; Equipo/Cliente local y públicos HTTP 200; Cloudflare Tunnel PID 8940 activo. No se reinició ningún servicio, tocó OAuth/credenciales/datos ni se interrumpió Tunnel. Pendiente reinicio coordinado de Nest y verificación semántica de los fixes antes de marcarlos activos.
**REP-TIMELINE-FRESH-01 (✅ corregido en fuente, 2026-11-25):** al cambiar el período en Reportes, la pestaña Auditoría invalidaba el timeline sin volver a cargarlo; además el error se silenciaba y el listener reintentaba al terminar la animación de pestaña, pudiendo reemplazar el fallo por un falso vacío. Ahora el período nuevo solicita timeline tras cargar los reportes, respuestas fuera de orden quedan invalidadas, fallo muestra error/reintento y no hay retry automático. Flutter reportes  9/9 en 320/390/820/1440; analyzer 2 archivos limpio; detector Impeccable sin hallazgos. Sin cambios backend, cálculos, datos ni Tunnel.
**REP-AUDIT-TZ-01 (🟡 corregido en fuente, 2026-11-25):** el timeline recibía fechas YYYY-MM-DD pero comparaba timestamptz contra medianoche UTC y fin 23:59:59.999Z; desplazaba el día de negocio. Las cuatro fuentes usan ahora `sqlFechaRango` compartido con límites America/Bogota e intervalo semiabierto, conservando `created_at` sin función para aprovechar índices. El default del endpoint usa día Bogotá. Pruebas Nest 2 suites/3 tests; build OK; CTE de solo lectura en foody_diseno_qa confirmó 2026-11-25 = [05:00Z, 05:00Z del día siguiente), 04:59:59Z incluido y 05:00Z excluido. API/Equipo/Cliente local y público HTTP 200, Tunnel PID 8940 activo. Nest PID 7584 inició 13:50:31 y no se reinició; dist/main.js ahora 22:03:45, así que fix aún no está activo en runtime. Sin escrituras en DB ni cambios OAuth/credenciales/Tunnel.
**OPS-RUNTIME-STALE-01 update (2026-11-25 22:03 COT):** Nest PID 7584 inició 13:50:31; dist/main.js se actualizó 22:03:45 al compilar REP-AUDIT-TZ-01. API, Cliente y Equipo local/públicos continúan HTTP 200; Cloudflare Tunnel PID 8940 activo. No se reinició Nest: la compilación nueva no se declara activa hasta reinicio coordinado + smoke semántico.
**OPS-RUNTIME-STALE-01 verificación final (2026-11-25 22:08 COT):** build final de Nest actualizó dist/main.js a las 22:08:55; PID 7584 sigue iniciado 13:50:31. API local y Tunnel HTTP 200; salud local/pública exito=true con timestamps iguales; Cloudflare PID 8940 activo. No se reinició el servicio. REP-AUDIT-TZ-01 está compilado y probado pero aún no está cargado por :3000.

**WOMPI-TX-LOOKUP-AUTH-01 (🟡 corregido en fuente, runtime pendiente, 2026-11-25):** `consultarTransaccion()` enviaba llave pública, pero el endpoint oficial de Wompi requiere llave privada y responde 404 con llave pública. Ahora usa la llave privada del backend. Prueba unitaria 2/2 y typecheck Nest pasan; no se invocó Wompi ni se usaron credenciales reales. Falta E2E/runtime en entorno aislado y verificar la llamada de consulta bajo el flujo real autorizado. Referencia: [Seguimiento de transacciones Wompi](https://docs.wompi.co/docs/colombia/seguimiento-de-transacciones/).

**OPS-RUNTIME-STALE-01 / IMP-QUEUE-CLASSIFY-01 — verificación read-only 2026-11-25 23:12 COT:** API local y `api.foodyy.store` responden `GET /api/v1/health` HTTP 200; el estado es `degradado` por `cola_impresion_errores:317`. PostgreSQL, Realtime y agente de impresión aparecen conectados; cola: 0 pendientes, 317 errores históricos y 1 enviado en 24 h. No se reencolaron jobs. Nest PID 7584 arrancó 13:50:31, antes de `dist/main.js` (22:08:55), por tanto el runtime no acredita los fixes actuales. Cloudflared PID 8940 activo; Equipo PID 9892 y Cliente PID 8480 responden local y por Tunnel HTTP 200. QA :3001 no está escuchando. Sin reinicios ni escrituras.

**Regresión focalizada multi-módulo (2026-11-25 23:13 COT):** pedidos resumen de pagos, liquidación domiciliarios/idempotencia, analítica cancelados, Wompi consulta, reserva renovaciones y asociación webhook: **6 suites / 12 pruebas** aprobadas; typecheck Nest `npx tsc --noEmit --incremental false -p tsconfig.build.json` aprobado y `git diff --check` limpio. Son unitarias/focalizadas, no sustituyen E2E con PostgreSQL aislado ni prueba del runtime PID 7584.

**Revisión visual autenticada por Tunnel (2026-11-25 23:21 COT) — Pedidos/Costos:** en Costos, escritorio 1920×1080 mostró el master-detail amplio; al restaurar la ventana ~500 px, la vista móvil tras recarga se apiló correctamente y conservó controles. El registro visible `cerso asado` tiene nombre posiblemente mal escrito y fotografía que contiene una captura de login, además figura sin receta pese a mostrar Stock OK / 1 venta; parece calidad de contenido del catálogo, no se modificó por ser dato del negocio. En Pedidos, 9 abiertos por $1.381.400; al filtrar Cobro/Ruta se vieron 8. Entre ellos, dos para llevar `#FDY-2026-0015`/`0014` en `Pagando` con edad 2947 h 55 min, y domicilio `#FDY-2026-0016` `En camino`, edad 2732 h 57 min y dirección «Por confirmar». Son datos visibles actuales, no clasificados como QA ni evidencia de deuda/cobro vigente: no abrir acciones ni cambiar estado hasta conciliación. A 500 px los chips de estado son desplazables con fade, pero el siguiente («Por cobrar») queda parcialmente visible; revisar una señal de desplazamiento más evidente. No se crearon ni editaron pedidos.
