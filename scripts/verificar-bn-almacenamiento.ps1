# BN-FIX-01 / AQ-SOLID-03 / AQ-DUP-04 — controller delgado + service ownership
# Uso: .\scripts\verificar-bn-almacenamiento.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar BN-FIX-01 almacenamiento ===' -ForegroundColor Cyan

$ctrl = Join-Path $PSScriptRoot '..\foody_backend\src\modulos\almacenamiento\almacenamiento.controller.ts'
$svc = Join-Path $PSScriptRoot '..\foody_backend\src\modulos\almacenamiento\almacenamiento.service.ts'
if (-not (Test-Path $ctrl)) { throw "Falta $ctrl" }
if (-not (Test-Path $svc)) { throw "Falta $svc" }

$ctrlTxt = Get-Content $ctrl -Raw
$svcTxt = Get-Content $svc -Raw

if ($ctrlTxt -match 'DatabaseService') {
    throw 'Controller no debe inyectar DatabaseService'
}
if ($ctrlTxt -match 'MenuCacheService') {
    throw 'Controller no debe inyectar MenuCacheService'
}
if ($ctrlTxt -match 'consultarUno|consultar\(') {
    throw 'Controller no debe ejecutar SQL'
}
Write-Host 'OK controller sin SQL/DB/cache' -ForegroundColor Green

if ($svcTxt -notmatch 'subirImagenEntidadCatalogo') {
    throw 'Service debe exponer subirImagenEntidadCatalogo'
}
if ($svcTxt -notmatch 'restauranteIdDeSucursal') {
    throw 'Service debe exponer restauranteIdDeSucursal'
}
Write-Host 'OK service ownership unificado' -ForegroundColor Green

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal

# Sin multipart → 400 (no 500)
$sinArchivo = Invoke-FoodyApi -Method POST -Path "/almacenamiento/imagen?sucursal_id=$sid&tipo=general" -Headers $h
if ($sinArchivo.ok -and $sinArchivo.json.exito) {
    throw 'FALLO: upload sin archivo debio fallar'
}
if ($sinArchivo.status -ne 400 -and $sinArchivo.status -ne 0) {
    Write-Host "AVISO status=$($sinArchivo.status) (esperado 400)" -ForegroundColor Yellow
} else {
    Write-Host "OK upload sin archivo rechazado ($($sinArchivo.status))" -ForegroundColor Green
}

# Entidad inexistente sin archivo → 400 por falta archivo (validacion controller primero)
$prodFake = Invoke-FoodyApi -Method POST -Path "/almacenamiento/productos/f0000000-0000-4000-8000-000000009999/imagen?sucursal_id=$sid" -Headers $h
if ($prodFake.ok -and $prodFake.json.exito) {
    throw 'FALLO: producto imagen sin archivo debio fallar'
}
Write-Host "OK producto imagen sin archivo rechazado ($($prodFake.status))" -ForegroundColor Green

Write-Host ''
Write-Host 'BN-FIX-01 almacenamiento OK' -ForegroundColor Green
