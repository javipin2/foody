# Foody — Auditoría de navegación / UX · Rol Admin

> **Documento vivo de seguimiento.** Fase 1 = diagnóstico (2026-07-22).  
> **No implementar sin aprobación** del plan; al aprobar: Alta → Media → Baja, **uno por uno**.  
> Complementa: `FRONTEND_ACCESOS_RAPIDOS.md` (AR-*), `FRONTEND_UX_AUDITORIA.md`, `FRONTEND_NAVIGATION_MAP.md`, `FRONTEND_RESPONSIVE_STRATEGY.md`.  
> Canvas de sesión: `canvases/auditoria-nav-admin.canvas.tsx` (IDE Cursor).

**Última actualización:** 2026-07-26 — **Baja NAV-ADM-20…23 ✅**. Ciclo 1 cerrado. Continuación: [`FRONTEND_AUDITORIA_NAV_ADMIN2.md`](FRONTEND_AUDITORIA_NAV_ADMIN2.md).

**Estado del ciclo:**

| Fase | Estado | Notas |
|------|--------|-------|
| 1. Diagnóstico | ✅ Hecho | Código + docs revisados; 24 hallazgos |
| 2. Aprobación plan | ✅ Hecho | Usuario pidió implementar Alta / Media / Baja por bloques |
| 3. Implementación Alta | ✅ Hecho | NAV-ADM-01…06 cerrados |
| 4. Implementación Media | 🟡 Parcial | 07–13,15–19 ✅ · 14 y 24 📅 diferidos |
| 5. Implementación Baja | ✅ Hecho | NAV-ADM-20…23 |
| 6. Verificación | 📅 Planificado | `verificar-flutter-ui.ps1` + QA rol admin |

---

## Leyenda de estados (por ítem)

| Símbolo | Significado |
|---------|-------------|
| ⏳ | Pendiente — aprobado o no, aún sin código |
| 🔄 | En curso — se está implementando ahora |
| ✅ | Hecho y verificado (analyze / script / smoke UI) |
| 📅 | Planificado — en cola, no empezar aún |
| 🚫 | Pospuesto / no aplica |
| 🟡 | Parcial — existe algo pero incompleto o poco descubrible |

---

## Resumen numérico

| Prioridad | Total | ✅ | 🔄 | ⏳/📅 | 🟡 |
|-----------|------:|--:|--:|----:|--:|
| Alta | 6 | 6 | 0 | 0 | 0 |
| Media | 14 | 12 | 0 | 2 | 0 |
| Baja | 4 | 4 | 0 | 0 | 0 |
| **Total backlog** | **24** | **22** | **0** | **2** | **0** |

### Ya existe en código (no es backlog nuevo — corregir docs viejos)

| Capacidad | Estado real | Nota |
|-----------|-------------|------|
| Búsqueda global admin (AR-28) | ✅ | Dialog adaptable + deep-link pedido (NAV-ADM-08) |
| Favoritos sidebar (AR-29) | ✅ | ★ visible + rail tablet (NAV-ADM-01 2026-07-22) |
| KPIs dashboard clicables (FF-04) | ✅ | Mesas/QR + consolidado ventas/pedidos (NAV-ADM-09/10) |
| Pedido → Ver mesa (AR-01) | ✅ | En sheet kanban |
| Alerta → entidad (AR-32) | ✅ | Navega si hay ref; SnackBar si no (NAV-ADM-18) |
| Menú → Costos (pie chart) | ✅ | Ida + Volver/breadcrumb (NAV-ADM-20) |
| Shell responsive drawer/rail/sidebar | ✅ | Breakpoints 720 / 1100 |

---

## Alcance del rol

- Entrada: `/admin/panel` · `PanelRestauranteScreen` · `?seccion=`
- **21 secciones** sidebar (ver mapa abajo)
- Widgets compartidos con cajero/mesero: `PedidosKanbanWidget`, `MesasGridWidget`, `PedidoCajeroScreen`, `KdsScreen`
- Fuera de alcance de este doc: cliente, super Foody Control, roles standalone (salvo conexiones cruzadas)

### Mapa secciones (`?seccion=`)

