# Orquestador CI / QA Foody — requiere API QA en :3001 + BD foody_diseno_qa seeded
# Uso:
#   .\scripts\verificar-ci.ps1              # modo rapido (smoke + P2)
#   .\scripts\verificar-ci.ps1 -Completo    # limpiar demo + suite E2E completa
#   .\scripts\verificar-ci.ps1 -SoloPaso0   # solo verificar-paso0.ps1

param(
    [switch]$Completo,
    [switch]$SoloPaso0
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$base = 'http://127.0.0.1:3001/api/v1'

Write-Host "=== Foody CI local ===" -ForegroundColor Cyan
Write-Host "Modo: $(if ($SoloPaso0) { 'paso0' } elseif ($Completo) { 'completo' } else { 'rapido' })" -ForegroundColor Cyan

try {
    $salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 8
    if (-not $salud.exito) { throw 'API /salud exito=false' }
    Write-Host "OK API $base" -ForegroundColor Green
} catch {
    Write-Host "FALLO: backend no disponible en $base" -ForegroundColor Red
    Write-Host 'Levanta la instancia Nest de QA en :3001 conectada a foody_diseno_qa.' -ForegroundColor Yellow
    exit 1
}

if ($SoloPaso0) {
    & "$raiz\verificar-paso0.ps1"
    exit $LASTEXITCODE
}

$scripts = @()
if ($Completo) {
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
        'verificar-p2-pulido.ps1',
        # Bloque C — remediación Nest (solo -Completo; no alarga modo rapido)
        'verificar-bn-pipe-forbid.ps1',
        'verificar-bn-dto-query.ps1',
        'verificar-bn-dto-query-rest.ps1',
        'verificar-bn-dto-inline.ps1',
        'verificar-bn-dto-fcm.ps1',
        'verificar-bn-dto-auditoria.ps1',
        'verificar-bn-almacenamiento.ps1',
        'verificar-bn-ctrl-usuarios.ps1',
        'verificar-bn-residuales.ps1',
        'verificar-rt-sec.ps1'
    )
} else {
    $scripts = @(
        'verificar-paso0.ps1',
        'verificar-rls.ps1',
        'verificar-salud.ps1',
        'verificar-p2-pulido.ps1',
        'verificar-multi-sucursal.ps1'
    )
}

$results = @()
foreach ($s in $scripts) {
    Write-Host ""
    Write-Host "========== $s ==========" -ForegroundColor Cyan
    & "$raiz\$s"
    $code = $LASTEXITCODE
    if ($null -eq $code -or $code -ne 0) {
        if (-not $?) { $code = 1 }
    }
    $results += [PSCustomObject]@{ Script = $s; Exit = $code; OK = ($code -eq 0) }
}

Write-Host ""
Write-Host '========== RESUMEN CI ==========' -ForegroundColor Yellow
$results | Format-Table -AutoSize
$ok = @($results | Where-Object { $_.OK }).Count
if ($ok -eq $results.Count) {
    Write-Host "CI OK ($ok/$($results.Count))" -ForegroundColor Green
    exit 0
}
Write-Host "CI FALLO ($ok/$($results.Count) OK)" -ForegroundColor Red
exit 1
