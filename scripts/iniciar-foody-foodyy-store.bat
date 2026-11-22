@echo off
REM Foody — arranque diario foodyy.store (PC = servidor via Cloudflare Tunnel)
REM Orden: Docker/API ya arriba -> tunel -> Flutter :8080
setlocal
cd /d "%~dp0.."

echo.
echo === Foody foodyy.store ===
echo   https://foodyy.store      -^> localhost:8080  (Flutter)
echo   https://api.foodyy.store  -^> localhost:3000  (Nest)
echo   https://sb.foodyy.store   -^> localhost:8000  (Supabase)
echo   (dominios FIJOS; no cambian al redesplegar)
echo.

REM 1) Sincronizar usarTunel=true + CORS
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sincronizar-url-tunel.ps1"
if errorlevel 1 exit /b 1

REM 2) Verificacion rapida (no bloquea si falla: el tunel script pregunta)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verificar-tunel-foodyy.ps1"
echo.

REM 3) Tunel en ventana aparte (debe quedarse abierta)
start "Foody cloudflared" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iniciar-cloudflare-tunnel.ps1"

timeout /t 3 /nobreak >nul

REM 4) Flutter web :8080 (esta ventana)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iniciar-flutter-web-tunel.ps1" -Flavor equipo

endlocal
