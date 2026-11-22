# CONS-PROMO-ADD + CFG-PATCH-SUCURSAL
# Uso: .\scripts\verificar-cons-promo-cfg-patch.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== CONS-PROMO-ADD / CFG-PATCH-SUCURSAL ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API salud fail' }

$admin = Get-FoodyToken 'admin@foody.demo'
$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$hAdmin = $admin.headers
$hCaja = $cajero.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$Precio = 8000

function Sql-Scalar([string]$Sql) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $raw = docker exec supabase-db psql -U postgres -d postgres -t -A -c $Sql 2>$null
  $ErrorActionPreference = $prev
  return ($raw -as [string]).Trim()
}

# --- CFG-PATCH-SUCURSAL-01 ---
$patch = Invoke-FoodyApi -Method PATCH -Path "/sucursales/$sid" -Headers $hAdmin -Body @{
  direccion = 'Calle QA CFG-PATCH'
}
if (-not ($patch.ok -and $patch.json.exito)) {
  throw "PATCH sucursal: $($patch.status) $($patch.json.mensaje)"
}
$dir = $patch.json.datos.direccion
if ($dir -ne 'Calle QA CFG-PATCH') { throw "direccion no persistio: $dir" }
Write-Host 'OK CFG-PATCH-SUCURSAL-01'

# --- CONS-PROMO-ADD-01 ---
# Promo % 10 demo o crear temporal
# imagen_url NOT NULL en estados_promociones
$promoId = Sql-Scalar "SELECT id::text FROM estados_promociones WHERE sucursal_id='$sid' AND codigo='QACONS10' AND activa=true LIMIT 1"
if (-not $promoId) {
  $promoId = Sql-Scalar @"
INSERT INTO estados_promociones (sucursal_id, titulo, codigo, descuento_porcentaje, activa, imagen_url, tipo_media)
VALUES ('$sid', 'QA CONS-PROMO', 'QACONS10', 10, true, 'https://foody.local/qa-cons-promo.png', 'imagen')
RETURNING id::text;
"@
}
if (-not $promoId) { throw 'No se pudo crear promo QA' }

$null = Limpiar-PedidosActivosDemo -Headers $hAdmin
$null = Ensure-CajaAbierta -Headers $hCaja
$libres = Get-MesasLibres -Headers $hCaja
if ($libres.Count -eq 0) { throw 'Sin mesa' }
$Mesa = $libres[0].id

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hCaja -Body @{
  sucursal_id     = $sid
  mesa_id         = $Mesa
  tipo            = 'mesa'
  device_id       = 'qa-cons-promo'
  metodo_pago     = 'efectivo'
  codigo_promocion = 'QACONS10'
  items           = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
if (-not ($crear.ok -and $crear.json.exito)) {
  # fallback: set promo after create
  $crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hCaja -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa
    tipo        = 'mesa'
    device_id   = 'qa-cons-promo2'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
  }
  if (-not ($crear.ok -and $crear.json.exito)) { throw "Crear: $($crear.json.mensaje)" }
  $pedidoId = $crear.json.datos.pedido_id
  if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }
  $null = Sql-Scalar "UPDATE pedidos SET promocion_id='$promoId', descuento=800, total=subtotal+costo_domicilio-800 WHERE id='$pedidoId'"
} else {
  $pedidoId = $crear.json.datos.pedido_id
  if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }
}

$sub1 = [double](Sql-Scalar "SELECT subtotal::text FROM pedidos WHERE id='$pedidoId'")
$desc1 = [double](Sql-Scalar "SELECT descuento::text FROM pedidos WHERE id='$pedidoId'")
# Force promo link if create used codigo path without id
$null = Sql-Scalar "UPDATE pedidos SET promocion_id=COALESCE(promocion_id, '$promoId') WHERE id='$pedidoId'"

$add = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedidoId/items?sucursal_id=$sid" -Headers $hCaja -Body @{
  items = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
if (-not ($add.ok -and $add.json.exito)) { throw "Add items: $($add.json.mensaje) $($add.json.error)" }

$sub2 = [double](Sql-Scalar "SELECT subtotal::text FROM pedidos WHERE id='$pedidoId'")
$desc2 = [double](Sql-Scalar "SELECT descuento::text FROM pedidos WHERE id='$pedidoId'")
$esperado = [Math]::Round($sub2 * 0.10)
if ([Math]::Abs($desc2 - $esperado) -gt 1) {
  throw "CONS-PROMO: sub=$sub2 desc=$desc2 (esperado ~$esperado). Antes sub=$sub1 desc=$desc1"
}
Write-Host "OK CONS-PROMO-ADD-01 (desc $desc1 -> $desc2 sobre sub $sub2)"

# cleanup promo
$null = Sql-Scalar "UPDATE estados_promociones SET activa=false WHERE id='$promoId'"

Write-Host '=== OK ===' -ForegroundColor Green
