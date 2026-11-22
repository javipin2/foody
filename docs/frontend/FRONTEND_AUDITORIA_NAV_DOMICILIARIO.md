# Foody — Auditoría de navegación / UX · Domiciliario planta

> Prefijo **NAV-DP**. Rol campo: `domiciliario_planta` · ruta `/admin/domiciliario`.  
> No confundir con admin «Gestionar repartidores» ni con independiente `/domiciliario/*`.

**Última actualización:** 2026-07-26 — ciclo NAV-DP cerrado (13/13).  
**2026-08-08:** supersedido por rediseño app repartidor — ver `FRONTEND_DOMICILIARIO_APP.md` (shell, tarjeta, ingresos, dispatch).
**Demo:** `domi@foody.demo` / `123456`

---

## Estado del ciclo

| Fase | Estado |
|------|--------|
| 1. Diagnóstico | ✅ |
| 2. Aprobación | ✅ («continua con todo») |
| 3. Alta DP-01…03 | ✅ |
| 4. Media DP-04…08 | ✅ |
| 5. Baja DP-09…13 | ✅ |
| 6. Verificación | 🟡 analyze OK · reiniciar API para `saldo_por_liquidar` · smoke UI hot restart |

---

## Hallazgos

| ID | Tema | Estado | Notas |
|----|------|--------|-------|
| DP-01 | FCM → planta | ✅ | `NavegadorFcmFoody`: planta → `/admin/domiciliario?pedido_id=` |
| DP-02 | Redirect panel | ✅ | `dashboard==domiciliario` → `/admin/domiciliario` |
| DP-03 | Cobro un sheet | ✅ | Mixto + fiado en un bottom sheet |
| DP-04 | Mini-mapa | ✅ | `mostrarMiniMapa: false` en planta |
| DP-05 | Panel móvil | ✅ | `DraggableScrollableSheet` |
| DP-06 | Título AppBar | ✅ | «Mi ruta» |
| DP-07 | Deuda fiado | ✅ | `saldo_por_liquidar` en estadísticas + banner |
| DP-08 | Llamar/Navegar web | ✅ | Copiar + snackbar web |
| DP-09 | Nueva asignación | ✅ | SnackBar + badge tab Activos (n) |
| DP-10 | Tabs | ✅ | Compactas &lt;420 + fade |
| DP-11 | Split ≥720 | ✅ | Mapa \| lista |
| DP-12 | Login hint | ✅ | Copy empleado vs independiente |
| DP-13 | Stats | ✅ | Oculta ceros; muestra liquidar |

---

## Archivos

- `lib/core/notificaciones/navegador_fcm_foody.dart`
- `lib/core/rutas/app_router.dart`
- `lib/features/domiciliarios/presentation/dashboard_domiciliario_screen.dart`
- `lib/features/domiciliarios/presentation/widgets/panel_entrega_activa.dart`
- `lib/features/auth/presentation/staff_login_screen.dart`
- `foody_backend/.../domiciliarios.service.ts` (`saldo_por_liquidar`)

## Fuera de alcance

`DomiciliariosAdminScreen`, ofertas inDriver, lógica Nest de cobro (solo campo extra en stats).
