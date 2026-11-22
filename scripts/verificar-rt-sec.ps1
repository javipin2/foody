# RT-SEC-01 / Bloque B1 — topics staff HMAC + login trae realtime_canales
# Uso: .\scripts\verificar-rt-sec.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

Write-Host '=== Verificar RT-SEC (Bloque B1) ===' -ForegroundColor Cyan

$fallos = 0
function Ok([string]$m) { Write-Host "  OK  $m" -ForegroundColor Green }
function Fail([string]$m) { Write-Host "  FALLO  $m" -ForegroundColor Red; $script:fallos++ }

try {
  $null = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
  Ok 'API /salud'
} catch {
  Fail "API caida: $_"
  exit 1
}

Write-Host ''
Write-Host '--- Login staff + realtime_canales ---' -ForegroundColor Yellow
$login = Invoke-RestMethod -Uri "$script:FoodyQaBase/auth/login" -Method Post -ContentType 'application/json' -Body (@{
  email = 'admin@foody.demo'
  contrasena = '123456'
} | ConvertTo-Json) -TimeoutSec 20

$datos = if ($login.datos) { $login.datos } else { $login }
if (-not $datos.token) { Fail 'login sin token'; exit 1 }
Ok 'login admin demo'

$canales = $datos.realtime_canales
if (-not $canales -or -not $canales.sucursal) {
  Fail 'login sin realtime_canales.sucursal'
} else {
  $t = [string]$canales.sucursal
  if ($t -match '^sucursal_[0-9a-f-]{36}_[0-9a-f]{16}$') {
    Ok "topic sucursal HMAC ($t)"
  } else {
    Fail "formato topic inesperado: $t"
  }
  if ($t -eq "sucursal_$($datos.usuario.sucursal_id)") {
    Fail 'topic sigue siendo adivinable (sin firma)'
  } else {
    Ok 'topic no es sucursal_{uuid} plano'
  }
}

Write-Host ''
Write-Host '--- Script canales (HMAC + leak anon) ---' -ForegroundColor Yellow
$node = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\verificar-realtime-canales.js'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
  node $node
  if ($LASTEXITCODE -ne 0) { Fail 'verificar-realtime-canales.js' } else { Ok 'verificar-realtime-canales.js' }
} finally {
  Pop-Location
}

if ($fallos -gt 0) {
  Write-Host "RT-SEC FALLA ($fallos)" -ForegroundColor Red
  exit 1
}
Write-Host 'RT-SEC OK' -ForegroundColor Green
exit 0
