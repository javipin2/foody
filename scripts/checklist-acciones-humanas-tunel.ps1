# Imprime (y opcionalmente copia) lo que debes pegar en UptimeRobot y Wompi.
# Uso: .\scripts\checklist-acciones-humanas-tunel.ps1
#      .\scripts\checklist-acciones-humanas-tunel.ps1 -AbrirNavegador

param([switch]$AbrirNavegador)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

$health = "$FoodyUrlApi/api/v1/health"
$webhook = "$FoodyUrlApi/api/v1/pagos/webhook-wompi"
$redirect = "$FoodyUrlEquipo/admin/panel?seccion=mejorar_plan"

Write-Host ''
Write-Host '=== Acciones humanas (PC + tunel) ===' -ForegroundColor Cyan
Write-Host 'El codigo de Fase 0 ya esta listo. Falta solo esto en dashboards externos.' -ForegroundColor DarkGray
Write-Host ''

Write-Host '1) UptimeRobot — New Monitor' -ForegroundColor Yellow
Write-Host "   URL:      $health"
Write-Host '   Tipo:     HTTPS'
Write-Host '   Interval: 5 minutes'
Write-Host '   Keyword:  "base_datos":true'
Write-Host '   Doc:      docs/MONITOREO_SALUD.md'
Write-Host ''

Write-Host '2) Wompi — Eventos / Webhooks' -ForegroundColor Yellow
Write-Host "   URL:      $webhook"
Write-Host "   Redirect: $redirect"
Write-Host '   Luego:    WOMPI_EVENTS_SECRET en foody_backend/.env + reiniciar Nest'
Write-Host '   Doc:      docs/WOMPI_PRODUCCION.md'
Write-Host '   Check:    .\scripts\verificar-wompi-tunel.ps1'
Write-Host ''

Write-Host '3) Cuando compres VPS' -ForegroundColor Yellow
Write-Host '   Guia:     docs/PREPARACION_VPS.md  (Fase 1)'
Write-Host '   Script:   scripts/setup-ubuntu-vps.sh'
Write-Host '   Preflight:.\scripts\verificar-listo-vps.ps1'
Write-Host ''

try {
  Set-Clipboard -Value $health
  Write-Host 'Clipboard = URL health (UptimeRobot). Cambia a webhook si quieres.' -ForegroundColor Green
} catch {
  Write-Host 'Clipboard no disponible en esta sesion.' -ForegroundColor DarkGray
}

if ($AbrirNavegador) {
  Start-Process 'https://uptimerobot.com/dashboard'
  Start-Process 'https://comercios.wompi.co'
  Start-Process $health
}

Write-Host 'Listo. Cuando crees el monitor / registres el webhook, avisa y marcamos OPS-05/03.' -ForegroundColor Cyan
