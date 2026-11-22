# Foody — Auditoría de producto SaaS (Head of Product)

> **Rol:** Head of Product · empresa SaaS B2B restaurantes  
> **Premisa:** Foody se vende a restaurantes profesionales (USD 80–300/mes por sede)  
> **Alcance:** 48 pantallas · 6 roles · comparación con productos comerciales reales  
> **Última actualización:** 2026-07-02  
> **Referencias comerciales:** Toast · Square · Lightspeed · TouchBistro · Uber Eats · Rappi · Shopify Admin · Linear

---

## Resumen ejecutivo — ¿Vendería esto hoy?

| Pregunta | Respuesta | Nota |
|----------|-----------|:----:|
| ¿Se ve profesional? | **Parcialmente** — operación (KDS, sidebar) sí; cliente y CRUD no | **5.5/10** |
| ¿Genera confianza? | **Limitado** — logo legacy, errores técnicos, factura HTML cruda | **5/10** |
| ¿Se siente moderna? | **En tiras** — 3 lenguajes visuales distintos en una app | **5.5/10** |
| ¿Parece premium? | **No aún** — falta coherencia, empty states, onboarding guiado | **4.5/10** |
| ¿Compite visualmente? | **Operación ~Toast lite** · **Cliente ~MVP 2019** · **Admin ~panel genérico** | **5/10** |

### Calificación global como producto SaaS

| Comparación | Nota | Comentario |
|-------------|:----:|------------|
| vs **Toast / Lightspeed** (POS + back-office) | **4.5/10** | Funcionalidad backend cercana en piloto; **presentación y flujos** no justifican precio enterprise |
| vs **Square** (simplicidad cobro) | **5.5/10** | Cobro mesa/POS existe pero **demasiados pasos** y UI heterogénea |
| vs **Uber Eats / Rappi** (cliente final) | **5/10** | Menú aceptable; carrito/checkout **por debajo** del estándar delivery 2024+ |
| vs **Shopify Admin** (SaaS B2B) | **4/10** | CRUD sin jerarquía, sin búsqueda global, tabs infinitos |
| **Promedio producto SaaS vendible** | **5.2/10** | **MVP operativo serio**, no producto premium listo para demo comercial a cadenas |

**Veredicto Head of Product:** Un gerente de restaurante **usaría** Foody en cocina y caja tras capacitación. Un **dueño que paga** compararía con Toast en la primera demo y diría: *«tiene todo, pero no se siente igual de pulido»*. Para cerrar deals con cadenas (10+ sedes) hace falta subir a **7.5+** en confianza visual y **8+** en operación diaria.

---

## Lo que ya vende el producto (ventajas reales)

| Fortaleza | Evidencia | Mensaje comercial |
|-----------|-----------|-------------------|
| **Cobertura funcional** | POS, mesas, KDS, caja, inventario, multi-sucursal, domi | «Todo en uno» vs stack fragmentado |
| **KDS** | Mejor pantalla del producto (8/10) | «Cocina sin fricción» |
| **Sidebar admin** | Estilo Linear/Notion (8/10) | «Panel serio» |
| **Multi-rol** | Cajero, mesero, cocina, domi, super | «Un login, el rol correcto» |
| **Backend robusto** | E2E, transacciones, auditoría | Confianza **técnica** (invisible en UI) |

---

## Detección transversal (amateur → premium)

### Elementos amateur

| # | Hallazgo | Pantallas | Impacto confianza |
|---|----------|-----------|-------------------|
| A1 | Logo **Tu Cancha Fácil** en splash | Splash | 🔴 Primera impresión |
| A2 | `slug` de ciudad visible al usuario | Ciudades | 🟠 Parece panel dev |
| A3 | Empty states = `Text('Sin pedidos')` centrado | Domi, menú filtro, listas | 🟠 Abandono percibido |
| A4 | Errores HTTP / técnicos al cliente | Checkout, menú | 🔴 Pérdida confianza pago |
| A5 | Facturación: preview HTML crudo | Facturación admin | 🔴 «Beta interna» |
| A6 | Carrito sin steppers +/− | Carrito | 🟠 Peor que cualquier delivery |
| A7 | 5–9 tabs horizontales sin scroll | Inventario, analítica | 🟠 Abrumador en tablet |
| A8 | Mismo módulo, distinto look (Material vs OperacionUi) | Admin CRUD vs KDS | 🟠 «Dos productos pegados» |

