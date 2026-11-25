# Flujo cruzado API (CHECKLIST_QA_ROLES.md seccion 4) — complementa UI manual.
# Uso: .\scripts\verificar-flujo-cruzado-api.ps1

$ErrorActionPreference = 'Continue'
$raiz = $PSScriptRoot

Write-Host '=== Flujo cruzado API (checklist sec4) ===' -ForegroundColor Cyan
. "$PSScriptRoot\lib\qa-helpers.ps1"
$qaUri = [Uri]$script:FoodyQaBase
$esQaLocal = @('127.0.0.1', 'localhost') -contains $qaUri.Host -and $qaUri.Port -eq 3001
$esClonDesechable = $script:FoodyQaDatabase -match '^foody_diseno_qa_codex_[a-zA-Z0-9_]+$'
if (-not $esQaLocal -or $script:FoodyQaDbContainer -ne 'foody-diseno-qa-db' -or -not $esClonDesechable) {
    Write-Host "BLOQUEADO: el flujo cruzado modifica datos y requiere API localhost:3001, contenedor foody-diseno-qa-db y clon foody_diseno_qa_codex_* (actual: $($script:FoodyQaBase), $($script:FoodyQaDbContainer)/$($script:FoodyQaDatabase))." -ForegroundColor Yellow
    exit 2
}
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

# El guard del orquestador también revisa las dependencias para evitar que un
# subguion con destino fijo eluda el clon y alcance el API :3000 o la BD dev.
$preflight = @($scripts | ForEach-Object { $_.Script }) + @('reparar-impresora-demo.ps1')
foreach ($scriptName in $preflight) {
    $scriptPath = Join-Path $raiz $scriptName
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        Write-Host "BLOQUEADO: falta el subguion requerido $scriptName" -ForegroundColor Yellow
        exit 2
    }
    $source = Get-Content -LiteralPath $scriptPath -Raw
    if ($source -match 'http://(?:localhost|127\.0\.0\.1):3000|docker\s+exec\s+supabase-db') {
        Write-Host "BLOQUEADO: $scriptName contiene un destino dev fijo; no se ejecutará ninguna prueba." -ForegroundColor Yellow
        exit 2
    }
}

try { Assert-FoodyQaDisposable }
catch { Write-Host "BLOQUEADO: $($_.Exception.Message)" -ForegroundColor Yellow; exit 2 }
Ensure-HorariosDemoAbiertos
& "$raiz\limpiar-demo-qa.ps1"
if ($LASTEXITCODE -ne 0) { exit 1 }

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
