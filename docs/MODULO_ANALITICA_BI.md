# Foody — Módulo «Centro de Análisis» (Analítica / BI)

> **Estado:** 📅 Planificado (solo documentación). Aún no implementado.
> **Tipo:** Módulo nuevo (`analitica`) que **extiende** el módulo `reportes` existente, no lo reemplaza.
> **Última actualización:** 2026-06-20 — Spec inicial completa (arquitectura, BD, endpoints, fórmulas, fases).

Este documento es la **fuente de verdad** para construir el módulo. Léelo antes de implementar cualquier parte. Respeta las reglas globales: **Flutter = solo UI**, **NestJS + PostgreSQL = cerebro**, **toda query lleva `sucursal_id`**, respuestas `{ exito, datos, mensaje }`.

---

## 1. Objetivo

Una pantalla única (el «cerebro analítico») donde **dueños** y **administradores** ven el análisis completo de su operación: ventas, cocinas, inventario, domiciliarios, caja, riesgo/fraude, eficiencia y comparativas temporales, con gráficas y filtros de fecha flexibles.

No es un módulo operativo (no crea pedidos ni cobra). Es **solo lectura analítica** sobre datos que ya existen en la BD.

### Diferencia con el módulo `reportes` actual

| | `reportes` (hoy) | `analitica` (nuevo) |
|---|---|---|
| Endpoints | `/reportes/financiero`, `/productos`, `/pedidos` | Superset: cocinas, inventario, domi, riesgo, comparativas, KPIs |
| Filtros fecha | `desde`/`hasta` (rango simple) | Presets: día, semana, mes, rango libre + comparativa periodo anterior |
| Gráficas | Tablas | Series temporales, rankings, distribuciones, heatmaps |
| Riesgo | — | Panel de anomalías + alertas + auditoría correlacionada |
| Comparación | — | Mes vs mes, periodo vs periodo, sede vs sede (solo dueño) |

> **Decisión:** reutilizar y mover la lógica de `reportes.service.ts` dentro del nuevo módulo, dejando los 3 endpoints actuales como compatibilidad (o redirigir). No duplicar SQL.

---

## 2. Alcance funcional (qué muestra)

1. **Resumen ejecutivo (KPIs):** ventas netas, # pedidos, ticket promedio, margen bruto estimado, % cancelaciones, efectivo vs digital, alertas abiertas.
2. **Ventas:** serie temporal (por día/hora), por tipo de pedido (mesa/llevar/domicilio/encargo), por método de pago, por categoría.
3. **Cocinas:** por cada cocina → unidades vendidas, ingresos, costo de insumos descontado, margen, ranking de productos, tiempo medio de preparación.
4. **Productos:** top vendidos, top por ingresos, top por margen, productos sin rotación, productos agotados con más demanda.
5. **Inventario:** stock descontado por periodo (valor en $), mermas, ajustes manuales, diferencias de conteo, insumos bajo mínimo, ingredientes con mayor consumo.
6. **Domiciliarios:** entregas por repartidor, eficiencia (tiempo medio asignación→entrega), distancia/ingresos por domicilio, ranking, % entregas tardías.
7. **Caja:** ventas vs movimientos, cuadre (diferencias de cierre), gastos por categoría, retiros, cuentas por cobrar pendientes.
8. **Riesgo / fraude / inconsistencias:** anomalías detectadas, alertas por nivel, descuentos atípicos, cancelaciones por usuario, transferencias de mesa múltiples, "salió sin pagar", diferencias de caja, acciones de auditoría sospechosas.
9. **Eficiencia operativa:** tiempos por estado del pedido (cocina, listo→entregado), hora pico, mesas más rentables, meseros con más ventas.
10. **Comparativas:** periodo actual vs anterior (Δ% y tendencia); para dueño: comparación entre sucursales del mismo restaurante.

