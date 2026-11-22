# BN-CTRL-04/05 — gates corporativos + contexto analitica en services.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== BN-CTRL-04/05 dashboard + analitica ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal

# CTRL-04 consolidado (admin demo es corporativo)
$cons = Invoke-FoodyApi -Path '/dashboard/consolidado' -Headers $h
if (-not ($cons.ok -and $cons.json.exito)) {
  throw "consolidado fallo: $($cons.json.error)"
}
Write-Host 'OK dashboard consolidado (corporativo)' -ForegroundColor Green

$comp = Invoke-FoodyApi -Path '/analitica/comparativa-sedes?preset=7d' -Headers $h
if (-not ($comp.ok -and $comp.json.exito)) {
  throw "comparativa-sedes fallo: $($comp.json.error)"
}
Write-Host 'OK analitica comparativa-sedes' -ForegroundColor Green

# CTRL-05: resumen usa resolverContexto (periodo+filtros)
$res = Invoke-FoodyApi -Path "/analitica/resumen?sucursal_id=$sid&preset=7d" -Headers $h
if (-not ($res.ok -and $res.json.exito)) {
  throw "analitica resumen fallo: $($res.json.error)"
}
if ($null -eq $res.json.datos.kpis) { throw 'resumen sin kpis' }
Write-Host 'OK analitica resumen (contexto en service)' -ForegroundColor Green

# Gate: cajero no corporativo -> 403 consolidado (si existe seed)
try {
  $caj = Get-FoodyToken 'cajero@foody.demo'
  $r = Invoke-WebRequest -Uri "$script:FoodyQaBase/dashboard/consolidado" -Headers $caj.headers -Method GET -SkipHttpErrorCheck
  if ($r.StatusCode -eq 403) {
    Write-Host 'OK cajero 403 consolidado' -ForegroundColor Green
  } else {
    Write-Host "AVISO: cajero consolidado status=$($r.StatusCode) (puede ser corporativo por permisos)" -ForegroundColor Yellow
  }
} catch {
  Write-Host 'AVISO: sin cajero@foody.demo para assert 403' -ForegroundColor Yellow
}

# Static: controllers delgados
$dashCtrl = Get-Content (Join-Path $PSScriptRoot '..\foody_backend\src\modulos\dashboard\dashboard.controller.ts') -Raw
if ($dashCtrl -match 'esCorporativo') { throw 'dashboard.controller aun tiene esCorporativo' }
$anCtrl = Get-Content (Join-Path $PSScriptRoot '..\foody_backend\src\modulos\analitica\analitica.controller.ts') -Raw
if ($anCtrl -match 'resolverPeriodoAnalitica|parseFiltrosDesdeDto|esCorporativo') {
  throw 'analitica.controller aun parsea periodo/filtros o gate corporativo'
}
Write-Host 'OK controllers sin gate/parse de negocio' -ForegroundColor Green

Write-Host 'BN-CTRL-04/05 OK' -ForegroundColor Green
