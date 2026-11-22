# E2E ofertas domiciliario independiente: dispatch, aceptar, anti doble-aceptación
# Uso: .\scripts\verificar-ofertas-independiente.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

$fallos = 0
function Assert($c, $m) { if (-not (Assert-Qa $c $m)) { $script:fallos++ } }

Write-Host '=== Verificar ofertas independiente (inDriver API) ===' -ForegroundColor Cyan

$sid = $script:FoodyQaSucursal
$producto = 'f0000000-0000-4000-8000-000000000002'
$latSuc = 10.463310
$lngSuc = -73.253220
$latRep = 10.464100
$lngRep = -73.252500

$admin = Get-FoodyToken 'admin@foody.demo'
$hAdmin = $admin.headers

$null = Limpiar-PedidosActivosDemo -Headers $hAdmin
$null = Limpiar-AsignacionesDomicilioDemo
Ensure-HorariosDemoAbiertos | Out-Null
Assert $true 'Horarios demo abiertos'
Assert (Ensure-CajaAbierta -Headers $hAdmin) 'Caja abierta'

# ponytail: sin planta libre el auto-dispatch va a independientes
$null = docker exec supabase-db psql -U postgres -d postgres -c `
    "UPDATE domiciliarios_planta SET activo = false WHERE sucursal_id = '$sid';" 2>&1

try {
    $rep = Get-FoodyTokenDomiciliarioIndep 'repartidor@foody.demo'
    $hRep = $rep.headers

    $sesIni = Invoke-FoodyApi -Method POST -Path '/domiciliarios/sesion/iniciar' -Headers $hRep -Body @{
        lat = $latRep
        lng = $lngRep
    }
    Assert ($sesIni.ok -and $sesIni.json.exito) 'Repartidor inicia turno'

    $sesEst = Invoke-FoodyApi -Path '/domiciliarios/sesion/estado' -Headers $hRep
    Assert ($sesEst.ok -and $sesEst.json.exito -and $sesEst.json.datos.activa -eq $true) 'Sesion activa=true'

    $crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hAdmin -Body @{
        sucursal_id       = $sid
        tipo              = 'domicilio'
        device_id         = 'qa-indep-oferta'
        cliente_nombre    = 'QA Oferta'
        cliente_telefono  = '3001112233'
        direccion_entrega = 'Calle Oferta QA 45'
        lat               = $latSuc
        lng               = $lngSuc
        metodo_pago       = 'pendiente'
        items             = @(@{ producto_id = $producto; cantidad = 1; precio = 12000 })
    }
    Assert ($crear.ok -and $crear.json.exito) 'Crear pedido domicilio con GPS'
    if (-not ($crear.ok -and $crear.json.exito)) { throw 'abort' }

    $pedidoId = $crear.json.datos.pedido_id
    if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }

    foreach ($est in @('en_cocina', 'listo')) {
        $e = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $hAdmin -Body @{ estado = $est }
        Assert ($e.ok -and $e.json.exito) "Pedido -> $est"
    }

    Start-Sleep -Seconds 1
    $ofertasPre = Invoke-FoodyApi -Path '/domiciliarios/ofertas-activas' -Headers $hRep
    $ofertaId = $null
    if ($ofertasPre.ok -and $ofertasPre.json.exito -and @($ofertasPre.json.datos).Count -gt 0) {
        $ofertaId = $ofertasPre.json.datos[0].oferta_id
        Assert $true 'Oferta creada por auto-dispatch al listo'
    }
    else {
        $dispatch = Invoke-FoodyApi -Method POST -Path "/domiciliarios-planta/dispatch-independiente/$pedidoId?sucursal_id=$sid" -Headers $hAdmin
        $motivo = $dispatch.json.datos.motivo
        if ($dispatch.json.datos.oferta_id) {
            $ofertaId = $dispatch.json.datos.oferta_id
        }
        Assert (
            ($dispatch.ok -and $dispatch.json.exito) -or
            ($motivo -eq 'oferta_activa' -and $ofertaId)
        ) "Dispatch independiente ($motivo)"
    }
    Assert ($null -ne $ofertaId) 'oferta_id disponible'
    $ofertas = Invoke-FoodyApi -Path '/domiciliarios/ofertas-activas' -Headers $hRep
    Assert ($ofertas.ok -and $ofertas.json.exito) 'GET ofertas-activas'
    $lista = @($ofertas.json.datos)
    Assert ($lista.Count -ge 1) 'Al menos una oferta activa'
    $oferta = $lista | Where-Object { $_.oferta_id -eq $ofertaId } | Select-Object -First 1
    if (-not $oferta) { $oferta = $lista[0] }
    Assert ($null -ne $oferta.lat -and $null -ne $oferta.lng) 'Oferta incluye lat/lng'
    Assert ($oferta.cliente_nombre -eq 'QA Oferta') 'Oferta cliente_nombre'
    Assert ($null -ne $oferta.ganancia_estimada) 'Oferta ganancia_estimada desde API'
    Assert ($null -eq $oferta.cliente_telefono -or $oferta.cliente_telefono -eq '') 'Sin teléfono en oferta (privacidad)'

    $aceptar = Invoke-FoodyApi -Method POST -Path "/domiciliarios/ofertas/$($oferta.oferta_id)/responder" -Headers $hRep -Body @{
        respuesta = 'aceptada'
    }
    Assert ($aceptar.ok -and $aceptar.json.exito) 'Aceptar oferta'
    Assert ($aceptar.json.datos.estado -eq 'asignado') 'Estado asignado tras aceptar'

    $doble = Invoke-FoodyApi -Method POST -Path "/domiciliarios/ofertas/$($oferta.oferta_id)/responder" -Headers $hRep -Body @{
        respuesta = 'aceptada'
    }
    Assert ((-not $doble.ok) -or (-not $doble.json.exito)) 'Bloqueo doble aceptación mismo repartidor'

    $activos = Invoke-FoodyApi -Path '/domiciliarios/pedidos-activos' -Headers $hRep
    Assert ($activos.ok -and $activos.json.exito) 'GET pedidos-activos'
    $ped = @($activos.json.datos | Where-Object { $_.id -eq $pedidoId })[0]
    Assert ($null -ne $ped) 'Pedido en activos'
    Assert ($ped.cliente_telefono -eq '3001112233') 'Teléfono visible tras aceptar'

    $camino = Invoke-FoodyApi -Method PATCH -Path "/domiciliarios/pedidos/$pedidoId/en-camino" -Headers $hRep
    Assert ($camino.ok -and $camino.json.exito) 'Marcar en camino'

    $entrega = Invoke-FoodyApi -Method PATCH -Path "/domiciliarios/pedidos/$pedidoId/confirmar-entrega" -Headers $hRep -Body @{
        metodo_pago = 'efectivo'
    }
    Assert ($entrega.ok -and $entrega.json.exito) 'Confirmar entrega'
}
finally {
    $null = docker exec supabase-db psql -U postgres -d postgres -c `
        "UPDATE domiciliarios_planta SET activo = true WHERE sucursal_id = '$sid';" 2>&1
}

Write-Host ''
if ($fallos -eq 0) {
    Write-Host 'Verificacion ofertas independiente OK' -ForegroundColor Green
    exit 0
}
Write-Host "$fallos fallos" -ForegroundColor Red
exit 1
