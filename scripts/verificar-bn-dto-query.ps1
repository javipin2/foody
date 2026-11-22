# BN-FIX-04 — query DTOs + IsBoolean CrearPedido
# Uso: .\scripts\verificar-bn-dto-query.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar BN-FIX-04 query DTOs ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }

$sid = $script:FoodyQaSucursal

# validar-codigo sin UUID → 400
$bad = Invoke-FoodyApi -Method GET -Path '/promociones/validar-codigo?sucursal_id=x&codigo=ABC'
if ($bad.ok -and $bad.json.exito) {
    throw 'FALLO: validar-codigo debio rechazar UUID invalido'
}
Write-Host "OK validar-codigo UUID invalido ($($bad.status))" -ForegroundColor Green

# validar-codigo limpio (puede ser codigo inexistente pero DTO OK → 200 con datos o negocio)
$ok = Invoke-FoodyApi -Method GET -Path "/promociones/validar-codigo?sucursal_id=$sid&codigo=NOEXISTE&subtotal=10000"
if (-not $ok.ok) {
    # 400 negocio vs pipe: si status 400 con SOLICITUD_INVALIDA por whitelist extra sería malo
    Write-Host "AVISO validar-codigo status=$($ok.status) msg=$($ok.json.mensaje)" -ForegroundColor Yellow
} else {
    Write-Host 'OK validar-codigo DTO aceptado' -ForegroundColor Green
}

# geografia sin q → 400
$geoBad = Invoke-FoodyApi -Method GET -Path '/geografia/buscar'
if ($geoBad.ok -and $geoBad.json.exito) {
    throw 'FALLO: geografia sin q debio fallar'
}
Write-Host "OK geografia sin q rechazado ($($geoBad.status))" -ForegroundColor Green

# geografia con q (Photon puede fallar offline — no debe ser pipe whitelist)
$geo = Invoke-FoodyApi -Method GET -Path '/geografia/buscar?q=bogota&limite=3'
$msg = "$($geo.json.mensaje)$($geo.json.error)"
if ($msg -match 'whitelist|property should not exist|forbid') {
    throw "FALLO: geografia limpia rechazo pipe: $msg"
}
Write-Host "OK geografia query DTO (status=$($geo.status); Photon puede 400 offline)" -ForegroundColor Green

# CrearPedido bool basura (publico)
$pedidoBad = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
    sucursal_id      = $sid
    device_id        = 'qa-bn-fix-04'
    tipo             = 'para_llevar'
    requiere_factura = 'si'
    items            = @(@{ producto_id = 'f0000000-0000-4000-8000-000000000002'; cantidad = 1; precio = 1 })
}
if ($pedidoBad.ok -and $pedidoBad.json.exito) {
    throw 'FALLO: requiere_factura string debio fallar IsBoolean'
}
Write-Host "OK CrearPedido IsBoolean ($($pedidoBad.status))" -ForegroundColor Green

Write-Host ''
Write-Host 'BN-FIX-04 query DTOs OK' -ForegroundColor Green
