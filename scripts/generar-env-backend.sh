#!/usr/bin/env bash
# Genera foody_backend/.env desde ~/supabase-docker/.env
set -eu

FOODY_ROOT="${FOODY_ROOT:-/mnt/c/Users/javier/Videos/usb/FOODY APP}"
ENV_OUT="$FOODY_ROOT/foody_backend/.env"
SUPA_ENV="$HOME/supabase-docker/.env"

if [ ! -f "$SUPA_ENV" ]; then
  echo "ERROR: No existe $SUPA_ENV — instala Supabase con scripts/setup-supabase-docker.sh"
  exit 1
fi

leer() { grep -m1 "^$1=" "$SUPA_ENV" | cut -d= -f2-; }

POOLER_TENANT_ID="$(leer POOLER_TENANT_ID)"
POSTGRES_PASSWORD="$(leer POSTGRES_PASSWORD)"
ANON_KEY="$(leer ANON_KEY)"
SERVICE_ROLE_KEY="$(leer SERVICE_ROLE_KEY)"
JWT_SECRET="$(leer JWT_SECRET)"
IP="$(hostname -I | awk '{print $1}')"

cat > "$ENV_OUT" << EOF
# Generado por scripts/generar-env-backend.sh — no commitear

DATABASE_URL=postgresql://postgres.${POOLER_TENANT_ID}:${POSTGRES_PASSWORD}@localhost:5432/postgres

SUPABASE_URL=http://${IP}:8000
SUPABASE_ANON_KEY=${ANON_KEY}
SUPABASE_SERVICE_KEY=${SERVICE_ROLE_KEY}

JWT_SECRET=${JWT_SECRET}
JWT_EXPIRACION=7d

FIREBASE_PROJECT_ID=foody-app
FIREBASE_PRIVATE_KEY=
FIREBASE_CLIENT_EMAIL=

PUERTO=3000
HOST=0.0.0.0
ENTORNO=desarrollo
WEBSOCKET_IMPRESION_PUERTO=3001
CORS_ORIGEN=*
EOF

echo "OK → $ENV_OUT"
echo "SUPABASE_URL=http://${IP}:8000"
