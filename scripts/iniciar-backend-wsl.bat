@echo off
chcp 65001 >nul
title Foody — API NestJS (WSL)

if exist "%~dp0_foody-rutas.bat" (
  call "%~dp0_foody-rutas.bat"
) else (
  call "C:\Users\javier\Videos\usb\FOODY APP\scripts\_foody-rutas.bat"
)

if not exist "%FOODY_RAIZ%\foody_backend\package.json" (
  echo.
  echo  ERROR: No encuentro foody_backend en:
  echo    %FOODY_RAIZ%
  echo  Edita scripts\_foody-rutas.bat
  pause
  exit /b 1
)

where wsl >nul 2>&1
if errorlevel 1 (
  echo  ERROR: WSL no esta instalado.
  pause
  exit /b 1
)

echo.
echo  ========================================
echo   Foody — Backend NestJS (puerto 3000)
echo  ========================================
echo.
echo  Proyecto: %FOODY_RAIZ%
echo  Docker Desktop: encendido (contenedor supabase)
echo.
  echo  ESPERA hasta ver en esta ventana:
  echo    "Nest application successfully started"
  echo    y que "npm run build" termine SIN errores TypeScript.
  echo  Si el build falla, el API queda viejo y Mesas/QR daran 404.
  echo  Luego abre Flutter o recarga Chrome.
echo.
echo  Prueba en Chrome cuando arranque:
echo    http://localhost:3000/api/v1/ciudades
echo.
echo  NO cierres esta ventana.
echo.

wsl -d Ubuntu --cd "%FOODY_RAIZ%\foody_backend" bash -lc "source ~/.nvm/nvm.sh 2>/dev/null || true; if [ ! -d node_modules ]; then npm install; fi; echo Compilando backend...; npm run build || exit 1; exec node dist/main.js"
set ERR=%ERRORLEVEL%

if %ERR% neq 0 (
  echo.
  echo  ERROR al arrancar (codigo %ERR%).
  echo  En Ubuntu: cd foody_backend ^&^& npm install ^&^& npm run build ^&^& node dist/main.js
  echo.
)

pause
exit /b %ERR%
