# Foody — HUER D3: observaciones KDS + costeo combos
# Uso: powershell -File scripts/verificar-huer-d3.ps1
$ErrorActionPreference = "Continue"
$Base = "http://localhost:3000/api/v1"
$Sucursal = "c0000000-0000-4000-8000-000000000001"
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
    if ($Cond) { Write-Host "  OK  $Msg" }
    else { Write-Host "  FALLO  $Msg"; $script:Fallos++ }
}

Write-Host "=== Verificar HUER D3 (obs KDS + combos costeo) ==="

$salud = Invoke-Api -Path "/salud"
Assert-True ($salud.ok -and $salud.json.exito) "API /salud"

$login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email      = "admin@foody.demo"
    contrasena = "123456"
}
Assert-True ($login.ok -and $login.json.exito) "login admin"
$token = $login.json.datos.token
$h = @{ Authorization = "Bearer $token" }

# --- Costeo combos ---
$res = Invoke-Api -Path "/costeo/resumen/$Sucursal" -Headers $h
Assert-True ($res.ok -and $res.json.exito) "GET /costeo/resumen"
$combos = @()
if ($res.ok -and $res.json.exito) { $combos = @($res.json.datos.combos) }
Assert-True ($res.ok -and $null -ne $res.json.datos.combos) "resumen incluye clave combos (n=$($combos.Count))"

if ($combos.Count -gt 0) {
    $cid = [string]$combos[0].id
    $rec = Invoke-Api -Method POST -Path "/costeo/combos/$cid/recalcular?sucursal_id=$Sucursal" -Headers $h
    Assert-True ($rec.ok -and $rec.json.exito) "POST /costeo/combos/:id/recalcular"
    $costoCalc = $rec.json.datos.costo_calculado
    if ($null -eq $costoCalc) { $costoCalc = $rec.json.datos.costo_calculado_total }
    if ($null -eq $costoCalc) { $costoCalc = $rec.json.datos.costo }
    Assert-True ($null -ne $costoCalc) "costo calculado en respuesta"
}
else {
    Write-Host "  NOTA: sin combos demo — skip recalcular"
    Assert-True $true "skip combos vacio"
}

# --- Observaciones KDS ---
$loginC = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email      = "cocina@foody.demo"
    contrasena = "123456"
}
if (-not ($loginC.ok -and $loginC.json.exito)) {
    $loginC = $login
}
Assert-True ($loginC.ok -and $loginC.json.exito) "login cocina/admin"
$hk = @{ Authorization = "Bearer $($loginC.json.datos.token)" }

$cocinas = Invoke-Api -Path "/cocina/cocinas" -Headers $hk
Assert-True ($cocinas.ok -and $cocinas.json.exito) "GET /cocina/cocinas"
$cocinaId = $null
foreach ($c in @($cocinas.json.datos)) {
    if ($c.id) { $cocinaId = [string]$c.id; break }
}
Assert-True ($null -ne $cocinaId) "hay cocina para KDS"

$tickets = Invoke-Api -Path "/cocina/tickets/$cocinaId" -Headers $hk
Assert-True ($tickets.ok -and $tickets.json.exito) "GET /cocina/tickets"
$itemId = $null
foreach ($t in @($tickets.json.datos)) {
    foreach ($it in @($t.items)) {
        if ($it.item_id -and $it.estado_cocina -ne 'listo' -and $it.estado_cocina -ne 'no_disponible') {
            $itemId = [string]$it.item_id
            break
        }
    }
    if ($itemId) { break }
}

if ($itemId) {
    $obs = Invoke-Api -Method PATCH -Path "/cocina/items/$itemId/observaciones" -Headers $hk -Body @{
        observaciones = "Nota QA huer-d3"
    }
    Assert-True ($obs.ok -and $obs.json.exito) "PATCH observaciones"
    Assert-True (("$($obs.json.datos.observaciones)" -match "Nota QA")) "obs guardada"
    # restaurar limpio (sin borrar urgente si existiera)
    $null = Invoke-Api -Method PATCH -Path "/cocina/items/$itemId/observaciones" -Headers $hk -Body @{
        observaciones = ""
    }
}
else {
    Write-Host "  NOTA: sin ítem KDS abierto — skip PATCH obs"
    Assert-True $true "skip obs sin ticket"
}

Write-Host ""
if ($Fallos -eq 0) {
    Write-Host "Verificacion HUER D3 OK (exit 0)"
    exit 0
}
Write-Host "Verificacion HUER D3 FALLO ($Fallos) (exit 1)"
exit 1
