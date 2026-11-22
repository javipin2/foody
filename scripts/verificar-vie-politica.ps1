# VIE 1C/2C/3C - cobro cocina completa, fallo prep, qty inmutable
# Uso: .\scripts\verificar-vie-politica.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar politica VIE 1C/2C/3C ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }

$admin = Get-FoodyToken 'admin@foody.demo'
$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$cocina = Get-FoodyToken 'cocina@foody.demo'
$hCaja = $cajero.headers
$hAdmin = $admin.headers
$hCoc = $cocina.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$Precio = 8000

$null = Limpiar-PedidosActivosDemo -Headers $hAdmin
$null = Ensure-CajaAbierta -Headers $hCaja
$null = Restaurar-InventarioDemo -Headers $hAdmin

function Sql-Scalar([string]$Sql) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $raw = docker exec supabase-db psql -U postgres -d postgres -t -A -c $Sql 2>$null
    $ErrorActionPreference = $prev
    return ($raw -as [string]).Trim()
}

function Get-PrimerItemId([string]$PedidoId) {
    return Sql-Scalar "SELECT id::text FROM pedido_items WHERE pedido_id='$PedidoId' ORDER BY created_at LIMIT 1"
}

# --- 1C: abono OK con cocina incompleta; saldar bloqueado; admin+motivo OK ---
$libres = Get-MesasLibres -Headers $hCaja
if ($libres.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $hAdmin
    $libres = Get-MesasLibres -Headers $hCaja
}
if ($libres.Count -eq 0) { throw 'Sin mesa libre' }
$Mesa = $libres[0].id

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hCaja -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa
    tipo        = 'mesa'
    device_id   = 'qa-vie-1c'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
if (-not ($crear.ok -and $crear.json.exito)) { throw "Crear 1C: $($crear.json.mensaje)" }
$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }

$itemId = Get-PrimerItemId $pedidoId
if (-not $itemId) { throw 'Sin item_id en pedido 1C' }
$prep = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$itemId/estado" -Headers $hCoc -Body @{
    estado_cocina = 'preparando'
}
if (-not ($prep.ok -and $prep.json.exito)) { throw "Preparando: $($prep.json.mensaje)" }

$abono = Invoke-FoodyApi -Method POST -Path "/pedidos/mesa/$Mesa/cobrar?sucursal_id=$sid" -Headers $hCaja -Body @{
    monto_parcial = 2000
    metodo_pago   = 'efectivo'
}
if (-not ($abono.ok -and $abono.json.exito)) { throw "Abono 1C: $($abono.json.mensaje)" }
Write-Host 'OK 1C abono con item preparando' -ForegroundColor Green

$saldar = Invoke-FoodyApi -Method POST -Path "/pedidos/mesa/$Mesa/cobrar?sucursal_id=$sid" -Headers $hCaja -Body @{
    metodo_pago = 'efectivo'
}
if ($saldar.ok -and $saldar.json.exito) {
    throw 'FALLO 1C: cajero pudo cerrar pagado con cocina incompleta'
}
if ($saldar.json.error -ne 'COCINA_INCOMPLETA_PARA_PAGADO') {
    Write-Host "AVISO: rechazo saldar error=$($saldar.json.error) (esperado COCINA_INCOMPLETA_PARA_PAGADO)" -ForegroundColor Yellow
} else {
    Write-Host 'OK 1C saldar bloqueado (COCINA_INCOMPLETA_PARA_PAGADO)' -ForegroundColor Green
}

$forzar = Invoke-FoodyApi -Method POST -Path "/pedidos/mesa/$Mesa/cobrar?sucursal_id=$sid" -Headers $hAdmin -Body @{
    metodo_pago = 'efectivo'
    motivo      = 'QA override cocina incompleta VIE-05'
}
if (-not ($forzar.ok -and $forzar.json.exito)) {
    throw "Admin+motivo: $($forzar.json.mensaje) error=$($forzar.json.error)"
}
Write-Host 'OK 1C admin+motivo -> pagado' -ForegroundColor Green

