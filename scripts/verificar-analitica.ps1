# Verifica scope analítica (P1-08): sede vs corporativo + comparativa sedes
# Uso: .\scripts\verificar-analitica.ps1

$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'

function Login-Staff {
  param([string]$Email, [string]$Pass = '123456')
  $body = @{ email = $Email; contrasena = $Pass } | ConvertTo-Json
  $r = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -Body $body -ContentType 'application/json'
  if (-not $r.exito) { throw $r.mensaje }
  return $r.datos
}

function Get-ExpectStatus {
  param(
    [string]$Url,
    [hashtable]$Headers,
    [int[]]$OkCodes = @(200)
  )
  try {
    $resp = Invoke-WebRequest -Uri $Url -Headers $Headers -Method GET -UseBasicParsing -TimeoutSec 12
    $code = [int]$resp.StatusCode
    if ($OkCodes -contains $code) { return $code }
    throw "Status inesperado $code en $Url"
  } catch {
    if ($_.Exception.Response) {
      $code = [int]$_.Exception.Response.StatusCode
      if ($OkCodes -contains $code) { return $code }
    }
    throw $_
  }
}

Write-Host "=== Verificar analítica (scope + comparativa sedes) ===" -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }
Write-Host "OK salud" -ForegroundColor Green

$admin = Login-Staff 'admin@foody.demo'
$hAdmin = @{ Authorization = "Bearer $($admin.token)" }
$sidAdmin = $admin.usuario.sucursal_id

$sucursales = Invoke-RestMethod -Uri "$base/sucursales/mi-restaurante" -Headers $hAdmin
$lista = @($sucursales.datos)
$otraSid = ($lista | Where-Object { $_.id -ne $sidAdmin } | Select-Object -First 1).id

# Admin corporativo: resumen propia sede
$code = Get-ExpectStatus -Url "$base/analitica/resumen?sucursal_id=$sidAdmin&preset=7d" -Headers $hAdmin
Write-Host "OK admin resumen propia sede ($code)" -ForegroundColor Green

# Admin corporativo: comparativa sedes
$code = Get-ExpectStatus -Url "$base/analitica/comparativa-sedes?preset=7d" -Headers $hAdmin
Write-Host "OK admin comparativa-sedes ($code)" -ForegroundColor Green

# Sucursal ajena al restaurante -> 403
$fakeSid = '00000000-0000-4000-8000-000000000099'
$code = Get-ExpectStatus -Url "$base/analitica/resumen?sucursal_id=$fakeSid&preset=7d" -Headers $hAdmin -OkCodes @(403)
Write-Host "OK admin bloqueado sucursal inválida ($code)" -ForegroundColor Green

# Gerente sede (sin gestionar_sucursales): propia OK, otra 403
$gerente = Login-Staff 'gerente@foody.demo'
$hGerente = @{ Authorization = "Bearer $($gerente.token)" }
$sidGerente = $gerente.usuario.sucursal_id

$code = Get-ExpectStatus -Url "$base/analitica/resumen?sucursal_id=$sidGerente&preset=7d" -Headers $hGerente
Write-Host "OK gerente resumen propia sede ($code)" -ForegroundColor Green

$code = Get-ExpectStatus -Url "$base/analitica/comparativa-sedes?preset=7d" -Headers $hGerente -OkCodes @(403)
Write-Host "OK gerente bloqueado comparativa-sedes ($code)" -ForegroundColor Green

if ($otraSid -and $otraSid -ne $sidGerente) {
  $code = Get-ExpectStatus -Url "$base/analitica/resumen?sucursal_id=$otraSid&preset=7d" -Headers $hGerente -OkCodes @(403)
  Write-Host "OK gerente bloqueado otra sede ($code)" -ForegroundColor Green
} else {
  Write-Host "AVISO: aplica migr. 062_demo_segunda_sede_qa.sql para probar bloqueo cross-sede" -ForegroundColor Yellow
}

# Cocina sin permiso analítica
$cocina = Login-Staff 'cocina@foody.demo'
$hCocina = @{ Authorization = "Bearer $($cocina.token)" }
$code = Get-ExpectStatus -Url "$base/analitica/resumen?preset=7d" -Headers $hCocina -OkCodes @(403)
Write-Host "OK cocina sin permiso analítica ($code)" -ForegroundColor Green

# Multi-filtro: horas + estados + comparar
$urlFiltros = "$base/analitica/resumen?sucursal_id=$sidAdmin&preset=7d&hora_desde=12&hora_hasta=18&estados=pagado,entregado&comparar=true"
$rFiltros = Invoke-RestMethod -Uri $urlFiltros -Headers $hAdmin -TimeoutSec 20
if (-not $rFiltros.exito) { throw "Filtros combinados fallaron: $($rFiltros.mensaje)" }
if (-not $rFiltros.datos.kpis) { throw 'Resumen con filtros sin kpis' }
Write-Host "OK resumen multi-filtro (hora+estados+comparar)" -ForegroundColor Green

