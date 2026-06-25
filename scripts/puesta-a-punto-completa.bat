@echo off
chcp 65001 >nul
title Foody — Puesta a punto (migraciones + backend)

call "%~dp0_foody-rutas.bat" 2>nul
if not defined FOODY_RAIZ set "FOODY_RAIZ=%~dp0.."

echo.
echo  ========================================
echo   Foody — Puesta a punto local
echo  ========================================
echo.

where wsl >nul 2>&1
if errorlevel 1 (
  echo  ERROR: WSL no instalado.
  pause
  exit /b 1
)

echo  [1/4] Comprobando Docker Supabase...
wsl -d Ubuntu docker ps --format "{{.Names}}" | findstr /C:"supabase-db" >nul
if errorlevel 1 (
  echo  ERROR: Contenedor supabase-db no corre. Enciende Docker Desktop.
  pause
  exit /b 1
)
echo       OK supabase-db

echo.
echo  [2/4] Migraciones SQL 026-033...
for %%F in (026_cocinas_kds.sql 027_bloque2_dinero.sql 028_bloque4_seguridad_rls.sql 029_completar_rls_bloque4.sql 030_fix_demo_operacion.sql 031_paso1_demo_recetas.sql 032_costeo_industrial.sql 033_costeo_demo_subreceta_empaque.sql) do (
  echo       ^>^> %%F
  wsl -d Ubuntu bash -c "docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 < '/mnt/c/Users/javier/Videos/usb/FOODY APP/foody_supabase/migrations/%%F'" 
  if errorlevel 1 (
    echo  AVISO: %%F puede fallar si ya estaba aplicada — revisa arriba.
  )
)

echo.
echo  [3/4] Generando .env backend...
wsl -d Ubuntu bash "/mnt/c/Users/javier/Videos/usb/FOODY APP/scripts/generar-env-backend.sh"
if errorlevel 1 (
  echo  AVISO: generar-env fallo; usa foody_backend\.env manual.
)

echo.
echo  [4/4] Compilar backend (WSL)...
wsl -d Ubuntu bash -lc "source ~/.nvm/nvm.sh 2>/dev/null; cd '/mnt/c/Users/javier/Videos/usb/FOODY APP/foody_backend' && npm install && npm run build"
if errorlevel 1 (
  echo  ERROR en build.
  pause
  exit /b 1
)

echo.
echo  Listo. Ahora ejecuta: scripts\iniciar-backend-wsl.bat
echo  Prueba: http://localhost:3000/api/v1/salud
echo.
pause
