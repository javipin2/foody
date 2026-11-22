# Plan — Completar Análisis / Reportes

> **Estado:** Fase 1 implementada (2026-07-29) — pendiente QA API viva (Supabase local)  
> **Fecha:** 2026-07-29  
> **Base:** inventario Fase 0 (sesión) + decisiones de producto abajo  
> **Spec previa:** `MODULO_ANALITICA_BI.md` (núcleo ya construido; este plan **extiende**, no rehace)

---

## Decisiones cerradas (producto)

| # | Decisión | Elección |
|---|----------|----------|
| 1 | ¿Dónde filtros + gráficas? | **Solo Análisis (Insights).** Reportes = export rápido + auditoría con periodo simple. |
| 2 | Huecos de datos | **A** poblar `duracion_estado_anterior_seg` · **B** persistir `distancia_km` · **C** inferir frecuente/nuevo · **D** omitir “por cocinero”. **No** atribución KDS. |
| 3 | Exportación | **Híbrido:** Flutter PDF/impresión (extender); backend CSV/Excel para rangos/filtros pesados. |
| 4 | Primera entrega | **Equilibrio:** filtros core + UI con datos API ya existentes + gráficas básicas + 3 preguntas reales contestables. |

**Principio:** no rehacer lo que ya funciona (endpoints `/analitica/*`, KPIs Resumen, export PDF/CSV Reportes, cuadre caja, tabs existentes). Extender o construir solo el gap.

**Leyenda por ítem:**  
- **Ya existe** — no tocar salvo cablear UI/filtros  
- **Extender** — hay base; completar  
- **Construir** — de cero en este plan  
- **Fuera de alcance** — explícito

---

## 0. Prerrequisitos de datos (habilitan métricas reales)

| Ítem | Tipo | Qué hacer |
|------|------|-----------|
| `duracion_estado_anterior_seg` | **Extender** (columna existe, insert no la llena) | En `PedidosEstadoCommandService.aplicarEstadoEnTransaccion`: al insertar historial, calcular segundos desde el último `fecha` del mismo `pedido_id`. |
| `asignaciones_domicilio.distancia_km` | **Construir** (columna + write) | Migración `ADD COLUMN distancia_km numeric`; al crear/aceptar asignación, guardar el km ya calculado en dispatch. Histórico = NULL. |
| Cliente frecuente / nuevo | **Construir** (regla, sin CRM) | Regla: **frecuente** = ≥ N pedidos válidos en últimos 90 días con mismo `cliente_telefono` o `device_id` (N default 3, configurable en umbrales). **Nuevo** = 1er pedido en el periodo o &lt; N en 90d. Filtro en API; no tabla nueva. |
| Por cocinero | **Fuera de alcance** | No hay `cocinero_id` en ítems. Tabs Cocinas = por estación (`cocinas`), no por persona. |

---

## 1. Centro de filtros combinables

**Ámbito UI:** solo `AnaliticaScreen` (+ drawer/modal). Reportes **no** recibe este centro.

