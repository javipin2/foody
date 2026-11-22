# Checklist tras pegar TUNNEL_TOKEN. URLs = config/foody-entorno.env
# Uso: .\scripts\configurar-foodyy-store.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')
$envFile = Join-Path $PSScriptRoot 'cloudflare-tunnel.env'

Write-Host ''
Write-Host "=== $FoodyDominio — URLs Foody ===" -ForegroundColor Cyan
Write-Host "  App:      $FoodyUrlApp" -ForegroundColor White
Write-Host "  Equipo:   $FoodyUrlEquipo" -ForegroundColor White
Write-Host "  API:      $FoodyUrlApi/api/v1" -ForegroundColor White
Write-Host "  Supabase: $FoodyUrlSb" -ForegroundColor White
Write-Host ''

if (-not (Test-Path $envFile)) {
  Copy-Item (Join-Path $PSScriptRoot 'cloudflare-tunnel.env.example') $envFile
  Write-Host "Creado $envFile — pega TUNNEL_TOKEN y vuelve a ejecutar." -ForegroundColor Yellow
  exit 1
}

$raw = Get-Content $envFile -Raw
if ($raw -match 'TUNNEL_TOKEN=\s*$' -or $raw -notmatch 'TUNNEL_TOKEN=\S{20,}') {
  Write-Host 'Falta TUNNEL_TOKEN en cloudflare-tunnel.env' -ForegroundColor Red
  Write-Host "Dashboard → Networks → Tunnels → $FoodyTunnelNombre → Instalar conector → copiar token" -ForegroundColor Yellow
  exit 1
}

& (Join-Path $PSScriptRoot 'sincronizar-entorno.ps1') -Modo tunel
& (Join-Path $PSScriptRoot 'actualizar-supabase-foodyy-store.ps1')

Write-Host ''
Write-Host 'Backend .env (Wompi tip):' -ForegroundColor Magenta
Write-Host "  WOMPI_REDIRECT_URL=$FoodyUrlEquipo/admin/panel?seccion=mejorar_plan"
Write-Host ''
Write-Host 'Arranque: .\scripts\iniciar-foody-subdominios.bat' -ForegroundColor Cyan
Write-Host 'Doc: docs/CONFIG_ENTORNO_FOODY.md' -ForegroundColor DarkGray
