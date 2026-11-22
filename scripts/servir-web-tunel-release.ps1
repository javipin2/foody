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
    Write-Host "Liberando :$Puerto (PID $id)" -ForegroundColor Yellow
    Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
  }
}

function Build-Web([string]$Flavor, [string]$OutDir) {
  Write-Host "Build web RELEASE flavor=$Flavor -> $OutDir" -ForegroundColor Cyan
  & flutter build web --release `
    --dart-define="APP_FLAVOR=$Flavor" `
    -t lib/main.dart `
    -o $OutDir
  if ($LASTEXITCODE -ne 0) { throw "flutter build web $Flavor fallo ($LASTEXITCODE)" }
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
    -WindowStyle Minimized `
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

if (-not $SkipBuild) {
  Build-Web 'cliente' $outCliente
  Build-Web 'equipo' $outEquipo
} else {
  if (-not (Test-Path (Join-Path $outCliente 'index.html'))) { throw "Falta $outCliente - quita -SkipBuild" }
  if (-not (Test-Path (Join-Path $outEquipo 'index.html'))) { throw "Falta $outEquipo - quita -SkipBuild" }
}

Write-Host ''
Write-Host 'Sirviendo estatico:' -ForegroundColor Cyan
Write-Host "  $FoodyUrlApp         <- :$pCli cliente" -ForegroundColor White
Write-Host "  $FoodyUrlEquipo  <- :$pEq equipo + superadmin" -ForegroundColor White
Write-Host ''

# Equipo primero: si falla, no dejamos solo el cliente “medio funcionando”
Start-SpaServidor -Puerto $pEq -Directorio $outEquipo -Nombre 'equipo'
Start-SpaServidor -Puerto $pCli -Directorio $outCliente -Nombre 'cliente'

try {
  $m = Invoke-WebRequest "http://127.0.0.1:$pCli/main.dart.js" -UseBasicParsing -TimeoutSec 10
  Write-Host "cliente main.dart.js len=$($m.RawContentLength) (release suele ser >1MB)" -ForegroundColor DarkGray
} catch { Write-Host 'AVISO: no se pudo leer main.dart.js cliente' -ForegroundColor Yellow }

Write-Host ''
Write-Host 'Listo (ambos puertos OK). Recarga Ctrl+F5:' -ForegroundColor Green
Write-Host "  $FoodyUrlApp"
Write-Host "  $FoodyUrlEquipo/admin/login"
Write-Host "Para parar: mata procesos en :$pEq / :$pCli"
