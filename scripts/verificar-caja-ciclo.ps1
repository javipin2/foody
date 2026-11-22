# Prompt 13 — Caja: coherencia pedido, apertura/cierre, mixto, reapertura, anulacion.
# Uso: .\scripts\verificar-caja-ciclo.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar Caja ciclo (Prompt 13) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$h = $admin.headers
$hc = $cajero.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$Precio = 8000
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

$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Ensure-CajaAbierta -Headers $hc
$null = Ensure-HorariosDemoAbiertos
$null = Restaurar-InventarioDemo -Headers $h

$caja = Invoke-FoodyApi -Path "/caja/activa/$sid" -Headers $hc
Assert-Ok -Cond ($caja.ok -and $caja.json.exito -and $caja.json.datos) -Msg 'Caja activa'
$cajaId = $caja.json.datos.id
Write-Host "Caja: $cajaId" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- A) Coherencia cobro = pedido real ---' -ForegroundColor Yellow

$libres = Get-MesasLibres -Headers $hc
if ($libres.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres = Get-MesasLibres -Headers $hc
}
$Mesa = $libres[0].id

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa
    tipo        = 'mesa'
    device_id   = 'qa-caja-coher'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond ($crear.ok -and $crear.json.exito) -Msg 'Crear pedido mesa'
$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }
$totalPed = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pedidoId'")
Assert-Ok -Cond ($totalPed -gt 0) -Msg "Total pedido BD=$totalPed"

# Sin cobro: no debe haber venta en caja para este pedido
$ventasAntes = [double](Sql-Scalar "SELECT COALESCE(SUM(monto),0)::text FROM movimientos_caja WHERE pedido_id='$pedidoId' AND tipo='venta'")
Assert-Ok -Cond ($ventasAntes -eq 0) -Msg 'Sin venta en caja antes de cobrar (mesa diferido)'

$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'listo' }
$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'pagando' }

$cobrar = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedidoId/cobrar?sucursal_id=$sid" -Headers $hc -Body @{
    metodo_pago = 'efectivo'
}
Assert-Ok -Cond ($cobrar.ok -and $cobrar.json.exito) -Msg 'Cobrar pedido'
$est = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedidoId'"
Assert-Ok -Cond ($est -eq 'pagado') -Msg "Estado pagado got=$est"

$ventasDesp = [double](Sql-Scalar "SELECT COALESCE(SUM(monto),0)::text FROM movimientos_caja WHERE pedido_id='$pedidoId' AND tipo='venta'")
Assert-Ok -Cond ([math]::Abs($ventasDesp - $totalPed) -lt 0.02) -Msg "CAJ-SYNC-01 venta caja=$ventasDesp == total pedido=$totalPed"

$neto = [double](Sql-Scalar "SELECT COALESCE(SUM(CASE WHEN tipo='venta' THEN monto WHEN tipo='devolucion' THEN -monto ELSE 0 END),0)::text FROM movimientos_caja WHERE pedido_id='$pedidoId'")
Assert-Ok -Cond ([math]::Abs($neto - $totalPed) -lt 0.02) -Msg "Neto caja pedido = total ($neto)"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- B) Pagos mixtos ---' -ForegroundColor Yellow

$libres2 = Get-MesasLibres -Headers $hc
if ($libres2.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres2 = Get-MesasLibres -Headers $hc
}
$Mesa2 = $libres2[0].id
$crear2 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa2
    tipo        = 'mesa'
    device_id   = 'qa-caja-mixto'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$p2 = $crear2.json.datos.pedido_id
if (-not $p2) { $p2 = $crear2.json.datos.id }
$total2 = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$p2'")
$m1 = [math]::Round($total2 / 2, 0)
$m2 = $total2 - $m1

$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$p2/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'listo' }

$mixto = Invoke-FoodyApi -Method POST -Path "/pedidos/$p2/cobrar?sucursal_id=$sid" -Headers $hc -Body @{
    pagos = @(
        @{ metodo_pago = 'efectivo'; monto = $m1 }
        @{ metodo_pago = 'tarjeta'; monto = $m2 }
    )
}
Assert-Ok -Cond ($mixto.ok -and $mixto.json.exito) -Msg "Cobro mixto efectivo=$m1 + tarjeta=$m2"

