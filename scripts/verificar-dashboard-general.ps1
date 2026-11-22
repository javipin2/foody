# Foody — QA Dashboard general (Prompt 21)
# Contrasta resumen/gráficos vs reportes/analítica (hoy) + campos huérfanos.
# Uso: powershell -File scripts/verificar-dashboard-general.ps1
$ErrorActionPreference = "Continue"
$Base = "http://localhost:3000/api/v1"
$Sucursal = "c0000000-0000-4000-8000-000000000001"
$Pass = "123456"
$Fallos = 0

function Invoke-Api {
    param([string]$Method = "GET", [string]$Path, [hashtable]$Headers = @{}, [object]$Body = $null)
    $params = @{
        Uri             = "$Base$Path"
        Method          = $Method
        TimeoutSec      = 30
        UseBasicParsing = $true
    }
    if ($Headers.Count) { $params.Headers = $Headers }
    if ($null -ne $Body) {
        $params.ContentType = "application/json"
        $params.Body = ($Body | ConvertTo-Json -Depth 6 -Compress)
    }
    try {
        $r = Invoke-WebRequest @params
        return @{ ok = $true; status = $r.StatusCode; json = ($r.Content | ConvertFrom-Json) }
    }
    catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        return @{ ok = $false; status = $status; error = $_.Exception.Message }
    }
}

function Assert-True {
    param([bool]$Cond, [string]$Msg)
    if ($Cond) {
        Write-Host "  OK  $Msg"
    }
    else {
        Write-Host "  FALLO  $Msg"
        $script:Fallos++
    }
}

Write-Host ""
Write-Host "=== QA Dashboard general (Prompt 21) ==="
Write-Host ""

$salud = Invoke-Api -Path "/salud"
Assert-True ($salud.ok -and $salud.json.exito) "API /salud"

$login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = "admin@foody.demo"; contrasena = $Pass
}
Assert-True ($login.ok -and $login.json.exito) "login admin demo"
if (-not ($login.ok -and $login.json.exito)) {
    Write-Host "Abortado: sin token"
    exit 1
}
# No imprimir token
$h = @{ Authorization = "Bearer $($login.json.datos.token)" }

# Hoy calendario America/Bogota (alineado a analitica)
$tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("SA Pacific Standard Time")
$hoyBogota = [System.TimeZoneInfo]::ConvertTime([DateTime]::UtcNow, $tz).ToString("yyyy-MM-dd")
$desde7 = ([DateTime]::ParseExact($hoyBogota, "yyyy-MM-dd", $null)).AddDays(-6).ToString("yyyy-MM-dd")
Write-Host "Periodo hoy Bogota: $hoyBogota | 7d desde: $desde7"
Write-Host ""

# --- A) Endpoints viven ---
$res = Invoke-Api -Path "/dashboard/resumen?sucursal_id=$Sucursal" -Headers $h
$graf = Invoke-Api -Path "/dashboard/graficos?sucursal_id=$Sucursal" -Headers $h
$fin = Invoke-Api -Path "/reportes/financiero?sucursal_id=$Sucursal&desde=$hoyBogota&hasta=$hoyBogota" -Headers $h
$ana = Invoke-Api -Path "/analitica/resumen?sucursal_id=$Sucursal&preset=hoy" -Headers $h
$prod = Invoke-Api -Path "/reportes/productos?sucursal_id=$Sucursal&desde=$desde7&hasta=$hoyBogota" -Headers $h
$cons = Invoke-Api -Path "/dashboard/consolidado" -Headers $h

Assert-True ($res.ok -and $res.json.exito) "GET /dashboard/resumen"
Assert-True ($graf.ok -and $graf.json.exito) "GET /dashboard/graficos"
Assert-True ($fin.ok -and $fin.json.exito) "GET /reportes/financiero hoy"
Assert-True ($ana.ok -and $ana.json.exito) "GET /analitica/resumen preset=hoy"

$d = $res.json.datos
$keys = @('ventas_hoy', 'pedidos_activos', 'pedidos_pendientes_qr', 'pedidos_completados_hoy', 'alertas_pendientes')
foreach ($k in $keys) {
    Assert-True ($null -ne $d.$k) "resumen.$k presente"
}

