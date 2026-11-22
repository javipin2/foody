# Prompt 33 — Suite E2E Jest/Supertest (5 flujos + casos limite 28-30)
# Uso: .\scripts\verificar-e2e-jest.ps1
# Requiere: API viva en :3000 + seed demo

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$backend = Join-Path $raiz 'foody_backend'
$base = 'http://127.0.0.1:3000/api/v1'

Write-Host '=== Foody E2E Jest (flujos criticos) ===' -ForegroundColor Cyan

try {
    $salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 8
    if (-not $salud.exito) { throw 'salud exito=false' }
    Write-Host 'OK API viva' -ForegroundColor Green
} catch {
    Write-Host "FALLO: API no disponible en $base" -ForegroundColor Red
    exit 1
}

Push-Location $backend
try {
    npm run test:e2e -- --runInBand
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($code -eq 0) {
    Write-Host 'E2E Jest OK' -ForegroundColor Green
    exit 0
}
Write-Host "E2E Jest FALLO exit=$code" -ForegroundColor Red
exit $code