| seccion | Pantalla | Grupo |
|---------|----------|-------|
| `dashboard` | DashboardResumen (+ consolidado/gráficos) | Inicio |
| `pedidos` | PedidosKanbanWidget | Operación |
| `nuevo_pedido` | PedidoCajeroScreen | Operación |
| `caja` | CajaAdminScreen | Operación |
| `mesas` | MesasGridWidget | Operación |
| `menu` | MenuAdminScreen | Menú e inventario |
| `insumos` | InventarioAdminScreen | Menú e inventario |
| `costos_margenes` | CostosMargenesScreen | Menú e inventario |
| `promociones` | PromocionesAdminScreen | Menú e inventario |
| `cocinas` | CocinasAdminScreen | Cocina |
| `cocina_kds` | KdsScreen embed | Cocina |
| `domiciliarios` | DomiciliariosAdminScreen | Domicilio |
| `zonas` | ZonasAdminScreen | Domicilio |
| `sucursales` | SucursalesAdminScreen | Sucursal |
| `horarios` | HorariosAdminScreen | Sucursal |
| `reportes` | ReportesAdminScreen | Finanzas |
| `analitica` | AnaliticaScreen | Finanzas |
| `finanzas` | FinanzasAdminScreen | Finanzas |
| `facturacion` | FacturacionAdminScreen | Finanzas |
| `usuarios` | UsuariosAdminScreen | Equipo |
| `alertas` | AlertasAdminScreen | Sistema |
| `mejorar_plan` | MejorarPlanScreen | Sistema |

---

## Backlog — Prioridad Alta (implementar primero)

| ID | Pantalla | Problema (resumen) | Mejora | Tipo | Dispositivos | Afectadas | Estado | Ref AR/FF |
|----|----------|-------------------|--------|------|--------------|-----------|--------|-----------|
| **NAV-ADM-01** | Favoritos sidebar | Long-press sin pista; favoritos ocultos en rail tablet | Pin / menú «Añadir»; pins en tablet | Atajo + Responsive | Todos (peor Tablet) | `panel_sidebar_nav` | ✅ 2026-07-22 | AR-29 |
| **NAV-ADM-02** | Pedidos — sheet | Faltan Cobrar mesa, Caja, Factura, KDS | Atajos + deep-links en sheet | Atajo + Conexión | Todos | Pedidos, Mesas, Caja, Facturación, KDS | ✅ 2026-07-22 | AR-17, AR-18, AR-06 |
| **NAV-ADM-03** | Mesas — long-press | Opciones admin solo long-press invisible | Menú ⋮ o hint | Atajo | Todos | Mesas admin | ✅ 2026-07-22 | — |
| **NAV-ADM-04** | Mesas — banner QR | Banner urgente solo «Actualizar» | CTA → mesa `pendiente_aprobacion` | Feedback + Conexión | Todos | Mesas | ✅ 2026-07-22 | AR-03 (parcial) |
| **NAV-ADM-05** | Menú — filas producto | Overflow trailing (iconos+Switch); TabBar sin scroll | Overflow menu; `isScrollable` | Responsive + Layout | Móvil | Menú, Costos | ✅ 2026-07-22 | RS menú |
| **NAV-ADM-06** | Cobro mesa admin | Más taps que cajero; densid. opciones | «Cobrar todo» / CTA kanban / atajo Modo caja | Rediseño + Atajo | Todos | Mesas, Pedidos, Cajero | ✅ 2026-07-22 | FF-07 follow-up |

---

## Backlog — Prioridad Media

