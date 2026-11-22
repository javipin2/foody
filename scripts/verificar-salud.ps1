# Verifica salud operativa Foody (BD, Realtime, cola impresion)
# Uso:
#   .\scripts\verificar-salud.ps1
#   .\scripts\verificar-salud.ps1 -BaseUrl https://api.foodyy.store/api/v1
#   .\scripts\verificar-salud.ps1 -Estricto   # falla si agente impresion offline

param(
    [string]$BaseUrl = 'http://localhost:3000/api/v1',
    [switch]$Estricto
)

$ErrorActionPreference = 'Stop'

function Get-Json {
    param([string]$Url, [int]$TimeoutSec = 12)
    $r = Invoke-RestMethod -Uri $Url -TimeoutSec $TimeoutSec
    if (-not $r.exito) { throw $r.mensaje }
    return $r.datos
}

Write-Host '=== Verificar salud Foody ===' -ForegroundColor Cyan
Write-Host "Base: $BaseUrl" -ForegroundColor DarkGray

$fallos = 0
$avisos = 0

# 1. Salud basica (BD)
try {
    $salud = Get-Json "$BaseUrl/salud"
    if ($salud.base_datos) {
        Write-Host 'OK GET /salud (base_datos)' -ForegroundColor Green
    }
    else {
        Write-Host 'FALLO GET /salud: base_datos=false' -ForegroundColor Red
        $fallos++
    }
}
catch {
    Write-Host "FALLO GET /salud: $_" -ForegroundColor Red
    $fallos++
}

# 2. Consolidado
try {
    $h = Get-Json "$BaseUrl/health" -TimeoutSec 20
    $estado = $h.estado
    $color = switch ($estado) {
        'ok' { 'Green' }
        'degradado' { 'Yellow' }
        default { 'Red' }
    }
    Write-Host "OK GET /health estado=$estado" -ForegroundColor $color
    if ($h.alertas -and $h.alertas.Count -gt 0) {
        foreach ($a in @($h.alertas)) {
            Write-Host "  alerta: $a" -ForegroundColor Yellow
            $avisos++
        }
    }
    $cola = $h.impresion.cola
    Write-Host "  cola: pendientes=$($cola.pendientes) error=$($cola.error) enviados_24h=$($cola.enviados_24h)" -ForegroundColor DarkGray
    if ($estado -eq 'critico') { $fallos++ }
}
catch {
    Write-Host "FALLO GET /health: $_" -ForegroundColor Red
    $fallos++
}

# 3. Realtime (detalle)
try {
    $rt = Get-Json "$BaseUrl/health/realtime" -TimeoutSec 15
    if ($rt.conectado) {
        Write-Host 'OK Realtime conectado' -ForegroundColor Green
    }
    elseif ($rt.configurado) {
        Write-Host "AVISO Realtime desconectado: $($rt.detalle)" -ForegroundColor Yellow
        $avisos++
    }
    else {
        Write-Host "AVISO Realtime no configurado: $($rt.detalle)" -ForegroundColor Yellow
        $avisos++
    }
}
catch {
    Write-Host "FALLO health/realtime: $_" -ForegroundColor Red
    $fallos++
}

# 4. Impresion (detalle)
try {
    $imp = Get-Json "$BaseUrl/health/impresion" -TimeoutSec 10
    if ($imp.conectado) {
        Write-Host "OK Agente impresion: $($imp.mensaje)" -ForegroundColor Green
    }
    else {
        Write-Host "AVISO Agente impresion: $($imp.mensaje)" -ForegroundColor Yellow
        Write-Host '  Inicia: .\scripts\iniciar-impresora.ps1' -ForegroundColor DarkGray
        $avisos++
        if ($Estricto) { $fallos++ }
    }
    if ($imp.cola.error -gt 0) {
        Write-Host "AVISO jobs impresion en error: $($imp.cola.error)" -ForegroundColor Yellow
        $avisos++
        if ($Estricto) { $fallos++ }
    }
}
catch {
    Write-Host "FALLO health/impresion: $_" -ForegroundColor Red
    $fallos++
}

Write-Host ''
if ($fallos -gt 0) {
    Write-Host "Salud FALLO ($fallos critico(s), $avisos aviso(s))" -ForegroundColor Red
    exit 1
}
if ($avisos -gt 0) {
    Write-Host "Salud OK con avisos ($avisos) - normal en dev sin agente impresion" -ForegroundColor Yellow
    exit 0
}
Write-Host 'Salud OK (todo operativo)' -ForegroundColor Green
exit 0
