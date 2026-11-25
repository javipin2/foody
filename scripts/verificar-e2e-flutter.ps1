# Prompt 33 — Flutter E2E contratos API (5 flujos + VIE-01)
# Uso: .\scripts\verificar-e2e-flutter.ps1
#      .\scripts\verificar-e2e-flutter.ps1 -EnDispositivo   # integration_test + -d windows
# Requiere: API viva + flutter en PATH

param(
    [switch]$EnDispositivo,
    [string]$Device = 'windows',
    [switch]$PermitirEscrituras,
    [string]$ApiHost = 'http://127.0.0.1:3001'
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$base = "$($ApiHost.TrimEnd('/'))/api/v1"
$uriHost = [Uri]$ApiHost
$esQaLocal = @('127.0.0.1', 'localhost') -contains $uriHost.Host -and $uriHost.Port -eq 3001

Write-Host '=== Foody E2E Flutter ===' -ForegroundColor Cyan

if (-not $PermitirEscrituras) {
    Write-Host 'BLOQUEADO: estos E2E crean y cancelan pedidos. Usa una BD QA aislada y vuelve a ejecutar con -PermitirEscrituras.' -ForegroundColor Yellow
    exit 2
}

if (-not $esQaLocal -and $env:FOODY_E2E_ALLOW_NON_QA -ne '1') {
    Write-Host "BLOQUEADO: E2E apunta a $ApiHost. Usa API QA local :3001; override requiere FOODY_E2E_ALLOW_NON_QA=1." -ForegroundColor Yellow
    exit 2
}

Write-Host "Destino verificado: $ApiHost" -ForegroundColor DarkGray

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
        flutter test integration_test/flujos_criticos_e2e_test.dart -d $Device `
            --dart-define=FOODY_E2E_API_HABILITADO=true `
            "--dart-define=E2E_HOST=$($ApiHost.TrimEnd('/'))"
    } else {
        Write-Host 'Modo VM: test/e2e/flujos_criticos_api_test.dart' -ForegroundColor DarkGray
        flutter test test/e2e/flujos_criticos_api_test.dart `
            --dart-define=FOODY_E2E_API_HABILITADO=true `
            "--dart-define=E2E_HOST=$($ApiHost.TrimEnd('/'))"
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
