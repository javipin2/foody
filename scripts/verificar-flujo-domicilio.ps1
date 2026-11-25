# Verifica P0.2/P0.3: domicilio listo->entregado bloqueado; flujo completo con cobro
# Uso: .\scripts\verificar-flujo-domicilio.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"
Assert-FoodyQaDisposable

$fallos = 0
function Assert($c, $m) { if (-not (Assert-Qa $c $m)) { $script:fallos++ } }

Write-Host '=== Verificar flujo domicilio (P0.2 / P0.3) ===' -ForegroundColor Cyan

$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$DomiPlantaId = '92000000-0000-4000-8000-000000000001'

$admin = Get-FoodyToken 'admin@foody.demo'
$hAdmin = $admin.headers

$null = Limpiar-PedidosActivosDemo -Headers $hAdmin
$null = Limpiar-AsignacionesDomicilioDemo
Assert (Ensure-CajaAbierta -Headers $hAdmin) 'Caja abierta para cobro contra entrega'

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hAdmin -Body @{
    sucursal_id       = $sid
    tipo              = 'domicilio'
    device_id         = 'qa-domi-e2e'
    cliente_nombre    = 'QA Domi'
    cliente_telefono  = '3000000000'
    direccion_entrega = 'Calle QA 123'
    metodo_pago       = 'pendiente'
    items             = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
Assert ($crear.ok -and $crear.json.exito) 'Crear pedido domicilio'
if (-not ($crear.ok -and $crear.json.exito)) {
    if (-not $crear.json) { Write-Host "  DEBUG crear status=$($crear.status) err=$($crear.error)" -ForegroundColor DarkYellow }
    else { Write-Host "  DEBUG crear status=$($crear.status) err=$($crear.json.error) msg=$($crear.json.mensaje)" -ForegroundColor DarkYellow }
    exit 1
}

$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }

function Set-QaPedidoEstado($estado) {
    Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $hAdmin -Body @{ estado = $estado }
}

$e0 = Set-QaPedidoEstado 'en_cocina'
Assert ($e0.ok -and $e0.json.exito) 'Pedido -> en_cocina'
$cocina = Get-FoodyToken 'cocina@foody.demo'
$detalle = Invoke-FoodyApi -Path "/pedidos/$pedidoId/detalle?sucursal_id=$sid" -Headers $hAdmin
$items = @($detalle.json.datos.items_resumen)
if ($items.Count -eq 0) { $items = @($detalle.json.datos.items) }
if ($items.Count -eq 0) { $items = @($detalle.json.datos.pedido.items) }
if ($items.Count -eq 0) { throw 'No se encontraron líneas para validar el paso de Cocina' }
foreach ($item in $items) {
    $itemId = if ($item.item_id) { $item.item_id } else { $item.id }
    if (-not $itemId -or $item.estado_cocina -in @('listo', 'no_disponible')) { continue }
    $resuelto = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$itemId/estado" -Headers $cocina.headers -Body @{ estado_cocina = 'listo' }
    Assert ($resuelto.ok -and $resuelto.json.exito) "Cocina resuelve ítem $itemId"
}
$e1 = Set-QaPedidoEstado 'listo'
Assert ($e1.ok -and $e1.json.exito) 'Pedido -> listo'

$saltar = Set-QaPedidoEstado 'entregado'
Assert ((-not $saltar.ok) -or (-not $saltar.json.exito)) 'Bloqueo listo->entregado'
Assert ($saltar.status -eq 400 -or $saltar.json.error -eq 'TRANSICION_ESTADO_INVALIDA') 'Error TRANSICION_ESTADO_INVALIDA'

$asigRes = Ensure-AsignacionDomiPlanta -PedidoId $pedidoId -Headers $hAdmin -SucursalId $sid -DomiPlantaId $DomiPlantaId
if ($asigRes.auto) {
    Assert $true "Auto-dispatch dejo pedido en $($asigRes.estado)"
}
else {
    Assert $asigRes.ok "Asignar domiciliario ($($asigRes.mensaje))"
}

$domi = Get-FoodyToken 'domi@foody.demo'
$hDomi = $domi.headers

$camino = Invoke-FoodyApi -Method PATCH -Path "/domiciliario/pedidos/$pedidoId/en-camino" -Headers $hDomi
Assert ($camino.ok -and $camino.json.exito) "Marcar en camino ($($camino.json.mensaje))"

$entrega = Invoke-FoodyApi -Method PATCH -Path "/domiciliario/pedidos/$pedidoId/confirmar-entrega" -Headers $hDomi -Body @{
    metodo_pago = 'efectivo'
}
Assert ($entrega.ok -and $entrega.json.exito) "Confirmar entrega ($($entrega.json.mensaje))"
Assert ($entrega.json.datos.estado -eq 'entregado') 'Estado final entregado'

Write-Host ''
if ($fallos -eq 0) {
    Write-Host 'Verificacion domicilio OK' -ForegroundColor Green
    exit 0
}
Write-Host "$fallos fallos" -ForegroundColor Red
exit 1
