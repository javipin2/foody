# Empalme de trabajo Codex — Foody

**Continuidad 26-nov-2026:** POS-TOTAL-DRIFT-01 ahora exige la cotización de servidor en cobros staff para llevar y pide confirmación renovada ante cambio de total; POS+repositorio 27/27, backend 15 pruebas focales + build. `PED-ITEM-PAY-ALLOC-01` protege líneas cobradas/asignadas de modificación monetaria o borrado; todo el módulo Nest Pedidos 21 suites/76 pruebas y build OK. Ambos están solo en fuente/dist; :3000 no se reinició. En investigación de finanzas se reafirma que `monto_pagado` mezcla pago de cliente con liquidación de domiciliario; la decisión sigue abierta, no tocar saldos hasta separar conceptos. Riesgo nuevo pendiente: modificar toppings después de descontar inventario no reconcilia stock por componente. No hacer despliegue integrado con bundle Flutter desactualizado; Tunnel/OAuth/datos de negocio sin cambios.

**Continuación 25-nov-2026:** DOMI-MANUAL-PAY-LEDGER-01 fue corregido en fuente y el E2E de domicilio exige que `pagos_resumen` coincida con la venta de Caja al entregar manualmente. Build OK; unitarias cercanas 2 suites/6 pruebas y E2E domicilio 7/7 en Nest QA `:3001` + clon desechable. API QA y clon retirados; `:3000` PID 7584 intacto. DOMI-OFF-CAJA-TRACKING-01 sigue como decisión independiente sobre el cargo que recibe el domiciliario y su medio de pago. No reiniciar el runtime ni modificar Tunnel hasta coordinar activación.

**Suite completa:** estabilizada. `caja-rbac-write.e2e-spec.ts` usa la identidad separada `cajero.sololectura.test@foody.demo`; el launcher protegido recompone los grants desde las migraciones, exige un clon `foody_diseno_qa_codex_*` y crea el usuario sintético solo allí. Resultado integral: **10/10 suites, 51/51 pruebas**. QA fuente después: 1.274 pedidos, 76 grants y 0 usuario de prueba sintético; la diferencia frente a 80 migrados es la ausencia de los cuatro grants de 094. Clon eliminado, :3001 apagado y :3000 PID 7584 intacto.

**Actualizado:** 25 de noviembre de 2026. Este documento resume el último estado conocido para continuar en otro chat o cuenta. No reemplaza los documentos oficiales del proyecto; señala cuáles leer y qué evitar repetir.

## Avance desde el primer corte

Javier reanudó explícitamente el rediseño. `COST-RECIPE-STRUCT-01` organiza Costos y márgenes a partir de la referencia aprobada: producto destacado, cinco pasos, grupos plegables, acompañamientos por separado y resumen de costo/margen a la derecha en escritorio o al final en móvil. El editor agrupa ingredientes, preparaciones y empaques; los subtotales editables son orientativos. Búsqueda reconoce tipos reales y permite recuperar resultados. COST-RECIPE-LOAD-FAIL-01 bloquea el editor ante error de lectura. COST-RECIPE-EDIT-RESP-01 corrige overflow del selector, resumen y fila de stock en móvil. Suite de Recetas + Costos 16/16; analyzer limpio. La prueba cubre payload UI→repositorio en 320/390/820/1440 y composición completa del detalle con repositorios fake sin red externa. COST-RECIPE-INTEGRATION-01 propagó las dependencias del padre a receta e incluidos; el paso activo se sincroniza con el escenario y se corrigió el overflow por nombre largo de plato en acompañamientos. Falta persistencia/recálculo autenticados y QA visual real.

`ANA-PNL-COMP-FILTER-01`: se corrigió Rentabilidad para que el COGS del período comparado aplique los mismos filtros y fechas que el período actual. Jest focalizado 3/3 y build Nest OK. Revisión read-only: API :3000 PID 7584 inició 13:50:31, mientras `dist/main.js` es posterior (18:53:56); `GET /api/v1/salud` local/Tunnel 200, Cliente/Equipo local/Tunnel 200 y cloudflared PID 8940 activo. No se reinició ni publicó. Los arreglos backend compilados siguen pendientes de activación coordinada.

`ANA-PNL-EXP-SCOPE-01`: bajo filtros de pedido, ventas/COGS se segmentan pero los gastos operativos permanecen completos por sede/período; no existe política de prorrateo. La UI ya aclara el alcance; Flutter Análisis 8/8 en 320/390/820/1440 y analyzer limpio. Decisión contable queda pendiente; no se alteró fórmula ni datos.

## Cómo se conserva el contexto al cambiar de cuenta

El historial, archivos adjuntos y memoria de una cuenta de ChatGPT no se comparten automáticamente con otra. La carpeta del proyecto sí conserva sus archivos locales si la nueva cuenta abre este mismo equipo y la misma ruta. Si se usa otro computador, habrá que transferir/sincronizar el repositorio por el medio habitual. Exportar una conversación sirve como referencia, pero no la importa como un chat activo.

