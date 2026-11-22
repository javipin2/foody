# BN-DTO-01/02 — bodies FCM auth
# Uso: .\scripts\verificar-bn-dto-fcm.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar BN-DTO FCM ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }

$login = Invoke-FoodyApi -Method POST -Path '/auth/login' -Body @{
    email      = 'admin@foody.demo'
    contrasena = $script:FoodyQaPass
}
if (-not ($login.ok -and $login.json.exito)) {
    throw "Login fallo: $($login.json.mensaje)"
}
$token = $login.json.datos.token
if (-not $token) { throw 'Login sin token' }
$h = @{ Authorization = "Bearer $token" }

# sin fcm_token → 400
$sin = Invoke-FoodyApi -Method POST -Path '/auth/registrar-fcm' -Headers $h -Body @{ plataforma = 'android' }
if ($sin.ok -and $sin.json.exito) {
    throw 'FALLO: registrar-fcm sin token debio fallar'
}
Write-Host "OK registrar-fcm sin token ($($sin.status))" -ForegroundColor Green

# prop extra → 400 (forbidNonWhitelisted)
$extra = Invoke-FoodyApi -Method POST -Path '/auth/registrar-fcm' -Headers $h -Body @{
    fcm_token  = 'token-qa-bn-dto-fcm-0123456789'
    plataforma = 'android'
    hack       = 1
}
if ($extra.ok -and $extra.json.exito) {
    throw 'FALLO: registrar-fcm debio rechazar prop extra'
}
Write-Host "OK registrar-fcm prop extra ($($extra.status))" -ForegroundColor Green

# limpio → 200
$ok = Invoke-FoodyApi -Method POST -Path '/auth/registrar-fcm' -Headers $h -Body @{
    fcm_token  = 'token-qa-bn-dto-fcm-0123456789'
    plataforma = 'android'
}
if (-not ($ok.ok -and $ok.json.exito)) {
    throw "FALLO registrar-fcm limpio: $($ok.json.mensaje)"
}
Write-Host 'OK registrar-fcm limpio' -ForegroundColor Green

# desactivar limpio
$off = Invoke-FoodyApi -Method POST -Path '/auth/desactivar-fcm' -Headers $h -Body @{
    fcm_token = 'token-qa-bn-dto-fcm-0123456789'
}
if (-not ($off.ok -and $off.json.exito)) {
    throw "FALLO desactivar-fcm: $($off.json.mensaje)"
}
Write-Host 'OK desactivar-fcm' -ForegroundColor Green

Write-Host ''
Write-Host 'BN-DTO-01/02 FCM OK' -ForegroundColor Green
