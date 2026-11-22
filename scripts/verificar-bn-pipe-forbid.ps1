# BN-FIX-06 / BN-PIPE-03 — forbidNonWhitelisted
# Uso: .\scripts\verificar-bn-pipe-forbid.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar BN-FIX-06 forbidNonWhitelisted ===' -ForegroundColor Cyan

$main = Join-Path $PSScriptRoot '..\foody_backend\src\main.ts'
$txt = Get-Content $main -Raw
if ($txt -notmatch 'forbidNonWhitelisted:\s*true') {
    throw 'main.ts debe tener forbidNonWhitelisted: true'
}
Write-Host 'OK main.ts forbidNonWhitelisted' -ForegroundColor Green

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }

# Extra prop en login → 400
$loginExtra = Invoke-FoodyApi -Method POST -Path '/auth/login' -Body @{
    email      = 'admin@foody.demo'
    contrasena = $script:FoodyQaPass
    hack       = 'no'
}
if ($loginExtra.ok -and $loginExtra.json.exito) {
    throw 'FALLO: login con prop extra debio ser 400'
}
Write-Host "OK login rechaza prop extra (status=$($loginExtra.status))" -ForegroundColor Green

# Login limpio OK
$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
Write-Host 'OK login limpio' -ForegroundColor Green

# Disponibilidad con prop desconocida
$disp = Invoke-FoodyApi -Method PATCH -Path '/productos/f0000000-0000-4000-8000-000000000002/disponibilidad' -Headers $h -Body @{
    disponible = $true
    foo        = 1
}
if ($disp.ok -and $disp.json.exito) {
    throw 'FALLO: disponibilidad con prop extra debio fallar'
}
Write-Host "OK disponibilidad rechaza prop extra (status=$($disp.status))" -ForegroundColor Green

# Disponibilidad limpia OK (smoke contrato Flutter)
$dispOk = Invoke-FoodyApi -Method PATCH -Path '/productos/f0000000-0000-4000-8000-000000000002/disponibilidad' -Headers $h -Body @{
    disponible = $true
}
if (-not ($dispOk.ok -and $dispOk.json.exito)) {
    throw "Disponibilidad limpia fallo: $($dispOk.json.mensaje)"
}
Write-Host 'OK disponibilidad limpia' -ForegroundColor Green

# Cotizar query limpia + query basura (si ValidationPipe aplica a query DTO)
$cot = Invoke-FoodyApi -Method GET -Path "/zonas/cotizar-domicilio?sucursal_id=$($script:FoodyQaSucursal)&hack=1"
if ($cot.ok -and $cot.json.exito) {
    Write-Host 'AVISO: query extra en cotizar no rechazo (pipe query?)' -ForegroundColor Yellow
} else {
    Write-Host "OK cotizar rechaza query extra (status=$($cot.status))" -ForegroundColor Green
}

Write-Host ''
Write-Host 'BN-FIX-06 forbidNonWhitelisted OK' -ForegroundColor Green
