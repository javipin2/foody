@echo off
chcp 65001 >nul
title Foody — Desarrollo

if exist "%~dp0_foody-rutas.bat" (
  call "%~dp0_foody-rutas.bat"
) else (
  call "C:\Users\javier\Videos\usb\FOODY APP\scripts\_foody-rutas.bat"
)

echo.
echo  [1/4] Sincronizando .env del backend (Supabase)...
call "%~dp0sincronizar-env-backend.bat" >nul 2>&1
if errorlevel 1 (
  echo  AVISO: No se pudo sincronizar .env. Ejecuta sincronizar-env-backend.bat manualmente.
) else (
  echo  OK - foody_backend\.env actualizado
)

echo.
echo  [2/4] Comprobando Docker (Supabase)...
docker info >nul 2>&1
if errorlevel 1 (
  echo  AVISO: Docker Desktop no responde. Enciendelo y espera a que supabase este en verde.
) else (
  echo  OK - Docker activo (Supabase/Postgres)
)

echo.
echo  [3/4] Arrancando API NestJS (WSL)...
call "%~dp0verificar-backend.bat"
if errorlevel 1 (
  echo  API ausente o desactualizada — reiniciando...
  start "" cmd /k call "%SCRIPTS%iniciar-backend-wsl.bat"
  echo  Esperando API en http://localhost:3000 ...
  set /a INTENTOS=0
  :esperar_api
  timeout /t 3 /nobreak >nul
  call "%~dp0verificar-backend.bat"
  if not errorlevel 1 goto api_lista
  set /a INTENTOS+=1
  if %INTENTOS% lss 40 goto esperar_api
  echo.
  echo  ERROR: La API no respondio en 2 minutos.
  echo  Revisa la ventana "Foody — API NestJS (WSL)".
  pause
  exit /b 1
) else (
  echo  OK - API ya estaba corriendo
)
:api_lista

echo.
echo  [4/4] Iniciando Flutter (Chrome)...
cd /d "%FOODY_RAIZ%"
flutter run -d chrome

pause
