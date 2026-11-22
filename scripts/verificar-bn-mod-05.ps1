# BN-MOD-05 — SQL ventas unificado (reportes / analitica / dashboard).
# Comprueba imports + coherencia de cifras vía script existente.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root 'foody_backend\src'
$shared = 'compartido/sql/ventas-metricas.sql.ts'

$archivos = @(
  'modulos\reportes\reportes.service.ts',
  'modulos\dashboard\dashboard.service.ts',
  'modulos\analitica\analitica.service.ts',
  'modulos\analitica\analitica-filtros.util.ts',
  'modulos\analitica\analitica-sql.const.ts'
)

Write-Host '=== BN-MOD-05 ventas SQL unificado ===' -ForegroundColor Cyan

$sharedPath = Join-Path $src ($shared -replace '/', '\')
if (-not (Test-Path $sharedPath)) { throw "Falta $shared" }
Write-Host "OK fuente $shared" -ForegroundColor Green

foreach ($rel in $archivos) {
  $path = Join-Path $src $rel
  $txt = Get-Content -Raw -Path $path
  if ($txt -notmatch 'ventas-metricas\.sql') {
    throw "Sin import ventas-metricas: $rel"
  }
  Write-Host "OK import $rel" -ForegroundColor Green
}

# Literales viejos no deben quedar en reportes/dashboard (sí pueden en comentarios)
foreach ($rel in @('modulos\reportes\reportes.service.ts', 'modulos\dashboard\dashboard.service.ts')) {
  $txt = Get-Content -Raw -Path (Join-Path $src $rel)
  if ($txt -match "estado NOT IN \('cancelado', 'rechazado'\)") {
    throw "Literal estado NOT IN aun en $rel - debe usar SQL_PEDIDOS_VALIDOS"
  }
  if ($txt -match "America/Bogota") {
    throw "Literal America/Bogota aun en $rel - debe usar SQL_TZ_NEGOCIO"
  }
  Write-Host "OK sin literales duplicados $rel" -ForegroundColor Green
}

Write-Host ''
& "$PSScriptRoot\verificar-coherencia-pedidos-analitica.ps1"
if (-not $?) { throw 'coherencia fallo' }

Write-Host ''
Write-Host 'BN-MOD-05 OK' -ForegroundColor Green
