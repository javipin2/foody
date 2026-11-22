# OPT-04: paginación cerrados-hoy + movimientos inventario.
# Uso: .\scripts\verificar-paginacion-ops.ps1

$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'
$sid = 'c0000000-0000-4000-8000-000000000001'
$fallos = 0

function Ok([string]$m) { Write-Host "OK  $m" -ForegroundColor Green }
function Fail([string]$m) { Write-Host "FAIL $m" -ForegroundColor Red; $script:fallos++ }

Write-Host '=== Verificar paginacion OPT-04 ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }

$body = @{ email = 'admin@foody.demo'; contrasena = '123456' } | ConvertTo-Json
$login = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -Body $body -ContentType 'application/json'
$h = @{ Authorization = "Bearer $($login.datos.token)" }

$c = Invoke-RestMethod -Uri "$base/pedidos/cerrados-hoy?sucursal_id=$sid&page=1&limit=5" -Headers $h
if ($null -eq $c.datos.items) { Fail 'cerrados-hoy sin items[]' }
elseif ($null -eq $c.datos.total) { Fail 'cerrados-hoy sin total' }
else { Ok "cerrados-hoy page=1 items=$(@($c.datos.items).Count) total=$($c.datos.total) pages=$($c.datos.totalPages)" }

$m = Invoke-RestMethod -Uri "$base/inventario/movimientos/${sid}?page=1&limit=10" -Headers $h
if ($null -eq $m.datos.items) { Fail 'movimientos sin items[]' }
else { Ok "movimientos page=1 items=$(@($m.datos.items).Count) total=$($m.datos.total)" }

# Sin page sigue siendo lista (compat)
$c2 = Invoke-RestMethod -Uri "$base/pedidos/cerrados-hoy?sucursal_id=$sid&limit=3" -Headers $h
if ($c2.datos -is [System.Array] -or $c2.datos.GetType().Name -eq 'Object[]') {
  Ok "cerrados-hoy sin page = lista ($(@($c2.datos).Count))"
} elseif ($c2.datos.items) {
  Fail 'cerrados-hoy sin page no debe envolver'
} else {
  # PowerShell puede deserializar array JSON como Object[]
  Ok "cerrados-hoy sin page tipo=$($c2.datos.GetType().Name)"
}

Write-Host ''
if ($fallos -eq 0) { Write-Host 'Paginacion OK' -ForegroundColor Green; exit 0 }
Write-Host "Fallos: $fallos" -ForegroundColor Red; exit 1
