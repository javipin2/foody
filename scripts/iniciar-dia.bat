@echo off
chcp 65001 >nul
title Foody — Arranque del dia

echo.
echo  ========================================
echo   Foody — Arranque completo (recomendado)
echo  ========================================
echo.
echo  1) Docker Desktop (contenedor supabase en verde)
echo  2) API NestJS en WSL (ventana aparte, puerto 3000)
echo  3) Flutter Chrome
echo.
echo  El contenedor "foodyapp" detenido es NORMAL si usas Supabase.
echo  Sin la API NestJS la app muestra error al cargar ciudades.
echo.
pause

call "%~dp0iniciar-foody-dev.bat"
