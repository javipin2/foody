# CFG-NOMBRE-MARCA-07 — PATCH /sucursales/marca con nombre/telefono
# Uso: .\scripts\verificar-cfg-nombre-marca.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== CFG-NOMBRE-MARCA-07 ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API salud fail' }

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers

$antes = Invoke-FoodyApi -Method GET -Path '/sucursales/marca' -Headers $h
if (-not ($antes.ok -and $antes.json.exito)) { throw "GET marca: $($antes.status)" }
$nombreOrig = [string]$antes.json.datos.nombre
$telOrig = [string]$antes.json.datos.telefono

$patch = Invoke-FoodyApi -Method PATCH -Path '/sucursales/marca' -Headers $h -Body @{
  nombre   = 'QA Marca Foody'
  telefono = '3001112233'
}
if (-not ($patch.ok -and $patch.json.exito)) {
  throw "PATCH marca: $($patch.status) $($patch.json.mensaje)"
}
if ($patch.json.datos.nombre -ne 'QA Marca Foody') {
  throw "nombre no persistio: $($patch.json.datos.nombre)"
}
if ([string]$patch.json.datos.telefono -ne '3001112233') {
  throw "telefono no persistio: $($patch.json.datos.telefono)"
}
Write-Host 'OK PATCH nombre+telefono'

# vacio nombre → 400
$bad = Invoke-FoodyApi -Method PATCH -Path '/sucursales/marca' -Headers $h -Body @{
  nombre = '   '
}
if ($bad.ok -and $bad.json.exito) { throw 'nombre vacio debio fallar' }
Write-Host "OK rechazo nombre vacio ($($bad.status))"

# restaurar
$rest = Invoke-FoodyApi -Method PATCH -Path '/sucursales/marca' -Headers $h -Body @{
  nombre   = $nombreOrig
  telefono = $(if ([string]::IsNullOrWhiteSpace($telOrig)) { '' } else { $telOrig })
}
if (-not ($rest.ok -and $rest.json.exito)) {
  Write-Host "WARN restore marca: $($rest.json.mensaje)" -ForegroundColor Yellow
} else {
  Write-Host 'OK restore'
}

Write-Host '=== OK ===' -ForegroundColor Green
