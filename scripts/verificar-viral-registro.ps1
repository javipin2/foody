# VIRAL antispike registro (cupo/flag/estado + defer horarios).
# Uso: .\scripts\verificar-viral-registro.ps1
# Opcional: REGISTRO_RESTAURANTE_ABIERTO=0 en el proceso Nest para assert 503.
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Base = 'http://localhost:3000/api/v1'
$fallos = 0

function Assert-Ok {
  param([bool]$Cond, [string]$Msg)
  if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
  else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

Write-Host '=== VIRAL registro antispike ===' -ForegroundColor Cyan

$anti = Get-Content -Raw (Join-Path $Root 'foody_backend\src\core\auth\registro-antispike.ts')
$authCtrl = Get-Content -Raw (Join-Path $Root 'foody_backend\src\core\auth\auth.controller.ts')
$onb = Get-Content -Raw (Join-Path $Root 'foody_backend\src\core\onboarding\onboarding-restaurante.service.ts')
$ui = Get-Content -Raw (Join-Path $Root 'lib\features\auth\presentation\restaurante_registro_screen.dart')

Assert-Ok ($anti -match 'registroCupoDiario') 'registro-antispike cupo'
Assert-Ok ($authCtrl -match 'registro-estado') 'GET auth/registro-estado'
Assert-Ok ($onb -match 'completarPostCommit') 'onboarding defer post-commit'
Assert-Ok ($ui -match '_registroAbierto') 'UI waitlist flag'

$salud = Invoke-RestMethod -Uri "$Base/salud" -TimeoutSec 8
Assert-Ok ([bool]$salud.exito) 'GET /salud'

$est = Invoke-RestMethod -Uri "$Base/auth/registro-estado" -TimeoutSec 8
Assert-Ok ([bool]$est.exito) 'GET /auth/registro-estado exito'
$d = $est.datos
Assert-Ok ($null -ne $d.abierto) 'estado.abierto presente'
Assert-Ok ($null -ne $d.mensaje) 'estado.mensaje presente'
Assert-Ok ($null -ne $d.cupo_diario) 'estado.cupo_diario presente'
Write-Host ("  estado abierto={0} usados_hoy={1} cupo={2}" -f $d.abierto, $d.usados_hoy, $d.cupo_diario) -ForegroundColor DarkGray

# Si el Nest corre con REGISTRO_RESTAURANTE_ABIERTO=0, POST debe 503
$cerradoEnv = [string]$env:REGISTRO_RESTAURANTE_ABIERTO
if ($cerradoEnv -eq '0' -or $d.registro_habilitado -eq $false -or $d.abierto -eq $false) {
  $code = 0
  try {
    Invoke-WebRequest -Method Post -Uri "$Base/auth/registro-restaurante" `
      -ContentType 'application/json' `
      -Body '{"ciudad_id":"a0000000-0000-4000-8000-000000000001","nombre_restaurante":"Viral Test","admin_nombre":"Viral","admin_email":"viral-cupo-test@example.com","contrasena":"123456"}' `
      -TimeoutSec 8 | Out-Null
  } catch {
    if ($_.Exception.Response) {
      try { $code = [int]$_.Exception.Response.StatusCode.value__ } catch { }
    }
  }
  if ($d.abierto -eq $false) {
    Assert-Ok ($code -eq 503 -or $code -eq 429) ("POST registro bloqueado HTTP $code")
  } else {
    Write-Host '  SKIP assert 503 (estado abierto=true)' -ForegroundColor Yellow
  }
} else {
  Write-Host '  SKIP 503 (registro abierto; set REGISTRO_RESTAURANTE_ABIERTO=0 para forzar)' -ForegroundColor Yellow
}

Push-Location $Root
try {
  $ana = & dart analyze lib/features/auth/data/auth_repository.dart lib/features/auth/presentation/restaurante_registro_screen.dart 2>&1 | Out-String
  Assert-Ok ($ana -notmatch '(?m)^  error') 'dart analyze auth registro'
} finally {
  Pop-Location
}

if ($fallos -gt 0) {
  Write-Host ('FAIL total=' + $fallos) -ForegroundColor Red
  exit 1
}
Write-Host 'OK verificar-viral-registro' -ForegroundColor Green
exit 0