> El asistente debe añadir cualquier métrica útil que falte (ver §12 «Métricas adicionales sugeridas»).

---

## 3. Roles, permisos y alcance multi-sucursal

### 3.1 Quién ve qué

| Rol | Alcance | Selector de sede |
|-----|---------|------------------|
| **Dueño / corporativo** (`gestionar_sucursales`) | Cualquier sucursal **de su restaurante**; análisis depende de la sede seleccionada | ✅ Sí (lista de sucursales del restaurante) |
| **Admin de sucursal** | **Solo su** `sucursal_id` (la del JWT); ve todo de esa sede | ❌ No (fijo a su sede) |
| Otros roles (cajero, cocina, mesero, domiciliario) | Sin acceso al módulo | — |

- El permiso de acceso al módulo será **`ver_analitica`** (nuevo). Hereda la lógica de `ver_reportes`.
- Diferencia dueño vs admin: `SucursalScopeService.esCorporativo(usuario)` (permiso `gestionar_sucursales`). **No** inventar nueva lógica de scope: reutilizar `SucursalScopeService.resolverLecturaOperativa(usuario, sucursalIdSolicitada)`.
- Comparación **entre** sucursales (sede vs sede) **solo** para corporativo; el admin nunca recibe datos de otra sede.

### 3.2 Regla de oro de seguridad

> **Cada endpoint resuelve la `sucursal_id` con `SucursalScopeService`, nunca confía en el `sucursal_id` crudo del query.** Un admin que pida otra sede recibe `403`. Todas las consultas SQL filtran por la `sucursal_id` ya validada.

### 3.3 Guards (orden NestJS, igual que `reportes`)

```
JwtAuthGuard → UsuarioActivoGuard → SuscripcionActivaGuard → PlanFeaturesGuard → RolGuard
@RequiereModulo('analitica')   // o 'reportes' si se decide no crear módulo de plan nuevo
@Permisos('ver_analitica')
```

> **Plan comercial:** decidir si `analitica` es un módulo aparte en `PlanFeaturesGuard` (p. ej. solo plan Pro/Enterprise) o si va incluido con `reportes`. Ver `docs/PLANES_SUSCRIPCION.md`. **Recomendado:** módulo propio `analitica` para poder venderlo como tier superior.

---

## 4. Arquitectura

```
Flutter (lib/features/analitica/)        NestJS (foody_backend/src/modulos/analitica/)
┌───────────────────────────┐            ┌──────────────────────────────────────────┐
│ AnaliticaScreen            │  Dio GET   │ AnaliticaController  (@Permisos)           │
│  - SelectorPeriodo         │ ─────────► │   /analitica/resumen                       │
│  - SelectorSucursal (dueño)│            │   /analitica/ventas                        │
│  - Tabs por sección        │ ◄───────── │   /analitica/cocinas                       │
│  - Gráficas (fl_chart)     │  JSON      │   /analitica/inventario                    │
│  AnaliticaRepository (red) │   {exito,  │   /analitica/domiciliarios                 │
│  AnaliticaProviders        │    datos,  │   /analitica/caja                          │
│  (Riverpod, estado UI)     │    mensaje}│   /analitica/riesgo                        │
└───────────────────────────┘            │ AnaliticaService (SOLO SQL de lectura)     │
                                          │   - reutiliza SucursalScopeService         │
   Flutter NO calcula nada.               │   - rango/fechas, comparativas, anomalías  │
   Solo pinta lo que llega.               └──────────────────────────────────────────┘
```

- **Flutter:** formatea moneda/fechas para mostrar (strings), pinta gráficas con datos ya calculados. **No** suma, no promedia, no calcula márgenes. Si una gráfica necesita un agregado, lo provee el backend.
- **NestJS:** todo el cálculo. Cada endpoint devuelve datos listos para pintar.
- **PostgreSQL:** agregaciones con `GROUP BY`, `FILTER`, `date_trunc`, ventanas. Zona horaria fija `America/Bogota` (igual que `reportes.service.ts`).

