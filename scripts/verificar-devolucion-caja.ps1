# Cancelar pedido mesa sin cobro no debe bajar saldo; devolución manual no puede exceder ventas del turno.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host 'verificar-devolucion-caja' -ForegroundColor Cyan

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'

if (-not (Ensure-CajaAbierta -Headers $h)) {
  Write-Host 'FAIL: no se pudo abrir caja QA' -ForegroundColor Red
  exit 1
}

$caja = Invoke-FoodyApi -Method GET -Path "/caja/activa/$sid" -Headers $h
if (-not ($caja.ok -and $caja.json.exito -and $caja.json.datos)) {
  Write-Host 'FAIL: no hay caja abierta para QA' -ForegroundColor Red
  exit 1
}
$cajaId = $caja.json.datos.id
$saldoAntes = [double]$caja.json.datos.saldo_sistema
$ventasTurno = [double]$caja.json.datos.total_ventas

$libres = Get-MesasLibres -Headers $h
if ($libres.Count -lt 1) {
  $null = Limpiar-PedidosActivosDemo -Headers $h
  Start-Sleep -Seconds 1
  $libres = Get-MesasLibres -Headers $h
}
if ($libres.Count -lt 1) {
  Write-Host 'FAIL: sin mesa libre para QA' -ForegroundColor Red
  exit 1
}
$mesaId = $libres[0].id

# Pedido mesa sin cobrar → cancelar (no debe mover caja)
$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
  sucursal_id = $sid
  mesa_id     = $mesaId
  tipo        = 'mesa'
  device_id   = 'qa-devolucion-caja'
  metodo_pago = 'efectivo'
  items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if (-not ($crear.ok -and $crear.json.exito)) {
  throw "crear pedido mesa: $($crear.json.mensaje)"
}
$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }

$cancel = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{
  estado = 'cancelado'
  motivo = 'QA cancelar mesa sin cobro'
}
if (-not ($cancel.ok -and $cancel.json.exito)) {
  throw "cancelar: $($cancel.json.mensaje)"
}
$devAuto = [double]($cancel.json.datos.caja.devolucion_automatica)
if ($devAuto -gt 0.01) {
  Write-Host "FAIL: cancelar mesa sin cobro generó devolución $devAuto" -ForegroundColor Red
  exit 1
}

$caja2 = Invoke-FoodyApi -Method GET -Path "/caja/activa/$sid" -Headers $h
$saldoDespues = [double]$caja2.json.datos.saldo_sistema
if ([math]::Abs($saldoDespues - $saldoAntes) -gt 0.01) {
  Write-Host "FAIL: saldo cambió tras cancelar mesa sin cobro ($saldoAntes -> $saldoDespues)" -ForegroundColor Red
  exit 1
}
Write-Host '   OK cancelar mesa sin cobro no altera saldo' -ForegroundColor Green

# Para-llevar prepagado: crear suma venta a caja; cancelar debe devolver al saldo original
# (regresión del bug de doble resta: borrar venta + agregar devolución dejaba caja en -monto).
$caja3 = Invoke-FoodyApi -Method GET -Path "/caja/activa/$sid" -Headers $h
$saldoBaseLlevar = [double]$caja3.json.datos.saldo_sistema
$ventasBaseLlevar = [double]$caja3.json.datos.total_ventas

$crearLlevar = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
  sucursal_id = $sid
  tipo        = 'para_llevar'
  device_id   = 'qa-devolucion-caja'
  metodo_pago = 'efectivo'
  items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if (-not ($crearLlevar.ok -and $crearLlevar.json.exito)) {
  throw "crear para_llevar: $($crearLlevar.json.mensaje)"
}
$pedidoLlevar = $crearLlevar.json.datos.pedido_id
if (-not $pedidoLlevar) { $pedidoLlevar = $crearLlevar.json.datos.id }

$cajaConVenta = Invoke-FoodyApi -Method GET -Path "/caja/activa/$sid" -Headers $h
$saldoConVenta = [double]$cajaConVenta.json.datos.saldo_sistema
if ($saldoConVenta -le $saldoBaseLlevar + 0.01) {
  Write-Host "FAIL: para_llevar prepagado no sumó venta a caja ($saldoBaseLlevar -> $saldoConVenta)" -ForegroundColor Red
  exit 1
}

$cancelLlevar = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoLlevar/estado?sucursal_id=$sid" -Headers $h -Body @{
  estado = 'cancelado'
  motivo = 'QA cancelar para_llevar prepagado'
}
if (-not ($cancelLlevar.ok -and $cancelLlevar.json.exito)) {
  throw "cancelar para_llevar: $($cancelLlevar.json.mensaje)"
}
$devLlevar = [double]($cancelLlevar.json.datos.caja.devolucion_automatica)
if ([math]::Abs($devLlevar - ($saldoConVenta - $saldoBaseLlevar)) -gt 0.01) {
  Write-Host "FAIL: devolución automática ($devLlevar) != venta registrada" -ForegroundColor Red
  exit 1
}

$cajaFinal = Invoke-FoodyApi -Method GET -Path "/caja/activa/$sid" -Headers $h
$saldoFinal = [double]$cajaFinal.json.datos.saldo_sistema
$ventasFinal = [double]$cajaFinal.json.datos.total_ventas
if ([math]::Abs($saldoFinal - $saldoBaseLlevar) -gt 0.01) {
  Write-Host "FAIL: cancelar prepagado no regresó al saldo original ($saldoBaseLlevar -> $saldoFinal); doble resta?" -ForegroundColor Red
  exit 1
}
Write-Host '   OK cancelar para_llevar prepagado regresa al saldo original (sin doble resta)' -ForegroundColor Green
if ([math]::Abs($ventasFinal - $ventasBaseLlevar) -gt 0.01) {
  Write-Host "FAIL: total Ventas infló tras cancelar ($ventasBaseLlevar -> $ventasFinal); venta cancelada no debe contar" -ForegroundColor Red
  exit 1
}
Write-Host '   OK total Ventas no infla con pedido cancelado (ventas netas)' -ForegroundColor Green

# Devolución manual mayor que ventas del turno debe fallar
$exceso = $ventasTurno + 100000
$dev = Invoke-FoodyApi -Method POST -Path '/caja/devolucion' -Headers $h -Body @{
  caja_id     = $cajaId
  sucursal_id = $sid
  monto       = $exceso
  motivo      = 'QA devolución excesiva'
}
if ($dev.ok -and $dev.json.exito) {
  Write-Host "FAIL: aceptó devolución $exceso con ventas turno $ventasTurno" -ForegroundColor Red
  exit 1
}
$codigo = $dev.json.error
if ($codigo -ne 'DEVOLUCION_EXCEDE_VENTAS_TURNO') {
  Write-Host "FAIL: error esperado DEVOLUCION_EXCEDE_VENTAS_TURNO, recibido $codigo" -ForegroundColor Red
  exit 1
}
Write-Host '   OK bloquea devolución > ventas del turno' -ForegroundColor Green

Write-Host "`nOK verificar-devolucion-caja" -ForegroundColor Green
