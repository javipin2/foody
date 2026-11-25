@echo off
chcp 65001 >nul
title Foody API NestJS puerto 3000

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

where node >nul 2>&1
if errorlevel 1 (
  echo.
  echo  ERROR: Node.js no esta en PATH de Windows.
  echo  Instala LTS desde nodejs.org y vuelve a abrir esta ventana.
  pause
  exit /b 1
)

echo.
echo  ========================================
echo   Foody - Backend NestJS puerto 3000
echo  ========================================
echo.
echo  Proyecto: %FOODY_RAIZ%
echo  Node:
node -v
echo.

docker info >nul 2>&1
if errorlevel 1 (
  echo  AVISO: Docker Desktop no responde.
  echo         Enciendelo antes del backend - Supabase Postgres puerto 5432.
  echo.
) else (
  echo  OK - Docker activo
  echo.
)

call "%~dp0verificar-backend.bat" >nul 2>&1
if not errorlevel 1 (
  powershell -NoProfile -Command ^
    "$c = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1; if (-not $c) { exit 2 }; try { $p = Get-Process -Id $c.OwningProcess -ErrorAction Stop; $b = Get-Item '%FOODY_RAIZ%\foody_backend\dist\main.js' -ErrorAction Stop; if ($b.LastWriteTime -gt $p.StartTime) { exit 3 }; exit 0 } catch { exit 2 }"
  if errorlevel 3 goto api_build_posterior
  if errorlevel 1 goto api_runtime_no_verificado
  goto api_ya_corre
)

REM Si una API ocupa el puerto pero no registra las rutas requeridas, no intentes
REM arrancar una segunda instancia encima: conserva el servicio y explica el paso manual.
powershell -NoProfile -Command ^
  "$c = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { exit 0 } else { exit 1 }"
if not errorlevel 1 goto api_ocupada_no_verificada

cd /d "%FOODY_RAIZ%\foody_backend"

if not exist node_modules (
  echo  Instalando dependencias npm install...
  call npm install
  if errorlevel 1 (
    echo  ERROR: npm install fallo.
    pause
    exit /b 1
  )
)

echo  Compilando backend npm run build...
call npm run build
if errorlevel 1 (
  echo.
  echo  ERROR: Compilacion fallida. Corrige los errores TypeScript de arriba.
  echo  Mientras el build falle, el puerto 3000 dara rechazo de conexion.
  pause
  exit /b 1
)

echo.
echo  Arrancando API con Node de Windows...
echo  No usar WSL - sharp y node_modules son binarios de Windows.
echo.
echo  ESPERA hasta ver:
echo    Foody API en http://localhost:3000/api/v1
echo.
echo  Prueba en Chrome:
echo    http://localhost:3000/api/v1/salud
echo.
echo  NO cierres esta ventana ni ejecutes otros comandos aqui.
echo.

node dist/main.js
set ERR=%ERRORLEVEL%

if %ERR% neq 0 (
  echo.
  echo  El proceso termino con codigo %ERR%.
  echo  Causas frecuentes:
  echo    - Docker o Supabase apagado
  echo    - Puerto 3000 ocupado por otro programa
  echo    - .env desactualizado - ejecuta scripts\sincronizar-env-backend.bat
  echo.
)

pause
exit /b %ERR%

:api_ya_corre
echo  La API ya responde en puerto 3000 - ruta salud en api v1
echo  El proceso activo no es anterior al build actual de dist/main.js.
echo  Si quieres reiniciar, cierra la otra ventana del backend primero.
echo.
if "%FOODY_NOPAUSE%"=="1" exit /b 0
pause
exit /b 0

:api_build_posterior
echo.
echo  ERROR: la API responde, pero dist/main.js fue compilado despues del inicio del proceso.
echo  El PID activo conserva codigo anterior en memoria; no se detuvo automaticamente.
echo  Cierra normalmente la ventana anterior del backend y vuelve a ejecutar este iniciador.
echo.
if "%FOODY_NOPAUSE%"=="1" exit /b 3
pause
exit /b 3

:api_runtime_no_verificado
echo.
echo  ERROR: la API responde, pero no pude verificar el proceso y la fecha del build activo.
echo  No se detuvo el proceso ni se inicio una instancia duplicada.
echo  Revisa el PID que escucha en :3000 y vuelve a intentarlo.
echo.
if "%FOODY_NOPAUSE%"=="1" exit /b 2
pause
exit /b 2

:api_ocupada_no_verificada
echo.
echo  ERROR: el puerto 3000 esta ocupado, pero la API no paso las rutas criticas.
echo  No se inicio otra instancia ni se detuvo el proceso activo.
echo  Revisa la ventana del backend Foody que ya esta abierta, detenla de forma
echo  controlada y vuelve a ejecutar este iniciador para compilar y arrancar.
echo  Si no reconoces el proceso que ocupa :3000, no lo cierres; revisa su PID.
echo.
if "%FOODY_NOPAUSE%"=="1" exit /b 1
pause
exit /b 1
