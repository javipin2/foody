# Foody — QA graficos dashboard admin (P2-15)
# Uso: powershell -File scripts/verificar-dashboard-graficos.ps1
$ErrorActionPreference = "Continue"
$Base = "http://localhost:3000/api/v1"
$Sucursal = "c0000000-0000-4000-8000-000000000001"
$Pass = "123456"

function Invoke-Api {
    param([string]$Method = "GET", [string]$Path, [hashtable]$Headers = @{}, [object]$Body = $null)
    $params = @{
        Uri             = "$Base$Path"
        Method          = $Method
        TimeoutSec      = 25
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
Write-Host "=== QA Dashboard graficos (P2-15) ==="
Write-Host ""

$login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = "admin@foody.demo"; contrasena = $Pass
}
if (-not ($login.ok -and $login.json.exito)) {
    Write-Host "FALLO: login"
    exit 1
}
$h = @{ Authorization = "Bearer $($login.json.datos.token)" }

$g = Invoke-Api -Path "/dashboard/graficos?sucursal_id=${Sucursal}" -Headers $h
if (-not ($g.ok -and $g.json.exito)) {
    Write-Host "FALLO: GET graficos ($($g.status))"
    exit 1
}

$d = $g.json.datos
$requeridos = @('ventas_7_dias', 'pedidos_por_tipo_hoy', 'top_productos_7d')
foreach ($prop in $requeridos) {
    if (-not ($d.PSObject.Properties.Name -contains $prop)) {
        Write-Host "FALLO: falta propiedad $prop"
        exit 1
    }
}

$diaCount = @($d.ventas_7_dias).Count
$tipoCount = @($d.pedidos_por_tipo_hoy).Count
$topCount = @($d.top_productos_7d).Count
Write-Host "Series 7d: $diaCount dias | tipos hoy: $tipoCount | top productos: $topCount"

Write-Host ""
Write-Host "OK - dashboard graficos verificado"
exit 0
