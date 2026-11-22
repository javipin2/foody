# PERF-CACHE + API-VAL residual
# Uso: .\scripts\verificar-perf-cache-api-val.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== PERF-CACHE / API-VAL ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API salud fail' }

# PERF-CACHE-02: GET /ciudades dos veces (cache hit no cambia datos)
$c1 = Invoke-FoodyApi -Path '/ciudades' -Headers @{}
$c2 = Invoke-FoodyApi -Path '/ciudades' -Headers @{}
if (-not ($c1.ok -and $c1.json.exito -and $c2.ok -and $c2.json.exito)) {
  throw 'GET /ciudades fallo'
}
$n1 = @($c1.json.datos).Count
$n2 = @($c2.json.datos).Count
if ($n1 -lt 1 -or $n1 -ne $n2) { throw "ciudades count $n1 vs $n2" }
Write-Host "OK ciudades cache-friendly ($n1)"

$slug = [string]$c1.json.datos[0].slug
$r1 = Invoke-FoodyApi -Path "/ciudades/$slug/restaurantes" -Headers @{}
$r2 = Invoke-FoodyApi -Path "/ciudades/$slug/restaurantes" -Headers @{}
if (-not ($r1.ok -and $r1.json.exito -and $r2.ok -and $r2.json.exito)) {
  throw "restaurantes ciudad $slug"
}
Write-Host "OK restaurantes por slug ($slug)"

# PERF-CACHE-03 + PERF-SQL-03 smoke: dashboard
$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal
$d1 = Invoke-FoodyApi -Path "/dashboard/resumen?sucursal_id=$sid" -Headers $h
$d2 = Invoke-FoodyApi -Path "/dashboard/resumen?sucursal_id=$sid" -Headers $h
if (-not ($d1.ok -and $d1.json.exito -and $d2.ok -and $d2.json.exito)) {
  throw "dashboard resumen $($d1.status) $($d1.json.mensaje)"
}
$g = Invoke-FoodyApi -Path "/dashboard/graficos?sucursal_id=$sid" -Headers $h
if (-not ($g.ok -and $g.json.exito)) { throw "dashboard graficos: $($g.json.mensaje)" }
$top = $g.json.datos.top_productos_7d
Write-Host "OK dashboard resumen+graficos (top=$(@($top).Count))"

# API-VAL-02: UUID basura → 400
$badRest = Invoke-FoodyApi -Path '/restaurantes/no-es-uuid/sucursales' -Headers @{}
if ($badRest.ok -and $badRest.json.exito) { throw 'UUID invalido restaurantes debio fallar' }
Write-Host "OK ParseUUID restaurantes ($($badRest.status))"

$badFact = Invoke-FoodyApi -Method POST -Path '/facturacion/emitir/not-a-uuid' -Headers $h
if ($badFact.ok -and $badFact.json.exito) { throw 'UUID invalido emitir debio fallar' }
Write-Host "OK ParseUUID facturacion emitir ($($badFact.status))"

Write-Host '=== OK ===' -ForegroundColor Green
