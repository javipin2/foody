# Sirve Flutter web para el tunel Cloudflare (puertos desde config/foody-entorno.env).
#
# Uso:
#   .\scripts\iniciar-flutter-web-tunel.ps1
#   .\scripts\iniciar-flutter-web-tunel.ps1 -Flavor cliente
#   .\scripts\iniciar-foody-subdominios.ps1

param(
  [ValidateSet('equipo', 'cliente')]
  [string]$Flavor = 'equipo',

  [int]$WebPort = 0,

  [ValidateSet('web-server', 'chrome', 'edge')]
  [string]$Device = 'web-server'
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

if ($WebPort -le 0) {
  $WebPort = if ($Flavor -eq 'cliente') { $FoodyPuertoCliente } else { $FoodyPuertoEquipo }
}

& (Join-Path $PSScriptRoot 'sincronizar-entorno.ps1') -Modo tunel

$hostHint = if ($Flavor -eq 'cliente') { $FoodyUrlApp } else { $FoodyUrlEquipo }

Write-Host ''
Write-Host "Flutter web flavor=$Flavor en :$WebPort ($hostHint)" -ForegroundColor Cyan
Write-Host "Device=$Device - deja esta ventana abierta. Hot restart: R" -ForegroundColor DarkGray
if ($Device -eq 'web-server') {
  Write-Host "Abre $hostHint en el navegador (no hace falta Chrome local)." -ForegroundColor Yellow
}
Write-Host ''

$ocup = Get-NetTCPConnection -LocalPort $WebPort -State Listen -ErrorAction SilentlyContinue |
  Select-Object -First 1
if ($ocup) {
  $pidOcup = [int]$ocup.OwningProcess
  Write-Host "Liberando :$WebPort (PID $pidOcup)..." -ForegroundColor Yellow
  Stop-Process -Id $pidOcup -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 1
}

& (Join-Path $PSScriptRoot 'flutter-run-flavor.ps1') `
  -Flavor $Flavor `
  -Device $Device `
  -WebPort $WebPort `
  -LiberarPuerto
