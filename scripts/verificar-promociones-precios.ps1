# Prompt 18 — Promociones y precios: desactivar promo abierta, cambio precio, apilado.
# Uso: .\scripts\verificar-promociones-precios.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar Promociones / Precios (Prompt 18) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$h = $admin.headers
$hc = $cajero.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$PrecioOrig = 8000
$Codigo = 'QA18' + (Get-Date -Format 'HHmmss')
$script:fallos = 0
$promoId = $null

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

$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Ensure-CajaAbierta -Headers $hc
$null = Ensure-HorariosDemoAbiertos
$null = Restaurar-InventarioDemo -Headers $h
$null = Sql-Scalar "UPDATE productos SET precio=$PrecioOrig, disponible=true WHERE id='$Producto';"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- A) Desactivar promo con pedido abierto ---' -ForegroundColor Yellow

$crearPromo = Invoke-FoodyApi -Method POST -Path '/promociones' -Headers $h -Body @{
    sucursal_id           = $sid
    titulo                = 'QA Prompt 18'
    imagen_url            = 'https://example.com/qa18.png'
    codigo                = $Codigo
    descuento_porcentaje  = 10
}
Assert-Ok -Cond ($crearPromo.ok -and $crearPromo.json.exito) -Msg "Crear promo codigo=$Codigo ($($crearPromo.json.error))"
$promoId = $crearPromo.json.datos.id
if (-not $promoId) {
    $promoId = Sql-Scalar "SELECT id::text FROM estados_promociones WHERE codigo='$Codigo' AND sucursal_id='$sid' LIMIT 1;"
}

$preview = Invoke-FoodyApi -Path "/promociones/validar-codigo?sucursal_id=$sid&codigo=$Codigo&subtotal=$PrecioOrig" -Headers $h
Assert-Ok -Cond ($preview.ok -and $preview.json.exito) -Msg "validar-codigo preview ($($preview.json.error))"
$montoEsperado = [math]::Round($PrecioOrig * 0.1)
if ($preview.json.datos.monto) { $montoEsperado = [double]$preview.json.datos.monto }

$libres = Get-MesasLibres -Headers $hc
if ($libres.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres = Get-MesasLibres -Headers $hc
}
$Mesa = $libres[0].id

$crearPed = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id      = $sid
    mesa_id          = $Mesa
    tipo             = 'mesa'
    device_id        = 'qa-promo-open'
    metodo_pago      = 'efectivo'
    codigo_promocion = $Codigo
    items            = @(@{ producto_id = $Producto; cantidad = 1; precio = $PrecioOrig })
}
Assert-Ok -Cond ($crearPed.ok -and $crearPed.json.exito) -Msg "Pedido con promo ($($crearPed.json.error))"
$pedA = $crearPed.json.datos.pedido_id
if (-not $pedA) { $pedA = $crearPed.json.datos.id }

$descA = [double](Sql-Scalar "SELECT COALESCE(descuento,0)::text FROM pedidos WHERE id='$pedA';")
$totalA = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pedA';")
$promoPed = Sql-Scalar "SELECT promocion_id::text FROM pedidos WHERE id='$pedA';"
Assert-Ok -Cond ($descA -gt 0) -Msg "Descuento snapshot=$descA (esperado~$montoEsperado)"
Assert-Ok -Cond ($promoPed -eq $promoId) -Msg "promocion_id ligado ($promoPed)"
Assert-Ok -Cond ($totalA -eq ($PrecioOrig - $descA)) -Msg "total=$totalA = precio-descuento"

# Desactivar mientras pedido abierto
$off = Invoke-FoodyApi -Method PATCH -Path "/promociones/$promoId" -Headers $h -Body @{
    activa = $false
}
Assert-Ok -Cond ($off.ok -and $off.json.exito) -Msg "Desactivar promo ($($off.json.error))"

$descPost = [double](Sql-Scalar "SELECT COALESCE(descuento,0)::text FROM pedidos WHERE id='$pedA';")
$totalPost = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pedA';")
Assert-Ok -Cond ($descPost -eq $descA -and $totalPost -eq $totalA) -Msg "Descuento se mantiene tras desactivar ($descPost / $totalPost)"

# Codigo ya no aplica a pedidos NUEVOS
$crearNuevo = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id      = $sid
    tipo             = 'para_llevar'
    device_id        = 'qa-promo-off-new'
    metodo_pago      = 'pendiente'
    codigo_promocion = $Codigo
    items            = @(@{ producto_id = $Producto; cantidad = 1; precio = $PrecioOrig })
}
Assert-Ok -Cond (-not ($crearNuevo.ok -and $crearNuevo.json.exito)) -Msg "Codigo inactivo rechazado en pedido nuevo ($($crearNuevo.json.error))"

