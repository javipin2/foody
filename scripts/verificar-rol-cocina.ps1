# Rol cocina + cocina_id + KDS filtrado por estación
# Uso: .\scripts\verificar-rol-cocina.ps1
# Pre: migración 069 aplicada + API con dist nuevo

$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'
$sid = 'c0000000-0000-4000-8000-000000000001'
$cocinaPrincipal = 'd0000000-0000-4000-8000-000000000001'

function Login-Staff {
  param([string]$Email, [string]$Pass = '123456')
  $body = @{ email = $Email; contrasena = $Pass } | ConvertTo-Json
  $r = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -Body $body -ContentType 'application/json'
  if (-not $r.exito) { throw $r.mensaje }
  return $r.datos
}

Write-Host '=== Rol cocina / KDS por estación ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Login-Staff 'admin@foody.demo'
$h = @{ Authorization = "Bearer $($admin.token)" }

$cat = Invoke-RestMethod -Uri "$base/usuarios/catalogo-roles" -Headers $h
$roles = @($cat.datos.roles | ForEach-Object { $_.rol })
if ($roles -notcontains 'cocina') { throw 'Catálogo sin rol cocina' }
Write-Host 'OK catalogo incluye cocina' -ForegroundColor Green

$cocinas = Invoke-RestMethod -Uri "$base/cocinas/$sid" -Headers $h
$listaC = @($cocinas.datos)
if ($listaC.Count -lt 1) { throw 'Sin cocinas en sede demo' }
$otra = $listaC | Where-Object { $_.id -ne $cocinaPrincipal } | Select-Object -First 1
$cocinaAsadosId = if ($otra) { $otra.id } else { $cocinaPrincipal }

$emailAsados = "qa-cocina-asados-$(Get-Date -Format 'HHmmss')@foody.test"
$crear = @{
  sucursal_id = $sid
  nombre      = 'QA Cocina Asados'
  email       = $emailAsados
  contrasena  = '123456'
  rol         = 'cocina'
  cocina_id   = $cocinaAsadosId
} | ConvertTo-Json
$nuevo = Invoke-RestMethod -Uri "$base/usuarios" -Method POST -Headers $h -Body $crear -ContentType 'application/json'
if (-not $nuevo.exito) { throw $nuevo.mensaje }
if ($nuevo.datos.rol -ne 'cocina') { throw 'Rol no es cocina' }
if ($nuevo.datos.cocina_id -ne $cocinaAsadosId) { throw 'cocina_id no guardado' }
Write-Host 'OK POST usuario rol cocina + estación' -ForegroundColor Green

# Sin cocina_id debe fallar
try {
  $bad = @{
    sucursal_id = $sid
    nombre      = 'QA Sin Cocina'
    email       = "qa-sin-cocina-$(Get-Date -Format 'HHmmss')@foody.test"
    contrasena  = '123456'
    rol         = 'cocina'
  } | ConvertTo-Json
  Invoke-RestMethod -Uri "$base/usuarios" -Method POST -Headers $h -Body $bad -ContentType 'application/json' | Out-Null
  throw 'Debió rechazar cocina sin estación'
} catch {
  if ($_.Exception.Message -match 'Debió') { throw }
  Write-Host 'OK rechaza cocina sin estación' -ForegroundColor Green
}

$demo = Login-Staff 'cocina@foody.demo'
if ($demo.dashboard -ne 'cocina') { throw 'dashboard demo != cocina' }
if (-not $demo.usuario.cocina_id) { throw 'demo sin cocina_id (¿migración 069?)' }
$hCocina = @{ Authorization = "Bearer $($demo.token)" }

$kds = Invoke-RestMethod -Uri "$base/cocina/cocinas" -Headers $hCocina
$visibles = @($kds.datos)
if ($visibles.Count -ne 1) { throw "KDS demo debe ver 1 cocina, vio $($visibles.Count)" }
if ($visibles[0].id -ne $demo.usuario.cocina_id) { throw 'KDS demo no coincide con cocina asignada' }
Write-Host "OK KDS demo solo ve su estación ($($visibles[0].nombre))" -ForegroundColor Green

# Intentar tickets de otra cocina → 403
if ($listaC.Count -ge 2) {
  $ajena = ($listaC | Where-Object { $_.id -ne $demo.usuario.cocina_id } | Select-Object -First 1).id
  try {
    Invoke-RestMethod -Uri "$base/cocina/tickets/$ajena" -Headers $hCocina | Out-Null
    throw 'Debió bloquear tickets de otra cocina'
  } catch {
    if ($_.Exception.Message -match 'Debió') { throw }
    Write-Host 'OK bloquea tickets de cocina ajena' -ForegroundColor Green
  }
}

# Usuario QA asados: solo su cocina
$qa = Login-Staff $emailAsados
$hQa = @{ Authorization = "Bearer $($qa.token)" }
$kdsQa = Invoke-RestMethod -Uri "$base/cocina/cocinas" -Headers $hQa
$visQa = @($kdsQa.datos)
if ($visQa.Count -ne 1 -or $visQa[0].id -ne $cocinaAsadosId) {
  throw 'QA asados no ve solo su estación'
}
Write-Host 'OK usuario QA asados filtrado' -ForegroundColor Green

# Cleanup: desactivar usuario QA
Invoke-RestMethod -Uri "$base/usuarios/$($nuevo.datos.id)/estado?sucursal_id=$sid" `
  -Method PATCH -Headers $h -Body (@{ activo = $false } | ConvertTo-Json) -ContentType 'application/json' | Out-Null

Write-Host '=== Rol cocina: OK ===' -ForegroundColor Cyan
