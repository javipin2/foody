# Verifica lote abiertos: FUZZ-LEN-01, SEC-BAC-06.
# Uso: .\scripts\verificar-lote-purpura-abiertos.ps1
$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'
$sid = 'c0000000-0000-4000-8000-000000000001'

function Login($email) {
  $body = @{ email = $email; contrasena = '123456' } | ConvertTo-Json
  $r = Invoke-RestMethod -Method POST -Uri "$base/auth/login" -ContentType 'application/json' -Body $body
  if (-not $r.exito) { throw "login fail $email" }
  return $r.datos
}

function Invoke-ExpectStatus {
  param([string]$Method, [string]$Url, [hashtable]$Headers, [string]$Body, [int]$Expect)
  try {
    Invoke-WebRequest -Method $Method -Uri $Url -Headers $Headers -ContentType 'application/json' -Body $Body -UseBasicParsing | Out-Null
    throw "esperaba $Expect, obtuvo 2xx"
  } catch {
    if ($_.Exception.Response) {
      $code = [int]$_.Exception.Response.StatusCode
      if ($code -ne $Expect) { throw "esperaba $Expect, obtuvo $code" }
      return
    }
    throw
  }
}

Write-Host '=== Lote abiertos (FUZZ / SEC-BAC-06) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod "$base/salud"
if (-not $salud.exito) { throw 'API salud fail' }
Write-Host 'OK salud'

$admin = Login 'admin@foody.demo'
$h = @{ Authorization = "Bearer $($admin.token)" }
$nombreLargo = 'x' * 5000
$bodyMesa = @{ sucursal_id = $sid; nombre = $nombreLargo } | ConvertTo-Json
Invoke-ExpectStatus -Method POST -Url "$base/mesas" -Headers $h -Body $bodyMesa -Expect 400
Write-Host 'OK FUZZ-LEN-01 (nombre 5k => 400)'

$permisos = @($admin.permisos)
if ($permisos -notcontains 'gestionar_finanzas') {
  throw 'admin sin gestionar_finanzas (mig 087 + re-login)'
}
Write-Host 'OK admin tiene gestionar_finanzas'

$cajero = Login 'cajero.test@foody.demo'
$hC = @{ Authorization = "Bearer $($cajero.token)" }
$bodyGasto = @{
  sucursal_id = $sid
  concepto = 'test-sec-bac-06'
  monto = 1000
  categoria = 'otro'
} | ConvertTo-Json
Invoke-ExpectStatus -Method POST -Url "$base/finanzas/gastos" -Headers $hC -Body $bodyGasto -Expect 403
Write-Host 'OK SEC-BAC-06 (cajero POST gasto => 403)'

$r = Invoke-RestMethod -Method POST -Uri "$base/finanzas/gastos" -Headers $h -ContentType 'application/json' -Body $bodyGasto
if (-not $r.exito) { throw 'admin gasto fail' }
Write-Host 'OK admin POST gasto con gestionar_finanzas'

Write-Host '=== Lote: OK ===' -ForegroundColor Green