| Capacidad | Tipo | Detalle |
|-----------|------|---------|
| Periodo: hoy / 7d / 30d / mes | **Ya existe** | Chips actuales |
| Ayer, esta semana, mes anterior, rango fechas | **Extender** | Backend DTO ya tiene presets; UI no los expone |
| Este año | **Construir** | Preset `anio` → 1-ene → hoy (Bogotá) |
| Rango de horas (`hora_desde`–`hora_hasta`, 0–23) | **Construir** | Filtro SQL sobre `EXTRACT(HOUR FROM created_at AT TIME ZONE 'America/Bogota')` (o timestamp del dominio: entregas → `entregado_at`) |
| Estado pedido (pagados, pendientes, cancelados, en_cocina, entregados, …) | **Construir** | Multi-select → `estado = ANY(...)`. “Pendientes de pago” = no terminal cobrado (`estado` + `monto_pagado` vs `total`, reutilizar helpers de `pedido-estados.ts`) |
| “En preparación” | **Construir** | Mapear a `pedido_items.estado_cocina = 'preparando'` **o** pedido `en_cocina` — documentar en API: filtro `item_estado_cocina` separado del estado de pedido |
| Facturados | **Extender** (dato parcial) | JOIN `facturas` donde exista factura emitida del `pedido_id`. Si FE pausada/pocos datos, el filtro funciona pero puede devolver vacío |
| Meseros: todos / uno / varios | **Construir** | `pedidos.mesera_id = ANY(...)`. Modo comparar varios = misma query + `GROUP BY mesera_id` en series |
| Cocina / estación | **Construir** | `COALESCE(pi.cocina_id, pr.cocina_id) = ANY(...)` |
| Domiciliarios | **Construir** | Filtro sobre `asignaciones_domicilio` (planta o independiente) |
| Productos: categoría / producto / combo / bebidas / postres | **Construir** | `categoria_id`, `producto_id`; combos vía `pedido_combo_selecciones` / productos combo; bebidas = categoría o cocina “Bebidas” **o** líneas en `pedido_item_bebidas` (definir OR documentado); postres = categoría/cocina por nombre/id |
| Clientes: específico / frecuente / nuevo | **Construir** | Teléfono o `device_id` + regla §0 |
| Caja / cajero / forma de pago | **Construir** | `caja_id`, `cajero_id` / `movimientos_caja.usuario_id`, `metodo_pago` |
| Combinación simultánea (ej. bebidas + mesero + horas + pagados + 1 producto) | **Construir** | Un solo DTO `FiltroAnaliticaDto` ampliado; todas las queries aplican el mismo `WHERE` builder |

### Contrato API (un endpoint-familia, no N combinaciones)

Mantener rutas actuales:

`GET /analitica/{resumen|ventas|productos|cocinas|inventario|domiciliarios|caja|riesgo|comparativa-sedes}`

Query params comunes (todos opcionales excepto scope):

```
sucursal_id
preset | desde+hasta
hora_desde, hora_hasta
estados[]                  # pedidos.estado
item_estados_cocina[]      # pedido_items.estado_cocina
solo_pendiente_pago        # bool
solo_facturados            # bool
mesera_ids[]
cocina_ids[]
domiciliario_ids[]         # uuid planta o independiente + tipo opcional
categoria_ids[]
producto_ids[]
incluir_combos             # bool
incluir_bebidas_addon      # bool
cliente_telefono | device_id
cliente_segmento           # frecuente | nuevo | todos
caja_ids[]
cajero_ids[]
metodos_pago[]
comparar                   # true | false
comparar_desde, comparar_hasta   # rangos custom (fase 2)
```

**Builder SQL compartido** (`AnaliticaFiltrosSql` o similar): un módulo que, dado el DTO, produce cláusulas reutilizadas por todos los métodos de `AnaliticaService`.  
**Reportes** sigue con `desde`/`hasta` solamente (sin este DTO).

**No** un mega-endpoint único tipo `/analitica/query`; sí **misma query string** en todos los GETs existentes.

---

## 2. Visualización (gráficas)

Hoy: Análisis tiene **una** línea en Ventas (`fl_chart`); el resto son KPIs/listas. Reportes: sin gráficas.

| Ítem | Tipo | Dónde |
|------|------|-------|
| Line chart ventas/día | **Ya existe** (parcial) | Tab Ventas — mantener |
| Barras (por hora, por tipo, por cocina, top productos) | **Construir** | Análisis; datos muchos ya en API |
| Circulares / pie (mix pago, mix tipo) | **Construir** | Resumen / Ventas / Caja |
| KPIs y tablas existentes | **Extender** | Reaccionan a filtros; no reemplazar |
| Gráficas en Reportes | **Fuera de alcance** | Decisión 1A |

