# Verifica modulo FCM (diagnostico + push de prueba)
# Uso: .\scripts\verificar-fcm.ps1

$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'

function Login-Staff {
  param([string]$Email, [string]$Pass = '123456')
  $body = @{ email = $Email; contrasena = $Pass } | ConvertTo-Json
  $r = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -Body $body -ContentType 'application/json'
  if (-not $r.exito) { throw $r.mensaje }
  return $r.datos
}

Write-Host '=== Verificar FCM ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Login-Staff 'admin@foody.demo'
$h = @{ Authorization = "Bearer $($admin.token)" }

$diag = Invoke-RestMethod -Uri "$base/notificaciones/diagnostico" -Headers $h
Write-Host 'Diagnostico FCM:' -ForegroundColor Yellow
Write-Host "  firebase_admin = $($diag.datos.firebase_admin)"
Write-Host "  pendientes     = $($diag.datos.pendientes)"

if (-not $diag.datos.firebase_admin) {
  Write-Host ''
  Write-Host 'AVISO: Firebase Admin NO inicializado.' -ForegroundColor Yellow
  Write-Host 'Define FIREBASE_SERVICE_ACCOUNT_PATH en foody_backend/.env y reinicia.' -ForegroundColor Yellow
}

$prueba = Invoke-RestMethod -Uri "$base/notificaciones/prueba" -Method POST -Headers $h
Write-Host "Push prueba encolado: procesadas=$($prueba.datos.procesadas) enviados=$($prueba.datos.enviados) modo=$($prueba.datos.modo)" -ForegroundColor Green

if ($diag.datos.tokens_web_staff -gt 0 -or $diag.datos.tokens_web_cliente -gt 0) {
  $web = Invoke-RestMethod -Uri "$base/notificaciones/prueba-web" -Method POST -Headers $h -ContentType 'application/json' -Body '{}'
  Write-Host "Push prueba WEB: enviados=$($web.datos.enviados) tokens_web=$($web.datos.tokens_web) fallos=$($web.datos.fallos)" -ForegroundColor Green
}
else {
  Write-Host 'Sin tokens web - abre Foody en Chrome y acepta notificaciones' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Verificacion FCM OK' -ForegroundColor Green
