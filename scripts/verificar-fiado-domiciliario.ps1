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

$resumenInicial = Invoke-FoodyApi -Path "/domiciliarios-planta/liquidacion/$sid" -Headers $h
if (-not ($resumenInicial.ok -and $resumenInicial.json.exito)) { throw 'Resumen liquidacion fallo' }
$permiteFiadoOriginal = [bool]$resumenInicial.json.datos.permite_fiado_domiciliario
$domisIniciales = @($resumenInicial.json.datos.domiciliarios)
$saldoPrevioDomiPrueba = $domisIniciales |
    Where-Object { $_.domiciliario_planta_id -eq $DomiPlantaId } |
    Select-Object -First 1

if (-not $CicloCompleto) {
    Write-Host "Modo de solo lectura. Fiado habilitado=$permiteFiadoOriginal" -ForegroundColor Yellow
    Write-Host "Cuentas pendientes actuales: $($domisIniciales.Count) domiciliario(s). No se liquidaron saldos." -ForegroundColor Yellow
    Write-Host 'Usa -CicloCompleto solo contra una base clon foody_diseno_qa_codex_*.' -ForegroundColor Yellow
    return
}

if ($script:FoodyQaDatabase -notmatch '^foody_diseno_qa_codex_[a-zA-Z0-9_]+$') {
    throw "Ciclo completo bloqueado: FOODY_QA_DATABASE debe ser un clon desechable foody_diseno_qa_codex_* (actual: $script:FoodyQaDatabase)."
}
$qaUri = [Uri]$script:FoodyQaBase
if (@('127.0.0.1', 'localhost') -notcontains $qaUri.Host -or $qaUri.Port -ne 3001) {
    throw "Ciclo completo bloqueado: el destino debe ser API QA local :3001 (actual: $script:FoodyQaBase)."
}
if ($saldoPrevioDomiPrueba -and [double]$saldoPrevioDomiPrueba.total_pendiente -gt 0.01) {
    throw "Ciclo completo bloqueado: el domiciliario fixture ya tiene una CxC pendiente de $($saldoPrevioDomiPrueba.total_pendiente). No se liquidara un saldo preexistente."
}

try {
    $cfg = Invoke-FoodyApi -Method PATCH -Path "/domiciliarios-planta/config-fiado/$sid" -Headers $h -Body @{ permitir = $true }
    if (-not ($cfg.ok -and $cfg.json.datos.permite_fiado_domiciliario -eq $true)) { throw 'No se activo el fiado' }
    Write-Host 'OK fiado activado temporalmente en el clon QA' -ForegroundColor Green

    $null = Limpiar-PedidosActivosDemo -Headers $h
    $null = Limpiar-AsignacionesDomicilioDemo
    if (-not (Ensure-CajaAbierta -Headers $h)) { throw 'Sin caja abierta' }

    $crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
        sucursal_id       = $sid
        tipo              = 'domicilio'
        device_id         = "qa-fiado-domi-$([guid]::NewGuid().ToString('N'))"
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

    $cocina = Get-FoodyToken 'cocina@foody.demo'
    $detalle = Invoke-FoodyApi -Path "/pedidos/$pedidoId/detalle?sucursal_id=$sid" -Headers $h
    if (-not ($detalle.ok -and $detalle.json.exito)) { throw 'No se pudo leer detalle para resolver Cocina' }
    $items = @($detalle.json.datos.items_resumen)
    if ($items.Count -eq 0) { $items = @($detalle.json.datos.items) }
    if ($items.Count -eq 0) { throw 'El pedido fiado no tiene líneas de Cocina verificables' }
    foreach ($item in $items) {
        $itemId = if ($item.item_id) { $item.item_id } else { $item.id }
        if (-not $itemId -or $item.estado_cocina -in @('listo', 'no_disponible')) { continue }
        $resuelto = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$itemId/estado" -Headers $cocina.headers -Body @{ estado_cocina = 'listo' }
        if (-not ($resuelto.ok -and $resuelto.json.exito)) { throw "Cocina no pudo resolver ítem $itemId" }
    }

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

    $abono = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedidoId/cobrar?sucursal_id=$sid" -Headers $h -Body @{
        monto_parcial = 2000
        pagos = @(@{ metodo_pago = 'transferencia'; monto = 2000 })
        idempotency_key = "qa-fiado-abono-$pedidoId"
    }
    if (-not ($abono.ok -and $abono.json.exito -and $abono.json.datos.parcial)) {
        throw "No se registro el abono previo por transferencia: $($abono.json.mensaje)"
    }
    Write-Host 'OK abono previo por transferencia: 2000 COP' -ForegroundColor Green

    $entrega = Invoke-FoodyApi -Method PATCH -Path "/domiciliario/pedidos/$pedidoId/confirmar-entrega" -Headers $hDomi -Body @{
        metodo_pago = 'pendiente_liquidacion'
    }
    if (-not ($entrega.ok -and $entrega.json.exito)) { throw "Entrega fiado: $($entrega.json.mensaje)" }
    Write-Host 'OK entrega con pendiente_liquidacion' -ForegroundColor Green