Fuentes oficiales: [cuentas múltiples](https://help.openai.com/en/articles/20001068-using-multiple-chatgpt-accounts-on-web-and-mobile), [ChatGPT Work y Codex](https://help.openai.com/en/articles/20001275-chatgpt-work-and-codex), [exportar datos](https://help.openai.com/en/articles/7260999-exporting-your-chatgpt-history-and-data), [transferir conversaciones](https://help.openai.com/en/articles/9106926-transferring-conversations-from-1-chatgpt-account-to-another-chatgpt-account).

## Inicio recomendado para la siguiente sesión

Abrir `C:\Users\javier\Videos\usb\FOODY APP` y leer, en este orden:

1. `AGENTS.md` y `MEMORIA.md`.
2. `docs/MASTER_STATUS.md`, `docs/PRIORIDADES_FOODY.md`, `docs/INFORME_MAESTRO_FOODY.md`, `docs/ROADMAP_TERMINAR_FOODY.md`, `docs/AVANCE_PROYECTO.md` y `docs/README.md`.
3. Este empalme; después abrir solo los informes de evidencia relacionados con el siguiente ítem.

Al comenzar, confirmar `git status --short` y revisar los archivos afectados antes de editar. **Hay 21 entradas modificadas/no rastreadas en el árbol de trabajo** tras las oleadas recientes (20 modificadas y 1 prueba nueva sin seguimiento), incluidos artefactos generados por `npm run build`. Son trabajo local pendiente de integrar; no ejecutar `git reset`, `git clean`, restauraciones masivas ni borrar archivos por asumir que son temporales. No se creó otro repositorio ni se hizo commit.

## Objetivo y preferencias del producto

- La auditoría y rediseño integral están **activos** desde la instrucción de Javier del 25/11/2026. Recetas avanzó parcialmente; no equivale a completar todas las vistas.
- Producto inicial para restaurantes; adopción Free y conversión Free → Pro; preparar modularidad y multi-tenant sin adelantar microservicios ni funciones de sectores futuros.
- Interfaz administrativa premium, clara, intuitiva y responsive para móvil/escritorio; conservar comportamiento y reglas operativas.
- La referencia visual de **Costos y márgenes** se aprobó por su organización, no por sus colores: producto resumido, flujo de cinco pasos (ingredientes, preparaciones, empaques, acompañamientos, costo y margen), secciones agrupadas y resumen de costo/margen/precio sugerido. En escritorio el resumen puede quedar visible; en pantallas estrechas debe reorganizarse y permitir secciones plegables.
- Regla comercial indicada por Javier: el valor del pedido se cobra completo; la propina es voluntaria y separada. Una propina sugerida no debe persistirse si el pago se difiere.
- Distinguir suscripción Foody, posible comisión porcentual sobre ventas, cargos de domicilio y pago al domiciliario; no dar por decidida una comisión comercial que no esté respaldada.

## Reglas operativas que no se deben perder

- Flutter es UI; NestJS + PostgreSQL contienen reglas y validaciones de negocio.
- Mantener el mismo repositorio y el acceso de prueba por Cloudflare Tunnel. No cambiar OAuth de Google, credenciales, configuración del túnel ni datos reales sin una petición explícita.
- La máquina de Javier hace de servidor local mientras no haya VPS. Un `/health` exitoso no demuestra que el proceso esté usando el último build.
- No detener ni reiniciar procesos del túnel/API como parte de una prueba sin coordinarlo con el uso actual de Javier; preferir scripts de inicio/QA ya existentes y entornos aislados.

## Últimos cambios técnicos comprobados

1. **Caja:** `lib/features/caja/data/caja_repository.dart` limita lectura del historial a un máximo de dos páginas de 50 para la vista de 80 movimientos recientes. El cálculo/cierre de caja sigue en backend. Evidencia reportada: `caja_repository_test.dart` y `caja_admin_screen_test.dart`, 18/18.
2. **Geografía:** `foody_backend/src/modulos/geografia/geografia.service.ts` aplica timeout de 5 s a Photon, diferencia timeout/error upstream y solo cachea resultados válidos. Spec: 3/3.
3. **Pool PostgreSQL:** `foody_backend/src/core/database/database.service.ts` configura timeout de adquisición/conexión del pool (5 s por defecto, configurable con `DB_POOL_CONNECT_TIMEOUT_MS`). Esto **no** limita la duración de una consulta SQL. Spec: 2/2.
4. **Pagos mixtos de domicilios:** resumen por método se consulta por pedido y sucursal, y se muestra en tarjetas/historial del domiciliario. QA de lectura reportada: 44/44 asignaciones entregadas con resumen; detectar diferencias del método escalar no significa que el detalle de pagos esté mal.
5. **Liquidación de cuenta por cobrar:** `domiciliarios.service.ts` ya no debe reemplazar el método real por `efectivo` al liquidar. Busca método real de `pagos_pedido` por pedido+sucursal, usa efectivo como fallback y limita el update a la sucursal. Spec focalizada: 2/2; build Nest reportado exitoso.

### Evidencia de suites al último corte conocido

- NestJS completo: **63 suites / 176 pruebas aprobadas**.
- Flutter completo: **297 aprobadas / 5 omitidas**.
- `flutter analyze`: terminó con 10 avisos informativos, sin errores reportados.
- Build Nest compilado: `foody_backend/dist/main.js`, 25/11/2026 17:46:22.
- La prueba end-to-end de liquidación con pago mixto **no se ejecutó**. El mecanismo propuesto para crear un clon temporal y arrancar una API adicional fue rechazado por la revisión automática. No eludir ese bloqueo con comandos equivalentes; preparar una ruta QA segura/aislada o pedir a Javier que ejecute el script existente.
- Las cifras son evidencia del corte anterior, no una afirmación de que nada haya cambiado desde entonces. Repetir únicamente lo necesario después de inspeccionar cambios posteriores.

## Estado local de procesos (corte 25/11/2026)

- Nest PID 7584 seguía corriendo desde las 13:50:31; el build de `dist/main.js` es de las 17:46:22. Por tanto el proceso puede estar sirviendo código anterior al build. No se ha confirmado reinicio/carga de ese build.
- En revisiones previas, `cloudflared` y webs locales 8080/8081 estaban activos. Volver a comprobar antes de diagnosticar; el estado cambia con el tiempo.
- No se modificaron OAuth ni la configuración del túnel en el trabajo técnico descrito aquí.

## Pendientes ordenados para la reanudación

1. **Confirmar cambios locales** y leer los documentos de prioridad. No reabrir toda la auditoría desde cero.
2. **Validar el cambio de liquidación de domiciliarios en QA aislado** (transferencia parcial + saldo en efectivo) y luego actualizar las filas pertinentes de `MASTER_STATUS`, `AVANCE_PROYECTO`, `INFORME_MAESTRO` y prioridades.
3. **Continuar el ciclo de modificación de líneas:** PED-ITEM-PAY-ALLOC-01 ya bloquea edición monetaria/borrado de líneas con pago asociado, permite notas sin cambiar importes y evita regrabar precios de topping idénticos. Falta prueba E2E; además, cambio de toppings con stock descontado todavía no reconcilia el ledger de ingredientes y debe diseñarse con snapshots/movimientos antes de ajustar la lógica.
4. **Wompi:** hay cuatro llamadas `fetch` sin timeout. No añadir timeout/reintento ciego a creación de cobros: una respuesta perdida puede ocultar un cobro aprobado y provocar duplicados. Diseñar primero reconciliación/consulta de estado e idempotencia.
5. **Rendimiento:** faltan mediciones representativas y límites/observabilidad de consultas; el timeout del pool no es timeout SQL. Ver auditoría de rendimiento y scripts en `scripts/perf/`; los scripts ligeros actuales no son prueba de capacidad.
6. **Diseño:** continuar por la matriz de vistas y prioridades; terminar QA autenticada de ADM-12 y seguir con las vistas pendientes. No afirmar que todas las ventanas estén terminadas hasta completar recorrido y QA por rol/tamaño.

## Texto para iniciar el nuevo chat

> Continúa Foody en `C:\Users\javier\Videos\usb\FOODY APP`. Lee primero `docs/HANDOFF_CODEX_FOODY.md` y los documentos iniciales enumerados allí, además de `AGENTS.md`. Integra el estado existente; no repitas auditorías ni suites ya aprobadas sin motivo. Conserva los cambios locales y las reglas de negocio, no toques OAuth/túnel/credenciales/datos reales y no reinicies servicios activos. Javier reanudó el rediseño: continúa por los pendientes priorizados, empezando por QA autenticada de ADM-12, y actualiza los documentos oficiales exigidos por AGENTS.md.

**Continuidad 2026-11-25 — conciliación de pago/devoluciones:** FIN-PAY-RECONCILIATION-01 parcial. Contrato del detalle agrega `devoluciones_caja_vinculadas` y `recaudo_neto_caja_vinculado`; neto calculado como ventas Caja menos devoluciones enlazadas, filtrando `pedido_id` + `sucursal_id`, sin mezclar `pagos_pedido` de otros canales. Flutter los muestra aparte de pagos brutos y propina, con nota de cobertura. Pruebas: Jest `pedidos.service.pagos-resumen.spec.ts` (1/1), Nest build OK, `flutter test test/pedido_detalle_sheet_test.dart` (5/5) y analyzer focalizado limpio. API local no reiniciada; fuente/build no significa runtime activo. Pendiente: estados/canales y políticas contables de abonos/devoluciones; no confundir el neto de Caja enlazado con ingreso contable completo.

**Continuidad 2026-11-25 — Costos y recetas:** suite combinada 15/15 al agregar guardado por UI→`InventarioRepository`→Dio con adaptador HTTP falso en 320/390/820/1440. Se detectó/corrigió overflow de 390 px en resumen costo, overflow compacto en texto stock y ancho del selector de tipo. Error GET mantiene editor bloqueado con reintento; respuesta vacía confirmada permite crear. Analyzer focalizado limpio. Esta prueba no alcanzó Nest; persistencia/recálculo autenticados contra API siguen pendientes. No reinicié ni publiqué runtime ni escribí DB.
