# F1 — Turno estable: unique caja abierta + idempotencia cobro.
# Uso: .\scripts\verificar-f1-turno.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar F1 turno (caja unique + cobro idempotente) ===' -ForegroundColor Cyan

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

# Schema 081
$idx = Sql-Scalar "SELECT COUNT(*) FROM pg_indexes WHERE indexname='uq_caja_abierta_sucursal'"
Assert-Ok -Cond ($idx -eq '1') -Msg 'Indice uq_caja_abierta_sucursal'
$tbl = Sql-Scalar "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='cobros_idempotencia'"
Assert-Ok -Cond ($tbl -eq '1') -Msg 'Tabla cobros_idempotencia'

$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Ensure-CajaAbierta -Headers $hc
$null = Ensure-HorariosDemoAbiertos
$null = Restaurar-InventarioDemo -Headers $h

# --- A) Segunda apertura debe fallar (CAJA_YA_ABIERTA) ---
Write-Host ''
Write-Host '--- A) Doble abrir caja ---' -ForegroundColor Yellow
$abrir2 = Invoke-FoodyApi -Method POST -Path "/caja/abrir?sucursal_id=$sid" -Headers $hc -Body @{
    sucursal_id   = $sid
    monto_inicial = 0
}
$errCode = $null
if ($abrir2.json.error) { $errCode = "$($abrir2.json.error)" }
elseif ($abrir2.json.mensaje) { $errCode = "$($abrir2.json.mensaje)" }
$rechazo = (-not $abrir2.ok) -or (-not $abrir2.json.exito)
Assert-Ok -Cond $rechazo -Msg "Segunda apertura rechazada (status/body)"
if ($errCode) { Write-Host "    detalle: $errCode" -ForegroundColor DarkGray }

# --- B) Cobro idempotente misma clave ---
Write-Host ''
Write-Host '--- B) Idempotencia cobro pedido ---' -ForegroundColor Yellow
$libres = Get-MesasLibres -Headers $hc
if ($libres.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres = Get-MesasLibres -Headers $hc
}
$Mesa = $libres[0].id
$clave = [guid]::NewGuid().ToString()

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa
    tipo        = 'mesa'
    device_id   = 'qa-f1-idem'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond ($crear.ok -and $crear.json.exito) -Msg 'Crear pedido mesa'
$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }

$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'listo' }
$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'pagando' }

$cobrar1 = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedidoId/cobrar?sucursal_id=$sid" -Headers $hc -Body @{
    metodo_pago      = 'efectivo'
    idempotency_key  = $clave
}
Assert-Ok -Cond ($cobrar1.ok -and $cobrar1.json.exito) -Msg 'Cobrar #1 con clave'

$ventas1 = [int](Sql-Scalar "SELECT COUNT(*) FROM movimientos_caja WHERE pedido_id='$pedidoId' AND tipo='venta'")
$cobrar2 = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedidoId/cobrar?sucursal_id=$sid" -Headers $hc -Body @{
    metodo_pago      = 'efectivo'
    idempotency_key  = $clave
}
Assert-Ok -Cond ($cobrar2.ok -and $cobrar2.json.exito) -Msg 'Cobrar #2 misma clave (replay)'
$ventas2 = [int](Sql-Scalar "SELECT COUNT(*) FROM movimientos_caja WHERE pedido_id='$pedidoId' AND tipo='venta'")
Assert-Ok -Cond ($ventas1 -eq 1 -and $ventas2 -eq 1) -Msg "Una sola venta en caja (antes=$ventas1 despues=$ventas2)"

$enCache = Sql-Scalar "SELECT COUNT(*) FROM cobros_idempotencia WHERE clave='$clave'"
Assert-Ok -Cond ($enCache -eq '1') -Msg 'Fila en cobros_idempotencia'

Write-Host ''
if ($script:fallos -gt 0) {
    Write-Host "FALLOS: $($script:fallos)" -ForegroundColor Red
    exit 1
}
Write-Host 'F1 turno OK' -ForegroundColor Green
exit 0
