# Flujo cruzado API (CHECKLIST_QA_ROLES.md seccion 4) — complementa UI manual.
# Uso: .\scripts\verificar-flujo-cruzado-api.ps1

$ErrorActionPreference = 'Continue'
$raiz = $PSScriptRoot

Write-Host '=== Flujo cruzado API (checklist sec4) ===' -ForegroundColor Cyan
. "$PSScriptRoot\lib\qa-helpers.ps1"
Ensure-HorariosDemoAbiertos
& "$raiz\limpiar-demo-qa.ps1"
if ($LASTEXITCODE -ne 0) { exit 1 }

$scripts = @(
    @{ Name = 'Cliente menu + registro (self-service)'; Script = 'verificar-self-service.ps1' }
    @{ Name = 'Para llevar + cocina (impresion)'; Script = 'verificar-impresion.ps1' }
    @{ Name = 'Domicilio planta'; Script = 'verificar-flujo-domicilio.ps1' }
    @{ Name = 'Cajero sin turno mesa'; Script = 'verificar-cajero-mesas.ps1' }
    @{ Name = 'Inventario menu'; Script = 'verificar-inventario-menu.ps1' }
    @{ Name = 'Traslado / copiar menu (gerente)'; Script = 'verificar-p2-pulido.ps1' }
    @{ Name = 'Limpieza antes mesas'; Script = 'limpiar-demo-qa.ps1' }
    @{ Name = 'Mesero + mesas'; Script = 'verificar-operacion-mesas.ps1' }
    @{ Name = 'Pagos mesa split/caja'; Script = 'verificar-pagos-mesa.ps1' }
    @{ Name = 'QR mesa (5 pedidos)'; Script = 'verificar-carga-qr.ps1'; ArgsHash = @{ Pedidos = 5 } }
    @{ Name = 'Caja coherencia'; Script = 'verificar-caja-coherencia.ps1' }
    @{ Name = 'Fiado domiciliario'; Script = 'verificar-fiado-domiciliario.ps1'; ArgsHash = @{ CicloCompleto = $true } }
)

$results = @()
foreach ($item in $scripts) {
    Write-Host ""
    Write-Host "---------- $($item.Script) ($($item.Name)) ----------" -ForegroundColor Cyan
    if ($item.ArgsHash) {
        $splat = $item.ArgsHash
        & "$raiz\$($item.Script)" @splat
    } else {
        & "$raiz\$($item.Script)"
    }
    $code = $LASTEXITCODE
    if (-not $?) { $code = 1 }
    if ($null -eq $code) { $code = if ($?) { 0 } else { 1 } }
    $results += [PSCustomObject]@{ Paso = $item.Name; Script = $item.Script; OK = ($code -eq 0) }
}

Write-Host ""
Write-Host '========== RESUMEN flujo cruzado API ==========' -ForegroundColor Yellow
$results | Format-Table -AutoSize
$ok = @($results | Where-Object { $_.OK }).Count
if ($ok -eq $results.Count) {
    Write-Host "Flujo cruzado API OK ($ok/$($results.Count))" -ForegroundColor Green
    exit 0
}
Write-Host "Fallaron $($results.Count - $ok) de $($results.Count)" -ForegroundColor Red
exit 1
