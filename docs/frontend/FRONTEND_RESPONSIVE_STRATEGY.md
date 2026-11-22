# Foody — Estrategia Responsive (Flutter)

> **Rol:** Experto Responsive Design · Flutter (mobile, tablet, desktop, web)  
> **Alcance:** 48 pantallas + widgets compartidos en `lib/features/`  
> **Última actualización:** 2026-07-30  
> **Complementa:** `FRONTEND_DESIGN_AUDIT.md`, `FRONTEND_ROADMAP.md`

---

## Resumen ejecutivo

| Aspecto | Estado actual | Nota |
|---------|---------------|:----:|
| Breakpoints unificados | ✅ `FoodyBreakpoints` (720 expand / 1100 large) | RS-20 parcialmente cerrado en operación |
| Panel admin | ✅ Mejor adaptado | Drawer &lt;720px · rail 72px · sidebar 272px |
| Operación (POS/caja/costeo) | ✅ Split desde **720** | Antes 900; alinea shell cajero |
| Cliente (menú/checkout) | 🟡 Móvil-first | Sin límite ancho en web ultrawide |
| Tablas / listas densas | ⚠️ Riesgo overflow | Tabs sin scroll, filas anchas |
| Diálogos / sheets | 🟡 Móvil OK | En desktop deberían ser paneles o diálogos anchos |
| Web | 🟡 Funcional | `usePathUrlStrategy`, QR manual, sin layout desktop cliente |

**Veredicto:** Foody es **usable en móvil y tablet operativa** gracias al panel admin y POS; **web desktop cliente y back-office CRUD** necesitan estrategia unificada.

---

## Breakpoints hoy (fragmentados)

| Origen | Móvil | Tablet | Escritorio | Uso |
|--------|-------|--------|------------|-----|
| `PanelLayoutBreakpoints` | &lt; **720** | 720–**1099** | ≥ **1100** | Panel restaurante + sidebar |
| `PanelFoodyControlScreen` | &lt; **800** | 800–1099 | ≥ **1100** rail extendido | Super admin |
| Operación (caja, POS, costeo) | &lt; **720** | — | ≥ **720** dos columnas | `FoodyBreakpoints.splitOperacion` |
| Kanban grid | — | 2 cols | ≥ **1200** → 3 cols | Grid pedidos |
| Mesas grid | 3 cols | ≥ **720** → 4 | ≥ **1100** → 5 | `FoodyBreakpoints` |
| KDS | `maxCrossAxisExtent: 360` | auto | auto | Grid fluido ✅ |

**Problema:** el mismo viewport 800px es «tablet con drawer» en admin pero «móvil apilado» en caja.

---

## Breakpoints objetivo (unificar)

Propuesta: **`lib/core/layout/foody_breakpoints.dart`**

| Token | Rango | Dispositivo típico | Comportamiento global |
|-------|-------|-------------------|------------------------|
| `compact` | &lt; 600 | Móvil portrait | 1 columna · bottom nav · drawer · sheets |
| `medium` | 600–719 | Móvil landscape / phablet | 1–2 cols · tabs scrollables |
| `expanded` | 720–1099 | Tablet | Sidebar rail 72px o drawer · 2 cols operación |
| `large` | 1100–1439 | Desktop / tablet landscape | Sidebar 272px · master-detail |
| `extraLarge` | ≥ 1440 | Monitor ancho | Contenido max-width 1280–1440 centrado |

```dart
// ponytail: un solo archivo, sin paquete responsive externo
class FoodyBreakpoints {
  static const compact = 600.0;
  static const expanded = 720.0;   // alinear PanelLayoutBreakpoints.movil
  static const large = 1100.0;
  static const extraLarge = 1440.0;
  static const maxContentCliente = 1200.0;
  static const maxContentAdmin = 1280.0;
}
```

---

## Matriz por grupo de pantallas

Leyenda:
- **Hoy** = comportamiento actual en código
- **Tablet** = cómo debería comportarse (720–1099)
- **Desktop** = cómo debería comportarse (≥1100)

