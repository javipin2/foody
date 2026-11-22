# Suite E2E completa Foody (auditoria + impresion + multi-sucursal + P2)
# Uso: .\scripts\verificar-todos-e2e.ps1
# Alias: .\scripts\verificar-ci.ps1 -Completo

$ErrorActionPreference = 'Continue'
$raiz = $PSScriptRoot

Write-Host '=== Foody QA E2E (suite completa) ===' -ForegroundColor Cyan
& "$raiz\limpiar-demo-qa.ps1"
if ($LASTEXITCODE -ne 0) { exit 1 }

$scripts = @(
    'verificar-pagos-mesa.ps1',
    'verificar-flujo-domicilio.ps1',
    'verificar-inventario-menu.ps1',
    'verificar-transferencia-mesa.ps1',
    'verificar-impresion.ps1',
    'verificar-multi-sucursal.ps1',
    'verificar-analitica.ps1',
    'verificar-cxc.ps1',
    'verificar-p2-pulido.ps1'
)
$results = @()
foreach ($s in $scripts) {
    Write-Host ""
    Write-Host "========== $s ==========" -ForegroundColor Cyan
    & "$raiz\$s"
    $code = $LASTEXITCODE
    if (-not $?) { $code = 1 }
    if ($null -eq $code) { $code = if ($?) { 0 } else { 1 } }
    $results += [PSCustomObject]@{ Script = $s; Exit = $code; OK = ($code -eq 0) }
}

Write-Host ""
Write-Host '========== RESUMEN ==========' -ForegroundColor Yellow
$results | Format-Table -AutoSize
$ok = @($results | Where-Object { $_.OK }).Count
if ($ok -eq $results.Count) {
    Write-Host "Todos OK ($ok/$($results.Count))" -ForegroundColor Green
    exit 0
}
Write-Host "Fallaron $($results.Count - $ok) de $($results.Count)" -ForegroundColor Red
exit 1