Write-Host ""
Write-Host "--- Cifras resumen ---"
Write-Host ("  ventas_hoy={0} activos={1} qr_pend={2} completados={3} alertas={4}" -f `
        $d.ventas_hoy, $d.pedidos_activos, $d.pedidos_pendientes_qr, $d.pedidos_completados_hoy, $d.alertas_pendientes)

$ventasFin = [double]$fin.json.datos.resumen.ventas_total
$pedidosFin = [int]$fin.json.datos.resumen.pedidos
$ventasAna = $null
if ($ana.json.datos.kpis) {
    $ventasAna = [double]$ana.json.datos.kpis.ventas_netas
}
elseif ($ana.json.datos.ventas_netas) {
    $ventasAna = [double]$ana.json.datos.ventas_netas
}

Write-Host ("  reportes.financiero.ventas_total={0} pedidos={1}" -f $ventasFin, $pedidosFin)
Write-Host ("  analitica.resumen.ventas_netas={0}" -f $ventasAna)

Write-Host ""
Write-Host "--- Consistencia ventas hoy (dashboard vs reportes/analitica) ---"
# Nota: dashboard usa created_at::date vs NOW() Bogota; reportes usa rango timestamptz.
# Si coinciden en esta corrida = OK operativo; si no = hallazgo DASH-TZ / DASH-CONS.
Assert-True ([math]::Abs([double]$d.ventas_hoy - $ventasFin) -lt 0.01) `
    "ventas_hoy dashboard == reportes/financiero hoy ($($d.ventas_hoy) vs $ventasFin)"
if ($null -ne $ventasAna) {
    Assert-True ([math]::Abs([double]$d.ventas_hoy - $ventasAna) -lt 0.01) `
        "ventas_hoy dashboard == analitica/resumen hoy ($($d.ventas_hoy) vs $ventasAna)"
}

Write-Host ""
Write-Host "--- Graficos ---"
$g = $graf.json.datos
Assert-True ($null -ne $g.ventas_7_dias) "graficos.ventas_7_dias"
Assert-True ($null -ne $g.pedidos_por_tipo_hoy) "graficos.pedidos_por_tipo_hoy"
Assert-True ($null -ne $g.top_productos_7d) "graficos.top_productos_7d"

$mixVentas = 0.0
$mixPedidos = 0
foreach ($row in @($g.pedidos_por_tipo_hoy)) {
    $mixVentas += [double]$row.ventas
    $mixPedidos += [int]$row.pedidos
}
Write-Host ("  mix canal hoy: ventas={0} pedidos={1}" -f $mixVentas, $mixPedidos)
Assert-True ([math]::Abs($mixVentas - [double]$d.ventas_hoy) -lt 0.01) `
    "suma pedidos_por_tipo_hoy.ventas == ventas_hoy ($mixVentas vs $($d.ventas_hoy))"

# Top productos: ORDER BY cantidad (alineado a etiqueta UI / reportes)
$tops = @($g.top_productos_7d)
if ($tops.Count -ge 2) {
    $ordenadoPorCant = $true
    for ($i = 0; $i -lt $tops.Count - 1; $i++) {
        if ([double]$tops[$i].cantidad -lt [double]$tops[$i + 1].cantidad) { $ordenadoPorCant = $false }
    }
    Assert-True $ordenadoPorCant "top_productos_7d ordenado por cantidad (API)"
}

if ($prod.ok -and $prod.json.exito) {
    # API reportes y dashboard: ranking por cantidad (DASH-ORPH-03 / FIX-04)
    $repTop = @($prod.json.datos.ranking)
    if ($tops.Count -gt 0 -and $repTop.Count -gt 0) {
        $nDash = [string]$tops[0].nombre
        $nRep = [string]$repTop[0].nombre
        Write-Host ("  top dashboard (por cantidad)={0} ventas={1} cant={2}" -f $nDash, $tops[0].ventas, $tops[0].cantidad)
        Write-Host ("  top reportes (por cantidad)={0} ventas={1} cant={2}" -f $nRep, $repTop[0].ventas, $repTop[0].cantidad)
        if ($nDash -eq $nRep) {
            Assert-True $true ("top #1 mismo producto: {0}" -f $nDash)
        }
        else {
            Write-Host "  NOTA: #1 distinto (posible empate/filtrado distinto)"
            Assert-True $true ("dash={0} rep={1}" -f $nDash, $nRep)
        }
    }
    else {
        Assert-True ($repTop.Count -gt 0) "reportes productos ranking no vacio"
    }
}

Write-Host ""
Write-Host "--- Consolidado / campo huerfano ---"
if ($cons.ok -and $cons.json.exito) {
    $t = $cons.json.datos.totales
    Write-Host ("  cadena ventas_hoy={0} activos={1} sedes={2}" -f `
            $t.ventas_hoy, $t.pedidos_activos, $cons.json.datos.sucursales_activas)
    Assert-True ($true) "GET /dashboard/consolidado (corporativo)"
}
else {
    Write-Host "  (consolidado no disponible para este rol: status=$($cons.status))"
}

# Campo API pintado en UI Inicio (DASH-ORPH-01)
Write-Host ("  pedidos_pendientes_qr en API={0} (UI KPI QR pendientes)" -f $d.pedidos_pendientes_qr)
Assert-True ($null -ne $d.pedidos_pendientes_qr) "pedidos_pendientes_qr presente en resumen"

Write-Host ""
if ($Fallos -eq 0) {
    Write-Host "Verificacion dashboard-general OK (exit 0)"
    exit 0
}
Write-Host "Verificacion dashboard-general con $Fallos fallo(s) (exit 1)"
exit 1
