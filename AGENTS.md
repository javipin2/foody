# Foody — guía para agentes (Cursor)

## Antes de codificar

1. Lee `MEMORIA.md` (contexto permanente).
2. Lee **`docs/AVANCE_PROYECTO.md`** — primero «Resumen de 1 minuto», luego «Referencias persistentes» (variables, BD, endpoints); evita trabajo redundante.
3. Lee **`docs/MODULOS_ESTADO.md`** — qué falta por módulo (actualizar al cerrar cada tarea).
3. Para detalle: `INFRAESTRUCTURA/GUIA_DESARROLLO_FOODY_CURSOR.md`, `esquema_maestro_bd_v3.md`, `endpoints_api_foody.md`, `pantallas_flujo_principal_foody.md`, `reglas_negocio_foody.md`.
4. **Multi-sucursal (cada sede aislada):** `docs/MULTI_SUCURSAL.md` — leer antes de tocar admin, inventario, usuarios o guards. Regla Cursor: `.cursor/rules/foody-multi-sucursal.mdc`.
5. **Admin menú / costeo / ítems incluidos:** `docs/ADMIN_MENU_COSTEO.md` (**prioridad**). Fórmulas costeo: `docs/MODULO_COSTEO.md`.
6. **Flujos por rol:** `docs/MAPA_FLUJOS_PANTALLAS.md` + `INFRAESTRUCTURA/foody_flujo_completo_pantallas.html`.
7. **Planes comerciales (brecha):** `docs/PLANES_SUSCRIPCION.md` — hoy plan = metadata; restricciones por tier ⏳ pendiente.
7b. **Self-service / plan gratis / cobro Wompi:** `docs/MODULO_SELF_SERVICE_PLANES.md` — auto-registro, login Google, freemium, pasarela y fases F1–F7 (planificado).
8. **Analítica / BI (Centro de Análisis):** `docs/MODULO_ANALITICA_BI.md` — leer antes de tocar `reportes` o construir el módulo `analitica` (scope dueño/admin, fórmulas, fases).
9. Entorno local: `docs/ENTORNO_LOCAL.md`.

## Después de implementar

Actualiza **`docs/AVANCE_PROYECTO.md`** según `.cursor/rules/foody-avance-documentar.mdc` (estado, falta, por qué, cuándo, changelog). Si el cambio afecta el estado global de un módulo, actualiza también **`docs/MODULOS_ESTADO.md`**.

## Principio no negociable

**Flutter = solo UI.** **NestJS + PostgreSQL = cerebro.** No añadir lógica de negocio en Dart salvo formateo visual (fechas, moneda para mostrar strings ya calculados por el backend).

## Un solo proyecto (no fork)

- **No** crear otro repo, copia ni app paralela “Foody limpio”.
- **Sí** modificar este mismo workspace: cambiar, migrar y **eliminar** legacy cuando Foody lo reemplace.
- Entry point: `lib/main.dart`. Código nuevo en `lib/features/`. Regla Cursor: `.cursor/rules/foody-mismo-repositorio.mdc`.

## Estructura del repo (objetivo)

```
FOODY APP/
├── lib/                    # Flutter actual (transición desde Cancha Fácil)
├── foody_backend/          # NestJS API
├── foody_supabase/         # Migraciones SQL
├── foody_python_printer/   # Impresión local (futuro)
├── INFRAESTRUCTURA/        # Especificación (no borrar)
├── docs/                   # Entorno, procedimientos y avance vivo
│   ├── ENTORNO_LOCAL.md
│   ├── AVANCE_PROYECTO.md  # Estado por sprint (leer/actualizar siempre)
│   └── MODULO_COSTEO.md    # Spec módulo costeo industrial (planificado)
└── docker-compose.dev.yml  # Postgres + servicios de desarrollo
```

## Orden de implementación

Seguir sprints en la guía de desarrollo (Fase 0 → Fundación → Cliente → Pedidos → Admin…).

## Al trabajar en este repo legacy

- `reserva_canchas` / Provider / Firebase: código heredado de Tu Cancha Fácil.
- **Preferir adaptar** pantallas y servicios existentes (`lib/screens/`, animaciones, `ciudad_preference_service`, splash, FCM) cambiando solo datos → NestJS.
- `lib/features/` cuando no hay pantalla equivalente o el flujo legacy no aplica (reservas/canchas).
- No extender escritura directa a Supabase/Firestore para pedidos, caja o inventario.
- Reglas Cursor: `foody-reutilizar-base.mdc`, `foody-mismo-repositorio.mdc`.

## Sesiones recomendadas

Adjuntar `@MEMORIA.md` y `@docs/AVANCE_PROYECTO.md` al iniciar tareas grandes de arquitectura o pedidos.

## Agency Agents (personas opcionales)

Instalados desde [agency-agents](https://github.com/msitarzewski/agency-agents): **209 reglas** en `.cursor/rules/*.mdc` (p. ej. `@backend-architect`, `@code-reviewer`).

- Guía Foody: **`.cursor/AGENCY_AGENTS_FOODY.md`**
- Skill de índice: **`.cursor/skills/agency-agents/SKILL.md`**
- Actualizar: `.\scripts\actualizar-agency-agents.ps1`

Las reglas `foody-*.mdc` tienen prioridad; los agentes Agency se invocan con `@nombre` cuando hace falta un especialista.
