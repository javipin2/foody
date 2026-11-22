# Foody Cliente — Auditoría UX/UI exhaustiva (sin código)

> **Solo análisis y backlog.** No implementar hasta que el dueño priorice.  
> Referencia de calidad: rediseño operativo admin (Pedidos, Analítica, `OperacionUi`, `FoodyBreakpoints`, pills pastel, cards radio 12–14).  
> Fecha: **2026-07-31** · Flavor `cliente` · Rutas en `lib/core/rutas/app_router.dart`

**Veredicto:** el journey cliente está **funcionalmente completo** (ciudad → restaurante → menú → carrito → checkout → seguimiento) y usa la paleta Foody en CTAs. **Oleada A (CL-01…08) implementada 2026-07-31.** Queda P1/P2 (tokens OperacionUi, chips pastel, motion, etc.) frente al premium del panel staff.

**Nota global (cliente):** **6.5 / 10** post-P0 (funcional 7.5 · visual 5.5 · interacción 6.5 · coherencia con admin 5.5) — era 5.5 antes de oleada A.

---

## 1. Mapa del journey

```mermaid
flowchart TD
  Splash[/splash] --> Ciudades["/cliente ciudades"]
  Ciudades --> Restos["/ciudades/:slug/restaurantes"]
  Restos --> Sedes["/restaurantes/:id/sucursales"]
  Sedes --> Menu["/menu/:sucursalId"]
  QR["/mesa/:token o escanear"] --> Menu
  Menu --> Carrito["/carrito/:id"]
  Carrito --> Checkout["/checkout/:id"]
  Checkout --> Seg["/pedidos/:id/seguimiento"]
  Ciudades --> MisPedidos["/cliente/mis-pedidos"]
  Restos --> Stories[Stories promo ciudad]
  Menu --> StoriesSede[Stories promo sede]
```

| Ruta | Pantalla | Archivo |
|------|----------|---------|
| `/splash` | Splash | `features/splash/.../foody_splash_screen.dart` |
| `/cliente` | Ciudades | `ciudades_screen_foody.dart` |
| `/ciudades/:slug/restaurantes` | Lugares / restaurantes | `restaurantes_screen_foody.dart` |
| `/restaurantes/:id/sucursales` | Sedes | `sucursales_screen_foody.dart` |
| `/menu/:sucursalId` | Menú | `menu_screen_foody.dart` |
| sheets | Producto / combo | `detalle_producto_sheet` · `detalle_combo_sheet` |
| `/carrito/:sucursalId` | Carrito | `carrito_screen.dart` |
| `/checkout/:sucursalId` | Checkout | `checkout_screen.dart` |
| `/pedidos/:id/seguimiento` | Seguimiento | `seguimiento_pedido_screen.dart` |
| `/cliente/mis-pedidos` | Historial | `mis_pedidos_screen.dart` |
| `/cliente/escanear-qr` | Escanear QR | `escanear_qr_mesa_screen.dart` |
| `/mesa/:qrToken` | Bridge mesa | `mesa_qr_entrada_screen.dart` |
| (embebido) | Promos stories | `promociones_ciudad_stories_bar` · `promocion_story_viewer` · `promociones_stories_bar` |
| shell | Scaffold + nav | `foody_scaffold_cliente` · `cliente_navegacion_inferior` |

---

## 2. Gap transversal vs admin premium

| Patrón admin (ya hecho) | Cliente hoy |
|-------------------------|-------------|
| `OperacionUi` / `OperacionTarjeta` (fondo `#F1F5F9`, radio 12, borde slate) | **Casi no usado** — `Card`/`ListTile` Material |
| `FoodyBreakpoints` / `maxContentCliente` | Constante existe; **no aplicada** en listas/menú web |
| Pills pastel estado (`PedidoEstadoPill`) | Solo staff/analítica; mis-pedidos/seguimiento = texto plano |
| Empty / error / loading unificados (`FoodyEstadoUi`) | **Inconsistente** (unas pantallas sí, otras spinner/`$e`) |
| Jerarquía tipográfica + CTAs filled primario | Parcial (FAB menú OK; listas pobres) |
| Motion intencional (2–3 por flujo) | Casi solo splash + haptic al agregar |
| Mensajes humanos (sin Dio/500) | Varias pantallas aún muestran error crudo |

**Principio de mejora:** portar tokens y widgets del admin al cliente (adaptados a “consumidor”), no rediseñar desde cero.

---

## 3. Auditoría por pantalla

Leyenda prioridad: **P0** bloquea confianza/conversión · **P1** calidad percibida · **P2** polish.

