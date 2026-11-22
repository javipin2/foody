# Preflight: todo lo adelantable en PC+tunel antes de comprar VPS.
# Uso:
#   .\scripts\verificar-listo-vps.ps1
#   .\scripts\verificar-listo-vps.ps1 -SinDocker

param([switch]$SinDocker)

$ErrorActionPreference = 'Continue'
$raiz = Split-Path $PSScriptRoot -Parent
Set-Location $raiz
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

$fallos = 0
$avisos = 0

function Ok([string]$m) { Write-Host "OK $m" -ForegroundColor Green }
function Fail([string]$m) { Write-Host "FAIL $m" -ForegroundColor Red; $script:fallos++ }
function Aviso([string]$m) { Write-Host "AVISO $m" -ForegroundColor Yellow; $script:avisos++ }

Write-Host '=== verificar-listo-vps (PC + tunel) ===' -ForegroundColor Cyan
Write-Host "dominio=$FoodyDominio modo=$FoodyModo" -ForegroundColor DarkGray

# 1) Entorno
& (Join-Path $PSScriptRoot 'sincronizar-entorno.ps1') -Modo tunel | Out-Null
$dart = Get-Content (Join-Path $raiz 'lib\core\constantes\configuracion.dart') -Raw -Encoding UTF8
if ($dart -match 'usarTunel = true' -and $dart.Contains("hostApi = '$FoodyUrlApi'")) { Ok 'Flutter usarTunel + hostApi' }
else { Fail 'Flutter no alineado — sincronizar-entorno.ps1' }

# 2) Backend .env (sin imprimir secretos)
$envPath = Join-Path $raiz 'foody_backend\.env'
if (-not (Test-Path $envPath)) { Fail 'falta foody_backend/.env' }
else {
  $raw = Get-Content $envPath -Raw -Encoding UTF8
  if ($raw -match '(?m)^DB_POOL_MAX=(\d+)' -and [int]$Matches[1] -ge 20) { Ok "DB_POOL_MAX=$($Matches[1])" }
  else { Fail 'DB_POOL_MAX debe ser >= 20 (recomendado 25)' }

  $wantCorsApp = $FoodyUrlApp
  $wantCorsEq = $FoodyUrlEquipo
  $corsLine = ($raw -split "`n" | Where-Object { $_ -match '^CORS_ORIGEN=' } | Select-Object -First 1)
  if ($corsLine -and $corsLine.Contains($wantCorsApp) -and $corsLine.Contains($wantCorsEq)) { Ok 'CORS incluye app+equipo' }
  else { Fail 'CORS_ORIGEN incompleto' }

  $wantW = "$FoodyUrlApi/api/v1/pagos/retorno-app"
  if ($raw -match [regex]::Escape("WOMPI_REDIRECT_URL=$wantW")) { Ok 'WOMPI_REDIRECT_URL' }
  else { Fail 'WOMPI_REDIRECT_URL no alineado (esperado bridge retorno-app)' }
}

# 3) Tunel token file (existencia, no contenido)
$cfEnv = Join-Path $PSScriptRoot 'cloudflare-tunnel.env'
if (Test-Path $cfEnv) {
  $cf = Get-Content $cfEnv -Raw
  if ($cf -match 'TUNNEL_TOKEN=\S{20,}') { Ok 'cloudflare-tunnel.env tiene TUNNEL_TOKEN' }
  else { Aviso 'cloudflare-tunnel.env sin token (arranque tunel fallara)' }
} else { Aviso 'falta scripts/cloudflare-tunnel.env' }

# 4) Backup scripts
if (Test-Path (Join-Path $PSScriptRoot 'backup-postgres.ps1')) { Ok 'backup-postgres.ps1' } else { Fail 'falta backup-postgres.ps1' }
if (Test-Path (Join-Path $PSScriptRoot 'backup-postgres.sh')) { Ok 'backup-postgres.sh' } else { Fail 'falta backup-postgres.sh' }
if (Test-Path (Join-Path $PSScriptRoot 'programar-backup-windows.ps1')) { Ok 'programar-backup-windows.ps1' } else { Aviso 'falta programar-backup-windows.ps1' }

# 5) Salud local + publica
try {
  $s = Invoke-RestMethod "http://localhost:$FoodyPuertoApi/api/v1/salud" -TimeoutSec 5
  if ($s.exito) { Ok "API local :$FoodyPuertoApi /salud" } else { Fail 'API local exito=false' }
} catch { Fail "API local :$FoodyPuertoApi no responde" }

try {
  $h = Invoke-RestMethod "$FoodyUrlApi/api/v1/health" -TimeoutSec 15
  if ($h.exito -and $h.datos.base_datos -eq $true) { Ok "API publica /health (base_datos)" }
  elseif ($h.exito) { Aviso 'API publica /health sin base_datos=true' }
  else { Fail 'API publica /health exito=false' }
} catch { Fail "API publica $FoodyUrlApi/health" }

# 6) Wompi tunel
& (Join-Path $PSScriptRoot 'verificar-wompi-tunel.ps1') | Out-Null
if ($LASTEXITCODE -eq 0) { Ok 'verificar-wompi-tunel' } else { Fail 'verificar-wompi-tunel' }

# 7) Docker prod (opcional)
if (-not $SinDocker) {
  $compose = Join-Path $raiz 'docker-compose.prod.yml'
  if (-not (Test-Path $compose)) { Fail 'falta docker-compose.prod.yml' }
  else {
    $vd = Join-Path $PSScriptRoot 'verificar-docker-prod.ps1'
    if (Test-Path $vd) {
      & $vd | Out-Null
      if ($LASTEXITCODE -eq 0) { Ok 'verificar-docker-prod' } else { Aviso 'verificar-docker-prod fallo (revisar Docker Desktop)' }
    } else { Aviso 'no hay verificar-docker-prod.ps1' }
  }
} else {
  Write-Host 'SKIP docker prod (-SinDocker)' -ForegroundColor DarkGray
}

# 8) Acciones humanas
Write-Host ''
Write-Host 'Acciones humanas (no bloquean exit si el resto OK):' -ForegroundColor Cyan
Write-Host "  - UptimeRobot -> $FoodyUrlApi/api/v1/health keyword base_datos:true"
Write-Host "  - Wompi Eventos -> $FoodyUrlApi/api/v1/pagos/webhook-wompi"
Write-Host '  - Comprar VPS -> docs/PREPARACION_VPS.md Fase 1'

Write-Host ''
if ($fallos -eq 0) {
  Write-Host "verificar-listo-vps OK (avisos=$avisos)" -ForegroundColor Green
  exit 0
}
Write-Host "verificar-listo-vps FALLOS=$fallos avisos=$avisos" -ForegroundColor Red
exit 1
