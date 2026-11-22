# Foody — Auditoría de navegación / UX · Rol Cocina (KDS)

> **Menú / Insumos / Costos:** el rol `cocina` solo tiene `ver_cocina` → **no aplica** esa cadena.
> Entorno real: **KDS standalone** `/admin/cocina`.

**Última actualización:** 2026-07-26 — NAV-CK Alta+Media (+ Baja rápidos) implementadas.

**Estado del ciclo:**

| Fase | Estado | Notas |
|------|--------|-------|
| 1. Diagnóstico | ✅ | Menú/costeo N/A · 13 ítems KDS |
| 2. Implementación | ✅ | CK-01…10,12,13 (CK-11 diferido) |
| 3. Verificación | 🟡 | analyze + build API · smoke UI `cocina@foody.demo` |

---

## Menú / Insumos / Costos — veredicto

| Pregunta | Respuesta |
|----------|-----------|
| ¿Tiene pantallas de costeo/menú/insumos? | **No** |
| Permisos | Solo `['ver_cocina']` |
| Destino post-login | `/admin/cocina` → `KdsScreen(standalone: true)` |
| Sidebar si entrara al panel | Solo «Cocina en vivo (KDS)» (ahora redirigido fuera del panel) |

---

## Hallazgos KDS (NAV-CK)

| ID | Pantalla | Problema | Mejora | Tipo | Device | Prioridad | Estado |
|----|----------|----------|--------|------|--------|-----------|--------|
| **NAV-CK-01** | Timer ticket | Usaba `pedido.created_at` → minutos absurdos | `cocina_desde` = MIN(ítem.created_at); cap `99+ min` | Feedback | Todos | Alta | ✅ |
| **NAV-CK-02** | Tabs estación | Embebido listaba todas las cocinas | Rol cocina / standalone → siempre `cocinasParaKds` | NAV | Todos | Alta | ✅ |
| **NAV-CK-03** | Panel admin | Cocina podía abrir `/admin/panel` | Redirect GoRouter → `/admin/cocina` | NAV | Todos | Alta | ✅ |
| **NAV-CK-04** | Header card | Badges apretados | Fila `#pedido`+timer; chips abajo; ellipsis | Layout | Móvil | Media | ✅ |
| **NAV-CK-05** | CTAs ítem | 3 botones texto overflow | Narrow: icon buttons | Responsive | Móvil | Media | ✅ |
| **NAV-CK-06** | Refresh | Spinner full-screen | Solo carga inicial; indicador AppBar | Feedback | Todos | Media | ✅ |
| **NAV-CK-07** | Timer UI | Congelado 30s | Tick UI 60s | Feedback | Todos | Media | ✅ |
| **NAV-CK-08** | Empty | Blanco70 en fondo claro embebido | Colores adaptativos + copy «Todo listo» | Empty | Embebido | Media | ✅ |
| **NAV-CK-09** | Error / sin estación | Mensaje genérico | Icono + copy admin + Reintentar | Empty/Error | Todos | Media | ✅ |
| **NAV-CK-10** | AppBar | Sin nombre estación | Subtítulo «Estación: …» | Copy | Todos | Baja | ✅ |
| **NAV-CK-11** | URGENTE | Hack `[URGENTE]` en obs | UI prioridad API | Otro | Todos | Baja | ⏳ |
| **NAV-CK-12** | Empty refresh | Sin pull-to-refresh | `AlwaysScrollable` + RefreshIndicator | Atajo | Móvil | Baja | ✅ |
| **NAV-CK-13** | Pedido pagado | Sin señal visual | Badge «Cobrado — terminar» + borde | Feedback | Todos | Baja | ✅ |

---

## Conexiones entre roles

| Mejora | Otro rol |
|--------|----------|
| Sin estación asignada | **Admin/Gerente** debe vincular `cocina_id` en Usuarios |
| Badge «Cobrado» | Depende de **Cajero** marcando pedido pagado con ítems pendientes |
| Tabs multi-estación | Solo **admin** con `ver_cocina` en panel (todas las cocinas de la sede) |
| NAV-CK-11 (prioridad) | **Mesero/Admin** deberían setear urgencia; cocina solo reflejar |

---

## Archivos tocados

- `lib/features/cocinas/presentation/kds_screen.dart`
- `lib/core/rutas/app_router.dart` (redirect cocina)
- `foody_backend/src/modulos/cocinas/cocinas.service.ts` (`cocina_desde` + `created_at` ítem)

---

## Changelog

- **2026-07-26:** Diagnóstico: costeo N/A. Implementación NAV-CK KDS (timer, filtro estación, redirect panel, layout móvil, empty/error, badge pagado).
