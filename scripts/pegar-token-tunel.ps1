# Pega el token del tunel Cloudflare y lo guarda en cloudflare-tunnel.env
# Uso: .\scripts\pegar-token-tunel.ps1

$ErrorActionPreference = 'Stop'
$envFile = Join-Path $PSScriptRoot 'cloudflare-tunnel.env'

function Extraer-Token {
  param([string]$Entrada)
  $t = $Entrada.Trim()
  if ($t -match '--token[=\s]+([A-Za-z0-9_-]+)') { return $Matches[1] }
  if ($t -match '(eyJ[A-Za-z0-9_-]+)') { return $Matches[1] }
  return ($t -replace '\s', '')
}

function Probar-Token {
  param([string]$Token)
  if ([string]::IsNullOrWhiteSpace($Token)) {
    return 'vacio'
  }
  return $null
}

Write-Host ''
Write-Host 'Pega el comando COMPLETO de Cloudflare o solo el token eyJ...' -ForegroundColor Cyan
Write-Host 'Dashboard: Zero Trust - Networks - Tunnels - foody - Install connector' -ForegroundColor DarkGray
Write-Host 'Tip: pega primero en Bloc de notas y copia de ahi la linea entera.' -ForegroundColor DarkGray
Write-Host ''
$entrada = Read-Host 'Pegar aqui'
$token = Extraer-Token $entrada
$err = Probar-Token $token
if ($err) {
  Write-Host ''
  Write-Host "ERROR: token invalido - $err" -ForegroundColor Red
  Write-Host 'El token que ves en pantalla puede estar truncado. Prueba:' -ForegroundColor Yellow
  Write-Host '  1. Tunnels - foody - Rotate token - Install connector (comando nuevo)' -ForegroundColor Yellow
  Write-Host '  2. Copiar TODO el comando cloudflared ... eyJ... hasta el final' -ForegroundColor Yellow
  exit 1
}

if (-not (Test-Path $envFile)) {
  Copy-Item (Join-Path $PSScriptRoot 'cloudflare-tunnel.env.example') $envFile
}

$lineas = Get-Content $envFile
$nuevas = foreach ($linea in $lineas) {
  if ($linea -match '^\s*TUNNEL_TOKEN\s*=') { "TUNNEL_TOKEN=$token" } else { $linea }
}
if (-not ($nuevas -match '^\s*TUNNEL_TOKEN\s*=')) {
  $nuevas += "TUNNEL_TOKEN=$token"
}
Set-Content -Path $envFile -Value $nuevas -Encoding UTF8

Write-Host ''
Write-Host "OK token guardado ($($token.Length) caracteres) en cloudflare-tunnel.env" -ForegroundColor Green
if ($token.Length -lt 200) {
  Write-Host 'AVISO: token corto; si cloudflared falla, rota el token en el dashboard.' -ForegroundColor Yellow
}
Write-Host 'Prueba: .\scripts\iniciar-cloudflare-tunnel.ps1' -ForegroundColor Cyan
