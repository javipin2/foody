# F2 - Politica: mesero no cobra; cascade stock hermanos; mesero no marca listo.
# Uso: .\scripts\verificar-f2-politica.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar F2 politica (RBAC + stock cascade) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$mesero = Get-FoodyToken 'mesero@foody.com'
$h = $admin.headers
$hc = $cajero.headers
$hm = $mesero.headers
$sid = $script:FoodyQaSucursal
$ProdA = 'f0000000-0000-4000-8000-000000000001'
$ProdB = 'f0000000-0000-4000-8000-000000000002'
$PapaId = '40000000-0000-4000-8000-000000000003'
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

$perm = Sql-Scalar "SELECT COUNT(*) FROM roles_permisos WHERE permiso='cobrar_pedido' AND rol IN ('admin','cajero','gerente')"
Assert-Ok -Cond ([int]$perm -ge 3) -Msg "Permiso cobrar_pedido en roles ($perm)"

$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Ensure-CajaAbierta -Headers $hc
$null = Ensure-HorariosDemoAbiertos
$null = Restaurar-InventarioDemo -Headers $h

Write-Host ''
Write-Host '--- A RBAC mesero cobrar ---' -ForegroundColor Yellow
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
    device_id   = 'qa-f2-rbac'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $ProdB; cantidad = 1; precio = 8000 })
}
Assert-Ok -Cond ($crear.ok -and $crear.json.exito) -Msg 'Crear pedido'
$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }

$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'listo' }
$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'pagando' }

$cobroMesero = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedidoId/cobrar?sucursal_id=$sid" -Headers $hm -Body @{
    metodo_pago = 'efectivo'
}
Assert-Ok -Cond ((-not $cobroMesero.ok) -or (-not $cobroMesero.json.exito)) -Msg 'Mesero cobrar rechazado'
Write-Host "    status=$($cobroMesero.status) err=$($cobroMesero.json.error)" -ForegroundColor DarkGray

$cobroMesaMesero = Invoke-FoodyApi -Method POST -Path "/pedidos/mesa/$Mesa/cobrar?sucursal_id=$sid" -Headers $hm -Body @{
    metodo_pago = 'efectivo'
}
Assert-Ok -Cond ((-not $cobroMesaMesero.ok) -or (-not $cobroMesaMesero.json.exito)) -Msg 'Mesero cobrar mesa rechazado'

$cobroCajero = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedidoId/cobrar?sucursal_id=$sid" -Headers $hc -Body @{
    metodo_pago = 'efectivo'
}
Assert-Ok -Cond ($cobroCajero.ok -and $cobroCajero.json.exito) -Msg 'Cajero cobrar OK'

Write-Host ''
Write-Host '--- B RBAC mesero estados ---' -ForegroundColor Yellow
$libres2 = Get-MesasLibres -Headers $hc
$Mesa2 = $libres2[0].id
$crear2 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hm -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa2
    tipo        = 'mesa'
    device_id   = 'qa-f2-estado'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $ProdB; cantidad = 1; precio = 8000 })
}
Assert-Ok -Cond ($crear2.ok -and $crear2.json.exito) -Msg 'Mesero crea pedido'
$ped2 = $crear2.json.datos.pedido_id
if (-not $ped2) { $ped2 = $crear2.json.datos.id }

$listoMesero = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$ped2/estado?sucursal_id=$sid" -Headers $hm -Body @{ estado = 'listo' }
Assert-Ok -Cond ((-not $listoMesero.ok) -or (-not $listoMesero.json.exito)) -Msg 'Mesero listo rechazado'
Write-Host "    err=$($listoMesero.json.error)" -ForegroundColor DarkGray

$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$ped2/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'listo' }
$pagando2 = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$ped2/estado?sucursal_id=$sid" -Headers $hm -Body @{ estado = 'pagando' }
Assert-Ok -Cond ($pagando2.ok -and $pagando2.json.exito) -Msg 'Mesero pagando OK tras listo'

Write-Host ''
Write-Host '--- C CONS-STOCK-CASCADE ---' -ForegroundColor Yellow
$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Restaurar-InventarioDemo -Headers $h

$recetaBody = @{
    tipo_item      = 'ingrediente'
    ingrediente_id = $PapaId
    cantidad       = 200
    unidad         = 'g'
}
$null = Invoke-FoodyApi -Method POST -Path '/inventario/producto-ingredientes' -Headers $h -Body @{
    producto_id = $ProdA
    items       = @($recetaBody)
}
$null = Invoke-FoodyApi -Method POST -Path '/inventario/producto-ingredientes' -Headers $h -Body @{
    producto_id = $ProdB
    items       = @($recetaBody)
}
$aj = Invoke-FoodyApi -Method PATCH -Path "/inventario/$PapaId" -Headers $h -Body @{
    stock_nuevo   = 200
    motivo_ajuste = 'QA F2 cascade'
}
Assert-Ok -Cond ($aj.ok -and $aj.json.exito) -Msg 'Ajuste stock papa=200g'

$null = docker exec supabase-db psql -U postgres -d postgres -c "UPDATE productos SET disponible = true WHERE id IN ('$ProdA','$ProdB') AND sucursal_id='$sid';" 2>&1

$libres3 = Get-MesasLibres -Headers $hc
$Mesa3 = $libres3[0].id
$crear3 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa3
    tipo        = 'mesa'
    device_id   = 'qa-f2-cascade'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $ProdA; cantidad = 1; precio = 18000 })
}
Assert-Ok -Cond ($crear3.ok -and $crear3.json.exito) -Msg "Pedido que agota papa ($($crear3.json.error))"

$dispA = Sql-Scalar "SELECT disponible::text FROM productos WHERE id='$ProdA'"
$dispB = Sql-Scalar "SELECT disponible::text FROM productos WHERE id='$ProdB'"
$stock = Sql-Scalar "SELECT stock_actual::text FROM ingredientes WHERE id='$PapaId'"
Assert-Ok -Cond ([decimal]$stock -le 0) -Msg "Stock papa=$stock"
Assert-Ok -Cond ($dispA -eq 'f' -or $dispA -eq 'false') -Msg "ProdA disponible=false ($dispA)"
Assert-Ok -Cond ($dispB -eq 'f' -or $dispB -eq 'false') -Msg "ProdB hermano off ($dispB)"

$null = Restaurar-InventarioDemo -Headers $h
$null = docker exec supabase-db psql -U postgres -d postgres -c "UPDATE productos SET disponible = true WHERE id IN ('$ProdA','$ProdB') AND sucursal_id='$sid';" 2>&1

Write-Host ''
if ($script:fallos -gt 0) {
    Write-Host "FALLOS: $($script:fallos)" -ForegroundColor Red
    exit 1
}
Write-Host 'F2 politica OK' -ForegroundColor Green
exit 0
