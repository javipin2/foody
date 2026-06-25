# Planes y suscripciones — estado vs objetivo

> **Documento de brecha (2026-06-09).** Lo que existe hoy en código vs lo que debe hacer cada plan comercialmente.
> Estado vivo del sprint: `docs/AVANCE_PROYECTO.md` · Spec negocio: `INFRAESTRUCTURA/reglas_negocio_foody.md` · Precios propuestos: `INFRAESTRUCTURA/plan_negocio_fondo_emprender.md`

---

## Resumen en 30 segundos

| Concepto | ¿Implementado? | Efecto real hoy |
|----------|----------------|-----------------|
| **Estado** de suscripción (`prueba`, `activa`, `vencida`, `bloqueada`) | ✅ Parcial | `SuscripcionActivaGuard` bloquea al staff si no es `prueba` ni `activa` |
| **Plan** (`basico`, `pro`, `enterprise`) | ✅ Parcial | `PlanFeaturesGuard` + `@RequiereModulo` en inventario/cocina/domi/facturación/reportes; JWT/login incluye `plan` y `modulos[]`; sidebar Flutter filtra rutas |
| **fecha_vencimiento** | 🟡 Parcial | Se guarda y muestra; **no hay job** que pase automáticamente a `vencida` |
| Matriz plan → módulos / límites | ⏳ Pendiente | Solo documentado en negocio, no en backend ni Flutter |

Un restaurante con plan **enterprise** y otro con **básico** tienen **las mismas funciones** si ambos tienen estado `activa` o `prueba`.

---

## Qué sí hace el sistema hoy

### Tabla `suscripciones_restaurante`

Migración `011_super_admin.sql`:

- `estado`: `prueba` \| `activa` \| `vencida` \| `bloqueada`
- `plan`: `basico` \| `pro` \| `enterprise` (CHECK en BD)
- `fecha_inicio`, `fecha_vencimiento`, `motivo_bloqueo`, etc.

### Guard operativo (solo estado, no plan)

Archivo: `foody_backend/src/core/auth/guards/suscripcion-activa.guard.ts`

- Staff con `restaurante_id`: consulta `estado` de la suscripción.
- Permite acceso solo si `estado IN ('activa', 'prueba')`.
- `super_admin` y `domiciliario_independiente` pasan sin revisar suscripción.
- **No lee la columna `plan`.**

### UI superadmin (Foody Control)

- Pestaña **Planes** y menú en **Restaurantes**: editar plan, estado y fecha de vencimiento.
- Al crear restaurante (`POST /super/restaurantes`): suscripción `prueba` + plan `basico` + 14 días.

---

## Qué NO hace el plan (brecha principal)

No existe en el código:

1. **Guard o servicio de features por plan** — p. ej. bloquear inventario/cocina/facturación si plan = `basico`.
2. **Límites numéricos** — máx. sucursales, usuarios staff, productos por plan.
3. **Menú Flutter condicionado al plan** — el sidebar del admin restaurante no oculta módulos según plan.
4. **Respuestas API específicas** — no hay error tipo `PLAN_NO_INCLUYE_MODULO`.
5. **Vencimiento automático** — cron que actualice `vencida` cuando `fecha_vencimiento < now()`.
6. **Facturación / cobro** — integración de pagos recurrentes (fuera de scope actual).

Búsqueda en backend (`foody_backend/src`): la columna `plan` solo aparece en `super-admin.service.ts` (listar/actualizar/onboarding). Ningún otro módulo la consulta.

---

## Objetivo comercial (a implementar)

Referencia: `INFRAESTRUCTURA/plan_negocio_fondo_emprender.md`

| Plan | Precio propuesto/mes | Incluiría |
|------|----------------------|-----------|
| **Básico** | ~$50.000 | Menú digital, pedidos, caja |
| **Pro** | ~$100.000 | Básico + inventario, domiciliarios, cocina (KDS) |
| **Enterprise** | ~$130.000 | Pro + facturación electrónica, multi-sucursal ampliada, reportes avanzados |

Reglas adicionales en spec (`reglas_negocio_foody.md`):

- Período de prueba: **14 días** (estado `prueba`, no confundir con nombre de plan).
- Restaurante bloqueado/vencido: datos conservados **30 días** (`dias_datos_restaurante_bloqueado` en config global).
- Sucursales extra: a definir (recomendado cobrar desde la 3.ª sucursal).

---

## Trabajo pendiente (Sprint 8+)

| # | Tarea | Dónde | Prioridad |
|---|-------|-------|-----------|
| 1 | Definir matriz oficial **plan → módulos/permisos/límites** (cerrar con negocio) | Este doc + `reglas_negocio_foody.md` | Alta |
| 2 | `PlanFeaturesGuard` o `PlanFeaturesService` en NestJS | `foody_backend/src/core/` | Alta |
| 3 | Decorador `@RequierePlan('pro')` o `@RequiereModulo('inventario')` en controllers | Módulos afectados | Alta |
| 4 | Incluir `plan` y/o `features[]` en JWT o endpoint `/auth/perfil` | `auth.service` | Media |
| 5 | Ocultar/deshabilitar entradas del sidebar admin según plan | `panel_sidebar_nav.dart` | Media |
| 6 | Job/cron **vencimiento automático** (`activa`/`prueba` → `vencida`) | NestJS scheduler o SQL cron | Media |
| 7 | Pantalla upgrade / badge «Requiere plan Pro» en admin restaurante | Flutter admin | Baja |
| 8 | Tests e2e: restaurante básico no puede POST inventario | `scripts/verificar-paso0.ps1` o similar | Media |

### Módulos candidatos a restricción por plan (borrador)

| Módulo / feature | Básico | Pro | Enterprise |
|------------------|--------|-----|------------|
| Menú + pedidos + caja | ✅ | ✅ | ✅ |
| Mesas QR | ✅ | ✅ | ✅ |
| Inventario + costeo | ❌ | ✅ | ✅ |
| Cocina / KDS / impresoras | ❌ | ✅ | ✅ |
| Domiciliarios (planta + independiente) | ❌ | ✅ | ✅ |
| Reportes avanzados | ❌ | 🟡 básicos | ✅ |
| Facturación electrónica (DIAN) | ❌ | ❌ | ✅ |
| Multi-sucursal (>2 sucursales) | ❌ | 🟡 límite 2 | ✅ ilimitado |

> **Nota:** tabla borrador hasta acuerdo explícito; no es comportamiento actual del código.

---

## Archivos de referencia

| Área | Ruta |
|------|------|
| Guard suscripción (estado) | `foody_backend/src/core/auth/guards/suscripcion-activa.guard.ts` |
| CRUD suscripciones super | `foody_backend/src/modulos/super-admin/super-admin.service.ts` |
| UI planes | `lib/features/admin/presentation/panel_foody_control_screen.dart` |
| Esquema BD | `foody_supabase/migrations/011_super_admin.sql` |
| Foody Control widgets | `lib/features/admin/presentation/widgets/foody_control_ui.dart` |

---

## Cuándo implementar

- **Sprint 8** (Super Admin): después de estabilizar Foody Control y guard tenant global.
- **Antes de producción comercial**: obligatorio si se cobra por tier; si todos los clientes tienen acceso full en piloto, puede posponerse con plan fijo manual.