### Diseños anticuados

- `ListTile` + `Card` plano (cliente 2019).
- AppBar naranja sólida en todo el flujo cliente (no flat/blanco tipo Uber).
- Formularios monolíticos (checkout, registro restaurante, super admin).
- Tablas admin sin toolbar de filtros (Shopify 2018).

### Pantallas vacías / estados muertos

| Pantalla | Estado actual | Debería mostrar |
|----------|---------------|-----------------|
| Mis pedidos (0) | Texto plano | Ilustración + «Explorar restaurantes» CTA |
| Domi sin ofertas | `Text('Sin pedidos')` | Mapa + «Activa ubicación» + tips |
| Menú filtro vacío | Texto gris | Sugerir quitar filtro + populares |
| Inventario sin insumos | Spinner → lista vacía | Wizard «Crear primer insumo» |
| Alertas (0) | Lista vacía | «Todo en orden» con check verde |
| Reportes | Utilitario | Cards descargables con preview |

### Experiencias lentas (percepción)

| Causa | Efecto usuario | Prioridad |
|-------|----------------|-----------|
| Rebuild grid mesas cada 800ms (pulso QR) | Jank en rush hora | P1 |
| Sin skeleton loaders (solo `CircularProgressIndicator`) | «¿Se colgó?» | P1 |
| `mis_pedidos` ListView no builder | Scroll pesado con historial | P2 |
| Búsquedas sin debounce | Lag al tipear en kanban/listas | P2 |
| 20+ ítems sidebar sin búsqueda | «No encuentro nada» | P0 producto |

### Flujos poco intuitivos

| Flujo | Clics hoy | Benchmark | Gap |
|-------|-----------|-----------|-----|
| Admin: ver pedido → cobrar mesa | 4+ | Toast: 2 | Alto |
| Cobro split mesa | 6+ pasos | Square: modo simple + avanzado | Alto |
| Producto → ver por qué no disponible | Ir a inventario manual | 1 tap inline | Medio |
| Alerta → resolver entidad | Copiar ID mentalmente | Deep link | Alto |
| Onboarding restaurante nuevo | Form largo | Wizard 3 pasos | Alto |

---

## Análisis por pantalla — lente producto SaaS

Escala por criterio: **P** Profesional · **C** Confianza · **M** Moderna · **$** Premium · **⚔** Compite comercial  
(1–4 insuficiente · 5–6 MVP · 7–8 vendible · 9–10 referencia)

### Cliente (11 pantallas) — media **5.0/10** producto

| Pantalla | P | C | M | $ | ⚔ | Diagnóstico producto |
|----------|:-:|:-:|:-:|:-:|:-:|----------------------|
| Splash | 4 | 4 | 5 | 3 | 4 | Legacy mata credibilidad marca Foody |
| Ciudades | 5 | 5 | 5 | 4 | 5 | Utilitaria; no transmite «marketplace curado» |
| Restaurantes | 6 | 6 | 6 | 5 | 6 | Stories ayudan; falta social proof (reseñas, ETA) |
| Sucursales | 5 | 6 | 5 | 4 | 5 | Paso redundante si 1 sede — fricción onboarding |
| Menú | 7 | 7 | 7 | 6 | 7 | **Mejor asset cliente**; aún lejos de Rappi polish |
| Carrito | 4 | 5 | 4 | 3 | 4 | **Deal-breaker** en comparación con delivery |
| Checkout | 5 | 5 | 5 | 4 | 5 | Pago = máxima confianza; formulario largo da dudas |
| Seguimiento | 7 | 8 | 7 | 6 | 7 | Timeline genera confianza post-compra |
| Mis pedidos | 5 | 6 | 5 | 4 | 5 | Sin reorder = pierde retención |
| Mesa QR entrada | 6 | 7 | 6 | 5 | 6 | Funcional; falta «bienvenido a Mesa 5» premium |
| Escanear QR | 6 | 7 | 6 | 5 | 6 | Estándar; marco branded elevaría percepción |

**Mensaje comercial cliente:** Aceptable para QR mesa en restaurante propio; **no** competir como app delivery white-label sin Fase DS-02.

---

