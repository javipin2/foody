# F4 - Sesion & totales: AUTH-STORE (JWT secure) + POST /pedidos/estimar
# Uso: .\scripts\verificar-f4-sesion.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar F4 sesion & totales ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$sid = $script:FoodyQaSucursal
$ProdB = 'f0000000-0000-4000-8000-000000000002'
$script:fallos = 0

function Assert-Ok {
    param([bool]$Cond, [string]$Msg)
    if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
    else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

function Sql-Scalar([string]$Sql) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $raw = docker exec supabase-db psql -U postgres -d postgres -t -A -c $Sql 2>$null
    $ErrorActionPreference = $prev
    return ($raw -as [string]).Trim()
}

Write-Host ''
Write-Host '--- A AUTH-STORE (codigo) ---' -ForegroundColor Yellow
$sesionSrc = Get-Content -Raw "$PSScriptRoot\..\lib\core\sesion\sesion_staff_service.dart"
Assert-Ok -Cond ($sesionSrc -match 'FlutterSecureStorage') -Msg 'SesionStaffService usa FlutterSecureStorage'
Assert-Ok -Cond ($sesionSrc -match 'prefs\.remove\(_keyToken\)') -Msg 'Migracion limpia token de prefs (movil)'
Assert-Ok -Cond ($sesionSrc -match 'kIsWeb') -Msg 'Web usa prefs (evita MissingPluginException)'
Assert-Ok -Cond ($sesionSrc -match 'MissingPluginException') -Msg 'Fallback documentado ante fallo plugin'
$pub = Get-Content -Raw "$PSScriptRoot\..\pubspec.yaml"
Assert-Ok -Cond ($pub -match 'flutter_secure_storage') -Msg 'pubspec declara flutter_secure_storage'

Write-Host ''
Write-Host '--- B POST /pedidos/estimar ---' -ForegroundColor Yellow
$null = Ensure-HorariosDemoAbiertos
$precioBd = Sql-Scalar "SELECT precio::text FROM productos WHERE id='$ProdB'"
Assert-Ok -Cond ($precioBd -ne '') -Msg "Precio BD producto B ($precioBd)"

$est = Invoke-FoodyApi -Method POST -Path '/pedidos/estimar' -Body @{
    sucursal_id = $sid
    device_id   = 'qa-f4-estimar'
    tipo        = 'para_llevar'
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $ProdB; cantidad = 2; precio = 1 })
}
Assert-Ok -Cond ($est.ok -and $est.json.exito) -Msg 'estimar OK'
$datos = $est.json.datos
$total = [double]$datos.total
$sub = [double]$datos.subtotal
$esperado = [double]$precioBd * 2
Assert-Ok -Cond ($sub -eq $esperado) -Msg "subtotal=$sub == BD*$esperado (ignora precio cliente=1)"
Assert-Ok -Cond ($total -eq $sub) -Msg "total=$total == subtotal (sin domicilio/promo)"
Assert-Ok -Cond ($null -eq $datos.pedido_id) -Msg 'estimar no crea pedido_id'

$antes = Sql-Scalar "SELECT COUNT(*) FROM pedidos WHERE device_id='qa-f4-estimar'"
Assert-Ok -Cond ([int]$antes -eq 0) -Msg 'BD sin pedido tras estimar'

# Error esperado: producto inexistente
$bad = Invoke-FoodyApi -Method POST -Path '/pedidos/estimar' -Body @{
    sucursal_id = $sid
    device_id   = 'qa-f4-estimar'
    tipo        = 'para_llevar'
    items       = @(@{ producto_id = '00000000-0000-4000-8000-000000000099'; cantidad = 1; precio = 0 })
}
Assert-Ok -Cond ((-not $bad.ok) -or (-not $bad.json.exito)) -Msg 'estimar producto fake rechazado'

Write-Host ''
if ($script:fallos -gt 0) {
    Write-Host "F4 FALLA ($script:fallos)" -ForegroundColor Red
    exit 1
}
Write-Host 'F4 sesion OK' -ForegroundColor Green
exit 0
