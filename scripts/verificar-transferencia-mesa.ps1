# Verifica P2.1/P2.2: transferencia mesa con pedido activo
# Uso: .\scripts\verificar-transferencia-mesa.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

$fallos = 0
function Assert($c, $m) { if (-not (Assert-Qa $c $m)) { $script:fallos++ } }

Write-Host '=== Verificar transferencia mesa (P2) ===' -ForegroundColor Cyan

$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'

$admin = Get-FoodyToken 'admin@foody.demo'
$null = Limpiar-PedidosActivosDemo -Headers $admin.headers
$h = $admin.headers

$libres = Get-MesasLibres -Headers $h
Assert ($libres.Count -ge 2) 'Al menos 2 mesas libres'
if ($libres.Count -lt 2) { exit 1 }

$mesaOrigen = $libres[0].id
$mesaDestinoId = $libres[1].id

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
    sucursal_id = $sid
    mesa_id     = $mesaOrigen
    tipo        = 'mesa'
    device_id   = 'qa-transfer-mesa'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
Assert ($crear.ok -and $crear.json.exito) 'Pedido en mesa origen'
if (-not ($crear.ok -and $crear.json.exito)) { exit 1 }
$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }
if (-not $pedidoId) {
    Write-Host '  FALLO  pedido_id vacio tras crear' -ForegroundColor Red
    exit 1
}

$xfer = Invoke-FoodyApi -Method POST -Path '/mesas/transferir' -Headers $h -Body @{
    sucursal_id     = $sid
    pedido_id       = $pedidoId
    mesa_origen_id  = $mesaOrigen
    mesa_destino_id = $mesaDestinoId
    motivo          = 'QA transferencia E2E'
}
Assert ($xfer.ok -and $xfer.json.exito) "POST transferir (err=$($xfer.json.error) msg=$($xfer.json.mensaje))"

Start-Sleep -Seconds 1
$mesas2 = Invoke-FoodyApi -Path "/mesas/$sid" -Headers $h
$dest = @($mesas2.json.datos | Where-Object { $_.id -eq $mesaDestinoId })[0]
Assert ($dest.estado_operativo -eq 'ocupada') 'Mesa destino ocupada'
Assert ($dest.pedido_id -eq $pedidoId) 'Pedido activo en mesa destino'

$orig = @($mesas2.json.datos | Where-Object { $_.id -eq $mesaOrigen })[0]
Assert (-not $orig.pedido_id) 'Mesa origen sin pedido activo'

Write-Host ''
if ($fallos -eq 0) {
    Write-Host 'Verificacion transferencia mesa OK' -ForegroundColor Green
    exit 0
}
Write-Host "$fallos fallos" -ForegroundColor Red
exit 1
