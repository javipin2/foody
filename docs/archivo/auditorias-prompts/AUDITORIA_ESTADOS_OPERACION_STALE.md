# Auditoría de pedidos y sesiones operativas envejecidos — 2026-11-25

## Alcance

Lecturas agregadas de Supabase local dentro de `BEGIN READ ONLY`/`ROLLBACK`, cruce de `pedidos`, `asignaciones_domicilio`, `estados_pedido_historial`, `mesas`, `cajas`, `movimientos_caja` y `domiciliarios_sesiones`, más revisión del código vigente de transiciones y cierres. No se leyó ni publicó información de clientes, no se modificó ningún registro y no se confirmó si la data pertenece a una demo, pruebas o un negocio real.

## Hallazgos

### OPS-STALE-ORDERS-02 — pedidos en estado operativo durante meses

Al corte había 15 pedidos en estados `pendiente`, `en_cocina`, `pagando`, `asignado` o `en_camino` con más de 24 horas: 14 se crearon hace más de 30 días y uno el 22-nov. El saldo aparente agregado (`total - monto_pagado`, limitado a cero) es $1.312.384 COP; no se interpreta como deuda real ni ingreso confirmado mientras no se determine si son fixtures.

Distribución >30 días: para llevar/pagando 5; mesa/pagando 4; mesa/en_cocina 2; domicilio/en_camino 1; domicilio/asignado 1; domicilio/pendiente 1. El pedido restante es para llevar/en_cocina y se creó el 22-nov.

Impacto si los registros son operativos reales: tablero y alertas presentan pedidos viejos como activos; cuatro de once mesas activas aparecen ocupadas por pedidos; los cierres de caja pueden seguir bloqueados por pedidos abiertos; los importes abiertos contaminan el seguimiento de ventas pendientes y del trabajo de Cocina/Domicilio.

### DOM-STATE-RECON-01 — pedido y asignación no coinciden

El domicilio antiguo actualmente `en_camino` tiene historial `asignado → en_camino` con fecha 04-ago-2026, pero su fila de `asignaciones_domicilio` permanece `asignado` desde 26-jul-2026. El servicio vigente de domiciliario de planta e independiente cambia primero `asignaciones_domicilio.estado` a `en_camino` y aplica el estado del pedido dentro de una misma transacción; la evidencia apunta a dato legado/inconsistente, no confirma un defecto en la ruta actual. Esta discrepancia puede impedir que las consultas de ruta/ubicación que filtran asignaciones `en_camino` encuentren el repartidor correcto.

El otro domicilio actualmente `asignado` coincide con su asignación; se creó el 04-ago. La relación de estado por pedido se documentó sin revelar IDs ni dirección/teléfono.

### OPS-STALE-CASH-SESSION-01 — cajas abiertas durante meses

Se observaron 7 cajas abiertas en 7 sedes, todas con apertura anterior a 30 días; la más antigua se abrió el 02-jul. Cuatro no tienen movimientos registrados en los últimos 30 días. Esto puede impedir abrir un turno nuevo o acumular recaudos de varios periodos en un solo arqueo. No se cerró ninguna caja ni se alteraron movimientos.

### DOM-SESSION-STALE-01 — sesiones activas de domiciliario antiguas

Hay dos sesiones de domiciliario con `activa=true` desde hace más de 30 días. Pueden afectar disponibilidad y despacho si son sesiones abandonadas, aunque se requiere comprobar si los dispositivos siguen activos. No se desconectó a ningún domiciliario.

## Estado del runtime API

El PID 10204 que escucha :3000 se inició el 25-nov a las 07:22 local. En la nueva lectura `foody_backend/dist/main.js` ya está actualizado a las 09:14 local, después del arranque. El proceso sigue siendo PID 10204 y muestra respuesta `version=2026-07-01`; la gráfica pública sigue teniendo solo dos fechas. `scripts/verificar-backend.bat` (exit 0), `/salud` 200 y `/salud/completo` 200 demuestran que la API está disponible/rutas existen, no que ese PID cargó los cambios recientes.

### Resolución runtime 2026-11-25 13:50 COT

Se compiló el estado actual de Nest (`npm run build`, exit 0) y se reemplazó el PID 10204 identificado como el proceso Foody dueño de :3000 por el PID 7584, iniciado 13:50. Local y Tunnel `/salud` devolvieron HTTP 200; `scripts/verificar-backend.bat` exit 0. El texto `version=2026-07-01` es constante fija en `SaludService`, por tanto no identifica el build ni se utilizó para validar frescura. Se endureció `iniciar-backend-wsl.bat` comparando hora de inicio del PID con `dist/main.js`, con aviso de estado stale y sin cierre automático.

