# Foody — Auditoría de navegación / UX · Admin (ciclo 2)

> Complementa [`FRONTEND_AUDITORIA_NAV_ADMIN.md`](FRONTEND_AUDITORIA_NAV_ADMIN.md) (NAV-ADM-01…24, cerrado 2026-07-22).  
> Prefijo **NAV-ADM2** — gaps de aterrizaje, paridad móvil y cross-links. No reabre ítems ✅ del ciclo 1 salvo regresión.

**Última actualización:** 2026-07-26 — ciclo NAV-ADM2 cerrado (Alta+Media+Baja clave).  
**Diferidos:** ADM2-06 (`FoodyBreakpoints` unificado), ADM2-24 (tokens shell globales) — YAGNI hasta rediseño tablet.

---

## Estado del ciclo

| Fase | Estado |
|------|--------|
| 1. Diagnóstico | ✅ |
| 2. Aprobación | ✅ (usuario: «continua con todo») |
| 3. Alta | ✅ ADM2-01…03 |
| 4. Media | ✅ 04–05, 07–11 (06 📅) |
| 5. Baja | ✅ 12–23 (24 📅) |
| 6. Verificación | 🟡 `flutter analyze` archivos tocados + smoke manual admin |

---

## Resumen

| Prioridad | Total | ✅ | 📅 |
|-----------|------:|--:|--:|
| Alta | 3 | 3 | 0 |
| Media | 8 | 7 | 1 |
| Baja | 13 | 12 | 1 |
| **Total** | **24** | **22** | **2** |

---

## Hallazgos

| ID | Tema | Estado | Notas |
|----|------|--------|-------|
| ADM2-01 | FCM/`pedido_id` → panel | ✅ | `app_router` + `pedidoIdInicial` |
| ADM2-02 | Alertas → pedido concreto | ✅ | `_navegarDesdeAlerta` + `_irPedidosConPedido` |
| ADM2-03 | Kanban móvil lista &lt;720 | ✅ | Misma regla mesero |
| ADM2-04 | Alertas → insumo destacado | ✅ | `ingrediente_id` + `destacarIngredienteId` |
| ADM2-05 | Alertas costo → Costos | ✅ | producto/combo → `_irCostosConProducto` |
| ADM2-06 | Unificar breakpoints | 📅 | Shell 720 vs POS 900 — sprint tablet |
| ADM2-07 | Cabecera única | ✅ | `ocultarCabecera` pedidos/mesas/caja/POS; sin título Dashboard duplicado |
| ADM2-08 | Banner suscripción dismiss | ✅ | `SuscripcionAvisoBanner.onDismiss` |
| ADM2-09 | KDS empty admin | ✅ | CTA «Configurar cocinas» |
| ADM2-10 | POS sin caja → Caja | ✅ | SnackBarAction en `PedidoCajeroScreen` |
| ADM2-11 | Persist `pedido_id` en URL | ✅ | `_seleccionarSeccion` / `_irPedidosConPedido` |
| ADM2-12 | Reportes ↔ Analítica | ✅ | TextButtons cruzados |
| ADM2-13 | Cocinas ↔ KDS | ✅ | botones cruzados |
| ADM2-14 | Domiciliarios → pedidos | ✅ | CTA «Ver pedidos domicilio» |
| ADM2-15 | Gráficos → Reportes/Análisis | ✅ | `DashboardGraficosWidget` |
| ADM2-16 | Título Mejorar plan | ✅ | `_tituloSeccionActual` |
| ADM2-17 | Refresh AppBar | ✅ | `_refreshTick` + `ValueKey` |
| ADM2-18 | Mesas banner API | ✅ | texto corto + Ocultar |
| ADM2-19 | Promos → Menú | ✅ | «Ver menú» |
| ADM2-20 | Usuarios sin cocinas | ✅ | SnackBar «Crear cocina» |
| ADM2-21 | Sucursales → Horarios/Zonas | ✅ | ⋮ por fila |
| ADM2-22 | Búsqueda ancho | ✅ | clamp hasta 720 |
| ADM2-23 | Chips estado → filtro | ✅ | `OperacionStatChip.onTap` |
| ADM2-24 | Paridad tokens shells | 📅 | Cubre parcialmente 07; resto con rediseño |

---

## Archivos clave

- `lib/core/rutas/app_router.dart`
- `lib/features/admin/presentation/panel_restaurante_screen.dart`
- `lib/features/admin/presentation/widgets/pedidos_kanban_widget.dart`
- `lib/features/admin/presentation/widgets/operacion_ui.dart`
- `lib/features/admin/presentation/widgets/mesas_grid_widget.dart`
- `lib/features/admin/presentation/widgets/admin_busqueda_dialog.dart`
- Módulos: KDS, cocinas, inventario, sucursales, promos, domiciliarios, usuarios, reportes, analítica, POS

## Credenciales smoke

`admin@foody.demo` / `123456` · flavor `equipo`
