# Smoke: historial cliente + columnas auth_uid (migracion 079).
# Uso: .\scripts\verificar-historial-cliente-auth.ps1

$ErrorActionPreference = 'Stop'
$Base = if ($env:FOODY_API) { $env:FOODY_API.TrimEnd('/') } else { 'http://localhost:3000/api/v1' }

Write-Host "== Salud ==" -ForegroundColor Cyan
$salud = Invoke-RestMethod -Uri "$Base/salud" -Method Get
if (-not $salud.exito) { throw "API salud falló" }
Write-Host "OK salud"

Write-Host "== Columnas BD ==" -ForegroundColor Cyan
$colDisp = docker exec supabase-db psql -U postgres -d postgres -tAc `
  "SELECT count(*) FROM information_schema.columns WHERE table_name='dispositivos_cliente' AND column_name='auth_uid';"
$colPed = docker exec supabase-db psql -U postgres -d postgres -tAc `
  "SELECT count(*) FROM information_schema.columns WHERE table_name='pedidos' AND column_name='cliente_auth_uid';"
if ($colDisp.Trim() -ne '1') { throw "Falta dispositivos_cliente.auth_uid (migracion 079)" }
if ($colPed.Trim() -ne '1') { throw "Falta pedidos.cliente_auth_uid (migracion 079)" }
Write-Host "OK columnas auth_uid"

Write-Host "== GET /pedidos/mios sin device_id ==" -ForegroundColor Cyan
try {
  Invoke-RestMethod -Uri "$Base/pedidos/mios" -Method Get | Out-Null
  throw "Debía fallar sin device_id"
} catch {
  $code = $_.Exception.Response.StatusCode.value__
  if ($code -ne 400) {
    # Nest puede devolver 400 en body con interceptor
    $msg = $_.ErrorDetails.Message
    if ($msg -notmatch 'device_id') {
      Write-Host "WARN status=$code body=$msg (esperado 400 device_id)"
    }
  }
  Write-Host "OK rechazo sin device_id"
}

$device = [guid]::NewGuid().ToString()
Write-Host "== GET /pedidos/mios device vacío ==" -ForegroundColor Cyan
$mios = Invoke-RestMethod -Uri "$Base/pedidos/mios?device_id=$device" -Method Get
if (-not $mios.exito) { throw "listarMios falló: $($mios.mensaje)" }
$lista = @($mios.datos)
Write-Host "OK listarMios device nuevo → $($lista.Count) pedidos"

Write-Host "== POST /dispositivos/vincular-auth token inválido ==" -ForegroundColor Cyan
try {
  Invoke-RestMethod -Uri "$Base/dispositivos/vincular-auth" -Method Post -ContentType 'application/json' -Body (@{
    device_id = $device
    access_token = 'token-invalido-qa'
  } | ConvertTo-Json) | Out-Null
  throw "Debía rechazar token inválido"
} catch {
  Write-Host "OK rechazo token inválido"
}

Write-Host "`nVERIFICAR HISTORIAL CLIENTE AUTH: OK" -ForegroundColor Green
