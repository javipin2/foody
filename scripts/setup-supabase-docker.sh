#!/usr/bin/env bash
# Ejecutar en Ubuntu: sed -i 's/\r$//' scripts/setup-supabase-docker.sh
# Foody — Supabase self-hosted (sin git clone completo)
set -euo pipefail

WSL_IP="${WSL_IP:-$(hostname -I | awk '{print $1}')}"
SUPABASE_DIR="${SUPABASE_DIR:-$HOME/supabase-docker}"
FOODY_ROOT="${FOODY_ROOT:-/mnt/c/Users/javier/Videos/usb/FOODY APP}"

echo "=== Foody: Supabase self-hosted ==="
echo "IP WSL: $WSL_IP"
echo "Directorio: $SUPABASE_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker no disponible en WSL. Abre Docker Desktop."
  exit 1
fi

echo "1) Liberar puerto 5432 (Postgres Foody dev)..."
if [ -d "$FOODY_ROOT" ]; then
  (cd "$FOODY_ROOT" && docker compose -f docker-compose.dev.yml down || true)
fi

echo "2) Limpiar contenedores Supabase previos..."
docker rm -f supabase-studio supabase-kong supabase-auth supabase-rest supabase-storage \
  supabase-meta supabase-analytics supabase-vector supabase-pooler supabase-edge-functions \
  realtime-dev.supabase-realtime supabase-db supabase-imgproxy 2>/dev/null || true

echo "3) Descargar carpeta docker/ de Supabase (tarball)..."
rm -rf "$SUPABASE_DIR"
mkdir -p "$SUPABASE_DIR"
cd "$SUPABASE_DIR"
curl -fsSL --retry 5 --retry-delay 3 -o supabase.tar.gz \
  https://github.com/supabase/supabase/archive/refs/heads/master.tar.gz
tar xzf supabase.tar.gz --strip-components=2 supabase-master/docker
rm -f supabase.tar.gz

echo "4) Generar secretos y claves..."
cp -n .env.example .env
chmod +x utils/generate-keys.sh utils/add-new-auth-keys.sh 2>/dev/null || true
sh utils/generate-keys.sh
if [ -f utils/add-new-auth-keys.sh ]; then
  sh utils/add-new-auth-keys.sh || true
fi

echo "5) URLs públicas para red local..."
sed -i "s|^SUPABASE_PUBLIC_URL=.*|SUPABASE_PUBLIC_URL=http://${WSL_IP}:8000|" .env
sed -i "s|^API_EXTERNAL_URL=.*|API_EXTERNAL_URL=http://${WSL_IP}:8000|" .env
sed -i "s|^SITE_URL=.*|SITE_URL=http://${WSL_IP}:8000|" .env

echo "5b) Descomentar Google OAuth en docker-compose (activar con scripts/configurar-google-oauth-supabase.ps1)..."
sed -i 's|^[[:space:]]*# GOTRUE_EXTERNAL_GOOGLE_ENABLED:|      GOTRUE_EXTERNAL_GOOGLE_ENABLED:|' docker-compose.yml
sed -i 's|^[[:space:]]*# GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID:|      GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID:|' docker-compose.yml
sed -i 's|^[[:space:]]*# GOTRUE_EXTERNAL_GOOGLE_SECRET:|      GOTRUE_EXTERNAL_GOOGLE_SECRET:|' docker-compose.yml
sed -i 's|^[[:space:]]*# GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI:|      GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI:|' docker-compose.yml

echo "6) Levantar stack Supabase (puede tardar varios minutos)..."
docker compose up -d

echo "7) Esperar salud de Kong..."
for i in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:8000/rest/v1/" -H "apikey: $(grep '^ANON_KEY=' .env | cut -d= -f2-)" >/dev/null 2>&1; then
    echo "Kong/API OK"
    break
  fi
  sleep 5
  if [ "$i" -eq 60 ]; then
    echo "ADVERTENCIA: API aún no responde; revisa: docker compose ps"
  fi
done

echo "8) Sincronizar foody_backend/.env ..."
if [ -f "$FOODY_ROOT/foody_backend/.env.example" ]; then
  ANON="$(grep '^ANON_KEY=' .env | cut -d= -f2-)"
  SERVICE="$(grep '^SERVICE_ROLE_KEY=' .env | cut -d= -f2-)"
  PG_PASS="$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)"
  JWT="$(grep '^JWT_SECRET=' .env | cut -d= -f2-)"

  cat > "$FOODY_ROOT/foody_backend/.env" <<EOF
# Generado por scripts/setup-supabase-docker.sh

DATABASE_URL=postgresql://postgres:${PG_PASS}@localhost:5432/postgres

SUPABASE_URL=http://${WSL_IP}:8000
SUPABASE_ANON_KEY=${ANON}
SUPABASE_SERVICE_KEY=${SERVICE}

JWT_SECRET=${JWT}
JWT_EXPIRACION=7d

FIREBASE_PROJECT_ID=foody-app
FIREBASE_PRIVATE_KEY=
FIREBASE_CLIENT_EMAIL=

PUERTO=3000
ENTORNO=desarrollo
WEBSOCKET_IMPRESION_PUERTO=3001
CORS_ORIGEN=*
EOF

  mkdir -p "$FOODY_ROOT/lib/core/constantes"
  cat > "$FOODY_ROOT/lib/core/constantes/configuracion.dart" <<EOF
/// Configuración local Foody (generada automáticamente).
class Configuracion {
  static const String urlBackend = 'http://${WSL_IP}:3000/api/v1';
  static const String urlSupabase = 'http://${WSL_IP}:8000';
  static const String supabaseAnonKey = '${ANON}';
  static const Duration timeoutConexion = Duration(seconds: 10);
  static const Duration timeoutRespuesta = Duration(seconds: 30);
}
EOF
fi

echo ""
echo "=== Supabase listo ==="
echo "API:    http://${WSL_IP}:8000"
echo "Studio: http://${WSL_IP}:8000 (vía Kong/dashboard)"
echo "Postgres (pooler): localhost:5432  user=postgres"
echo ""
docker compose ps
