# Foody — Auditoría visual / Product Design (Flutter)

> **Rol:** Senior Product Designer · Flutter  
> **Alcance:** 40 pantallas en `lib/features/` + widgets compartidos  
> **Última actualización:** 2026-07-02  
> **Referencias benchmark:** Uber Eats · Toast POS · Square · Shopify · Rappi · Notion · Linear

---

## Resumen ejecutivo

| Dimensión | Nota global | Veredicto |
|-----------|:-----------:|-----------|
| Jerarquía visual | 5.5/10 | Mezcla 3 lenguajes (cliente delivery, operación slate, Material genérico) |
| Espaciado | 5/10 | Sin escala 4/8/16/24 unificada; padding ad hoc por pantalla |
| Tipografía | 5/10 | Poppins+Inter definidos en tema pero **no aplicados** en la mayoría de `TextStyle` inline |
| Colores / marca | 6/10 | Paleta Foody existe; **~90+ hex sueltos** compiten con `ColoresFoody` |
| Contraste | 6.5/10 | KDS/sidebar bien; cliente gris sobre gris en secundarios |
| Componentes | 5/10 | `OperacionUi` solo en ~5 módulos operativos; resto `Card`+`ListTile` crudo |
| Consistencia | **4.5/10** | Principal deuda visual del producto |
| Identidad Foody | 5/10 | Naranja presente pero splash/logo legacy «Tu Cancha Fácil» |

**Nota media pantallas:** **5.8 / 10** — Funcional y usable en operación; **no compite visualmente** con Uber Eats/Rappi en cliente ni con Toast/Linear en admin.

---

## Diagnóstico del sistema de diseño actual

### Lo que existe

| Activo | Ubicación | Estado |
|--------|-----------|--------|
| Paleta marca | `lib/core/constantes/colores_foody.dart` | ✅ 9 tokens |
| Tema M3 | `lib/core/tema/tema_foody.dart` | 🟡 Mínimo (AppBar naranja, 2 estilos texto) |
| Tokens operación | `operacion_ui.dart` | ✅ Slate + chips estado (estilo Linear/Toast) |
| Sidebar admin | `panel_sidebar_nav.dart` | ✅ Oscuro `#0F172A` (Notion/Linear) |
| Sidebar super | `foody_control_ui.dart` | 🟡 Similar pero duplicado |

### Problemas transversales

1. **Dos productos visuales en uno**
   - **Cliente:** fondos `#F3F4F6`, botones `#111624`, chips Material — cercano a Rappi/Uber pero **sin** fotografía hero, sin bottom sheet estándar, sin tipografía de marca.
   - **Staff:** slate oscuro + tarjetas blancas 12px radius — cercano a Toast/Linear en KDS/sidebar.
   - **Admin CRUD:** Material 2018 (`Card`, `ListTile`, `TabBar` naranja) — cercano a **panel genérico**, no Shopify.

2. **Tema global no gobierna**
   - `TemaFoody` no define: `elevatedButtonTheme`, `inputDecorationTheme`, `cardTheme`, `chipTheme`, `tabBarTheme`, `snackBarTheme`, espaciado.
   - Casi todo es `TextStyle(fontSize: 12, color: Colors.grey.shade600)` inline.

3. **Tipografía a medias**
   - `GoogleFonts` solo en `textTheme` base; pantallas no usan `Theme.of(context).textTheme`.
   - Pesos mezclados: `w600`, `w700`, `w800` sin escala (display / title / body / caption).

4. **Identidad diluida**
   - Splash: `assets/tucanchafacil.png` + fondo `fondo2.jpg` legacy.
   - Paquete `reserva_canchas` (deuda P3-05).
   - Secundario `#2EC4B6` y acento `#FFE66D` **casi ausentes** en UI.

5. **Diseños anticuados detectados**
   - `ListTile` + `Card` plano para listas cliente (2019).
   - `AppBar` naranja sólido en todo el flujo cliente (no estilo Uber Eats flat/blanco).
   - Formularios checkout largos sin secciones visuales (no Square/Shopify checkout).
   - Tab bars con 5–9 tabs sin sub-navegación (Inventario, Analítica).
   - Errores con texto técnico y bloques de párrafo (no empty state ilustrado).