$urlVentas = "$base/analitica/ventas?sucursal_id=$sidAdmin&preset=hoy&hora_desde=0&hora_hasta=23"
$rVentas = Invoke-RestMethod -Uri $urlVentas -Headers $hAdmin -TimeoutSec 20
if (-not $rVentas.exito) { throw $rVentas.mensaje }
Write-Host "OK ventas con rango horas" -ForegroundColor Green

$urlCocinas = "$base/analitica/cocinas?sucursal_id=$sidAdmin&preset=mes"
$rCocinas = Invoke-RestMethod -Uri $urlCocinas -Headers $hAdmin -TimeoutSec 20
if (-not $rCocinas.exito) { throw $rCocinas.mensaje }
Write-Host "OK cocinas (tiempos min/max si hay data)" -ForegroundColor Green

$urlRiesgo = "$base/analitica/riesgo?sucursal_id=$sidAdmin&preset=30d"
$rRiesgo = Invoke-RestMethod -Uri $urlRiesgo -Headers $hAdmin -TimeoutSec 20
if (-not $rRiesgo.exito) { throw $rRiesgo.mensaje }
if ($null -eq $rRiesgo.datos.productos_cancelados_post_cocina_aprox) {
  throw 'Falta productos_cancelados_post_cocina_aprox en riesgo'
}
Write-Host "OK riesgo con ranking cancelados post-cocina" -ForegroundColor Green

# Fase 2: export CSV + comparativa en ventas
$exportUrl = "$base/analitica/export?sucursal_id=$sidAdmin&preset=7d&formato=csv&comparar=true"
$exportResp = Invoke-WebRequest -Uri $exportUrl -Headers $hAdmin -Method GET -UseBasicParsing -TimeoutSec 30
if ($exportResp.StatusCode -ne 200) { throw "Export status $($exportResp.StatusCode)" }
if ($exportResp.RawContentLength -le 50) { throw "Export CSV demasiado corto ($($exportResp.RawContentLength) bytes)" }
Write-Host "OK export CSV ($($exportResp.RawContentLength) bytes)" -ForegroundColor Green

$urlVentasCmp = "$base/analitica/ventas?sucursal_id=$sidAdmin&preset=7d&comparar=true"
$rVentasCmp = Invoke-RestMethod -Uri $urlVentasCmp -Headers $hAdmin -TimeoutSec 20
if (-not $rVentasCmp.exito) { throw $rVentasCmp.mensaje }
if (-not $rVentasCmp.datos.comparativa) { throw 'ventas?comparar=true sin datos.comparativa' }
Write-Host "OK ventas con comparativa (delta $($rVentasCmp.datos.comparativa.delta.ventas_netas_pct)%)" -ForegroundColor Green

# Fase 3: lista alertas en resumen + señales Δ prep / categorías en riesgo
$rResumen3 = Invoke-RestMethod -Uri "$base/analitica/resumen?sucursal_id=$sidAdmin&preset=7d&comparar=true" -Headers $hAdmin -TimeoutSec 20
if (-not $rResumen3.exito) { throw $rResumen3.mensaje }
if ($null -eq $rResumen3.datos.alertas_abiertas_lista) {
  throw 'Falta alertas_abiertas_lista en resumen'
}
Write-Host "OK resumen alertas_abiertas_lista ($($rResumen3.datos.alertas_abiertas_lista.Count) items)" -ForegroundColor Green

$rRiesgo3 = Invoke-RestMethod -Uri "$base/analitica/riesgo?sucursal_id=$sidAdmin&preset=7d&comparar=true" -Headers $hAdmin -TimeoutSec 25
if (-not $rRiesgo3.exito) { throw $rRiesgo3.mensaje }
if ($null -eq $rRiesgo3.datos.cocinas_prep_delta) { throw 'Falta cocinas_prep_delta en riesgo' }
if ($null -eq $rRiesgo3.datos.categorias_caida) { throw 'Falta categorias_caida en riesgo' }
Write-Host "OK riesgo prep_delta=$($rRiesgo3.datos.cocinas_prep_delta.Count) categorias_caida=$($rRiesgo3.datos.categorias_caida.Count)" -ForegroundColor Green

$rPedidos = Invoke-RestMethod -Uri "$base/analitica/pedidos-recientes?sucursal_id=$sidAdmin&preset=7d&limite=10" -Headers $hAdmin -TimeoutSec 20
if (-not $rPedidos.exito) { throw $rPedidos.mensaje }
if ($null -eq $rPedidos.datos.pedidos) { throw 'Falta datos.pedidos en pedidos-recientes' }
Write-Host "OK pedidos-recientes ($($rPedidos.datos.pedidos.Count) items)" -ForegroundColor Green

Write-Host ""
Write-Host "Verificación analítica OK" -ForegroundColor Green
exit 0
