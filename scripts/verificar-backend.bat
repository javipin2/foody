@echo off
chcp 65001 >nul
REM Salud 200 + rutas Sprint 5/6/7 (401 sin token, NO 404)
powershell -NoProfile -Command ^
  "$salud = 'http://localhost:3000/api/v1/salud';" ^
  "$probes = @(" ^
  "  'http://localhost:3000/api/v1/combos/00000000-0000-4000-8000-000000000001'," ^
  "  'http://localhost:3000/api/v1/domiciliario/pedidos-asignados'," ^
  "  'http://localhost:3000/api/v1/reportes/financiero'," ^
  "  'http://localhost:3000/api/v1/alertas/c0000000-0000-4000-8000-000000000001'," ^
  "  'http://localhost:3000/api/v1/usuarios'" ^
  ");" ^
  "function Test-Probe($url) {" ^
  "  try { Invoke-WebRequest -Uri $url -TimeoutSec 3 -UseBasicParsing | Out-Null; return $true }" ^
  "  catch { $c = [int]$_.Exception.Response.StatusCode; return ($c -eq 401 -or $c -eq 403) }" ^
  "}" ^
  "try {" ^
  "  $r = Invoke-WebRequest -Uri $salud -TimeoutSec 3 -UseBasicParsing;" ^
  "  if ($r.StatusCode -ne 200) { exit 1 }" ^
  "} catch { exit 1 }" ^
  "foreach ($p in $probes) { if (-not (Test-Probe $p)) { exit 1 } }" ^
  "exit 0"
exit /b %ERRORLEVEL%