**Regla:** Flutter solo pinta series/agregados del backend. Al cambiar filtros → invalidar cache de tabs y refetch.

---

## 3. Profundidad por pestaña (Análisis)

### Resumen / Ventas

| Métrica | Tipo |
|---------|------|
| KPIs actuales + mix pago + Δ periodo | **Ya existe** |
| Top productos más vendidos en Resumen | **Extender** (API productos ya tiene ranking; embeber o llamar) |
| Horas de mayor demanda | **Extender** (`por_hora` ya en `/ventas`; UI no lo muestra) |
| Series filtradas por DTO común | **Extender** |

### Productos

| Métrica | Tipo |
|---------|------|
| Ranking cantidad + margen en UI | **Ya existe** (parcial) |
| Rankings ingresos / margen + sin rotación | **Extender** (API ya; UI faltante) |
| Comparativa periodo en rankings | **Extender** (fase comparativas) |
| Agotados con demanda | **Construir** (producto no disponible + intentos/pedidos rechazados stock si hay señal; si no, diferir) |

### Cocinas

| Métrica | Tipo |
|---------|------|
| Unidades, ingresos, margen, top productos, prep media | **Ya existe** (prep media inútil hasta §0 duración) |
| Tiempo prom / máx / mín | **Extender** (AVG/MAX/MIN de duración tras poblar) |
| Horas pico por cocina | **Construir** |
| Pedidos retrasados (prep &gt; umbral) | **Construir** (umbral en `UMBRALES_ALERTA` o config) |
| Por cocinero | **Fuera de alcance** |

### Domi

| Métrica | Tipo |
|---------|------|
| Entregas, tiempo prom, % tardías, ranking | **Ya existe** (parcial UI) |
| Valor transportado (`costo_domicilio` / total pedido) | **Extender** (API ya trae `ingresos_domicilio`; UI + aclarar definición) |
| Distancia | **Extender** tras §0 persistencia; histórico NULL → “n/d” |

### Caja

| Métrica | Tipo |
|---------|------|
| Cuadre pedidos vs movimientos | **Ya existe** en Análisis y Reportes (SQL duplicado) |
| Reutilizar lógica Reportes | **Extender** — extraer helper compartido `cuadreCaja(sucursal, rango, filtros)` usado por ambos servicios |
| Ingresos / egresos / métodos / aperturas-cierres / diferencias | **Extender** (API caja ya tiene retiros, gastos_por_categoria, cierres; UI incompleta) |

### Inventario

| Métrica | Tipo |
|---------|------|
| Consumo, mermas, dif conteo, bajo mínimo | **Ya existe** (parcial UI) |
| Top consumo | **Extender** (API sí; UI no) |
| Valor inventario actual (stock × costo) | **Construir** |
| Menor rotación insumos | **Construir** |
| Productos menú agotados | **Extender** (`productos.disponible = false` + opcional cruce ventas) |

### Riesgo

| Hoy | Debe vivir aquí |
|-----|-----------------|
| Contador alertas abiertas (global) | Mantener + **lista** de alertas abiertas (tipo, nivel, fecha) |
| Alertas por nivel, descuentos atípicos | **Ya existe** API; UI parcial |
| Cancelaciones por usuario | **Extender** UI + filtrar rol mesero |
| Diferencias caja, salió sin pagar, transferencias | **Ya existe** en API `senales` / umbrales; **Extender** UI |
| Retrasos cocina/domi | **Construir** / enlazar alertas nuevas §4 |

---

## 4. Alertas inteligentes

Contador actual = **Ya existe** (COUNT `revisada = false`). Completar:

