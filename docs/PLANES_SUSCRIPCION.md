# Planes y suscripciones — estado vs objetivo

> **Actualizado:** 2026-06-24 (post-Antigravity + freemium). Estado vivo: `docs/AVANCE_PROYECTO.md` § Antigravity.
> Spec negocio: `INFRAESTRUCTURA/reglas_negocio_foody.md` · Precios: `INFRAESTRUCTURA/plan_negocio_fondo_emprender.md`
> **Foody NOC (dueño SaaS):** Centro de Operaciones — [`SUPERADMIN_FOODY_CONTROL.md`](SUPERADMIN_FOODY_CONTROL.md) (visión completa · **Fase A esencial ahora**; nombres **Gratis / Pro / Ultra**).

---

## Resumen en 30 segundos

| Concepto | ¿Implementado? | Efecto real hoy |
|----------|----------------|-----------------|
| Plan **`gratis`** (self-service) | ✅ | Onboarding automático; módulos core **con límites numéricos** |
| Planes **`basico` / `pro` / `enterprise`** | ✅ Parcial | Wompi checkout + webhook (local: sincronizar manual) |
| **Estado** suscripción | ✅ | `SuscripcionActivaGuard` + cron vencimiento |
| **Módulos por plan** | ✅ | `PlanFeaturesGuard` + `@RequiereModulo`; guard lee plan en **BD** (no JWT obsoleto) |
| **Límites numéricos** | ✅ | `LIMITES_POR_PLAN` + `assertLimite*` en mesas, productos, ingredientes, staff, sucursales |
| UI Flutter candados / upgrade | ✅ | Paywall automático 403 + `MejorarPlanScreen` |

---

## Matriz oficial plan → módulos (implementada)

Fuente: `foody_backend/src/core/auth/plan-features.config.ts` + `lib/features/admin/domain/plan_modulos.dart`

| Módulo | Gratis | Básico | Pro | Enterprise |
|--------|--------|--------|-----|------------|
| Menú + pedidos + caja + mesas | ✅ | ✅ | ✅ | ✅ |
| Inventario + costeo | ✅* | ✅ | ✅ | ✅ |
| Cocina / KDS | ✅* | ✅ | ✅ | ✅ |
| Domiciliarios + zonas | ✅* | ✅ | ✅ | ✅ |
| Reportes | ✅* | ✅ | ✅ | ✅ |
| Centro de Análisis (`analitica`) | ❌ | ❌ | ✅ | ✅ |
| Facturación DIAN | ❌ | ❌ | ❌ | ✅ |

\* Plan **gratis**: mismo acceso a módulo, pero con **límites numéricos** (ver tabla siguiente).

---

## Límites numéricos por plan (implementados)

Fuente: `LIMITES_POR_PLAN` en `plan-features.config.ts`

| Plan | Sucursales | Staff | Mesas | Productos | Ingredientes |
|------|------------|-------|-------|-----------|--------------|
| **gratis** | 1 | **2** | **2** | **5** | **5** |
| basico | 1 | 8 | 30 | 200 | 200 |
| pro | 3 | 25 | 100 | 9999 | 9999 |
| enterprise | 99 | 99 | 9999 | 9999 | 9999 |

Al superar un límite: HTTP **403** con `error: PLAN_LIMITE_EXCEDIDO` y mensaje descriptivo.

---

## Precios checkout (Wompi)

| Plan | COP/mes (referencia) |
|------|----------------------|
| Básico | 50.000 |
| Pro | 100.000 |
| Enterprise | 130.000 |

Centavos en backend: `foody_backend/src/modulos/pagos/pagos-planes.config.ts`

---

## Archivos de referencia

| Área | Ruta |
|------|------|
| Config planes y límites | `foody_backend/src/core/auth/plan-features.config.ts` |
| Validación límites | `foody_backend/src/core/auth/plan-features.service.ts` |
| Guard módulos | `foody_backend/src/core/auth/guards/plan-features.guard.ts` |
| UI módulos sidebar | `lib/features/admin/domain/plan_modulos.dart` |
| UI precios/planes | `lib/features/pagos/domain/planes_comerciales.dart` |
| Auditoría Antigravity (archivada) | `docs/archivo/auditoria_flujos_foody-antigravity.md` |
| Walkthrough (archivado) | `docs/archivo/walkthrough-antigravity.md` |

---

## Histórico (pre-2026-06)

Antes de Sprint 8 y Antigravity, la columna `plan` existía en BD pero **no restringía módulos**. Ver commits anteriores a `plan-features.config.ts` freemium.
