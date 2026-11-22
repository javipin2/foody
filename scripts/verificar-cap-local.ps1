# Foody — Verificación CAP local (multi-instancia sin VPS)
#
# Objetivo:
# - Levantar un segundo backend en puerto distinto
# - Verificar salud en ambos
# - Verificar rate-limit compartido en Postgres (429) alternando puertos
#
# Nota:
# - Esto no sustituye PM2/PgBouncer en producción. Es una evidencia funcional de multi-instancia.

$ErrorActionPreference = "Stop"

$Base3000 = "http://localhost:3000/api/v1"
$Base3001 = "http://localhost:3001/api/v1"

$Email = "admin@foody.demo"
$Pass = "wrongpass"

$ipHeader = "9.9.9.9" # clave de rate-limit usa IP del header

function Get-PidByPort([int]$Port) {
  $c = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -eq $c) { return $null }
  return $c.OwningProcess
}

function Invoke-Health([string]$Base) {
  $r = Invoke-RestMethod -Method Get -Uri ($Base + "/salud") -TimeoutSec 10
  if (-not $r.exito) { throw "Health exito=false en $Base" }
}

function Try-429([string]$Base, [int]$i) {
  $body = @{ email = $Email; contrasena = $Pass } | ConvertTo-Json -Compress -Depth 6
  $headers = @{ "x-forwarded-for" = $ipHeader }
  try {
    Invoke-WebRequest -Method Post `
      -Uri ($Base + "/auth/login") `
      -ContentType "application/json" `
      -Headers $headers `
      -Body $body `
      -TimeoutSec 5 | Out-Null

    # Si llega acá, inesperado (debería ser 401 o 429 por password wrong).
    return $false
  } catch {
    $code = 0
    if ($_.Exception.Response) {
      try { $code = [int]$_.Exception.Response.StatusCode.value__ } catch { }
    }
    return ($code -eq 429)
  }
}

Write-Host "=== Verificar CAP local (multi-instancia) ===" -ForegroundColor Cyan

# 1) Asegurar que :3000 está arriba
Invoke-Health $Base3000
Write-Host "OK salud :3000" -ForegroundColor Green

# 2) Subir un segundo backend en :3001 si no existe
$pid3001 = Get-PidByPort 3001
if ($null -eq $pid3001) {
  Write-Host "Levantando backend secundario en :3001..." -ForegroundColor Yellow
  $repoRoot = Split-Path -Parent $PSScriptRoot
  $backendDir = Join-Path $repoRoot "foody_backend"
  $logPath = Join-Path $repoRoot "._cap_local_3001.log"
  $errPath = Join-Path $repoRoot "._cap_local_3001.err"
  # Ponemos RATE_LIMIT_FORZAR=1 y PUERTO=3001 para evidenciar multi-instancia sin VPS.
  # backtick antes de $ para que se ejecute en el proceso hijo (no interpolación del padre).
  $cmd = "`$env:RATE_LIMIT_FORZAR='1'; `$env:PUERTO='3001'; npm run start:prod"
  Start-Process -FilePath "powershell" -WindowStyle Hidden -PassThru `
    -WorkingDirectory $backendDir `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd) `
    -RedirectStandardOutput $logPath `
    -RedirectStandardError $errPath | Out-Null

  # Esperar salud (hasta 60s)
  $ok = $false
  for ($t = 0; $t -lt 240; $t = $t + 1) {
    Start-Sleep -Milliseconds 250
    try {
      if (Get-PidByPort 3001) {
        Invoke-Health $Base3001
        $ok = $true
        break
      }
    } catch { }
  }
  if (-not $ok) {
    $pidFinal = Get-PidByPort 3001
    $tail = ""
    try {
      if (Test-Path $logPath) {
        $tail = (Get-Content $logPath -Tail 80 | Out-String)
      }
    } catch { }
    try {
      if (Test-Path $errPath) {
        $tail = $tail + "`n--- stderr ---`n" + (Get-Content $errPath -Tail 80 | Out-String)
      }
    } catch { }
    throw "Backend :3001 no levantó salud en tiempo (pid=$pidFinal). Logs:$logPath / $errPath`n$tail"
  }
  Write-Host "OK salud :3001" -ForegroundColor Green
} else {
  Write-Host ":3001 ya estaba arriba (PID=$pid3001). Se usará solo verificación." -ForegroundColor Yellow
}

# 3) Rate-limit compartido (Postgres): alternar puertos con misma IP header
Write-Host "Verificando 429 compartido entre :3000 y :3001..." -ForegroundColor Yellow
$hit = $false

for ($i = 0; $i -lt 60; $i = $i + 1) {
  $base = if (($i % 2) -eq 0) { $Base3000 } else { $Base3001 }
  if (Try-429 -Base $base -i $i) {
    Write-Host "HIT 429 en iteración $i (puerto alterno)" -ForegroundColor Green
    $hit = $true
    break
  }
}

if (-not $hit) {
  throw "No se obtuvo 429 en el rango de iteraciones: revisar RATE_LIMIT_FORZAR y/o ENTRORNO"
}

Write-Host "Verificacion CAP local OK" -ForegroundColor Green
exit 0

