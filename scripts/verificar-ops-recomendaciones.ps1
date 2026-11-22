# OPS recomendaciones implementables sin VPS (OPS-02/04 local, FCM-02, STOR-01).
# Uso: .\scripts\verificar-ops-recomendaciones.ps1
# Requiere: API :3000, supabase-db, migr. 078 aplicada.

$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'
$raiz = Split-Path $PSScriptRoot -Parent
$fallos = 0

function Ok([string]$m) { Write-Host "OK  $m" -ForegroundColor Green }
function Fail([string]$m) { Write-Host "FAIL $m" -ForegroundColor Red; $script:fallos++ }

Write-Host '=== Verificar OPS recomendaciones ===' -ForegroundColor Cyan

# --- Migracion 078 ---
$col = docker exec supabase-db psql -U postgres -d postgres -tAc `
  "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='notificaciones_pendientes' AND column_name IN ('intentos','abandonada')"
if ($col.Trim() -eq '2') { Ok 'migr 078 columnas intentos+abandonada' }
else {
  Write-Host 'Aplicando 078...' -ForegroundColor Yellow
  & "$PSScriptRoot\aplicar-migracion-supabase.ps1" 078_ops_fcm_intentos_limpieza.sql
  $col2 = docker exec supabase-db psql -U postgres -d postgres -tAc `
    "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='notificaciones_pendientes' AND column_name IN ('intentos','abandonada')"
  if ($col2.Trim() -eq '2') { Ok 'migr 078 aplicada' } else { Fail "migr 078 columnas=$col2" }
}

# --- Backup script ---
$bak = Join-Path $raiz 'backups'
& "$PSScriptRoot\backup-postgres.ps1" -Destino $bak -RetencionDias 14
$ultimo = Get-ChildItem $bak -Filter 'foody_db-*.sql*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($ultimo -and $ultimo.Length -gt 1000) { Ok "backup $($ultimo.Name) ($($ultimo.Length) bytes)" }
else { Fail 'backup no generado o vacio' }

# --- API ---
try {
  $salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 5
  if (-not $salud.exito) { throw 'salud false' }
  Ok 'API /salud'
} catch {
  Fail "API no responde: $_"
  Write-Host "Fallos: $fallos" -ForegroundColor Red
  exit 1
}

$body = @{ email = 'admin@foody.demo'; contrasena = '123456' } | ConvertTo-Json
$login = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -Body $body -ContentType 'application/json'
if (-not $login.exito) { Fail 'login admin'; exit 1 }
$h = @{ Authorization = "Bearer $($login.datos.token)" }

# --- FCM-02 diagnostico ---
$diag = Invoke-RestMethod -Uri "$base/notificaciones/diagnostico" -Headers $h
if ($null -eq $diag.datos.max_intentos) { Fail 'diagnostico sin max_intentos (API vieja?)' }
else { Ok "FCM max_intentos=$($diag.datos.max_intentos) abandonadas_24h=$($diag.datos.abandonadas_24h)" }

# Inserta notificacion fantasma y prueba formula abandono (mismo UPDATE que el servicio)
$idRaw = docker exec supabase-db psql -U postgres -d postgres -tAc `
  "INSERT INTO notificaciones_pendientes (tipo, payload, intentos, abandonada, enviada)
   VALUES ('ops_test_abandono', '{}'::jsonb, 9, false, false)
   RETURNING id;"
$id = ([regex]::Match($idRaw, '[0-9a-fA-F-]{36}')).Value
if (-not $id) { Fail "no uuid notificacion: $idRaw"; exit 1 }
docker exec supabase-db psql -U postgres -d postgres -tAc `
  "UPDATE notificaciones_pendientes
   SET intentos = intentos + 1, abandonada = (intentos + 1 >= 10)
   WHERE id = '$id';" | Out-Null
$abd = (docker exec supabase-db psql -U postgres -d postgres -tAc `
  "SELECT abandonada::text || ',' || intentos::text FROM notificaciones_pendientes WHERE id = '$id';").Trim()
if ($abd -match '^(t|true),10$') { Ok "FCM abandono formula SQL ($abd)" }
else { Fail "FCM abandono esperado t|true,10 got '$abd'" }
docker exec supabase-db psql -U postgres -d postgres -tAc `
  "DELETE FROM notificaciones_pendientes WHERE id = '$id';" | Out-Null

# --- STOR-01 ---
$suc = (docker exec supabase-db psql -U postgres -d postgres -tAc `
  "SELECT id FROM sucursales LIMIT 1;").Trim()
$promoRaw = docker exec supabase-db psql -U postgres -d postgres -tAc `
  "INSERT INTO estados_promociones (sucursal_id, titulo, imagen_url, expira_at, activa)
   VALUES ('$suc', 'ops_test_limpieza', 'https://example.com/fake.webp', now() - interval '10 days', false)
   RETURNING id;"
$promoId = ([regex]::Match($promoRaw, '[0-9a-fA-F-]{36}')).Value
$lim = Invoke-RestMethod -Uri "$base/promociones/admin/limpiar-expiradas" -Method POST -Headers $h
if ($lim.exito -and $lim.datos.filas -ge 1) { Ok "STOR-01 limpieza filas=$($lim.datos.filas) storage=$($lim.datos.objetos_storage)" }
else {
  $queda = (docker exec supabase-db psql -U postgres -d postgres -tAc `
    "SELECT COUNT(*) FROM estados_promociones WHERE id = '$promoId';").Trim()
  if ($queda -eq '0') { Ok 'STOR-01 fila borrada (respuesta parcial)' }
  else { Fail "STOR-01 no limpio promo $promoId resp=$($lim | ConvertTo-Json -Compress)" }
}
docker exec supabase-db psql -U postgres -d postgres -tAc `
  "DELETE FROM estados_promociones WHERE titulo = 'ops_test_limpieza';" | Out-Null

Write-Host ''
if ($fallos -eq 0) {
  Write-Host 'Verificacion OPS OK' -ForegroundColor Green
  exit 0
}
Write-Host "Fallos: $fallos" -ForegroundColor Red
exit 1
