# Dashboard: serie de ventas y conteo de alertas

**Fecha:** 2026-11-25  
**Alcance:** consulta backend y presentación del panel; solo fuente, pruebas y documentación. No se modificó la base de datos.

## Hallazgo DASH-7D-ZERO-01 — serie diaria incompleta y límite horario ambiguo

`DashboardService.graficos()` agrupaba por fecha de Bogotá, pero solo devolvía días con pedidos. El gráfico se titulaba “últimos 7 días” y asignaba sus posiciones según el largo recibido, por lo que una semana con ventas en dos días se dibujaba como dos puntos consecutivos, sin indicar los cinco días sin ventas. Además, el filtro `created_at >= fecha_local - 6 días` comparaba `timestamptz` con una fecha/hora sin zona explícita; PostgreSQL podía interpretarla según `TimeZone` de sesión.

**Corrección:** el endpoint genera siete fechas calendario locales (incluye hoy), hace `LEFT JOIN` con ventas válidas y retorna cero para días sin pedidos. Los límites de consulta se convierten explícitamente desde `America/Bogota` a `timestamptz`, incluyendo límite superior exclusivo del día siguiente. Se aplica también al top de productos, que comparte el filtro `SQL_PEDIDO_DESDE_7D_P`.

**Verificación:** Jest `ventas-metricas.sql.spec.ts` + `dashboard.service.spec.ts`: 7/7; `npm run build` OK. Test responsive `dashboard_resumen_widget_test.dart`: 9/9 en 320, 390, 820 y 1440 px.

La misma serie se ejecutó dentro de `foody-diseno-qa-db` bajo `BEGIN READ ONLY`/`ROLLBACK`: devolvió exactamente siete días (19–25 nov 2026), con 0 el 19–21 y datos del 22–25. Esto confirma el SQL en PostgreSQL con los datos QA de esa sucursal. No es una comprobación de la API activa ni una consulta a la BD operacional.

## Hallazgo DASH-ALERTAS-COPY-01 — el total no es el número de filas visibles

El KPI muestra todas las alertas sin revisar; el acordeón limita la lista a 8 (`_maxFilas`). El subtítulo ahora explica que se muestran hasta 8 y que el KPI conserva el total pendiente.

## Complemento UX — semana sin ventas y tarjetas vacías

Con el backend corregido, una semana sin ventas contiene igualmente siete filas en cero. El panel ahora trata una serie de ceros como estado vacío (`Sin ventas en la semana`) y reduce las gráficas vacías del mix/top a una altura compacta de 82 px con icono. `dashboard_graficos_widget_test.dart` pasa 4/4 en 320/390/820/1440 px; `analitica_caja_screen_test.dart` 5/5; analyzer de los widgets limpio. Sin cambio de datos ni de cálculos.

Build Equipo Release para ese ajuste publicado y verificado en el subdominio. SHA-256 de `main.dart.js`: `38D26D5FF5DDEFA293B826985114E890169CD1A34C55C9A2404040822812E6BD`, idéntico en build y descargas local :8080/público Tunnel; index con versión de caché nueva. La vista del túnel muestra ahora el mix vacío compacto con icono. Sigue dibujando solo 23–24 de noviembre en “7 días”: prueba visual directa de que la API activa aún corre versión anterior.

## Activación / límites

El Nest que atiende :3000 (PID 10204 al momento de la auditoría) se inició antes del `dist` actual. El reinicio fue rechazado por el control automático en esta sesión; por tanto las pruebas verifican el nuevo código fuente compilado, no el proceso vivo del Tunnel. No se alteraron Cloudflare, OAuth, credenciales ni datos de negocio. Requiere activación coordinada del backend y comprobación de siete filas en la respuesta real.
