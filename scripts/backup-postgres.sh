#!/usr/bin/env bash
# Backup PostgreSQL Foody (VPS / Ubuntu).
# Uso:
#   ./scripts/backup-postgres.sh
#   DESTINO=/var/backups/foody RETENCION_DIAS=14 ./scripts/backup-postgres.sh
# Cron (ejemplo 03:00):
#   0 3 * * * /opt/foody/scripts/backup-postgres.sh >> /var/log/foody-backup.log 2>&1
#
# Offsite (opcional, tras dump):
#   R2_REMOTE=foody-r2 R2_PATH=backups ./scripts/backup-postgres.sh
#   (requiere rclone remoto configurado)

set -euo pipefail

CONTENEDOR="${CONTENEDOR:-supabase-db}"
DB="${DB:-postgres}"
USUARIO="${USUARIO:-postgres}"
RETENCION_DIAS="${RETENCION_DIAS:-14}"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DESTINO="${DESTINO:-$RAIZ/backups}"

mkdir -p "$DESTINO"
STAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVO="$DESTINO/foody_db-$STAMP.sql.gz"

echo "=== Backup PostgreSQL -> $ARCHIVO ==="

if docker ps --filter "name=^${CONTENEDOR}$" --format '{{.Names}}' | grep -qx "$CONTENEDOR"; then
  docker exec "$CONTENEDOR" pg_dump -U "$USUARIO" -d "$DB" --no-owner --no-acl \
    | gzip -c > "$ARCHIVO"
else
  if ! command -v pg_dump >/dev/null 2>&1; then
    echo "ERROR: no hay contenedor $CONTENEDOR ni pg_dump en PATH" >&2
    exit 1
  fi
  PGPASSWORD="${PGPASSWORD:-}" pg_dump -h "${PGHOST:-localhost}" -U "$USUARIO" -d "$DB" \
    --no-owner --no-acl | gzip -c > "$ARCHIVO"
fi

BYTES="$(wc -c < "$ARCHIVO" | tr -d ' ')"
if [[ "$BYTES" -lt 100 ]]; then
  echo "ERROR: dump demasiado pequeño ($BYTES bytes)" >&2
  exit 1
fi
echo "OK backup ($BYTES bytes)"

# Retención local
find "$DESTINO" -maxdepth 1 -type f -name 'foody_db-*.sql*' -mtime "+$RETENCION_DIAS" -delete 2>/dev/null || true
echo "Retención: borrados dumps > ${RETENCION_DIAS} días en $DESTINO"

# Offsite opcional (rclone)
if [[ -n "${R2_REMOTE:-}" ]]; then
  R2_PATH="${R2_PATH:-backups}"
  if ! command -v rclone >/dev/null 2>&1; then
    echo "ERROR: R2_REMOTE definido pero rclone no está instalado" >&2
    exit 1
  fi
  rclone copy "$ARCHIVO" "${R2_REMOTE}:${R2_PATH}/" --quiet
  echo "OK offsite -> ${R2_REMOTE}:${R2_PATH}/$(basename "$ARCHIVO")"
fi