# Cobrar pedido abierto: usa total snapshot
$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedA/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'listo' }
$cobrar = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedA/cobrar?sucursal_id=$sid" -Headers $hc -Body @{
    metodo_pago = 'efectivo'
}
Assert-Ok -Cond ($cobrar.ok -and $cobrar.json.exito) -Msg "Cobrar con promo desactivada ($($cobrar.json.error))"
$venta = [double](Sql-Scalar "SELECT COALESCE(SUM(monto),0)::text FROM movimientos_caja WHERE pedido_id='$pedA' AND tipo='venta'")
Assert-Ok -Cond ([math]::Abs($venta - $totalA) -lt 0.02) -Msg "Caja cobro=$venta == total snapshot=$totalA"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- B) Cambiar precio producto con pedidos abiertos ---' -ForegroundColor Yellow

$null = Limpiar-PedidosActivosDemo -Headers $h
$libres = Get-MesasLibres -Headers $hc
$MesaB = $libres[0].id
$crearB = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $MesaB
    tipo        = 'mesa'
    device_id   = 'qa-precio-open'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $PrecioOrig })
}
$pedB = $crearB.json.datos.pedido_id
if (-not $pedB) { $pedB = $crearB.json.datos.id }
$puAntes = [double](Sql-Scalar "SELECT precio_unitario::text FROM pedido_items WHERE pedido_id='$pedB' LIMIT 1;")
$totalAntes = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pedB';")
Assert-Ok -Cond ($puAntes -eq $PrecioOrig) -Msg "precio_unitario congelado=$puAntes"

$PrecioNuevo = 12000
$patchProd = Invoke-FoodyApi -Method PATCH -Path "/productos/$Producto" -Headers $h -Body @{
    precio = $PrecioNuevo
}
Assert-Ok -Cond ($patchProd.ok -and $patchProd.json.exito) -Msg "PATCH precio catalogo -> $PrecioNuevo ($($patchProd.json.error))"

$puDespues = [double](Sql-Scalar "SELECT precio_unitario::text FROM pedido_items WHERE pedido_id='$pedB' LIMIT 1;")
$totalDespues = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pedB';")
Assert-Ok -Cond ($puDespues -eq $PrecioOrig) -Msg "Item abierto conserva precio viejo ($puDespues)"
Assert-Ok -Cond ($totalDespues -eq $totalAntes) -Msg "total pedido abierto no cambia ($totalDespues)"

# Agregar item: precio NUEVO del catalogo
$add = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedB/items?sucursal_id=$sid" -Headers $hc -Body @{
    items = @(@{ producto_id = $Producto; cantidad = 1; precio = 1 })
}
Assert-Ok -Cond ($add.ok -and $add.json.exito) -Msg "Agregar item tras cambio precio ($($add.json.error))"
$puNew = [double](Sql-Scalar @"
SELECT precio_unitario::text FROM pedido_items
WHERE pedido_id='$pedB' ORDER BY created_at DESC LIMIT 1;
"@)
Assert-Ok -Cond ($puNew -eq $PrecioNuevo) -Msg "Item nuevo usa precio catalogo actual ($puNew)"

$totalMix = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pedB';")
Assert-Ok -Cond ($totalMix -eq ($PrecioOrig + $PrecioNuevo)) -Msg "total mixto=$totalMix (viejo+nuevo)"

$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedB/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'listo' }
$cobrarB = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedB/cobrar?sucursal_id=$sid" -Headers $hc -Body @{
    metodo_pago = 'efectivo'
}
Assert-Ok -Cond ($cobrarB.ok -and $cobrarB.json.exito) -Msg "Cobrar mixto ($($cobrarB.json.error))"
$ventaB = [double](Sql-Scalar "SELECT COALESCE(SUM(monto),0)::text FROM movimientos_caja WHERE pedido_id='$pedB' AND tipo='venta'")
Assert-Ok -Cond ([math]::Abs($ventaB - $totalMix) -lt 0.02) -Msg "Caja=$ventaB == total mixto (no precio catalogo solo)"

# Restaurar precio
$null = Invoke-FoodyApi -Method PATCH -Path "/productos/$Producto" -Headers $h -Body @{ precio = $PrecioOrig }

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- C) Combos + promos / apilado ---' -ForegroundColor Yellow

$null = Limpiar-PedidosActivosDemo -Headers $h

