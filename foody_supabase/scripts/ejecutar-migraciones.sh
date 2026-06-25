#!/usr/bin/env bash
# Ejecuta migraciones Foody en Postgres (Supabase self-hosted)
set -euo pipefail

FOODY_ROOT="${FOODY_ROOT:-/mnt/c/Users/javier/Videos/usb/FOODY APP}"
MIGRATIONS_DIR="$FOODY_ROOT/foody_supabase/migrations"
CONTAINER="${POSTGRES_CONTAINER:-supabase-db}"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: contenedor $CONTAINER no está corriendo."
  exit 1
fi

for f in $(ls "$MIGRATIONS_DIR"/*.sql 2>/dev/null | sort); do
  echo ">> $(basename "$f")"
  docker exec -i "$CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$f"
done

echo ""
echo "=== Migraciones completadas ==="
docker exec -i "$CONTAINER" psql -U postgres -d postgres -c \
  "SELECT count(*) AS tablas_foody FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';"
