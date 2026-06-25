@echo off
REM Parchea el CMake del Firebase C++ SDK para compatibilidad con CMake moderno.
REM Ejecutar si flutter run -d windows falla con error de cmake_minimum_required.

set "FILE=build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt"
if not exist "%FILE%" (
  echo El archivo no existe. Ejecuta primero: flutter build windows
  echo Se extraera el SDK y luego vuelve a ejecutar este script.
  exit /b 1
)

powershell -Command "(Get-Content '%FILE%') -replace 'cmake_minimum_required(VERSION 3.1)', 'cmake_minimum_required(VERSION 3.5)' | Set-Content '%FILE%'"
echo CMake del Firebase SDK actualizado a VERSION 3.5.
echo Vuelve a ejecutar: flutter run -d windows
