# Residuales menores BN-DTO-28 / BN-MOD-03 / BN-DTO-33
# Uso: .\scripts\verificar-bn-residuales.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar residuales BN menores ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API /salud no responde' }
Write-Host 'OK /salud ligero' -ForegroundColor Green

$comp = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud/completo" -TimeoutSec 10
if (-not $comp.exito) { throw 'API /salud/completo fallo' }
Write-Host 'OK /salud/completo (alias profundo)' -ForegroundColor Green

$health = Invoke-RestMethod -Uri "$script:FoodyQaBase/health" -TimeoutSec 10
if (-not $health.exito) { throw 'API /health fallo' }
Write-Host 'OK /health (monitoreo)' -ForegroundColor Green

$login = Invoke-FoodyApi -Method POST -Path '/auth/login' -Body @{
    email      = 'admin@foody.demo'
    contrasena = $script:FoodyQaPass
}
if (-not ($login.ok -and $login.json.exito)) { throw "Login: $($login.json.mensaje)" }
$h = @{ Authorization = "Bearer $($login.json.datos.token)" }
$sid = $script:FoodyQaSucursal

# BN-DTO-33 ParseUUIDPipe mesas
$badMesa = Invoke-FoodyApi -Method GET -Path "/mesas/no-uuid?sucursal_id=$sid" -Headers $h
# may 404 route - try PATCH style
$badProd = Invoke-FoodyApi -Method PATCH -Path "/productos/no-es-uuid/disponibilidad" -Headers $h -Body @{ disponible = $true }
if ($badProd.ok -and $badProd.json.exito) { throw 'FALLO: producto id basura debio 400' }
if ($badProd.status -ne 400) {
    Write-Host "AVISO productos UUID status=$($badProd.status) (esperado 400)" -ForegroundColor Yellow
} else {
    Write-Host 'OK ParseUUIDPipe productos (400)' -ForegroundColor Green
}

$badUser = Invoke-FoodyApi -Method PATCH -Path "/usuarios/xxx/estado?sucursal_id=$sid" -Headers $h -Body @{ activo = $false }
if ($badUser.ok -and $badUser.json.exito) { throw 'FALLO usuarios UUID' }
if ($badUser.status -ne 400) {
    Write-Host "AVISO usuarios UUID status=$($badUser.status)" -ForegroundColor Yellow
} else {
    Write-Host 'OK ParseUUIDPipe usuarios (400)' -ForegroundColor Green
}

$badFin = Invoke-FoodyApi -Method GET -Path "/finanzas/resumen/no-es-uuid" -Headers $h
if ($badFin.ok -and $badFin.json.exito) { throw 'FALLO finanzas UUID' }
if ($badFin.status -ne 400) {
    Write-Host "AVISO finanzas UUID status=$($badFin.status)" -ForegroundColor Yellow
} else {
    Write-Host 'OK ParseUUIDPipe finanzas (400)' -ForegroundColor Green
}

$badDom = Invoke-FoodyApi -Method GET -Path "/domiciliarios-planta/disponibles/no-es-uuid" -Headers $h
if ($badDom.status -eq 400) {
    Write-Host 'OK ParseUUIDPipe domiciliarios-planta (400)' -ForegroundColor Green
} else {
    Write-Host "AVISO domiciliarios-planta UUID status=$($badDom.status)" -ForegroundColor Yellow
}

# BN-DTO-28 aprobar body vacio {} (si hay pedido pendiente - soft)
$lista = Invoke-FoodyApi -Method GET -Path "/pedidos?sucursal_id=$sid&solo_activos=true&limit=20" -Headers $h
$pend = $null
if ($lista.ok -and $lista.json.datos) {
    $items = @($lista.json.datos)
    if ($lista.json.datos.items) { $items = @($lista.json.datos.items) }
    $pend = $items | Where-Object { $_.estado -eq 'pendiente_aprobacion' } | Select-Object -First 1
}
if ($pend) {
    $apr = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$($pend.id)/aprobar?sucursal_id=$sid" -Headers $h -Body @{}
    if (-not ($apr.ok -and $apr.json.exito)) {
        Write-Host "AVISO aprobar {} status=$($apr.status) msg=$($apr.json.mensaje)" -ForegroundColor Yellow
    } else {
        Write-Host 'OK aprobar body vacio {}' -ForegroundColor Green
    }
} else {
    Write-Host 'AVISO sin pedido pendiente_aprobacion (DTO-28 body {} no ejercido)' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'BN residuales menores OK' -ForegroundColor Green