# Reactivar promo o crear otra
$Codigo2 = 'QA18B' + (Get-Date -Format 'HHmmss')
$promo2 = Invoke-FoodyApi -Method POST -Path '/promociones' -Headers $h -Body @{
    sucursal_id          = $sid
    titulo               = 'QA Prompt 18 stack'
    imagen_url           = 'https://example.com/qa18b.png'
    codigo               = $Codigo2
    descuento_porcentaje = 10
}
$promo2Id = $promo2.json.datos.id
if (-not $promo2Id) {
    $promo2Id = Sql-Scalar "SELECT id::text FROM estados_promociones WHERE codigo='$Codigo2' LIMIT 1;"
}

$comboId = Sql-Scalar "SELECT id::text FROM combos WHERE sucursal_id='$sid' AND disponible=true LIMIT 1;"
$comboPrecio = [double](Sql-Scalar "SELECT precio_fijo::text FROM combos WHERE id='$comboId';")
Assert-Ok -Cond ($null -ne $comboId -and $comboPrecio -gt 0) -Msg "Combo demo ($comboId precio=$comboPrecio)"

$crearComboPromo = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id      = $sid
    tipo             = 'para_llevar'
    device_id        = 'qa-combo-promo'
    metodo_pago      = 'pendiente'
    codigo_promocion = $Codigo2
    combos           = @(@{ combo_id = $comboId; cantidad = 1; precio = $comboPrecio })
}
Assert-Ok -Cond ($crearComboPromo.ok -and $crearComboPromo.json.exito) -Msg "Combo+promo mismo pedido ($($crearComboPromo.json.error))"
$pedC = $crearComboPromo.json.datos.pedido_id
if (-not $pedC) { $pedC = $crearComboPromo.json.datos.id }
$descC = [double](Sql-Scalar "SELECT COALESCE(descuento,0)::text FROM pedidos WHERE id='$pedC';")
$subC = [double](Sql-Scalar "SELECT subtotal::text FROM pedidos WHERE id='$pedC';")
$totalC = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pedC';")
Assert-Ok -Cond ($subC -eq $comboPrecio) -Msg "Subtotal=precio_fijo combo ($subC)"
Assert-Ok -Cond ($descC -gt 0) -Msg "Promo aplica SOBRE combo (descuento=$descC) - apilado de facto"
Assert-Ok -Cond ($totalC -eq ($subC - $descC)) -Msg "total=subtotal-descuento ($totalC)"

# Una sola promo: no hay campo para 2 codigos; automaticas eligen 1
$nPromoCols = Sql-Scalar "SELECT COUNT(*)::text FROM information_schema.columns WHERE table_name='pedidos' AND column_name='promocion_id';"
Assert-Ok -Cond ($nPromoCols -eq '1') -Msg 'Un solo promocion_id por pedido (sin multi-promo)'

# Dos automaticas: crear segunda activa sin codigo y verificar mejor unica
$null = Invoke-FoodyApi -Method POST -Path '/promociones' -Headers $h -Body @{
    sucursal_id        = $sid
    titulo             = 'QA auto 5pct'
    imagen_url         = 'https://example.com/qa18auto.png'
    descuento_porcentaje = 5
}
$null = Invoke-FoodyApi -Method POST -Path '/promociones' -Headers $h -Body @{
    sucursal_id        = $sid
    titulo             = 'QA auto 15pct'
    imagen_url         = 'https://example.com/qa18auto2.png'
    descuento_porcentaje = 15
}
$crearAuto = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-auto-best'
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $PrecioOrig })
}
Assert-Ok -Cond ($crearAuto.ok -and $crearAuto.json.exito) -Msg "Pedido auto-promo ($($crearAuto.json.error))"
$pedAuto = $crearAuto.json.datos.pedido_id
if (-not $pedAuto) { $pedAuto = $crearAuto.json.datos.id }
$descAuto = [double](Sql-Scalar "SELECT COALESCE(descuento,0)::text FROM pedidos WHERE id='$pedAuto';")
# Mejor = 15% de 8000 = 1200
Assert-Ok -Cond ($descAuto -eq 1200 -or $descAuto -eq [math]::Round($PrecioOrig * 0.15)) `
    -Msg "Elige UNA automatica (mejor) descuento=$descAuto (no suma 5+15)"

# Cleanup promos QA
$null = Sql-Scalar @"
UPDATE estados_promociones SET activa=false
WHERE sucursal_id='$sid' AND (codigo LIKE 'QA18%' OR titulo LIKE 'QA auto%' OR titulo LIKE 'QA Prompt 18%');
"@
$null = Invoke-FoodyApi -Method PATCH -Path "/productos/$Producto" -Headers $h -Body @{ precio = $PrecioOrig }
$null = Limpiar-PedidosActivosDemo -Headers $h

Write-Host ''
if ($script:fallos -eq 0) {
    Write-Host 'Verificacion promociones-precios OK' -ForegroundColor Green
    exit 0
}
Write-Host "$($script:fallos) fallos" -ForegroundColor Red
exit 1
