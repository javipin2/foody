# Foody — QA simulador popularidad mesa/domicilio (P2-13)
# Uso: powershell -File scripts/verificar-popularidad.ps1
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
Write-Host "=== QA Popularidad costeo (P2-13) ==="
Write-Host ""

$login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = "admin@foody.demo"; contrasena = $Pass
}
if (-not ($login.ok -and $login.json.exito)) {
    Write-Host "FALLO: login"
    exit 1
}
$h = @{ Authorization = "Bearer $($login.json.datos.token)" }

$pop = Invoke-Api -Path "/costeo/popularidad/${Sucursal}?preset=30d" -Headers $h
if (-not ($pop.ok -and $pop.json.exito)) {
    Write-Host "FALLO: GET popularidad ($($pop.status))"
    exit 1
}

$d = $pop.json.datos
if (-not $d.mesa -or -not $d.domicilio) {
    Write-Host "FALLO: respuesta sin bloques mesa/domicilio"
    exit 1
}

$mesaCount = @($d.mesa.productos).Count
$domiCount = @($d.domicilio.productos).Count
Write-Host "Periodo: $($d.periodo.label)"
Write-Host "Productos mesa: $mesaCount | domicilio/llevar: $domiCount"
Write-Host "Totales mesa ventas=$($d.mesa.totales.ventas) margen=$($d.mesa.totales.margen_bruto)"

if ($mesaCount -gt 0) {
    $p0 = $d.mesa.productos[0]
    if (-not $p0.clasificacion_abc -or -not $p0.clasificacion_matriz) {
        Write-Host "FALLO: producto sin clasificacion ABC/matriz"
        exit 1
    }
    Write-Host "Ejemplo: $($p0.nombre) ABC=$($p0.clasificacion_abc) matriz=$($p0.clasificacion_matriz)"
}

Write-Host ""
Write-Host "OK - simulador popularidad verificado"
exit 0