# --- 2C: fallo preparacion -> N/D + merma ---
$null = Limpiar-PedidosActivosDemo -Headers $hAdmin
$libres = Get-MesasLibres -Headers $hCaja
$Mesa2 = $libres[0].id
$crear2 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hCaja -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa2
    tipo        = 'mesa'
    device_id   = 'qa-vie-2c'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$pedido2 = $crear2.json.datos.pedido_id
if (-not $pedido2) { $pedido2 = $crear2.json.datos.id }
$item2 = Get-PrimerItemId $pedido2
if (-not $item2) { throw 'Sin item_id en pedido 2C' }
$null = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$item2/estado" -Headers $hCoc -Body @{
    estado_cocina = 'preparando'
}
$fallo = Invoke-FoodyApi -Method POST -Path "/cocina/items/$item2/fallo-preparacion" -Headers $hCoc -Body @{
    motivo = 'QA sin insumos mid-prep'
}
if (-not ($fallo.ok -and $fallo.json.exito)) {
    throw "Fallo prep: $($fallo.json.mensaje) error=$($fallo.json.error)"
}
$estItem = $fallo.json.datos.estado_cocina
if ($estItem -ne 'no_disponible') {
    throw "Fallo prep: estado_cocina=$estItem (esperado no_disponible)"
}
$nMerma = [int](Sql-Scalar "SELECT COUNT(*)::text FROM movimientos_ingrediente WHERE pedido_id='$pedido2' AND tipo='merma'")
if ($nMerma -lt 1) {
    Write-Host "AVISO 2C: sin filas merma (quiza sin stock_descontado). n=$nMerma" -ForegroundColor Yellow
} else {
    Write-Host "OK 2C fallo prep -> N/D + merma (n=$nMerma)" -ForegroundColor Green
}

# --- 3C: qty-down preparando bloqueado; DELETE OK ---
$null = Limpiar-PedidosActivosDemo -Headers $hAdmin
$libres = Get-MesasLibres -Headers $hCaja
$Mesa3 = $libres[0].id
$crear3 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hCaja -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa3
    tipo        = 'mesa'
    device_id   = 'qa-vie-3c'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 2; precio = $Precio })
}
$pedido3 = $crear3.json.datos.pedido_id
if (-not $pedido3) { $pedido3 = $crear3.json.datos.id }
$item3 = Get-PrimerItemId $pedido3
if (-not $item3) { throw 'Sin item_id en pedido 3C' }
$null = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$item3/estado" -Headers $hCoc -Body @{
    estado_cocina = 'preparando'
}
# ponytail: backtick before ? evita wildcard de PowerShell
$qty = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedido3/items/$item3`?sucursal_id=$sid" -Headers $hCaja -Body @{
    cantidad = 1
}
if ($qty.ok -and $qty.json.exito) {
    throw 'FALLO 3C: permitio bajar qty en preparando'
}
if ($qty.json.error -ne 'CANTIDAD_COCINA_INMUTABLE') {
    Write-Host "AVISO: qty-down error=$($qty.json.error) (esperado CANTIDAD_COCINA_INMUTABLE)" -ForegroundColor Yellow
} else {
    Write-Host 'OK 3C qty-down bloqueado (CANTIDAD_COCINA_INMUTABLE)' -ForegroundColor Green
}

$add = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedido3/items`?sucursal_id=$sid" -Headers $hCaja -Body @{
    items = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
if (-not ($add.ok -and $add.json.exito)) { throw "Add item 3C: $($add.json.mensaje)" }
$del = Invoke-FoodyApi -Method DELETE -Path "/pedidos/$pedido3/items/$item3`?sucursal_id=$sid" -Headers $hCaja -Body @{
    motivo = 'QA eliminar post-cocina VIE-QTY'
}
if (-not ($del.ok -and $del.json.exito)) {
    throw "DELETE item 3C: $($del.json.mensaje) error=$($del.json.error)"
}
Write-Host 'OK 3C DELETE con motivo' -ForegroundColor Green

Write-Host 'Verificacion VIE politica OK (1C/2C/3C)' -ForegroundColor Green
exit 0
