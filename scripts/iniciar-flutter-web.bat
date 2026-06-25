@echo off
chcp 65001 >nul
title Foody — Flutter (Chrome)

if exist "%~dp0_foody-rutas.bat" (
  call "%~dp0_foody-rutas.bat"
) else (
  call "C:\Users\javier\Videos\usb\FOODY APP\scripts\_foody-rutas.bat"
)

cd /d "%FOODY_RAIZ%"

echo.
echo  ========================================
echo   Foody — Flutter en Chrome
echo  ========================================
echo.
echo  Antes de continuar:
echo    1. Docker Desktop encendido
echo    2. Backend corriendo (iniciar-backend-wsl.bat)
echo.
pause

flutter run -d chrome

pause