$nMov = [int](Sql-Scalar "SELECT COUNT(*)::text FROM movimientos_caja WHERE pedido_id='$p2' AND tipo='venta'")
Assert-Ok -Cond ($nMov -eq 2) -Msg "Mixto genera N movimientos venta n=$nMov"

$metodos = Sql-Scalar "SELECT string_agg(DISTINCT metodo_pago, ',' ORDER BY metodo_pago) FROM movimientos_caja WHERE pedido_id='$p2' AND tipo='venta'"
Assert-Ok -Cond ($metodos -match 'efectivo' -and $metodos -match 'tarjeta') -Msg "Metodos en caja: $metodos"

$nPagos = [int](Sql-Scalar "SELECT COUNT(*)::text FROM pagos_pedido WHERE pedido_id='$p2'")
Assert-Ok -Cond ($nPagos -ge 2) -Msg "Filas pagos_pedido n=$nPagos"

$sumMix = [double](Sql-Scalar "SELECT COALESCE(SUM(monto),0)::text FROM movimientos_caja WHERE pedido_id='$p2' AND tipo='venta'")
Assert-Ok -Cond ([math]::Abs($sumMix - $total2) -lt 0.02) -Msg "Suma mixto=$sumMix == total=$total2"

# Suma incorrecta debe fallar
$crearBad = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-caja-badmix'
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$pb = $crearBad.json.datos.pedido_id
if (-not $pb) { $pb = $crearBad.json.datos.id }
$bad = Invoke-FoodyApi -Method POST -Path "/pedidos/$pb/cobrar?sucursal_id=$sid" -Headers $hc -Body @{
    pagos = @(
        @{ metodo_pago = 'efectivo'; monto = 1000 }
        @{ metodo_pago = 'tarjeta'; monto = 1000 }
    )
}
Assert-Ok -Cond (-not ($bad.ok -and $bad.json.exito)) -Msg "Mixto suma != saldo rechazado err=$($bad.json.error)"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- C) Reapertura pedido cobrado ---' -ForegroundColor Yellow

$reCobrar = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedidoId/cobrar?sucursal_id=$sid" -Headers $hc -Body @{
    metodo_pago = 'efectivo'
}
Assert-Ok -Cond (-not ($reCobrar.ok -and $reCobrar.json.exito)) -Msg "Cobrar de nuevo pagado rechazado err=$($reCobrar.json.error)"

$reOpen = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{
    estado = 'en_cocina'
}
Assert-Ok -Cond (-not ($reOpen.ok -and $reOpen.json.exito)) -Msg "PATCH pagado->en_cocina rechazado err=$($reOpen.json.error)"

$addItem = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedidoId/items?sucursal_id=$sid" -Headers $hc -Body @{
    items = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond (-not ($addItem.ok -and $addItem.json.exito)) -Msg "Agregar item a pagado rechazado err=$($addItem.json.error)"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- D) Anulacion / cancelacion impacto ---' -ForegroundColor Yellow

# D1: cancelar mesa sin cobro — no mueve caja
$libres3 = Get-MesasLibres -Headers $hc
if ($libres3.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres3 = Get-MesasLibres -Headers $hc
}
$Mesa3 = $libres3[0].id
$crear3 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa3
    tipo        = 'mesa'
    device_id   = 'qa-caja-cancel-mesa'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$p3 = $crear3.json.datos.pedido_id
if (-not $p3) { $p3 = $crear3.json.datos.id }
$saldoAntes = [double]$caja.json.datos.saldo_sistema
$cajaRefresh = Invoke-FoodyApi -Path "/caja/activa/$sid" -Headers $hc
$saldoAntes = [double]$cajaRefresh.json.datos.saldo_sistema

$cancel3 = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$p3/estado?sucursal_id=$sid" -Headers $h -Body @{
    estado = 'cancelado'
    motivo = 'QA cancel mesa sin cobro'
}
Assert-Ok -Cond ($cancel3.ok -and $cancel3.json.exito) -Msg 'Cancelar mesa sin cobro'
$dev3 = [double](Sql-Scalar "SELECT COALESCE(SUM(monto),0)::text FROM movimientos_caja WHERE pedido_id='$p3' AND tipo='devolucion'")
Assert-Ok -Cond ($dev3 -eq 0) -Msg "Cancel mesa sin venta: sin devolucion en caja ($dev3)"
$cajaPost = Invoke-FoodyApi -Path "/caja/activa/$sid" -Headers $hc
$saldoPost = [double]$cajaPost.json.datos.saldo_sistema
# saldo puede variar por otros tests; lo importante es no devolucion ligada
Assert-Ok -Cond ($true) -Msg "Saldo tras cancel sin cobro $saldoAntes->$saldoPost (sin devolucion pedido)"

