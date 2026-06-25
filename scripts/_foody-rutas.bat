@echo off
REM Edita estas rutas si mueves el proyecto
set "FOODY_RAIZ=C:\Users\javier\Videos\usb\FOODY APP"
set "FOODY_RAIZ_WSL=/mnt/c/Users/javier/Videos/usb/FOODY APP"
for %%I in ("%FOODY_RAIZ%") do set "FOODY_RAIZ=%%~fI"
set "SCRIPTS=%FOODY_RAIZ%\scripts\"