6. **Exceso de texto**
   - Checkout, caja, mesa cobro, registro restaurante, super admin.
   - Subtítulos API (`slug`) visibles al usuario en ciudades.

7. **Mala alineación / distribución**
   - Dashboard: KPIs + gráficos sin grid responsive unificado.
   - Inventario: tablas anchas en móvil con scroll horizontal implícito.
   - Cliente carrito: trailing `Row` estrecho (íconos comprimidos).

---

## Benchmark — qué tomar de cada referencia

| Referencia | Aplicar en Foody | Pantallas objetivo |
|------------|------------------|-------------------|
| **Uber Eats / Rappi** | App bar blanca, categorías chip scroll, imágenes producto 16:9, carrito sticky inferior, sheets para modifiers | Menú, carrito, checkout |
| **Toast POS** | Botones grandes táctiles, estados color codificados, densidad alta pero **una acción primaria** por vista | Cajero, mesero, mesas, KDS |
| **Square** | Checkout en pasos, resumen pedido sticky, tipografía clara montos | Checkout, cobro mesa |
| **Shopify Admin** | Tablas limpias, filtros en toolbar, páginas con un CTA primario | Menú admin, inventario, usuarios |
| **Notion / Linear** | Sidebar oscuro, contenido blanco, bordes `1px #E2E8F0`, headers 16px semibold | Panel admin shell, listados |
| **Linear** | Chips estado pastel, barra acento 3px en tarjetas, spacing 12/16 | Kanban, mesas, alertas |

---

## Calificación por pantalla (1–10)

Escala: **1–4** anticuado · **5–6** aceptable MVP · **7–8** moderno usable · **9–10** referencia industria

### Cliente (`flavor cliente`)

| # | Pantalla | Archivo | Nota | Problemas clave | Mejora prioritaria |
|---|----------|---------|:----:|-----------------|-------------------|
| 1 | Splash | `foody_splash_screen.dart` | **5** | Logo legacy, tipografía genérica | Logo Foody + gradiente marca |
| 2 | Ciudades | `ciudades_screen_foody.dart` | **5** | ListTile plano, slug visible, AppBar naranja | Cards con imagen ciudad, ocultar slug |
| 3 | Restaurantes | `restaurantes_screen_foody.dart` | **6** | Stories bien; cards desiguales | Grid 2 col, rating/distancia, foto hero |
| 4 | Sucursales | `sucursales_screen_foody.dart` | **5** | Lista utilitaria | Card sede + ETA + «Abierto» chip |
| 5 | Menú | `menu_screen_foody.dart` | **7** | Mejor pantalla cliente; hex sueltos; error crudo | Unificar tokens; imágenes; sheet producto |
| 6 | Carrito | `carrito_screen.dart` | **4** | Mínima; sin +; ListTile 2019 | Barra inferior sticky Square; steppers |
| 7 | Checkout | `checkout_screen.dart` | **5** | Formulario largo; factura siempre visible | Steps 1-2-3; secciones colapsables |
| 8 | Seguimiento | `seguimiento_pedido_screen.dart` | **7** | Timeline claro; mezcla estilos | Ilustración estado; mapa domi más grande |
| 9 | Mis pedidos | `mis_pedidos_screen.dart` | **5** | Lista básica | Cards con reorder CTA (Rappi) |
| 10 | Entrada mesa QR | `mesa_qr_entrada_screen.dart` | **6** | Funcional | Animación bienvenida mesa |
| 11 | Escanear QR | `escanear_qr_mesa_screen.dart` | **6** | Estándar cámara | Marco escaneo branded |

**Media cliente: 5.7**

---

### Auth / onboarding

| # | Pantalla | Archivo | Nota | Problemas | Mejora |
|---|----------|---------|:----:|-----------|--------|
| 12 | Login staff | `staff_login_screen.dart` | **7** | Animaciones OK; split visual cliente/staff | Card centrada Linear; logo Foody |
| 13 | Registro restaurante | `restaurante_registro_screen.dart` | **6** | Form largo | Wizard 3 pasos Shopify |
| 14 | Registro domi | `domiciliario_registro_screen.dart` | **5** | Form estándar | Mismos tokens |
| 15 | Login domi | `domiciliario_independiente_login_screen.dart` | **5** | Básico | Igualar staff login |
| 16 | Espera domi | `domiciliario_registro_screen.dart` | **5** | Texto estático | Estado ilustrado |

