# CONC-INV-LOCK + INFRA-EXT-DOWN (smoke API) + sync SEC-BAC (F3)
# Uso: .\scripts\verificar-conc-inv-infra-down.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== CONC-INV-LOCK / INFRA-EXT-DOWN / SEC-BAC sync ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API salud fail' }
Write-Host 'OK salud (banner offline se oculta con API viva)'

# SEC-BAC-03 posesión
$devId = "qa-conc-anon-$(Get-Random)"
$null = Invoke-FoodyApi -Method POST -Path '/dispositivos/registrar' -Headers @{} -Body @{
  device_id  = $devId
  fcm_token  = 'tok-conc'
  plataforma = 'android'
}
$sin = Invoke-FoodyApi -Method DELETE -Path "/dispositivos/anonimizar/$devId" -Headers @{} -Body @{}
if ($sin.ok -and $sin.json.exito) { throw 'SEC-BAC-03: anonimizar sin posesión debio fallar' }
Write-Host 'OK SEC-BAC-03 rechazo sin posesion'

# SEC-BAC-04 prueba-web permisos
$mesero = Get-FoodyToken 'mesero@foody.com'
$pw = Invoke-FoodyApi -Method POST -Path '/notificaciones/prueba-web' -Headers $mesero.headers -Body @{}
if ($pw.ok -and $pw.json.exito) { throw 'SEC-BAC-04: mesero prueba-web debio 403' }
Write-Host "OK SEC-BAC-04 mesero bloqueado ($($pw.status))"

# CONC-INV-LOCK: ajuste stock con admin (FOR UPDATE en exigirIngrediente — smoke funcional)
$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal

function Sql-Scalar([string]$Sql) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $raw = docker exec supabase-db psql -U postgres -d postgres -t -A -c $Sql 2>$null
  $ErrorActionPreference = $prev
  return ($raw -as [string]).Trim()
}

$ing = Sql-Scalar "SELECT id::text FROM ingredientes WHERE sucursal_id='$sid' AND activo=true LIMIT 1"
if (-not $ing) { throw 'Sin ingrediente demo' }
$stockAntes = [double](Sql-Scalar "SELECT stock_actual::text FROM ingredientes WHERE id='$ing'")
$stockNuevo = [math]::Round($stockAntes + 0.001, 3)

$patch = Invoke-FoodyApi -Method PATCH -Path "/inventario/$ing" -Headers $h -Body @{
  stock_nuevo   = $stockNuevo
  motivo_ajuste = 'QA CONC-INV-LOCK'
}
if (-not ($patch.ok -and $patch.json.exito)) {
  throw "Ajuste stock: $($patch.status) $($patch.json.mensaje) $($patch.json.error)"
}
$stockDespues = [double](Sql-Scalar "SELECT stock_actual::text FROM ingredientes WHERE id='$ing'")
$null = Invoke-FoodyApi -Method PATCH -Path "/inventario/$ing" -Headers $h -Body @{
  stock_nuevo   = $stockAntes
  motivo_ajuste = 'QA CONC-INV-LOCK restore'
}
Write-Host "OK CONC-INV-LOCK ajuste ($stockAntes -> $stockDespues -> restore)"

Write-Host '=== OK ===' -ForegroundColor Green
