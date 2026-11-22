# BN-FIX-03: bodies inline → DTO class-validator (happy + error)
# Uso: .\scripts\verificar-bn-dto-inline.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar BN-DTO inline (06-19 + cotizar) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal

# Cotizar: DTO query (BN-DTO-21) — sin coords = default (no falla cobertura)
$cot = Invoke-FoodyApi -Method GET -Path "/zonas/cotizar-domicilio?sucursal_id=$sid"
if (-not ($cot.ok -and $cot.json.exito)) {
    throw "Cotizar OK esperado: $($cot.json.mensaje)"
}
Write-Host 'OK cotizar-domicilio con query DTO' -ForegroundColor Green

$cotBad = Invoke-FoodyApi -Method GET -Path '/zonas/cotizar-domicilio?sucursal_id=no-uuid'
if ($cotBad.ok -and $cotBad.json.exito) {
    throw 'FALLO: cotizar debio rechazar sucursal_id invalido'
}
Write-Host 'OK cotizar rechaza UUID invalido' -ForegroundColor Green

# Disponibilidad sin boolean → 400
$dispBad = Invoke-FoodyApi -Method PATCH -Path '/productos/f0000000-0000-4000-8000-000000000002/disponibilidad' -Headers $h -Body @{
    disponible = 'si'
}
if ($dispBad.ok -and $dispBad.json.exito) {
    throw 'FALLO: disponibilidad debio rechazar string'
}
Write-Host 'OK disponibilidad rechaza no-boolean' -ForegroundColor Green

# Observaciones cocina sin string → 400 (item fake UUID — puede 404 tras validacion body)
$obsBad = Invoke-FoodyApi -Method PATCH -Path '/cocina/items/f0000000-0000-4000-8000-000000000099/observaciones' -Headers $h -Body @{
    observaciones = 123
}
if ($obsBad.ok -and $obsBad.json.exito) {
    throw 'FALLO: observaciones debio rechazar number'
}
Write-Host "OK observaciones rechaza number (status=$($obsBad.status))" -ForegroundColor Green

# Rechazar sin motivo
$rech = Invoke-FoodyApi -Method PATCH -Path '/pedidos/f0000000-0000-4000-8000-000000000099/rechazar' -Headers $h -Body @{}
if ($rech.ok -and $rech.json.exito) {
    throw 'FALLO: rechazar sin motivo debio fallar'
}
Write-Host "OK rechazar sin motivo rechazado (status=$($rech.status))" -ForegroundColor Green

Write-Host ''
Write-Host 'BN-DTO inline OK' -ForegroundColor Green
