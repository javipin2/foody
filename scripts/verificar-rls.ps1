# Verifica RLS exhaustivo en Postgres (P0-08)
# Uso: .\scripts\verificar-rls.ps1
# Requiere: Docker + contenedor supabase-db

param(
    [string]$Container = 'supabase-db'
)

$ErrorActionPreference = 'Stop'

Write-Host '=== Verificar RLS PostgreSQL (P0-08) ===' -ForegroundColor Cyan

$db = docker exec $Container psql -U postgres -d postgres -tAc "SELECT 1" 2>&1
if ($db -notmatch '1') {
    Write-Host "FALLO: contenedor $Container no responde" -ForegroundColor Red
    exit 1
}
Write-Host "OK Postgres $Container" -ForegroundColor Green

$sqlSinRls = @"
SELECT c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND NOT c.relrowsecurity
ORDER BY 1;
"@

$sinRls = @(docker exec $Container psql -U postgres -d postgres -tAc $sqlSinRls | Where-Object { $_.Trim() })
if ($sinRls.Count -gt 0) {
    Write-Host "FALLO: tablas sin RLS ($($sinRls.Count)):" -ForegroundColor Red
    $sinRls | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'OK todas las tablas public tienen RLS habilitado' -ForegroundColor Green

$sqlSinForce = @"
SELECT c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relrowsecurity
  AND NOT c.relforcerowsecurity
ORDER BY 1;
"@

$sinForce = @(docker exec $Container psql -U postgres -d postgres -tAc $sqlSinForce | Where-Object { $_.Trim() })
if ($sinForce.Count -gt 0) {
    Write-Host "FALLO: tablas con RLS pero sin FORCE ($($sinForce.Count)):" -ForegroundColor Red
    $sinForce | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'OK todas las tablas public tienen FORCE ROW LEVEL SECURITY' -ForegroundColor Green

$total = docker exec $Container psql -U postgres -d postgres -tAc @"
SELECT COUNT(*)::text
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r';
"@
Write-Host "Tablas public con RLS+FORCE: $($total.Trim())" -ForegroundColor DarkGray

function Test-RlsForce {
    param([string]$Valor)
    $v = $Valor.Trim().ToLower()
    return ($v -eq 't,t' -or $v -eq 'true,true')
}

# Spot-check: pedidos y pagos_pedido
$ped = docker exec $Container psql -U postgres -d postgres -tAc @"
SELECT relrowsecurity::text || ',' || relforcerowsecurity::text
FROM pg_class WHERE relname = 'pedidos' AND relkind = 'r';
"@
if (-not (Test-RlsForce $ped)) {
    Write-Host "FALLO: pedidos RLS=$($ped.Trim())" -ForegroundColor Red
    exit 1
}
Write-Host 'OK spot-check pedidos (rls+force)' -ForegroundColor Green

$pag = docker exec $Container psql -U postgres -d postgres -tAc @"
SELECT relrowsecurity::text || ',' || relforcerowsecurity::text
FROM pg_class WHERE relname = 'pagos_pedido' AND relkind = 'r';
"@
if (-not (Test-RlsForce $pag)) {
    Write-Host "FALLO: pagos_pedido RLS=$($pag.Trim()) (aplica migr.064)" -ForegroundColor Red
    exit 1
}
Write-Host 'OK spot-check pagos_pedido (rls+force)' -ForegroundColor Green

Write-Host ''
Write-Host 'Verificacion RLS OK' -ForegroundColor Green
exit 0
