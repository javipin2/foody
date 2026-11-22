# Auditoría — Dashboard general (Prompt 21)

> **Fecha:** 2026-08-06  
> **Alcance:** frescura (tiempo real vs snapshot), widgets/KPI huérfanos o mal cableados, consistencia de cifras vs Reportes/Analítica (Prompt 20).  
> **Superficies:** `GET /dashboard/resumen|graficos|consolidado` · `DashboardResumenWidget` · `DashboardGraficosWidget` · `DashboardConsolidadoWidget` · panel admin.  
> **Verificación:** `scripts/verificar-dashboard-general.ps1` (OK, exit 0) + `verificar-dashboard-graficos.ps1`.  
> Relacionados: [`AUDITORIA_REPORTES.md`](AUDITORIA_REPORTES.md) · [`AUDITORIA_REALTIME.md`](AUDITORIA_REALTIME.md) · [`../frontend/FRONTEND_FRICTION_FIXES.md`](../frontend/FRONTEND_FRICTION_FIXES.md) FF-04.

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| ¿El usuario sabe si ve datos en vivo o un snapshot? | **No.** Sin badge de frescura ni hora de actualización. Solo botón «Actualizar». No hay Realtime ni poll en el dashboard. |
| ¿Hay cache de servidor? | **No** en el módulo dashboard: cada GET ejecuta SQL fresco. El «cache» es solo el estado Flutter hasta refresh/manual. |
| ¿Widgets huérfanos / mal cableados? | **Sí:** KPI QR pendiente solo en API; «Ventas hoy» abre Caja; top productos etiquetado «por unidades» pero ordenado por $; claim «misma lectura que Análisis» sin mismo endpoint. |
| ¿Cifras = reportes/analítica de hoy? | **Sí en demo (hoy):** `ventas_hoy` = financiero = analítica = **187200**. Riesgo TZ de noche (ver DASH-TZ-01). Universos distintos en «Completados» vs count reportes y en ranking top. |

---

## Mapa de datos (qué pinta qué)

| Bloque UI | Fuente | Auto-refresh | Acción al tap |
|-----------|--------|--------------|---------------|
| KPI Ventas hoy | `GET /dashboard/resumen` → SQL | No (manual) | → **Caja** |
| KPI Activos / Completados | idem | No | → Pedidos |
| KPI Alertas | idem (+ lista parcial alertas) | No | → Alertas |
| Acordeón mesas demora | `GET /mesas` + umbrales cliente | No | → Mesas / KDS |
| Acordeón domicilios | `GET` pedidos activos + umbrales | No | → Domi / Pedidos |
| Acordeón stock | `GET` ingredientes | No | → Insumos |
| Acordeón alertas | `GET /alertas` | No | → Alertas |
| Gráficos 7d / mix / top | `GET /dashboard/graficos` | No | Botones Reportes / Análisis |
| Consolidado cadena | `GET /dashboard/consolidado` | No | sede / Reportes / Pedidos / Alertas |
| Banner Realtime (panel) | salud RT | Timer 60 s | No afecta dashboard |

---

## A) Tiempo real vs snapshot (frescura)

### Qué hay

- **Backend:** sin capa cache (`dashboard.service.ts` → `DatabaseService` directo).
- **Flutter resumen/gráficos/consolidado:** carga en `initState` / cambio de sede / icono refresh. **Sin** `FoodyRealtime.suscribirSucursal`, **sin** `PollRealtimeRespaldo`.
- **Kanban / mesas / KDS** (otras secciones): sí Realtime + poll 45–90 s.
- **Reportes UI:** muestra `Act. HH:mm` tras cargar; **dashboard no**.

### Evidencia API (2026-08-06)

```text
.\scripts\verificar-dashboard-general.ps1
→ ventas_hoy=187200 == reportes/financiero == analitica/resumen
→ Verificacion dashboard-general OK (exit 0)
```

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **DASH-RT-01** | 🟣 | Media | Dashboard operativo **no** es tiempo real ni poll; snapshot hasta refresh manual | `dashboard_resumen_widget.dart` `_cargar`; sin canal/poll |
| **DASH-RT-02** | 🟣 | Media | `RealtimeAvisoBanner` habla de refresh 45–90 s en kanban/mesas/cocina; el usuario en **Inicio** puede asumir que el dashboard también se actualiza solo | `realtime_aviso_banner.dart` + dashboard sin poll |
| **DASH-FRESH-01** | 🟣 | Media | Sin «Actualizado a las…» ni indicador stale; Reportes sí tiene hora | `dashboard_resumen_widget` `_header` vs `reportes_admin_screen` |
| **DASH-CACHE-01** | ✅ | — | No hay cache Nest del dashboard; GET = SQL vivo en ese instante | `dashboard.service.ts` / module sin Cache |

---

## B) Widgets / campos huérfanos o mal cableados