### A — Cliente (`flavor cliente`)

| Pantalla | Móvil (hoy) | Tablet (debería) | Desktop / Web (debería) | Riesgos |
|----------|-------------|------------------|-------------------------|---------|
| Splash | Full bleed | Igual | Logo centrado, max 480px | Legacy asset |
| Ciudades | Lista 1 col | Grid 2 cols | Grid 3 cols, contenido max 1200px centrado | AppBar acciones apretadas |
| Restaurantes | Lista + stories | Grid 2 cols cards | Grid 3 cols; sidebar filtros opcional | Lista larga en ultrawide |
| Sucursales | Lista 1 col | Cards 2 cols | Cards 3 cols | — |
| **Menú** | SliverList 1 col, FAB carrito | Grid 2 cols productos | Grid 3–4 cols; carrito panel derecho 360px fijo | **Overflow** `trailing Row` en combos |
| Carrito | Lista ListTile | Misma + steppers grandes | 2 cols: ítems | izquierda, resumen derecha | Sin `+` cantidad |
| Checkout | 1 col scroll + bottom bar | 2 cols: form | izq, resumen sticky der | Formulario muy largo |
| Seguimiento | 1 col timeline + mapa 200px | Mapa 320px | 2 cols timeline | mapa | OK móvil |
| Mis pedidos | Lista | Cards 2 cols | Tabla simple o cards 3 cols | — |
| Mesa QR / Escanear | 1 col; web = input manual | Igual | QR grande centrado | Web sin cámara OK |

**Web cliente:** envolver body en `Center` + `ConstrainedBox(maxWidth: 1200)` excepto mapas/full-bleed.

---

### B — Auth y onboarding

| Pantalla | Móvil | Tablet | Desktop | Riesgos |
|----------|-------|--------|---------|---------|
| Login staff | Card max 420 centrado ✅ | Igual | Igual + fondo split marca | Bien implementado |
| Registro restaurante | Scroll 1 col | 2 cols campos | Form max 640px centrado | Form largo |
| Registro / login domi | 1 col básico | Igual login staff | Igual | Sin maxWidth |

---

### C — Shell admin (`panel_restaurante`)

| Elemento | Móvil (&lt;720) | Tablet (720–1099) | Desktop (≥1100) | Riesgos |
|----------|----------------|-------------------|-----------------|---------|
| Navegación | Drawer hamburger | Sidebar **72px** iconos | Sidebar **272px** labels | ✅ Referencia |
| AppBar | Título + sucursal dropdown + 2 icons | Igual | Sucursal en sidebar; menos actions | **Overflow** dropdown + chip en &lt;360px |
| Contenido módulo | 100% ancho | 100% | max-width opcional 1280 en CRUD | Módulos heterogéneos |

**Debería:** en desktop, selector sucursal baja al sidebar; AppBar solo título + búsqueda global.

---

### D — Operación (POS, mesas, pedidos, KDS)

| Pantalla / widget | Móvil | Tablet | Desktop | Riesgos |
|-------------------|-------|--------|---------|---------|
| **Panel cajero/mesero** | Bottom `NavigationBar` 3/2 tabs | Igual o tabs top | Tabs top + más espacio; sin bottom nav | OK móvil |
| **POS cajero** | Menú arriba, carrito fijo abajo | Split 50/50 desde **720** ✅ | Menú + carrito 300px | RS-20 |
| **Mesas grid** | 2–3 columnas | 4 cols ≥720 | 5 cols ≥1100 | RS-22 parcial |
| **Kanban pedidos** | Scroll horizontal columnas 300px | Columnas visibles 3–4 | Todas las columnas sin scroll; altura completa | Stats chips: scroll horizontal ✅ |
| **Kanban grid alt.** | 2 cols | 2 cols | 3 cols ≥1200 | — |
| **KDS** | Grid max 360px ✅ | Más columnas auto | Pantalla completa, 4+ tickets | Mejor responsive del app |
| **Caja admin** | Lista apilada | 2 cols ≥720 ✅ | Principal + lateral 280px fijo | RS-20 |
| **Mesa pedidos sheet** | Banner 1 línea · split en avanzadas · sheet ~82% | Banner completo + split visible | Igual tablet | Densidad móvil 2026-07-30 |

