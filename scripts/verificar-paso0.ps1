# Foody - Paso 0: verificacion entorno + logins demo + rutas clave
# Uso: powershell -File scripts/verificar-paso0.ps1
$ErrorActionPreference = "Continue"
$Base = "http://localhost:3000/api/v1"
$Sucursal = "c0000000-0000-4000-8000-000000000001"
$Pass = "123456"

function Invoke-Api {
    param([string]$Method = "GET", [string]$Path, [hashtable]$Headers = @{}, [object]$Body = $null)
    $uri = "$Base$Path"
    $params = @{
        Uri             = $uri
        Method          = $Method
        TimeoutSec      = 15
        UseBasicParsing = $true
    }
    if ($Headers.Count) { $params.Headers = $Headers }
    if ($null -ne $Body) {
        $params.ContentType = "application/json"
        $params.Body = ($Body | ConvertTo-Json -Depth 6 -Compress)
    }
    try {
        $r = Invoke-WebRequest @params
        $json = $null
        try { $json = $r.Content | ConvertFrom-Json } catch {}
        return @{ ok = $true; status = $r.StatusCode; json = $json; raw = $r.Content }
    }
    catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        return @{ ok = $false; status = $status; error = $_.Exception.Message }
    }
}

$results = @()

function Add-Result($area, $test, $ok, $detail) {
    $script:results += [PSCustomObject]@{
        Area   = $area
        Test   = $test
        OK     = if ($ok) { "OK" } else { "FALLO" }
        Detalle = $detail
    }
}

Write-Host ""
Write-Host "=== PASO 0 - Verificacion Foody ==="
Write-Host ""

# 1. Salud
$s = Invoke-Api -Path "/salud"
Add-Result "Infra" "GET /salud" ($s.ok -and $s.status -eq 200) "status=$($s.status)"

# 2. Docker (opcional)
try {
    $db = docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT 1" 2>&1
    Add-Result "Infra" "Postgres supabase-db" ($db -match "1") $db.ToString().Trim()
}
catch { Add-Result "Infra" "Postgres supabase-db" $false $_.Exception.Message }

# 3. Logins staff
$logins = @(
    @{ email = "admin@foody.demo"; rol = "admin"; perfil = "/auth/perfil" }
    @{ email = "super@foody.demo"; rol = "super_admin"; perfil = "/auth/perfil" }
    @{ email = "cocina@foody.demo"; rol = "cocina"; perfil = "/auth/perfil" }
    @{ email = "domi@foody.demo"; rol = "domiciliario_planta"; perfil = "/auth/perfil" }
)
$tokens = @{}
foreach ($L in $logins) {
    $login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
        email = $L.email; contrasena = $Pass
    }
    $ok = $login.ok -and $login.json.exito -eq $true -and $login.json.datos.token
    $detail = if ($ok) { "rol=$($login.json.datos.usuario.rol)" } else { "status=$($login.status) $($login.error)" }
    Add-Result "Login" $L.email $ok $detail
    if ($ok) { $tokens[$L.email] = $login.json.datos.token }
}

# 4. Login domiciliario independiente
$loginInd = Invoke-Api -Method POST -Path "/auth/login-domiciliario" -Body @{
    email = "repartidor@foody.demo"; contrasena = $Pass
}
$okInd = $loginInd.ok -and $loginInd.json.exito -eq $true
Add-Result "Login" "repartidor@foody.demo (independiente)" $okInd $(if ($okInd) { "token OK" } else { "status=$($loginInd.status)" })
$tokenRepartidor = if ($okInd) { $loginInd.json.datos.token } else { $null }

