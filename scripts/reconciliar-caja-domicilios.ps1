# Reconcilia movimientos de caja duplicados (domicilio creado + entregado).
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sql = Join-Path $PSScriptRoot 'reconciliar-caja-domicilios.sql'

Write-Host 'Antes:' -ForegroundColor Cyan
Get-Content $sql -Raw | docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "
SELECT p.numero_pedido, p.total, COALESCE(SUM(m.monto),0) suma_ventas
FROM pedidos p
LEFT JOIN movimientos_caja m ON m.pedido_id=p.id AND m.tipo='venta'
GROUP BY p.id, p.numero_pedido, p.total
HAVING COALESCE(SUM(m.monto),0) > p.total + 0.01
ORDER BY p.numero_pedido;" 2>&1

Write-Host "`nAplicando reconciliacion..." -ForegroundColor Cyan
Get-Content $sql -Raw | docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 2>&1

Write-Host "`nDespues:" -ForegroundColor Cyan
docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "
SELECT COUNT(*) AS pedidos_con_exceso FROM (
  SELECT p.id
  FROM pedidos p
  LEFT JOIN movimientos_caja m ON m.pedido_id=p.id AND m.tipo='venta'
  GROUP BY p.id, p.total
  HAVING COALESCE(SUM(m.monto),0) > p.total + 0.01
) x;" 2>&1

Write-Host 'OK reconciliar-caja-domicilios' -ForegroundColor Green
