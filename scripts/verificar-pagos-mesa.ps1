# Verifica split bill / pago mixto mesa + P0.1 + health Realtime
# Uso: .\scripts\verificar-pagos-mesa.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar pagos mesa / caja ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }
Write-Host "OK salud base_datos=$($salud.datos.base_datos)" -ForegroundColor Green

$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$h = $cajero.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'

$libres = Get-MesasLibres -Headers $h
if ($libres.Count -eq 0) {
    $admin = Get-FoodyToken 'admin@foody.demo'
    $null = Limpiar-PedidosActivosDemo -Headers $admin.headers
    $libres = Get-MesasLibres -Headers $h
}
if ($libres.Count -eq 0) { throw 'No hay mesa libre tras cleanup' }
$Mesa = $libres[0].id
Write-Host "Mesa QA: $Mesa" -ForegroundColor DarkGray

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa
    tipo        = 'mesa'
    device_id   = 'qa-pagos-mesa'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if (-not ($crear.ok -and $crear.json.exito)) {
    throw "Crear pedido mesa: $($crear.json.mensaje)"
}

$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }
$totalPedido = [double]$crear.json.datos.total
if ($totalPedido -le 0) { $totalPedido = 8000 }

$listo = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'listo' }
if (-not ($listo.ok -and $listo.json.exito)) {
    throw "Pasar a listo: $($listo.json.mensaje)"
}

$pagando = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'pagando' }
if (-not ($pagando.ok -and $pagando.json.exito)) {
    throw "Pasar a pagando: $($pagando.json.mensaje)"
}

$saltar = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'entregado' }
if ($saltar.ok -and $saltar.json.exito) {
    throw 'FALLO P0.1: entregado permitido en mesa sin cobro'
}
Write-Host 'OK P0.1 bloqueo pagando->entregado mesa' -ForegroundColor Green

$cobro = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedidoId/cobrar?sucursal_id=$sid" -Headers $h -Body @{
    pagos = @(@{ metodo_pago = 'efectivo'; monto = $totalPedido })
}
if (-not ($cobro.ok -and $cobro.json.exito)) {
    throw "Cobro pedido: $($cobro.json.mensaje)"
}
Write-Host 'OK cobrar pedido mesa' -ForegroundColor Green

$rt = Invoke-RestMethod -Uri "$script:FoodyQaBase/health/realtime" -TimeoutSec 15
Write-Host "OK health/realtime configurado=$($rt.datos.configurado) conectado=$($rt.datos.conectado)" -ForegroundColor Green

Write-Host 'Verificacion pagos OK' -ForegroundColor Green
exit 0