### Auth / onboarding (5) — media **5.2/10**

| Pantalla | P | C | M | $ | ⚔ | Nota |
|----------|:-:|:-:|:-:|:-:|:-:|------|
| Login staff | 7 | 7 | 7 | 6 | 7 | Animaciones = primera señal «somos serios» |
| Registro restaurante | 6 | 6 | 5 | 5 | 5 | Form largo = abandono trial |
| Registro domi | 5 | 5 | 5 | 4 | 5 | Igualar staff login |
| Login domi independiente | 5 | 6 | 5 | 4 | 5 | Básico |
| Espera aprobación domi | 4 | 5 | 4 | 3 | 4 | Texto estático; usuario ansioso |

**Gap trial SaaS:** Sin checklist «Configura tu sede en 15 min» (menú → mesas → caja → primer pedido).

---

### Operación staff (12) — media **6.5/10** ⭐ donde se gana el contrato

| Pantalla | P | C | M | $ | ⚔ | Nota |
|----------|:-:|:-:|:-:|:-:|:-:|------|
| Panel shell | 7 | 7 | 7 | 6 | 7 | Sidebar vende; contenido inconsistente |
| Sidebar nav | 8 | 8 | 8 | 7 | 8 | **Plantilla premium** |
| Dashboard resumen | 6 | 6 | 6 | 5 | 6 | KPIs muertos — no «command center» |
| Dashboard gráficos | 6 | 7 | 6 | 5 | 6 | Datos sí; storytelling no |
| Kanban pedidos | 7 | 7 | 7 | 6 | 7 | Cerca Toast en densidad |
| Mesas grid | 7 | 7 | 7 | 6 | 7 | Operativo; cobro complejo resta premium |
| KDS | 8 | 8 | 8 | 7 | 8 | **Demo estrella** |
| POS cajero | 6 | 7 | 6 | 5 | 6 | Falta teclado numérico Square |
| Panel cajero/mesero | 6 | 7 | 6 | 5 | 6 | Tabs OK; unificar grids |
| Mesa pedidos sheet | 6 | 6 | 6 | 5 | 6 | Demasiada info = curva aprendizaje |

**Pitch:** «La cocina y el piso funcionan» — el dueño necesita **dashboard** que lo convenza en 30 segundos.

---

### Back-office (16) — media **4.8/10** ⚠️ donde se pierde el upsell

| Pantalla | P | C | M | $ | ⚔ | Nota |
|----------|:-:|:-:|:-:|:-:|:-:|------|
| Menú admin | 5 | 6 | 5 | 4 | 5 | CRUD denso |
| Inventario | 4 | 5 | 4 | 3 | 4 | **Peor primera impresión admin** |
| Caja | 6 | 7 | 6 | 5 | 6 | Crítico finanzas; mezcla estilos |
| Analítica | 6 | 7 | 6 | 5 | 6 | Datos valiosos; UX no |
| Facturación | 4 | 4 | 4 | 3 | 3 | DIAN pausada + HTML = no demo |
| Usuarios / alertas / reportes | 5 | 6 | 5 | 4 | 5 | Genérico |
| Mejorar plan | 7 | 7 | 7 | 7 | 7 | **Referencia paywall** — copiar patrón |

**Riesgo churn:** Gerente que solo entra a inventario/analítica percibe producto barato.

---

### Super admin + domi campo (4) — media **5.5/10**

| Pantalla | P | C | M | $ | ⚔ | Nota |
|----------|:-:|:-:|:-:|:-:|:-:|------|
| Foody Control | 6 | 6 | 6 | 5 | 6 | Potente; necesita wizard |
| Dashboard domi planta | 6 | 7 | 6 | 5 | 6 | Operativo |
| Repartidor independiente | 6 | 7 | 6 | 5 | 6 | GPS chip ✅ |
| Documentos domi | 5 | 6 | 5 | 4 | 5 | Onboarding compliance |

---

## Propuesta — Producto premium (Fase 10)

### 1. Dashboards modernos (command center)

