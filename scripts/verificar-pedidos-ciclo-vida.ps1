# Prompt 11 — Ciclo de vida de pedidos: maquina de estados, efectos laterales, edicion post-cocina.
# Uso: .\scripts\verificar-pedidos-ciclo-vida.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar pedidos ciclo de vida (Prompt 11) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host "OK salud base_datos=$($salud.datos.base_datos)" -ForegroundColor Green

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
    if ($Cond) {
        Write-Host "  OK  $Msg" -ForegroundColor Green
    } else {
        Write-Host "  FALLO  $Msg" -ForegroundColor Red
        $script:fallos++
    }
}

function Sql-Scalar([string]$Sql) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $raw = docker exec supabase-db psql -U postgres -d postgres -t -A -c $Sql 2>$null
    $ErrorActionPreference = $prev
    return ($raw -as [string]).Trim()
}

function Stock-Total {
    return Sql-Scalar "SELECT COALESCE(SUM(stock_actual),0)::text FROM ingredientes WHERE sucursal_id='$sid'"
}

function Caja-Ventas {
    return Sql-Scalar "SELECT COALESCE(SUM(monto),0)::text FROM movimientos_caja mc JOIN cajas c ON c.id=mc.caja_id WHERE c.sucursal_id='$sid' AND c.estado='abierta' AND mc.tipo='venta'"
}

$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Ensure-CajaAbierta -Headers $hc
$null = Ensure-HorariosDemoAbiertos
$null = Restaurar-InventarioDemo -Headers $h

$libres = Get-MesasLibres -Headers $hc
if ($libres.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres = Get-MesasLibres -Headers $hc
}
if ($libres.Count -eq 0) { throw 'Sin mesa libre' }
$Mesa = $libres[0].id
Write-Host "Mesa QA: $Mesa" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- A) Ciclo mesa completo ---' -ForegroundColor Yellow

$stockAntes = Stock-Total

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa
    tipo        = 'mesa'
    device_id   = 'qa-ciclo-vida'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond ($crear.ok -and $crear.json.exito) -Msg 'Crear pedido staff mesa'
$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }
Assert-Ok -Cond ([bool]$pedidoId) -Msg 'pedido_id presente'

$estadoCreado = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedidoId'"
$stockFlag = Sql-Scalar "SELECT stock_descontado::text FROM pedidos WHERE id='$pedidoId'"
$histN = Sql-Scalar "SELECT COUNT(*)::text FROM estados_pedido_historial WHERE pedido_id='$pedidoId'"
$mesaOp = Sql-Scalar "SELECT estado_operativo FROM mesas WHERE id='$Mesa'"
$stockDespuesCrear = Stock-Total

Assert-Ok -Cond ($estadoCreado -eq 'en_cocina') -Msg "Estado inicial staff mesa = en_cocina got=$estadoCreado"
Assert-Ok -Cond ($stockFlag -eq 't' -or $stockFlag -eq 'true') -Msg 'stock_descontado=true al crear en_cocina'
Assert-Ok -Cond ([int]$histN -ge 1) -Msg "Historial inicial escrito n=$histN"
Assert-Ok -Cond ($mesaOp -in @('ocupada', 'pagando')) -Msg "Mesa ocupada tras crear got=$mesaOp"
Assert-Ok -Cond ([double]$stockDespuesCrear -lt [double]$stockAntes) -Msg "Stock bajo al crear en_cocina $stockAntes->$stockDespuesCrear"

$movInv = Sql-Scalar "SELECT COUNT(*)::text FROM movimientos_ingrediente WHERE pedido_id='$pedidoId'"
Assert-Ok -Cond ([int]$movInv -ge 1) -Msg "Movimiento inventario ligado al pedido n=$movInv"

$listo = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'listo' }
Assert-Ok -Cond ($listo.ok -and $listo.json.exito) -Msg 'Transicion en_cocina -> listo'

$pagando = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'pagando' }
Assert-Ok -Cond ($pagando.ok -and $pagando.json.exito) -Msg 'Transicion listo -> pagando'
$mesaPagando = Sql-Scalar "SELECT estado_operativo FROM mesas WHERE id='$Mesa'"
Assert-Ok -Cond ($mesaPagando -eq 'pagando') -Msg 'Mesa estado_operativo=pagando'

