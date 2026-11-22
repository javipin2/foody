# Arranca cliente + equipo detrás del tunel (puertos/URLs = config/foody-entorno.env).
# Uso: .\scripts\iniciar-foody-subdominios.ps1

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
Set-Location $raiz
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

Write-Host '=== Foody subdominios (tunel) ===' -ForegroundColor Cyan
Write-Host "  $FoodyUrlApp         -> :$FoodyPuertoCliente  cliente" -ForegroundColor White
Write-Host "  $FoodyUrlEquipo  -> :$FoodyPuertoEquipo  equipo (+ superadmin)" -ForegroundColor White
Write-Host "  $FoodyUrlApi     -> :$FoodyPuertoApi  API" -ForegroundColor White
Write-Host "  $FoodyUrlSb      -> :$FoodyPuertoSb  Supabase" -ForegroundColor White
Write-Host ''

& (Join-Path $PSScriptRoot 'sincronizar-entorno.ps1') -Modo tunel

foreach ($p in @($FoodyPuertoEquipo, $FoodyPuertoCliente)) {
  $c = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($c) {
    Write-Host "Liberando :$p (PID $($c.OwningProcess))..." -ForegroundColor Yellow
    Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue
  }
}
Start-Sleep -Seconds 1

$tunel = Join-Path $PSScriptRoot 'iniciar-flutter-web-tunel.ps1'

Write-Host "Abriendo EQUIPO en ventana aparte (:$FoodyPuertoEquipo)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList @(
  '-NoProfile', '-ExecutionPolicy', 'Bypass',
  '-File', $tunel,
  '-Flavor', 'equipo',
  '-WebPort', "$FoodyPuertoEquipo",
  '-Device', 'web-server'
)

Start-Sleep -Seconds 2
Write-Host "Iniciando CLIENTE en esta ventana (:$FoodyPuertoCliente)..." -ForegroundColor Cyan
Write-Host "Superadmin: $FoodyUrlEquipo/admin/login -> panel Foody Control" -ForegroundColor DarkGray
Write-Host ''

& $tunel -Flavor cliente -WebPort $FoodyPuertoCliente -Device web-server