| ID | Pantalla | Problema (resumen) | Mejora | Tipo | Dispositivos | Afectadas | Estado | Ref |
|----|----------|-------------------|--------|------|--------------|-----------|--------|-----|
| **NAV-ADM-07** | AppBar móvil | Dropdown sede + 3 iconos saturan | Overflow ⋮; sede en drawer | Responsive | Móvil | Panel | ✅ 2026-07-22 | R-04 |
| **NAV-ADM-08** | Búsqueda global | Dialog fijo; pedido no abre tarjeta | Full-width móvil; deep-link | Atajo + Responsive | Móvil, PC | Búsqueda, Pedidos, Mesas | ✅ 2026-07-22 | AR-28 |
| **NAV-ADM-09** | Dashboard sede | `onIrMesas` no usado | KPI Mesas / QR → mesas | Conexión | Todos | Dashboard, Mesas | ✅ 2026-07-22 | FF-04 gap |
| **NAV-ADM-10** | Dashboard cadena | KPIs ventas/activos no navegan | Taps a reportes/pedidos | Conexión | Tablet, PC | Consolidado | ✅ 2026-07-22 | — |
| **NAV-ADM-11** | Pedidos vista/kanban | Admin default grid; cols 300px scroll H | Preferencia + cols flex | Responsive + Rediseño | PC, Tablet | Pedidos | ✅ 2026-07-22 | RS-21 |
| **NAV-ADM-12** | Nuevo pedido sidebar | Duplica Operación; split 900 vs shell 720 | CTA Nuevo en Pedidos; BP → 24 | Rediseño + Responsive | Todos | Pedidos, POS | ✅ 2026-07-22 | NAV-09 |
| **NAV-ADM-13** | Caja | Movimiento sin link a pedido | Tap → pedidos | Conexión | Todos | Caja, Pedidos | ✅ 2026-07-22 | AR-05 |
| **NAV-ADM-14** | Insumos | Curva alta; alerta no aterriza en acción | Deep-link tab+insumo; tareas | Conexión + Rediseño | Todos | Inventario, Alertas | 📅 | AR-07, AR-14 |
| **NAV-ADM-15** | Cocinas vs KDS | Nombres confunden config vs ops | Rename + badge Operación | Otro (copy) | Todos | Cocinas, KDS | ✅ 2026-07-22 | — |
| **NAV-ADM-16** | Reportes vs Analítica | Solapan conceptos | Subtítulos sidebar o landing | Otro (IA) | Todos | Finanzas | ✅ 2026-07-22 | — |
| **NAV-ADM-17** | Facturación | Sin Ver pedido; preview overflow | Link bidireccional + constrain | Conexión + Feedback | Todos | Facturación, Pedidos | ✅ 2026-07-22 | AR-19 |
| **NAV-ADM-18** | Alertas | Tap sin ref = silencio; toolbar densa | SnackBar; Wrap toolbar | Feedback + Responsive | Móvil / Todos | Alertas | ✅ 2026-07-22 | AR-32 |
| **NAV-ADM-19** | Domiciliarios admin | Nombre ≈ dashboard campo | Copy «Gestionar repartidores» | Conexión + Otro | Todos | Domi admin vs planta | ✅ 2026-07-22 | NAV-05 |

**También Media (transversal):**

| ID | Tema | Mejora | Estado |
|----|------|--------|--------|
| **NAV-ADM-24** | Breakpoints 720 vs 900 | Unificar `FoodyBreakpoints` (doc responsive) | 📅 diferido |

---

## Backlog — Prioridad Baja

| ID | Pantalla | Problema (resumen) | Mejora | Tipo | Dispositivos | Estado | Ref |
|----|----------|-------------------|--------|------|--------------|--------|-----|
| **NAV-ADM-20** | Menú ↔ Costos | Atajo solo ida | Breadcrumb / Volver al menú | Conexión | Todos | ✅ 2026-07-22 | AR-10/11 |
| **NAV-ADM-21** | Zonas / Horarios / Sucursales | Empty débil; sin preview cliente | Empty+CTA; preview horario | Feedback | Todos | ✅ 2026-07-22 | AR-31 |
| **NAV-ADM-22** | Promociones / Usuarios | Dialogs estrechos en PC | maxWidth 560 / panel | Responsive | PC | ✅ 2026-07-22 | — |
| **NAV-ADM-23** | Mejorar plan | 3 entradas al mismo sitio | Una CTA primaria | Consistencia | Todos | ✅ 2026-07-22 | — |

---

## En curso (sesión actual)

| ID | Qué se hace | Quién / notas |
|----|-------------|----------------|
| — | *Baja cerrada* | Quedan diferidos Media **14/24** · QA F0 |

Cuando empiece un ítem: pasar de 📅 → 🔄 aquí y en la fila del backlog. Al cerrar: 🔄 → ✅ + fecha + evidencia en changelog abajo.

