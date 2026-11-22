# Foody — guía para agentes (Cursor)

## Antes de codificar

1. Lee `MEMORIA.md` (contexto permanente).
2. Lee **`docs/MASTER_STATUS.md`** — estado oficial consolidado.
3. Lee **`docs/PRIORIDADES_FOODY.md`** — lista viva A→F (qué hacer arriba→abajo; tachar avance).
4. Lee **`docs/INFORME_MAESTRO_FOODY.md`** — cola de corrección F0–F8 (hallazgos priorizados).
5. Lee **`docs/ROADMAP_TERMINAR_FOODY.md`** — checklist P0→P3.
6. Lee **`docs/AVANCE_PROYECTO.md`** — referencias persistentes (BD, env, endpoints).
7. Índice: **`docs/README.md`**
8. **Trabajo Flutter:** **`docs/frontend/FRONTEND_ROADMAP.md`** + **`docs/frontend/FRONTEND_INSTRUCCIONES.md`**. Flavors/QA: **`docs/ESTRATEGIA_BACKEND_PRIMERO.md`**.
9. **Detalle forense de un ID** (solo al implementar ese fix): `docs/archivo/auditorias-prompts/` (índice en su README).

## Después de implementar

Actualiza **`docs/MASTER_STATUS.md`** y **`docs/AVANCE_PROYECTO.md`** según `.cursor/rules/foody-avance-documentar.mdc`.  
Si cierra un ítem del informe maestro, márcalo en **`docs/INFORME_MAESTRO_FOODY.md`**.  
Checkbox P0–P3 en **`docs/ROADMAP_TERMINAR_FOODY.md`** si aplica.  
`docs/MODULOS_ESTADO.md` es secundario a MASTER (no duplicar fixes ahí).

## Principio no negociable

**Flutter = solo UI.** **NestJS + PostgreSQL = cerebro.** No añadir lógica de negocio en Dart salvo formateo visual (fechas, moneda para mostrar strings ya calculados por el backend).

**Verificar antes de entregar:** reglas `.cursor/rules/foody-verificar-antes-entregar.mdc` + `.cursor/rules/foody-sesion-completa-antes-entregar.mdc` — evidencia real backend+frontend+UX juntos; no declarar hecho sin probar.

**Riesgos de producción:** `.cursor/rules/foody-riesgos-produccion.mdc` — si un fallo puede tumbar API/DB/caja en prod, corregir + documentar; no confundir con DX local (p. ej. puerto `dartvm` 8080).

## Un solo proyecto (no fork)

- **No** crear otro repo, copia ni app paralela “Foody limpio”.
- **Sí** modificar este mismo workspace: cambiar, migrar y **eliminar** legacy cuando Foody lo reemplace.
- Entry point: `lib/main.dart`. Código nuevo en `lib/features/`. Regla Cursor: `.cursor/rules/foody-mismo-repositorio.mdc`.

## Estructura del repo (objetivo)

```
FOODY APP/
├── lib/                    # Flutter
├── foody_backend/          # NestJS API
├── foody_supabase/         # Migraciones SQL
├── foody_python_printer/   # Impresión local
├── INFRAESTRUCTURA/        # Especificación (no borrar)
├── docs/
│   ├── README.md           # Hub corto
│   ├── MASTER_STATUS.md    # Estado oficial
│   ├── INFORME_MAESTRO_FOODY.md  # Cola F0–F8
│   ├── ROADMAP_TERMINAR_FOODY.md
│   ├── AVANCE_PROYECTO.md
│   └── archivo/auditorias-prompts/  # Evidencia forense (no status)
└── docker-compose.dev.yml
```

## Orden de implementación

Seguir sprints en la guía de desarrollo (Fase 0 → Fundación → Cliente → Pedidos → Admin…). Prioridad de bugs: **INFORME_MAESTRO** F0 primero.

## Al trabajar en este repo legacy

- `reserva_canchas` / Provider / Firebase: código heredado de Tu Cancha Fácil.
- **Preferir adaptar** pantallas y servicios existentes cambiando solo datos → NestJS.
- `lib/features/` cuando no hay pantalla equivalente.
- No extender escritura directa a Supabase/Firestore para pedidos, caja o inventario.
- Reglas Cursor: `foody-reutilizar-base.mdc`, `foody-mismo-repositorio.mdc`.

## Sesiones recomendadas

Adjuntar `@MEMORIA.md`, `@docs/MASTER_STATUS.md`, `@docs/PRIORIDADES_FOODY.md`, `@docs/INFORME_MAESTRO_FOODY.md` y `@docs/AVANCE_PROYECTO.md` al iniciar tareas grandes.

## Agency Agents (personas opcionales)

Instalados desde [agency-agents](https://github.com/msitarzewski/agency-agents): **209 reglas** en `.cursor/rules/*.mdc` (p. ej. `@backend-architect`, `@code-reviewer`).

- Guía Foody: **`.cursor/AGENCY_AGENTS_FOODY.md`**
- Skill de índice: **`.cursor/skills/agency-agents/SKILL.md`**
- Actualizar: `.\scripts\actualizar-agency-agents.ps1`

Las reglas `foody-*.mdc` tienen prioridad; los agentes Agency se invocan con `@nombre` cuando hace falta un especialista.

## Ponytail (código mínimo / YAGNI)

Instalado desde [ponytail](https://github.com/DietrichGebert/ponytail): regla **`.cursor/rules/ponytail.mdc`** (`alwaysApply: true`).

- Complementa (no reemplaza) las reglas `foody-*`: prefiere el diff más corto, reutilizar lo existente, sin dependencias nuevas salvo necesidad.
- **No relaja:** validación en límites de confianza, seguridad, accesibilidad, reglas de negocio en NestJS (Flutter solo UI).
- Actualizar: `.\scripts\actualizar-ponytail.ps1`
- En Cursor no hay comandos `/ponytail`; la regla aplica en cada sesión de agente.