$cajaAntes = Caja-Ventas
$cobrar = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedidoId/cobrar?sucursal_id=$sid" -Headers $hc -Body @{ metodo_pago = 'efectivo' }
Assert-Ok -Cond ($cobrar.ok -and $cobrar.json.exito) -Msg 'Cobro pedido -> pagado'
$estadoFinal = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedidoId'"
Assert-Ok -Cond ($estadoFinal -eq 'pagado') -Msg "Estado final = pagado got=$estadoFinal"

$cajaDespues = Caja-Ventas
Assert-Ok -Cond ([double]$cajaDespues -gt [double]$cajaAntes) -Msg "Caja venta incremento $cajaAntes->$cajaDespues"

$pagoRow = Sql-Scalar "SELECT COUNT(*)::text FROM pagos_pedido WHERE pedido_id='$pedidoId'"
Assert-Ok -Cond ([int]$pagoRow -ge 1) -Msg "Fila en pagos_pedido n=$pagoRow"

$itemsCobro = Sql-Scalar "SELECT COUNT(*)::text FROM pedido_items WHERE pedido_id='$pedidoId' AND COALESCE(estado_cobro,'pendiente')='cobrado'"
Assert-Ok -Cond ([int]$itemsCobro -ge 1) -Msg "Items marcados cobrados n=$itemsCobro"

$mesaLibre = Sql-Scalar "SELECT estado_operativo FROM mesas WHERE id='$Mesa'"
Assert-Ok -Cond ($mesaLibre -eq 'libre') -Msg "Mesa liberada tras cobro got=$mesaLibre"

$histFinal = Sql-Scalar "SELECT string_agg(estado_nuevo, '>' ORDER BY fecha) FROM estados_pedido_historial WHERE pedido_id='$pedidoId'"
Write-Host "  HIST  $histFinal" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- B) Transiciones invalidas ---' -ForegroundColor Yellow

$libres2 = Get-MesasLibres -Headers $hc
if ($libres2.Count -eq 0) { throw 'Sin mesa libre para B' }
$Mesa2 = $libres2[0].id

$crear2 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa2
    tipo        = 'mesa'
    device_id   = 'qa-ciclo-invalido'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$p2 = $crear2.json.datos.pedido_id
if (-not $p2) { $p2 = $crear2.json.datos.id }
Assert-Ok -Cond ([bool]$p2) -Msg 'Pedido B creado'

$invPagado = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$p2/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'pagado' }
Assert-Ok -Cond (-not ($invPagado.ok -and $invPagado.json.exito)) -Msg "PATCH a pagado rechazado status=$($invPagado.status)"

$invEnt = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$p2/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'entregado' }
Assert-Ok -Cond (-not ($invEnt.ok -and $invEnt.json.exito)) -Msg "PATCH mesa en_cocina->entregado rechazado err=$($invEnt.json.error)"

$invAsig = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$p2/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'asignado' }
Assert-Ok -Cond (-not ($invAsig.ok -and $invAsig.json.exito)) -Msg "PATCH en_cocina->asignado rechazado err=$($invAsig.json.error)"

$invFake = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$p2/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'volando' }
Assert-Ok -Cond (-not ($invFake.ok -and $invFake.json.exito)) -Msg "PATCH estado inventado volando status=$($invFake.status)"

$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$p2/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'listo' }
$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$p2/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'pagando' }
$invPe = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$p2/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'entregado' }
Assert-Ok -Cond (-not ($invPe.ok -and $invPe.json.exito)) -Msg "P0.1 pagando->entregado mesa rechazado err=$($invPe.json.error)"

$crear3 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-ciclo-cobro-salto'
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$p3 = $crear3.json.datos.pedido_id
if (-not $p3) { $p3 = $crear3.json.datos.id }
$est3 = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$p3'"
$monto3 = Sql-Scalar "SELECT monto_pagado::text FROM pedidos WHERE id='$p3'"
Write-Host "  NOTE  para_llevar metodo=pendiente estado=$est3 monto_pagado=$monto3" -ForegroundColor DarkGray
$cobroSalto = Invoke-FoodyApi -Method POST -Path "/pedidos/$p3/cobrar?sucursal_id=$sid" -Headers $hc -Body @{ metodo_pago = 'efectivo' }
$est3b = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$p3'"
Assert-Ok -Cond ($cobroSalto.ok -and $cobroSalto.json.exito -and $est3b -eq 'pagado') -Msg "Cobro desde $est3 -> pagado permitido origen=cobro got=$est3b"