| ID | Componente | Inspiración | Contenido |
|----|------------|-------------|-----------|
| PR-01 | **Home gerente** | Toast HQ + Shopify Home | Ventas hoy · pedidos activos · mesas ocupadas · alertas P0 |
| PR-02 | **KPI cards clicables** | Shopify | Tap ventas → caja; tap pedidos → kanban |
| PR-03 | **Pulso en vivo** | Linear | Badge Realtime «3 pedidos nuevos» sin refrescar |
| PR-04 | **Comparativa ayer** | Lightspeed | ▲12% vs ayer mismo horario |
| PR-05 | **Setup progress** | Notion onboarding | Barra «Sede 80% configurada» trial |

### 2. Acciones rápidas (FAB / command bar)

| ID | Rol | Acción | Ubicación |
|----|-----|--------|-----------|
| PR-10 | Gerente | + Pedido · + Mesa · Abrir caja | FAB panel home |
| PR-11 | Cajero | Cobrar mesa · POS rápido | Barra inferior fija |
| PR-12 | Mesero | Nueva mesa · QR mesa | Speed dial |
| PR-13 | Cocina | Marcar todo listo columna | Header KDS |
| PR-14 | Todos staff | ⌘K búsqueda global | Overlay (AR-28) |

### 3. Atajos inteligentes (contextuales)

Reutilizar backlog **`FRONTEND_ACCESOS_RAPIDOS.md`** con prioridad producto:

| P0 producto | AR-ID | Valor SaaS |
|-------------|-------|------------|
| Kanban → mesa | AR-01 | Reduce errores servicio |
| Alerta → entidad | AR-32 | Cierra loop operativo |
| Búsqueda global | AR-28 | «Se siente enterprise» |
| Favoritos sidebar | AR-29 | Personalización = retención |
| Seguimiento → menú | AR-20 | Upsell cliente |

### 4. Tarjetas informativas (patrón único)

```
FoodyInsightCard
├── icono + severidad (info/warn/critical)
├── título 16px semibold
├── métrica grande (Poppins 28)
├── subtítulo contexto («vs ayer»)
└── CTA texto → navegación
```

Aplicar en: dashboard, caja (resumen turno), mesa (cuenta), alertas, inventario (stock bajo).

### 5. Estados vacíos útiles

| Contexto | Copy | CTA |
|----------|------|-----|
| Sin pedidos cocina | «Todo al día — la cocina respira» | — |
| Sin productos menú | «Tu menú está vacío» | «Agregar primer producto» |
| Sin movimientos caja | «Abre turno para registrar ventas» | «Abrir caja» |
| Sin alertas | «Sin incidencias» | Ver historial |
| Cliente sin pedidos | «Aún no has pedido» | «Explorar» |

Componente: **`FoodyEmptyState`** (DS-06) con ilustración SVG ligera (no Lottie pesado en web).

### 6. Animaciones necesarias (solo donde importa)

| Momento | Animación | Duración | Por qué |
|---------|-----------|----------|---------|
| Login exitoso | Fade + slide al dashboard | 300ms | Transición premium |
| Pedido confirmado cliente | Checkmark scale | 400ms | Confianza pago |
| KDS nuevo pedido | Pulse borde tarjeta | 2× | Atención sin sonido |
| Mesa → ocupada | Color morph tile | 200ms | Feedback piso |
| Sheet cobro mesa | `DraggableScrollableSheet` | estándar | Expectativa iOS/Android |

**No animar:** listas CRUD, tablas inventario, formularios largos.

### 7. Microinteracciones

| ID | Interacción | Referencia |
|----|-------------|------------|
| PR-20 | Haptic light al marcar pedido listo | Toast |
| PR-21 | Snackbar con acción «Deshacer» 5s | Gmail |
| PR-22 | Pull-to-refresh con logo Foody | Rappi |
| PR-23 | Badge carrito bounce al agregar ítem | Uber Eats |
| PR-24 | Toggle disponible producto — switch animado | Shopify |
| PR-25 | Copiar # pedido — toast «Copiado» | Linear |

### 8. Navegación premium

| ID | Mejora | Detalle |
|----|--------|---------|
| PR-30 | **Sidebar colapsable** + iconos | Más espacio contenido tablet |
| PR-31 | **Breadcrumb** en CRUD | Menú › Bebidas › Coca-Cola |
| PR-32 | **Bottom nav cliente** | Inicio · Pedidos · QR (NAV-10) |
| PR-33 | **Role home único** | Post-login siempre «hoy» no último módulo |
| PR-34 | **Deep links** staff | `/admin/panel?seccion=pedidos&id=…` |
| PR-35 | **Command palette** ⌘K | Buscar pedido, mesa, producto, ir a módulo |

