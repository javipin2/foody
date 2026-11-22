# Foody — QA empaques/subrecetas en receta (P2-14)
# Uso: powershell -File scripts/verificar-receta-empaque.ps1
$ErrorActionPreference = "Continue"
$Base = "http://localhost:3000/api/v1"
$Sucursal = "c0000000-0000-4000-8000-000000000001"
$Producto = "f0000000-0000-4000-8000-000000000001"
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
Write-Host "=== QA Receta empaques (P2-14) ==="
Write-Host ""

$login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = "admin@foody.demo"; contrasena = $Pass
}
if (-not ($login.ok -and $login.json.exito)) {
    Write-Host "FALLO: login"
    exit 1
}
$h = @{ Authorization = "Bearer $($login.json.datos.token)" }

$recalc = Invoke-Api -Method POST -Path "/costeo/recalcular/${Sucursal}" -Headers $h
if (-not ($recalc.ok -and $recalc.json.exito)) {
    Write-Host "AVISO: recalcular sucursal ($($recalc.status)) - continuando"
}

$rec = Invoke-Api -Path "/inventario/producto-ingredientes/${Producto}" -Headers $h
if (-not ($rec.ok -and $rec.json.exito)) {
    Write-Host "FALLO: GET receta ($($rec.status))"
    exit 1
}

$d = $rec.json.datos
$items = @($d.items)
$empaques = @($items | Where-Object { $_.tipo_item -eq 'empaque' })
$subrecetas = @($items | Where-Object { $_.tipo_item -eq 'subreceta' })

Write-Host "Producto demo: $Producto"
Write-Host "Lineas totales: $($items.Count) | subrecetas: $($subrecetas.Count) | empaques: $($empaques.Count)"
Write-Host "costo_calculado=$($d.costo_calculado) costo_domicilio=$($d.costo_domicilio) margen_error=$($d.margen_error)"

if ($empaques.Count -lt 1) {
    Write-Host "FALLO: se esperaba al menos 1 linea tipo empaque en seed demo"
    exit 1
}

$costoMesa = [decimal]$d.costo_calculado
$costoDomi = [decimal]$d.costo_domicilio
if ($costoDomi -le $costoMesa) {
    Write-Host "FALLO: costo_domicilio debe ser mayor que costo_calculado (mesa)"
    exit 1
}

Write-Host ""
Write-Host "OK - receta con empaques y costo domicilio verificado"
exit 0
