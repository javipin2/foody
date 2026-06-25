# foody_backend

API **NestJS** — cerebro de Foody. Toda la lógica de negocio, transacciones y validaciones viven aquí.

## Inicio rápido

```bash
cp .env.example .env
# Editar .env (DATABASE_URL, Supabase, JWT)

# Postgres local
cd ..
docker compose -f docker-compose.dev.yml up -d db

cd foody_backend
npm install
npm run start:dev
```

Base URL: `http://localhost:3000/api/v1`

## Crear proyecto (primera vez)

Si esta carpeta aún no tiene código NestJS:

```bash
npm i -g @nestjs/cli
nest new . --skip-git
```

Seguir `INFRAESTRUCTURA/GUIA_DESARROLLO_FOODY_CURSOR.md` — Fase 0 y Fase 2.

## Documentación

- Endpoints: `../INFRAESTRUCTURA/endpoints_api_foody.md`
- Entorno: `../docs/ENTORNO_LOCAL.md`
