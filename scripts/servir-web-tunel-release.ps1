# Compila Flutter web RELEASE (cliente + equipo) y sirve en puertos de foody-entorno.env.
# Uso:
#   .\scripts\servir-web-tunel-release.ps1
#   .\scripts\servir-web-tunel-release.ps1 -SkipBuild

param(
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
Set-Location $raiz
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

# netstat: no depende del modulo NetTCPIP (a veces falla al cargar en PS)
function Get-PidsEscuchando([int]$Puerto) {
  $pids = @()
  foreach ($line in (netstat -ano 2>$null)) {
    if ($line -notmatch 'LISTENING') { continue }
    if ($line -notmatch ":$Puerto\s+") { continue }
    $pidTxt = ($line.Trim() -split '\s+')[-1]
    if ($pidTxt -match '^\d+$') {
      $id = [int]$pidTxt
      if ($id -gt 0 -and $pids -notcontains $id) { $pids += $id }
    }
  }
  return $pids
}

function Test-PuertoEscucha([int]$Puerto) {
  return @(Get-PidsEscuchando $Puerto).Count -gt 0
}

function Liberar-Puerto([int]$Puerto) {
  foreach ($id in (Get-PidsEscuchando $Puerto)) {
    $proceso = Get-CimInstance Win32_Process -Filter "ProcessId = $id" -ErrorAction SilentlyContinue
    $spaEsperado = Join-Path $PSScriptRoot 'spa_http_server.py'
    if (-not $proceso -or $proceso.Name -notmatch '^python(w)?\.exe$' -or
        $proceso.CommandLine.IndexOf($spaEsperado, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
      throw "No liberar :${Puerto}: PID $id no coincide con el servidor SPA de Foody."
    }
    Write-Host "Liberando servidor SPA Foody :$Puerto (PID $id)" -ForegroundColor Yellow
    Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
  }
}

function Build-Web([string]$Flavor, [string]$OutDir) {
  if (Test-Path -LiteralPath $OutDir) {
    Remove-Item -LiteralPath $OutDir -Recurse -Force
  }
  Write-Host "Build web RELEASE flavor=$Flavor -> $OutDir (staging)" -ForegroundColor Cyan
  & flutter build web --release `
    --dart-define="APP_FLAVOR=$Flavor" `
    -t lib/main.dart `
    -o $OutDir
  if ($LASTEXITCODE -ne 0) { throw "flutter build web $Flavor fallo ($LASTEXITCODE)" }

  # Flutter solo publica los artefactos que gestiona; conserva los recursos web
  # propios del proyecto (FCM service worker, páginas legales y manifest).
  Get-ChildItem (Join-Path $raiz 'web') -File |
    Where-Object { $_.Name -ne 'index.html' } |
    Copy-Item -Destination $OutDir -Force

  # Evita que el navegador conserve el main.dart.js de una publicación anterior.
  $mainJs = Join-Path $OutDir 'main.dart.js'
  $bootstrapPath = Join-Path $OutDir 'flutter_bootstrap.js'
  $indexPath = Join-Path $OutDir 'index.html'
  # Calcular sin Get-FileHash: este script también se ejecuta con Windows
  # PowerShell -NoProfile, donde el módulo Utility puede no quedar visible
  # dentro de funciones anidadas aunque se importe en el ámbito del script.
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  $hashStream = [System.IO.File]::OpenRead($mainJs)
  try {
    $hashBytes = $sha256.ComputeHash($hashStream)
    $cacheVersion = [BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant()
  } finally {
    $hashStream.Dispose()
    $sha256.Dispose()
  }
  $bootstrap = [IO.File]::ReadAllText($bootstrapPath)
  $index = [IO.File]::ReadAllText($indexPath)
  $mainJsPath = '"mainJsPath":"main.dart.js"'
  $bootstrapScript = 'flutter_bootstrap.js'
  if (-not $bootstrap.Contains($mainJsPath) -or -not $index.Contains($bootstrapScript)) {
    throw "No pude versionar el cache del flavor $Flavor; revisa los artefactos Flutter."
  }
  $bootstrap = $bootstrap.Replace(
    $mainJsPath,
    ('"mainJsPath":"main.dart.js?v=' + $cacheVersion + '"')
  )
  $index = $index.Replace(
    'flutter_bootstrap.js',
    ('flutter_bootstrap.js?v=' + $cacheVersion)
  )
  [IO.File]::WriteAllText($bootstrapPath, $bootstrap, [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText($indexPath, $index, [Text.UTF8Encoding]::new($false))
  Write-Host "Cache web versionado por SHA-256 ($Flavor): $cacheVersion" -ForegroundColor DarkGray
}

function Start-SpaServidor {
  param(
    [Parameter(Mandatory)][int]$Puerto,
    [Parameter(Mandatory)][string]$Directorio,
    [Parameter(Mandatory)][string]$Nombre
  )
  $spa = Join-Path $PSScriptRoot 'spa_http_server.py'
  if (-not (Test-Path $spa)) { throw "Falta $spa" }
  if (-not (Test-Path (Join-Path $Directorio 'index.html'))) {
    throw "Falta index.html en $Directorio"
  }

  Liberar-Puerto $Puerto
  Start-Sleep -Milliseconds 400

  $outLog = Join-Path $env:TEMP "foody-spa-$Nombre-out.log"
  $errLog = Join-Path $env:TEMP "foody-spa-$Nombre-err.log"
  Remove-Item $outLog, $errLog -Force -ErrorAction SilentlyContinue

  # ArgumentList con paths con espacios (FOODY APP): un solo string tipico de cmd
  $arg = "`"$spa`" $Puerto `"$Directorio`""
  $proc = Start-Process -FilePath 'python' -ArgumentList $arg `
    -WorkingDirectory $raiz `
    -WindowStyle Hidden `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError $errLog `
    -PassThru

  $ok = $false
  for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 250
    if ($proc.HasExited) { break }
    if (Test-PuertoEscucha $Puerto) { $ok = $true; break }
  }

  if (-not $ok) {
    $errTxt = ''
    if (Test-Path $errLog) { $errTxt = (Get-Content $errLog -Raw -ErrorAction SilentlyContinue) }
    if ($proc.HasExited) {
      throw "SPA $Nombre NO arranco en :$Puerto (python salio). Log: $errTxt"
    }
    throw "SPA $Nombre NO escucha :$Puerto tras arrancar. Log: $errTxt"
  }

  try {
    $r = Invoke-WebRequest "http://127.0.0.1:$Puerto/" -UseBasicParsing -TimeoutSec 5
    if ($r.StatusCode -ne 200) { throw "HTTP $($r.StatusCode)" }
  } catch {
    throw "SPA $Nombre escucha :$Puerto pero no responde HTTP: $($_.Exception.Message)"
  }

  Write-Host "OK $Nombre http://127.0.0.1:$Puerto (PID $($proc.Id))" -ForegroundColor Green
}

& (Join-Path $PSScriptRoot 'sincronizar-entorno.ps1') -Modo tunel

$outCliente = Join-Path $raiz 'build\web_cliente'
$outEquipo = Join-Path $raiz 'build\web_equipo'
$pCli = $FoodyPuertoCliente
$pEq = $FoodyPuertoEquipo

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$stageRoot = Join-Path $raiz "build\.foody-release-stage-$stamp"
$stageCliente = Join-Path $stageRoot 'cliente'
$stageEquipo = Join-Path $stageRoot 'equipo'

$tieneCliente = Test-Path (Join-Path $outCliente 'index.html')
$tieneEquipo = Test-Path (Join-Path $outEquipo 'index.html')
# -SkipBuild omite Flutter solo si el artefacto existe y está al día.
# Un build viejo servía silenciosamente una UI anterior por el túnel.
$rutasFuente = @('lib', 'web', 'assets')
$archivosFuente = @('pubspec.yaml', 'pubspec.lock')
$cambiosFuente = @()
foreach ($ruta in $rutasFuente) {
  if (Test-Path $ruta -PathType Container) {
    $cambiosFuente += Get-ChildItem $ruta -File -Recurse -ErrorAction SilentlyContinue |
      Select-Object -ExpandProperty LastWriteTimeUtc
  }
}
foreach ($ruta in $archivosFuente) {
  if (Test-Path $ruta -PathType Leaf) {
    $cambiosFuente += (Get-Item $ruta).LastWriteTimeUtc
  }
}
$ultimoCambioFuente = if ($cambiosFuente.Count -gt 0) { ($cambiosFuente | Measure-Object -Maximum).Maximum } else { [DateTime]::MinValue }

function Build-Desactualizado([string]$Directorio, [bool]$Existe) {
  if (-not $Existe) { return $true }
  $index = Get-Item (Join-Path $Directorio 'index.html')
  return $index.LastWriteTimeUtc -lt $ultimoCambioFuente
}

$buildClientePendiente = (-not $SkipBuild) -or (Build-Desactualizado $outCliente $tieneCliente)
$buildEquipoPendiente = (-not $SkipBuild) -or (Build-Desactualizado $outEquipo $tieneEquipo)
if ($buildClientePendiente -or $buildEquipoPendiente) {
  if ($SkipBuild) {
    Write-Host 'AVISO: builds web faltantes o desactualizados; compilando los flavors necesarios...' -ForegroundColor Yellow
  }
  if ($buildClientePendiente) { Build-Web 'cliente' $stageCliente }
  if ($buildEquipoPendiente) { Build-Web 'equipo' $stageEquipo }
}

foreach ($candidato in @(
  @{ Requerido = $buildClientePendiente; Stage = $stageCliente; Nombre = 'cliente' },
  @{ Requerido = $buildEquipoPendiente; Stage = $stageEquipo; Nombre = 'equipo' }
)) {
  if (-not $candidato.Requerido) { continue }
  foreach ($archivo in @('index.html', 'main.dart.js', 'flutter_bootstrap.js')) {
    if (-not (Test-Path -LiteralPath (Join-Path $candidato.Stage $archivo))) {
      throw "Build $($candidato.Nombre) incompleto; falta $archivo. El sitio actual sigue servido."
    }
  }
}

Write-Host ''
Write-Host 'Sirviendo estatico:' -ForegroundColor Cyan
Write-Host "  $FoodyUrlApp         <- :$pCli cliente" -ForegroundColor White
Write-Host "  $FoodyUrlEquipo  <- :$pEq equipo + superadmin" -ForegroundColor White
Write-Host ''

$backups = @{}
$publicados = @()
try {
  # Compilar ambos antes del corte. El servicio anterior sigue respondiendo durante los builds.
  Liberar-Puerto $pEq
  Liberar-Puerto $pCli
  Start-Sleep -Milliseconds 400

  foreach ($candidato in @(
    @{ Requerido = $buildEquipoPendiente; Stage = $stageEquipo; Destino = $outEquipo; Nombre = 'equipo' },
    @{ Requerido = $buildClientePendiente; Stage = $stageCliente; Destino = $outCliente; Nombre = 'cliente' }
  )) {
    if (-not $candidato.Requerido) { continue }
    $backup = "$($candidato.Destino).__previous_$stamp"
    if (Test-Path -LiteralPath $backup) { throw "Ya existe backup inesperado: $backup" }
    if (Test-Path -LiteralPath $candidato.Destino) {
      Move-Item -LiteralPath $candidato.Destino -Destination $backup
      $backups[$candidato.Nombre] = $backup
    }
    Move-Item -LiteralPath $candidato.Stage -Destination $candidato.Destino
    $publicados += $candidato.Nombre
  }

  # Equipo primero; ambos artifacts ya están completos y versionados por SHA.
  Start-SpaServidor -Puerto $pEq -Directorio $outEquipo -Nombre 'equipo'
  Start-SpaServidor -Puerto $pCli -Directorio $outCliente -Nombre 'cliente'
} catch {
  Write-Host "Falló la publicación web: $($_.Exception.Message). Restaurando el último build disponible..." -ForegroundColor Red
  foreach ($puerto in @($pEq, $pCli)) {
    try { Liberar-Puerto $puerto } catch { Write-Host $_.Exception.Message -ForegroundColor Yellow }
  }
  foreach ($nombre in @('cliente', 'equipo')) {
    if ($backups.ContainsKey($nombre)) {
      $destino = if ($nombre -eq 'cliente') { $outCliente } else { $outEquipo }
      $failed = "$destino.__failed_$stamp"
      if (Test-Path -LiteralPath $destino) { Move-Item -LiteralPath $destino -Destination $failed }
      Move-Item -LiteralPath $backups[$nombre] -Destination $destino
    }
  }
  if ((Test-Path (Join-Path $outEquipo 'index.html')) -and (Test-Path (Join-Path $outCliente 'index.html'))) {
    try {
      Start-SpaServidor -Puerto $pEq -Directorio $outEquipo -Nombre 'equipo-rollback'
      Start-SpaServidor -Puerto $pCli -Directorio $outCliente -Nombre 'cliente-rollback'
      Write-Host 'Rollback de los bundles anteriores comprobado en ambos puertos.' -ForegroundColor Yellow
    } catch { Write-Host "No se pudo reactivar SPA anterior: $($_.Exception.Message)" -ForegroundColor Red }
  }
  throw
}

try {
  $m = Invoke-WebRequest "http://127.0.0.1:$pCli/main.dart.js" -UseBasicParsing -TimeoutSec 10
  Write-Host "cliente main.dart.js len=$($m.RawContentLength) (release suele ser >1MB)" -ForegroundColor DarkGray
} catch { Write-Host 'AVISO: no se pudo leer main.dart.js cliente' -ForegroundColor Yellow }

Write-Host ''
Write-Host 'Listo (ambos puertos OK). Recarga Ctrl+F5:' -ForegroundColor Green
Write-Host "  $FoodyUrlApp"
Write-Host "  $FoodyUrlEquipo/admin/login"
Write-Host "Para parar: mata procesos en :$pEq / :$pCli"
if ($backups.Count -gt 0) {
  Write-Host "Backups previos conservados: $($backups.Values -join ', ')" -ForegroundColor DarkGray
}
