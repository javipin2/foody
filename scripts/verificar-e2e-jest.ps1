# Prompt 33 — Suite E2E Jest/Supertest (5 flujos + casos limite 28-30)
# Uso: .\scripts\verificar-e2e-jest.ps1
# Requiere: API QA viva en :3001 + seed demo. Los E2E escriben y limpian pedidos.

param(
    [string]$ApiHost
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$backend = Join-Path $raiz 'foody_backend'

if ([string]::IsNullOrWhiteSpace($ApiHost)) {
    $ApiHost = if ([string]::IsNullOrWhiteSpace($env:E2E_HOST)) {
        'http://127.0.0.1:3001'
    } else {
        $env:E2E_HOST.TrimEnd('/')
    }
}
$ApiHost = $ApiHost.TrimEnd('/')
$uriHost = [Uri]$ApiHost
$esQaLocal = @('127.0.0.1', 'localhost') -contains $uriHost.Host -and $uriHost.Port -eq 3001
if (-not $esQaLocal -and $env:FOODY_E2E_ALLOW_NON_QA -ne '1') {
    Write-Host "BLOQUEADO: E2E apunta a $ApiHost. Usa API QA local :3001; override requiere FOODY_E2E_ALLOW_NON_QA=1." -ForegroundColor Yellow
    exit 2
}
$base = "$ApiHost/api/v1"

Write-Host '=== Foody E2E Jest (flujos criticos) ===' -ForegroundColor Cyan
Write-Host "Destino verificado: $ApiHost" -ForegroundColor DarkGray

try {
    $salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 8
    if (-not $salud.exito) { throw 'salud exito=false' }
    Write-Host 'OK API viva' -ForegroundColor Green
} catch {
    Write-Host "FALLO: API no disponible en $base" -ForegroundColor Red
    exit 1
}

# La suite anterior puede consumir stock demo además de crear pedidos. Para que
# sea repetible, restablecer solo la BD QA aislada antes de ejecutar Jest.
if ($esQaLocal) {
    $qaBaseAnterior = $env:FOODY_QA_API_BASE
    try {
        $env:FOODY_QA_API_BASE = "$ApiHost/api/v1"
        & "$PSScriptRoot\limpiar-demo-qa.ps1"
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'FALLO: no se pudo preparar la BD QA' -ForegroundColor Red
            exit 1
        }
    } finally {
        $env:FOODY_QA_API_BASE = $qaBaseAnterior
    }
}

Push-Location $backend
$e2eHostAnterior = $env:E2E_HOST
try {
    $env:E2E_HOST = $ApiHost
    npm run test:e2e -- --runInBand
    $code = $LASTEXITCODE
} finally {
    $env:E2E_HOST = $e2eHostAnterior
    Pop-Location
}

if ($code -eq 0) {
    Write-Host 'E2E Jest OK' -ForegroundColor Green
    exit 0
}
Write-Host "E2E Jest FALLO exit=$code" -ForegroundColor Red
exit $code
