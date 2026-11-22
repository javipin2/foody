# CONS-COSTO-SNAPSHOT / CONS-MARGEN-STALE — update cantidad reaplica margenes_venta
# Uso: .\scripts\verificar-cons-costo-snapshot.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== CONS-COSTO-SNAPSHOT / MARGEN-STALE ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API salud fail' }

$admin = Get-FoodyToken 'admin@foody.demo'
$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$hAdmin = $admin.headers
$hCaja = $cajero.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'

function Sql-Scalar([string]$Sql) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $raw = docker exec supabase-db psql -U postgres -d postgres -t -A -c $Sql 2>$null
  $ErrorActionPreference = $prev
  return ($raw -as [string]).Trim()
}

# A) Analítica inventario expone fuentes_cogs
$inv = Invoke-FoodyApi -Path "/analitica/inventario?sucursal_id=$sid&preset=30d" -Headers $hAdmin
if (-not ($inv.ok -and $inv.json.exito)) { throw "analitica/inventario: $($inv.status)" }
$fuentes = $inv.json.datos.fuentes_cogs
if (-not $fuentes -or -not $fuentes.nota) { throw 'Falta fuentes_cogs.nota en inventario' }
Write-Host 'OK analitica inventario fuentes_cogs'

$rent = Invoke-FoodyApi -Path "/analitica/rentabilidad?sucursal_id=$sid&preset=30d" -Headers $hAdmin
if (-not ($rent.ok -and $rent.json.exito)) { throw "rentabilidad: $($rent.status)" }
if ([string]$rent.json.datos.fuente_cogs -notmatch 'pedido_items') {
  throw "fuente_cogs rentabilidad: $($rent.json.datos.fuente_cogs)"
}
Write-Host 'OK rentabilidad fuente_cogs snapshot'

# B) Editar cantidad → margenes_venta.costo_al_momento = costo_unitario * cantidad
$null = Limpiar-PedidosActivosDemo -Headers $hAdmin
$null = Ensure-CajaAbierta -Headers $hCaja
$libres = Get-MesasLibres -Headers $hCaja
if ($libres.Count -eq 0) { throw 'Sin mesa' }
$Mesa = $libres[0].id

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hCaja -Body @{
  sucursal_id = $sid
  mesa_id     = $Mesa
  tipo        = 'mesa'
  device_id   = 'qa-cons-costo'
  metodo_pago = 'efectivo'
  items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if (-not ($crear.ok -and $crear.json.exito)) { throw "Crear: $($crear.json.mensaje)" }
$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }

$itemId = Sql-Scalar "SELECT id::text FROM pedido_items WHERE pedido_id='$pedidoId' LIMIT 1"
if (-not $itemId) { throw 'Sin item' }

$patch = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/items/$itemId`?sucursal_id=$sid" -Headers $hCaja -Body @{
  cantidad = 3
}
if (-not ($patch.ok -and $patch.json.exito)) {
  throw "PATCH item: $($patch.status) $($patch.json.mensaje) $($patch.json.error)"
}

$pair = Sql-Scalar @"
SELECT (pi.costo_unitario::numeric * pi.cantidad)::text || '|' || m.costo_al_momento::text
FROM pedido_items pi
JOIN margenes_venta m ON m.pedido_item_id = pi.id
WHERE pi.id = '$itemId'
"@
if (-not ($pair -match '\|')) { throw "Sin margenes_venta: $pair" }
$parts = $pair -split '\|'
$esperado = [double]$parts[0]
$ledger = [double]$parts[1]
if ([math]::Abs($esperado - $ledger) -gt 0.02) {
  throw "CONS-MARGEN-STALE: ledger=$ledger esperado=$esperado"
}
Write-Host "OK margenes_venta tras qty=3 (costo=$ledger)"

Write-Host '=== OK ===' -ForegroundColor Green
