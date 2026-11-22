# BN-DTO-23 — query DTO auditoria/timeline
# Uso: .\scripts\verificar-bn-dto-auditoria.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar BN-DTO-23 auditoria timeline ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }

$login = Invoke-FoodyApi -Method POST -Path '/auth/login' -Body @{
    email      = 'admin@foody.demo'
    contrasena = $script:FoodyQaPass
}
if (-not ($login.ok -and $login.json.exito)) {
    throw "Login fallo: $($login.json.mensaje)"
}
$h = @{ Authorization = "Bearer $($login.json.datos.token)" }
$sid = $script:FoodyQaSucursal
$hoy = (Get-Date).ToString('yyyy-MM-dd')

# fecha basura → 400
$bad = Invoke-FoodyApi -Method GET -Path "/auditoria/timeline?desde=ayer&hasta=$hoy&sucursal_id=$sid" -Headers $h
if ($bad.ok -and $bad.json.exito) {
    throw 'FALLO: desde=ayer debio fallar validacion'
}
Write-Host "OK desde invalido ($($bad.status))" -ForegroundColor Green

# prop extra → 400
$extra = Invoke-FoodyApi -Method GET -Path "/auditoria/timeline?desde=$hoy&hasta=$hoy&sucursal_id=$sid&hack=1" -Headers $h
if ($extra.ok -and $extra.json.exito) {
    throw 'FALLO: prop hack debio fallar forbidNonWhitelisted'
}
Write-Host "OK prop extra ($($extra.status))" -ForegroundColor Green

# limpio → 200
$ok = Invoke-FoodyApi -Method GET -Path "/auditoria/timeline?desde=$hoy&hasta=$hoy&sucursal_id=$sid" -Headers $h
if (-not ($ok.ok -and $ok.json.exito)) {
    throw "FALLO timeline limpio: $($ok.json.mensaje)"
}
Write-Host 'OK timeline limpio' -ForegroundColor Green

# defaults (sin fechas) → 200
$def = Invoke-FoodyApi -Method GET -Path "/auditoria/timeline?sucursal_id=$sid" -Headers $h
if (-not ($def.ok -and $def.json.exito)) {
    throw "FALLO timeline defaults: $($def.json.mensaje)"
}
Write-Host 'OK timeline defaults hoy' -ForegroundColor Green

Write-Host ''
Write-Host 'BN-DTO-23 auditoria OK' -ForegroundColor Green
