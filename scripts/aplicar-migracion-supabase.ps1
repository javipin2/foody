# Aplica una migración SQL al contenedor Supabase local (supabase-db / postgres).
# Uso: .\scripts\aplicar-migracion-supabase.ps1 057_storage_bucket_foody_assets.sql

param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Archivo
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$sqlPath = Join-Path $repo "foody_supabase\migrations\$Archivo"

if (-not (Test-Path $sqlPath)) {
  Write-Error "No existe: $sqlPath"
}

$contenedor = 'supabase-db'
$existe = docker ps --format '{{.Names}}' | Select-String -Pattern "^$contenedor$"
if (-not $existe) {
  Write-Error "Contenedor '$contenedor' no está en ejecución. Levanta Supabase/Docker primero."
}

Write-Host "Aplicando $Archivo en $contenedor (base postgres)..." -ForegroundColor Cyan
Get-Content $sqlPath -Raw | docker exec -i $contenedor psql -U postgres -d postgres -v ON_ERROR_STOP=1
Write-Host "OK: $Archivo" -ForegroundColor Green