### 3.1 Splash

| Dimensión | Qué hay | Qué falta / mejora |
|-----------|---------|-------------------|
| Visual | Gradiente marca + logo + animación scale | Tagline genérico; poco uso de acento `#FFE66D` |
| Funcional | Restore ciudad/mesa/deep-link | — |
| Interactivo | Entrada suave | Corte brusco a ciudades; sin fade al destino |

**Mejoras:** P1 copy consumidor; P2 transición coordinada splash→destino.

---

### 3.2 Shell / navegación inferior

| Dimensión | Qué hay | Qué falta / mejora |
|-----------|---------|-------------------|
| Visual | Bottom nav Inicio · Pedidos · QR | AppBar de ciudades **duplica** mismos destinos |
| Funcional | Oculta nav con sesión mesa | **No** envuelve restaurantes/menú/carrito/seguimiento → sensación de apps distintas |
| Interactivo | — | Botón **«Acceso staff»** en home cliente (fuga de marca / confusión) |

**Mejoras:**
- **P0** Quitar o esconder «Acceso staff» en flavor `cliente` (login staff solo por URL conocida).
- **P0** Un solo patrón: nav inferior **o** iconos AppBar (no ambos).
- **P1** Continuidad de scaffold (o variante ligera) en menú → carrito → seguimiento.
- **P1** Centrar contenido web con `FoodyBreakpoints.maxContentCliente`.

---

### 3.3 Ciudades (`/cliente`)

| Dimensión | Qué hay | Qué falta / mejora |
|-----------|---------|-------------------|
| Visual | Lista `Card`+`ListTile`; estados `FoodyEstadoUi` OK | Sin hero marca; subtitle genérico «Ver restaurantes»; sin atmósfera |
| Funcional | Guarda preferencia ciudad | Sin pull-to-refresh |
| Interactivo | Tap → restaurantes | Sin haptic / transición |

**Mejoras:** P0 tarjetas radio 12–14 + borde tipo `OperacionTarjeta`; P1 ilustración/gradiente suave + refresh; P2 motion entrada.

---

### 3.4 Restaurantes / «lugares» (por ciudad)

| Dimensión | Qué hay | Qué falta / mejora |
|-----------|---------|-------------------|
| Visual | Banner+logo, SearchBar, stories, cards más ricas (radio 16) | Carga = spinner crudo; vacío = texto plano; radio ≠ admin 12 |
| Funcional | Búsqueda + refresh | Error muestra `${snapshot.error}` crudo; sin badge abierto/cerrado |
| Interactivo | Stories promo | Layout logo overlay frágil (`bottom: -24`) |

**Mejoras:**
- **P0** Unificar estados con `FoodyEstadoUi` + mensajes humanos; vacío con CTA «Cambiar ciudad».
- **P1** Alinear radio/borde; grid 2 cols en tablet/web; badge sede/restaurante cerrado si API lo da.
- **P2** Skeleton shimmer.

---

### 3.5 Sucursales

| Dimensión | Qué hay | Qué falta / mejora |
|-----------|---------|-------------------|
| Visual | Lista mínima; `FoodyEstadoUi` en vacío/error | Sin CTA filled «Ver menú»; sin horario |
| Funcional | Auto-redirect si 1 sede | «Abriendo menú…» sin cancelar ni branding |
| Interactivo | Tap fila | — |

**Mejoras:** P1 cards + CTA filled; P1 skip animado si 1 sede; P2 horario/estado abierto.

---

### 3.6 Menú

| Dimensión | Qué hay | Qué falta / mejora |
|-----------|---------|-------------------|
| Visual | SliverAppBar, chips categoría, cards producto+imagen, FAB carrito, banners mesa | Fondo `#F3F4F6` hardcode; chips selected sólidos ≠ pastel admin; combos más pobres que productos |
| Funcional | Búsqueda, Realtime catálogo, horario cerrado | **`disponible == false` → return silencioso**; el + sigue visible y no hace nada (**no hay «Agotado»**) |
| Interactivo | Sheet siempre (también sin extras); haptic al agregar | FAB choca con snackbars; sin barra sticky «Ver carrito · N · $» |

**Mejoras:**
- **P0** Estado **Agotado** (opacidad, pill, + deshabilitado).
- **P0** Barra inferior sticky de carrito (patrón delivery) además o en vez de solo FAB.
- **P1** Chips pastel; unificar radio 12–14; elevar combos al layout de productos.
- **P2** Skip sheet si no hay personalización; animación al filtrar.

---

