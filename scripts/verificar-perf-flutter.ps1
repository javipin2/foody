# Prompt 24 — Performance Flutter: chequeos estaticos (listas / leaks / imagenes)
# Uso: .\scripts\verificar-perf-flutter.ps1
# No sustituye profiling DevTools de 8h; deja evidencia grep+analyze.

param(
  [switch]$SkipAnalyze
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Features = Join-Path $Root 'lib\features'
$Fallos = 0
$Avisos = 0

Write-Host '=== Foody PERF Flutter (Prompt 24) ===' -ForegroundColor Cyan
Write-Host "features=$Features"

function Get-DartMatches {
  param([string]$Pattern, [string]$Path = $Features)
  Get-ChildItem -Path $Path -Recurse -Filter '*.dart' -ErrorAction SilentlyContinue |
    Select-String -Pattern $Pattern
}

$memCache = @(Get-DartMatches 'memCacheWidth|memCacheHeight|cacheWidth|cacheHeight')
$imgNet = @(Get-DartMatches 'Image\.network\(|CachedNetworkImage\(|NetworkImage\(')
$unsub = @(Get-DartMatches '\.unsubscribe\(\)')
$remove = @(Get-DartMatches 'removeChannel')
$builders = @(Get-DartMatches 'ListView\.builder|SliverList|GridView\.builder')
$shrink = @(Get-DartMatches 'shrinkWrap:\s*true')
$compressDart = @(Get-DartMatches 'FlutterImageCompress|flutter_image_compress')

Write-Host ''
Write-Host '--- Conteos estaticos lib/features ---' -ForegroundColor Cyan
Write-Host ("  network/cached image refs : {0}" -f $imgNet.Count)
Write-Host ("  memCacheWidth/Height      : {0}" -f $memCache.Count)
Write-Host ("  .unsubscribe()            : {0}" -f $unsub.Count)
Write-Host ("  removeChannel             : {0}" -f $remove.Count)
Write-Host ("  ListView/Grid/Sliver build: {0}" -f $builders.Count)
Write-Host ("  shrinkWrap:true           : {0}" -f $shrink.Count)
Write-Host ("  FlutterImageCompress uso  : {0}" -f $compressDart.Count)

if ($memCache.Count -eq 0) {
  Write-Host '  AVISO PERF-FL-IMG-01: 0 memCacheWidth/Height en features (decode full-res)' -ForegroundColor Yellow
  $Avisos++
}
else {
  Write-Host '  OK hay memCache* (revisar cobertura)' -ForegroundColor Green
}

if ($compressDart.Count -eq 0) {
  Write-Host '  AVISO PERF-FL-IMG-03: flutter_image_compress en pubspec pero 0 usos Dart' -ForegroundColor Yellow
  $Avisos++
}

$caja = Join-Path $Features 'caja\presentation\caja_admin_screen.dart'
if (Test-Path $caja) {
  $cajaShrink = @(Select-String -Path $caja -Pattern 'shrinkWrap:\s*true')
  if ($cajaShrink.Count -gt 0) {
    Write-Host '  AVISO PERF-FL-LIST-07: caja_admin_screen usa shrinkWrap (lista movimientos)' -ForegroundColor Yellow
    $Avisos++
  }
}

$kanban = Join-Path $Features 'admin\presentation\widgets\pedidos_kanban_widget.dart'
if (Test-Path $kanban) {
  $wrap = @(Select-String -Path $kanban -Pattern 'Wrap\(')
  if ($wrap.Count -gt 0) {
    Write-Host '  AVISO PERF-FL-LIST-01: pedidos_kanban_widget usa Wrap (cards eager)' -ForegroundColor Yellow
    $Avisos++
  }
}

$sharp = Join-Path $Root 'foody_backend\src\modulos\almacenamiento\almacenamiento.service.ts'
if (Test-Path $sharp) {
  $s = @(Select-String -Path $sharp -Pattern 'comprimirImagen|\.webp')
  if ($s.Count -gt 0) {
    Write-Host '  OK backend sharp comprimirImagen (upload Nest -> webp max 800)' -ForegroundColor Green
  }
  else {
    Write-Host '  FALLO: se esperaba comprimirImagen en almacenamiento.service' -ForegroundColor Red
    $Fallos++
  }
}

if (-not $SkipAnalyze) {
  Write-Host ''
  Write-Host '--- dart analyze (paths clave) ---' -ForegroundColor Cyan
  Push-Location $Root
  try {
    $paths = @(
      'lib/features/pedidos/presentation/mis_pedidos_screen.dart',
      'lib/features/inventario/presentation/inventario_admin_screen.dart',
      'lib/features/caja/presentation/caja_admin_screen.dart',
      'lib/features/admin/presentation/widgets/pedidos_kanban_widget.dart',
      'lib/features/menu/presentation/menu_screen_foody.dart'
    )
    $out = & dart analyze @paths 2>&1 | Out-String
    Write-Host ($out.Trim().Split("`n") | Select-Object -Last 5 | Out-String)
    if ($out -match 'error -') {
      Write-Host '  FALLO: dart analyze reporta errors' -ForegroundColor Red
      $Fallos++
    }
    else {
      Write-Host '  OK dart analyze sin errors (warnings OK)' -ForegroundColor Green
    }
  }
  finally {
    Pop-Location
  }
}

Write-Host ''
Write-Host '--- Nota sesion 8h ---' -ForegroundColor DarkGray
Write-Host '  Profiling DevTools heap (turno 8h) NO corrido en esta verificacion estatica.'
Write-Host '  Evidencia de riesgo: FL-LEAK-02 / PERF-FL-MEM-01 (unsubscribe sin removeChannel).'

Write-Host ''
if ($Fallos -gt 0) {
  Write-Host "Verificacion PERF Flutter FALLO fallos=$Fallos avisos=$Avisos" -ForegroundColor Red
  exit 1
}
Write-Host "Verificacion PERF Flutter OK (avisos=$Avisos) - ver docs/AUDITORIA_PERF_FLUTTER.md" -ForegroundColor Green
exit 0