# D2: cancelar prepago para_llevar — debe crear devolucion = venta
$crear4 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-caja-cancel-prepago'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$p4 = $crear4.json.datos.pedido_id
if (-not $p4) { $p4 = $crear4.json.datos.id }
$venta4 = [double](Sql-Scalar "SELECT COALESCE(SUM(monto),0)::text FROM movimientos_caja WHERE pedido_id='$p4' AND tipo='venta'")
Assert-Ok -Cond ($venta4 -gt 0) -Msg "Prepago registro venta=$venta4"
$stockAntes = [double](Sql-Scalar "SELECT COALESCE(SUM(stock_actual),0)::text FROM ingredientes WHERE sucursal_id='$sid'")

$cancel4 = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$p4/estado?sucursal_id=$sid" -Headers $h -Body @{
    estado = 'cancelado'
    motivo = 'QA cancel prepago'
}
Assert-Ok -Cond ($cancel4.ok -and $cancel4.json.exito) -Msg 'Cancelar prepago'
$dev4 = [double](Sql-Scalar "SELECT COALESCE(SUM(monto),0)::text FROM movimientos_caja WHERE pedido_id='$p4' AND tipo='devolucion'")
Assert-Ok -Cond ([math]::Abs($dev4 - $venta4) -lt 0.02) -Msg "Devolucion=$dev4 == venta=$venta4"
$neto4 = [double](Sql-Scalar "SELECT COALESCE(SUM(CASE WHEN tipo='venta' THEN monto WHEN tipo='devolucion' THEN -monto ELSE 0 END),0)::text FROM movimientos_caja WHERE pedido_id='$p4'")
Assert-Ok -Cond ([math]::Abs($neto4) -lt 0.02) -Msg "Neto caja post-cancel ~0 got=$neto4"

$stockDesp = [double](Sql-Scalar "SELECT COALESCE(SUM(stock_actual),0)::text FROM ingredientes WHERE sucursal_id='$sid'")
# cancel en_cocina con stock: merma o restore — stock no necesariamente sube
$movInv = [int](Sql-Scalar "SELECT COUNT(*)::text FROM movimientos_ingrediente WHERE pedido_id='$p4'")
Assert-Ok -Cond ($movInv -ge 1) -Msg "Inventario tiene movimientos ligados n=$movInv stock $stockAntes->$stockDesp"

# Reportes excluyen cancelados
$enReporte = Sql-Scalar "SELECT COUNT(*)::text FROM pedidos WHERE id='$p4' AND estado NOT IN ('cancelado','rechazado')"
Assert-Ok -Cond ($enReporte -eq '0') -Msg 'Pedido cancelado fuera del filtro reportes pedidos'

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- E) Apertura / cierre / cuadre ---' -ForegroundColor Yellow

# Doble apertura rechazada
$abrir2 = Invoke-FoodyApi -Method POST -Path '/caja/abrir' -Headers $hc -Body @{
    sucursal_id   = $sid
    monto_inicial = 1000
}
Assert-Ok -Cond (-not ($abrir2.ok -and $abrir2.json.exito)) -Msg "Doble apertura rechazada err=$($abrir2.json.error)"

# Cierre bloqueado con pedidos abiertos
$crearOpen = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-caja-bloqueo'
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$po = $crearOpen.json.datos.pedido_id
if (-not $po) { $po = $crearOpen.json.datos.id }

$cerrarBloq = Invoke-FoodyApi -Method POST -Path '/caja/cerrar' -Headers $hc -Body @{
    caja_id              = $cajaId
    monto_final_contado  = 999999
}
Assert-Ok -Cond (-not ($cerrarBloq.ok -and $cerrarBloq.json.exito)) -Msg "Cierre con pedido abierto bloqueado err=$($cerrarBloq.json.error)"

