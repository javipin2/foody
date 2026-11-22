# API-HTTP-01/02/04 — creates 201 + conflictos 409 + codigos preservados.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== API-HTTP creates/conflictos ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal

# Static: ConflictException en caja/pedidos
$caja = Get-Content (Join-Path $PSScriptRoot '..\foody_backend\src\modulos\caja\caja.service.ts') -Raw
if ($caja -notmatch 'ConflictException' -or $caja -notmatch 'CAJA_YA_ABIERTA') {
  throw 'caja.service sin ConflictException CAJA_YA_ABIERTA'
}
$filter = Get-Content (Join-Path $PSScriptRoot '..\foody_backend\src\compartido\filtros\http-exception.filter.ts') -Raw
foreach ($c in @('CAJA_YA_CERRADA','PEDIDO_CERRADO','SIN_SALDO')) {
  if ($filter -notmatch [regex]::Escape($c)) { throw "filter sin preservar $c" }
}
Write-Host 'OK ConflictException + CODIGOS_ERROR_PRESERVAR' -ForegroundColor Green

# CAJA_YA_ABIERTA -> 409 si ya hay caja
$activa = Invoke-FoodyApi -Path "/caja/activa/$sid" -Headers $h
if ($activa.ok -and $activa.json.exito -and $activa.json.datos.id) {
  try {
    $body = @{ sucursal_id = $sid; monto_inicial = 0 } | ConvertTo-Json
    Invoke-WebRequest -Uri "$script:FoodyQaBase/caja/abrir" -Method POST -Headers @{ Authorization = $h.Authorization; 'Content-Type' = 'application/json' } -Body $body -UseBasicParsing | Out-Null
    throw 'esperaba 409 al reabrir caja'
  } catch {
    if ($_.Exception.Message -match 'esperaba 409') { throw }
    $code = [int]$_.Exception.Response.StatusCode
    $txt = [string]$_.ErrorDetails.Message
    if ($code -ne 409) { throw "reabrir caja status=$code body=$txt" }
    if ($txt -notmatch 'CAJA_YA_ABIERTA') { throw "sin CAJA_YA_ABIERTA: $txt" }
    Write-Host 'OK CAJA_YA_ABIERTA -> 409' -ForegroundColor Green
  }
} else {
  Write-Host 'AVISO: sin caja abierta; skip 409 reopen' -ForegroundColor Yellow
}

# Static: HttpCode CREATED en creates clave
$creates = @(
  'modulos\pedidos\pedidos-public.controller.ts',
  'modulos\pedidos\pedidos.controller.ts',
  'modulos\caja\caja.controller.ts',
  'modulos\usuarios\usuarios.controller.ts',
  'modulos\catalogo\productos.controller.ts'
)
$srcRoot = Join-Path $PSScriptRoot '..\foody_backend\src'
foreach ($rel in $creates) {
  $txt = Get-Content (Join-Path $srcRoot $rel) -Raw
  if ($txt -notmatch 'HttpCode\(HttpStatus\.CREATED\)') {
    throw "Sin @HttpCode(CREATED): $rel"
  }
  Write-Host "OK HttpCode CREATED $rel" -ForegroundColor Green
}

Write-Host 'API-HTTP OK' -ForegroundColor Green