### 3.7 Sheet producto / combo

| Dimensión | Qué hay | Qué falta / mejora |
|-----------|---------|-------------------|
| Visual | Combo con imagen; producto **sin** hero imagen | Checkboxes densos; bordes Outline genéricos |
| Funcional | Toppings/bebidas/obs; preview precio | Preview math en cliente (OK mostrar; coherencia con carrito) |
| Interactivo | CTA «Agregar · $» sticky | Combo sin observaciones |

**Mejoras:** P0 imagen en producto; P1 tokens `FoodyFormulario` + pills precio; P1 obs en combo; P2 resumen selección.

---

### 3.8 Carrito

| Dimensión | Qué hay | Qué falta / mejora |
|-----------|---------|-------------------|
| Visual | Cards radio 12 + borde (cerca admin); pasos pedido | Sin thumb de imagen |
| Funcional | Qty +/−; vacío con CTA menú | **Subtotal línea = unit × qty sin toppings/bebidas** (muestra nombres de toppings pero no suma) → fricción vs checkout |
| Interactivo | Continuar checkout | Sin swipe delete |

**Mejoras:** **P0** subtotal de línea con extras (usar `LineaCarrito.subtotal` / `subtotalPara`); P1 thumb + quitar claro; P2 animación a vacío.

---

### 3.9 Checkout

| Dimensión | Qué hay | Qué falta / mejora |
|-----------|---------|-------------------|
| Visual | Flujo completo (tipo, factura, propina, pago, promo, mapa domi) | Formulario largo sin cards de sección; chips pago sin pastel |
| Funcional | Cotización zona, stock dialog, idempotencia, disclaimer «estimado» | Validación solo SnackBar (fácil de perder); sin guard carrito vacío fuerte |
| Interactivo | CTA sticky total | Propina free-text sin chips 0/10%/sugerido |

**Mejoras:** **P0** errores inline + scroll al campo; P1 secciones tipo tarjeta + chips pago/propina; P2 resumen carrito colapsable arriba.

---

### 3.10 Seguimiento

| Dimensión | Qué hay | Qué falta / mejora |
|-----------|---------|-------------------|
| Visual | Bloque estado grande; timeline; mapa domi | **No** usa `PedidoEstadoPill`; carga/error crudos |
| Funcional | Realtime+poll; cancelar; mesera; calificar; FAB mesa | Sin `FoodyPasosPedido` paso 3 |
| Interactivo | — | Timeline sin conector vertical premium; sin pulse «en camino» |

**Mejoras:** **P0** pill pastel + `FoodyEstadoUi`; P1 timeline con línea + iconos; P2 pulse en camino.

---

### 3.11 Mis pedidos

| Dimensión | Qué hay | Qué falta / mejora |
|-----------|---------|-------------------|
| Visual | ListTile + estado texto gris | Debe usar `PedidoEstadoPill`; cards sin borde 12 |
| Funcional | Merge API+local; vacío con tip | Sin filtro «En curso / Anteriores» |
| Interactivo | Tap → seguimiento | — |

**Mejoras:** **P0** pills + cards alineadas; P1 tabs filtro; P2 swipe.

---

### 3.12 Promociones (estados e interacción)

| Capa | Comportamiento hoy |
|------|-------------------|
| API cliente | Solo activas (`listarActivas` / stories ciudad) |
| Admin | Toggle activa/inactiva |
| Barras stories | Si vacío → `SizedBox.shrink` (sin loading/error) |
| Viewer | Fullscreen; **sin auto-avance**; copy de error menciona «admin»; **sin CTA «Ir al menú»**; **sin badge expirada/por vencer** |
| Checkout código | SnackBar éxito/error; sin estados ricos de promo |

**Estados que el usuario no ve:** inactiva, expirada, agotada, por vencer — solo «desapareció» o SnackBar al fallar el código.

**Mejoras:**
- **P0** Viewer: CTA a menú/sucursal; quitar copy interno «admin».
- **P1** Auto-advance + zonas tap izquierda/derecha; anillo «visto»; mostrar vigencia si API la manda.
- **P1** Loading/error visible en barra (no shrink silencioso).
- **P2** Share / «Usar en checkout» con código precargado.

---

### 3.13 Escanear QR / entrada mesa

| Dimensión | Qué hay | Qué falta / mejora |
|-----------|---------|-------------------|
| Visual | Cámara + marco acento; AppBar primario filled (rompe el resto) | Bridge mesa = spinner genérico |
| Funcional | Fallback manual; errores QR | Mensajes HTTP a veces crudos |
| Interactivo | Nav inferior compite con escaneo | Sin haptic/flash al éxito |

