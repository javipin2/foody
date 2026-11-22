# Cierre producto sin VPS: CI + flujos + roles + realtime + FCM + docker config
# Uso: .\scripts\verificar-cierre-sin-vps.ps1
#      .\scripts\verificar-cierre-sin-vps.ps1 -SinDocker   # omite build imagen prod

param(
    [switch]$SinDocker
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent

$pasos = @(
    @{ Nombre = 'CI rapido'; Script = 'verificar-ci.ps1' }
    @{ Nombre = 'Preproduccion P0'; Script = 'verificar-preproduccion.ps1' }
    @{ Nombre = 'Flujo cruzado API sec4'; Script = 'verificar-flujo-cruzado-api.ps1' }
    @{ Nombre = 'QA roles API sec3'; Script = 'verificar-qa-roles-api.ps1' }
    @{ Nombre = 'Realtime API'; Script = 'verificar-realtime-api.ps1' }
    @{ Nombre = 'E2E suite'; Script = 'verificar-todos-e2e.ps1' }
    @{ Nombre = 'FCM diagnostico'; Script = 'verificar-fcm.ps1' }
)

if (-not $SinDocker) {
    $pasos += @{ Nombre = 'Docker prod build'; Script = 'verificar-docker-prod.ps1' }
}

Write-Host '=== Cierre Foody sin VPS ===' -ForegroundColor Cyan
Write-Host ('Fecha: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm')) -ForegroundColor DarkGray
. "$PSScriptRoot\lib\qa-helpers.ps1"
Ensure-HorariosDemoAbiertos
Write-Host ''

$resultados = @()
foreach ($p in $pasos) {
    Write-Host ('######## {0} ########' -f $p.Nombre) -ForegroundColor Yellow
    & "$PSScriptRoot\$($p.Script)"
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = if ($?) { 0 } else { 1 } }
    $ok = ($code -eq 0)
    $resultados += [pscustomobject]@{ paso = $p.Nombre; script = $p.Script; ok = $ok }
    if (-not $ok) {
        Write-Host ('FALLO en {0} - abortando cierre' -f $p.Script) -ForegroundColor Red
        break
    }
    Write-Host ''
}

Write-Host '========== RESUMEN CIERRE SIN VPS ==========' -ForegroundColor Yellow
$resultados | Format-Table -AutoSize

$okN = @($resultados | Where-Object { $_.ok }).Count
$total = $resultados.Count
$fecha = Get-Date -Format 'yyyy-MM-dd'
$sesion = Join-Path $raiz 'docs\qa-sesiones'
if (-not (Test-Path $sesion)) { New-Item -ItemType Directory -Path $sesion | Out-Null }
$archivo = Join-Path $sesion ($fecha + '-cierre-sin-vps.md')
$lineas = @(
    ('# Cierre sin VPS - ' + $fecha),
    '',
    '| Paso | OK |',
    '|------|-----|'
)
foreach ($r in $resultados) {
    $mark = if ($r.ok) { 'si' } else { 'no' }
    $lineas += ('| {0} | {1} |' -f $r.paso, $mark)
}
$lineas += ''
$lineas += 'Bloqueado hasta VPS: P0-05, P0-06, P0-07, P0-01 impresora fisica.'
$lineas | Set-Content -Path $archivo -Encoding UTF8

if ($okN -lt $total) {
    Write-Host ('CIERRE INCOMPLETO ({0}/{1})' -f $okN, $total) -ForegroundColor Red
    exit 1
}
Write-Host ('CIERRE SIN VPS OK ({0}/{1})' -f $okN, $total) -ForegroundColor Green
Write-Host ('Sesion: docs\qa-sesiones\{0}-cierre-sin-vps.md' -f $fecha) -ForegroundColor DarkGray
exit 0
