@echo off
chcp 65001 >nul
title Foody — Generar .env backend

if exist "%~dp0_foody-rutas.bat" (
  call "%~dp0_foody-rutas.bat"
) else (
  call "%~dp0_foody-rutas.bat"
)

echo.
echo  Generando foody_backend\.env desde Supabase (WSL)...
echo.

wsl -d Ubuntu sed -i "s/\r$//" "%FOODY_RAIZ%/scripts/generar-env-backend.sh"
wsl -d Ubuntu bash "%FOODY_RAIZ%/scripts/generar-env-backend.sh"

if errorlevel 1 (
  echo.
  echo  ERROR. ¿Supabase corriendo en Docker?
  pause
  exit /b 1
)

echo.
echo  Listo. Reinicia el backend (iniciar-backend-wsl.bat).
echo.
pause
