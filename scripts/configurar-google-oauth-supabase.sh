#!/usr/bin/env bash
# Foody - habilita Google OAuth en Supabase self-hosted (WSL).
set -euo pipefail

SUPABASE_DIR="${SUPABASE_DIR:-$HOME/supabase-docker}"
WSL_IP="${WSL_IP:-$(hostname -I | awk '{print $1}')}"
CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-}"
WEB_PORT="${FLUTTER_WEB_PORT:-8080}"

set_env() {
  local key="$1"
  local val="$2"
  if grep -q "^${key}=" "$SUPABASE_DIR/.env"; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$SUPABASE_DIR/.env"
  else
    echo "${key}=${val}" >> "$SUPABASE_DIR/.env"
  fi
}

if [ ! -f "$SUPABASE_DIR/.env" ]; then
  echo "ERROR: No existe $SUPABASE_DIR/.env - ejecuta scripts/setup-supabase-docker.sh primero."
  exit 1
fi

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "ERROR: Faltan GOOGLE_CLIENT_ID y GOOGLE_CLIENT_SECRET."
  exit 1
fi

COMPOSE="$SUPABASE_DIR/docker-compose.yml"
if [ ! -f "$COMPOSE" ]; then
  echo "ERROR: No existe $COMPOSE"
  exit 1
fi

echo "=== Foody: Google OAuth en Supabase ==="
echo "Supabase: $SUPABASE_DIR"
echo "IP WSL:   $WSL_IP"

sed -i 's|^[[:space:]]*# GOTRUE_EXTERNAL_GOOGLE_ENABLED:|      GOTRUE_EXTERNAL_GOOGLE_ENABLED:|' "$COMPOSE"
sed -i 's|^[[:space:]]*# GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID:|      GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID:|' "$COMPOSE"
sed -i 's|^[[:space:]]*# GOTRUE_EXTERNAL_GOOGLE_SECRET:|      GOTRUE_EXTERNAL_GOOGLE_SECRET:|' "$COMPOSE"
sed -i 's|^[[:space:]]*# GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI:|      GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI:|' "$COMPOSE"

REDIRECTS="http://localhost:${WEB_PORT}/admin/login,http://localhost:${WEB_PORT}/admin/registro,foody://login"

set_env "API_EXTERNAL_URL" "http://localhost:8000"
set_env "SUPABASE_PUBLIC_URL" "http://localhost:8000"
set_env "SITE_URL" "http://localhost:8000"
set_env "GOOGLE_ENABLED" "true"
set_env "GOOGLE_CLIENT_ID" "$CLIENT_ID"
set_env "GOOGLE_SECRET" "$CLIENT_SECRET"
set_env "ADDITIONAL_REDIRECT_URLS" "$REDIRECTS"

echo "ADDITIONAL_REDIRECT_URLS=$REDIRECTS"

cd "$SUPABASE_DIR"
echo "Recreando contenedor auth..."
docker compose up -d auth --force-recreate

echo "Esperando salud de auth..."
for i in $(seq 1 30); do
  if docker compose ps auth 2>/dev/null | grep -q healthy; then
    echo "supabase-auth: healthy"
    break
  fi
  sleep 2
done

echo ""
echo "=== Listo ==="
echo "Callback Google: http://localhost:8000/auth/v1/callback"
echo "Origen JS:       http://localhost:${WEB_PORT}"
echo "Prueba: app Equipo -> Continuar con Google"
