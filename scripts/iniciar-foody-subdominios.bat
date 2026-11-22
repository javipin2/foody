@echo off
REM Foody — arranque diario PUBLICO (cliente + equipo + tunel)
REM Requiere: Docker arriba + API Nest en :3000 (iniciar-backend-wsl.bat)
REM Rebuild: iniciar-foody-subdominios.bat rebuild
REM Atajo OK: scripts\iniciar1\iniciar-foody-subdominios.bat
setlocal EnableExtensions

set "SCRIPTS=%~dp0"
if not exist "%SCRIPTS%servir-web-tunel-release.ps1" (
  echo ERROR: falta servir-web-tunel-release.ps1 en:
  echo   %SCRIPTS%
  echo Usa scripts\iniciar-foody-subdominios.bat o el atajo en iniciar1\
  goto :pausar_y_salir_error
)

cd /d "%SCRIPTS%.."
if errorlevel 1 (
  echo ERROR: no pude entrar al proyecto
  goto :pausar_y_salir_error
)

echo.
echo === Foody dia (tunel) ===
echo   Carpeta scripts: %SCRIPTS%
echo   1) Docker + API :3000 ya deben estar arriba
echo   2) cloudflared + web equipo:8080 + cliente:8081
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS%_check-api-salud.ps1"
if errorlevel 1 (
  echo.
  echo FAIL: API Nest no responde en :3000
  echo Abre primero: scripts\iniciar-backend-wsl.bat
  goto :pausar_y_salir_error
)
echo OK API :3000

tasklist /FI "IMAGENAME eq cloudflared.exe" 2>NUL | find /I "cloudflared.exe" >NUL
if errorlevel 1 (
  echo Arrancando cloudflared...
  start "Foody cloudflared" powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS%iniciar-cloudflare-tunnel.ps1"
  timeout /t 4 /nobreak >nul
) else (
  echo OK cloudflared ya corria
)

if /I "%~1"=="rebuild" (
  echo Compilando web RELEASE + sirviendo...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS%servir-web-tunel-release.ps1"
) else (
  echo Sirviendo builds existentes (-SkipBuild^)...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS%servir-web-tunel-release.ps1" -SkipBuild
)

if errorlevel 1 (
  echo.
  echo FAIL: no quedaron los dos sitios arriba.
  goto :pausar_y_salir_error
)

echo.
echo OK. Abre:
echo   https://foodyy.store
echo   https://equipo.foodyy.store/admin/login
echo.
echo NO hace falta correr cloudflare aparte.
echo.
goto :pausar_y_salir_ok

:pausar_y_salir_error
if "%FOODY_NOPAUSE%"=="1" exit /b 1
pause
exit /b 1

:pausar_y_salir_ok
if "%FOODY_NOPAUSE%"=="1" exit /b 0
pause
exit /b 0
