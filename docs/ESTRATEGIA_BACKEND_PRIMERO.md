# Foody — Estrategia: pulido UI + QA manual (2026-07-02)

> **Decisión 2026-07-02:** Backend cerrado para demo/piloto. Prioridad: **pantallas Flutter pulidas** y **QA manual por rol**.

> **Facturación electrónica DIAN:** 🚫 pausada — ver `docs/FACTURACION_ELECTRONICA_PAUSADA.md`.

---

## Qué está activo

| Área | Verificación |
|------|----------------|
| **Flutter features** | `.\scripts\verificar-flutter-ui.ps1` |
| **QA manual UI** | `docs/CHECKLIST_QA_ROLES.md` |
| **API por rol** | `.\scripts\verificar-qa-manual.ps1 -RolesApi` |
| **Cierre completo** | `.\scripts\verificar-cierre-sin-vps.ps1 -SinDocker` |
| **Backend** | Mantener con CI; no nuevas features salvo fixes UI |

---

## Flavors Flutter

| Flavor | Puerto dev | Roles |
|--------|------------|-------|
| `cliente` | 8081 / 8082 | Cliente, mesa QR, seguimiento |
| `equipo` | 8080 | Admin, cajero, mesero, cocina, domi, super |

**Importante:** no probar cliente en flavor `equipo` (rutas bloqueadas).

### Puerto ocupado (errno 10048 / dartvm)

Si `flutter run` falla con *«Solo se permite un uso de cada dirección de socket»* en `:8080`, hay un **Flutter web anterior** (`dartvm`) que no se cerró. **No afecta producción** (prod no usa ese servidor de hot-reload).

```powershell
# Libera solo el dartvm/flutter de ese puerto y arranca de nuevo:
.\scripts\flutter-run-flavor.ps1 -Flavor equipo -Device chrome -WebPort 8080 -LiberarPuerto

# O usa otro puerto:
.\scripts\flutter-run-flavor.ps1 -Flavor equipo -Device chrome -WebPort 8083
```

Regla agente: `.cursor/rules/foody-riesgos-produccion.mdc`.

---

## Usuarios demo QA

| Rol | Email | Pass |
|-----|-------|------|
| Admin | `admin@foody.demo` | `123456` |
| Gerente | `gerente@foody.demo` | `123456` |
| Cocina | `cocina@foody.demo` | `123456` |
| Domi planta | `domi@foody.demo` | `123456` |
| Repartidor | `repartidor@foody.demo` | `123456` |
| Super | `super@foody.demo` | `123456` |
| Cajero | `cajero.test@foody.demo` | `123456` |
| Mesero | `mesero@foody.com` | `123456` |

---

## Pospuesto (sin recursos ahora)

- Facturación electrónica DIAN (`X-01`)
- VPS + Wompi prod (`P0-05`–`P0-07`)
- Impresora física (`P0-01`)

---

## Referencias

- **`docs/frontend/FRONTEND_ROADMAP.md`** — documento maestro (fases, estado, changelog)
- `docs/frontend/FRONTEND_INSTRUCCIONES.md` — instrucciones de producto pendientes
- Índice completo: `docs/frontend/README.md`
- `docs/CHECKLIST_QA_ROLES.md`
- `docs/archivo/auditorias-prompts/AUDITORIA_PANTALLAS_BOTONES.md`
- `docs/FACTURACION_ELECTRONICA_PAUSADA.md`
