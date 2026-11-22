# Comprueba config Wompi alineada al tunel (sin imprimir secretos).
# Uso: .\scripts\verificar-wompi-tunel.ps1

$ErrorActionPreference = 'Continue'
$raiz = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

$fallos = 0
$wantRedirect = "$FoodyUrlApi/api/v1/pagos/retorno-app"
$webhook = "$FoodyUrlApi/api/v1/pagos/webhook-wompi"

Write-Host '=== verificar-wompi-tunel ===' -ForegroundColor Cyan
Write-Host "Redirect esperado (bridge app): $wantRedirect" -ForegroundColor DarkGray
Write-Host "Webhook dashboard: $webhook" -ForegroundColor DarkGray

$envPath = Join-Path $raiz 'foody_backend\.env'
if (-not (Test-Path $envPath)) {
  Write-Host 'FAIL falta foody_backend/.env' -ForegroundColor Red
  exit 1
}

$raw = Get-Content $envPath -Raw -Encoding UTF8
if ($raw -match '(?m)^WOMPI_REDIRECT_URL=(.*)$') {
  $got = $Matches[1].Trim()
  if ($got -eq $wantRedirect) {
    Write-Host 'OK WOMPI_REDIRECT_URL = bridge retorno-app' -ForegroundColor Green
  } else {
    Write-Host 'FAIL WOMPI_REDIRECT_URL distinto del bridge retorno-app' -ForegroundColor Red
    Write-Host '  Corre: .\scripts\sincronizar-entorno.ps1' -ForegroundColor Yellow
    $fallos++
  }
} else {
  Write-Host 'FAIL falta WOMPI_REDIRECT_URL' -ForegroundColor Red
  $fallos++
}

if ($raw -match '(?m)^WOMPI_EQUIPO_URL=(.*)$') {
  $eq = $Matches[1].Trim()
  if ($eq -eq $FoodyUrlEquipo) {
    Write-Host 'OK WOMPI_EQUIPO_URL alineado' -ForegroundColor Green
  } else {
    Write-Host "AVISO WOMPI_EQUIPO_URL=$eq (esperado $FoodyUrlEquipo)" -ForegroundColor Yellow
  }
} else {
  Write-Host 'AVISO falta WOMPI_EQUIPO_URL (fallback web del bridge)' -ForegroundColor Yellow
}

$tienePub = $raw -match '(?m)^WOMPI_PUBLIC_KEY=\S+'
$tienePrv = $raw -match '(?m)^WOMPI_PRIVATE_KEY=\S+' -or $raw -match '(?m)^WOMPI_SECRET_KEY=\S+'
$tieneEvents = $raw -match '(?m)^WOMPI_EVENTS_SECRET=\S+' -or $raw -match '(?m)^WOMPI_EVENT_KEY=\S+'
$ambLine = if ($raw -match '(?m)^WOMPI_AMBIENTE=(.*)$') { $Matches[1].Trim() } else { '' }
if ($ambLine -match '^(production|prod)$') { Write-Host 'ambiente=production' -ForegroundColor DarkGray }
elseif ($ambLine -match '^(sandbox|test)?$' -or [string]::IsNullOrWhiteSpace($ambLine)) {
  Write-Host 'ambiente=sandbox (sandbox|test|default)' -ForegroundColor DarkGray
} else {
  Write-Host "AVISO: WOMPI_AMBIENTE='$ambLine' (usa sandbox/test o production)" -ForegroundColor Yellow
}
Write-Host ("claves publicas={0} privadas={1} secreto_eventos={2}" -f $tienePub, $tienePrv, $tieneEvents) -ForegroundColor DarkGray

if (-not $tienePub -or -not $tienePrv) {
  Write-Host 'AVISO: faltan claves Wompi en .env (no bloquea preflight tunel)' -ForegroundColor Yellow
}
if (-not $tieneEvents) {
  Write-Host 'AVISO: falta WOMPI_EVENTS_SECRET (o alias WOMPI_EVENT_KEY) — el webhook rechazara firmas' -ForegroundColor Yellow
}

try {
  # OPTIONS/GET sin firma debe responder (no 502). Body puede ser 400/404/405.
  $r = Invoke-WebRequest -Uri $webhook -Method Get -UseBasicParsing -TimeoutSec 15
  Write-Host "OK webhook reachable status=$($r.StatusCode)" -ForegroundColor Green
} catch {
  $code = $null
  if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
  if ($code -and $code -lt 500) {
    Write-Host "OK webhook reachable status=$code (esperado sin firma)" -ForegroundColor Green
  } else {
    Write-Host "FAIL webhook no alcanzable: $($_.Exception.Message)" -ForegroundColor Red
    $fallos++
  }
}

Write-Host ''
Write-Host 'Dashboard Wompi → Eventos → URL:' -ForegroundColor Cyan
Write-Host "  $webhook"
Write-Host 'Luego pega el secreto de eventos en WOMPI_EVENTS_SECRET y reinicia Nest.'

if ($fallos -eq 0) {
  Write-Host 'verificar-wompi-tunel OK' -ForegroundColor Green
  exit 0
}
Write-Host "verificar-wompi-tunel FALLOS=$fallos" -ForegroundColor Red
exit 1
