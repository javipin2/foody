# Regenera e instala reglas Cursor desde agency-agents
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Vendor = Join-Path $Root ".vendor\agency-agents"

if (-not (Test-Path $Vendor)) {
    Write-Host "Clonando agency-agents..."
    git clone --depth 1 https://github.com/msitarzewski/agency-agents.git $Vendor
} else {
    Write-Host "Actualizando agency-agents..."
    Push-Location $Vendor
    git pull --ff-only
    Pop-Location
}

Write-Host "Convirtiendo para Cursor..."
bash -lc "cd '$($Vendor -replace '\\','/')' && ./scripts/convert.sh --tool cursor"

Write-Host "Instalando en .cursor/rules..."
Push-Location $Root
bash -lc "./.vendor/agency-agents/scripts/install.sh --tool cursor --no-interactive"
Pop-Location

Write-Host "Listo. Ver .cursor/AGENCY_AGENTS_FOODY.md para agentes utiles en Foody."