**Media auth: 5.6**

---

### Admin — shell y operación

| # | Pantalla / módulo | Archivo | Nota | Problemas | Mejora |
|---|-------------------|---------|:----:|-----------|--------|
| 17 | Panel restaurante (shell) | `panel_restaurante_screen.dart` | **6** | Buen sidebar; contenido heterogéneo | Fondo `OperacionUi.fondoPagina` en todos los módulos |
| 18 | Sidebar nav | `panel_sidebar_nav.dart` | **8** | Referencia interna | Extraer a design system |
| 19 | Dashboard resumen | `dashboard_resumen_widget.dart` | **6** | KPIs no clicables | Cards métricas Shopify |
| 20 | Dashboard gráficos | `dashboard_graficos_widget.dart` | **6** | Charts OK; leyendas pequeñas | Paleta chart = marca |
| 21 | Dashboard consolidado | `dashboard_consolidado_widget.dart` | **6** | Denso | Grid 2×2 responsive |
| 22 | Pedidos kanban | `pedidos_kanban_widget.dart` | **7** | Chips OperacionUi | Columnas más anchas; drag handle |
| 23 | Mesas grid | `mesas_grid_widget.dart` | **7** | Operativo Toast-like | Unificar con mesero/cajero |
| 24 | KDS cocina | `kds_screen.dart` | **8** | Mejor pantalla staff | Tipografía mono para tiempos |
| 25 | POS cajero | `pedido_cajero_screen.dart` | **6** | OperacionUi parcial | Teclado numérico Square |
| 26 | Panel cajero | `panel_cajero_screen.dart` | **6** | Tabs funcionales | Tab bar inferior móvil Toast |
| 27 | Panel mesero | `panel_mesero_screen.dart` | **6** | Similar cajero | Misma shell operación |
| 28 | Mesa pedidos sheet | `mesa_pedidos_sheet.dart` | **6** | Mucha info | Tabs dentro sheet |

**Media operación: 6.6**

---

### Admin — back-office (CRUD)

| # | Pantalla | Archivo | Nota | Problemas | Mejora |
|---|----------|---------|:----:|-----------|--------|
| 29 | Menú admin | `menu_admin_screen.dart` | **5** | Tabla densa | Shopify table + drawer detalle |
| 30 | Inventario | `inventario_admin_screen.dart` | **4** | 5 tabs; abrumador | Sub-nav lateral; 1 tab visible |
| 31 | Caja | `caja_admin_screen.dart` | **6** | Mezcla OperacionUi | Resumen caja hero card |
| 32 | Cocinas config | `cocinas_admin_screen.dart` | **5** | CRUD básico | Lista + empty states |
| 33 | Analítica | `analitica_screen.dart` | **6** | 8–9 tabs | Dropdown métricas; menos tabs |
| 34 | Reportes | `reportes_admin_screen.dart` | **5** | Utilitario | Cards descargables |
| 35 | Facturación | `facturacion_admin_screen.dart` | **4** | Borrador HTML crudo | Preview card; DIAN pausada |
| 36 | Usuarios | `usuarios_admin_screen.dart` | **5** | Tabla | Avatar + rol chip |
| 37 | Alertas | `alertas_admin_screen.dart` | **5** | Lista | Severidad color + icono |
| 38 | Promociones | `promociones_admin_screen.dart` | **6** | Stories creativo | Mantener; pulir forms |
| 39 | Zonas domicilio | `zonas_admin_screen.dart` | **5** | Mapa+form | Mapa full bleed |
| 40 | Horarios | `horarios_admin_screen.dart` | **5** | Grid horas | Week view calendario |
| 41 | Sucursales | `sucursales_admin_screen.dart` | **5** | Lista | Cards sede |
| 42 | Costeo | `costos_margenes_screen.dart` | **6** | `costeo_ui_bloques` | Extender bloques a inventario |
| 43 | Domiciliarios admin | `domiciliarios_admin_screen.dart` | **5** | Denso | Kanban asignación |
| 44 | Mejorar plan | `mejorar_plan_screen.dart` | **7** | Paywall claro | Referencia para otros módulos |

**Media back-office: 5.3**

---

### Super admin y domi campo

