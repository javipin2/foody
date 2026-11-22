# Reconcilia ventas huérfanas y exceso en caja (demo/QA).
$ErrorActionPreference = 'Stop'
$sql = Join-Path $PSScriptRoot 'reconciliar-cuadre-demo.sql'
$sid = 'c0000000-0000-4000-8000-000000000001'

Write-Host '=== Reconciliar cuadre demo ===' -ForegroundColor Cyan

$antes = docker exec -i supabase-db psql -U postgres -d postgres -tAc "
SELECT COALESCE(SUM(m.monto),0) - COALESCE(SUM(p.monto_pagado),0)
FROM pedidos p
LEFT JOIN movimientos_caja m ON m.pedido_id = p.id AND m.tipo = 'venta'
WHERE p.sucursal_id = '$sid' AND p.estado NOT IN ('cancelado','rechazado');" 2>&1
Write-Host "Antes (caja ventas - monto_pagado acum): $antes" -ForegroundColor Gray

Get-Content $sql -Raw | docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 2>&1 | Out-Null

$exceso = docker exec -i supabase-db psql -U postgres -d postgres -tAc "
SELECT COUNT(*) FROM (
  SELECT p.id FROM pedidos p
  JOIN movimientos_caja m ON m.pedido_id = p.id AND m.tipo = 'venta'
  GROUP BY p.id, p.total
  HAVING SUM(m.monto) > p.total + 0.01
) x;" 2>&1
Write-Host "Pedidos con SUM(ventas) > total: $($exceso.Trim())" -ForegroundColor $(if ([int]$exceso.Trim() -eq 0) { 'Green' } else { 'Yellow' })

$despues = docker exec -i supabase-db psql -U postgres -d postgres -tAc "
SELECT ROUND(COALESCE((SELECT SUM(monto) FROM movimientos_caja WHERE sucursal_id='$sid' AND tipo='venta'),0)::numeric,2),
       ROUND(COALESCE((SELECT SUM(monto_pagado) FROM pedidos WHERE sucursal_id='$sid' AND estado NOT IN ('cancelado','rechazado')),0)::numeric,2);" 2>&1
$parts = $despues.Trim() -split '\|'
Write-Host "Despues: ventas_caja=$($parts[0]) | sum monto_pagado=$($parts[1])" -ForegroundColor Green
Write-Host 'OK reconciliar-cuadre-demo' -ForegroundColor Green
