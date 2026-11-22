# F3 - Confianza Foody: CFG-GLOBAL, HUER-PERM, RBAC-GUARD anonimizar/prueba-web
# Uso: .\scripts\verificar-f3-confianza.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar F3 confianza Foody ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$mesero = Get-FoodyToken 'mesero@foody.com'
$h = $admin.headers
$hm = $mesero.headers
$sid = $script:FoodyQaSucursal
$script:fallos = 0

function Assert-Ok {
    param([bool]$Cond, [string]$Msg)
    if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
    else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

function Sql-Scalar([string]$Sql) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $raw = docker exec supabase-db psql -U postgres -d postgres -t -A -c $Sql 2>$null
    $ErrorActionPreference = $prev
    return ($raw -as [string]).Trim()
}

# --- A) Anonimizar sin prueba ---
Write-Host ''
Write-Host '--- A RBAC-GUARD anonimizar ---' -ForegroundColor Yellow
$devId = "qa-f3-anon-$(Get-Random)"
$null = Invoke-FoodyApi -Method POST -Path '/dispositivos/registrar' -Headers @{} -Body @{
    device_id  = $devId
    fcm_token  = 'token-secreto-f3'
    plataforma = 'android'
}
$sinPrueba = Invoke-FoodyApi -Method DELETE -Path "/dispositivos/anonimizar/$devId" -Headers @{} -Body @{}
Assert-Ok -Cond ((-not $sinPrueba.ok) -or (-not $sinPrueba.json.exito)) -Msg 'Anonimizar sin prueba rechazado'
Write-Host "    err=$($sinPrueba.json.error)" -ForegroundColor DarkGray

$conPrueba = Invoke-FoodyApi -Method DELETE -Path "/dispositivos/anonimizar/${devId}?fcm_token=token-secreto-f3" -Headers @{}
Assert-Ok -Cond ($conPrueba.ok -and $conPrueba.json.exito -and $conPrueba.json.datos.anonimizado -eq $true) -Msg 'Anonimizar con fcm_token OK'

# --- B) prueba-web mesero ---
Write-Host ''
Write-Host '--- B RBAC-GUARD prueba-web ---' -ForegroundColor Yellow
$pwMesero = Invoke-FoodyApi -Method POST -Path '/notificaciones/prueba-web' -Headers $hm -Body @{}
Assert-Ok -Cond ((-not $pwMesero.ok) -or (-not $pwMesero.json.exito)) -Msg 'Mesero prueba-web rechazado'
Write-Host "    status=$($pwMesero.status)" -ForegroundColor DarkGray

$pwAdmin = Invoke-FoodyApi -Method POST -Path '/notificaciones/prueba-web' -Headers $h -Body @{}
Assert-Ok -Cond ($pwAdmin.ok -and $pwAdmin.json.exito) -Msg 'Admin prueba-web permitido (tokens propios o cero)'
$modo = "$($pwAdmin.json.datos.enviados)"
Write-Host "    enviados=$modo msg=$($pwAdmin.json.datos.mensaje)" -ForegroundColor DarkGray

# --- C) CFG-GLOBAL cableado (cuadre) ---
Write-Host ''
Write-Host '--- C CFG-GLOBAL umbrales ---' -ForegroundColor Yellow
$clave = 'umbral_alerta_cuadre_caja'
$antes = Sql-Scalar "SELECT valor FROM configuracion_global_foody WHERE clave='$clave'"
Assert-Ok -Cond ($antes -ne '') -Msg "Clave $clave existe ($antes)"

# Sin super token facil: verificar que UMBRALES se leen al boot via analitica riesgo umbrales
$riesgo = Invoke-FoodyApi -Path "/analitica/riesgo?sucursal_id=$sid&preset=7d" -Headers $h
Assert-Ok -Cond ($riesgo.ok -and $riesgo.json.exito) -Msg 'GET analitica/riesgo'
$umb = $riesgo.json.datos.umbrales
if ($null -eq $umb) { $umb = $riesgo.json.datos.umbrales_alerta }
$cuadre = $null
if ($umb) { $cuadre = $umb.cuadreCajaCOP }
if ($null -eq $cuadre -and $umb) { $cuadre = $umb.cuadre_caja_cop }
Assert-Ok -Cond ($null -ne $cuadre) -Msg "Umbral cuadre expuesto en riesgo ($cuadre)"
Assert-Ok -Cond ([double]$cuadre -eq [double]$antes) -Msg "Runtime cuadre=$cuadre == BD=$antes"

# --- D) HUER-PERM rentabilidad API ---
Write-Host ''
Write-Host '--- D HUER-PERM rentabilidad ---' -ForegroundColor Yellow
$rentMesero = Invoke-FoodyApi -Path "/analitica/rentabilidad?sucursal_id=$sid&preset=7d" -Headers $hm
Assert-Ok -Cond ((-not $rentMesero.ok) -or (-not $rentMesero.json.exito)) -Msg 'Mesero rentabilidad 403'
$rentAdmin = Invoke-FoodyApi -Path "/analitica/rentabilidad?sucursal_id=$sid&preset=7d" -Headers $h
Assert-Ok -Cond ($rentAdmin.ok -and $rentAdmin.json.exito) -Msg 'Admin rentabilidad OK'

Write-Host ''
if ($script:fallos -gt 0) {
    Write-Host "FALLOS: $($script:fallos)" -ForegroundColor Red
    exit 1
}
Write-Host 'F3 confianza OK' -ForegroundColor Green
exit 0
