# Foody — IP LAN para APK / móvil físico (misma Wi‑Fi que el PC)
# Uso: .\scripts\sincronizar-ip-movil.ps1
# Luego: flutter build apk --release  (o reinstalar debug)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$config = Join-Path $raiz 'lib\core\constantes\configuracion.dart'

# IPv4 de la interfaz Wi‑Fi/Ethernet (no virtual WSL/Docker)
$ip = Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {
    $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and
    $_.InterfaceAlias -notmatch 'vEthernet|WSL|Loopback|VirtualBox|VMware|Docker'
  } |
  Sort-Object -Property InterfaceMetric |
  Select-Object -ExpandProperty IPAddress -First 1

if (-not $ip) {
  Write-Host 'ERROR: No se detectó IP LAN. Configura ipLan manualmente en configuracion.dart' -ForegroundColor Red
  exit 1
}

Write-Host "IP LAN detectada: $ip" -ForegroundColor Cyan

$anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzgwMDE3NzA4LCJleHAiOjE5Mzc2OTc3MDh9.04FH-8DC44nr6aDoM9NGDeQLKsjKurjfnwtUYuFI-eU'
if (Test-Path (Join-Path $raiz 'foody_backend\.env')) {
  $envContent = Get-Content (Join-Path $raiz 'foody_backend\.env') -Raw
  if ($envContent -match 'SUPABASE_ANON_KEY=(.+)') {
    $k = $Matches[1].Trim()
    if ($k.Length -gt 20) { $anonKey = $k }
  }
}

$dart = @"
import 'package:flutter/foundation.dart';

/// Configuración local Foody — generada por scripts/sincronizar-ip-movil.ps1
class Configuracion {
  /// IP de tu PC en la red Wi‑Fi (ipconfig). El móvil NO puede usar localhost ni IP WSL.
  static const String ipLan = '$ip';

  /// Web: localhost. APK / móvil físico: ipLan (misma red Wi‑Fi que el PC).
  static String get urlBackend => kIsWeb
      ? 'http://localhost:3000/api/v1'
      : 'http://`$ipLan:3000/api/v1';

  static String get urlSupabase => kIsWeb
      ? 'http://localhost:8000'
      : 'http://`$ipLan:8000';

  static const String supabaseAnonKey = '$anonKey';

  static const Duration timeoutConexion = Duration(seconds: 10);
  static const Duration timeoutRespuesta = Duration(seconds: 30);
}
"@

Set-Content -Path $config -Value $dart -Encoding UTF8
Write-Host "Actualizado: $config" -ForegroundColor Green

# Comprobar API desde la LAN
$salud = $null
try {
  $salud = Invoke-WebRequest -Uri "http://${ip}:3000/api/v1/salud" -UseBasicParsing -TimeoutSec 5
} catch {}

if ($salud -and $salud.StatusCode -eq 200) {
  Write-Host "OK API http://${ip}:3000/api/v1/salud" -ForegroundColor Green
} else {
  Write-Host "AVISO: API no responde en http://${ip}:3000 - backend encendido (iniciar-backend-wsl.bat)?" -ForegroundColor Yellow
  Write-Host "       Si falla solo desde el móvil, abre firewall (ejecutar como admin):" -ForegroundColor Yellow
  Write-Host "       netsh advfirewall firewall add rule name=`"Foody API 3000`" dir=in action=allow protocol=TCP localport=3000" -ForegroundColor DarkGray
  Write-Host "       netsh advfirewall firewall add rule name=`"Foody Supabase 8000`" dir=in action=allow protocol=TCP localport=8000" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Siguiente paso: reconstruir e instalar APK" -ForegroundColor Cyan
Write-Host "  flutter build apk --release" -ForegroundColor White
Write-Host "Movil y PC deben estar en la MISMA red WiFi." -ForegroundColor White
Write-Host "Fuera de casa (datos moviles) hace falta VPS o tunel (ver docs/MOVIL_RED_LOCAL.md)." -ForegroundColor DarkGray