# 5. Rutas por rol (admin)
if ($tokens["admin@foody.demo"]) {
    $h = @{ Authorization = "Bearer $($tokens['admin@foody.demo'])" }
    $checks = @(
        @{ name = "Pedidos sucursal"; path = "/pedidos?sucursal_id=$Sucursal" }
        @{ name = "Inventario"; path = "/inventario/$Sucursal" }
        @{ name = "Costos productos"; path = "/inventario/costos/$Sucursal" }
        @{ name = "Combos"; path = "/combos/$Sucursal" }
        @{ name = "Cocinas"; path = "/cocinas/$Sucursal" }
        @{ name = "Zonas"; path = "/zonas/$Sucursal" }
        @{ name = "Horarios"; path = "/sucursales/$Sucursal/horarios" }
        @{ name = "Reportes financiero"; path = ('/reportes/financiero?sucursal_id=' + $Sucursal + '&desde=2026-01-01&hasta=2026-12-31') }
        @{ name = "Alertas"; path = "/alertas/$Sucursal" }
    )
    foreach ($c in $checks) {
        $r = Invoke-Api -Path $c.path -Headers $h
        Add-Result "Admin API" $c.name ($r.ok -and $r.json.exito -eq $true) "HTTP $($r.status)"
    }
}

# 6. Cocina KDS
if ($tokens["cocina@foody.demo"]) {
    $h = @{ Authorization = "Bearer $($tokens['cocina@foody.demo'])" }
    $r = Invoke-Api -Path "/cocina/cocinas?sucursal_id=$Sucursal" -Headers $h
    Add-Result "Cocina API" "GET /cocina/cocinas" ($r.ok -and $r.json.exito -eq $true) "HTTP $($r.status)"
}

# 7. Domiciliario planta
if ($tokens["domi@foody.demo"]) {
    $h = @{ Authorization = "Bearer $($tokens['domi@foody.demo'])" }
    $r = Invoke-Api -Path "/domiciliario/pedidos-asignados" -Headers $h
    Add-Result "Dom. planta" "pedidos-asignados" ($r.ok -and $r.json.exito -eq $true) "HTTP $($r.status)"
}

# 8. Repartidor independiente
if ($tokenRepartidor) {
    $h = @{ Authorization = "Bearer $tokenRepartidor" }
    $r = Invoke-Api -Path "/domiciliarios/ofertas-activas" -Headers $h
    Add-Result "Dom. independiente" "ofertas-activas" ($r.ok -and $r.json.exito -eq $true) "HTTP $($r.status)"
}

# 9. Super admin
if ($tokens["super@foody.demo"]) {
    $h = @{ Authorization = "Bearer $($tokens['super@foody.demo'])" }
    $r = Invoke-Api -Path "/super/estadisticas" -Headers $h
    Add-Result "Super admin" "GET /super/estadisticas" ($r.ok -and $r.json.exito -eq $true) "HTTP $($r.status)"
}

# 10. Público cliente
$menu = Invoke-Api -Path "/menu/$Sucursal"
Add-Result "Cliente" "GET /menu/:sucursal" ($menu.ok -and $menu.json.exito -eq $true) "HTTP $($menu.status)"
$ciudades = Invoke-Api -Path "/ciudades"
Add-Result "Cliente" "GET /ciudades" ($ciudades.ok -and $ciudades.json.exito -eq $true) "HTTP $($ciudades.status)"

# 11. BD checks
try {
    $iva = docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='pedidos' AND column_name IN ('iva_porcentaje','iva_valor')" 2>&1
    Add-Result "Migraciones" "IVA en pedidos (027)" ($iva.Trim() -eq "2") "cols=$($iva.Trim())"
    $rls = docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT relrowsecurity FROM pg_class WHERE relname='pedidos'" 2>&1
    Add-Result "Migraciones" "RLS pedidos (028)" ($rls.Trim() -eq "t") "rls=$($rls.Trim())"
    $hor = docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT COUNT(*) FROM horarios_sucursal WHERE sucursal_id='$Sucursal'" 2>&1
    Add-Result "Migraciones" "Horarios sucursal (030)" ([int]$hor.Trim() -ge 7) "filas=$($hor.Trim())"
}
catch { Add-Result "Migraciones" "docker exec" $false $_.Exception.Message }

Write-Host ""
$results | Format-Table -AutoSize
$fail = ($results | Where-Object { $_.OK -eq "FALLO" }).Count
$ok = ($results | Where-Object { $_.OK -eq "OK" }).Count
Write-Host ""
Write-Host "Resumen: $ok OK, $fail FALLO"
Write-Host ""
if ($fail -gt 0) { exit 1 }
exit 0
