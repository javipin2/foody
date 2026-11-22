#!/usr/bin/env bash
# Foody — bootstrap VPS Ubuntu (Fase 1). Ejecutar EN el servidor.
# Uso: chmod +x scripts/setup-ubuntu-vps.sh && ./scripts/setup-ubuntu-vps.sh
# Previo en PC: .\scripts\verificar-listo-vps.ps1  · docs/PREPARACION_VPS.md

set -euo pipefail

echo "=== Foody: setup VPS (Ubuntu) ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f config/foody-entorno.env ]]; then
  if [[ -f config/foody-entorno.env.example ]]; then
    cp config/foody-entorno.env.example config/foody-entorno.env
    echo "Creado config/foody-entorno.env desde example — revisa DOMINIO/puertos."
  else
    echo "ERROR: falta config/foody-entorno.env"
    exit 1
  fi
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Instalando Docker..."
  sudo apt-get update
  sudo apt-get install -y docker.io docker-compose-plugin curl
  sudo usermod -aG docker "$USER" || true
  echo "AVISO: cierra sesion SSH y vuelve a entrar para usar docker sin sudo."
fi

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared no esta en PATH."
  echo "  Instala: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
  echo "  Token: copia scripts/cloudflare-tunnel.env desde el PC (no commitear)."
fi

if [[ ! -f foody_backend/.env ]]; then
  echo "ERROR: falta foody_backend/.env — copialo desde el PC (scp) antes del compose."
  exit 1
fi

echo ""
echo "Checklist manual (no automatico aqui):"
echo "  1) Stack Supabase self-hosted arriba (docs/ENTORNO_LOCAL.md)"
echo "  2) Migraciones SQL aplicadas"
echo "  3) En foody_backend/.env: ENTORNO=produccion, JWT_SECRET fuerte, DB_POOL_MAX=25"
echo "  4) docker compose -f docker-compose.prod.yml up -d --build"
echo "  5) cloudflared service con TUNNEL_TOKEN (apagar el del PC)"
echo "  6) Servir web release :8080/:8081 (o Nginx) segun foody-entorno.env"
echo "  7) Cron backup:"
echo "       chmod +x scripts/backup-postgres.sh"
echo "       0 3 * * * DESTINO=/var/backups/foody RETENCION_DIAS=14 $ROOT_DIR/scripts/backup-postgres.sh >> /var/log/foody-backup.log 2>&1"
echo "  8) Probar: curl -sS https://api.\$(grep ^DOMINIO= config/foody-entorno.env | cut -d= -f2)/api/v1/salud"
echo ""
echo "=== setup-ubuntu-vps: prerequisitos Docker listos ==="
echo "Sigue PREPARACION_VPS.md Fase 1 pasos 5–13."