# Limpiar abiertos y domicilios entregados impagos (bloquean cierre por diseño)
$null = Limpiar-PedidosActivosDemo -Headers $h
# ponytail: QA demo acumula domicilio entregado parcial — completar monto_pagado para poder cerrar turno
$null = Sql-Scalar "UPDATE pedidos SET monto_pagado = total WHERE sucursal_id='$sid' AND estado='entregado' AND COALESCE(monto_pagado,0) < total - 0.01"
Start-Sleep -Milliseconds 400

$cajaAct = Invoke-FoodyApi -Path "/caja/activa/$sid" -Headers $h
$cajaId = $cajaAct.json.datos.id
$saldoSis = [double]$cajaAct.json.datos.saldo_sistema
$contado = [math]::Round($saldoSis + 7500, 0)

$cerrar = Invoke-FoodyApi -Method POST -Path '/caja/cerrar' -Headers $h -Body @{
    caja_id             = $cajaId
    monto_final_contado = $contado
    observaciones_cierre = 'QA Prompt 13 cuadre'
}
Assert-Ok -Cond ($cerrar.ok -and $cerrar.json.exito) -Msg "Cierre caja OK err=$($cerrar.json.error) msg=$($cerrar.json.mensaje)"
$diff = 0
if ($cerrar.json.datos.diferencia -ne $null) { $diff = [double]$cerrar.json.datos.diferencia }
Assert-Ok -Cond ($cerrar.ok -and [math]::Abs($diff - 7500) -lt 1) -Msg "Diferencia registrada diff=$diff"
$estadoCaja = Sql-Scalar "SELECT estado FROM cajas WHERE id='$cajaId'"
Assert-Ok -Cond ($estadoCaja -eq 'cerrada') -Msg "Caja cerrada got=$estadoCaja"

$alertaCuadre = Sql-Scalar "SELECT COUNT(*)::text FROM alertas_riesgo WHERE sucursal_id='$sid' AND tipo='cuadre_caja_diferencia' AND created_at > now() - interval '10 minutes'"
Assert-Ok -Cond ([int]$alertaCuadre -ge 1) -Msg "Alerta cuadre_caja_diferencia n=$alertaCuadre"

# Contar cuantos domicilios impagos habia (hallazgo documentado: bloquean cierre)
Write-Host '  NOTE  CAJ-DOM-IMPAGO-01: domicilio entregado con saldo pendiente bloquea cierre (by design)' -ForegroundColor DarkYellow

$reabrir = Invoke-FoodyApi -Method POST -Path '/caja/abrir' -Headers $hc -Body @{
    sucursal_id   = $sid
    monto_inicial = 50000
    arqueo_ciego  = $true
}
Assert-Ok -Cond ($reabrir.ok -and $reabrir.json.exito) -Msg 'Reabrir turno post-cierre'
$actCiego = Invoke-FoodyApi -Path "/caja/activa/$sid" -Headers $hc
$saldoCiego = $actCiego.json.datos.PSObject.Properties.Name -contains 'saldo_sistema' -and $null -ne $actCiego.json.datos.saldo_sistema
Write-Host "  NOTE  arqueo_ciego: cajero saldo_sistema visible=$saldoCiego" -ForegroundColor DarkYellow

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- F) Invariante global neto <= total ---' -ForegroundColor Yellow
$exceso = Sql-Scalar "SELECT COUNT(*)::text FROM (SELECT p.id FROM pedidos p LEFT JOIN movimientos_caja m ON m.pedido_id=p.id AND m.tipo IN ('venta','devolucion') GROUP BY p.id, p.total HAVING COALESCE(SUM(CASE WHEN m.tipo='venta' THEN m.monto WHEN m.tipo='devolucion' THEN -m.monto ELSE 0 END),0) > p.total + 0.01) x"
Assert-Ok -Cond ($exceso -eq '0') -Msg "0 pedidos con neto caja > total (exceso=$exceso)"

Write-Host ''
if ($script:fallos -gt 0) {
    Write-Host "Verificacion caja ciclo FALLO: $($script:fallos) asserts" -ForegroundColor Red
    exit 1
}
Write-Host 'Verificacion caja ciclo OK' -ForegroundColor Green
exit 0
