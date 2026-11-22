# Checks P0 preproduccion (sin VPS): schema, IDOR, cobro domicilio, backup dry-run.
# Uso: .\scripts\verificar-preproduccion.ps1

$ErrorActionPreference = 'Stop'

$pasos = @(
    'verificar-migraciones-prod.ps1'
    'verificar-idor-scope.ps1'
    'verificar-cobro-domicilio.ps1'
)

Write-Host '=== Verificar preproduccion P0 ===' -ForegroundColor Cyan
$resultados = @()

foreach ($s in $pasos) {
    Write-Host ("--- {0} ---" -f $s) -ForegroundColor Yellow
    & "$PSScriptRoot\$s"
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = if ($?) { 0 } else { 1 } }
    $ok = ($code -eq 0)
    $resultados += [pscustomobject]@{ script = $s; ok = $ok }
    if (-not $ok) { break }
}

Write-Host '========== RESUMEN PREPROD ==========' -ForegroundColor Yellow
$resultados | Format-Table -AutoSize
$okN = @($resultados | Where-Object { $_.ok }).Count
if ($okN -lt $resultados.Count) {
    Write-Host "PREPROD INCOMPLETO ($okN/$($resultados.Count))" -ForegroundColor Red
    exit 1
}
Write-Host "PREPROD OK ($okN/$($resultados.Count))" -ForegroundColor Green
