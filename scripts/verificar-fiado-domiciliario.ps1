# Verifica ciclo completo fiado domiciliario: entrega pendiente_liquidacion -> CxC -> liquidar caja
# Uso: .\scripts\verificar-fiado-domiciliario.ps1 [-CicloCompleto]

param([switch]$CicloCompleto)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\qa-helpers.ps1')

$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$DomiPlantaId = '92000000-0000-4000-8000-000000000001'

Write-Host '=== Verificar fiado / liquidacion domiciliario ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers

$cfg = Invoke-FoodyApi -Method PATCH -Path "/domiciliarios-planta/config-fiado/$sid" -Headers $h -Body @{ permitir = $true }
if (-not ($cfg.json.datos.permite_fiado_domiciliario -eq $true)) { throw 'No se activo el fiado' }
Write-Host 'OK fiado activado en sucursal' -ForegroundColor Green

if ($CicloCompleto) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $null = Limpiar-AsignacionesDomicilioDemo
    if (-not (Ensure-CajaAbierta -Headers $h)) { throw 'Sin caja abierta' }

    $crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
        sucursal_id       = $sid
        tipo              = 'domicilio'
        device_id         = 'qa-fiado-domi'
        cliente_nombre    = 'QA Fiado'
        cliente_telefono  = '3001112233'
        direccion_entrega = 'Calle Fiado 1'
        metodo_pago       = 'pendiente'
        items             = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
    }
    if (-not ($crear.ok -and $crear.json.exito)) { throw "Crear domicilio: $($crear.json.mensaje)" }
    $pedidoId = $crear.json.datos.pedido_id
    if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }
    Write-Host "OK pedido fiado $pedidoId" -ForegroundColor Green

    foreach ($est in @('en_cocina', 'listo')) {
        $e = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = $est }
        if (-not ($e.ok -and $e.json.exito)) { throw "Estado $est : $($e.json.mensaje)" }
    }

    $asigRes = Ensure-AsignacionDomiPlanta -PedidoId $pedidoId -Headers $h -SucursalId $sid -DomiPlantaId $DomiPlantaId
    if (-not $asigRes.ok) { throw "Asignar: $($asigRes.mensaje)" }
    if ($asigRes.auto) {
        Write-Host "OK auto-dispatch estado=$($asigRes.estado)" -ForegroundColor Green
    }
    else {
        Write-Host 'OK asignacion manual domiciliario' -ForegroundColor Green
    }

    $domi = Get-FoodyToken 'domi@foody.demo'
    $hDomi = $domi.headers
    $camino = Invoke-FoodyApi -Method PATCH -Path "/domiciliario/pedidos/$pedidoId/en-camino" -Headers $hDomi
    if (-not ($camino.ok -and $camino.json.exito)) { throw "En camino: $($camino.json.mensaje)" }

    $entrega = Invoke-FoodyApi -Method PATCH -Path "/domiciliario/pedidos/$pedidoId/confirmar-entrega" -Headers $hDomi -Body @{
        metodo_pago = 'pendiente_liquidacion'
    }
    if (-not ($entrega.ok -and $entrega.json.exito)) { throw "Entrega fiado: $($entrega.json.mensaje)" }
    Write-Host 'OK entrega con pendiente_liquidacion' -ForegroundColor Green
}

$resumen = Invoke-FoodyApi -Path "/domiciliarios-planta/liquidacion/$sid" -Headers $h
if (-not ($resumen.ok -and $resumen.json.exito)) { throw 'Resumen liquidacion fallo' }
$doms = @($resumen.json.datos.domiciliarios)
Write-Host "Resumen: domiciliarios_con_saldo=$($doms.Count)" -ForegroundColor Yellow

if ($CicloCompleto) {
    if ($doms.Count -lt 1) { throw 'Se esperaba saldo tras entrega fiado' }
    $primero = $doms[0]
    if ([double]$primero.total_pendiente -lt 0.01) { throw 'total_pendiente debe ser > 0' }
    Write-Host "OK saldo pendiente: $($primero.nombre) -> $($primero.total_pendiente)" -ForegroundColor Green

    $liq = Invoke-FoodyApi -Method POST -Path "/domiciliarios-planta/liquidar/$($primero.domiciliario_planta_id)?sucursal_id=$sid" -Headers $h
    if (-not ($liq.ok -and $liq.json.exito)) { throw "Liquidar: $($liq.json.mensaje)" }
    Write-Host "OK liquidado: $($liq.json.datos.liquidados) pedidos, $($liq.json.datos.total) COP" -ForegroundColor Green
} elseif ($doms.Count -gt 0) {
    $primero = $doms[0]
    $liq = Invoke-FoodyApi -Method POST -Path "/domiciliarios-planta/liquidar/$($primero.domiciliario_planta_id)?sucursal_id=$sid" -Headers $h
    if ($liq.ok -and $liq.json.exito) {
        Write-Host "OK liquidado existente: $($liq.json.datos.total)" -ForegroundColor Green
    } else {
        Write-Host "AVISO liquidacion: $($liq.json.mensaje)" -ForegroundColor Yellow
    }
} else {
    Write-Host 'Sin saldo (usa -CicloCompleto para probar entrega fiado)' -ForegroundColor Yellow
}

Invoke-FoodyApi -Method PATCH -Path "/domiciliarios-planta/config-fiado/$sid" -Headers $h -Body @{ permitir = $false } | Out-Null
Write-Host 'OK fiado restaurado a desactivado' -ForegroundColor Green
Write-Host 'Verificacion fiado OK' -ForegroundColor Green