**Hecho:** umbral split operación = **720** (`lib/core/layout/foody_breakpoints.dart`).

---

### E — Back-office CRUD (dentro del panel)

| Pantalla | Móvil | Tablet | Desktop | Riesgos |
|----------|-------|--------|---------|---------|
| **Inventario** | 5 **TabBar** fijas | Tabs `isScrollable` | Sub-nav lateral + 1 vista | **Overflow tabs** en &lt;400px |
| **Menú admin** | 4 tabs con contadores | Scroll tabs | Master-detail producto | Tabs largas «Productos (N)» |
| **Analítica** | 8–9 tabs scrollables ✅ | Igual | Nav lateral + gráfico ancho | Charts estrechos en móvil |
| **Reportes** | 4 tabs | Scroll | Export panel derecho | — |
| **Facturación** | 2 tabs; preview HTML | Igual | Preview 2 cols | HTML sin constrain |
| **Usuarios** | Lista; diálogo 360px | Tabla | Tabla completa + drawer detalle | Diálogo estrecho en desktop |
| **Cocinas / zonas / horarios** | 1 col forms | 2 cols forms | Form + mapa lado a lado | Mapas pequeños |
| **Costeo** | Lista → detalle navegación ✅ | Master-detail ≥900 ✅ | Panel 320 + detalle | Bien resuelto |
| **Promociones / alertas** | Lista 1 col | 2 cols | Tabla + preview | — |
| **Dashboard** | KPI grid 2 cols | 4 cols &gt;700 ✅ | 4–6 cols + gráficos anchos | KPIs no responsive &lt;700 |

**Listas tipo tabla (inventario movimientos, usuarios):** filas con 4–6 datos → en móvil deben ser **cards**, no fila horizontal.

---

### F — Super admin (`foody-control`)

| Pantalla | Móvil (&lt;800) | Tablet | Desktop (≥1100) | Riesgos |
|----------|----------------|--------|-----------------|---------|
| Shell | Drawer | Rail 72px | Rail 220px | Breakpoint **800** ≠ panel 720 |
| Secciones (7) | 1 col densas | 2 cols donde aplique | Tablas anchas + filtros toolbar | Diálogos 400px fijos |

**Debería:** alinear breakpoint móvil a **720** como panel restaurante.

---

### G — Domiciliario campo

| Pantalla | Móvil | Tablet | Desktop | Riesgos |
|----------|-------|--------|---------|---------|
| Dashboard planta | 3 tabs | Mapa más alto | No aplica (móvil) | — |
| Repartidor independiente | 1 col + GPS chip | Igual | N/A | — |
| Documentos | Upload lista | Igual | N/A | — |

---

## Problemas detectados (inventario técnico)

### Overflow / widgets que se rompen

| ID | Ubicación | Problema | Severidad |
|----|-----------|----------|-----------|
| R-01 | `menu_screen_foody.dart` | ~~`ListTile.trailing: Row` precio + IconButton~~ → precio en subtitle; trailing solo `+` | ✅ 2026-07-26 |
| R-02 | `inventario_admin_screen.dart` | ~~TabBar sin scroll~~ → `isScrollable: true` | ✅ |
| R-03 | `menu_admin_screen.dart` | ~~Tabs largas~~ → `isScrollable` + header ⋮ &lt;400px | ✅ |
| R-04 | `panel_restaurante_screen.dart` | AppBar: dropdown sucursal + chip + 2 icons | Media (mitigado en móvil) |
| R-05 | `pedidos_kanban_widget.dart` | Stats + `FoodyScrollHorizontalFade` | Baja |
| R-06 | Cliente web ultrawide | Sin `maxWidth` → menú lista infinita en 4K | Media UX |
| R-07 | `facturacion_admin_screen.dart` | Preview + TabBar `isScrollable` | Baja |
| R-08 | `inventario` movimientos | ~~fila densa~~ → card apilada (fecha en subtitle) | ✅ 2026-07-26 |

