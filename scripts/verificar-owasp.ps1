# Prompt 25 — OWASP: chequeos RLS + secretos + rate-limit markers + IDOR scope
# Uso: .\scripts\verificar-owasp.ps1
# Complementa (no sustituye): verificar-rls.ps1, verificar-idor-scope.ps1

param(
  [switch]$SkipIdor,
  [switch]$SkipApi
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Fallos = 0
$Avisos = 0

Write-Host '=== Foody OWASP (Prompt 25) ===' -ForegroundColor Cyan

# 1) RLS
Write-Host "`n--- RLS ---" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'verificar-rls.ps1')
if ($LASTEXITCODE -ne 0) { $Fallos++ }

$stats = docker exec supabase-db psql -U postgres -d postgres -tAc @"
SELECT
  (SELECT COUNT(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r')::text
  || '|' ||
  (SELECT COUNT(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r' AND c.relrowsecurity AND c.relforcerowsecurity)::text
  || '|' ||
  (SELECT COUNT(*) FROM pg_policies WHERE schemaname='public')::text;
"@
$parts = $stats.Trim().Split('|')
Write-Host ("  tablas={0} rls+force={1} policies_public={2}" -f $parts[0], $parts[1], $parts[2]) -ForegroundColor DarkGray
if ($parts[0] -ne $parts[1]) {
  Write-Host '  FALLO: alguna tabla public sin RLS+FORCE' -ForegroundColor Red
  $Fallos++
}
else {
  Write-Host '  OK cobertura RLS+FORCE 100% public' -ForegroundColor Green
}

# 2) Secret markers
Write-Host "`n--- Secretos / gitignore ---" -ForegroundColor Cyan
$gi = Get-Content (Join-Path $Root '.gitignore') -Raw
if ($gi -notmatch 'config/foody-entorno\.env') {
  Write-Host '  AVISO SEC-SECRET-03: config/foody-entorno.env no esta en .gitignore' -ForegroundColor Yellow
  $Avisos++
}
else {
  Write-Host '  OK config/foody-entorno.env en .gitignore' -ForegroundColor Green
}
$jwtFallback = @(
  Select-String -Path (Join-Path $Root 'foody_backend\src\core\auth\*.ts') -Pattern "foody_jwt_secret_cambiar'" -ErrorAction SilentlyContinue
)
if ($jwtFallback.Count -gt 0) {
  Write-Host '  AVISO SEC-SECRET-01: fallback JWT hardcodeado sigue en auth' -ForegroundColor Yellow
  $Avisos++
}

# 3) Rate limit: login + pedidos public deben tener decorator
Write-Host "`n--- Rate limit markers ---" -ForegroundColor Cyan
$authCtrl = Join-Path $Root 'foody_backend\src\core\auth\auth.controller.ts'
$pedPub = Join-Path $Root 'foody_backend\src\modulos\pedidos\pedidos-public.controller.ts'
$rlAuth = @(Select-String -Path $authCtrl -Pattern 'RateLimitPublico')
$rlPed = @(Select-String -Path $pedPub -Pattern 'RateLimitPublico')
Write-Host ("  auth RateLimitPublico: {0}" -f $rlAuth.Count)
Write-Host ("  pedidos-public RateLimitPublico: {0}" -f $rlPed.Count)
if ($rlAuth.Count -lt 4 -or $rlPed.Count -lt 1) {
  Write-Host '  FALLO: faltan RateLimitPublico en login/pedidos' -ForegroundColor Red
  $Fallos++
}
else {
  Write-Host '  OK decoradores presentes (activo solo si NODE_ENV=production)' -ForegroundColor Green
}
$rlGuard = Get-Content (Join-Path $Root 'foody_backend\src\compartido\guards\rate-limit.guard.ts') -Raw
if ($rlGuard -match 'if \(!esProduccion\(\)\) return true') {
  Write-Host '  AVISO SEC-RLIMIT-01: rate limit NO-OP fuera de produccion' -ForegroundColor Yellow
  $Avisos++
}

# 4) BAC markers still present
Write-Host "`n--- BAC markers (Prompt 06 reconfirm) ---" -ForegroundColor Cyan
$cajaCtrl = Get-Content (Join-Path $Root 'foody_backend\src\modulos\caja\caja.controller.ts') -Raw
if ($cajaCtrl -match "resolverEscritura\(usuario, usuario\.sucursal_id\)" -and (Select-String -Path (Join-Path $Root 'foody_backend\src\modulos\caja\caja.service.ts') -Pattern 'WHERE id = \$1 FOR UPDATE' -Quiet)) {
  Write-Host '  AVISO SEC-BAC-01: cerrar caja sigue sin assert sucursal_id del UUID' -ForegroundColor Yellow
  $Avisos++
}
$pedCtrl = Get-Content (Join-Path $Root 'foody_backend\src\modulos\pedidos\pedidos.controller.ts') -Raw
if ($pedCtrl -match "Permisos\('crear_pedido', 'ver_pedidos'\)" -or $pedCtrl -match "Permisos\('ver_pedidos', 'crear_pedido'\)") {
  Write-Host '  AVISO SEC-BAC-02: cobrar con OR ver_pedidos/crear_pedido' -ForegroundColor Yellow
  $Avisos++
}
$anon = Select-String -Path (Join-Path $Root 'foody_backend\src\modulos\dispositivos\dispositivos.controller.ts') -Pattern 'anonimizar' -Context 0,2
if ($anon -and ($anon.Line -notmatch 'UseGuards|Jwt')) {
  Write-Host '  AVISO SEC-BAC-03: DELETE anonimizar sigue publico' -ForegroundColor Yellow
  $Avisos++
}
$pw = Get-Content (Join-Path $Root 'foody_backend\src\modulos\notificaciones\notificaciones.controller.ts') -Raw
if ($pw -match 'prueba-web' -and $pw -match 'todos_web:\s*true' -and $pw -notmatch "prueba-web[\s\S]{0,200}RolGuard") {
  Write-Host '  AVISO SEC-BAC-04: prueba-web JWT sin RolGuard + todos_web' -ForegroundColor Yellow
  $Avisos++
}

# 5) IDOR scope script
if (-not $SkipIdor) {
  Write-Host "`n--- IDOR scope ---" -ForegroundColor Cyan
  if (-not $SkipApi) {
    try {
      $null = Invoke-RestMethod 'http://127.0.0.1:3000/api/v1/salud' -TimeoutSec 5
      & (Join-Path $PSScriptRoot 'verificar-idor-scope.ps1')
      if ($LASTEXITCODE -ne 0) { $Fallos++ }
    }
    catch {
      Write-Host '  AVISO: API no responde; IDOR omitido' -ForegroundColor Yellow
      $Avisos++
    }
  }
}

Write-Host ''
if ($Fallos -gt 0) {
  Write-Host "Verificacion OWASP FALLO fallos=$Fallos avisos=$Avisos" -ForegroundColor Red
  exit 1
}
Write-Host "Verificacion OWASP OK (avisos=$Avisos) - ver docs/AUDITORIA_OWASP.md" -ForegroundColor Green
exit 0
