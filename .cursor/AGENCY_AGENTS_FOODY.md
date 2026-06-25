# Agency Agents — guía para Foody

Instalados desde [agency-agents](https://github.com/msitarzewski/agency-agents) como **reglas Cursor** en `.cursor/rules/*.mdc` (209 agentes). Las reglas Foody (`foody-*.mdc`) siguen con prioridad (`alwaysApply: true`); los agentes de The Agency se activan **bajo demanda**.

## Cómo activar un agente

En el chat de Cursor, menciona la regla con `@`:

```
@backend-architect Revisa el módulo de pedidos NestJS
@database-optimizer Índices para listado de pedidos por sucursal
@code-reviewer Revisa este PR antes de merge
```

También puedes escribir: *«Actúa como @frontend-developer»* o *«Usa el agente @security-architect»*.

## Agentes recomendados por tarea (Foody)

| Necesidad | Regla `@` | Cuándo |
|-----------|-----------|--------|
| Flutter / UI cliente | `frontend-developer` | Pantallas, widgets, Riverpod, rendimiento |
| NestJS / API | `backend-architect` | Módulos, guards, transacciones, diseño API |
| PostgreSQL / migraciones | `database-optimizer` | Esquema, índices, queries lentas, RLS (Bloque 4) |
| Arquitectura general | `software-architect` | Decisiones de capas, DDD, trade-offs |
| Cambios mínimos | `minimal-change-engineer` | Fixes puntuales sin scope creep |
| Code review | `code-reviewer` | PRs, calidad, seguridad básica |
| Tests / QA | `api-tester`, `test-results-analyzer` | Endpoints, regresiones |
| Seguridad | `security-architect`, `penetration-tester` | RLS, auth, hardening |
| DevOps / Docker | `devops-automator`, `sre-site-reliability-engineer` | CI, despliegue, observabilidad |
| Documentación | `technical-writer` | API docs, runbooks |
| Onboarding código | `codebase-onboarding-engineer` | Explicar flujos legacy vs `lib/features/` |
| UX / diseño Foody | `ui-designer`, `ux-researcher` | Mejoras cliente (Bloque 5) |
| Git / PRs | `git-workflow-master` | Commits, branches, releases |
| Incidentes prod | `incident-response-commander` | Caídas API, pedidos atascados |
| Realidad / scope | `reality-checker` | Validar que no sobre-ingenieríes |
| Sprint / prioridades | `sprint-prioritizer`, `project-shepherd` | Ordenar backlog vs `PLAN_COMPLETAR_FOODY.md` |

## Reglas Foody vs Agency

| Tipo | Archivos | Comportamiento |
|------|----------|----------------|
| **Foody (proyecto)** | `foody-*.mdc` | Siempre activas — stack, avance, legacy |
| **Agency (opcionales)** | resto de `.mdc` | `alwaysApply: false` — solo cuando las invocas |

No contradigas las reglas Foody (Flutter solo UI, un repo, NestJS cerebro, español).

## Actualizar agentes

```powershell
cd "FOODY APP"
.\scripts\actualizar-agency-agents.ps1
```

Fuente clonada en `.vendor/agency-agents/` (no commitear; regenera reglas en `.cursor/rules/`).

## Licencia

MIT — ver `.vendor/agency-agents/LICENSE`.
