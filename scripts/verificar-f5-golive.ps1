# F5 Go-live P0 — preflight codigo + config (NO marca impresora/VPS/Wompi dashboard como hecho)
# Uso: .\scripts\verificar-f5-golive.ps1
#       .\scripts\verificar-f5-golive.ps1 -Estricto   # FAIL si agente impresion offline
param(
    [switch]$Estricto
)
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\qa-helpers.ps1"
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

Write-Host '=== Verificar F5 go-live (parcial) ===' -ForegroundColor Cyan
Write-Host 'Humano pendiente: Wompi dashboard + VPS + QA termica — ver docs/CHECKLIST_F5_GOLIVE.md' -ForegroundColor DarkGray

$script:fallos = 0
$script:avisos = 0

function Assert-Ok {
    param([bool]$Cond, [string]$Msg)
    if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
    else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}
function Assert-Aviso {
    param([bool]$Cond, [string]$Msg)
    if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
    else {
        Write-Host "  AVISO  $Msg" -ForegroundColor Yellow
        $script:avisos++
        if ($Estricto) { $script:fallos++ }
    }
}

Write-Host ''
Write-Host '--- A API ---' -ForegroundColor Yellow
try {
    $salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
    Assert-Ok -Cond ([bool]$salud.exito) -Msg 'GET /salud'
} catch {
    Assert-Ok -Cond $false -Msg "GET /salud ($_)"
}

Write-Host ''
Write-Host '--- B Impresion health ---' -ForegroundColor Yellow
try {
    $hi = Invoke-RestMethod -Uri "$script:FoodyQaBase/health/impresion" -TimeoutSec 8
    $conectado = [bool]$hi.datos.conectado
    Assert-Aviso -Cond $conectado -Msg "Agente impresion conectado ($($hi.datos.mensaje))"
} catch {
    Assert-Aviso -Cond $false -Msg "health/impresion ($_)"
}

Write-Host ''
Write-Host '--- C Wompi config ---' -ForegroundColor Yellow
$raiz = Split-Path $PSScriptRoot -Parent
$envPath = Join-Path $raiz 'foody_backend\.env'
Assert-Ok -Cond (Test-Path $envPath) -Msg 'foody_backend/.env existe'
$raw = if (Test-Path $envPath) { Get-Content $envPath -Raw -Encoding UTF8 } else { '' }
$tienePub = $raw -match '(?m)^WOMPI_PUBLIC_KEY=\S+'
$tienePrv = $raw -match '(?m)^WOMPI_PRIVATE_KEY=\S+' -or $raw -match '(?m)^WOMPI_SECRET_KEY=\S+'
$tieneEvents = $raw -match '(?m)^WOMPI_EVENTS_SECRET=\S+' -or $raw -match '(?m)^WOMPI_EVENT_KEY=\S+'
$tieneRedirect = $raw -match '(?m)^WOMPI_REDIRECT_URL=https?://\S+'
Assert-Aviso -Cond $tienePub -Msg 'WOMPI_PUBLIC_KEY presente'
Assert-Aviso -Cond $tienePrv -Msg 'WOMPI_PRIVATE/SECRET_KEY presente'
Assert-Aviso -Cond $tieneEvents -Msg 'WOMPI_EVENTS_SECRET presente'
Assert-Ok -Cond $tieneRedirect -Msg 'WOMPI_REDIRECT_URL presente'

$webhook = "$FoodyUrlApi/api/v1/pagos/webhook-wompi"
try {
    $null = Invoke-WebRequest -Uri $webhook -Method Get -UseBasicParsing -TimeoutSec 15
    Assert-Ok -Cond $true -Msg "Webhook reachable ($webhook)"
} catch {
    $code = $null
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    if ($code -and $code -lt 500) {
        Assert-Ok -Cond $true -Msg "Webhook reachable status=$code"
    } else {
        Assert-Ok -Cond $false -Msg "Webhook no alcanzable: $($_.Exception.Message)"
    }
}

Write-Host ''
Write-Host '--- D BN-EXC rastro (codigo) ---' -ForegroundColor Yellow
$pagosSrc = Get-Content -Raw (Join-Path $raiz 'foody_backend\src\modulos\pagos\pagos.service.ts')
$impSrc = Get-Content -Raw (Join-Path $raiz 'foody_backend\src\core\impresion\impresion.service.ts')
Assert-Ok -Cond ($pagosSrc -match 'registrarFalloFuentePago') -Msg 'pagos.service audita fallo fuente'
Assert-Ok -Cond ($impSrc -match 'error_encolado') -Msg 'impresion deja job error si encola falla'

Write-Host ''
Write-Host "Avisos: $script:avisos (ops humano / agente offline)" -ForegroundColor DarkGray
if ($script:fallos -gt 0) {
    Write-Host "F5 FALLA ($script:fallos)" -ForegroundColor Red
    exit 1
}
Write-Host 'F5 go-live PARCIAL OK (codigo+config local)' -ForegroundColor Green
Write-Host 'No cierra C-05/C-06: falta checklist humano' -ForegroundColor Yellow
exit 0
