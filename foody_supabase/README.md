# Foody — migraciones PostgreSQL

Esquema maestro v3 en `INFRAESTRUCTURA/esquema_maestro_bd_v3.md`.

## Archivos

Ejecutar en orden numérico:

```
migrations/001_geografia.sql
…
migrations/012_seed_demo.sql
migrations/013_usuarios_hash_contrasena.sql
migrations/014_seed_admin_demo.sql
migrations/015_seed_pedidos_demo.sql
migrations/016_seed_mesa_pendiente.sql
```

**Staff demo:** `admin@foody.demo` / `123456`

## Supabase self-hosted (WSL)

```bash
cd "/mnt/c/Users/javier/Videos/usb/FOODY APP"

for f in foody_supabase/migrations/*.sql; do
  echo ">>> $f"
  docker exec -i supabase-db psql -U postgres -d postgres < "$f"
done
```

## Verificación rápida

```bash
docker exec supabase-db psql -U postgres -d postgres -c "SELECT slug FROM ciudades;"
docker exec supabase-db psql -U postgres -d postgres -c "SELECT nombre FROM productos;"
```

## NestJS y pooler

Si Postgres expone el puerto **5432** vía **Supavisor**, la URL debe usar:

```
postgresql://postgres.<POOLER_TENANT_ID>:<POSTGRES_PASSWORD>@localhost:5432/postgres
```

El `POOLER_TENANT_ID` está en `~/supabase-docker/.env` (por defecto `your-tenant-id`).
