# Verifica contrato Realtime Foody (emisores backend + coalesce Flutter)
# Uso: .\scripts\verificar-realtime.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

Write-Host '=== Verificar Realtime Foody ===' -ForegroundColor Cyan

$fallos = 0

function Test-Contiene {
    param([string]$Path, [string]$Patron, [string]$Etiqueta)
    if (-not (Test-Path $Path)) {
        Write-Host "FALLO $Etiqueta : no existe $Path" -ForegroundColor Red
        $script:fallos++
        return
    }
    $txt = Get-Content $Path -Raw
    if ($txt -match $Patron) {
        Write-Host "OK $Etiqueta" -ForegroundColor Green
    }
    else {
        Write-Host "FALLO $Etiqueta" -ForegroundColor Red
        $script:fallos++
    }
}

$rtBackend = Join-Path $root 'foody_backend\src\core\realtime\realtime-broadcast.service.ts'
$rtFlutter = Join-Path $root 'lib\core\realtime\foody_realtime.dart'
$caja = Join-Path $root 'foody_backend\src\modulos\caja\caja.service.ts'
$dispatch = Join-Path $root 'foody_backend\src\modulos\domiciliarios\dispatch.service.ts'

Test-Contiene $rtBackend 'event_id:\s*randomUUID' 'payload event_id UUID'
Test-Contiene $rtBackend 'ubicacionRepartidor' 'emisión ubicacion_repartidor'
Test-Contiene $rtBackend 'llamarMesera' 'emisión llamar_mesera'
Test-Contiene $rtBackend 'ofertaExpirada' 'emisión oferta_expirada'
Test-Contiene $rtBackend 'pedidoDesasignado' 'emisión pedido_desasignado'

Test-Contiene $rtFlutter "'pedido_actualizado'" 'coalesce re-emite pedido_actualizado'
Test-Contiene $rtFlutter "'mesas_actualizadas'" 'coalesce re-emite mesas_actualizadas'
Test-Contiene $rtFlutter "'llamar_mesera'" 'suscripción llamar_mesera'
Test-Contiene $rtFlutter 'ubicacion_repartidor' 'suscripción ubicacion_repartidor'
Test-Contiene $rtFlutter 'pedido_desasignado' 'suscripción pedido_desasignado'
Test-Contiene $rtFlutter 'oferta_expirada' 'suscripción oferta_expirada'

Test-Contiene $caja "tipo: 'cierre'" 'caja_movimiento cierre'
Test-Contiene $caja "tipo: 'retiro'" 'caja_movimiento retiro'
Test-Contiene $caja "tipo: 'gasto'" 'caja_movimiento gasto'
Test-Contiene $caja "tipo: 'devolucion'" 'caja_movimiento devolucion'

Test-Contiene $dispatch 'ofertaExpirada' 'dispatch notifica oferta expirada'
Test-Contiene $rtBackend 'canalPedidoSeguimiento' 'canal pedido opaco RT-9'
Test-Contiene $rtFlutter 'canalPedidoSeguimiento' 'Flutter canal pedido opaco'

$banner = Join-Path $root 'lib\features\admin\presentation\widgets\realtime_aviso_banner.dart'
Test-Contiene $banner 'RealtimeAvisoBanner' 'widget banner RT degradado (0.3)'
Test-Contiene $banner 'verificarRealtime' 'banner consulta salud realtime'

# Salud liviana + realtime en /health (verificarCompleto), no en /salud
$baseUrl = 'http://localhost:3000/api/v1'
try {
    $salud = Invoke-RestMethod -Uri "$baseUrl/salud" -TimeoutSec 8
    if ($salud.exito) {
        Write-Host 'OK GET /salud' -ForegroundColor Green
    }
}
catch {
    Write-Host "AVISO: API no alcanzable en $baseUrl (solo checks estaticos)" -ForegroundColor Yellow
}

try {
    $health = Invoke-RestMethod -Uri "$baseUrl/health" -TimeoutSec 8
    if ($health.exito -and $health.datos.realtime.conectado) {
        Write-Host 'OK GET /health realtime.conectado' -ForegroundColor Green
    }
    elseif ($health.exito -and $null -ne $health.datos.realtime) {
        Write-Host "AVISO GET /health: realtime configurado=$($health.datos.realtime.configurado) conectado=$($health.datos.realtime.conectado)" -ForegroundColor Yellow
    }
    elseif ($health.exito) {
        Write-Host 'AVISO GET /health sin bloque realtime' -ForegroundColor Yellow
    }
}
catch {
    Write-Host 'AVISO: GET /health no alcanzable' -ForegroundColor Yellow
}

if ($fallos -gt 0) {
    Write-Host "`nFALLO: $fallos comprobacion(es)" -ForegroundColor Red
    exit 1
}

Write-Host "`nOK verificacion Realtime estatica" -ForegroundColor Green
exit 0