| Alerta | Tipo | Lógica |
|--------|------|--------|
| Tipos operativos actuales (descuento, cuadre, demora entrega, margen, caída producto, …) | **Ya existe** | `AlertasRiesgoService` + callers |
| Δ tiempo prep cocina vs periodo anterior | **Construir** | Requiere §0 duración; batch/cron o al cerrar día |
| Caída ventas por categoría | **Extender** | Patrón similar a `caida_ventas_producto` |
| Mesero con % cancelación &gt; promedio sede | **Construir** | Sobre historial cancel + `mesera_id` |
| Producto sin venta en X días | **Construir** | Cruce catálogo vs `pedido_items` |
| Insumo → stock mínimo | **Ya existe** (parcial) | Inventario/alertas stock; asegurar que alimente `alertas_riesgo` y aparezca en Resumen |

**UI Resumen:** no solo el número — chip/lista “Alertas abiertas” con deep-link a tab Riesgo / pantalla alertas (NAV-ADM2 ya enlaza alertas).

---

## 5. Exportación

| Capacidad | Tipo | Notas |
|-----------|------|-------|
| PDF/CSV Reportes (periodo simple, sin filtros avanzados) | **Ya existe** | `ReporteExportFoody` + share |
| Export Análisis con **filtros aplicados** | **Construir** | Botón en Análisis |
| PDF / impresión desde Flutter | **Extender** | Reutilizar generador; pasar snapshot del tab o “informe completo” filtrado |
| CSV/Excel desde backend | **Construir** | `GET /analitica/export?formato=csv|xlsx&...mismos filtros` |
| Auditoría en export Reportes | **Extender** (opcional fase 2) | Hoy no entra al PDF/CSV |

---

## 6. Comparativas de periodo

| Capacidad | Tipo |
|-----------|------|
| Chip Comparar + Δ ventas en Resumen | **Ya existe** |
| Δ en todas las pestañas (mismos KPIs/series del tab) | **Extender** |
| Dos rangos custom (`comparar_desde` / `comparar_hasta`) | **Construir** |
| Comparar meseros (varios IDs) lado a lado | **Construir** (reuse GROUP BY) |
| Comparativa sedes | **Ya existe** (corporativo) |

---

## Arquitectura de datos y rendimiento

1. **Filtro builder único** — evita N variantes SQL por combinación.  
2. **Índices** (migración; varios ya en `055`/`056` — completar huecos):
   - `pedidos (sucursal_id, created_at)` + partial por estado si hace falta  
   - `pedidos (sucursal_id, mesera_id, created_at)`  
   - `pedido_items (cocina_id)` / `(producto_id)`  
   - `movimientos_caja (sucursal_id, created_at, tipo)`  
   - `asignaciones_domicilio (sucursal_id, entregado_at)`  
   - `alertas_riesgo (sucursal_id, revisada)`  
3. **Límites:** max rango 366 días; con filtros de hora/producto el scan baja. Rankings `LIMIT 25–50`.  
4. **Cache corto** in-memory por hash `(sucursal + filtros + tab)` 60–120 s para periodos cerrados.  
5. **Vistas materializadas** (`mv_ventas_diarias_sucursal`, `mv_ventas_cocina_diaria`): **fase tardía** (F5 del doc BI), no bloquean Fase 1. Día en curso = tablas vivas.  
6. **No** materializar todas las combinaciones de filtro — imposible; MV solo ejes frecuentes (día × sucursal × opcional cocina).

---

## Responsive (Móvil / Tablet / PC)

| Superficie | Comportamiento |
|------------|----------------|
| **Filtros** | PC/tablet ancha: panel colapsable superior o rail. Móvil: botón “Filtros” → **modal/bottom sheet** con chips + aplicar. Badge con # filtros activos. |
| **Gráficas** | PC: 2 columnas. Tablet: 1–2. Móvil: **apiladas**, altura fija ~180–220. |
| **Tablas / rankings** | PC: DataTable/listas. Móvil: **tarjetas** (patrón ya usado en Productos/Cocinas). |
| **KPIs** | `Wrap` actual; en móvil 2 por fila. |
| Reportes | Sin cambio de layout mayor (solo export). |

