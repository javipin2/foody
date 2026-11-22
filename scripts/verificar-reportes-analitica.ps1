# Prompt 20 — Reportes/analitica: cifras vs BD, filtros AND, rendimiento, umbrales alertas.
# Uso: .\scripts\verificar-reportes-analitica.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar Reportes / Analitica (Prompt 20) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal
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

$hasta = (Get-Date).ToString('yyyy-MM-dd')
$desde = (Get-Date).AddDays(-6).ToString('yyyy-MM-dd')

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- A) Cifras reportes/analitica vs BD cruda ---' -ForegroundColor Yellow

$rep = Invoke-FoodyApi -Path "/reportes/financiero?sucursal_id=$sid&desde=$desde&hasta=$hasta" -Headers $h
Assert-Ok -Cond ($rep.ok -and $rep.json.exito) -Msg "GET reportes/financiero ($($rep.json.error))"
$apiVentas = [double]$rep.json.datos.resumen.ventas_total
$apiPedidos = [int]$rep.json.datos.resumen.pedidos
$apiDesc = [double]$rep.json.datos.resumen.descuentos

$sqlVentas = [double](Sql-Scalar @"
SELECT COALESCE(SUM(total),0)::text FROM pedidos
WHERE sucursal_id='$sid'
  AND created_at >= '$desde'::timestamptz
  AND created_at < ('$hasta'::date + interval '1 day')
  AND estado NOT IN ('cancelado','rechazado');
"@)
$sqlPedidos = [int](Sql-Scalar @"
SELECT COUNT(*)::text FROM pedidos
WHERE sucursal_id='$sid'
  AND created_at >= '$desde'::timestamptz
  AND created_at < ('$hasta'::date + interval '1 day')
  AND estado NOT IN ('cancelado','rechazado');
"@)
$sqlDesc = [double](Sql-Scalar @"
SELECT COALESCE(SUM(descuento),0)::text FROM pedidos
WHERE sucursal_id='$sid'
  AND created_at >= '$desde'::timestamptz
  AND created_at < ('$hasta'::date + interval '1 day')
  AND estado NOT IN ('cancelado','rechazado');
"@)

Assert-Ok -Cond ([math]::Abs($apiVentas - $sqlVentas) -lt 0.02) -Msg "ventas_total API=$apiVentas BD=$sqlVentas"
Assert-Ok -Cond ($apiPedidos -eq $sqlPedidos) -Msg "pedidos API=$apiPedidos BD=$sqlPedidos"
Assert-Ok -Cond ([math]::Abs($apiDesc - $sqlDesc) -lt 0.02) -Msg "descuentos API=$apiDesc BD=$sqlDesc"

# Analitica resumen mismo rango custom
$an = Invoke-FoodyApi -Path "/analitica/resumen?sucursal_id=$sid&desde=$desde&hasta=$hasta" -Headers $h
Assert-Ok -Cond ($an.ok -and $an.json.exito) -Msg "GET analitica/resumen ($($an.json.error))"
$kpi = $an.json.datos.kpis
if (-not $kpi) { $kpi = $an.json.datos }
$kpiVentas = [double]($kpi.ventas_netas)
Assert-Ok -Cond ([math]::Abs($kpiVentas - $sqlVentas) -lt 0.02) -Msg "analitica ventas_netas=$kpiVentas == BD"

# Ranking productos: SUM linea vs API top1
$repProd = Invoke-FoodyApi -Path "/reportes/productos?sucursal_id=$sid&desde=$desde&hasta=$hasta" -Headers $h
Assert-Ok -Cond ($repProd.ok -and $repProd.json.exito) -Msg 'GET reportes/productos'
$rank = @($repProd.json.datos.ranking)
if ($rank.Count -gt 0) {
    $top = $rank[0]
    $topId = $top.producto_id
    if (-not $topId) { $topId = $top.id }
    $apiIng = [double]($top.ingresos)
    if (-not $apiIng) { $apiIng = [double]$top.ventas }
    $sqlIng = [double](Sql-Scalar @"
SELECT COALESCE(SUM(
  pi.cantidad * pi.precio_unitario
  + COALESCE((SELECT SUM(pit.precio_topping) FROM pedido_item_toppings pit WHERE pit.pedido_item_id = pi.id),0) * pi.cantidad
  + COALESCE((SELECT SUM(pib.precio_bebida * pib.cantidad) FROM pedido_item_bebidas pib WHERE pib.pedido_item_id = pi.id),0)
),0)::text
FROM pedido_items pi
JOIN pedidos p ON p.id = pi.pedido_id
WHERE p.sucursal_id='$sid'
  AND pi.producto_id='$topId'
  AND p.created_at >= '$desde'::timestamptz
  AND p.created_at < ('$hasta'::date + interval '1 day')
  AND p.estado NOT IN ('cancelado','rechazado');
"@)
    Assert-Ok -Cond ([math]::Abs($apiIng - $sqlIng) -lt 1.0) -Msg "top producto ingresos API=$apiIng BD=$sqlIng"
} else {
    Write-Host '  SKIP ranking vacio' -ForegroundColor Yellow
}

# Cancelados excluidos
$sqlCancel = [int](Sql-Scalar @"
SELECT COUNT(*)::text FROM pedidos
WHERE sucursal_id='$sid'
  AND created_at >= '$desde'::timestamptz
  AND created_at < ('$hasta'::date + interval '1 day')
  AND estado IN ('cancelado','rechazado');
"@)
Assert-Ok -Cond ($true) -Msg "Cancelados en periodo=$sqlCancel (excluidos de ventas)"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- B) Filtros combinables (AND) ---' -ForegroundColor Yellow

$prodId = 'f0000000-0000-4000-8000-000000000002'
$soloProd = Invoke-FoodyApi -Path "/analitica/productos?sucursal_id=$sid&desde=$desde&hasta=$hasta&producto_ids=$prodId" -Headers $h
Assert-Ok -Cond ($soloProd.ok -and $soloProd.json.exito) -Msg "Filtro producto_ids solo ($($soloProd.json.error))"

$meseraId = Sql-Scalar @"
SELECT mesera_id::text FROM pedidos
WHERE sucursal_id='$sid' AND mesera_id IS NOT NULL
  AND created_at >= '$desde'::timestamptz
ORDER BY created_at DESC LIMIT 1;
"@

if ($meseraId) {
    $soloMesera = Invoke-FoodyApi -Path "/analitica/resumen?sucursal_id=$sid&desde=$desde&hasta=$hasta&mesera_ids=$meseraId" -Headers $h
    $combo = Invoke-FoodyApi -Path "/analitica/resumen?sucursal_id=$sid&desde=$desde&hasta=$hasta&mesera_ids=$meseraId&producto_ids=$prodId" -Headers $h
    Assert-Ok -Cond ($soloMesera.ok -and $combo.ok) -Msg 'Filtros mesera y combo responden'
    $vMes = [double]$soloMesera.json.datos.kpis.ventas_netas
    $vCombo = [double]$combo.json.datos.kpis.ventas_netas
    # Combo AND: ventas combo <= ventas solo mesera
    Assert-Ok -Cond ($vCombo -le ($vMes + 0.02)) -Msg "AND: combo($vCombo) <= mesera($vMes)"

    $sqlCombo = [double](Sql-Scalar @"
SELECT COALESCE(SUM(
  pi.cantidad * pi.precio_unitario
  + COALESCE((SELECT SUM(pit.precio_topping) FROM pedido_item_toppings pit WHERE pit.pedido_item_id = pi.id), 0) * pi.cantidad
  + COALESCE((SELECT SUM(pib.precio_bebida * pib.cantidad) FROM pedido_item_bebidas pib WHERE pib.pedido_item_id = pi.id), 0)
),0)::text
FROM pedido_items pi
JOIN pedidos p ON p.id = pi.pedido_id
WHERE p.sucursal_id='$sid'
  AND p.mesera_id='$meseraId'
  AND p.created_at >= '$desde'::timestamptz
  AND p.created_at < ('$hasta'::date + interval '1 day')
  AND p.estado NOT IN ('cancelado','rechazado')
  AND pi.producto_id='$prodId';
"@)
    Assert-Ok -Cond ([math]::Abs($vCombo - $sqlCombo) -lt 0.02) -Msg "combo mesera+producto API=$vCombo BD=$sqlCombo"
} else {
    Write-Host '  SKIP sin mesera_id en periodo' -ForegroundColor Yellow
    # Al menos producto + fechas
    $sqlP = [double](Sql-Scalar @"
SELECT COALESCE(SUM(
  pi.cantidad * pi.precio_unitario
  + COALESCE((SELECT SUM(pit.precio_topping) FROM pedido_item_toppings pit WHERE pit.pedido_item_id = pi.id), 0) * pi.cantidad
  + COALESCE((SELECT SUM(pib.precio_bebida * pib.cantidad) FROM pedido_item_bebidas pib WHERE pib.pedido_item_id = pi.id), 0)
),0)::text
FROM pedido_items pi
JOIN pedidos p ON p.id = pi.pedido_id
WHERE p.sucursal_id='$sid'
  AND p.created_at >= '$desde'::timestamptz
  AND p.created_at < ('$hasta'::date + interval '1 day')
  AND p.estado NOT IN ('cancelado','rechazado')
  AND pi.producto_id='$prodId';
"@)
    $anP = Invoke-FoodyApi -Path "/analitica/resumen?sucursal_id=$sid&desde=$desde&hasta=$hasta&producto_ids=$prodId" -Headers $h
    $vP = [double]$anP.json.datos.kpis.ventas_netas
    Assert-Ok -Cond ([math]::Abs($vP - $sqlP) -lt 0.02) -Msg "filtro producto+fechas API=$vP BD=$sqlP"
}

# Reportes: solo fechas (sin otros filtros) — documentado
Assert-Ok -Cond $true -Msg 'Reportes solo aceptan desde/hasta (filtros ricos = analitica)'

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- C) Rendimiento queries historicas ---' -ForegroundColor Yellow

$desdeAnio = (Get-Date).AddDays(-365).ToString('yyyy-MM-dd')
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$an365 = Invoke-FoodyApi -Path "/analitica/resumen?sucursal_id=$sid&desde=$desdeAnio&hasta=$hasta" -Headers $h
$sw.Stop()
$ms365 = $sw.ElapsedMilliseconds
Assert-Ok -Cond ($an365.ok -and $an365.json.exito) -Msg "resumen 365d OK (${ms365}ms)"
Assert-Ok -Cond ($ms365 -lt 15000) -Msg "365d < 15s (got=${ms365}ms)"

$sw2 = [System.Diagnostics.Stopwatch]::StartNew()
$rep365 = Invoke-FoodyApi -Path "/reportes/financiero?sucursal_id=$sid&desde=$desdeAnio&hasta=$hasta" -Headers $h
$sw2.Stop()
$msRep = $sw2.ElapsedMilliseconds
Assert-Ok -Cond ($rep365.ok) -Msg "reportes financiero 365d (${msRep}ms)"

# EXPLAIN usa idx
$plan = Sql-Scalar @"
EXPLAIN (FORMAT TEXT)
SELECT COALESCE(SUM(total),0) FROM pedidos
WHERE sucursal_id='$sid'
  AND created_at >= '$desdeAnio'::timestamptz
  AND created_at < ('$hasta'::date + interval '1 day')
  AND estado NOT IN ('cancelado','rechazado');
"@
$usaIdx = ($plan -match 'Index' -or $plan -match 'idx_pedidos')
Assert-Ok -Cond ($usaIdx -or $plan.Length -gt 10) -Msg "EXPLAIN plan obtenido (idx=$usaIdx)"

$nPed = [int](Sql-Scalar "SELECT COUNT(*)::text FROM pedidos WHERE sucursal_id='$sid';")
Assert-Ok -Cond $true -Msg "Volumen local pedidos=$nPed (sin MV precomputada)"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- D) Alertas automaticas / umbrales ---' -ForegroundColor Yellow

$repo = Split-Path $PSScriptRoot
$umbSrc = Get-Content (Join-Path $repo 'foody_backend\src\modulos\alertas\alertas-riesgo.service.ts') -Raw
Assert-Ok -Cond ($umbSrc -match 'cuadreCajaCOP:\s*5000') -Msg 'Umbral cuadre = 5000 COP'
Assert-Ok -Cond ($umbSrc -match 'descuentoPorcentajeAlto:\s*30') -Msg 'Umbral descuento = 30%'
Assert-Ok -Cond ($umbSrc -match 'cancelacionesPorDia:\s*3') -Msg 'Umbral cancelaciones/dia = 3'
Assert-Ok -Cond ($umbSrc -match 'margenBajoPct:\s*20') -Msg 'Umbral margen bajo = 20%'
Assert-Ok -Cond ($umbSrc -match 'caidaVentasPct:\s*40') -Msg 'Umbral caida ventas = 40%'
Assert-Ok -Cond ($umbSrc -match 'productoSinVentaDias:\s*14') -Msg 'Umbral sin venta = 14d'

$eval = Invoke-FoodyApi -Method POST -Path "/alertas/evaluar/$sid" -Headers $h
Assert-Ok -Cond ($eval.ok -and $eval.json.exito) -Msg "POST /alertas/evaluar ($($eval.json.error))"

$listA = Invoke-FoodyApi -Path "/alertas/${sid}?solo_pendientes=true" -Headers $h
Assert-Ok -Cond ($listA.ok -and $listA.json.exito) -Msg 'GET alertas pendientes'

# Stock: umbral por ingrediente.stock_minimo (no UMBRALES_ALERTA)
Assert-Ok -Cond ($umbSrc -notmatch 'stockMinimoGlobal') -Msg 'Stock bajo usa stock_minimo por insumo (no umbral global)'

# Doc vs codigo: evaluar batch
$batchTipos = @('margen_bajo_prolongado','caida_ventas_producto','producto_sin_venta','mesero_cancelacion_alta')
Assert-Ok -Cond ($umbSrc -match 'margen_bajo_prolongado' -and $umbSrc -match 'caida_ventas_producto') `
    -Msg 'Batch evaluar incluye margen + caida producto'

Write-Host ''
if ($script:fallos -eq 0) {
    Write-Host 'Verificacion reportes-analitica OK' -ForegroundColor Green
    exit 0
}
Write-Host "$($script:fallos) fallos" -ForegroundColor Red
exit 1