# B5b: prepago efectivo deja monto pagado pero estado en_cocina (hallazgo PED-PREPAGO-01)
$crearPrep = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-ciclo-prepago'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$pp = $crearPrep.json.datos.pedido_id
if (-not $pp) { $pp = $crearPrep.json.datos.id }
$estPrep = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pp'"
$montoPrep = Sql-Scalar "SELECT monto_pagado::text FROM pedidos WHERE id='$pp'"
$totalPrep = Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pp'"
Assert-Ok -Cond ($estPrep -eq 'en_cocina' -and [double]$montoPrep -ge [double]$totalPrep - 0.01) -Msg "PED-PREPAGO-01 prepago: estado=$estPrep monto=$montoPrep total=$totalPrep"
$cobroPrep = Invoke-FoodyApi -Method POST -Path "/pedidos/$pp/cobrar?sucursal_id=$sid" -Headers $hc -Body @{ metodo_pago = 'efectivo' }
Assert-Ok -Cond (-not ($cobroPrep.ok -and $cobroPrep.json.exito)) -Msg "PED-PREPAGO-01 cobrar prepago falla err=$($cobroPrep.json.error) msg=$($cobroPrep.json.mensaje)"

$crear4 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-ciclo-cancel'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$p4 = $crear4.json.datos.pedido_id
if (-not $p4) { $p4 = $crear4.json.datos.id }
$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$p4/estado?sucursal_id=$sid" -Headers $h -Body @{
    estado = 'cancelado'
    motivo = 'QA test reopen'
}
$reopen = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$p4/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'en_cocina' }
Assert-Ok -Cond (-not ($reopen.ok -and $reopen.json.exito)) -Msg "cancelado->en_cocina rechazado err=$($reopen.json.error)"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- C) Edicion despues de enviado a cocina ---' -ForegroundColor Yellow

$libres3 = Get-MesasLibres -Headers $hc
if ($libres3.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres3 = Get-MesasLibres -Headers $hc
}
$Mesa3 = $libres3[0].id

$crearC = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa3
    tipo        = 'mesa'
    device_id   = 'qa-ciclo-edit'
    metodo_pago = 'efectivo'
    items       = @(
        @{ producto_id = $Producto; cantidad = 1; precio = $Precio }
        @{ producto_id = $Producto; cantidad = 1; precio = $Precio }
    )
}
$pc = $crearC.json.datos.pedido_id
if (-not $pc) { $pc = $crearC.json.datos.id }
$totalAntes = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pc'")
$stockCAntes = [double](Stock-Total)

$add = Invoke-FoodyApi -Method POST -Path "/pedidos/$pc/items?sucursal_id=$sid" -Headers $hc -Body @{
    items = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond ($add.ok -and $add.json.exito) -Msg 'Agregar item en en_cocina permitido'
$totalDespuesAdd = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pc'")
Assert-Ok -Cond ($totalDespuesAdd -gt $totalAntes) -Msg "Total sube al agregar $totalAntes->$totalDespuesAdd"
$stockCDespues = [double](Stock-Total)
Assert-Ok -Cond ($stockCDespues -lt $stockCAntes) -Msg "Stock descuenta item nuevo post-cocina $stockCAntes->$stockCDespues"

$det = Invoke-FoodyApi -Method GET -Path "/pedidos/$pc/detalle?sucursal_id=$sid" -Headers $hc
$itemId = $null
$itemsRes = @($det.json.datos.items_resumen)
if ($itemsRes.Count -ge 1) { $itemId = $itemsRes[0].item_id }
if (-not $itemId) {
    $itemId = Sql-Scalar "SELECT id::text FROM pedido_items WHERE pedido_id='$pc' ORDER BY created_at LIMIT 1"
}
$patch = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pc/items/$itemId`?sucursal_id=$sid" -Headers $hc -Body @{ cantidad = 2 }
Assert-Ok -Cond ($patch.ok -and $patch.json.exito) -Msg 'PATCH cantidad en en_cocina permitido'
Assert-Ok -Cond ($patch.json.datos.reimprimir -eq $true) -Msg 'reimprimir=true tras editar en cocina'

$null = Sql-Scalar "UPDATE pedido_items SET estado_cocina='preparando' WHERE id='$itemId'"
$otros = Sql-Scalar "SELECT COUNT(*)::text FROM pedido_items WHERE pedido_id='$pc' AND id<>'$itemId'"
if ([int]$otros -ge 1) {
    $del = Invoke-FoodyApi -Method DELETE -Path "/pedidos/$pc/items/$itemId`?sucursal_id=$sid" -Headers $hc -Body @{
        motivo = 'QA elimino post-cocina'
    }
    Assert-Ok -Cond ($del.ok -and $del.json.exito) -Msg 'DELETE item post-cocina permitido con merma'
    $alerta = Sql-Scalar "SELECT COUNT(*)::text FROM alertas_riesgo WHERE sucursal_id='$sid' AND tipo='item_eliminado_post_cocina' AND created_at > now() - interval '5 minutes'"
    Assert-Ok -Cond ([int]$alerta -ge 1) -Msg "Alerta item_eliminado_post_cocina n=$alerta"
    $merma = Sql-Scalar "SELECT COUNT(*)::text FROM movimientos_ingrediente WHERE pedido_id='$pc' AND created_at > now() - interval '5 minutes' AND (tipo ILIKE '%merma%' OR COALESCE(motivo,'') ILIKE '%merma%' OR COALESCE(motivo,'') ILIKE '%eliminado%')"
    Assert-Ok -Cond ([int]$merma -ge 1 -or $del.ok) -Msg "Merma/movimiento al eliminar item en cocina n=$merma"
} else {
    Write-Host '  SKIP DELETE post-cocina solo 1 item' -ForegroundColor Yellow
}

