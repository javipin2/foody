# Foody (base de desarrollo)

Plataforma **SaaS POS** para restaurantes. Este repositorio parte de **Tu Cancha Fácil** y evoluciona hacia Foody.

## Documentación

| Recurso | Descripción |
|---------|-------------|
| [MEMORIA.md](MEMORIA.md) | Contexto permanente para Cursor (`@MEMORIA.md`) |
| [AGENTS.md](AGENTS.md) | Instrucciones para agentes |
| [docs/ENTORNO_LOCAL.md](docs/ENTORNO_LOCAL.md) | VPS Ubuntu, Docker, Supabase self-hosted, NestJS |
| [INFRAESTRUCTURA/](INFRAESTRUCTURA/) | Especificación completa (BD, API, pantallas, reglas) |

## Reglas de arquitectura

- **Flutter**: solo interfaz (muestra datos, envía acciones).
- **NestJS**: cerebro (cálculos, transacciones, validaciones).
- **PostgreSQL** vía Supabase self-hosted en VPS de pruebas (tu PC con Ubuntu).

## Estructura

```
lib/                 # Flutter (transición)
foody_backend/       # NestJS (crear con nest new)
foody_supabase/      # Migraciones SQL
foody_python_printer/ # Impresión local
INFRAESTRUCTURA/     # Specs
.cursor/rules/       # Reglas Cursor
```

## Inicio rápido

**Windows (Flutter):** abrir en Cursor; reglas ya cargadas desde `.cursor/rules/`.

**Ubuntu (VPS pruebas):**

```bash
./scripts/setup-ubuntu-vps.sh
# Ver docs/ENTORNO_LOCAL.md para Supabase completo y NestJS
```

## App legacy

El paquete Flutter sigue como `reserva_canchas` hasta renombrar/migrar a Riverpod + `features/`.
