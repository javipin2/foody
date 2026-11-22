# Foody — IP LAN para APK / movil fisico (misma Wi-Fi que el PC)
# Uso: .\scripts\sincronizar-ip-movil.ps1
# Solo actualiza ipLan + usarTunel=false. NO borra hostApp/hostApi/foodyy.store.
# Para tunel otra vez: .\scripts\sincronizar-url-tunel.ps1

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$config = Join-Path $raiz 'lib\core\constantes\configuracion.dart'

# IPv4 de la interfaz Wi-Fi/Ethernet (no virtual WSL/Docker)
$ip = Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {
    $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and
    $_.InterfaceAlias -notmatch 'vEthernet|WSL|Loopback|VirtualBox|VMware|Docker'
  } |
  Sort-Object -Property InterfaceMetric |
  Select-Object -ExpandProperty IPAddress -First 1

if (-not $ip) {
  Write-Host 'ERROR: No se detecto IP LAN. Configura ipLan manualmente en configuracion.dart' -ForegroundColor Red
  exit 1
}

Write-Host "IP LAN detectada: $ip" -ForegroundColor Cyan

if (-not (Test-Path $config)) {
  Write-Host "ERROR: no existe $config" -ForegroundColor Red
  exit 1
}

$c = Get-Content $config -Raw -Encoding UTF8

# Solo LAN: apaga tunel; conserva hosts foodyy.store para cuando vuelvas a sincronizar-url-tunel
$c = $c -replace 'usarTunel\s*=\s*true', 'usarTunel = false'
$c = $c -replace "static const String ipLan = '[^']*'", "static const String ipLan = '$ip'"

# Si faltan hosts (archivo muy viejo), no inventar plantilla completa: avisar
if ($c -notmatch 'hostApi') {
  Write-Host 'AVISO: configuracion.dart incompleta. Restaura con .\scripts\sincronizar-url-tunel.ps1' -ForegroundColor Yellow
}

Set-Content -Path $config -Value $c.TrimEnd() -Encoding UTF8
Write-Host "OK ipLan=$ip | usarTunel=false (hosts foodyy.store conservados)" -ForegroundColor Green
Write-Host '   Hot restart Flutter / rebuild APK para aplicar.' -ForegroundColor Yellow

# Comprobar API desde la LAN
$salud = $null
try {
  $salud = Invoke-WebRequest -Uri "http://${ip}:3000/api/v1/salud" -UseBasicParsing -TimeoutSec 5
} catch {}

if ($salud -and $salud.StatusCode -eq 200) {
  Write-Host "OK API http://${ip}:3000/api/v1/salud" -ForegroundColor Green
} else {
  Write-Host "AVISO: API no responde en http://${ip}:3000 - backend encendido?" -ForegroundColor Yellow
  Write-Host '       Firewall (admin):' -ForegroundColor Yellow
  Write-Host '       netsh advfirewall firewall add rule name="Foody API 3000" dir=in action=allow protocol=TCP localport=3000' -ForegroundColor DarkGray
  Write-Host '       netsh advfirewall firewall add rule name="Foody Supabase 8000" dir=in action=allow protocol=TCP localport=8000' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'Siguiente: flutter build apk --release (misma WiFi PC+movil)' -ForegroundColor Cyan
Write-Host 'Fuera de casa: .\scripts\sincronizar-url-tunel.ps1 + docs/CLOUDFLARE_TUNNEL_FOODY.md' -ForegroundColor DarkGray
