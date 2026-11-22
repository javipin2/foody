# F6 — Perf turno: indices caja + paginacion movimientos + DASH-TZ
# Uso: .\scripts\verificar-f6-perf.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar F6 perf turno ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal
$script:fallos = 0

function Assert-Ok {
    param([bool]$Cond, [string]$Msg)
    if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
    else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

function Sql-Scalar([string]$Sql) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $raw = docker exec supabase-db psql -U postgres -d postgres -t -A -c $Sql 2>$null
    $ErrorActionPreference = $prev
    return ($raw -as [string]).Trim()
}

Write-Host ''
Write-Host '--- A Indices BD ---' -ForegroundColor Yellow
$ixCajas = Sql-Scalar "SELECT COUNT(*) FROM pg_indexes WHERE tablename='cajas' AND indexname='idx_cajas_sucursal_estado'"
$ixMovCaja = Sql-Scalar "SELECT COUNT(*) FROM pg_indexes WHERE tablename='movimientos_caja' AND indexname='idx_movimientos_caja_caja_id'"
$ixMovSuc = Sql-Scalar "SELECT COUNT(*) FROM pg_indexes WHERE tablename='movimientos_caja' AND indexname='idx_movimientos_caja_sucursal_created'"
Assert-Ok -Cond ([int]$ixCajas -ge 1) -Msg 'idx_cajas_sucursal_estado'
Assert-Ok -Cond ([int]$ixMovCaja -ge 1) -Msg 'idx_movimientos_caja_caja_id'
Assert-Ok -Cond ([int]$ixMovSuc -ge 1) -Msg 'idx_movimientos_caja_sucursal_created'

Write-Host ''
Write-Host '--- B Paginacion movimientos ---' -ForegroundColor Yellow
$null = Ensure-CajaAbierta -Headers $h
$caja = Invoke-FoodyApi -Path "/caja/activa/$sid" -Headers $h
$cajaId = $caja.json.datos.id
Assert-Ok -Cond ($null -ne $cajaId) -Msg "Caja activa $cajaId"

$mov = Invoke-FoodyApi -Path "/caja/$cajaId/movimientos?page=1&limit=5" -Headers $h
Assert-Ok -Cond ($mov.ok -and $mov.json.exito) -Msg 'GET movimientos paginado'
$d = $mov.json.datos
Assert-Ok -Cond ($null -ne $d.items) -Msg 'datos.items presente'
Assert-Ok -Cond ($null -ne $d.total -and $null -ne $d.page -and $null -ne $d.limit) -Msg "meta total=$($d.total) page=$($d.page) limit=$($d.limit)"
Assert-Ok -Cond ([int]$d.limit -le 5) -Msg "limit respetado ($($d.limit))"

Write-Host ''
Write-Host '--- C DASH-TZ codigo ---' -ForegroundColor Yellow
$dashSrc = Get-Content -Raw "$PSScriptRoot\..\foody_backend\src\modulos\dashboard\dashboard.service.ts"
Assert-Ok -Cond ($dashSrc -notmatch 'created_at::date') -Msg 'Sin created_at::date crudo'
Assert-Ok -Cond ($dashSrc -match "created_at AT TIME ZONE 'America/Bogota'") -Msg 'Usa AT TIME ZONE Bogota'

$res = Invoke-FoodyApi -Path "/dashboard/resumen?sucursal_id=$sid" -Headers $h
Assert-Ok -Cond ($res.ok -and $res.json.exito) -Msg 'GET dashboard/resumen'
Assert-Ok -Cond ($null -ne $res.json.datos.ventas_hoy) -Msg "ventas_hoy=$($res.json.datos.ventas_hoy)"

Write-Host ''
if ($script:fallos -gt 0) {
    Write-Host "F6 FALLA ($script:fallos)" -ForegroundColor Red
    exit 1
}
Write-Host 'F6 perf OK' -ForegroundColor Green
exit 0
