# Foody — QA reportes admin + datos export P2-16
# Uso: powershell -File scripts/verificar-reportes-export.ps1
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
Write-Host "=== QA Reportes export (P2-16) ==="
Write-Host ""

$login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = "admin@foody.demo"; contrasena = $Pass
}
if (-not ($login.ok -and $login.json.exito)) {
    Write-Host "FALLO: login"
    exit 1
}
$h = @{ Authorization = "Bearer $($login.json.datos.token)" }

$hoy = (Get-Date).ToString("yyyy-MM-dd")
$desde = (Get-Date).AddDays(-6).ToString("yyyy-MM-dd")
$q = "sucursal_id=${Sucursal}&desde=${desde}&hasta=${hoy}"

$fin = Invoke-Api -Path "/reportes/financiero?$q" -Headers $h
$prod = Invoke-Api -Path "/reportes/productos?$q" -Headers $h
$ped = Invoke-Api -Path "/reportes/pedidos?$q" -Headers $h

foreach ($nombre in @('financiero', 'productos', 'pedidos')) {
    $r = switch ($nombre) {
        'financiero' { $fin }
        'productos' { $prod }
        'pedidos' { $ped }
    }
    if (-not ($r.ok -and $r.json.exito)) {
        Write-Host "FALLO: GET reportes/$nombre ($($r.status))"
        exit 1
    }
    if (-not $r.json.datos.periodo) {
        Write-Host "FALLO: reportes/$nombre sin periodo"
        exit 1
    }
}

$res = $fin.json.datos.resumen
if ($null -eq $res.ventas_total) {
    Write-Host "FALLO: financiero sin resumen.ventas_total"
    exit 1
}

Write-Host "Financiero: ventas=$($res.ventas_total) pedidos=$($res.pedidos)"
Write-Host "Productos ranking: $(@($prod.json.datos.ranking).Count) filas"
Write-Host "Pedidos por_dia: $(@($ped.json.datos.por_dia).Count) dias"
Write-Host ""
Write-Host "OK - API reportes lista para export PDF/CSV en Flutter"
exit 0
