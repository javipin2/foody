#!/usr/bin/env bash
# Foody — preparación inicial del VPS de pruebas (Ubuntu 22.04)
# Ejecutar en Ubuntu: chmod +x scripts/setup-ubuntu-vps.sh && ./scripts/setup-ubuntu-vps.sh

set -euo pipefail

echo "=== Foody: setup VPS de desarrollo ==="

if ! command -v docker >/dev/null 2>&1; then
  echo "Instalando Docker..."
  sudo apt-get update
  sudo apt-get install -y docker.io docker-compose-plugin
  sudo usermod -aG docker "$USER" || true
  echo "Reinicia sesión si docker pide permisos de grupo."
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js no encontrado. Instala Node 20 LTS: https://nodejs.org/"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

echo "Levantando PostgreSQL de desarrollo..."
docker compose -f docker-compose.dev.yml up -d db

echo ""
echo "=== Listo (fase 1) ==="
echo "Postgres: localhost:5432  DB=foody_db  user=postgres  pass=foody_password_dev"
echo ""
echo "Siguientes pasos:"
echo "  1. Supabase self-hosted: ver docs/ENTORNO_LOCAL.md"
echo "  2. cd foody_backend && cp .env.example .env && npm install"
echo "  3. Anotar IP de esta máquina: ip -4 addr show | grep inet"
echo "  4. En Flutter usar http://TU_IP:3000/api/v1"
echo ""
