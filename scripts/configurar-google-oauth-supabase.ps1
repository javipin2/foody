# Foody — configura Google OAuth en Supabase self-hosted (WSL).
# Uso:
#   .\scripts\configurar-google-oauth-supabase.ps1 `
#     -ClientId "xxx.apps.googleusercontent.com" `
#     -ClientSecret "GOCSPX-xxx"
#
# Sin credenciales solo prepara docker-compose (no activa Google).

param(
    [string]$ClientId = '',
    [string]$ClientSecret = '',
    [int]$WebPort = 8080
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$bashScript = Join-Path $PSScriptRoot 'configurar-google-oauth-supabase.sh'

if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Host 'ERROR: WSL no disponible.' -ForegroundColor Red
    exit 1
}

# Normalizar finales de línea del script bash (Windows → Unix)
$content = Get-Content $bashScript -Raw
$content = $content -replace "`r`n", "`n"
$wslPath = '/mnt/c/Users/javier/Videos/usb/FOODY APP/scripts/configurar-google-oauth-supabase.sh'
# LF puro (evita errores en bash/WSL)
$unixContent = ($content -replace "`r`n", "`n") -replace "`r", ""
[System.IO.File]::WriteAllText((Join-Path $root 'scripts\configurar-google-oauth-supabase.sh'), $unixContent, [System.Text.UTF8Encoding]::new($false))

if ([string]::IsNullOrWhiteSpace($ClientId) -or [string]::IsNullOrWhiteSpace($ClientSecret)) {
    Write-Host ''
    Write-Host '=== Credenciales Google OAuth requeridas ===' -ForegroundColor Yellow
    Write-Host @'

1. Abre https://console.cloud.google.com/apis/credentials
2. Crear credenciales → ID de cliente OAuth → Aplicación web
3. URI de redirección autorizada:
      http://localhost:8000/auth/v1/callback
   (NO uses IP 192.168.x.x — Google la rechaza)
4. Orígenes JavaScript autorizados:
      http://localhost:8080

5. Vuelve a ejecutar:
   .\scripts\configurar-google-oauth-supabase.ps1 `
     -ClientId "TU_ID.apps.googleusercontent.com" `
     -ClientSecret "TU_SECRET"

'@ -ForegroundColor White
    exit 1
}

$env:GOOGLE_CLIENT_ID = $ClientId.Trim()
$env:GOOGLE_CLIENT_SECRET = $ClientSecret.Trim()
$env:FLUTTER_WEB_PORT = "$WebPort"

wsl -e bash -lc "chmod +x '$wslPath' && GOOGLE_CLIENT_ID='$($env:GOOGLE_CLIENT_ID)' GOOGLE_CLIENT_SECRET='$($env:GOOGLE_CLIENT_SECRET)' FLUTTER_WEB_PORT='$WebPort' '$wslPath'"

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host 'Flutter web: usa puerto fijo para que coincidan los redirects:' -ForegroundColor Cyan
Write-Host "  .\scripts\flutter-run-flavor.ps1 -Flavor equipo -WebPort $WebPort" -ForegroundColor White
