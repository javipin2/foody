# Cancela pedidos activos demo y deja mesas listas para QA
# Uso: .\scripts\limpiar-demo-qa.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Limpiar demo QA ===' -ForegroundColor Cyan
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
Write-Host "Pedidos activos cancelados: $n" -ForegroundColor Green
exit 0
