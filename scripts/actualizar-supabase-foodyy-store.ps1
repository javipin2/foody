# Actualiza Supabase Auth (WSL) con URLs de config/foody-entorno.env
# Uso: .\scripts\actualizar-supabase-foodyy-store.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

$bashScript = Join-Path $PSScriptRoot 'actualizar-supabase-foodyy-store.sh'
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
  Write-Host 'ERROR: WSL no disponible.' -ForegroundColor Red
  exit 1
}

$redirects = @(
  "$FoodyUrlApp/admin/login",
  "$FoodyUrlApp/admin/registro",
  "$FoodyUrlEquipo/admin/login",
  "$FoodyUrlEquipo/admin/registro",
  "http://localhost:$FoodyPuertoEquipo/admin/login",
  "http://localhost:$FoodyPuertoEquipo/admin/registro",
  "http://localhost:$FoodyPuertoCliente/",
  'foody://login'
) -join ','

Write-Host 'Actualizando Supabase en WSL (URLs + OAuth redirects)...' -ForegroundColor Cyan
Write-Host "  SITE_URL=$FoodyUrlEquipo"
Write-Host "  PUBLIC=$FoodyUrlSb"
Write-Host "  REDIRECTS=$redirects"

$wslPath = '/mnt/c/Users/javier/Videos/usb/FOODY APP/scripts/actualizar-supabase-foodyy-store.sh'
# Pasar vars al bash
$export = "export URL_SB='$FoodyUrlSb' URL_APP='$FoodyUrlApp' URL_EQUIPO='$FoodyUrlEquipo' REDIRECTS='$redirects'"
wsl -d Ubuntu bash -c "sed -i 's/\r$//' '$wslPath' && $export && bash '$wslPath'"

if ($LASTEXITCODE -ne 0) {
  Write-Host 'ERROR al actualizar o reiniciar Supabase' -ForegroundColor Red
  exit 1
}

Write-Host ''
Write-Host 'OK Supabase Auth con URLs del entorno' -ForegroundColor Green
Write-Host ''
Write-Host 'Google Cloud Console:' -ForegroundColor Yellow
Write-Host "  URI redireccion: $FoodyUrlSb/auth/v1/callback"
Write-Host "  Origen JS:       $FoodyUrlApp"
Write-Host "  Origen JS:       $FoodyUrlEquipo"
Write-Host ''
Write-Host 'Reinicia Nest si CORS cambio: node dist/main.js en foody_backend' -ForegroundColor Yellow