**Mejoras:** P0 mensajes amigables en bridge; P1 AppBar alineado + modo fullscreen al escanear; P1 haptic éxito; P2 ilustración guía web.

---

## 4. Backlog priorizado (implementación futura)

### Oleada A — P0 (confianza y conversión)

| ID | Mejora | Pantallas | Tipo |
|----|--------|-----------|------|
| CL-01 | Quitar/esconder Acceso staff; unificar nav | Shell / ciudades | Funcional + visual | ✅ 2026-07-31 |
| CL-02 | Estados carga/error/vacío unificados (`FoodyEstadoUi` + mensaje humano) | Restaurantes, seguimiento, mesa bridge | Funcional + visual | ✅ 2026-07-31 |
| CL-03 | Agotado visible (no silent fail) | Menú | Funcional + visual | ✅ 2026-07-31 |
| CL-04 | `PedidoEstadoPill` (copy cliente) | Mis pedidos, seguimiento | Visual + UX estados | ✅ 2026-07-31 |
| CL-05 | Subtotal línea con extras | Carrito | Funcional | ✅ 2026-07-31 |
| CL-06 | Barra sticky carrito en menú | Menú | Interactivo + CTA | ✅ 2026-07-31 |
| CL-07 | Story: CTA menú + copy sin «admin» | Promo viewer | Funcional + interactivo | ✅ 2026-07-31 |
| CL-08 | Checkout: errores inline | Checkout | Interactivo | ✅ 2026-07-31 |

### Oleada B — P1 (armonía con admin)

| ID | Mejora | Tipo |
|----|--------|------|
| CL-10 | Tokens cliente = adaptar `OperacionUi` (fondo, tarjeta 12–14, tipografía) | Visual / estético |
| CL-11 | `maxContentCliente` + grids restaurantes/menú | Visual / responsive |
| CL-12 | Chips pastel (categoría, pago) | Visual |
| CL-13 | Formularios `FoodyFormulario`; secciones checkout en cards | Visual + funcional |
| CL-14 | Scaffold continuo menú→seguimiento | UX ruta |
| CL-15 | Propina chips; combos = cards producto | Interactivo + visual |
| CL-16 | Promos: visto + vigencia + loading barra | Interactivo + estados |
| CL-17 | Sucursales CTA filled; skip 1 sede animado | UX |

### Oleada C — P2 (delight)

| ID | Mejora |
|----|--------|
| CL-20 | Motion: fade splash, pulse «en camino», auto-advance stories |
| CL-21 | Skeletons; swipe delete carrito |
| CL-22 | Hero imagen sheet producto; QR fullscreen polish |
| CL-23 | Mis pedidos tabs En curso / Historial |

---

## 5. Criterios de «hecho» (cuando se implemente)

1. Mismo lenguaje visual que admin operativo (radio, borde, pills, empty/error) en ≥80% de pantallas cliente.
2. Ningún producto agotado «muerto» al tap; carrito muestra total de línea = extras incluidos.
3. Cero «Acceso staff» en home; cero errores técnicos crudos en UI consumidor.
4. Stories con CTA a menú; seguimiento/mis-pedidos con pill de estado.
5. `flutter analyze` archivos tocados + smoke manual guion A de `docs/archivo/qa-sesiones/2026-07-31-f0-ui.md`.
6. Actualizar este doc (checkbox) + `FRONTEND_ROADMAP.md` + `MASTER_STATUS.md`.

---

## 6. Fuera de alcance de esta auditoría

- Cambios de backend / nuevos endpoints (salvo si un P0 exige un campo ya existente no expuesto).
- Rediseño KDS / admin (ya avanzado).
- Tema oscuro.
- Login de cliente opcional (Google) para historial en la nube; pedidos anónimos siguen por `device_id`.

---

## 7. Relación con docs existentes

| Doc | Relación |
|------|----------|
| `FRONTEND_UX_AUDITORIA.md` | Baseline más antiguo (cliente ~4/5); **este doc lo profundiza** post-rediseño admin 2026-07 |
| `FRONTEND_DESIGN_AUDIT.md` | Notas 1–10 globales; aquí backlog accionable por pantalla |
| `FRONTEND_ROADMAP.md` | Enlazar oleada A como fase «Cliente premium» cuando se priorice |
| `qa-sesiones/2026-07-31-f0-ui.md` | Guion click-through A = smoke post-implementación |

---

*Documento generado 2026-07-31 · Sin cambios de código · Listo para priorización de producto.*
