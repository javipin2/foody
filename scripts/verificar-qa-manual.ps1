# Puerta QA manual: API automatica + recordatorio checklist UI por rol
# Uso:
#   .\scripts\verificar-qa-manual.ps1           # corre CI rapido + muestra checklist
#   .\scripts\verificar-qa-manual.ps1 -SoloApi  # solo CI rapido (sin mensaje largo)
#   .\scripts\verificar-qa-manual.ps1 -AbrirDoc # abre CHECKLIST_QA_ROLES.md en el editor por defecto
#   .\scripts\verificar-qa-manual.ps1 -FlujoApi  # CI rapido + flujo cruzado API (checklist §4)
#   .\scripts\verificar-qa-manual.ps1 -Realtime   # preflight RT + guia QA UI 2 pestanas
#   .\scripts\verificar-qa-manual.ps1 -RolesApi   # QA roles capa API (§3)
#   .\scripts\verificar-qa-manual.ps1 -Cierre     # suite completa sin VPS

param(
    [switch]$SoloApi,
    [switch]$AbrirDoc,
    [switch]$FlujoApi,
    [switch]$Realtime,
    [switch]$RolesApi,
    [switch]$Cierre
)

$ErrorActionPreference = 'Stop'
$raizRepo = Split-Path $PSScriptRoot -Parent
$checklist = Join-Path $raizRepo 'docs\CHECKLIST_QA_ROLES.md'

Write-Host '=== Foody QA manual (puerta automatica) ===' -ForegroundColor Cyan
Write-Host "Checklist: docs\CHECKLIST_QA_ROLES.md" -ForegroundColor DarkGray
Write-Host ""

& "$PSScriptRoot\verificar-ci.ps1"
$code = $LASTEXITCODE
if ($code -ne 0) {
    Write-Host ""
    Write-Host 'FALLO: API/BD no lista para QA UI. Corrige antes de probar Flutter.' -ForegroundColor Red
    exit $code
}

if ($SoloApi) {
    Write-Host 'API OK (--SoloApi). Ejecuta checklist UI en docs/CHECKLIST_QA_ROLES.md' -ForegroundColor Green
    exit 0
}

if ($FlujoApi) {
    Write-Host ''
    & "$PSScriptRoot\verificar-flujo-cruzado-api.ps1"
    $flujo = $LASTEXITCODE
    if ($flujo -ne 0) {
        Write-Host 'FALLO flujo cruzado API — revisa antes de UI manual' -ForegroundColor Red
        exit $flujo
    }
    Write-Host ''
    Write-Host 'Flujo cruzado API OK — continua con UI manual (checklist §3).' -ForegroundColor Green
}

if ($Realtime) {
    Write-Host ''
    & "$PSScriptRoot\verificar-realtime-qa-manual.ps1"
    exit $LASTEXITCODE
}

if ($RolesApi) {
    Write-Host ''
    & "$PSScriptRoot\verificar-qa-roles-api.ps1"
    exit $LASTEXITCODE
}

if ($Cierre) {
    Write-Host ''
    & "$PSScriptRoot\verificar-cierre-sin-vps.ps1"
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host '========== Siguiente: QA UI manual ==========' -ForegroundColor Yellow
Write-Host @'

Roles a probar (marcar en CHECKLIST_QA_ROLES.md):
  [ ] Cliente          /cliente
  [ ] Mesa QR          /mesa/demo-mesa-1
  [ ] Admin            admin@foody.demo  -> /admin/panel
  [ ] Cocina           cocina@foody.demo -> /admin/cocina
  [ ] Dom. planta      domi@foody.demo   -> /admin/domiciliario
  [ ] Repartidor       repartidor@foody.demo -> /domiciliario/login
  [ ] Super admin      super@foody.demo  -> /admin/foody-control
  [ ] Cajero / Mesero  cajero.test@foody.demo / mesero@foody.com

URLs publicas (tunel): https://foodyy.store  |  API: https://api.foodyy.store/api/v1
Futuro VPS: mismo checklist, cambiar base URL (seccion 6 del doc).

Flujo cruzado API: .\scripts\verificar-qa-manual.ps1 -FlujoApi
Release completo API: .\scripts\verificar-ci.ps1 -Completo

'@ -ForegroundColor White

if ($AbrirDoc -and (Test-Path $checklist)) {
    Start-Process $checklist
}

Write-Host 'Puerta QA OK — continua con UI manual.' -ForegroundColor Green
exit 0
