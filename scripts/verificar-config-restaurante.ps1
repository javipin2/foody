# Foody — QA Configuración restaurante (Prompt 22)
# Inventario API: superficies de config + brechas (PATCH sede, margen, fiscal, horarios).
# Uso: powershell -File scripts/verificar-config-restaurante.ps1
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
    if ($Cond) { Write-Host "  OK  $Msg" }
    else { Write-Host "  FALLO  $Msg"; $script:Fallos++ }
}

Write-Host ""
Write-Host "=== QA Config restaurante (Prompt 22) ==="
Write-Host ""

$salud = Invoke-Api -Path "/salud"
Assert-True ($salud.ok -and $salud.json.exito) "API /salud"

$login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = "admin@foody.demo"; contrasena = $Pass
}
Assert-True ($login.ok -and $login.json.exito) "login admin"
if (-not ($login.ok -and $login.json.exito)) { exit 1 }
$h = @{ Authorization = "Bearer $($login.json.datos.token)" }

# --- Superficies con UI esperada ---
$marca = Invoke-Api -Path "/sucursales/marca" -Headers $h
Assert-True ($marca.ok -and $marca.json.exito) "GET /sucursales/marca"
if ($marca.ok) {
    $mk = $marca.json.datos
    Write-Host ("    nombre={0} logo={1}" -f $mk.nombre, [bool]$mk.logo_url)
}

$hor = Invoke-Api -Path "/sucursales/$Sucursal/horarios" -Headers $h
Assert-True ($hor.ok -and $hor.json.exito) "GET horarios sede"
Write-Host ("    horarios count={0}" -f @($hor.json.datos).Count)

$fis = Invoke-Api -Path "/facturacion/config/$Sucursal" -Headers $h
if ($fis.ok -and $fis.json.exito) {
    Write-Host "  OK  GET facturacion/config"
    Write-Host ("    aplica_iva={0} pct={1}" -f $fis.json.datos.aplica_iva, $fis.json.datos.porcentaje_iva)
} elseif ($fis.status -eq 403) {
    Write-Host "  OK  GET facturacion/config bloqueado por plan (403) - UI existe, modulo enterprise (CFG-PLAN-FACT)"
} else {
    Write-Host ("  FALLO  GET facturacion/config status={0}" -f $fis.status)
    $Fallos++
}

$zon = Invoke-Api -Path "/zonas/$Sucursal" -Headers $h
Assert-True ($zon.ok -and $zon.json.exito) "GET zonas"
Write-Host ("    zonas count={0}" -f @($zon.json.datos).Count)

$map = Invoke-Api -Path "/zonas/sucursal/$Sucursal/configuracion-mapa" -Headers $h
Assert-True ($map.ok -and $map.json.exito) "GET configuracion-mapa (lat/lng)"

# Flags fiado/caja viven embebidos en liquidacion + domicilios (no GET dedicado)
$liq = Invoke-Api -Path "/domiciliarios-planta/liquidacion/$Sucursal" -Headers $h
if ($liq.ok -and $liq.json.exito) {
    Write-Host ("  OK  liquidacion.permite_fiado={0}" -f $liq.json.datos.permite_fiado_domiciliario)
} else {
    Write-Host ("  FALLO  GET liquidacion status={0}" -f $liq.status)
    $Fallos++
}
$dom = Invoke-Api -Path "/domiciliarios-planta/domicilios/$Sucursal" -Headers $h
if ($dom.ok -and $dom.json.exito) {
    Write-Host ("  OK  domicilios.domicilio_ingresa_a_caja={0}" -f $dom.json.datos.domicilio_ingresa_a_caja)
} else {
    Write-Host ("  FALLO  GET domicilios status={0}" -f $dom.status)
    $Fallos++
}

$coc = Invoke-Api -Path "/cocinas/$Sucursal" -Headers $h
Assert-True ($coc.ok -and $coc.json.exito) "GET cocinas"

$imp = Invoke-Api -Path "/impresoras/$Sucursal" -Headers $h
Assert-True ($imp.ok -and $imp.json.exito) "GET impresoras"

# --- Brechas: no debe existir PATCH perfil sede ---
$patchSede = Invoke-Api -Method PATCH -Path "/sucursales/$Sucursal" -Headers $h -Body @{
    nombre = "no-debe-existir"
}
# Nest suele devolver 404 si no hay ruta
Assert-True (-not $patchSede.ok -or $patchSede.status -ge 400) `
    ("PATCH /sucursales/:id ausente o rechazado (status={0}) CFG-PATCH-SUCURSAL-01" -f $patchSede.status)

# Marca DTO no incluye nombre (solo logo/banner/descripcion)
Assert-True ($null -ne $marca.json.datos.nombre) "marca.nombre legible (edicion nombre = CFG-NOMBRE-MARCA-07)"

# --- Super config: claves en BD vs uso runtime ---
$superLogin = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = "super@foody.demo"; contrasena = $Pass
}
Assert-True ($superLogin.ok -and $superLogin.json.exito) "login super"
$hs = @{ Authorization = "Bearer $($superLogin.json.datos.token)" }
$cfg = Invoke-Api -Path "/super/configuracion" -Headers $hs
Assert-True ($cfg.ok -and $cfg.json.exito) "GET /super/configuracion"
$claves = @($cfg.json.datos | ForEach-Object { $_.clave })
Write-Host ("    claves globales: {0}" -f ($claves -join ', '))
$esperadas = @(
    'comision_domiciliario_porcentaje',
    'tiempo_expiracion_oferta_seg',
    'umbral_alerta_descuento_pct',
    'tiempo_aprobacion_mesera_min',
    'dias_datos_restaurante_bloqueado'
)
foreach ($c in $esperadas) {
    Assert-True ($claves -contains $c) "clave global presente: $c"
}
Write-Host "  NOTA CFG-GLOBAL-DEAD: runtime usa UMBRALES_ALERTA / constantes dispatch; solo dias_datos leido en cron"

# Propagacion horario: PATCH no-op (mismos valores) + invalidacion cache (smoke)
$h0 = @($hor.json.datos) | Select-Object -First 1
if ($h0) {
    $hid = [string]$h0.id
    $patchH = Invoke-Api -Method PATCH -Path "/sucursales/horarios/$hid" -Headers $h -Body @{
        activo = [bool]$h0.activo
    }
    Assert-True ($patchH.ok -and $patchH.json.exito) "PATCH horario (smoke invalidacion menu cache)"
}

Write-Host ""
if ($Fallos -eq 0) {
    Write-Host "Verificacion config-restaurante OK (exit 0)"
    exit 0
}
Write-Host ("Verificacion config-restaurante con {0} fallo(s) (exit 1)" -f $Fallos)
exit 1
