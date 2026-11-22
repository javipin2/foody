# Escribe Flutter configuracion.dart + CORS backend desde URLs del entorno.
# Llamado por sincronizar-entorno.ps1 (no suele invocarse a mano).
param(
  [Parameter(Mandatory)][string]$UrlApp,
  [Parameter(Mandatory)][string]$UrlApi,
  [Parameter(Mandatory)][string]$UrlSb,
  [string]$UrlEquipo = '',
  [bool]$UsarTunel = $true,
  [string]$IpLan = '192.168.1.2',
  [int]$PuertoCliente = 8081,
  [int]$PuertoEquipo = 8080,
  [string]$Modo = 'entorno'
)

$raiz = Split-Path -Parent $PSScriptRoot
$config = Join-Path $raiz 'lib\core\constantes\configuracion.dart'
$backendEnv = Join-Path $raiz 'foody_backend\.env'

if (-not (Test-Path $config)) {
  throw "No existe $config"
}

if ([string]::IsNullOrWhiteSpace($UrlEquipo)) {
  # Derivar equipo.* del mismo dominio que api
  if ($UrlApi -match '^https://api\.(.+)$') {
    $UrlEquipo = "https://equipo.$($Matches[1])"
  } else {
    $UrlEquipo = $UrlApp
  }
}

$flag = if ($UsarTunel) { 'true' } else { 'false' }

$c = Get-Content $config -Raw -Encoding UTF8

if ($c -notmatch 'hostEquipo') {
  # Insertar hostEquipo tras hostApp si falta (migración suave)
  $c = $c -replace "(static const String hostApp = '[^']*';)", "`$1`r`n  static const String hostEquipo = '$UrlEquipo';"
}

$c = $c -replace 'usarTunel\s*=\s*(true|false)', "usarTunel = $flag"
$c = $c -replace "ipLan\s*=\s*'[^']*'", "ipLan = '$IpLan'"
$c = $c -replace "hostApp\s*=\s*'[^']*'", "hostApp = '$UrlApp'"
$c = $c -replace "hostEquipo\s*=\s*'[^']*'", "hostEquipo = '$UrlEquipo'"
$c = $c -replace "hostApi\s*=\s*'[^']*'", "hostApi = '$UrlApi'"
$c = $c -replace "hostSupabase\s*=\s*'[^']*'", "hostSupabase = '$UrlSb'"
$c = $c -replace 'puertoWebClienteDev\s*=\s*\d+', "puertoWebClienteDev = $PuertoCliente"
if ($c -match 'puertoWebEquipoDev\s*=') {
  $c = $c -replace 'puertoWebEquipoDev\s*=\s*\d+', "puertoWebEquipoDev = $PuertoEquipo"
} else {
  $c = $c -replace '(static const int puertoWebClienteDev = \d+;)', "`$1`r`n  static const int puertoWebEquipoDev = $PuertoEquipo;"
}
$c = $c -replace 'Generado por scripts \([^)]*\)', "Generado por scripts ($Modo)"

Set-Content -Path $config -Value $c -Encoding UTF8 -NoNewline
Write-Host "OK Flutter usarTunel=$flag | app=$UrlApp | equipo=$UrlEquipo | api=$UrlApi | sb=$UrlSb" -ForegroundColor Green


if (Test-Path $backendEnv) {
  $env = Get-Content $backendEnv -Raw -Encoding UTF8
  # Lista canónica (no acumular localhost basura de round-trips / puertos viejos)
  $corsWanted = @(
    $UrlApp,
    $UrlEquipo,
    "http://localhost:$PuertoEquipo",
    "http://localhost:$PuertoCliente",
    'http://localhost:8082',
    'http://localhost:3000'
  ) | Select-Object -Unique
  $corsLine = 'CORS_ORIGEN=' + ($corsWanted -join ',')
  if ($env -match '(?m)^CORS_ORIGEN=') {
    $env = $env -replace '(?m)^CORS_ORIGEN=.*$', $corsLine
  } else {
    $env = $env.TrimEnd() + "`n$corsLine`n"
  }
  if ($env -match '(?m)^CLIENT_WEB_URL=') {
    $env = $env -replace '(?m)^CLIENT_WEB_URL=.*$', "CLIENT_WEB_URL=$UrlApp"
  } else {
    $env = $env.TrimEnd() + "`nCLIENT_WEB_URL=$UrlApp`n"
  }
  # WOMPI: bridge HTTPS → app (foody://plan). Fallback web = host equipo.
  $wompiWant = "$UrlApi/api/v1/pagos/retorno-app"
  if ($env -match '(?m)^WOMPI_REDIRECT_URL=') {
    $env = $env -replace '(?m)^WOMPI_REDIRECT_URL=.*$', "WOMPI_REDIRECT_URL=$wompiWant"
  } else {
    $env = $env.TrimEnd() + "`nWOMPI_REDIRECT_URL=$wompiWant`n"
  }
  if ($env -match '(?m)^WOMPI_EQUIPO_URL=') {
    $env = $env -replace '(?m)^WOMPI_EQUIPO_URL=.*$', "WOMPI_EQUIPO_URL=$UrlEquipo"
  } else {
    $env = $env.TrimEnd() + "`nWOMPI_EQUIPO_URL=$UrlEquipo`n"
  }
  Set-Content -Path $backendEnv -Value ($env.TrimEnd() + "`n") -Encoding UTF8 -NoNewline
  Write-Host "OK Backend CLIENT_WEB_URL + CORS ($UrlApp, $UrlEquipo, localhost)" -ForegroundColor Green
  Write-Host '   Reinicia Nest si ya estaba corriendo para aplicar CORS.' -ForegroundColor Yellow
}