---

## 5. Modelo de datos (tablas fuente — ya existen)

> No se crean tablas nuevas para el MVP. Todo sale de las tablas operativas. (Optimización con vistas materializadas: §10.)

| Dominio | Tabla(s) | Columnas clave para análisis |
|---------|----------|------------------------------|
| Ventas | `pedidos` | `sucursal_id, tipo, estado, subtotal, costo_domicilio, descuento, total, metodo_pago, created_at, mesa_id, cajero_id` |
| Líneas de venta | `pedido_items` | `pedido_id, producto_id, cocina_id, cantidad, precio_unitario, costo_unitario, estado_cocina` |
| Cocinas | `cocinas`, `productos.cocina_id` | `cocinas.id, nombre`; producto→cocina |
| Tiempos de estado | `estados_pedido_historial` | `pedido_id, estado_anterior, estado_nuevo, fecha, duracion_estado_anterior_seg, usuario_id` |
| Márgenes | `margenes_venta` | `pedido_item_id, precio_venta, costo_al_momento, margen_porcentaje` |
| Caja | `cajas`, `movimientos_caja`, `gastos` | `tipo (venta/retiro/gasto/ingreso_extra/apertura), monto, metodo_pago, diferencia` |
| Cuentas | `cuentas_por_cobrar` | `monto, estado (pendiente/pagada)` |
| Inventario | `movimientos_ingrediente` | `tipo (compra/venta/ajuste/merma/produccion/conteo), cantidad, stock_anterior, stock_posterior, ingrediente_id` |
| Costo insumo | `ingredientes.costo_unitario_actual` | valorizar consumo |
| Conteos | `conteos_inventario`, `conteo_items.diferencia` | diferencias físicas |
| Domiciliarios | `asignaciones_domicilio` | `domiciliario_planta_id, estado, asignado_at, entregado_at` |
| Riesgo | `alertas_riesgo` | `tipo, nivel, revisada, created_at` |
| Auditoría | `auditoria_logs` | `usuario_id, accion, tabla_afectada, datos_antes, datos_despues, created_at` |
| Mesas | `transferencias_mesa` | transferencias por pedido |
| Estructura | `restaurantes`, `sucursales` | scope dueño |

### 5.1 Notas importantes de integridad (para no equivocar los números)

- **Ventas "reales":** excluir siempre `estado IN ('cancelado','rechazado')`. Para cuadre de caja, comparar contra `movimientos_caja.tipo = 'venta'`.
- **Filtro de fecha de ventas:** usar `pedidos.created_at`. Para caja usar `COALESCE(p.created_at, m.created_at)` (patrón ya usado en `reportes.service.ts` línea 36).
- **Cocina de un ítem:** preferir `pedido_items.cocina_id`; si es `NULL`, caer a `productos.cocina_id`. Documentar este fallback en SQL (`COALESCE(pi.cocina_id, pr.cocina_id)`).
- **Costo de venta:** `pedido_items.costo_unitario` es el costo congelado al momento de la venta. Úsalo para margen histórico. **No** recalcular con `productos.costo_calculado` actual (cambia con el tiempo).
- **Stock descontado valorizado:** `movimientos_ingrediente` de `tipo = 'venta'` × `ingredientes.costo_unitario_actual` da una **aproximación** (el costo actual ≠ costo al momento). Si se requiere exactitud, congelar costo en el movimiento (mejora futura, §11).
- **`pedidos.total` ya viene calculado por el backend** (incluye IVA/descuento/domicilio). Flutter nunca lo recompone.
- **Multi-sucursal:** un dueño con `gestionar_sucursales` puede pedir cualquier sede de su restaurante; el SQL filtra por la única `sucursal_id` resuelta (no agregamos varias sedes en un mismo número salvo en la vista comparativa explícita).

---

