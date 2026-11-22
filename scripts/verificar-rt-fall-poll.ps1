# RT-POLL / RT-FALL / CONS-NODISP-STOCK smoke.
# Uso: .\scripts\verificar-rt-fall-poll.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== RT-FALL / RT-POLL / CONS-NODISP-STOCK ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API salud fail' }
Write-Host 'OK salud'

# RT-POLL-01: helper reprograma (no Timer.periodic fijo)
$pollSrc = Get-Content "$PSScriptRoot\..\lib\core\realtime\poll_realtime_respaldo.dart" -Raw
if ($pollSrc -notmatch 'intervaloRtCaido') { throw 'PollRealtimeRespaldo sin intervaloRtCaido' }
if ($pollSrc -match 'Timer\.periodic') { throw 'PollRealtimeRespaldo aun usa Timer.periodic (RT-POLL)' }
if ($pollSrc -notmatch '_programarSiguiente') { throw 'PollRealtimeRespaldo sin reevaluacion por ciclo' }
Write-Host 'OK RT-POLL-01 (poll adaptativo en codigo)'

# RT-FALL-01: pantallas cableadas
$fallFiles = @(
  'lib\features\menu\presentation\menu_screen_foody.dart',
  'lib\features\pedidos\presentation\pedido_cajero_screen.dart',
  'lib\features\admin\presentation\panel_restaurante_screen.dart',
  'lib\features\domiciliarios\presentation\dashboard_domiciliario_screen.dart'
)
foreach ($rel in $fallFiles) {
  $p = Join-Path $PSScriptRoot "..\$rel"
  $t = Get-Content $p -Raw
  if ($t -notmatch 'PollRealtimeRespaldo') { throw "RT-FALL: falta Poll en $rel" }
}
Write-Host 'OK RT-FALL-01 (menu/POS/panel/domi)'

# CONS-NODISP-STOCK: N/D cocina apaga producto
$admin = Get-FoodyToken 'admin@foody.demo'
$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$cocina = Get-FoodyToken 'cocina@foody.demo'
$hAdmin = $admin.headers
$hCaja = $cajero.headers
$hCoc = $cocina.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'

function Sql-Scalar([string]$Sql) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $raw = docker exec supabase-db psql -U postgres -d postgres -t -A -c $Sql 2>$null
  $ErrorActionPreference = $prev
  return ($raw -as [string]).Trim()
}

$null = Limpiar-PedidosActivosDemo -Headers $hAdmin
$null = Ensure-CajaAbierta -Headers $hCaja
# Restaurar disponible del producto demo
$null = Sql-Scalar "UPDATE productos SET disponible = true WHERE id='$Producto' AND sucursal_id='$sid'"

$libres = Get-MesasLibres -Headers $hCaja
if ($libres.Count -eq 0) {
  $null = Limpiar-PedidosActivosDemo -Headers $hAdmin
  $libres = Get-MesasLibres -Headers $hCaja
}
if ($libres.Count -eq 0) { throw 'Sin mesa libre' }
$Mesa = $libres[0].id

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hCaja -Body @{
  sucursal_id = $sid
  mesa_id     = $Mesa
  tipo        = 'mesa'
  device_id   = 'qa-cons-nodisp'
  metodo_pago = 'efectivo'
  items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if (-not ($crear.ok -and $crear.json.exito)) { throw "Crear: $($crear.json.mensaje)" }
$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }
$itemId = Sql-Scalar "SELECT id::text FROM pedido_items WHERE pedido_id='$pedidoId' ORDER BY created_at LIMIT 1"
if (-not $itemId) { throw 'Sin item' }

$null = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$itemId/estado" -Headers $hCoc -Body @{
  estado_cocina = 'preparando'
}
$fallo = Invoke-FoodyApi -Method POST -Path "/cocina/items/$itemId/fallo-preparacion" -Headers $hCoc -Body @{
  motivo = 'qa-cons-nodisp-stock'
}
if (-not ($fallo.ok -and $fallo.json.exito)) {
  throw "N/D: $($fallo.json.mensaje) error=$($fallo.json.error)"
}

$disp = Sql-Scalar "SELECT disponible::text FROM productos WHERE id='$Producto' AND sucursal_id='$sid'"
if ($disp -ne 'f' -and $disp -ne 'false') {
  throw "CONS-NODISP: esperado disponible=false, obtuvo '$disp'"
}
Write-Host 'OK CONS-NODISP-STOCK-01 (producto off menu tras N/D)'

# Cleanup: reactivar producto
$null = Sql-Scalar "UPDATE productos SET disponible = true WHERE id='$Producto' AND sucursal_id='$sid'"

Write-Host '=== OK ===' -ForegroundColor Green
