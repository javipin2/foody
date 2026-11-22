# Verifica split bill / pago mixto / abono parcial mesa + P0.1 + F-17
# Uso: .\scripts\verificar-pagos-mesa.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar pagos mesa / caja (F-17 split) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }
Write-Host "OK salud base_datos=$($salud.datos.base_datos)" -ForegroundColor Green

$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$h = $cajero.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$Precio = 8000

$admin = Get-FoodyToken 'admin@foody.demo'
$null = Limpiar-PedidosActivosDemo -Headers $admin.headers

function Get-ItemIdsMesa {
    param([string]$MesaId)
    $r = Invoke-FoodyApi -Method GET -Path "/pedidos/mesa/$MesaId?sucursal_id=$sid" -Headers $h
    if ($r.ok -and $r.json.exito) {
        $ids = @()
        foreach ($p in @($r.json.datos.pedidos)) {
            foreach ($it in @($p.items)) {
                if ($it.estado_cobro -eq 'pendiente' -or -not $it.estado_cobro) {
                    $ids += $it.id
                }
            }
        }
        return @{ items = $ids; datos = $r.json.datos }
    }
    # ponytail: fallback SQL si GET mesa devuelve 500 (misma regla que SQL_WHERE_PEDIDO_BLOQUEA_MESA)
    $sql = @"
SELECT pi.id::text
FROM pedido_items pi
JOIN pedidos p ON p.id = pi.pedido_id
WHERE p.sucursal_id = '$sid'
  AND p.mesa_id = '$MesaId'
  AND COALESCE(pi.estado_cobro, 'pendiente') = 'pendiente'
  AND p.estado NOT IN ('cancelado','rechazado','pagado')
  AND (p.estado <> 'entregado' OR COALESCE(p.monto_pagado, 0) < p.total - 0.01)
ORDER BY pi.created_at
"@
    $raw = docker exec supabase-db psql -U postgres -d postgres -t -A -c $sql 2>$null
    $ids = @($raw -split "`n" | Where-Object { $_.Trim() -ne '' })
    $saldoSql = @"
SELECT COALESCE(SUM(GREATEST(p.total - COALESCE(p.monto_pagado,0), 0)), 0)::text
FROM pedidos p
WHERE p.sucursal_id = '$sid' AND p.mesa_id = '$MesaId'
  AND p.estado NOT IN ('cancelado','rechazado','pagado')
  AND (p.estado <> 'entregado' OR COALESCE(p.monto_pagado, 0) < p.total - 0.01)
"@
    $saldo = [double](docker exec supabase-db psql -U postgres -d postgres -t -A -c $saldoSql 2>$null)
    return @{
        items = $ids
        datos = @{ total_acumulado = $saldo; pedidos = @() }
    }
}

$libres = Get-MesasLibres -Headers $h
if ($libres.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $admin.headers
    $libres = Get-MesasLibres -Headers $h
}
if ($libres.Count -eq 0) { throw 'No hay mesa libre tras cleanup' }
$Mesa = $libres[0].id
Write-Host "Mesa QA: $Mesa" -ForegroundColor DarkGray

$bodyPedido = @{
    sucursal_id = $sid
    mesa_id     = $Mesa
    tipo        = 'mesa'
    device_id   = 'qa-pagos-mesa'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}

$crear1 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body $bodyPedido
if (-not ($crear1.ok -and $crear1.json.exito)) {
    throw "Crear pedido 1: $($crear1.json.mensaje)"
}
$crear2 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body $bodyPedido
if (-not ($crear2.ok -and $crear2.json.exito)) {
    throw "Crear pedido 2: $($crear2.json.mensaje)"
}

$pedidoId = $crear1.json.datos.pedido_id
$listo = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'listo' }
if (-not ($listo.ok -and $listo.json.exito)) { throw "Pasar a listo: $($listo.json.mensaje)" }

# VIE-05 C: ítems a nivel cocina listos (cobro→pagado)
$cocinaTokPrep = Get-FoodyToken 'cocina@foody.demo'
$infoItemsPrep = Get-ItemIdsMesa -MesaId $Mesa
foreach ($iid in @($infoItemsPrep.items)) {
    $null = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$iid/estado" -Headers $cocinaTokPrep.headers -Body @{
        estado_cocina = 'listo'
    }
}

$pagando = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'pagando' }
if (-not ($pagando.ok -and $pagando.json.exito)) { throw "Pasar a pagando: $($pagando.json.mensaje)" }