## 6. Filtros de fecha (contrato común)

Todos los endpoints aceptan los mismos query params:

| Param | Tipo | Ejemplo | Significado |
|-------|------|---------|-------------|
| `preset` | enum | `hoy`, `ayer`, `semana`, `mes`, `mes_anterior`, `7d`, `30d`, `rango` | Atajo de periodo |
| `desde` | date (YYYY-MM-DD) | `2026-05-17` | Inicio (si `preset=rango`) |
| `hasta` | date (YYYY-MM-DD) | `2026-06-12` | Fin inclusivo |
| `comparar` | bool | `true` | Devuelve además el periodo anterior equivalente |
| `sucursal_id` | uuid | … | Solo respetado si el usuario es corporativo; si no, se ignora y se usa el del JWT |
| `tz` | string | `America/Bogota` | Default fijo; no exponer al cliente por ahora |

### 6.1 Resolución del rango (backend)

- `mes` → primer día del mes actual 00:00 hasta ahora.
- `mes_anterior` → mes calendario completo anterior.
- `semana` → lunes de la semana actual hasta ahora (semana ISO).
- `rango` → usa `desde`/`hasta`; **validar** `desde <= hasta` y un tope máximo (p. ej. 366 días) para proteger el rendimiento.
- **Fin inclusivo:** las queries usan `created_at < (hasta::date + interval '1 day')` (patrón actual), nunca `BETWEEN` con horas.
- Extender `ReportesService.resolverRango` → `resolverPeriodo(preset, desde, hasta)` devolviendo `{ desde, hasta, label }` y, si `comparar`, `{ anterior: { desde, hasta } }`.

### 6.2 Periodo anterior para comparar (Δ%)

- Para `mes`: mismo nº de días del mes anterior (o mes calendario anterior — **decidir y documentar**; recomendado: mes calendario anterior completo para "mes", y "mismos N días" para presets de N días).
- Para `rango` de N días: los N días inmediatamente anteriores a `desde`.

---

## 7. Endpoints propuestos

Base: `/api/v1/analitica`. Todos `GET`, todos con guards de §3.3, todos devuelven `{ exito, datos, mensaje }`.

| Endpoint | Devuelve (en `datos`) |
|----------|------------------------|
| `GET /analitica/resumen` | KPIs del periodo + Δ% vs anterior (si `comparar`) |
| `GET /analitica/ventas` | serie por día/hora, por tipo, por método, por categoría |
| `GET /analitica/cocinas` | por cocina: unidades, ingresos, costo, margen, top productos, tiempo prep medio |
| `GET /analitica/productos` | rankings (cantidad, ingresos, margen), sin rotación |
| `GET /analitica/inventario` | consumo valorizado, mermas, ajustes, diferencias de conteo, bajo mínimo |
| `GET /analitica/domiciliarios` | entregas, eficiencia, ranking, % tardías |
| `GET /analitica/caja` | ventas vs caja, cuadre, gastos por categoría, retiros, CxC |
| `GET /analitica/riesgo` | anomalías, alertas por nivel, descuentos atípicos, cancelaciones por usuario, auditoría sospechosa |
| `GET /analitica/comparativa-sedes` | **solo corporativo**: KPIs lado a lado por sucursal del restaurante |

### 7.1 Forma de respuesta (ejemplo `resumen`)

```jsonc
{
  "exito": true,
  "datos": {
    "periodo": { "preset": "mes", "desde": "2026-06-01", "hasta": "2026-06-20", "label": "Junio 2026" },
    "sucursal_id": "c0000000-…-0001",
    "kpis": {
      "ventas_netas": 4820000,
      "pedidos": 312,
      "ticket_promedio": 15448.7,
      "margen_bruto_estimado": 2710000,
      "margen_bruto_pct": 56.2,
      "pct_cancelacion": 4.1,
      "efectivo_vs_digital": { "efectivo": 0.62, "digital": 0.38 },
      "alertas_abiertas": 3
    },
    "comparativa": {
      "anterior": { "desde": "2026-05-01", "hasta": "2026-05-31", "ventas_netas": 4100000 },
      "delta": { "ventas_netas_pct": 17.6, "tendencia": "sube" }
    }
  },
  "mensaje": "Operación exitosa"
}
```

