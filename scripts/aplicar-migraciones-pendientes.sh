#!/usr/bin/env bash
# Aplica migraciones Foody 026–028 (bloques 1–4) en Supabase Postgres local.
set -euo pipefail

FOODY_ROOT="${FOODY_ROOT:-/mnt/c/Users/javier/Videos/usb/FOODY APP}"
MIGRATIONS_DIR="$FOODY_ROOT/foody_supabase/migrations"
CONTAINER="${POSTGRES_CONTAINER:-supabase-db}"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: contenedor $CONTAINER no está corriendo (Docker Desktop + Supabase)."
  exit 1
fi

PENDIENTES=(
  026_cocinas_kds.sql
  027_bloque2_dinero.sql
  028_bloque4_seguridad_rls.sql
  029_completar_rls_bloque4.sql
  030_fix_demo_operacion.sql
  031_paso1_demo_recetas.sql
  032_costeo_industrial.sql
  033_costeo_demo_subreceta_empaque.sql
)

for f in "${PENDIENTES[@]}"; do
  path="$MIGRATIONS_DIR/$f"
  if [ ! -f "$path" ]; then
    echo "ERROR: no existe $path"
    exit 1
  fi
  echo ">> $f"
  docker exec -i "$CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$path"
done

echo ""
echo "=== Verificación ==="
docker exec -i "$CONTAINER" psql -U postgres -d postgres -c \
  "SELECT column_name FROM information_schema.columns WHERE table_name='pedidos' AND column_name IN ('iva_porcentaje','iva_valor');"
docker exec -i "$CONTAINER" psql -U postgres -d postgres -c \
  "SELECT relname, relrowsecurity, relforcerowsecurity FROM pg_class WHERE relname='pedidos' AND relkind='r';"
docker exec -i "$CONTAINER" psql -U postgres -d postgres -c \
  "SELECT email FROM usuarios WHERE email IN ('cocina@foody.demo','super@foody.demo','admin@foody.demo') ORDER BY email;"
echo ""
echo "Migraciones 026–033 aplicadas."
