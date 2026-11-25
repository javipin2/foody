# Auditoría de cola de impresión — estado observado 2026-11-25

## Alcance y método

Lectura de `public.impresion_cocina_jobs` en Supabase local dentro de una transacción `BEGIN READ ONLY … ROLLBACK`; cruce agregado con `pedidos`; consulta de salud profunda y revisión del consumidor Nest/Python. No se modificaron registros, no se reintentaron jobs ni se imprimió hardware. El análisis no incluyó contenido de tickets ni datos personales.

## Hallazgos

### IMP-QUEUE-CLASSIFY-01 — errores terminales de impresión

Al momento de la revisión existen 547 jobs: 230 `enviado` (entre el 26-jun y el 8-ago), 317 `error` y 0 `pendiente`. De los 317 errores, 316 tienen `ECONNREFUSED` y exactamente 10 intentos, coincidentes con `MAX_INTENTOS_JOB=10`; representan que Nest no pudo conectarse al agente WebSocket en esos intentos. El job restante está en `error` con 0 intentos, `ultimo_error` vacío, sin `error_encolado` en el payload y con cocina relacionada; el código actual no permite determinar quién o qué lo puso en ese estado.

Hay 3 errores creados en las 24 horas anteriores a la consulta: 2 relacionados con pedidos `pagado` para llevar y 1 con un pedido `asignado` de domicilio creado el 4-ago-2026. El primer grupo puede corresponder a nuevas comandas/reimpresiones de pedidos pagados; el registro no prueba el motivo. El último corresponde a una orden de más de tres meses que sigue operativamente asignada, hallazgo relacionado con `OPS-STALE-ACTIVE-ORDERS-01`. No se inspeccionó ticket ni se intentó reimprimir.

Los demás errores se vinculan con estados variados, incluidos `cancelado`, `pagado`, `pagando`, `entregado` y `en_cocina`. El estado actual del pedido no prueba si la comanda alcanzó o no una impresora física en intentos previos. No se deben reencolar en lote: puede duplicar tickets y suprimir evidencia del fallo.

### IMP-QUEUE-HEALTH-01 — alerta persistente

`GET /api/v1/salud/completo` devuelve `estado=degradado` únicamente por `cola_impresion_errores:317`, aunque en el mismo instante Base de Datos, Realtime y agente estaban conectados, con 0 pendientes. El endpoint `/salud` liviano sigue devolviendo HTTP 200. El check profundo cuenta todo job terminal en `error` sin separar antigüedad, sucursal, pedido activo/terminal o último fallo; por ello el historial mantiene la alerta indefinidamente. Suprimir la alerta por edad podría ocultar comandas no confirmadas; antes de cambiar severidad conviene introducir una bandeja autenticada de conciliación por sede/pedido y separar `requiere_atencion` de error histórico ya resuelto por un operador.

## Evidencia reproducible

- Consultas a PostgreSQL dentro de `BEGIN READ ONLY` y finalizadas con `ROLLBACK`; conteo global, clases de error y cruce agregado por estado/tipo.
- `GET http://127.0.0.1:3000/api/v1/salud/completo`: HTTP 200, `degradado`, `base_datos=true`, `realtime.conectado=true`, `impresion.agente.conectado=true`, `pendientes=0`, `error=317`, alerta única `cola_impresion_errores:317`.
- `cmd /c scripts/verificar-backend.bat`: exit 0.
- El ping prueba conectividad Nest→agente actual, no impresión física ni recepción de cada job antiguo.

## Decisiones y siguientes pasos

1. No borrar ni reintentar los 317 errores hasta conciliar cada pedido y confirmar si requiere una nueva comanda.
2. Investigar el único registro con error y 0 intentos desde auditoría/DB; no hay evidencia suficiente para corregirlo automáticamente.
3. Revisar primero el pedido de domicilio todavía `asignado` desde agosto y los otros pedidos activos envejecidos que ya aparecen en `OPS-STALE-ACTIVE-ORDERS-01`; confirmar con el negocio si son fixtures QA o reales antes de mutar datos.
4. Mantener visible el estado degradado mientras haya fallos sin conciliar. Como mejora posterior, construir una vista de conciliación que permita revisar y reimprimir pedido a pedido, con confirmación, permiso de cocina y rastro de auditoría.
5. Añadir métricas de salud que distingan jobs pendientes, errores recientes, errores históricos y tickets vinculados a pedidos operativos sin resolver; no convertir `error` en éxito por antigüedad.

**Estado:** diagnóstico clasificado; registros de negocio intactos. La cola y su alerta no se consideran resueltas.
