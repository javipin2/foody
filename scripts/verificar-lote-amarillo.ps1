# Lote 🟡: QR-MESA, PROMO-MANUAL, FUZZ-PAGE, CAJ/MES-MSG, PED-CHECK (mig 089).
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"
$fallos = 0
function Assert-Ok([bool]$Cond, [string]$Msg) {
  if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
  else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

Write-Host '=== Lote 🟡 bugs ===' -ForegroundColor Cyan
$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
Assert-Ok ([bool]$salud.exito) 'GET /salud'

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal

# QR-MESA-ID-01
$qr = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
  sucursal_id = $sid
  device_id   = 'qa-amarillo-mesa'
  tipo        = 'mesa'
  items       = @(@{ producto_id = 'f0000000-0000-4000-8000-000000000002'; cantidad = 1; precio = 8000 })
}
Assert-Ok (-not $qr.ok -or $qr.status -ge 400) 'tipo=mesa sin mesa_id rechazado'
$code = ''
if ($qr.json) { $code = [string]$qr.json.error }
Assert-Ok ($code -eq 'MESA_REQUERIDA' -or $code -eq 'SOLICITUD_INVALIDA') ("codigo mesa=$code")

# FUZZ-PAGE-01
$fuzz = Invoke-FoodyApi -Path "/usuarios?sucursal_id=$sid&page=-1&limit=999999" -Headers $h
Assert-Ok ($fuzz.status -eq 400 -or ($fuzz.ok -and $fuzz.json.datos.limit -le 100)) 'page=-1/limit enorme no unbounded'

# PED-CHECK
$chk = docker exec supabase-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM pg_constraint WHERE conname='pedidos_estado_check'"
Assert-Ok (([string]$chk).Trim() -eq '1') 'pedidos_estado_check existe'

# PROMO-DEL FK
$fk = docker exec supabase-db psql -U postgres -d postgres -t -A -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='pedidos'::regclass AND contype='f' AND pg_get_constraintdef(oid) ILIKE '%promocion_id%'"
Assert-Ok (([string]$fk) -match 'ON DELETE SET NULL') 'promocion_id ON DELETE SET NULL'

if ($fallos -gt 0) { Write-Host "FAIL=$fallos" -ForegroundColor Red; exit 1 }
Write-Host 'OK verificar-lote-amarillo' -ForegroundColor Green
exit 0
