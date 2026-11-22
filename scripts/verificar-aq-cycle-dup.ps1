# AQ-CYCLE / AQ-DUP / DASH-CONS-COMP smoke
# Uso: .\scripts\verificar-aq-cycle-dup.ps1
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

Write-Host '=== AQ-CYCLE / AQ-DUP / DASH labels ===' -ForegroundColor Cyan

$canon = @(
  'lib\core\tema\analitica_tokens.dart',
  'lib\features\pedidos\data\pedidos_repository.dart',
  'lib\features\pedidos\domain\pedido_admin_model.dart'
)
foreach ($rel in $canon) {
  $p = Join-Path $Root $rel
  if (-not (Test-Path $p)) { throw "Falta canonico: $rel" }
  Write-Host "OK $rel"
}

$shim = Get-Content (Join-Path $Root 'lib\features\analitica\presentation\widgets\analitica_tokens.dart') -Raw
if ($shim -notmatch 'core/tema/analitica_tokens') { throw 'Shim AnaliticaTokens roto' }
Write-Host 'OK shim analitica_tokens'

$shimPed = Get-Content (Join-Path $Root 'lib\features\admin\data\pedidos_repository.dart') -Raw
if ($shimPed -notmatch 'pedidos/data/pedidos_repository') { throw 'Shim PedidosRepository roto' }
Write-Host 'OK shim pedidos_repository'

$dash = Get-Content (Join-Path $Root 'lib\features\admin\presentation\widgets\dashboard_resumen_widget.dart') -Raw
if ($dash -notmatch "Cerrados hoy") { throw 'DASH-CONS-COMP: falta etiqueta Cerrados hoy' }
Write-Host 'OK DASH-CONS-COMP etiqueta'

Write-Host '=== OK ===' -ForegroundColor Green