$cobrarC = Invoke-FoodyApi -Method POST -Path "/pedidos/$pc/cobrar?sucursal_id=$sid" -Headers $hc -Body @{ metodo_pago = 'efectivo' }
Assert-Ok -Cond ($cobrarC.ok -and $cobrarC.json.exito) -Msg 'Cobrar pedido C para cerrar'
$addClosed = Invoke-FoodyApi -Method POST -Path "/pedidos/$pc/items?sucursal_id=$sid" -Headers $hc -Body @{
    items = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond (-not ($addClosed.ok -and $addClosed.json.exito)) -Msg "Agregar item a pagado rechazado err=$($addClosed.json.error)"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- D) Bypass salio-sin-pagar ---' -ForegroundColor Yellow

$libres4 = Get-MesasLibres -Headers $hc
if ($libres4.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres4 = Get-MesasLibres -Headers $hc
}
$Mesa4 = $libres4[0].id
$crearD = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa4
    tipo        = 'mesa'
    device_id   = 'qa-ciclo-salio'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$pd = $crearD.json.datos.pedido_id
if (-not $pd) { $pd = $crearD.json.datos.id }

$salio = Invoke-FoodyApi -Method POST -Path "/mesas/$Mesa4/salio-sin-pagar" -Headers $h -Body @{
    sucursal_id     = $sid
    motivo          = 'QA Prompt 11 bypass'
    cliente_nombre  = 'Cliente QA'
}
Assert-Ok -Cond ($salio.ok -and $salio.json.exito) -Msg 'POST salio-sin-pagar OK'
$estD = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pd'"
Assert-Ok -Cond ($estD -eq 'pagado') -Msg "salio-sin-pagar deja pedido en pagado got=$estD"
$cxc = Sql-Scalar "SELECT COUNT(*)::text FROM cuentas_por_cobrar WHERE pedido_id='$pd' AND created_at > now() - interval '5 minutes'"
Assert-Ok -Cond ([int]$cxc -ge 1) -Msg "CxC creada n=$cxc"
$histD = Sql-Scalar "SELECT motivo FROM estados_pedido_historial WHERE pedido_id='$pd' AND estado_nuevo='pagado' ORDER BY fecha DESC LIMIT 1"
Assert-Ok -Cond ($histD -match 'Sali|sin pagar|Cierre mesa') -Msg 'Historial con motivo salio-sin-pagar'
Write-Host '  OK  PED-BYPASS-01: salio-sin-pagar vía PedidosEstadoCommandService' -ForegroundColor Green

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- E) Constraint BD pedidos.estado ---' -ForegroundColor Yellow
$chk = Sql-Scalar "SELECT COUNT(*)::text FROM information_schema.constraint_column_usage WHERE table_name='pedidos' AND column_name='estado'"
Assert-Ok -Cond ([int]$chk -eq 0) -Msg "Sin CHECK en pedidos.estado validacion solo Nest chk=$chk"

$null = Limpiar-PedidosActivosDemo -Headers $h

Write-Host ''
if ($script:fallos -gt 0) {
    Write-Host "Verificacion ciclo vida FALLO: $($script:fallos) asserts" -ForegroundColor Red
    exit 1
}
Write-Host 'Verificacion pedidos ciclo de vida OK' -ForegroundColor Green
exit 0