| # | Pantalla | Archivo | Nota | Problemas | Mejora |
|---|----------|---------|:----:|-----------|--------|
| 45 | Foody Control | `panel_foody_control_screen.dart` | **6** | 7 secciones densas | Wizard restaurante |
| 46 | Dashboard domi planta | `dashboard_domiciliario_screen.dart` | **6** | Operativo | Mapa más prominente |
| 47 | Dashboard repartidor | `dashboard_domiciliario_independiente_screen.dart` | **6** | GPS chip OK | Bottom nav 3 ítems |
| 48 | Documentos domi | `domiciliario_documentos_screen.dart` | **5** | Upload básico | Progress steps |

**Media super/domi: 5.8**

---

## Tabla resumen por grupo

| Grupo | Pantallas | Media |
|-------|----------:|------:|
| Cliente | 11 | **5.7** |
| Auth / onboarding | 5 | **5.6** |
| Operación (POS/KDS/mesas) | 12 | **6.6** |
| Back-office CRUD | 16 | **5.3** |
| Super / domi campo | 4 | **5.8** |
| **Total** | **48** | **5.8** |

---

## Propuesta: Design System Foody (Fase 6)

### Tokens a formalizar (`lib/core/tema/`)

```
Espaciado: 4, 8, 12, 16, 24, 32, 48
Radius: 8 (chip), 12 (card), 16 (sheet), 24 (modal)
Tipografía:
  display: Poppins 28/32 w700
  title:   Poppins 18/22 w600
  body:    Inter 14/20 w400
  caption: Inter 12/16 w400 muted
Sombras: 0 1px 3px rgba(15,23,42,.08) — estilo Linear
```

### Componentes a extraer (1 por patrón)

| Componente | Inspiración | Reemplaza |
|------------|-------------|-----------|
| `FoodyScaffoldCliente` | Uber Eats | AppBar blanca + body gris |
| `FoodyProductCard` | Rappi | ListTile menú |
| `FoodyStickyBottomBar` | Square | FAB + bottom checkout |
| `FoodyOperacionScaffold` | Toast | Fondo slate + header |
| `FoodyDataTable` | Shopify | Listas admin |
| `FoodyEmptyState` | Linear | Texto centrado |
| `FoodyStatusChip` | OperacionUi | Chips ad hoc |
| `FoodySectionHeader` | Notion | Títulos inline |

### Roadmap visual (prioridad)

| ID | Mejora | Impacto | Esfuerzo |
|----|--------|---------|----------|
| DS-01 | Extender `TemaFoody` (buttons, inputs, cards, chips) | Alto | M |
| DS-02 | Cliente: menú + carrito + checkout (Uber/Square) | Alto | L |
| DS-03 | Migrar admin CRUD a `OperacionUi` + `FoodyDataTable` | Alto | L |
| DS-04 | Splash + logo Foody (quitar legacy) | Medio | S |
| DS-05 | Unificar fondos cliente (`ColoresFoody` vs `#F3F4F6`) | Medio | S |
| DS-06 | Empty/error states ilustrados | Medio | M |
| DS-07 | Usar secundario/acento en CTAs secundarios | Bajo | S |
| DS-08 | Tab bars → sub-nav o drawer (inventario/analítica) | Alto | M |

Detalle en **`FRONTEND_ROADMAP.md` Fase 6**.

---

## Pantallas referencia (objetivo interno 8+/10)

Usar como **plantilla** al rediseñar otras:

1. **KDS** (`kds_screen.dart`) — contraste, foco, acción clara  
2. **Sidebar admin** (`panel_sidebar_nav.dart`) — jerarquía, oscuro, compacto  
3. **Menú cliente** (`menu_screen_foody.dart`) — base Rappi (falta pulir)  
4. **Kanban pedidos** — chips y tarjetas OperacionUi  

---

## Relación con otros docs

| Doc | Relación |
|-----|----------|
| `FRONTEND_UX_AUDITORIA.md` | Fricción flujo (complementa esta auditoría visual) |
| `FRONTEND_FRICTION_FIXES.md` | Quick fixes UX |
| `FRONTEND_ROADMAP.md` | Fases implementación |
| `FRONTEND_INSTRUCCIONES.md` | INS-005 auditoría visual |

---

*Próxima revisión: tras Fase 6 DS-01 (tema extendido) — recalificar pantallas cliente y admin CRUD.*
