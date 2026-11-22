# BN-CTRL-02 — authz crear/actualizar en UsuariosService
# Uso: .\scripts\verificar-bn-ctrl-usuarios.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar BN-CTRL-02 usuarios authz ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }

$sid = $script:FoodyQaSucursal
$login = Invoke-FoodyApi -Method POST -Path '/auth/login' -Body @{
    email      = 'admin@foody.demo'
    contrasena = $script:FoodyQaPass
}
if (-not ($login.ok -and $login.json.exito)) {
    throw "Login fallo: $($login.json.mensaje)"
}
$h = @{ Authorization = "Bearer $($login.json.datos.token)" }

# crear cajero OK
$email = "qa-bn-ctrl-$(Get-Date -Format 'HHmmss')@foody.test"
$crear = Invoke-FoodyApi -Method POST -Path '/usuarios' -Headers $h -Body @{
    sucursal_id = $sid
    nombre      = 'QA BN CTRL'
    email       = $email
    contrasena  = '123456'
    rol         = 'cajero'
}
if (-not ($crear.ok -and $crear.json.exito)) {
    throw "Crear cajero fallo: $($crear.json.mensaje)"
}
Write-Host 'OK crear cajero (service authz)' -ForegroundColor Green

# gerente_cadena: requiere actor corporativo (permiso operar multi-sucursal)
$perfil = Invoke-FoodyApi -Method GET -Path '/auth/perfil' -Headers $h
$perms = @($perfil.json.datos.permisos)
$esCorp = $perms -contains 'gestionar_sucursales' -or ([string]$perfil.json.datos.rol) -eq 'gerente_cadena'

$cadena = Invoke-FoodyApi -Method POST -Path '/usuarios' -Headers $h -Body @{
    sucursal_id = $sid
    nombre      = 'QA Gerente Cadena'
    email       = "qa-cadena-$(Get-Date -Format 'HHmmss')@foody.test"
    contrasena  = '123456'
    rol         = 'gerente_cadena'
}
if ($esCorp) {
    if (-not ($cadena.ok -and $cadena.json.exito)) {
        throw "FALLO: actor corporativo no pudo crear gerente_cadena: $($cadena.json.mensaje)"
    }
    Write-Host 'OK crear gerente_cadena (actor corporativo demo)' -ForegroundColor Green
} else {
    if ($cadena.ok -and $cadena.json.exito) {
        throw 'FALLO: admin sede no corporativo creo gerente_cadena'
    }
    if ($cadena.status -ne 403) {
        Write-Host "AVISO: status=$($cadena.status) esperado 403 msg=$($cadena.json.mensaje)" -ForegroundColor Yellow
    } else {
        Write-Host 'OK gerente_cadena rechazado (403)' -ForegroundColor Green
    }
}

Write-Host ''
Write-Host 'BN-CTRL-02 usuarios OK' -ForegroundColor Green
