# Foody — verificación self-service F1–F4
# Uso: powershell -File scripts/verificar-self-service.ps1
$ErrorActionPreference = "Continue"
$Base = "http://localhost:3000/api/v1"

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

$results = @()
function Add-Result($test, $ok, $detail) {
    $script:results += [PSCustomObject]@{ Test = $test; OK = if ($ok) { "OK" } else { "FALLO" }; Detalle = $detail }
}

Write-Host "`n=== Verificación self-service ===`n"

# Salud
$s = Invoke-Api -Path "/salud"
Add-Result "GET /salud" ($s.ok -and $s.status -eq 200) "status=$($s.status)"

# Registro restaurante
$ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$email = "qa-self-$ts@foody.test"
$reg = Invoke-Api -Method POST -Path "/auth/registro-restaurante" -Body @{
    ciudad_id          = "a0000000-0000-4000-8000-000000000001"
    nombre_restaurante = "QA Self $ts"
    admin_nombre       = "Dueño QA"
    admin_email        = $email
    contrasena         = "test123456"
}
$okReg = $reg.ok -and $reg.json.exito -eq $true -and $reg.json.datos.plan -eq "gratis"
Add-Result "POST /auth/registro-restaurante" $okReg "plan=$($reg.json.datos.plan) estado=$($reg.json.datos.onboarding.suscripcion.estado)"

$token = $reg.json.datos.token
$restId = $reg.json.datos.onboarding.restaurante_id

# Perfil con suscripción
if ($token) {
    $perfil = Invoke-Api -Path "/auth/perfil" -Headers @{ Authorization = "Bearer $token" }
    $okPerfil = $perfil.ok -and $perfil.json.datos.suscripcion.plan -eq "gratis"
    Add-Result "GET /auth/perfil (suscripcion)" $okPerfil "plan=$($perfil.json.datos.suscripcion.plan)"
}

# Login correo
$login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = $email; contrasena = "test123456"
}
Add-Result "Login post-registro" ($login.ok -and $login.json.exito) "rol=$($login.json.datos.rol)"

# Google token inválido
$g = Invoke-Api -Method POST -Path "/auth/login-google" -Body @{ access_token = "token-invalido-de-prueba" }
Add-Result "login-google rechaza token inválido" ($g.status -eq 401 -or -not $g.json.exito) "status=$($g.status)"

# BD: origen self_service
$db = docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT origen, plan, estado FROM restaurantes r JOIN suscripciones_restaurante s ON s.restaurante_id = r.id WHERE r.id = '$restId';" 2>&1
Add-Result "BD origen self_service + plan gratis" ($db -match "self_service") $db.ToString().Trim()

# Columnas avisos F4
$cols = docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='suscripciones_restaurante' AND column_name IN ('aviso_3d_enviado_at','aviso_vence_hoy_enviado_at');" 2>&1
Add-Result "Migración 053 columnas avisos" ($cols.Trim() -eq "2") "cols=$cols"

# F5 checkout Wompi (requiere llaves en foody_backend/.env)
if ($token) {
    $chk = Invoke-Api -Method POST -Path "/pagos/checkout" -Headers @{ Authorization = "Bearer $token" } -Body @{ plan = "basico" }
    $url = $chk.json.datos.checkout_url
    $okChk = $chk.ok -and $chk.json.exito -eq $true -and $url -match "checkout\.wompi\.co/l/"
    Add-Result "POST /pagos/checkout (Wompi)" $okChk $(if ($okChk) { "url=$url" } else { "status=$($chk.status) $($chk.json.mensaje)" })
}

$results | Format-Table -AutoSize
$fallos = @($results | Where-Object { $_.OK -eq "FALLO" }).Count
if ($fallos -gt 0) { exit 1 }
Write-Host "`nTodo OK ($($results.Count) pruebas)`n"
