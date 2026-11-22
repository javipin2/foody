# Foody — HUER CFG 01: márgenes sede write
# Uso: powershell -File scripts/verificar-huer-cfg-01.ps1

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
        $params.Body = ($Body | ConvertTo-Json -Depth 8 -Compress)
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

Write-Host "=== Verificar HUER CFG 01 (márgenes sede) ==="

$salud = Invoke-Api -Path "/salud"
Assert-True ($salud.ok -and $salud.json.exito) "API /salud"

$login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email      = "admin@foody.demo"
    contrasena = "123456"
}
Assert-True ($login.ok -and $login.json.exito) "login admin"
$token = $login.json.datos.token
$h = @{ Authorization = "Bearer $token" }

$res1 = Invoke-Api -Path "/costeo/resumen/$Sucursal" -Headers $h
Assert-True ($res1.ok -and $res1.json.exito) "GET /costeo/resumen (antes)"

$origMargenDef = [double]$res1.json.datos.margen_objetivo_default
$origUmbral = [double]$res1.json.datos.umbral_margen

# Nuevos valores dentro de UI-range (5..80)
$newMargenDef = 40
$newUmbral = 30

$patch = Invoke-Api -Method PATCH -Path "/sucursales/margenes/$Sucursal" -Headers $h -Body @{
    margen_objetivo_default = $newMargenDef
    umbral_alerta_margen    = $newUmbral
}
Assert-True ($patch.ok -and $patch.json.exito) "PATCH /sucursales/margenes"
if (-not ($patch.ok -and $patch.json.exito)) {
    Write-Host "  DETALLE PATCH: status=$($patch.status) error=$($patch.error)"
}
Assert-True ($patch.json.datos.margen_objetivo_default -eq $newMargenDef) "margen_objetivo_default actualizado (respuesta)"
Assert-True ($patch.json.datos.umbral_alerta_margen -eq $newUmbral) "umbral_alerta_margen actualizado (respuesta)"

$res2 = Invoke-Api -Path "/costeo/resumen/$Sucursal" -Headers $h
Assert-True ($res2.ok -and $res2.json.exito) "GET /costeo/resumen (después)"
Assert-True ($res2.json.datos.margen_objetivo_default -eq $newMargenDef) "margen_objetivo_default refleja PATCH"
Assert-True ($res2.json.datos.umbral_margen -eq $newUmbral) "umbral_margen refleja PATCH"

# revertir
$revert = Invoke-Api -Method PATCH -Path "/sucursales/margenes/$Sucursal" -Headers $h -Body @{
    margen_objetivo_default = $origMargenDef
    umbral_alerta_margen    = $origUmbral
}
Assert-True ($revert.ok -and $revert.json.exito) "PATCH revert"

$res3 = Invoke-Api -Path "/costeo/resumen/$Sucursal" -Headers $h
Assert-True ($res3.ok -and $res3.json.exito) "GET /costeo/resumen (revert)"
Assert-True ($res3.json.datos.margen_objetivo_default -eq $origMargenDef) "revert margen_objetivo_default"
Assert-True ($res3.json.datos.umbral_margen -eq $origUmbral) "revert umbral_margen"

Write-Host ""
if ($Fallos -eq 0) {
    Write-Host "Verificacion HUER-CFG-01 OK (exit 0)"
    exit 0
}
Write-Host "Verificacion HUER-CFG-01 FALLO ($Fallos) (exit 1)"
exit 1

