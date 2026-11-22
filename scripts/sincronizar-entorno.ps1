# Foody — sincroniza TODO lo público desde config/foody-entorno.env
# Flutter configuracion.dart + backend CORS/CLIENT_WEB_URL + checklist Cloudflare/OAuth/Supabase
#
# Uso:
#   .\scripts\sincronizar-entorno.ps1           # según MODO=tunel|local del env
#   .\scripts\sincronizar-entorno.ps1 -Modo local
#   .\scripts\sincronizar-entorno.ps1 -Modo tunel
#
# Tras cambiar dominio/puertos: edita config/foody-entorno.env y vuelve a correr esto.
# Luego reinicia Nest si cambió CORS. Rebuild web/APK si cambió usarTunel/hosts.

param(
  [ValidateSet('tunel', 'local', '')]
  [string]$Modo = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

if ($Modo -ne '') { $FoodyModo = $Modo.ToLowerInvariant() }

$usarTunel = $FoodyModo -eq 'tunel'

# IP LAN
$ip = $FoodyIpLan
if ([string]::IsNullOrWhiteSpace($ip)) {
  try {
    $detected = Get-NetIPAddress -AddressFamily IPv4 |
      Where-Object {
        $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and
        $_.InterfaceAlias -notmatch 'vEthernet|WSL|Loopback|VirtualBox|VMware|Docker'
      } |
      Sort-Object InterfaceMetric |
      Select-Object -ExpandProperty IPAddress -First 1
    if ($detected) { $ip = $detected }
  } catch {}
}
if ([string]::IsNullOrWhiteSpace($ip)) { $ip = '192.168.1.2' }

Write-Host '=== Foody entorno (fuente: config/foody-entorno.env) ===' -ForegroundColor Cyan
Write-Host "  MODO=$FoodyModo  DOMINIO=$FoodyDominio" -ForegroundColor White
Write-Host "  App cliente: $FoodyUrlApp" -ForegroundColor White
Write-Host "  Equipo:      $FoodyUrlEquipo" -ForegroundColor White
Write-Host "  API:         $FoodyUrlApi/api/v1  (local :$FoodyPuertoApi)" -ForegroundColor White
Write-Host "  Supabase:    $FoodyUrlSb  (local :$FoodyPuertoSb)" -ForegroundColor White
Write-Host "  Web local:   equipo :$FoodyPuertoEquipo | cliente :$FoodyPuertoCliente" -ForegroundColor White
Write-Host "  ipLan=$ip" -ForegroundColor DarkGray
Write-Host ''

& (Join-Path $PSScriptRoot '_escribir-configuracion-tunel.ps1') `
  -UrlApp $FoodyUrlApp `
  -UrlApi $FoodyUrlApi `
  -UrlSb $FoodyUrlSb `
  -UrlEquipo $FoodyUrlEquipo `
  -UsarTunel:$usarTunel `
  -IpLan $ip `
  -PuertoCliente $FoodyPuertoCliente `
  -PuertoEquipo $FoodyPuertoEquipo `
  -Modo "entorno-$FoodyModo"

Write-Host ''
Write-Host 'Cloudflare Tunnel — Public Hostnames (Rutas):' -ForegroundColor Cyan
Write-Host ("  {0,-28} -> http://127.0.0.1:{1}" -f ($FoodyUrlApp -replace '^https://',''), $FoodyPuertoCliente)
Write-Host ("  {0,-28} -> http://127.0.0.1:{1}" -f ($FoodyUrlEquipo -replace '^https://',''), $FoodyPuertoEquipo)
Write-Host ("  {0,-28} -> http://127.0.0.1:{1}" -f ($FoodyUrlApi -replace '^https://',''), $FoodyPuertoApi)
Write-Host ("  {0,-28} -> http://127.0.0.1:{1}" -f ($FoodyUrlSb -replace '^https://',''), $FoodyPuertoSb)
Write-Host ''
Write-Host 'Google OAuth (consola + Supabase ADDITIONAL_REDIRECT_URLS):' -ForegroundColor Cyan
Write-Host "  Callback:     $FoodyUrlSb/auth/v1/callback"
Write-Host "  Origen JS:    $FoodyUrlApp"
Write-Host "  Origen JS:    $FoodyUrlEquipo"
Write-Host "  Redirects:    $FoodyUrlEquipo/admin/login , $FoodyUrlApp/admin/login , ..."
Write-Host ''
Write-Host 'Siguiente:' -ForegroundColor Yellow
Write-Host '  .\scripts\actualizar-supabase-foodyy-store.ps1   # Auth redirects'
Write-Host '  Reinicia Nest si cambiaste CORS'
Write-Host '  .\scripts\servir-web-tunel-release.ps1            # web public (release)'
Write-Host '  o rebuild APK si usas movil'
