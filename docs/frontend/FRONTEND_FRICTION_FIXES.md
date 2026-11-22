# Foody — Fricciones UX a corregir (fixes concretos)

> Ítems pequeños y acotados. Prioridad Fase 1 en `FRONTEND_ROADMAP.md`.  
> **Última actualización:** 2026-07-02

| ID | Prioridad | Estado | Resumen |
|----|-----------|--------|---------|
| FF-01 | P0 | ✅ | Salida visible sesión mesa QR |
| FF-02 | P0 | ✅ | Carrito: botón aumentar cantidad (+) |
| FF-03 | P1 | ✅ | Checkout: factura colapsada por defecto |
| FF-04 | P1 | ✅ | Dashboard KPIs clicables |
| FF-05 | P1 | ✅ | Errores cliente sin jerga técnica |
| FF-06 | P2 | ✅ | Una sede → omitir lista sucursales |
| FF-07 | P0 | ✅ | Cobro mesa: «Cobrar todo» prominente |
| FF-08 | P2 | 🟡 | Loading consistente (`FoodyEstadoUi` en panel/menú/ciudades) |
| FF-09 | P2 | ⏳ | Confirmación destructiva unificada (cancelar, borrar) |
| FF-10 | P3 | ⏳ | `flutter_secure_storage` tokens staff (post-piloto) |

---

## FF-01 — Salida visible sesión mesa QR

| Campo | Detalle |
|-------|---------|
| **Problema** | Tras UX-003 se quitó «Salir» genérico; el comensal no sabe cómo terminar la sesión mesa |
| **Pantalla** | `menu_screen_foody` (modo mesa), posible app bar |
| **Solución UX** | Botón «Terminé» / «Cerrar cuenta y salir» con copy que explique que puede volver escaneando QR |
| **No hacer** | Volver a exponer «Mis pedidos» global en sesión mesa |
| **Criterio aceptación** | Usuario encuentra salida en ≤2 s sin manual |
| **Estado** | ⏳ |

---

## FF-02 — Carrito: aumentar cantidad (+)

| Campo | Detalle |
|-------|---------|
| **Problema** | Solo se puede bajar cantidad o eliminar; subir requiere volver al menú |
| **Pantalla** | Carrito cliente |
| **Solución** | Botón + por línea; revalidar precio vía API al confirmar (no calcular en cliente) |
| **Criterio** | +/− en cada ítem; total mostrado = respuesta backend |
| **Estado** | ⏳ |

---

## FF-03 — Checkout: factura colapsable

| Campo | Detalle |
|-------|---------|
| **Problema** | Campos DIAN/factura ocupan espacio aunque DIAN esté pausada |
| **Pantalla** | Checkout |
| **Solución** | `ExpansionTile` o sección «Factura (opcional)» cerrada por defecto |
| **Nota** | Alineado con `FACTURACION_ELECTRONICA_PAUSADA.md` |
| **Estado** | ⏳ |

---

## FF-04 — Dashboard KPIs clicables

| Campo | Detalle |
|-------|---------|
| **Problema** | Números del dashboard no llevan al detalle |
| **Pantalla** | Dashboard admin |
| **Solución** | Tap en «Pedidos activos» → kanban; «Alertas» → alertas; etc. |
| **Estado** | ⏳ |

---

## FF-05 — Errores sin jerga técnica

| Campo | Detalle |
|-------|---------|
| **Problema** | Fallos de red muestran mensajes de desarrollo |
| **Alcance** | Cliente público (menú, checkout, seguimiento) |
| **Solución** | Mapa en `cliente_dio` / capa UI: «No pudimos conectar. Revisa tu internet e intenta de nuevo.» |
| **Estado** | ⏳ |

---

## FF-06 — Una sede → saltar lista

| Campo | Detalle |
|-------|---------|
| **Problema** | Paso extra si el restaurante tiene una sola sucursal |
| **Pantalla** | Flujo ciudades → restaurantes → sucursales |
| **Solución** | Si `sucursales.length == 1`, `go` directo a menú |
| **Estado** | ⏳ |

---

## FF-07 — Cobro mesa: modo simple

| Campo | Detalle |
|-------|---------|
| **Problema** | Cuenta/ticket/ítem/comensal/parcial abruma al cajero |
| **Pantallas** | Mesa detalle admin/cajero |
| **Solución** | CTA primario «Cobrar todo»; acordeón «Cobro parcial / por comensal» |
| **Backend** | Sin cambios si endpoints ya soportan modos |
| **Estado** | ⏳ |

---

## FF-08 — Loading consistente

| Campo | Detalle |
|-------|---------|
| **Problema** | Mezcla de `CircularProgressIndicator`, overlays y vacíos distintos |
| **Solución** | Reutilizar patrón legacy (overlay + `RefreshIndicator`) donde falte |
| **Estado** | ⏳ |

---

## FF-09 — Confirmaciones destructivas

| Campo | Detalle |
|-------|---------|
| **Problema** | Algunos borrados sin diálogo, otros con copy distinto |
| **Solución** | Widget/dialog común «¿Seguro?» + acción roja |
| **Estado** | ⏳ |

---

## FF-10 — Tokens staff en secure storage

| Campo | Detalle |
|-------|---------|
| **Problema** | JWT en storage web menos seguro |
| **Prioridad** | Post-piloto (auditoría preprod) |
| **Estado** | ⏳ |

---

## Registro de cierre

Al marcar ✅: fecha, archivos tocados, comando `verificar-flutter-ui.ps1`, nota en `FRONTEND_ROADMAP.md` changelog.