> **Convención de claves:** snake_case en JSON (consistente con el backend actual). Montos en número (no string) ya parseados.

---

## 8. Fórmulas matemáticas (definición exacta — el backend las implementa)

> Estas definiciones evitan ambigüedad. Toda fórmula se calcula en SQL/servicio NestJS, **nunca** en Flutter.

### 8.1 Ventas y ticket

```
ventas_netas      = Σ pedidos.total            WHERE estado ∉ (cancelado, rechazado)
pedidos_validos   = COUNT(pedidos)             (mismo filtro)
ticket_promedio   = ventas_netas / NULLIF(pedidos_validos, 0)
subtotal_neto     = Σ pedidos.subtotal         (sin domicilio ni IVA según definición de subtotal)
descuentos_total  = Σ pedidos.descuento
```

### 8.2 Margen bruto (aproximado por línea)

```
costo_linea       = pedido_items.cantidad * pedido_items.costo_unitario
ingreso_linea     = pedido_items.cantidad * pedido_items.precio_unitario
margen_bruto      = Σ ingreso_linea − Σ costo_linea     (solo pedidos válidos)
margen_bruto_pct  = margen_bruto / NULLIF(Σ ingreso_linea, 0) * 100
```
> Si `costo_unitario` es NULL en líneas antiguas, ese ítem cuenta ingreso pero costo 0 → margen sobrestimado. **Marcar en la respuesta** `cobertura_costo_pct` (= % de líneas con costo conocido) para que la UI advierta.

### 8.3 Por cocina

```
Para cada cocina c:
  unidades_c   = Σ pedido_items.cantidad         WHERE COALESCE(pi.cocina_id, pr.cocina_id) = c
  ingresos_c   = Σ (cantidad * precio_unitario)  (mismo filtro, pedidos válidos)
  costo_c      = Σ (cantidad * costo_unitario)
  margen_c     = ingresos_c − costo_c
  margen_pct_c = margen_c / NULLIF(ingresos_c, 0) * 100
  tiempo_prep_c = AVG(duracion estado 'en_cocina' → 'listo')  (de estados_pedido_historial)
```

### 8.4 Inventario (consumo valorizado)

```
consumo_unidades = Σ |movimientos_ingrediente.cantidad|  WHERE tipo = 'venta'
consumo_valor    = Σ |cantidad| * ingredientes.costo_unitario_actual   (aprox.)
merma_valor      = Σ |cantidad| * costo                  WHERE tipo = 'merma'
ajuste_neto      = Σ (stock_posterior − stock_anterior)  WHERE tipo = 'ajuste'
diferencia_conteo = Σ conteo_items.diferencia            (por conteo cerrado)
```

### 8.5 Domiciliarios (eficiencia)

```
entregas_d        = COUNT(asignaciones_domicilio)  WHERE estado='entregado' AND domiciliario_planta_id=d
tiempo_entrega_d  = AVG(EXTRACT(EPOCH FROM (entregado_at − asignado_at)) / 60)   (minutos)
pct_tardias_d     = entregas con tiempo > (UMBRAL * tiempo_estimado) / entregas_d * 100
ranking           = ORDER BY entregas_d DESC
```
> `UMBRALES_ALERTA.demoraEntregaMultiplo = 2` ya existe en `alertas-riesgo.service.ts`; reutilizar para "tardía".

### 8.6 Caja y cuadre