Alinear con `docs/frontend/FRONTEND_RESPONSIVE_STRATEGY.md`.

---

## Orden de construcción sugerido

### Fase 1 — Entrega usable (prioridad) ✅ objetivo “equilibrio”
1. Poblar `duracion_estado_anterior_seg`  
2. `FiltroAnaliticaDto` + SQL builder + aplicar a endpoints existentes  
3. UI centro de filtros (core: tiempo + horas + estado + mesero + cocina + categoría/producto)  
4. Cablear UI a datos API ya existentes (`por_hora`, rankings, top consumo, caja gastos/cierres, riesgo señales)  
5. Gráficas básicas (barras hora, pie mix pago, barras top productos)  
6. Validar las **3 preguntas** (§ siguiente)  

### Fase 2 — Profundidad + export híbrido ✅ (2026-07-30)
1. Persist `distancia_km` + UI Domi — hecho en Fase 1 (migr. 070 + inserts)  
2. Segmento cliente frecuente/nuevo + filtro — hecho en Fase 1  
3. Filtros caja/cajero/método/domiciliario/facturados — hecho en Fase 1  
4. Tiempos min/max cocina + alertas (mesero cancelación, sin venta); Δ prep vs periodo queda Fase 3  
5. Export Análisis: Flutter PDF + `GET /analitica/export` CSV (xlsx = mismo CSV; nativo = Fase 3)  
6. Comparar en todas las tabs + rangos custom (`comparar_desde`/`comparar_hasta`)  

### Fase 3 — Escala ✅ parcial (2026-07-30)
1. Extraer `cuadreCaja` compartido — **aplazado** (YAGNI: Reportes y Analítica tienen superficies de filtro distintas)
2. Índices restantes + cache — **aplazado** (sin dolor de carga)
3. Vistas materializadas — **aplazado**
4. Lista rica de alertas en Resumen + alertas Δ prep / caída categoría — **hecho**
5. XLSX nativo — **aplazado** (CSV abre en Excel)

---

## Validación — 3 preguntas reales

### 1. «¿Cuánto vendió Juan el martes pasado entre 14:00–18:00, solo bebidas, y cuáles quedaron pendientes de pago?»

| Parte | ¿Se puede? | Cómo |
|-------|------------|------|
| Juan (mesero) | **Sí** (Fase 1) | `mesera_ids=[uuid Juan]` |
| Martes pasado + 14–18h | **Sí** (Fase 1) | `preset=rango` desde/hasta = ese día + `hora_desde=14&hora_hasta=18` |
| Solo bebidas | **Sí si** la sede tiene cocina o categoría “Bebidas” (o productos en esa cocina) | `cocina_ids` o `categoria_ids` |
| Ventas | **Sí** | `/analitica/resumen` o `/ventas` con filtros → `ventas_netas` |
| Pendientes de pago | **Sí** | Mismo filtro tiempo/mesero/bebidas + `solo_pendiente_pago=true` (o `estados` no pagados + saldo) |

**No bloqueado por Fase 0** si Juan tiene `mesera_id` en pedidos y bebidas están tipificadas por cocina/categoría.

### 2. «¿Qué cocina preparó más platos este mes y cuánto tiempo tardó en promedio?»

| Parte | ¿Se puede? | Cómo |
|-------|------------|------|
| Cocina con más platos | **Sí hoy** (API `/cocinas`) | `preset=mes` → max `unidades` |
| Tiempo promedio | **Hoy no fiable** → **Sí tras Fase 1 §0** | AVG `duracion_estado_anterior_seg` en transición `en_cocina`→`listo` |

Sin poblar duración, el plan **no** puede responder la segunda mitad con honestidad.

### 3. «¿Cuáles son los cinco productos que más se cancelan después de ser enviados a cocina?»

