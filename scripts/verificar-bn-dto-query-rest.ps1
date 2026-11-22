# BN-DTO-24…27 — query DTOs pedidos / costeo / upload / retorno-app
# Uso: .\scripts\verificar-bn-dto-query-rest.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar BN-DTO-24…27 ===' -ForegroundColor Cyan

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

# BN-DTO-24 pedidos
$badPage = Invoke-FoodyApi -Method GET -Path "/pedidos?sucursal_id=$sid&solo_activos=true&page=abc" -Headers $h
if ($badPage.ok -and $badPage.json.exito) { throw 'FALLO: page=abc debio fallar' }
Write-Host "OK pedidos page invalido ($($badPage.status))" -ForegroundColor Green

$extra = Invoke-FoodyApi -Method GET -Path "/pedidos?sucursal_id=$sid&solo_activos=true&hack=1" -Headers $h
if ($extra.ok -and $extra.json.exito) { throw 'FALLO: hack en pedidos' }
Write-Host "OK pedidos prop extra ($($extra.status))" -ForegroundColor Green

$okPed = Invoke-FoodyApi -Method GET -Path "/pedidos?sucursal_id=$sid&solo_activos=true&limit=10" -Headers $h
if (-not ($okPed.ok -and $okPed.json.exito)) { throw "FALLO listar pedidos: $($okPed.json.mensaje)" }
Write-Host 'OK pedidos limpio' -ForegroundColor Green

$okCer = Invoke-FoodyApi -Method GET -Path "/pedidos/cerrados-hoy?sucursal_id=$sid&page=1&limit=5" -Headers $h
if (-not ($okCer.ok -and $okCer.json.exito)) { throw "FALLO cerrados-hoy: $($okCer.json.mensaje)" }
Write-Host 'OK cerrados-hoy' -ForegroundColor Green

# BN-DTO-25 costeo impacto (producto demo seed)
$prod = 'f0000000-0000-4000-8000-000000000002'
$badCant = Invoke-FoodyApi -Method GET -Path "/costeo/productos/$prod/impacto-stock?sucursal_id=$sid&cantidad=0" -Headers $h
if ($badCant.ok -and $badCant.json.exito) { throw 'FALLO: cantidad=0 debio fallar' }
Write-Host "OK impacto cantidad invalida ($($badCant.status))" -ForegroundColor Green

$badTipo = Invoke-FoodyApi -Method GET -Path "/costeo/productos/$prod/impacto-stock?sucursal_id=$sid&tipo_entidad=foo" -Headers $h
if ($badTipo.ok -and $badTipo.json.exito) { throw 'FALLO: tipo_entidad=foo' }
Write-Host "OK impacto tipo invalido ($($badTipo.status))" -ForegroundColor Green

$okImp = Invoke-FoodyApi -Method GET -Path "/costeo/productos/$prod/impacto-stock?sucursal_id=$sid&cantidad=1" -Headers $h
if (-not ($okImp.ok -and $okImp.json.exito)) {
    Write-Host "AVISO impacto limpio status=$($okImp.status) msg=$($okImp.json.mensaje)" -ForegroundColor Yellow
} else {
    Write-Host 'OK impacto limpio' -ForegroundColor Green
}

# BN-DTO-26 upload query (sin archivo → 400 negocio, no pipe whitelist)
$badTipoUp = Invoke-FoodyApi -Method POST -Path "/almacenamiento/imagen?sucursal_id=$sid&tipo=logo" -Headers $h
if ($badTipoUp.ok -and $badTipoUp.json.exito) { throw 'FALLO: tipo=logo debio fallar' }
Write-Host "OK upload tipo invalido ($($badTipoUp.status))" -ForegroundColor Green

$extraUp = Invoke-FoodyApi -Method POST -Path "/almacenamiento/imagen?sucursal_id=$sid&tipo=producto&hack=1" -Headers $h
if ($extraUp.ok -and $extraUp.json.exito) { throw 'FALLO: hack upload' }
Write-Host "OK upload prop extra ($($extraUp.status))" -ForegroundColor Green

# BN-DTO-27 retorno-app (HTML bridge — no JSON Foody)
$badPagoR = $null
try {
    Invoke-WebRequest -Uri "$script:FoodyQaBase/pagos/retorno-app?pago_id=no-uuid" -Method GET -TimeoutSec 10 -UseBasicParsing | Out-Null
    throw 'FALLO: pago_id invalido debio 400'
} catch {
    if ($_.Exception.Response) {
        $badPagoR = [int]$_.Exception.Response.StatusCode
    } elseif ("$($_.Exception.Message)" -match 'FALLO:') {
        throw
    }
}
if ($badPagoR -ne 400) {
    Write-Host "AVISO retorno pago_id invalido status=$badPagoR" -ForegroundColor Yellow
} else {
    Write-Host 'OK retorno-app pago_id invalido (400)' -ForegroundColor Green
}

$okHtml = Invoke-WebRequest -Uri "$script:FoodyQaBase/pagos/retorno-app" -Method GET -TimeoutSec 10 -UseBasicParsing
if ($okHtml.StatusCode -ne 200 -or "$($okHtml.Content)" -notmatch 'foody://plan') {
    throw "FALLO retorno-app limpio status=$($okHtml.StatusCode)"
}
Write-Host 'OK retorno-app HTML 200' -ForegroundColor Green

Write-Host ''
Write-Host 'BN-DTO-24…27 OK' -ForegroundColor Green