```
ventas_caja       = Σ movimientos_caja.monto   WHERE tipo='venta'
diferencia_cuadre = ventas_netas (pedidos) − ventas_caja
gastos_total      = Σ movimientos_caja.monto   WHERE tipo='gasto'  (+ tabla gastos)
retiros_total     = Σ movimientos_caja.monto   WHERE tipo='retiro'
cxc_pendiente     = Σ cuentas_por_cobrar.monto WHERE estado='pendiente'
```
> Umbral de descuadre relevante: `UMBRALES_ALERTA.cuadreCajaCOP = 5000`.

### 8.7 Comparativa (Δ%)

```
delta_pct = (actual − anterior) / NULLIF(anterior, 0) * 100
tendencia = delta_pct > +ε ? 'sube' : delta_pct < −ε ? 'baja' : 'estable'   (ε ≈ 1%)
```
> Si `anterior = 0` y `actual > 0` → mostrar "nuevo" en vez de ∞%.

### 8.8 Detección de anomalías (reglas, no ML en MVP)

| Señal | Regla | Umbral (constante) |
|-------|-------|--------------------|
| Descuento atípico | `pedido.descuento / NULLIF(subtotal,0) > X` | `descuentoPorcentajeAlto = 30%` |
| Cancelaciones por usuario | COUNT cancelaciones por `usuario_id`/día | `cancelacionesPorDia = 3` |
| Transferencias de mesa | COUNT por pedido | `transferenciasMesa = 2` |
| Descuadre de caja | `|diferencia_cuadre|` | `cuadreCajaCOP = 5000` |
| Caída de ventas | Δ% ventas vs media | `caidaVentasPct = 40%` |
| Margen bajo sostenido | margen_pct < umbral por N días | `margenBajoPct = 20`, `margenDias = 7` |
| Salió sin pagar | alertas `salio_sin_pagar` | conteo |

> **Reutilizar `UMBRALES_ALERTA`** (no inventar nuevos números). El panel de riesgo correlaciona estas señales con `alertas_riesgo` y `auditoria_logs`.

---

## 9. Pantalla Flutter (UI)

Ruta: `/admin/analitica` (GoRouter). Carpeta: `lib/features/analitica/`.

```
lib/features/analitica/
├── presentation/
│   ├── analitica_screen.dart            # Scaffold + tabs + selectores
│   ├── widgets/
│   │   ├── selector_periodo.dart         # presets + date range picker
│   │   ├── selector_sucursal.dart        # solo si esCorporativo
│   │   ├── tarjeta_kpi.dart
│   │   ├── grafica_serie_ventas.dart     # fl_chart LineChart
│   │   ├── grafica_cocinas.dart          # BarChart
│   │   ├── panel_riesgo.dart
│   │   └── tabla_ranking.dart
│   └── tabs/  (resumen, ventas, cocinas, inventario, domi, caja, riesgo)
├── data/
│   ├── analitica_repository.dart         # Dio → endpoints §7 (RespuestaApi)
│   └── modelos/                          # DTOs de cada respuesta
└── state/
    └── analitica_providers.dart          # Riverpod: periodo, sede, futures por tab
```

- **Gráficas:** usar `fl_chart` (revisar si ya está en `pubspec.yaml`; si no, añadir). Mantener estética Foody (`#FF6B35`, `#2EC4B6`, `#FFE66D`, Poppins/Inter).
- **Estados:** loading (shimmer), vacío ("sin datos en este periodo"), error (reintentar) — reutilizar patrones legacy ya existentes.
- **Selector de periodo:** chips de preset + `showDateRangePicker` para rango libre. Al cambiar, refresca todos los tabs (invalida providers).
- **Selector de sucursal:** visible solo si el login trae `gestionar_sucursales`; al cambiar, recarga con `sucursal_id`. (Patrón ya usado en panel admin multi-sede.)
- **Exportar (futuro):** botón a PDF/CSV → backend genera (no Flutter).

---

## 10. Rendimiento (clave para que no haya fallos ni lentitud)

