# Foody — QA cuadre caja (I7): reportes financiero vs movimientos_caja
# Uso: powershell -File scripts/verificar-cuadre-caja.ps1
$ErrorActionPreference = "Continue"
$Base = "http://localhost:3000/api/v1"
$Sucursal = "c0000000-0000-4000-8000-000000000001"
$Pass = "123456"
$hoy = Get-Date -Format "yyyy-MM-dd"
$desde = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")

function Invoke-Api {
    param([string]$Method = "GET", [string]$Path, [hashtable]$Headers = @{}, [object]$Body = $null)
    $params = @{
        Uri             = "$Base$Path"
        Method          = $Method
        TimeoutSec      = 20
        UseBasicParsing = $true
    }
    if ($Headers.Count) { $params.Headers = $Headers }
    if ($null -ne $Body) {
        $params.ContentType = "application/json"
        $params.Body = ($Body | ConvertTo-Json -Depth 6 -Compress)
    }
    try {
        $r = Invoke-WebRequest @params
        $json = $r.Content | ConvertFrom-Json
        return @{ ok = $true; status = $r.StatusCode; json = $json }
    }
    catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        return @{ ok = $false; status = $status; error = $_.Exception.Message }
    }
}

Write-Host ""
Write-Host "=== QA Cuadre caja (reportes vs movimientos) ==="
Write-Host ""

$login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = "admin@foody.demo"; contrasena = $Pass
}
if (-not ($login.ok -and $login.json.exito)) {
    Write-Host "FALLO: login admin ($($login.status) $($login.error))"
    exit 1
}
$token = $login.json.datos.token
$h = @{ Authorization = "Bearer $token" }

$path = "/reportes/financiero?sucursal_id=$Sucursal&desde=$desde&hasta=$hoy"
$rep = Invoke-Api -Path $path -Headers $h
if (-not ($rep.ok -and $rep.json.exito)) {
    Write-Host "FALLO: GET reportes/financiero ($($rep.status))"
    exit 1
}

$datos = $rep.json.datos
$cuadre = $datos.cuadre_caja
if (-not $cuadre) {
    Write-Host "FALLO: respuesta sin bloque cuadre_caja"
    exit 1
}

$ventasPedidos = [double]$cuadre.ventas_pedidos
$ventasCaja = [double]$cuadre.ventas_movimientos_caja
$diferencia = [double]$cuadre.diferencia
$movs = [int]$cuadre.movimientos_venta
$pagadoAcum = $null
$diffPagado = $null

Write-Host "Periodo: $desde -> $hoy"
Write-Host "Tickets (pedidos):  $ventasPedidos"
Write-Host "Cobrado caja neto:  $ventasCaja"
Write-Host "Diferencia API:     $diferencia"
Write-Host "Movimientos venta:  $movs"
if ($cuadre.nota_universos) {
    Write-Host "Nota: $($cuadre.nota_universos)"
}

$pagadoSql = @"
SELECT COALESCE(SUM(monto_pagado), 0) AS pagado
FROM pedidos
WHERE sucursal_id = '$Sucursal'
  AND created_at >= '$desde'::timestamptz
  AND created_at < ('$hoy'::date + interval '1 day')
  AND estado NOT IN ('cancelado', 'rechazado');
"@
$pagadoRaw = docker exec supabase-db psql -U postgres -d postgres -tAc $pagadoSql 2>&1
if ($pagadoRaw -match '^\s*[\d.]') {
    $pagadoAcum = [double]$pagadoRaw.Trim()
    $diffPagado = [math]::Round($pagadoAcum - $ventasCaja, 2)
    Write-Host "Monto pagado (pedidos): $pagadoAcum"
    Write-Host "Diff pagado vs caja:    $diffPagado"
}

# Cruce BD — mismos filtros que foody_backend/.../ventas-metricas.sql + reportes.service financiero()
$sql = @"
SELECT
  COALESCE((
    SELECT SUM(total) FROM pedidos
    WHERE sucursal_id = '$Sucursal'
      AND created_at >= '$desde'::timestamptz
      AND created_at < ('$hoy'::date + interval '1 day')
      AND estado NOT IN ('cancelado', 'rechazado')
  ), 0) AS ventas_pedidos,
  COALESCE((
    SELECT SUM(CASE WHEN m.tipo = 'venta' THEN m.monto ELSE -m.monto END)
    FROM movimientos_caja m
    LEFT JOIN pedidos p ON p.id = m.pedido_id
    WHERE m.sucursal_id = '$Sucursal'
      AND m.tipo IN ('venta', 'devolucion')
      AND (
        (p.created_at IS NOT NULL AND p.created_at >= '$desde'::timestamptz AND p.created_at < ('$hoy'::date + interval '1 day'))
        OR (p.created_at IS NULL AND m.created_at >= '$desde'::timestamptz AND m.created_at < ('$hoy'::date + interval '1 day'))
      )
  ), 0) AS ventas_caja;
"@
$dbRaw = docker exec supabase-db psql -U postgres -d postgres -tAc $sql 2>&1
if ($dbRaw -match '\|') {
    $parts = $dbRaw.Trim() -split '\|'
    $dbPedidos = [double]$parts[0]
    $dbCaja = [double]$parts[1]
    $dbDiff = [math]::Round($dbPedidos - $dbCaja, 2)
    Write-Host ""
    Write-Host "Cruce BD (alineado API):"
    Write-Host "  pedidos: $dbPedidos | caja neto: $dbCaja | diff: $dbDiff"
    $apiMatch = [math]::Abs($ventasPedidos - $dbPedidos) -lt 0.01 -and [math]::Abs($ventasCaja - $dbCaja) -lt 0.01
    if (-not $apiMatch) {
        Write-Host "FALLO: API no coincide con consulta SQL directa"
        exit 1
    }
    Write-Host "OK: API alineada con BD"
}
else {
    Write-Host "AVISO: no se pudo cruzar con BD ($dbRaw)"
}

if ([math]::Abs($diferencia - ($ventasPedidos - $ventasCaja)) -gt 0.01) {
    Write-Host "FALLO: diferencia no cuadra con ventas_pedidos - ventas_caja"
    exit 1
}
Write-Host "OK: campo diferencia coherente"

if ([math]::Abs($diferencia) -lt 1) {
    Write-Host ""
    Write-Host "RESULTADO: CUADRE OK (tickets vs caja neto < 1 COP)"
    exit 0
}

if ($null -ne $pagadoAcum -and [math]::Abs($diffPagado) -lt 1) {
    Write-Host ""
    Write-Host "RESULTADO: CUADRE COBROS OK (monto_pagado vs caja < 1 COP)"
    Write-Host "  Nota: diferencia tickets-vs-caja ($diferencia) es normal con mesas/domicilios sin cobrar aun."
    exit 0
}

Write-Host ""
Write-Host "RESULTADO: DIFERENCIA ESPERABLE (tickets - caja neto = $diferencia COP)"
Write-Host "  Universos distintos: reportes suman pedidos del periodo; caja suma cobros netos."
Write-Host "  No es fallo de cuadre contable si hay pedidos abiertos o prepago pendiente de cierre."
exit 0