---

## Qué se hará (orden acordado)

1. ~~NAV-ADM-01…06~~ ✅ Alta completa 2026-07-22
2. ~~Media 07–13,15–19~~ ✅ · **📅 diferidos:** 14 (insumos), 24 (breakpoints)
3. ~~Baja NAV-ADM-20…23~~ ✅ 2026-07-22
4. Sync docs / QA · opcional cerrar 14/24

---

## Conexiones entre roles

| Mejora admin | Otro rol | Impacto |
|--------------|----------|---------|
| NAV-ADM-02 sheet Pedidos | Cajero, Mesero | Mismo `PedidosKanbanWidget` |
| NAV-ADM-03 / 04 Mesas | Mesero, Cajero | Mismo `MesasGridWidget`; long-press solo admin hoy |
| NAV-ADM-06 cobro rápido | Cajero | Journey óptimo es `/admin/cajero` |
| NAV-ADM-15 Cocinas/KDS | Cocina standalone | Mismo `KdsScreen` |
| NAV-ADM-19 Domiciliarios | Domi planta | Evitar confusión de nombres |
| NAV-ADM-21 preview horarios | Cliente | Coherencia menú público |
| NAV-ADM-01 / 08 shell | — | Solo panel restaurante (sin sidebar en cajero/mesero) |

---

## Criterios de aceptación (por ítem Alta)

Al marcar ✅ un NAV-ADM-XX:

1. Diff solo frontend (sin lógica NestJS / BD salvo que el atajo ya tenga API).
2. `flutter analyze` en archivos tocados sin errores nuevos.
3. Smoke: flujo del rol admin en el tamaño indicado (al menos Móvil **o** PC según el ítem).
4. Si toca widget compartido: notar impacto en cajero/mesero en el changelog.
5. Actualizar esta tabla (Estado + fecha) y una línea en «Changelog» abajo.

---

## Changelog de este documento

- **2026-07-22:** **Baja 20–23** ✅ — Volver/breadcrumb Menú↔Costos; empty+CTA zonas/sucursales + preview horarios; dialogs max 560; sidebar sin duplicar Mejorar plan (banner + módulo bloqueado).
- **2026-07-22:** **Media 07–13,15–19** ✅ — AppBar ⋮ móvil; búsqueda deep-link; KPIs dashboard; kanban default+cols flex+Nuevo; caja→pedido; copy cocinas/KDS/reportes/analítica/repartidores; factura Ver pedido+preview constrain; alertas SnackBar+Wrap. **Diferidos:** NAV-ADM-14, NAV-ADM-24.
- **2026-07-22:** **NAV-ADM-04…06** ✅ — banner QR tappable+Revisar; menú productos ⋮ + TabBar scroll; Modo caja + hint cobrar + CTA «Cobrar todo · $».
- **2026-07-22:** **NAV-ADM-03** ✅ — ⋮ en tile mesa admin (`mesas_grid_widget`); long-press se mantiene.
- **2026-07-22:** **NAV-ADM-02** ✅ — sheet Pedidos: Cobrar mesa / Ir a caja / Factura+banner emitir / Abrir KDS. Archivos: `pedidos_kanban_widget`, `panel_restaurante_screen`, `facturacion_admin_screen`.
- **2026-07-22:** **NAV-ADM-01** ✅ — ★ visible en tiles; favoritos en rail tablet; ★ en popup de grupos; hint «Toca ★». Archivo: `panel_sidebar_nav.dart`.
- **2026-07-22:** Creación. Diagnóstico Fase 1 (24 hallazgos NAV-ADM-01…24). Implementación no iniciada. Corrección de estado real AR-28/29/FF-04 vs docs antiguos (🟡 descubribilidad).

---

## Cómo usar en cada sesión

1. Leer **Estado del ciclo** + **En curso**.
2. Si hay 🔄, terminar ese ítem antes de abrir otro.
3. Si no hay 🔄 y el plan está aprobado, tomar el siguiente 📅 de Alta (luego Media, luego Baja).
4. No reinventar: enlazar a AR/FF existentes cuando aplique.
