# Foody — Documentación Frontend (Flutter / UI)

> **Carpeta única** para auditorías, roadmap y backlog de trabajo Flutter.  
> Índice general del repo: [`../README.md`](../README.md)

---

## Empezar aquí

| Orden | Documento | Para qué |
|------:|-----------|----------|
| 1 | [**FRONTEND_ROADMAP.md**](FRONTEND_ROADMAP.md) | **Maestro** — fases F0–F10, estado, changelog |
| 1b | [**FRONTEND_PLAN_EJECUCION.md**](FRONTEND_PLAN_EJECUCION.md) | Sprints 1–5 (orden implementación) |
| 1c | [**FRONTEND_AUDITORIA_NAV_ADMIN.md**](FRONTEND_AUDITORIA_NAV_ADMIN.md) | **Nav/UX admin** ciclo 1 — NAV-ADM (cerrado) |
| 1c2 | [**FRONTEND_AUDITORIA_NAV_ADMIN2.md**](FRONTEND_AUDITORIA_NAV_ADMIN2.md) | **Nav/UX admin** ciclo 2 — NAV-ADM2 (deep-links, móvil, cross-links) |
| 1d | [**FRONTEND_AUDITORIA_NAV_MENU_COSTEO.md**](FRONTEND_AUDITORIA_NAV_MENU_COSTEO.md) | **Nav/UX cadena Menú→Insumos→Costeo** — backlog NAV-MC |
| 1e | [**FRONTEND_AUDITORIA_NAV_CAJERO.md**](FRONTEND_AUDITORIA_NAV_CAJERO.md) | **Nav/UX shell Cajero** — backlog NAV-CJ |
| 1f | [**FRONTEND_AUDITORIA_NAV_COCINA.md**](FRONTEND_AUDITORIA_NAV_COCINA.md) | **Nav/UX KDS Cocina** — costeo N/A · backlog NAV-CK |
| 1g | [**FRONTEND_AUDITORIA_NAV_MESERO.md**](FRONTEND_AUDITORIA_NAV_MESERO.md) | **Nav/UX shell Mesero** — backlog NAV-MS |
| 1h | [**FRONTEND_AUDITORIA_NAV_DOMICILIARIO.md**](FRONTEND_AUDITORIA_NAV_DOMICILIARIO.md) | **Nav/UX Domi planta** — backlog NAV-DP |
| 1i | [**FRONTEND_AUDITORIA_UX_CLIENTE.md**](FRONTEND_AUDITORIA_UX_CLIENTE.md) | **UX/UI cliente** (ciudad→seguimiento, promos) — backlog CL-01… · **solo análisis** |
| 2 | [**FRONTEND_INSTRUCCIONES.md**](FRONTEND_INSTRUCCIONES.md) | Peticiones de producto (INS-000…) |
| 3 | [**../ESTRATEGIA_BACKEND_PRIMERO.md**](../ESTRATEGIA_BACKEND_PRIMERO.md) | Flavors, usuarios demo, verificación |
| 4 | [**../CHECKLIST_QA_ROLES.md**](../CHECKLIST_QA_ROLES.md) | QA manual por rol |

---

## Auditorías (panorama completo)

| Documento | Rol / enfoque | Nota global |
|-----------|---------------|:-----------:|
| [FRONTEND_UX_AUDITORIA.md](FRONTEND_UX_AUDITORIA.md) | UX por pantalla y rol | Intuitividad 3–5/5 |
| [FRONTEND_AUDITORIA_UX_CLIENTE.md](FRONTEND_AUDITORIA_UX_CLIENTE.md) | Cliente end-to-end vs admin premium | **5.5/10** · CL backlog |
| [FRONTEND_AUDITORIA_NAV_ADMIN.md](FRONTEND_AUDITORIA_NAV_ADMIN.md) | Nav/atajos **rol admin** ciclo 1 | NAV-ADM 24 ítems |
| [FRONTEND_AUDITORIA_NAV_ADMIN2.md](FRONTEND_AUDITORIA_NAV_ADMIN2.md) | Nav/atajos **rol admin** ciclo 2 | NAV-ADM2 22/24 ✅ |
| [FRONTEND_AUDITORIA_NAV_DOMICILIARIO.md](FRONTEND_AUDITORIA_NAV_DOMICILIARIO.md) | Nav/UX **Domi planta** | NAV-DP 13/13 ✅ |
| [FRONTEND_DESIGN_AUDIT.md](FRONTEND_DESIGN_AUDIT.md) | Product Design visual | **5.8/10** |
| [FRONTEND_PRODUCT_AUDIT.md](FRONTEND_PRODUCT_AUDIT.md) | Head of Product SaaS | **6.0/10** |
| [FRONTEND_RESPONSIVE_STRATEGY.md](FRONTEND_RESPONSIVE_STRATEGY.md) | Responsive mobile/tablet/web | **6.5/10** |
| [FRONTEND_NAVIGATION_MAP.md](FRONTEND_NAVIGATION_MAP.md) | Arquitectura de navegación | 22 rutas |
| [FRONTEND_FLUTTER_ARCHITECTURE.md](FRONTEND_FLUTTER_ARCHITECTURE.md) | Código Flutter / mantenibilidad | **5/10** |

---

## Backlog accionable

| Documento | IDs | Fases roadmap |
|-----------|-----|---------------|
| [FRONTEND_FRICTION_FIXES.md](FRONTEND_FRICTION_FIXES.md) | FF-01… | Fase 1 |
| [FRONTEND_ACCESOS_RAPIDOS.md](FRONTEND_ACCESOS_RAPIDOS.md) | AR-01…40 | Fases 2–4 |
| [FRONTEND_AUDITORIA_NAV_ADMIN.md](FRONTEND_AUDITORIA_NAV_ADMIN.md) | **NAV-ADM-01…24** | Auditoría nav rol admin (2026-07-22) |
| [FRONTEND_AUDITORIA_NAV_MENU_COSTEO.md](FRONTEND_AUDITORIA_NAV_MENU_COSTEO.md) | **NAV-MC-01…19** | Auditoría nav cadena Menú→Insumos→Costeo (2026-07-22) |
| Fase 6 en roadmap | DS-01…08 | Design System |
| Fase 7 en roadmap | RS-01…42 | Responsive |
| Fase 8 en roadmap | NAV-01…14 | Navegación |
| Fase 9 en roadmap | FL-10…63 | Arquitectura código |
| Fase 10 en roadmap | PR-01…35 | Producto premium |

---

## Referencias técnicas (fuera de esta carpeta)

| Documento | Contenido |
|-----------|-----------|
| [../archivo/auditorias-prompts/AUDITORIA_PANTALLAS_BOTONES.md](../archivo/auditorias-prompts/AUDITORIA_PANTALLAS_BOTONES.md) | Botones → API |
| [../MAPA_FLUJOS_PANTALLAS.md](../MAPA_FLUJOS_PANTALLAS.md) | Flujos legacy |
| [../../lib/core/rutas/app_router.dart](../../lib/core/rutas/app_router.dart) | Rutas GoRouter |

---

## Verificación

```powershell
.\scripts\verificar-flutter-ui.ps1
.\scripts\flutter-run-flavor.ps1 -Flavor cliente -Device chrome -WebPort 8082
.\scripts\flutter-run-flavor.ps1 -Flavor equipo -Device chrome -WebPort 8080
```

Al cerrar tarea: actualizar roadmap changelog + [`../AVANCE_PROYECTO.md`](../AVANCE_PROYECTO.md) + [`../MASTER_STATUS.md`](../MASTER_STATUS.md).
