# Empalme de trabajo Codex — Foody

**Actualizado:** 25 de noviembre de 2026. Este documento resume el último estado conocido para continuar en otro chat o cuenta. No reemplaza los documentos oficiales del proyecto; señala cuáles leer y qué evitar repetir.

## Cómo se conserva el contexto al cambiar de cuenta

El historial, archivos adjuntos y memoria de una cuenta de ChatGPT no se comparten automáticamente con otra. La carpeta del proyecto sí conserva sus archivos locales si la nueva cuenta abre este mismo equipo y la misma ruta. Si se usa otro computador, habrá que transferir/sincronizar el repositorio por el medio habitual. Exportar una conversación sirve como referencia, pero no la importa como un chat activo.

Fuentes oficiales: [cuentas múltiples](https://help.openai.com/en/articles/20001068-using-multiple-chatgpt-accounts-on-web-and-mobile), [ChatGPT Work y Codex](https://help.openai.com/en/articles/20001275-chatgpt-work-and-codex), [exportar datos](https://help.openai.com/en/articles/7260999-exporting-your-chatgpt-history-and-data), [transferir conversaciones](https://help.openai.com/en/articles/9106926-transferring-conversations-from-1-chatgpt-account-to-another-chatgpt-account).

## Inicio recomendado para la siguiente sesión

Abrir `C:\Users\javier\Videos\usb\FOODY APP` y leer, en este orden:

1. `AGENTS.md` y `MEMORIA.md`.
2. `docs/MASTER_STATUS.md`, `docs/PRIORIDADES_FOODY.md`, `docs/INFORME_MAESTRO_FOODY.md`, `docs/ROADMAP_TERMINAR_FOODY.md`, `docs/AVANCE_PROYECTO.md` y `docs/README.md`.
3. Este empalme; después abrir solo los informes de evidencia relacionados con el siguiente ítem.

Al comenzar, confirmar `git status --short` y revisar los archivos afectados antes de editar. **Hay 264 entradas modificadas/no rastreadas en el árbol de trabajo** al momento de este corte. Son trabajo local pendiente de integrar; no ejecutar `git reset`, `git clean`, restauraciones masivas ni borrar archivos por asumir que son temporales. No se creó otro repositorio ni se hizo commit.

## Objetivo y preferencias del producto

- La auditoría y rediseño integral siguen **pausados** hasta que Javier pida reanudarlos. El trabajo de diseño previo no equivale a completar todas las vistas.
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
3. **Inspeccionar el ciclo de edición/eliminación de ítems de pedido con pagos parciales.** Hay una protección en `reemplazarItemPedido` (`ITEM_REQUIERE_AJUSTE_COBRO`); verificar si `actualizarItemPedido` y `eliminarItemPedido` comprueban `estado_cobro`/`pago_pedido_items` antes de concluir si existe una inconsistencia. No asumir un bug sin probar el flujo.
4. **Wompi:** hay cuatro llamadas `fetch` sin timeout. No añadir timeout/reintento ciego a creación de cobros: una respuesta perdida puede ocultar un cobro aprobado y provocar duplicados. Diseñar primero reconciliación/consulta de estado e idempotencia.
5. **Rendimiento:** faltan mediciones representativas y límites/observabilidad de consultas; el timeout del pool no es timeout SQL. Ver auditoría de rendimiento y scripts en `scripts/perf/`; los scripts ligeros actuales no son prueba de capacidad.
6. **Diseño:** continuar por la matriz de vistas y prioridades cuando Javier reanude; no afirmar que todas las ventanas estén terminadas hasta completar recorrido y QA por rol/tamaño.

## Texto para iniciar el nuevo chat

> Continúa Foody en `C:\Users\javier\Videos\usb\FOODY APP`. Lee primero `docs/HANDOFF_CODEX_FOODY.md` y los documentos iniciales enumerados allí, además de `AGENTS.md`. Integra el estado existente; no repitas auditorías ni suites ya aprobadas sin motivo. Conserva los cambios locales y las reglas de negocio, no toques OAuth/túnel/credenciales/datos reales y no reinicies servicios activos. La tarea principal quedó pausada: antes de continuarla, confirma conmigo que quieres reanudar. Al reanudar, sigue los pendientes priorizados del empalme y actualiza los documentos oficiales exigidos por AGENTS.md.
