# Verifica que config/foody-entorno.env se propaga a Flutter + CORS + (opcional) API.
# Uso: .\scripts\verificar-entorno.ps1

$ErrorActionPreference = 'Continue'
$raiz = Split-Path $PSScriptRoot -Parent
Set-Location $raiz
$fallos = 0

. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

Write-Host '=== verificar-entorno ===' -ForegroundColor Cyan
Write-Host "fuente=$FoodyEntornoPath MODO=$FoodyModo DOMINIO=$FoodyDominio" -ForegroundColor DarkGray

# Sync fresco
& (Join-Path $PSScriptRoot 'sincronizar-entorno.ps1') | Out-Null

$dart = Get-Content (Join-Path $raiz 'lib\core\constantes\configuracion.dart') -Raw -Encoding UTF8
$esperados = @(
  @{ N = 'usarTunel'; Ok = ($FoodyModo -eq 'local' -and $dart -match 'usarTunel = false') -or ($FoodyModo -ne 'local' -and $dart -match 'usarTunel = true') },
  @{ N = 'hostApp'; Ok = $dart.Contains("hostApp = '$FoodyUrlApp'") },
  @{ N = 'hostEquipo'; Ok = $dart.Contains("hostEquipo = '$FoodyUrlEquipo'") },
  @{ N = 'hostApi'; Ok = $dart.Contains("hostApi = '$FoodyUrlApi'") },
  @{ N = 'hostSb'; Ok = $dart.Contains("hostSupabase = '$FoodyUrlSb'") },
  @{ N = 'puertoCliente'; Ok = $dart.Contains("puertoWebClienteDev = $FoodyPuertoCliente") },
  @{ N = 'puertoEquipo'; Ok = $dart.Contains("puertoWebEquipoDev = $FoodyPuertoEquipo") }
)
foreach ($e in $esperados) {
  if ($e.Ok) { Write-Host "OK dart $($e.N)" -ForegroundColor Green }
  else { Write-Host "FAIL dart $($e.N)" -ForegroundColor Red; $fallos++ }
}

$benvPath = Join-Path $raiz 'foody_backend\.env'
if (-not (Test-Path $benvPath)) {
  Write-Host 'FAIL falta foody_backend/.env' -ForegroundColor Red
  $fallos++
} else {
  $corsLine = (Get-Content $benvPath -Encoding UTF8 | Where-Object { $_ -match '^CORS_ORIGEN=' } | Select-Object -First 1)
  if (-not $corsLine) {
    Write-Host 'FAIL CORS_ORIGEN ausente' -ForegroundColor Red
    $fallos++
  } else {
    $lista = @(($corsLine -replace '^CORS_ORIGEN=', '') -split ',' | ForEach-Object { $_.Trim() })
    foreach ($o in @($FoodyUrlApp, $FoodyUrlEquipo, "http://localhost:$FoodyPuertoEquipo", "http://localhost:$FoodyPuertoCliente")) {
      if ($lista -contains $o) { Write-Host "OK CORS $o" -ForegroundColor Green }
      else { Write-Host "FAIL CORS falta $o" -ForegroundColor Red; $fallos++ }
    }
    $basura = $lista | Where-Object { $_ -match '^http://localhost:\d+$' -and $_ -notin @(
        "http://localhost:$FoodyPuertoEquipo",
        "http://localhost:$FoodyPuertoCliente",
        'http://localhost:8082',
        'http://localhost:3000'
      ) }
    if ($basura) {
      Write-Host "FAIL CORS basura: $($basura -join ', ')" -ForegroundColor Red
      $fallos++
    } else {
      Write-Host 'OK CORS sin puertos basura' -ForegroundColor Green
    }
  }
}

try {
  $s = Invoke-RestMethod "http://localhost:$FoodyPuertoApi/api/v1/salud" -TimeoutSec 5
  if ($s.exito) { Write-Host "OK API local :$FoodyPuertoApi /salud" -ForegroundColor Green }
  else { Write-Host 'FAIL API local exito=false' -ForegroundColor Red; $fallos++ }
} catch {
  Write-Host "AVISO API local no responde :$FoodyPuertoApi (no cuenta como fallo de config)" -ForegroundColor Yellow
}

if ($fallos -eq 0) {
  Write-Host 'verificar-entorno OK' -ForegroundColor Green
  exit 0
}
Write-Host "verificar-entorno FALLOS=$fallos" -ForegroundColor Red
exit 1