---

## Matriz competitiva (demo comercial)

| Capacidad | Foody hoy | Toast | Square | Rappi white-label |
|-----------|:---------:|:-----:|:------:|:-----------------:|
| KDS / cocina | ●●●●○ | ●●●●● | ●●●○○ | ●●○○○ |
| Mesas + QR | ●●●●○ | ●●●●● | ●●●○○ | ●●●○○ |
| POS / caja | ●●●○○ | ●●●●● | ●●●●● | ●●○○○ |
| Cliente delivery UI | ●●○○○ | ●●○○○ | ●●○○○ | ●●●●● |
| Inventario / costeo | ●●●●○ | ●●●●○ | ●●●○○ | ●○○○○ |
| Multi-sucursal | ●●●●○ | ●●●●● | ●●●○○ | ●●●○○ |
| Look & feel premium | ●●○○○ | ●●●●● | ●●●●○ | ●●●●● |
| Onboarding trial | ●●○○○ | ●●●●○ | ●●●●● | ●●●○○ |

**Posicionamiento recomendado:** *«POS + inventario LATAM, precio medio, cocina best-in-class»* — no competir head-on con Rappi en cliente hasta DS-02.

---

## Roadmap producto (prioridad revenue)

| Fase | Entregable | Impacto venta | Esfuerzo |
|------|------------|---------------|----------|
| **P0** | Logo Foody + quitar legacy splash | Confianza día 1 | S |
| **P0** | Dashboard gerente PR-01…05 | Demo de 30s | M |
| **P0** | ⌘K búsqueda + favoritos (AR-28/29) | «Enterprise feel» | M |
| **P1** | Carrito + checkout Square (DS-02) | Cliente white-label | L |
| **P1** | Empty states PR + FoodyEmptyState | Retención trial | M |
| **P1** | Cobro mesa modo simple (FF-07) | Operación rush | M |
| **P2** | Inventario sub-nav (DS-08) | Admin premium | M |
| **P2** | Wizard onboarding restaurante | Trial → pago | L |
| **P3** | Animaciones PR-20…25 | Delight | S |

Detalle implementación visual: **`FRONTEND_DESIGN_AUDIT.md` Fase 6**  
Detalle atajos: **`FRONTEND_ACCESOS_RAPIDOS.md`**  
Detalle navegación: **`FRONTEND_NAVIGATION_MAP.md` Fase 8**

---

## Calificación final — Foody como SaaS

| Dimensión | Nota | Peso venta B2B |
|-----------|:----:|:--------------:|
| Funcionalidad / cobertura | **8/10** | 25% |
| Operación piso (KDS/mesas/POS) | **6.5/10** | 25% |
| Confianza / marca | **5/10** | 20% |
| Back-office / reporting | **5/10** | 15% |
| Cliente final / QR | **5.5/10** | 10% |
| Onboarding / trial | **4.5/10** | 5% |

### **Nota producto SaaS ponderada: 6.0 / 10**

| Escala | Significado |
|:------:|-------------|
| **1–4** | No vendible; demo interna |
| **5–6** | **Foody hoy** — piloto con early adopters, capacitación incluida |
| **7–8** | Vendible a restaurantes independientes sin vergüenza en demo |
| **9–10** | Compite con Toast/Lightspeed en presentación; listo para cadenas |

**Para llegar a 8/10 (objetivo 2 trimestres frontend):** Fase 6 Design System + Fase 10 Product Premium (dashboard + búsqueda + empty states + quitar legacy) + Fase 1 UX quick wins.

---

## Relación con otros docs

| Doc | Relación |
|-----|----------|
| `FRONTEND_DESIGN_AUDIT.md` | Capa visual (complementa esta capa producto/negocio) |
| `FRONTEND_UX_AUDITORIA.md` | Fricción por rol |
| `FRONTEND_ROADMAP.md` | Fase 10 Product Premium |
| `FRONTEND_INSTRUCCIONES.md` | INS-009 auditoría producto |

---

*Próxima revisión: tras PR-01 (dashboard gerente) + DS-04 (splash Foody) — recalificar confianza y premium.*
