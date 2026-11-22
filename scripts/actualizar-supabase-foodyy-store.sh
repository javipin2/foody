#!/usr/bin/env bash
# Foody — URLs en Supabase self-hosted (WSL). Vars desde sincronizar / ps1 wrapper.
set -euo pipefail

SUPABASE_DIR="${SUPABASE_DIR:-$HOME/supabase-docker}"
ENV_FILE="$SUPABASE_DIR/.env"

URL_SB="${URL_SB:-https://sb.foodyy.store}"
URL_APP="${URL_APP:-https://foodyy.store}"
URL_EQUIPO="${URL_EQUIPO:-https://equipo.foodyy.store}"
REDIRECTS="${REDIRECTS:-${URL_APP}/admin/login,${URL_APP}/admin/registro,${URL_EQUIPO}/admin/login,${URL_EQUIPO}/admin/registro,http://localhost:8080/admin/login,http://localhost:8080/admin/registro,foody://login}"

set_env() {
  local key="$1"
  local val="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
  else
    echo "${key}=${val}" >> "$ENV_FILE"
  fi
}

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: No existe $ENV_FILE"
  exit 1
fi

set_env SUPABASE_PUBLIC_URL "$URL_SB"
set_env API_EXTERNAL_URL "$URL_SB"
set_env SITE_URL "$URL_EQUIPO"
set_env ADDITIONAL_REDIRECT_URLS "$REDIRECTS"

grep -E '^SUPABASE_PUBLIC_URL=|^API_EXTERNAL_URL=|^SITE_URL=|^ADDITIONAL_REDIRECT_URLS=' "$ENV_FILE"

cd "$SUPABASE_DIR"
docker compose up -d auth --force-recreate

for i in $(seq 1 30); do
  if docker compose ps auth 2>/dev/null | grep -q healthy; then
    echo 'supabase-auth: healthy'
    break
  fi
  sleep 2
done

docker compose ps auth
