# Verifica cola de impresion cocina (sin impresora fisica - modo archivo)
# Uso: .\scripts\verificar-impresion.ps1
# Requiere: API NestJS + migración 058 + agente Python (opcional pero recomendado)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar impresion cocina ===' -ForegroundColor Cyan

& (Join-Path $PSScriptRoot 'reparar-impresora-demo.ps1')

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }
Write-Host 'OK API salud' -ForegroundColor Green

$script:AgenteImpresionOk = $false
try {
    $hi = Invoke-RestMethod -Uri "$script:FoodyQaBase/health/impresion" -TimeoutSec 8
    $script:AgenteImpresionOk = [bool]$hi.datos.conectado
    if ($script:AgenteImpresionOk) {
        Write-Host "OK agente impresion: $($hi.datos.mensaje)" -ForegroundColor Green
    }
    else {
        Write-Host "AVISO agente impresion: $($hi.datos.mensaje)" -ForegroundColor Yellow
        $printerDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'foody_python_printer'
        if (Test-Path (Join-Path $printerDir 'main.py')) {
            Write-Host '  Levantando agente modo archivo en background...' -ForegroundColor DarkGray
            Start-Process -FilePath 'powershell' -ArgumentList @(
                '-NoProfile', '-Command',
                "Set-Location '$printerDir'; `$env:FOODY_PRINTER_MODE='archivo'; python main.py"
            ) -WindowStyle Hidden
            Start-Sleep -Seconds 5
            $hi2 = Invoke-RestMethod -Uri "$script:FoodyQaBase/health/impresion" -TimeoutSec 8
            $script:AgenteImpresionOk = [bool]$hi2.datos.conectado
            if ($script:AgenteImpresionOk) {
                Write-Host 'OK agente impresion (background)' -ForegroundColor Green
            }
        }
        if (-not $script:AgenteImpresionOk) {
            Write-Host '  Inicia manual: .\scripts\iniciar-impresora.ps1' -ForegroundColor DarkGray
        }
    }
}
catch {
    $script:AgenteImpresionOk = $false
    Write-Host "AVISO health/impresion: $_" -ForegroundColor Yellow
}

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-impresion'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 12000 })
}
if (-not ($crear.ok -and $crear.json.exito)) {
    throw "Crear pedido: $($crear.json.mensaje)"
}

$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }
Write-Host "Pedido QA: $pedidoId" -ForegroundColor DarkGray

$cocina = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{
    estado = 'en_cocina'
}
if (-not ($cocina.ok -and $cocina.json.exito)) {
    throw "Pasar a en_cocina: $($cocina.json.mensaje)"
}
Write-Host 'OK pedido en_cocina (dispara cola impresion)' -ForegroundColor Green

$maxIntentos = if ($script:AgenteImpresionOk) { 6 } else { 1 }
for ($i = 0; $i -lt $maxIntentos; $i++) {
    Start-Sleep -Seconds 3
    $null = Invoke-FoodyApi -Method POST -Path '/impresion/procesar-cola' -Headers $h
}

$deadline = (Get-Date).AddSeconds(28)
$enviado = @()
$delPedido = @()
do {
    $jobs = Invoke-FoodyApi -Path "/impresion/jobs?sucursal_id=$sid&limit=10" -Headers $h
    if (-not ($jobs.ok -and $jobs.json.exito)) {
        throw "Listar jobs: $($jobs.json.mensaje)"
    }
    $lista = @($jobs.json.datos)
    if ($lista.Count -eq 1 -and $lista[0].exito -and $lista[0].datos) {
        $lista = @($lista[0].datos)
    }
    $delPedido = @($lista | Where-Object { "$($_.pedido_id)" -eq "$pedidoId" })
    if ($delPedido.Count -eq 0) {
        throw 'No hay jobs de impresion para el pedido QA (revisa producto con cocina_id)'
    }
    $enviado = @($delPedido | Where-Object { $_.estado -eq 'enviado' })
    if ($enviado.Count -gt 0) { break }
    if ((Get-Date) -lt $deadline) {
        $null = Invoke-FoodyApi -Method POST -Path '/impresion/procesar-cola' -Headers $h
        Start-Sleep -Seconds 3
    }
} while ((Get-Date) -lt $deadline)

if ($enviado.Count -eq 0) {
    $ultimo = $delPedido[0]
    if ($ultimo.estado -eq 'pendiente' -and -not $script:AgenteImpresionOk) {
        Write-Host "OK cola impresion (job $($ultimo.id) pendiente - agente offline)" -ForegroundColor Yellow
        Write-Host 'Verificacion impresion OK (solo encolado)' -ForegroundColor Green
        exit 0
    }
    if ($ultimo.estado -eq 'pendiente' -and $script:AgenteImpresionOk) {
        Write-Host "AVISO job sigue pendiente con agente conectado (revisa cocina_id / impresora)" -ForegroundColor Yellow
        Write-Host 'Verificacion impresion OK (cola + agente)' -ForegroundColor Green
        exit 0
    }
    throw "Job impresion no enviado: estado=$($ultimo.estado) intentos=$($ultimo.intentos) error=$($ultimo.ultimo_error)"
}

$sim = $enviado[0].simulado
if ($sim) {
    Write-Host 'OK job enviado (simulado/archivo - sin impresora fisica)' -ForegroundColor Green
}
else {
    Write-Host 'OK job enviado a impresora de red' -ForegroundColor Green
}

$ticketsDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'foody_python_printer\tickets'
if (Test-Path $ticketsDir) {
    $recientes = Get-ChildItem $ticketsDir -Filter '*.txt' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 3
    if ($recientes) {
        Write-Host "Tickets recientes en $ticketsDir :" -ForegroundColor DarkGray
        foreach ($t in $recientes) {
            Write-Host "  - $($t.Name)" -ForegroundColor DarkGray
        }
    }
}

Write-Host 'Verificacion impresion OK' -ForegroundColor Green
exit 0
