# Verifica coherencia caja: sin ventas > total por pedido; util repartirCobroDomicilio.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\qa-helpers.ps1"
Assert-FoodyQaDisposable

Write-Host '1) repartirCobroDomicilio...' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'verificar-cobro-domicilio.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

function Get-DockerScalar($sql) {
  $lines = docker exec -i $script:FoodyQaDbContainer psql -U postgres -d $script:FoodyQaDatabase -t -A -c $sql 2>$null
  $uuid = $lines | Where-Object { $_ -match '^[0-9a-f]{8}-[0-9a-f]{4}-' } | Select-Object -First 1
  if ($uuid) { return $uuid.Trim() }
  return ($lines | Where-Object { $_ -match '^\d+$' -and $_ -notmatch '^\[rtk\]' } | Select-Object -Last 1).Trim()
}

Write-Host '2) Pedidos con neto cobrado (ventas - devoluciones) > total...' -ForegroundColor Cyan
$exceso = Get-DockerScalar @"
SELECT COUNT(*) FROM (
  SELECT p.id FROM pedidos p
  LEFT JOIN movimientos_caja m ON m.pedido_id=p.id AND m.tipo IN ('venta','devolucion')
  GROUP BY p.id, p.total
  HAVING COALESCE(SUM(CASE WHEN m.tipo='venta' THEN m.monto ELSE -m.monto END),0) > p.total + 0.01
) x;
"@
if ($exceso -ne '0') {
  Write-Host "FAIL: $exceso pedidos con ventas duplicadas en caja" -ForegroundColor Red
  exit 1
}
Write-Host '   OK: 0 pedidos con exceso' -ForegroundColor Green

Write-Host '3) API salud...' -ForegroundColor Cyan
try {
  $salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
  if (-not $salud.exito) { throw 'salud.exito false' }
  Write-Host '   OK salud' -ForegroundColor Green
} catch {
  Write-Host "FAIL API: $_" -ForegroundColor Red
  exit 1
}

Write-Host '4) debeRegistrarVentaAlCrear excluye domicilio (build)...' -ForegroundColor Cyan
$dist = Join-Path $root 'foody_backend\dist\modulos\pedidos\pedidos-caja-auditoria.service.js'
if (-not (Test-Path $dist)) {
  Write-Host 'FAIL: falta dist, ejecuta npm run build' -ForegroundColor Red
  exit 1
}
$js = Get-Content $dist -Raw
if ($js -notmatch "tipo === 'domicilio'") {
  Write-Host 'FAIL: dist sin exclusion domicilio' -ForegroundColor Red
  exit 1
}
Write-Host '   OK exclusion domicilio en dist' -ForegroundColor Green

Write-Host '5) Aplicar descuento (factura_id + API fresca)...' -ForegroundColor Cyan
$facturaCol = Get-DockerScalar "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='pedidos' AND column_name='factura_id';"
if ($facturaCol -ne '1') {
  Write-Host 'FAIL: columna pedidos.factura_id no existe' -ForegroundColor Red
  exit 1
}
$adminQa = Get-FoodyToken 'admin@foody.demo'
$hQa = $adminQa.headers
$sidQa = $script:FoodyQaSucursal
# Pedido demo en sucursal admin para probar descuento (sin crear pedido nuevo).
$pedidoTest = Get-DockerScalar @"
UPDATE pedidos SET estado='en_cocina' WHERE id = (
   SELECT id FROM pedidos WHERE sucursal_id='$sidQa' AND estado IN ('cancelado','pendiente','confirmado','en_cocina')
   ORDER BY created_at DESC LIMIT 1
 ) RETURNING id;
"@
if (-not $pedidoTest) { throw 'Sin pedido demo para probar descuento' }
$desc = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedidoTest/descuento?sucursal_id=$sidQa" -Headers $hQa -Body @{
  porcentaje = 5
  motivo     = 'Verificacion caja coherencia'
}
if (-not ($desc.ok -and $desc.json.exito)) {
  $msg = if ($desc.json) { $desc.json.mensaje } else { $desc.error }
  Write-Host "FAIL descuento: $msg" -ForegroundColor Red
  exit 1
}
Write-Host "   OK descuento en pedido $pedidoTest (factura_id presente)" -ForegroundColor Green

Write-Host "`nOK verificar-caja-coherencia" -ForegroundColor Green
