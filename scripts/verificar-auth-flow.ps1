# AUTH-FLOW / AUTH-REV: refresh + logout + token_version
# Uso: .\scripts\verificar-auth-flow.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar AUTH-FLOW (refresh / logout / tv) ===' -ForegroundColor Cyan

$col = docker exec supabase-db psql -U postgres -d postgres -tAc `
  "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='usuarios' AND column_name='token_version';" 2>$null
if (($col -as [string]).Trim() -ne '1') {
    throw 'Falta usuarios.token_version (migracion 084). Aplicala y reintenta.'
}

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
Write-Host 'OK login' -ForegroundColor Green

$perfil = Invoke-FoodyApi -Method GET -Path '/auth/perfil' -Headers $h
if (-not ($perfil.ok -and $perfil.json.exito)) {
    throw "Perfil con token fresco fallo: $($perfil.json.mensaje)"
}
Write-Host 'OK perfil con token fresco' -ForegroundColor Green

$ref = Invoke-FoodyApi -Method POST -Path '/auth/refresh' -Headers $h
if (-not ($ref.ok -and $ref.json.exito)) {
    throw "Refresh fallo: $($ref.json.mensaje)"
}
$token2 = $ref.json.datos.token
if (-not $token2) { throw 'Refresh sin token' }
if ($token2 -eq $token) {
    Write-Host 'AVISO: refresh devolvio el mismo string JWT (posible clock)' -ForegroundColor Yellow
}
$h2 = @{ Authorization = "Bearer $token2" }
$perfil2 = Invoke-FoodyApi -Method GET -Path '/auth/perfil' -Headers $h2
if (-not ($perfil2.ok -and $perfil2.json.exito)) {
    throw "Perfil post-refresh fallo: $($perfil2.json.mensaje)"
}
Write-Host 'OK refresh' -ForegroundColor Green

$logout = Invoke-FoodyApi -Method POST -Path '/auth/logout' -Headers $h2
if (-not ($logout.ok -and $logout.json.exito)) {
    throw "Logout fallo: $($logout.json.mensaje)"
}
Write-Host 'OK logout' -ForegroundColor Green

$perfilMuerto = Invoke-FoodyApi -Method GET -Path '/auth/perfil' -Headers $h2
if ($perfilMuerto.ok -and $perfilMuerto.json.exito) {
    throw 'FALLO: token post-logout sigue valido en /auth/perfil'
}
if ($perfilMuerto.status -ne 401) {
    Write-Host "AVISO: post-logout status=$($perfilMuerto.status) (esperado 401)" -ForegroundColor Yellow
} else {
    Write-Host 'OK token revocado (401 perfil)' -ForegroundColor Green
}

$refMuerto = Invoke-FoodyApi -Method POST -Path '/auth/refresh' -Headers $h2
if ($refMuerto.ok -and $refMuerto.json.exito) {
    throw 'FALLO: refresh post-logout no debio aceptar el JWT'
}
Write-Host 'OK refresh post-logout rechazado' -ForegroundColor Green

# Login de nuevo para no dejar admin con tv alto sin sesion usable en otros scripts
$null = Invoke-FoodyApi -Method POST -Path '/auth/login' -Body @{
    email      = 'admin@foody.demo'
    contrasena = $script:FoodyQaPass
}

Write-Host ''
Write-Host 'AUTH-FLOW OK' -ForegroundColor Green