| Parte | ¿Se puede? | Cómo |
|-------|------------|------|
| Cancelación post-cocina | **Parcial → Extender** | Pedidos con historial que tuvieron `en_cocina` (o posterior) y luego `cancelado`/`rechazado`; agregar `pedido_items` de esos pedidos → top 5 productos |
| Cancelación a nivel ítem en cocina | **Parcial** | Existe eliminación ítem / `no_disponible` + alertas; ranking dedicado = **Construir** query en `/riesgo` o `/productos` |

**Limitación Fase 0:** el historial es por **pedido**, no por ítem. La respuesta “productos más cancelados tras envío a cocina” es una **aproximación** (líneas del pedido cancelado después de haber estado en cocina), no “este SKU se canceló en KDS” salvo flujos de ítem. El plan lo documenta así en la UI (“pedidos cancelados tras cocina”).

---

## Qué no se hace en este plan

- Unificar pantallas Reportes + Análisis  
- Filtros avanzados en Reportes  
- Atribución por cocinero  
- CRM de clientes  
- Reescribir endpoints que ya existen  
- MV como requisito de Fase 1  

---

### Criterios de aceptación Fase 1

- [x] Combinar mesero + cocina + horas + estado/pagado en una sola consulta (DTO + SQL builder + UI filtros)
- [x] Las 3 preguntas del § validación contestables en diseño (API + UI); QA E2E pendiente de API/BD viva
- [x] `duracion_estado_anterior_seg` poblado en cambios de estado nuevos (`PedidosEstadoCommandService`)
- [x] Reportes intactos (sin filtros avanzados)
- [x] Script `scripts/verificar-analitica.ps1` extendido con multi-filtro (ejecutar cuando API esté arriba)

### Hecho en código (2026-07-29)

| Área | Archivos clave |
|------|----------------|
| Duración estados | `pedidos-estado-command.service.ts` |
| Migración distancia + índices | `070_analitica_filtros_distancia.sql` |
| Filtros API | `filtro-analitica.dto.ts`, `analitica-filtros.util.ts`, `analitica.service.ts`, controller |
| Distancia al asignar | `dispatch.service.ts`, `domiciliarios.service.ts`, `domiciliarios-independientes.service.ts` |
| Alertas nuevas | `producto_sin_venta`, `mesero_cancelacion_alta` en `alertas-riesgo.service.ts` |
| Flutter | `analitica_screen.dart`, `analitica_filtros_sheet.dart`, `analitica_export_foody.dart`, repository |

### Criterios de aceptación Fase 2

- [x] `GET /analitica/export` CSV UTF-8 BOM con mismos filtros
- [x] Comparativa KPIs en tabs (ventas/productos/cocinas/inventario/domi/caja/riesgo) cuando `comparar=true`
- [x] Flutter: export CSV + banner comparar + rango custom
- [x] `verificar-analitica.ps1` incluye export + ventas comparativa (OK 2026-07-30)

### Criterios de aceptación Fase 3 (parcial)

- [x] `alertas_abiertas_lista` en `/analitica/resumen` + UI Resumen con puente a Riesgo
- [x] `cocinas_prep_delta` + `categorias_caida` en `/analitica/riesgo?comparar=true` + UI
- [x] Cron `evaluarAlertasProgramadas`: `cocina_prep_subida`, `caida_ventas_categoria`
- [ ] XLSX nativo / MV / cuadreCaja compartido (aplazados YAGNI)

### Pendiente opcional

- XLSX nativo; vistas materializadas / cache
- Click-through QA en dispositivo
- Extraer `cuadreCaja` solo si Reportes y Analítica divergen peligrosamente

---

## Referencias

- Inventario Fase 0 (chat 2026-07-29)  
- `docs/MODULO_ANALITICA_BI.md`  
- Código: `analitica.service.ts`, `analitica_screen.dart`, `reportes_admin_screen.dart`, `reporte_export_foody.dart`, `alertas-riesgo.service.ts`  
- Decisiones: 1A · 2A+B+C+D · 3C · 4C  