### Tablas demasiado grandes

No hay `DataTable` nativo; las «tablas» son `ListTile`/`Row` con muchos `Text`. Afectan:

- Inventario → movimientos, conteo
- Usuarios → lista permisos
- Reportes → históricos
- Foody Control → restaurantes, suscripciones

**Patrón objetivo:** `FoodyAdaptiveList` → card en `compact`, fila en `large`.

### Diálogos incorrectos por viewport

| Patrón actual | Móvil | Desktop (debería) |
|---------------|-------|-------------------|
| `AlertDialog` ancho fijo 360–420 | OK | `Dialog` con `maxWidth: 560`, centrado |
| `showModalBottomSheet` 88% altura | OK | `showAdaptiveDialog` o panel lateral |
| Formularios insumo/producto | Sheet | Side panel 480px en `large` |

Archivos con diálogos fijos: `mesas_grid_widget.dart` (24), `catalogo/menu_admin`, `inventario`, `caja`, `panel_foody_control`.

### Menús poco adaptables

| Menú | Problema | Fix |
|------|----------|-----|
| Sidebar admin 20+ ítems | Solo drawer/rail; sin búsqueda | Command palette en desktop |
| TabBar inventario (5) | No scroll | `isScrollable: true` o sub-nav |
| TabBar analítica (9) | Scroll OK pero abruma móvil | Drawer métricas en compact |
| Bottom nav cajero | OK móvil | Ocultar en `large` si hay sidebar |
| Categorías menú cliente | `SingleChildScrollView` horizontal ✅ | — |

---

## Comportamiento Web específico

| Tema | Estado | Acción |
|------|--------|--------|
| URLs limpias | ✅ `usePathUrlStrategy` | — |
| QR mesa | ✅ Input manual en web | Mantener |
| ViewInsets teclado | ✅ Workaround en `main.dart` | — |
| FCM | ❌ No en web | Esperado |
| Geolocalización checkout | Depende navegador | Mensaje claro si denegado |
| **Ancho infinito cliente** | ❌ | `maxContentCliente` 1200px |
| **Hover / cursor** | No implementado | `MouseRegion` en cards desktop |
| **Teclado shortcuts** | No | `/` búsqueda admin en Fase 4 |

---

## Estrategia responsive completa

### 1. Fundación (Fase 7 — prioridad P0)

| ID | Tarea | Archivos |
|----|-------|----------|
| RS-01 | Crear `FoodyBreakpoints` + extension `context.foodyLayout` | `lib/core/layout/` |
| RS-02 | Widget `FoodyAdaptiveContainer` (maxWidth cliente/admin) | mismo |
| RS-03 | `FoodyAdaptiveDialog.show()` — sheet móvil, dialog desktop | `lib/core/layout/` |
| RS-04 | Unificar breakpoints panel control 800→720 | `panel_foody_control_screen.dart` |
| RS-05 | TabBar global: `isScrollable` donde tabs &gt; 4 o texto largo | inventario, menu_admin, reportes |

### 2. Cliente (P1)

| ID | Tarea |
|----|-------|
| RS-10 | Menú: grid adaptativo (`crossAxisCount` por breakpoint) |
| RS-11 | Menú: split carrito lateral en `large` (web) |
| RS-12 | Checkout: 2 columnas resumen + form en ≥900px |
| RS-13 | Restaurantes: grid 2/3 columnas |
| RS-14 | Fix overflow combos (`trailing` → `Column` o `LayoutBuilder`) |

### 3. Operación staff (P1)

| ID | Tarea |
|----|-------|
| RS-20 | Alinear split POS/caja a sidebar visible (720 vs 900) | ✅ 2026-07-30 `FoodyBreakpoints` |
| RS-21 | Kanban desktop: columnas en `Row` `Expanded` sin scroll horizontal |
| RS-22 | Mesas: `crossAxisCount` 3/4/5/6 por breakpoint |
| RS-23 | Mesa sheet → `FoodyAdaptiveDialog` |