La instancia se inició bajo `scripts/iniciar-backend-wsl.bat` (`cmd` → `node dist/main.js`). El mismo iniciador comprueba la salud y si ya funciona va a `api_ya_corre`, donde conserva el proceso y muestra “cierra la otra ventana primero”; volver a ejecutarlo no recompila ni activa el `dist` nuevo. También había otro intento de launcher en curso, pero no reemplazó PID 10204. Se requiere cerrar el terminal propietario mediante su flujo normal y volver a iniciar; un control automático de seguridad rechazó que el agente detuviera el PID directamente, y no se buscó una ruta alternativa para forzar el restart.

## Verificación y límites

- Todas las consultas de datos terminaron en `ROLLBACK` en transacción `READ ONLY`.
- Salud profunda: DB/Reatime/agente de impresión conectados, cola sin pendientes y 317 jobs terminales en error (ver `AUDITORIA_IMPRESION_COLA.md`).
- El verificador oficial `cmd /c scripts/verificar-backend.bat` terminó exit 0; es una comprobación de salud/rutas, no de semántica de cada feature.
- No se realizó login, no se llamó a endpoints mutadores, no se cerró caja/pedido/sesión y no se disparó reimpresión.

## Siguiente paso seguro

1. Determinar si la base local es exclusivamente QA/demo y si estos registros deben preservarse.
2. Si son datos de prueba, preparar una limpieza acotada con respaldo/preview y verificación de efectos dependientes; no ejecutar limpieza general sobre pedidos que hoy no cubre el helper QA.
3. Si son registros de operación, conciliar uno por uno con el negocio antes de transicionar estados, liberar mesas/sesiones o modificar Caja.
4. Reiniciar Nest de forma coordinada al artefacto actual y verificar en runtime el listado de pedidos y el pago del domicilio entregado con saldo. `scripts/verificar-backend.bat` por sí solo no cierra ese punto.

**Estado:** discrepancias documentadas; falta clasificación funcional de los datos y activación runtime del build. Ningún dato fue cambiado.

## Verificación visual autenticada en panel — 2026-11-25 11:26 COT

En el Equipo publicado por Tunnel, el Centro de operación muestra **9 pedidos abiertos**, **26 alertas**, una mesa “En cobro” con antigüedad de **113 d 9 h**, y un domicilio de planta “En camino” con la misma antigüedad. El KDS muestra **0 en Cocina** y **6 en Listos**; los tickets se muestran como tarjetas con acciones de reimpresión y retorno a cocina, pero la vista no presenta antigüedad. Consulta agregada `READ ONLY`/`ROLLBACK` en `supabase-db`, acotada a la Sede principal y los seis números visibles, confirmó que **6 de 6** se crearon hace más de 30 días; rango UTC 2026-07-02 a 2026-08-04. No se consultaron datos de clientes ni se modificaron filas. Esta combinación indica una cola de listos antigua que requiere conciliación individual; la antigüedad no demuestra que cada pedido llevara todo ese tiempo en estado “listo”.

La observación es una comprobación del frontend público del Tunnel, no prueba que el PID Nest :3000 haya cargado el último build. No se pulsaron acciones de pedidos/tickets, no se alteraron datos ni se generó impresión. Los datos siguen sin clasificación del propietario; no ejecutar la acción “Volver a cocina”, cierres ni una limpieza automatizada hasta conciliar cada operación.

## Evidencia técnica anterior — 2026-11-25 10:35 COT

Estado actual confirmado de forma read-only: PID 10204 sigue atendiendo :3000 desde 07:22; `foody_backend/dist/main.js` se actualizó a las 09:14; `/salud` devuelve `version=2026-07-01` y `base_datos=true`. :3001 no escucha. El equipo local :8080 da HTTP 200. La suite unitaria Nest sobre fuentes actuales pasó 55/55 suites y 144/144 pruebas (`npm test -- --runInBand --silent`).

No ejecuté `verificar-todos-e2e.ps1`: empieza cancelando pedidos activos y elimina trabajos de impresión en la base `foody_diseno_qa`. La base está en el contenedor dedicado `foody-diseno-qa-db` (21 MB), pero no hay confirmación del founder sobre el carácter desechable de todos sus datos. El intento de preparar una base temporal clonada y levantar Nest en :3001 fue rechazado por revisión automática; comprobación posterior confirmó que no se creó la base ni se inició :3001. No se tocó :3000, la QA persistente, Tunnel ni datos.

La activación del `dist` actual y E2E contra una copia aislada siguen pendientes. Esperar clasificación del founder antes de limpiar datos; para QA, habilitar un mecanismo autorizado de clon efímero con teardown validado.
