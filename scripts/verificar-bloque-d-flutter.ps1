# Bloque D — smoke Flutter paths tocados (HUER-HALF / PERF-FL).
# Uso: .\scripts\verificar-bloque-d-flutter.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

Write-Host '=== Verificar Bloque D Flutter (analyze paths) ===' -ForegroundColor Cyan

$paths = @(
  'lib/features/facturacion/presentation/facturacion_admin_screen.dart',
  'lib/features/admin/domain/menu_admin_item.dart',
  'lib/features/caja/presentation/caja_admin_screen.dart',
  'lib/features/admin/presentation/widgets/pedidos_kanban_widget.dart',
  'lib/features/admin/presentation/widgets/mesas_grid_widget.dart',
  'lib/features/admin/providers/operacion_sucursal_provider.dart',
  'lib/features/pedidos/presentation/widgets/asignar_domiciliario_slot.dart',
  'lib/features/costeo/presentation/widgets/producto_items_incluidos_panel.dart',
  'lib/features/costeo/presentation/widgets/receta_producto_panel.dart',
  'lib/features/costeo/presentation/widgets/costeo_stitch_ui.dart',
  'lib/features/promociones/presentation/promociones_admin_screen.dart',
  'lib/features/restaurantes/presentation/restaurantes_screen_foody.dart',
  'lib/features/sucursales/presentation/sucursales_admin_screen.dart'
)

$r = & dart analyze @paths 2>&1
$r | Select-Object -Last 30
$texto = ($r | Out-String)
if ($texto -match '(?m)^\s*error -') {
  Write-Host 'FALLO: hay errors en analyze' -ForegroundColor Red
  exit 1
}

# liberarCanal / removeChannel en pantallas realtime clave
$fugas = Select-String -Path 'lib/features/**/*.dart' -Pattern '\.unsubscribe\(' -SimpleMatch -ErrorAction SilentlyContinue |
  Where-Object { $_.Line -notmatch 'liberarCanal|removeChannel|// ' }
if ($fugas) {
  Write-Host 'AVISO: unsubscribe suelto (revisar):' -ForegroundColor Yellow
  $fugas | Select-Object -First 10 | ForEach-Object { Write-Host "  $($_.Path):$($_.LineNumber)" }
} else {
  Write-Host 'OK sin unsubscribe suelto en features (scan simple)' -ForegroundColor Green
}

try {
  $salud = Invoke-RestMethod -Uri 'http://localhost:3000/api/v1/salud' -TimeoutSec 5
  if (-not $salud.exito) { throw 'salud false' }
  Write-Host 'OK API /salud' -ForegroundColor Green
} catch {
  Write-Host 'AVISO: API no responde (analyze Flutter igual cuenta)' -ForegroundColor Yellow
}

Write-Host 'Bloque D Flutter smoke OK' -ForegroundColor Green
exit 0
