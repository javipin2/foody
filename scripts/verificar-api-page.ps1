# API-PAGE — tope + paginacion opt-in usuarios/productos/insumos.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== API-PAGE listados ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal

function Assert-ArrayDatos($json, [string]$label) {
  if (-not $json.exito) { throw "$label exito=false $($json.error)" }
  if ($json.datos -isnot [System.Array]) {
    throw "$label sin page debe ser array, got $($json.datos.GetType().Name)"
  }
  Write-Host "OK $label array n=$($json.datos.Count)" -ForegroundColor Green
}

function Assert-Paginado($json, [string]$label) {
  if (-not $json.exito) { throw "$label exito=false $($json.error)" }
  $d = $json.datos
  if ($null -eq $d.items -or $null -eq $d.total -or $null -eq $d.page) {
    throw "$label con page debe tener items/total/page"
  }
  Write-Host "OK $label page=$($d.page) items=$($d.items.Count) total=$($d.total)" -ForegroundColor Green
}

# Sin page = array (compat Flutter)
$u = Invoke-FoodyApi -Path "/usuarios?sucursal_id=$sid" -Headers $h
Assert-ArrayDatos $u.json 'GET /usuarios'
$p = Invoke-FoodyApi -Path "/productos/sucursal/${sid}" -Headers $h
Assert-ArrayDatos $p.json 'GET /productos'
$i = Invoke-FoodyApi -Path "/inventario/${sid}" -Headers $h
Assert-ArrayDatos $i.json 'GET /inventario'

# Con page = meta
$up = Invoke-FoodyApi -Path "/usuarios?sucursal_id=$sid&page=1&limit=5" -Headers $h
Assert-Paginado $up.json 'GET /usuarios?page=1'
$pp = Invoke-FoodyApi -Path "/productos/sucursal/${sid}?page=1&limit=5" -Headers $h
Assert-Paginado $pp.json 'GET /productos?page=1'
$ip = Invoke-FoodyApi -Path "/inventario/${sid}?page=1&limit=5" -Headers $h
Assert-Paginado $ip.json 'GET /inventario?page=1'

# Static: LIMITE en extras
$cat = Get-Content (Join-Path $PSScriptRoot '..\foody_backend\src\modulos\catalogo\catalogo.service.ts') -Raw
if ($cat -notmatch 'LIMITE_LISTADO_SIN_PAGINA') {
  throw 'catalogo sin LIMITE_LISTADO_SIN_PAGINA'
}
Write-Host 'OK toppings/bebidas/combos con tope' -ForegroundColor Green

Write-Host 'API-PAGE OK' -ForegroundColor Green