$saltar = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'entregado' }
if ($saltar.ok -and $saltar.json.exito) {
    throw 'FALLO P0.1: entregado permitido en mesa sin cobro'
}
Write-Host 'OK P0.1 bloqueo pagando->entregado mesa' -ForegroundColor Green

# --- F-17: abono parcial + split por item no sobrecobra ---
$info = Get-ItemIdsMesa -MesaId $Mesa
if ($info.items.Count -lt 2) { throw 'Se esperaban 2 items en mesa (2 tickets)' }
$item1 = $info.items[0]
$item2 = $info.items[1]
$totalMesa = [double]$info.datos.total_acumulado

$abono = Invoke-FoodyApi -Method POST -Path "/pedidos/mesa/$Mesa/cobrar?sucursal_id=$sid" -Headers $h -Body @{
    monto_parcial = 4000
    metodo_pago   = 'efectivo'
}
if (-not ($abono.ok -and $abono.json.exito)) {
    throw "Abono parcial: $($abono.json.mensaje)"
}
$saldoTrasAbono = [double]$abono.json.datos.saldo_restante
Write-Host "OK abono parcial saldo_restante=$saldoTrasAbono" -ForegroundColor Green

$exceso = Invoke-FoodyApi -Method POST -Path "/pedidos/mesa/$Mesa/cobrar?sucursal_id=$sid" -Headers $h -Body @{
    item_ids    = @($item1, $item2)
    metodo_pago = 'efectivo'
}
if ($exceso.ok -and $exceso.json.exito) {
    throw 'FALLO F-17: debio rechazar ITEMS_EXCEDEN_SALDO (2 items tras abono)'
}
$codigoExceso = $exceso.json.error
if ($codigoExceso -ne 'ITEMS_EXCEDEN_SALDO') {
    Write-Host "AVISO: rechazo exceso con error=$codigoExceso (esperado ITEMS_EXCEDEN_SALDO)" -ForegroundColor Yellow
} else {
    Write-Host 'OK F-17 ITEMS_EXCEDEN_SALDO' -ForegroundColor Green
}

$splitItem = Invoke-FoodyApi -Method POST -Path "/pedidos/mesa/$Mesa/cobrar?sucursal_id=$sid" -Headers $h -Body @{
    item_ids    = @($item1)
    metodo_pago = 'tarjeta'
}
if (-not ($splitItem.ok -and $splitItem.json.exito)) {
    throw "Split por item tras abono: $($splitItem.json.mensaje)"
}
$totalCobradoSplit = [double]$splitItem.json.datos.total_cobrado
if ($totalCobradoSplit -gt $saldoTrasAbono + 0.02) {
    throw "FALLO F-17: cobro item ($totalCobradoSplit) > saldo ($saldoTrasAbono)"
}
Write-Host "OK F-17 split item ($totalCobradoSplit)" -ForegroundColor Green

# --- Pago mixto cierra saldo (VIE-05 C: items cocina listos) ---
$saldoFinal = [double](Get-ItemIdsMesa -MesaId $Mesa).datos.total_acumulado
if ($saldoFinal -gt 0.01) {
    $cocinaTok = Get-FoodyToken 'cocina@foody.demo'
    $hCoc = $cocinaTok.headers
    $infoPre = Get-ItemIdsMesa -MesaId $Mesa
    foreach ($iid in @($infoPre.items)) {
        $null = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$iid/estado" -Headers $hCoc -Body @{
            estado_cocina = 'listo'
        }
    }
    $m1 = [math]::Round($saldoFinal / 2, 0)
    $m2 = $saldoFinal - $m1
    $mixto = Invoke-FoodyApi -Method POST -Path "/pedidos/mesa/$Mesa/cobrar?sucursal_id=$sid" -Headers $h -Body @{
        pagos = @(
            @{ metodo_pago = 'efectivo'; monto = $m1 }
            @{ metodo_pago = 'tarjeta'; monto = $m2 }
        )
    }
    if (-not ($mixto.ok -and $mixto.json.exito)) {
        throw "Pago mixto: $($mixto.json.mensaje) error=$($mixto.json.error)"
    }
    Write-Host 'OK pago mixto mesa' -ForegroundColor Green
}

$rt = Invoke-RestMethod -Uri "$script:FoodyQaBase/health/realtime" -TimeoutSec 15
Write-Host "OK health/realtime configurado=$($rt.datos.configurado) conectado=$($rt.datos.conectado)" -ForegroundColor Green

Write-Host 'Verificacion pagos mesa OK (F-17)' -ForegroundColor Green
exit 0
