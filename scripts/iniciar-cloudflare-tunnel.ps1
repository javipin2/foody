# Foody — arranca el conector Cloudflare Tunnel (PC como servidor público HTTPS)
# Uso: .\scripts\iniciar-cloudflare-tunnel.ps1

$ErrorActionPreference = 'Stop'
$envFile = Join-Path $PSScriptRoot 'cloudflare-tunnel.env'

if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
  Write-Host 'ERROR: Instala cloudflared: winget install Cloudflare.cloudflared' -ForegroundColor Red
  exit 1
}

if (-not (Test-Path $envFile)) {
  Write-Host 'ERROR: Falta scripts/cloudflare-tunnel.env' -ForegroundColor Red
  exit 1
}

function Get-TunnelTokenFromEnv {
  param([string]$Path)
  $raw = Get-Content $Path -Raw
  foreach ($line in ($raw -split "`n")) {
    $line = $line.Trim()
    if ($line -match '^\s*#' -or $line -notmatch 'TUNNEL_TOKEN') { continue }
    if ($line -match 'TUNNEL_TOKEN\s*=\s*(.+)$') {
      $v = $Matches[1].Trim().Trim('"').Trim("'")
      if ($v -match '--token\s+(\S+)') { $v = $Matches[1] }
      # Quitar espacios/saltos si el token se partio al pegar en varias lineas
      return ($v -replace '\s', '')
    }
  }
  return $null
}

$token = Get-TunnelTokenFromEnv -Path $envFile

if ([string]::IsNullOrWhiteSpace($token)) {
  Write-Host 'ERROR: TUNNEL_TOKEN vacio en cloudflare-tunnel.env' -ForegroundColor Red
  Write-Host 'Cloudflare - Tunnels - foody - Instalar conector - copia solo el token eyJ...' -ForegroundColor Yellow
  exit 1
}

if ($token.Length -lt 200) {
  Write-Host "AVISO: token corto ($($token.Length) chars). cloudflared dira si es valido." -ForegroundColor Yellow
}

function Test-ServicioHttp {
  param(
    [string]$Url,
    [int[]]$CodigosOk = @(200)
  )
  try {
    $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 4
    return $CodigosOk -contains [int]$r.StatusCode
  } catch {
    $resp = $_.Exception.Response
    if ($resp) {
      return $CodigosOk -contains [int]$resp.StatusCode
    }
    return $false
  }
}

$checks = @(
  @{ Nombre = 'API NestJS'; Url = 'http://localhost:3000/api/v1/salud'; Ok = @(200) },
  @{ Nombre = 'Supabase'; Url = 'http://localhost:8000'; Ok = @(200, 401, 404) }
)
$fallos = 0
foreach ($c in $checks) {
  if (Test-ServicioHttp -Url $c.Url -CodigosOk $c.Ok) {
    Write-Host "OK $($c.Nombre)" -ForegroundColor Green
  } else {
    $fallos++
    Write-Host "AVISO: $($c.Nombre) no responde en $($c.Url)" -ForegroundColor Yellow
  }
}
if ($fallos -gt 0) {
  Write-Host '       Enciende Docker Desktop + scripts\iniciar-backend-wsl.bat ANTES del tunel.' -ForegroundColor DarkGray
  Write-Host ''
  $cont = Read-Host 'Continuar igual? (s/N)'
  if ($cont -notmatch '^[sS]') { exit 1 }
}

Write-Host ''
Write-Host 'Iniciando tunel Cloudflare (Ctrl+C para detener)...' -ForegroundColor Cyan
Write-Host ''

# ponytail: --token=valor evita que PowerShell interprete guiones del JWT como flags
& cloudflared @('tunnel', '--no-autoupdate', 'run', "--token=$token")
if ($LASTEXITCODE -ne 0) {
  Write-Host ''
  Write-Host 'ERROR: cloudflared rechazo el token (invalido, revocado o de otro tunel).' -ForegroundColor Red
  Write-Host 'Genera uno nuevo: Zero Trust - Networks - Tunnels - foody - Instalar conector' -ForegroundColor Yellow
  Write-Host 'Actualiza TUNNEL_TOKEN en scripts/cloudflare-tunnel.env y vuelve a ejecutar.' -ForegroundColor Yellow
  exit $LASTEXITCODE
}
