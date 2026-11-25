# Foody — QA cuentas por cobrar (P2-10): resumen, listado y cobro
# Uso: powershell -File scripts/verificar-cxc.ps1
$ErrorActionPreference = "Continue"
$Base = "http://127.0.0.1:3001/api/v1"
$Sucursal = "c0000000-0000-4000-8000-000000000001"
$Pass = "123456"

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
Write-Host "=== QA Cuentas por cobrar (CxC) ==="
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

$resumen = Invoke-Api -Path "/caja/cuentas-por-cobrar/$Sucursal/resumen" -Headers $h
if (-not ($resumen.ok -and $resumen.json.exito)) {
    Write-Host "FALLO: GET resumen CxC ($($resumen.status))"
    exit 1
}
Write-Host "Resumen: total pendiente=$($resumen.json.datos.total_pendiente) cantidad=$($resumen.json.datos.cantidad_pendiente) antiguas_7d=$($resumen.json.datos.antiguas_7d)"

$listado = Invoke-Api -Path "/caja/cuentas-por-cobrar/$Sucursal" -Headers $h
if (-not ($listado.ok -and $listado.json.exito)) {
    Write-Host "FALLO: GET listado CxC ($($listado.status))"
    exit 1
}
$pendientes = @($listado.json.datos | Where-Object { $_.estado -eq 'pendiente' })
Write-Host "Pendientes en listado: $($pendientes.Count)"

$historial = Invoke-Api -Path "/caja/cuentas-por-cobrar/${Sucursal}?incluir_pagadas=true" -Headers $h
if (-not ($historial.ok -and $historial.json.exito)) {
    Write-Host "FALLO: GET historial CxC ($($historial.status))"
    exit 1
}
Write-Host "Historial total: $(@($historial.json.datos).Count)"

# Crear cuenta de prueba si no hay pendientes (opcional smoke)
if ($pendientes.Count -eq 0) {
    $crear = Invoke-Api -Method POST -Path "/caja/cuentas-por-cobrar" -Headers $h -Body @{
        sucursal_id     = $Sucursal
        cliente_nombre  = "QA CxC $(Get-Date -Format 'HHmmss')"
        cliente_telefono = "3000000000"
        monto           = 15000
    }
    if (-not ($crear.ok -and $crear.json.exito)) {
        Write-Host "FALLO: POST crear CxC ($($crear.status))"
        exit 1
    }
    $cuentaId = $crear.json.datos.id
    Write-Host "Creada cuenta prueba: $cuentaId"
}
else {
    $cuentaId = $pendientes[0].id
    Write-Host "Usando cuenta existente: $cuentaId"
}

$pagar = Invoke-Api -Method PATCH -Path "/caja/cuentas-por-cobrar/$cuentaId/pagar" -Headers $h -Body @{
    metodo_pago = "transferencia"
}
if (-not ($pagar.ok -and $pagar.json.exito)) {
    Write-Host "FALLO: PATCH pagar CxC ($($pagar.status))"
    exit 1
}
Write-Host "Cobro OK (transferencia)"

$resumen2 = Invoke-Api -Path "/caja/cuentas-por-cobrar/$Sucursal/resumen" -Headers $h
Write-Host "Resumen post-cobro: cantidad=$($resumen2.json.datos.cantidad_pendiente)"

Write-Host ""
Write-Host "OK - CxC resumen, listado, historial y cobro verificados"
exit 0
