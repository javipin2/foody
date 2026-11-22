---
name: agency-agents
description: >-
  Activates specialized AI agents from The Agency (agency-agents) installed as
  Codex rules in .cursor/rules/. Use when the user wants a specific expert
  persona (backend architect, code reviewer, database optimizer, security,
  DevOps, UX, etc.) or mentions @agent-name, agency-agents, or The Agency.
---

# Agency Agents (Foody)

The Agency roster is installed as **209 Codex rules** in `.cursor/rules/*.mdc`.
They do not auto-apply; invoke them explicitly.

## Quick steps

1. Read the Foody mapping: [.cursor/AGENCY_AGENTS_FOODY.md](../AGENCY_AGENTS_FOODY.md)
2. Pick the rule slug (e.g. `backend-architect`, `database-optimizer`)
3. Follow that rule's instructions while respecting **foody-*.mdc** project rules

## Foody defaults

| Task | Prefer rule |
|------|-------------|
| NestJS / pedidos / caja | `@backend-architect` |
| Flutter cliente/admin | `@frontend-developer` |
| SQL / migraciones / RLS | `@database-optimizer` |
| Review before merge | `@code-reviewer` |
| Small targeted fix | `@minimal-change-engineer` |
| Bloque 4 seguridad | `@security-architect` |
| Bloque 5 UX cliente | `@ui-designer`, `@ux-researcher` |

## Invocation

User can type `@rule-name` in Codex chat. Apply the matching `.mdc` personality
and deliverables for that agent.

## Do not

- Override Foody stack (Flutter + NestJS + PostgreSQL only)
- Enable `alwaysApply: true` on agency rules (clutters context)
- Use marketing/game agents for Foody POS unless user explicitly asks
