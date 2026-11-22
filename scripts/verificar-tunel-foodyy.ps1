# Diagnostico tunel: puertos + URLs desde config/foody-entorno.env
# Uso: .\scripts\verificar-tunel-foodyy.ps1

$ErrorActionPreference = 'Continue'
$raiz = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

Write-Host "=== Verificar tunel Foody ($FoodyDominio) ===" -ForegroundColor Cyan
Write-Host "Fuente: config/foody-entorno.env | API :$FoodyPuertoApi | SB :$FoodyPuertoSb | web equipo :$FoodyPuertoEquipo | cliente :$FoodyPuertoCliente" -ForegroundColor DarkGray
Write-Host "Publico: $FoodyUrlApp | $FoodyUrlEquipo | $FoodyUrlApi | $FoodyUrlSb" -ForegroundColor DarkGray
Write-Host ''

$fallos = 0

$cf = Get-Process cloudflared -ErrorAction SilentlyContinue
if ($cf) {
  Write-Host "OK cloudflared corriendo (PID $($cf.Id -join ','))" -ForegroundColor Green
} else {
  Write-Host 'FAIL cloudflared NO esta corriendo -> .\scripts\iniciar-cloudflare-tunnel.ps1' -ForegroundColor Red
  $fallos++
}

function Test-Listen([int]$Port) {
  return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1)
}

$puertos = @(
  @{ N = 'API Nest'; P = $FoodyPuertoApi; Hint = 'cd foody_backend; node dist/main.js' },
  @{ N = 'Supabase Kong'; P = $FoodyPuertoSb; Hint = 'Docker Desktop + stack Supabase' },
  @{ N = 'Flutter equipo (tunel)'; P = $FoodyPuertoEquipo; Hint = '.\scripts\iniciar-flutter-web-tunel.ps1 -Flavor equipo' },
  @{ N = 'Flutter cliente (tunel)'; P = $FoodyPuertoCliente; Hint = '.\scripts\iniciar-flutter-web-tunel.ps1 -Flavor cliente' }
)
foreach ($x in $puertos) {
  if (Test-Listen $x.P) {
    Write-Host "OK $($x.N) escucha :$($x.P)" -ForegroundColor Green
  } else {
    Write-Host "FAIL $($x.N) NO escucha :$($x.P) -> $($x.Hint)" -ForegroundColor Red
    $fallos++
  }
}

$cfg = Join-Path $raiz 'lib\core\constantes\configuracion.dart'
$raw = Get-Content $cfg -Raw -Encoding UTF8
if ($raw -match 'usarTunel\s*=\s*true') {
  Write-Host 'OK configuracion.dart usarTunel = true' -ForegroundColor Green
} else {
  Write-Host 'FAIL usarTunel = false. Ejecuta: .\scripts\sincronizar-entorno.ps1 -Modo tunel' -ForegroundColor Red
  $fallos++
}
$hostApiEsc = [regex]::Escape($FoodyUrlApi)
if ($raw -match "hostApi\s*=\s*'$hostApiEsc'") {
  Write-Host "OK hostApi = $FoodyUrlApi" -ForegroundColor Green
} else {
  Write-Host "AVISO hostApi no es $FoodyUrlApi - .\scripts\sincronizar-entorno.ps1" -ForegroundColor Yellow
}

try {
  $s = Invoke-RestMethod "http://localhost:$FoodyPuertoApi/api/v1/salud" -TimeoutSec 5
  if ($s.exito) { Write-Host 'OK API local /salud' -ForegroundColor Green }
  else { Write-Host 'FAIL API local responde pero exito=false' -ForegroundColor Red; $fallos++ }
} catch {
  Write-Host "FAIL API local no responde :$FoodyPuertoApi" -ForegroundColor Red
  $fallos++
}

Write-Host ''
Write-Host '--- URLs publicas (Cloudflare) ---' -ForegroundColor Cyan
$checks = @(
  @{ U = "$FoodyUrlApi/api/v1/salud"; OkCodes = @(200) },
  @{ U = $FoodyUrlApp; OkCodes = @(200) },
  @{ U = $FoodyUrlEquipo; OkCodes = @(200) },
  @{ U = $FoodyUrlSb; OkCodes = @(200, 401, 404) }
)
foreach ($c in $checks) {
  try {
    $r = Invoke-WebRequest -Uri $c.U -UseBasicParsing -TimeoutSec 15
    $code = [int]$r.StatusCode
    if ($c.OkCodes -contains $code) {
      Write-Host "OK $($c.U) status=$code" -ForegroundColor Green
    } else {
      Write-Host "FAIL $($c.U) status=$code" -ForegroundColor Red
      $fallos++
    }
  } catch {
    $code = $null
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    if ($code -and ($c.OkCodes -contains $code)) {
      Write-Host "OK $($c.U) status=$code (esperado)" -ForegroundColor Green
    } else {
      $msg = $_.Exception.Message
      Write-Host "FAIL $($c.U) code=$code - $msg" -ForegroundColor Red
      $fallos++
    }
  }
}

Write-Host ''
$flutterLocal = (Test-Listen $FoodyPuertoCliente) -or (Test-Listen $FoodyPuertoEquipo)
if ($flutterLocal -and $fallos -gt 0) {
  Write-Host "--- Si $FoodyDominio da Error 522 ---" -ForegroundColor Yellow
  Write-Host "Web local OK. Revisa DNS + Public Hostnames del tunel '$FoodyTunnelNombre':" -ForegroundColor Yellow
  Write-Host "  $($FoodyUrlApp -replace '^https://','')  -> http://127.0.0.1:$FoodyPuertoCliente" -ForegroundColor Cyan
  Write-Host "  $($FoodyUrlEquipo -replace '^https://','') -> http://127.0.0.1:$FoodyPuertoEquipo" -ForegroundColor Cyan
  Write-Host '  (http, NO https). Detalle: docs/CONFIG_ENTORNO_FOODY.md' -ForegroundColor DarkGray
}

if ($fallos -eq 0) {
  Write-Host 'Tunel OK - dominios y puertos estables.' -ForegroundColor Green
  exit 0
}
Write-Host "Fallos: $fallos" -ForegroundColor Red
Write-Host "Causas tipicas: cloudflared apagado, Flutter no en :$FoodyPuertoEquipo/:$FoodyPuertoCliente, usarTunel=false, DNS mal." -ForegroundColor Yellow
Write-Host 'Arranque: .\scripts\iniciar-foody-subdominios.bat | sync: .\scripts\sincronizar-entorno.ps1' -ForegroundColor Cyan
exit 1
