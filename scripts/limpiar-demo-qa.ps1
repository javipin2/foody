# Cancela pedidos activos demo y deja mesas listas para QA aislada (:3001 + BD QA)
# Uso: .\scripts\limpiar-demo-qa.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Limpiar demo QA ===' -ForegroundColor Cyan
try {
    $qaUri = [Uri]$script:FoodyQaBase
    Assert-FoodyQaDisposable
} catch {
    Write-Host "BLOQUEADO: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 2
}
try {
    $containerActivo = docker inspect --format '{{.State.Running}}' $script:FoodyQaDbContainer 2>$null
    if ($LASTEXITCODE -ne 0 -or $containerActivo.Trim() -ne 'true') {
        throw "Contenedor QA '$script:FoodyQaDbContainer' no está ejecutándose"
    }
} catch {
    Write-Host "BLOQUEADO: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 2
}
try {
    $salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
    if (-not $salud.exito) { throw 'API no responde' }
}
catch {
    Write-Host "FALLO: backend no disponible en $script:FoodyQaBase" -ForegroundColor Red
    exit 1
}

$admin = Get-FoodyToken 'admin@foody.demo'
$n = Limpiar-PedidosActivosDemo -Headers $admin.headers
Restaurar-InventarioDemo -Headers $admin.headers
Ensure-HorariosDemoAbiertos
$sid = $script:FoodyQaSucursal
$jobsBorrados = docker exec $script:FoodyQaDbContainer psql -U postgres -d $script:FoodyQaDatabase -tAc `
    "DELETE FROM impresion_cocina_jobs WHERE sucursal_id = '$sid' AND estado IN ('error','pendiente') RETURNING 1;" 2>$null
$jb = @($jobsBorrados -split "`n" | Where-Object { $_.Trim() -ne '' }).Count
$devicesAnonimizados = docker exec $script:FoodyQaDbContainer psql -U postgres -d $script:FoodyQaDatabase -tAc `
    "UPDATE dispositivos_cliente SET fcm_token = NULL, ciudad_id = NULL, auth_uid = NULL, capability_hash = NULL, anonimizado = true, anonimizado_at = now() WHERE anonimizado = false AND auth_uid IS NULL AND (device_id LIKE 'jest-qr-%' OR device_id LIKE 'jest-numero-%') RETURNING 1;" 2>$null
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron anonimizar los dispositivos sintéticos E2E' }
$da = @($devicesAnonimizados -split "`n" | Where-Object { $_.Trim() -ne '' }).Count
Write-Host "Pedidos activos cancelados: $n | jobs impresión limpiados: $jb | devices E2E anonimizados: $da" -ForegroundColor Green
exit 0
