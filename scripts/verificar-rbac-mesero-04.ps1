# RBAC-MESERO-04 / RBAC-FIX-04: mesero NO asigna domiciliarios.
# Uso: .\scripts\verificar-rbac-mesero-04.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar RBAC-MESERO-04 (mesero no asigna domi) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$mesero = Get-FoodyToken 'mesero@foody.com'
$h = $admin.headers
$hm = $mesero.headers
$sid = $script:FoodyQaSucursal
$script:fallos = 0

function Assert-Ok {
    param([bool]$Cond, [string]$Msg)
    if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
    else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

$fakePedido = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
$fakeDomi = 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff'

Write-Host ''
Write-Host '--- Mesero: 403 en write/list dispatch ---' -ForegroundColor Yellow

$disp = Invoke-FoodyApi -Method GET -Path "/domiciliarios-planta/disponibles/$sid" -Headers $hm
Assert-Ok -Cond ($disp.status -eq 403) -Msg "Mesero GET disponibles -> 403 (status=$($disp.status))"

$asig = Invoke-FoodyApi -Method POST -Path '/domiciliarios-planta/asignar' -Headers $hm -Body @{
    sucursal_id               = $sid
    pedido_id                 = $fakePedido
    domiciliario_planta_id    = $fakeDomi
}
Assert-Ok -Cond ($asig.status -eq 403) -Msg "Mesero POST asignar -> 403 (status=$($asig.status))"

$reas = Invoke-FoodyApi -Method POST -Path '/domiciliarios-planta/reasignar' -Headers $hm -Body @{
    sucursal_id               = $sid
    pedido_id                 = $fakePedido
    domiciliario_planta_id    = $fakeDomi
}
Assert-Ok -Cond ($reas.status -eq 403) -Msg "Mesero POST reasignar -> 403 (status=$($reas.status))"

$indep = Invoke-FoodyApi -Method POST -Path "/domiciliarios-planta/dispatch-independiente/$fakePedido`?sucursal_id=$sid" -Headers $hm
Assert-Ok -Cond ($indep.status -eq 403) -Msg "Mesero POST dispatch-independiente -> 403 (status=$($indep.status))"

Write-Host ''
Write-Host '--- Admin: pasar RolGuard (no 403 por permiso) ---' -ForegroundColor Yellow

$dispA = Invoke-FoodyApi -Method GET -Path "/domiciliarios-planta/disponibles/$sid" -Headers $h
Assert-Ok -Cond ($dispA.status -ne 403) -Msg "Admin GET disponibles no 403 (status=$($dispA.status) exito=$($dispA.json.exito))"

$asigA = Invoke-FoodyApi -Method POST -Path '/domiciliarios-planta/asignar' -Headers $h -Body @{
    sucursal_id               = $sid
    pedido_id                 = $fakePedido
    domiciliario_planta_id    = $fakeDomi
}
Assert-Ok -Cond ($asigA.status -ne 403) -Msg "Admin POST asignar no 403 por RBAC (status=$($asigA.status) err=$($asigA.json.error))"

Write-Host ''
if ($script:fallos -gt 0) {
    Write-Host "FALLOS: $($script:fallos)" -ForegroundColor Red
    exit 1
}
Write-Host 'RBAC-MESERO-04 OK' -ForegroundColor Green
exit 0