$resumen = Invoke-FoodyApi -Path "/domiciliarios-planta/liquidacion/$sid" -Headers $h
if (-not ($resumen.ok -and $resumen.json.exito)) { throw 'Resumen liquidacion fallo' }
$doms = @($resumen.json.datos.domiciliarios)
Write-Host "Resumen: domiciliarios_con_saldo=$($doms.Count)" -ForegroundColor Yellow

$fixtureDomi = $doms |
    Where-Object { $_.domiciliario_planta_id -eq $DomiPlantaId } |
    Select-Object -First 1
if (-not $fixtureDomi) { throw 'No aparecio la CxC del domiciliario fixture' }
if ([double]$fixtureDomi.total_pendiente -lt 0.01) { throw 'total_pendiente debe ser > 0' }
Write-Host "OK saldo pendiente del fixture: $($fixtureDomi.nombre) -> $($fixtureDomi.total_pendiente)" -ForegroundColor Green

$liq = Invoke-FoodyApi -Method POST -Path "/domiciliarios-planta/liquidar/${DomiPlantaId}?sucursal_id=${sid}" -Headers $h
if (-not ($liq.ok -and $liq.json.exito)) { throw "Liquidar: $($liq.json.mensaje)" }
Write-Host "OK liquidado: $($liq.json.datos.liquidados) pedidos, $($liq.json.datos.total) COP" -ForegroundColor Green

$resumenFinal = Invoke-FoodyApi -Path "/domiciliarios-planta/liquidacion/$sid" -Headers $h
if (-not ($resumenFinal.ok -and $resumenFinal.json.exito)) { throw 'Resumen final de liquidacion fallo' }
$saldoFinalFixture = @($resumenFinal.json.datos.domiciliarios) |
    Where-Object { $_.domiciliario_planta_id -eq $DomiPlantaId }
if ($saldoFinalFixture.Count -gt 0 -and [double]$saldoFinalFixture[0].total_pendiente -gt 0.01) {
    throw 'La liquidacion dejo saldo pendiente en el domiciliario fixture'
}
Write-Host 'OK saldo del fixture liquidado' -ForegroundColor Green

$detalleFinal = Invoke-FoodyApi -Path "/pedidos/$pedidoId/detalle?sucursal_id=$sid" -Headers $h
if (-not ($detalleFinal.ok -and $detalleFinal.json.exito)) { throw 'No se pudo leer pedido liquidado' }
if ($detalleFinal.json.datos.metodo_pago -ne 'transferencia') {
    throw "La liquidacion reemplazo el primer metodo real; esperado transferencia, recibido $($detalleFinal.json.datos.metodo_pago)"
}
$resumenPagos = @($detalleFinal.json.datos.pagos_resumen)
$montoTransferencia = ($resumenPagos | Where-Object { $_.metodo_pago -eq 'transferencia' } | Measure-Object -Property monto -Sum).Sum
$montoEfectivo = ($resumenPagos | Where-Object { $_.metodo_pago -eq 'efectivo' } | Measure-Object -Property monto -Sum).Sum
if ([double]$montoTransferencia -lt 1999.99 -or [double]$montoEfectivo -lt 0.01) {
    throw "El resumen no conserva abono transferencia y liquidacion efectivo: transferencia=$montoTransferencia efectivo=$montoEfectivo"
}
Write-Host "OK pagos conservan medios reales: transferencia=$montoTransferencia, efectivo=$montoEfectivo COP" -ForegroundColor Green

$reintento = Invoke-FoodyApi -Method POST -Path "/domiciliarios-planta/liquidar/${DomiPlantaId}?sucursal_id=${sid}" -Headers $h
if ($reintento.ok -or $reintento.status -ne 400 -or $reintento.json.exito -ne $false) {
    throw "El reintento sin saldo debía rechazarse con HTTP 400; status=$($reintento.status)"
}
Write-Host 'OK reintento de liquidacion rechazado sin volver a cobrar' -ForegroundColor Green
Write-Host 'Verificacion fiado OK' -ForegroundColor Green
}
finally {
    $restaurar = Invoke-FoodyApi -Method PATCH -Path "/domiciliarios-planta/config-fiado/$sid" -Headers $h -Body @{ permitir = $permiteFiadoOriginal }
    if (-not ($restaurar.ok -and $restaurar.json.datos.permite_fiado_domiciliario -eq $permiteFiadoOriginal)) {
        throw 'No se pudo restaurar permite_fiado_domiciliario al valor previo'
    }
    Write-Host "OK configuracion de fiado restaurada: $permiteFiadoOriginal" -ForegroundColor Green
}