1. **Índices existentes a aprovechar:** `idx_pedidos_sucursal_created (sucursal_id, created_at DESC)`, `idx_pedidos_sucursal_estado`. **Faltan y conviene añadir** (migración futura cuando se implemente):
   - `pedido_items (pedido_id)` y `pedido_items (cocina_id)`.
   - `movimientos_caja (sucursal_id, tipo, created_at)`.
   - `movimientos_ingrediente (sucursal_id, tipo, created_at)`.
   - `asignaciones_domicilio (domiciliario_planta_id, estado, entregado_at)`.
   - `alertas_riesgo (sucursal_id, revisada, created_at)`.
   - `auditoria_logs (sucursal_id, created_at)`.
2. **Una query por bloque, no N+1:** agregaciones con `GROUP BY` + `FILTER (WHERE …)`. Evitar bucles que disparen muchas queries (el patrón actual de `resumenInventarioHermanas` hace loop por sucursal — aceptable para pocas sedes, no para análisis fino).
3. **Cache corto:** resultados por `(sucursal_id, periodo)` cacheables 60–300 s (los datos históricos no cambian). Considerar cache en memoria del servicio para periodos cerrados (mes anterior es inmutable).
4. **Vistas materializadas (fase 3, opcional):** `mv_ventas_diarias_sucursal`, `mv_ventas_cocina_diaria` refrescadas por cron nocturno; el endpoint lee del MV para meses cerrados y de tablas vivas para el día en curso.
5. **Límites:** rankings con `LIMIT` (25 como en `reportes`). Validar rango máximo de fechas para no escanear años.
6. **Timezone:** convertir con `AT TIME ZONE 'America/Bogota'` al agrupar por día/hora (patrón ya usado).

---

## 11. Variables, constantes y configuración (a tener en cuenta)

| Qué | Dónde | Valor / nota |
|-----|-------|--------------|
| Zona horaria | backend (hardcode) | `America/Bogota` |
| Moneda | UI (formateo) | COP, formateo en Flutter sobre número ya calculado |
| Umbrales de riesgo | `alertas-riesgo.service.ts` → `UMBRALES_ALERTA` | reutilizar, no duplicar |
| Permiso de acceso | seed migración | `ver_analitica` (admin, gerente, dueño) |
| Módulo de plan | `PlanFeaturesGuard` | `analitica` (decidir tier) |
| Tope de rango | DTO validación | ≤ 366 días |
| Límite rankings | servicio | 25 filas |
| Sucursal demo | seeds | `c0000000-0000-4000-8000-000000000001` |
| Restaurante demo | seeds | `b0000000-0000-4000-8000-000000000001` |

### 11.1 DTO de query (NestJS)

```ts
// foody_backend/src/modulos/analitica/dto/filtro-analitica.dto.ts
export class FiltroAnaliticaDto {
  @IsOptional() @IsIn(['hoy','ayer','semana','mes','mes_anterior','7d','30d','rango'])
  preset?: string;
  @IsOptional() @IsDateString() desde?: string;
  @IsOptional() @IsDateString() hasta?: string;
  @IsOptional() @IsBooleanString() comparar?: string;
  @IsOptional() @IsUUID() sucursal_id?: string;
}
```

### 11.2 Mejoras futuras que afectan exactitud (documentar deuda)

- **Costo congelado en `movimientos_ingrediente`:** hoy se valoriza con `costo_unitario_actual` (aprox.). Para exactitud histórica, añadir columna `costo_al_momento` al movimiento (migración futura).
- **`pedido_items.costo_unitario` NULL en datos viejos:** considerar backfill o exponer `cobertura_costo_pct`.
- **IVA desglosado:** si se requiere análisis fiscal fino, separar IVA en `pedidos` (hoy va dentro de `total`).

---

## 12. Métricas adicionales sugeridas (valor extra)

