# SEC-RLIMIT-03 (geo/menu/ciudades) + INFRA-EXT-UI-03 (lock KDS en codigo).
# Uso: .\scripts\verificar-sec-rlimit-kds.ps1
# Requiere API en :3000. Para 429 en desarrollo reinicia con RATE_LIMIT_FORZAR=1.
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Base = 'http://localhost:3000/api/v1'
$fallos = 0

function Assert-Ok {
  param([bool]$Cond, [string]$Msg)
  if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
  else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

Write-Host '=== SEC-RLIMIT + INFRA-EXT-UI-03 ===' -ForegroundColor Cyan

$menuSrc = Get-Content -Raw (Join-Path $Root 'foody_backend\src\modulos\menu\menu.controller.ts')
$ciuSrc = Get-Content -Raw (Join-Path $Root 'foody_backend\src\modulos\ciudades\ciudades.controller.ts')
$geoSrc = Get-Content -Raw (Join-Path $Root 'foody_backend\src\modulos\geografia\geografia.controller.ts')
$kdsSrc = Get-Content -Raw (Join-Path $Root 'lib\features\cocinas\presentation\kds_screen.dart')
$guardSrc = Get-Content -Raw (Join-Path $Root 'foody_backend\src\compartido\guards\rate-limit.guard.ts')

Assert-Ok ($menuSrc -match 'RateLimitPublico') 'menu.controller RateLimitPublico'
Assert-Ok ($ciuSrc -match 'RateLimitPublico') 'ciudades.controller RateLimitPublico'
Assert-Ok ($geoSrc -match 'RateLimitPublico') 'geografia.controller RateLimitPublico'
Assert-Ok ($guardSrc -match 'RATE_LIMIT_FORZAR') 'guard RATE_LIMIT_FORZAR (SEC-RLIMIT-01)'
Assert-Ok ($kdsSrc -match '_itemsEnVuelo') 'kds_screen _itemsEnVuelo (INFRA-EXT-UI-03)'
Assert-Ok ($kdsSrc -match '_conLockItem') 'kds_screen _conLockItem'

try {
  $salud = Invoke-RestMethod -Uri "$Base/salud" -TimeoutSec 8
  Assert-Ok ([bool]$salud.exito) 'GET /salud'
} catch {
  Assert-Ok $false ('GET /salud: ' + $_.Exception.Message)
  Write-Host ('FAIL total=' + $fallos) -ForegroundColor Red
  exit 1
}

$compose = Join-Path $Root 'docker-compose.prod.yml'
$dockerfile = Join-Path $Root 'foody_backend\Dockerfile'
Assert-Ok (Test-Path $compose) 'docker-compose.prod.yml en workspace'
Assert-Ok (Test-Path $dockerfile) 'foody_backend/Dockerfile en workspace'

function Test-Ruta429 {
  param([string]$Path, [int]$MaxIntentos = 150)
  $headers = @{ 'x-forwarded-for' = '203.0.113.77' }
  for ($i = 0; $i -lt $MaxIntentos; $i++) {
    try {
      Invoke-WebRequest -Method Get -Uri ($Base + $Path) -Headers $headers -TimeoutSec 5 | Out-Null
    } catch {
      $code = 0
      if ($_.Exception.Response) {
        try { $code = [int]$_.Exception.Response.StatusCode.value__ } catch { }
      }
      if ($code -eq 429) { return $true }
    }
    Start-Sleep -Milliseconds 20
  }
  return $false
}

$forzar = [string]$env:RATE_LIMIT_FORZAR
Write-Host ('RATE_LIMIT_FORZAR actual=' + $forzar) -ForegroundColor DarkGray

$hitGeo = Test-Ruta429 '/geografia/buscar?q=bogota'
$hitCiu = Test-Ruta429 '/ciudades'
$sid = 'a0000000-0000-4000-8000-000000000001'
$hitMenu = Test-Ruta429 ("/menu/" + $sid)

if ($forzar -eq '1') {
  Assert-Ok $hitGeo 'geografia 429 con FORZAR=1'
  Assert-Ok $hitCiu 'ciudades 429 con FORZAR=1'
  Assert-Ok $hitMenu 'menu 429 con FORZAR=1'
} else {
  Write-Host '  SKIP 429 en vivo (sin RATE_LIMIT_FORZAR=1)' -ForegroundColor Yellow
  if ($hitGeo -or $hitCiu -or $hitMenu) {
    Write-Host '  NOTA: hubo 429 sin FORZAR (posible produccion)' -ForegroundColor DarkGray
  }
}

Push-Location $Root
try {
  $ana = & dart analyze lib/features/cocinas/presentation/kds_screen.dart 2>&1 | Out-String
  $sinError = $ana -notmatch '(?m)^  error'
  Assert-Ok $sinError 'dart analyze kds_screen (sin errors)'
  if (-not $sinError) { Write-Host $ana -ForegroundColor DarkGray }
} finally {
  Pop-Location
}

if ($fallos -gt 0) {
  Write-Host ('FAIL total=' + $fallos) -ForegroundColor Red
  exit 1
}
Write-Host 'OK verificar-sec-rlimit-kds' -ForegroundColor Green
exit 0