Criterio: muestra dato pero **no alimenta una decisión** clara, o el tap lleva a un contexto que **no explica** la cifra.

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **DASH-ORPH-01** | 🟣 | Baja | `pedidos_pendientes_qr` se calcula en resumen/consolidado y **no se pinta** como KPI (solo demoras QR ≥3 min en acordeón mesas) | `dashboard.service.ts` + `_kpis()` sin ese campo |
| **DASH-ORPH-02** | 🟣 | Media | KPI **«Ventas hoy»** → `onIrCaja`. Caja = turno/movimientos; la cifra es `SUM(pedidos.total)` del día. Decisión esperada: Reportes/Analítica | `dashboard_resumen_widget.dart` `_kpis` + `panel_restaurante_screen` |
| **DASH-ORPH-03** | 🟣 | Baja | Card «Top productos — **Por unidades**» pero SQL `ORDER BY ventas DESC`; barras usan `cantidad` | `dashboard.service.ts:86` · `dashboard_graficos_widget.dart` subtitulo + `valorKey: 'cantidad'` |
| **DASH-ORPH-04** | 🟣 | Baja | Copy «Misma lectura que Análisis» sin compartir endpoint ni filtros de analítica | `dashboard_graficos_widget.dart` vs `/analitica/*` |
| **DASH-ORPH-05** | 🟡 | Baja | Consolidado N+1 por sede (mismo patrón cadena); útil para decidir sede, no huérfano de decisión | `consolidado()` loop · overlap BD-N1 |

**No huérfanos (sí accionables):** acordeones mesas/domi/stock/alertas + KPI activos/completados/alertas con deep-link a sección operativa.

---

## C) Consistencia vs Reportes / Analítica (Prompt 20)

### Universos

| Métrica | Dashboard | Reportes / Analítica | ¿Match? |
|---------|-----------|----------------------|---------|
| Ventas del día | `SUM(total)` no cancel/rechazo, filtro «hoy» | financiero / `analitica/resumen` mismo universo ticket | ✅ hoy en demo (187200) |
| Mix canal hoy | `pedidos_por_tipo_hoy` | financiero `por_tipo` (mismo día) | ✅ suma = ventas_hoy |
| Serie 7d | `ventas_7_dias` (Bogota date) | reportes pedidos por día / analítica ventas | Misma idea; UI reportes default **7d** |
| Top productos 7d | `ORDER BY ventas`, `SQL_VENTA_LINEA_ITEM` | reportes `ORDER BY cantidad` | Top #1 igual en demo; **criterio distinto** |
| «Completados» | `SQL_WHERE_PEDIDO_COMPLETADO` | reportes `COUNT(*)` no cancel | Igual solo si no hay activos/impagos |
| Alertas pendientes | `alertas_riesgo.revisada=false` | listado alertas | Mismo origen |

### Hallazgos consistencia / TZ

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **DASH-CONS-01** | ✅ | — | `ventas_hoy` = financiero hoy = analítica hoy en corrida | Script A · 187200 |
| **DASH-TZ-01** | 🟣 | Media-Alta | Resumen y `pedidos_por_tipo_hoy` usan `created_at::date = (NOW() AT TIME ZONE 'America/Bogota')::date` (cast de `timestamptz` en TZ de sesión, suele UTC). `ventas_7_dias` sí usa `(created_at AT TIME ZONE 'America/Bogota')::date`. **Riesgo divergencia tarde/noche CO** vs reportes (rango `timestamptz`) | `dashboard.service.ts` L45–48 vs L65 vs L183–184 |
| **DASH-CONS-TOP** | 🟣 | Baja | Ranking dashboard por **$**; reportes/productos por **unidades** | `ORDER BY ventas` vs `ORDER BY cantidad` |
| **DASH-CONS-COMP** | ✅ | Baja | KPI «Cerrados hoy» (universo cerrado ≠ tickets financiero) | UI dashboard |
| **DASH-CONS-PERIOD** | 🟡 | Baja | Reportes abre en **7d**; dashboard KPI es **hoy** — comparación visual sin cambiar periodo engaña | `reportes_admin_screen.dart` `_dias = 7` |
| **DASH-LINE-01** | 🟡 | Baja | Top productos = línea+extras (igual REP-LINE-01); no sumar top vs KPI ticket | Prompt 20 · `SQL_VENTA_LINEA_ITEM` |

---

## D) Hallazgos de documentación / DX

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **DASH-DOC-01** | 🟡 | Baja | FF-04 en `FRONTEND_FRICTION_FIXES.md` figura ⏳ pero KPIs ya son `InkWell` con callbacks | Doc vs código |
| **DASH-DOC-02** | ✅ | — | Script runnable Prompt 21 añadido | `scripts/verificar-dashboard-general.ps1` |

---

## Backlog sugerido (si se prioriza)

1. **DASH-FIX-01** — Unificar filtro «hoy» a `(created_at AT TIME ZONE 'America/Bogota')::date` (cerrar DASH-TZ-01). Prod-risk calendario CO.
2. **DASH-FIX-02** — Mostrar «Actualizado HH:mm» + poll opcional 60–90 s en resumen (o suscribir eventos pedido/alerta y refetch).
3. **DASH-FIX-03** — KPI Ventas hoy → Reportes (periodo Hoy) o Analítica; no Caja.
4. **DASH-FIX-04** — Alinear etiqueta/orden top productos (unidades vs ventas) con reportes; o documentar diferencia en UI.
5. **DASH-FIX-05** — Pintar KPI QR pendientes o dejar de calcularlo en API consolidado/resumen.
6. **DASH-FIX-06** — Suavizar copy «Misma lectura que Análisis» → «Tendencia de la sede (7 días)».

---

## Verificación

```text
.\scripts\verificar-dashboard-general.ps1
→ Verificacion dashboard-general OK (exit 0)

.\scripts\verificar-dashboard-graficos.ps1
→ OK - dashboard graficos verificado
```

Gaps: no se forzó ventana nocturna UTC/Bogota para DASH-TZ-01; click-through UI en dispositivo; consolidado con ventas en 2+ sedes el mismo día.