### 4. Admin CRUD (P2)

| ID | Tarea |
|----|-------|
| RS-30 | Inventario: sub-nav drawer en compact, tabs solo en medium+ |
| RS-31 | Listas densas → card layout &lt;600px |
| RS-32 | Analítica: sidebar métricas en desktop |
| RS-33 | Dashboard: `LayoutBuilder` unificado 2/4/6 columnas |

### 5. Shell y navegación (P2)

| ID | Tarea |
|----|-------|
| RS-40 | AppBar admin: acciones responsivas (`PopupMenu` en compact) |
| RS-41 | Cajero/mesero: ocultar bottom nav si width ≥1100 (raro pero tablet landscape) |
| RS-42 | Contenido admin max 1280px centrado en ultrawide |

---

## Patrones de implementación (copiar/pegar)

### Grid adaptativo

```dart
int columnasGrid(double w) {
  if (w >= FoodyBreakpoints.extraLarge) return 6;
  if (w >= FoodyBreakpoints.large) return 5;
  if (w >= FoodyBreakpoints.expanded) return 4;
  if (w >= FoodyBreakpoints.compact) return 3;
  return 2;
}
```

### Master-detail operación

```dart
LayoutBuilder(
  builder: (context, c) {
    final split = c.maxWidth >= 900; // o 720 si dentro de panel con sidebar
    if (split) return Row(children: [Expanded(child: maestro), SizedBox(width: 320, child: detalle)]);
    return Column(children: [Expanded(child: maestro), SizedBox(height: 280, child: detalle)]);
  },
)
```

### Contenedor web cliente

```dart
FoodyAdaptiveContainer(
  maxWidth: FoodyBreakpoints.maxContentCliente,
  child: child,
)
```

---

## Calificación responsive por grupo

| Grupo | Móvil | Tablet | Desktop/Web | Media |
|-------|:-----:|:------:|:-------------:|:-----:|
| Cliente | 7 | 5 | 4 | **5.3** |
| Auth | 8 | 8 | 8 | **8.0** |
| Shell admin | 8 | 8 | 7 | **7.7** |
| Operación | 7 | 7 | 6 | **6.7** |
| Back-office | 5 | 6 | 6 | **5.7** |
| Super admin | 6 | 7 | 6 | **6.3** |
| Domiciliario | 7 | 7 | N/A | **7.0** |
| **Global** | **6.9** | **6.9** | **5.8** | **6.5** |

---

## Orden de ejecución recomendado

1. **RS-01…05** — fundación (1–2 días, alto impacto bajo riesgo)
2. **RS-02 + RS-14** — web cliente + fix overflow combos
3. **RS-05 + RS-30** — tabs inventario (quick win)
4. **RS-10…13** — cliente desktop
5. **RS-20…23** — operación desktop
6. Resto P2 con Design System Fase 6

---

## Verificación responsive

```powershell
# Chrome DevTools: iPhone SE, iPad, Desktop 1920
.\scripts\flutter-run-flavor.ps1 -Flavor cliente -Device chrome -WebPort 8081
.\scripts\flutter-run-flavor.ps1 -Flavor equipo -Device chrome -WebPort 8080
```

Checklist manual ([`../CHECKLIST_QA_ROLES.md`](../CHECKLIST_QA_ROLES.md) ampliar):

- [ ] 320px ancho: sin overflow amarillo/negro
- [ ] 768px: sidebar rail visible staff
- [ ] 1280px: panel admin usable
- [ ] 1920px: cliente no estira infinito

Script futuro: `scripts/verificar-responsive.ps1` (golden tests o integration con tamaños fijos).

---

## Relación con roadmap

| Doc | Fase |
|-----|------|
| `FRONTEND_ROADMAP.md` | **Fase 7** — Responsive |
| `FRONTEND_DESIGN_AUDIT.md` | Visual + responsive van juntos en cliente |
| `FRONTEND_INSTRUCCIONES.md` | INS-006 |

---

*Próxima revisión: tras RS-01 y RS-05 — re-evaluar overflow en inventario y menú.*
