@echo off
REM Ejecutar desde la carpeta del proyecto correcta (donde esta main.dart con package:reserva_canchas)
cd /d "c:\Users\javier\Videos\usb\TuCanchaFacil"

echo Limpiando build (libera build\flutter_assets)...
call flutter clean

echo.
echo Obteniendo dependencias...
call flutter pub get

echo.
echo Iniciando en Chrome...
call flutter run -d chrome

pause