- **Hora pico / mapa de calor** ventas por hora×día de semana.
- **Tasa de recompra** por `device_id` (clientes que vuelven).
- **Productos "ancla"** (los que más arrastran ticket).
- **Velocidad de mesa** (rotación: tiempo medio ocupada→libre).
- **% pedidos con descuento** y impacto en margen.
- **Domicilios:** ingreso por `costo_domicilio` vs costo real (si se modela).
- **Predicción simple** (media móvil) de ventas próximas — fase avanzada.
- **Ranking de meseros** por ventas e items (vía `pedidos.mesera_id` / `cajero_id`).
- **Conciliación caja vs pedidos** con desglose de diferencias por método.

---

## 13. Plan de implementación por fases

| Fase | Entregable | Depende de |
|------|------------|-----------|
| **F0** | Esta documentación (✅ este archivo) | — |
| **F1 Backend núcleo** | Módulo `analitica` + `/resumen` + `/ventas` + DTO + scope + permiso seed | reportes existente |
| **F2 Backend secciones** | `/cocinas`, `/productos`, `/inventario`, `/domiciliarios`, `/caja` | F1 |
| **F3 Backend riesgo + comparativas** | `/riesgo`, `comparar`, `/comparativa-sedes` (corporativo) | F2 |
| **F4 Flutter UI** | Pantalla + selectores + tabs + gráficas (`fl_chart`) | F1–F3 |
| **F5 Rendimiento** | Índices nuevos + cache + (opc.) vistas materializadas | F2 |
| **F6 QA** | `scripts/verificar-analitica.ps1` (KPIs vs SQL manual, scope 403, comparativa) | F1–F4 |
| **F7 Extras** | Export PDF/CSV, métricas §12, predicción | F4 |

> Empezar por **F1** con un solo endpoint (`/resumen`) reutilizando SQL de `reportes.service.ts`, validando scope dueño/admin, antes de expandir.

---

## 14. Checklist de "no fallar" (revisar en cada PR)

- [ ] Toda query lleva la `sucursal_id` ya **resuelta por `SucursalScopeService`** (admin no puede leer otra sede → 403).
- [ ] Ventas excluyen `cancelado`/`rechazado`; cuadre compara contra `movimientos_caja`.
- [ ] Fechas con `created_at < (hasta + 1 día)` y `AT TIME ZONE 'America/Bogota'`.
- [ ] Divisiones protegidas con `NULLIF(...,0)`.
- [ ] Costo usa `pedido_items.costo_unitario` (histórico), no costo actual.
- [ ] Cocina con `COALESCE(pi.cocina_id, pr.cocina_id)`.
- [ ] Respuesta `{ exito, datos, mensaje }`, montos como número.
- [ ] Flutter no calcula nada (solo formatea/pinta).
- [ ] Rango máximo validado; rankings con `LIMIT`.
- [ ] Permiso `ver_analitica` + `@RequiereModulo` correctos; comparativa de sedes solo corporativo.
- [ ] Umbrales tomados de `UMBRALES_ALERTA` (sin duplicar).

---

## 15. Referencias

- Módulo base a extender: `foody_backend/src/modulos/reportes/`
- Scope multi-sede: `foody_backend/src/core/auth/sucursal-scope.service.ts` · `docs/MULTI_SUCURSAL.md`
- Umbrales de riesgo: `foody_backend/src/modulos/alertas/alertas-riesgo.service.ts` · `docs/ALERTAS_AUTOMATICAS.md`
- Esquemas BD: `foody_supabase/migrations/004,005,006,007,009,026,*.sql` · `INFRAESTRUCTURA/esquema_maestro_bd_v3.md`
- Endpoints: `INFRAESTRUCTURA/endpoints_api_foody.md`
- Planes/tier: `docs/PLANES_SUSCRIPCION.md`
- Estado global: `docs/AVANCE_PROYECTO.md` · `docs/MODULOS_ESTADO.md`
