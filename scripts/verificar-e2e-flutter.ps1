# Prompt 33 — Flutter E2E contratos API (5 flujos + VIE-01)
# Uso: .\scripts\verificar-e2e-flutter.ps1
#      .\scripts\verificar-e2e-flutter.ps1 -EnDispositivo   # integration_test + -d windows
# Requiere: API viva + flutter en PATH

param(
    [switch]$EnDispositivo,
    [string]$Device = 'windows'
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$base = 'http://127.0.0.1:3000/api/v1'

Write-Host '=== Foody E2E Flutter ===' -ForegroundColor Cyan

try {
    $salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 8
    if (-not $salud.exito) { throw 'salud exito=false' }
    Write-Host 'OK API viva' -ForegroundColor Green
} catch {
    Write-Host "FALLO: API no disponible en $base" -ForegroundColor Red
    exit 1
}

Push-Location $raiz
try {
    if ($EnDispositivo) {
        Write-Host "Modo integration_test -d $Device" -ForegroundColor DarkGray
        flutter test integration_test/flujos_criticos_e2e_test.dart -d $Device
    } else {
        Write-Host 'Modo VM: test/e2e/flujos_criticos_api_test.dart' -ForegroundColor DarkGray
        flutter test test/e2e/flujos_criticos_api_test.dart
    }
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($code -eq 0) {
    Write-Host 'E2E Flutter OK' -ForegroundColor Green
    exit 0
}
Write-Host "E2E Flutter FALLO exit=$code" -ForegroundColor Red
exit $code
