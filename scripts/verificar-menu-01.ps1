# Foody — Verificación de menú público (AQ-SCALE-03)

$ErrorActionPreference = "Stop"

$Base = "http://localhost:3000/api/v1"
$Sucursal = "c0000000-0000-4000-8000-000000000001"

$r = Invoke-RestMethod -Method Get -Uri ($Base + "/menu/" + $Sucursal) -TimeoutSec 30
if (-not $r.exito) {
  Write-Host "FALLO: menu.exito=false"
  exit 1
}

Write-Host "OK: menu exito=true"
exit 0

