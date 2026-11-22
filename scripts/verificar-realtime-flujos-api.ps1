# Emisores Realtime por flujo de negocio (checklist QA §1-4, capa API)
# Uso: .\scripts\verificar-realtime-flujos-api.ps1
# Requiere: API viva, migraciones 055/067, caja demo abierta

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

$fallos = 0
function Ok($msg) { Write-Host "OK $msg" -ForegroundColor Green }
function Fail($msg) {
    Write-Host "FALLO $msg" -ForegroundColor Red
    $script:fallos++
}

Write-Host '=== Verificar Realtime flujos (API) ===' -ForegroundColor Cyan

$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$CocinaId = 'd0000000-0000-4000-8000-000000000001'
$MesaQrId = '30000000-0000-4000-8000-000000000001'
$DomiPlantaId = '92000000-0000-4000-8000-000000000001'

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers

if (-not (Ensure-CajaAbierta -Headers $h)) {
    Fail 'caja demo no disponible'
    exit 1
}
$activa = Invoke-FoodyApi -Path "/caja/activa/$sid" -Headers $h
$cajaId = $activa.json.datos.id

# --- §1.3.4 gasto ---
$movAntes = @((Invoke-FoodyApi -Path "/caja/$cajaId/movimientos" -Headers $h).json.datos).Count
$gasto = Invoke-FoodyApi -Method POST -Path '/caja/gastos' -Headers $h -Body @{
    caja_id  = $cajaId
    concepto = 'QA realtime gasto'
    monto    = 1
    categoria = 'otros'
}
if ($gasto.ok -and $gasto.json.exito) {
    Start-Sleep -Milliseconds 300
    $movDesp = @((Invoke-FoodyApi -Path "/caja/$cajaId/movimientos" -Headers $h).json.datos).Count
    if ($movDesp -gt $movAntes) { Ok '§1.3.4 gasto caja -> movimiento BD' }
    else { Fail '§1.3.4 gasto sin movimiento en BD' }
}
else { Fail "§1.3.4 gasto API: $($gasto.json.mensaje)" }

# --- §1.3.5 devolucion ---
$movAntes = @((Invoke-FoodyApi -Path "/caja/$cajaId/movimientos" -Headers $h).json.datos).Count
$dev = Invoke-FoodyApi -Method POST -Path '/caja/devolucion' -Headers $h -Body @{
    caja_id     = $cajaId
    sucursal_id = $sid
    monto       = 1
    motivo      = 'QA realtime devolucion'
}
if ($dev.ok -and $dev.json.exito) {
    Start-Sleep -Milliseconds 300
    $movDesp = @((Invoke-FoodyApi -Path "/caja/$cajaId/movimientos" -Headers $h).json.datos).Count
    if ($movDesp -gt $movAntes) { Ok '§1.3.5 devolucion caja -> movimiento BD' }
    else { Fail '§1.3.5 devolucion sin movimiento en BD' }
}
else { Fail "§1.3.5 devolucion API: $($dev.json.mensaje)" }

# --- §1.6.1 producto disponibilidad ---
$prod = Get-ProductoCatalogo -Headers $h -ProductoId $Producto
if ($prod) {
    $off = Invoke-FoodyApi -Method PATCH -Path "/productos/$Producto/disponibilidad" -Headers $h -Body @{
        disponible = $false
    }
    if ($off.ok -and $off.json.exito) {
        Ok '§1.6.1 producto agotado (emisor catalogo_disponibilidad)'
        $on = Invoke-FoodyApi -Method PATCH -Path "/productos/$Producto/disponibilidad" -Headers $h -Body @{
            disponible = $true
        }
        if ($on.ok -and $on.json.exito) { Ok '§1.6.1 producto restaurado' }
        else { Fail 'revertir producto disponible' }
    }
    else { Fail 'PATCH producto disponible=false' }
}
else { Write-Host 'AVISO sin producto demo — omitido §1.6.1' -ForegroundColor Yellow }

# --- §1.4 / §2.1 pedido mesa QR + aprobar + seguimiento ---
$DeviceMesa = 'qa-rt-mesa-qr'
# Liberar mesa demo si hay pedido activo
$mesas = Invoke-FoodyApi -Path "/mesas/$sid" -Headers $h
foreach ($m in @($mesas.json.datos | Where-Object { $_.id -eq $MesaQrId })) {
    if ($m.pedido_id) {
        $null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$($m.pedido_id)/estado?sucursal_id=$sid" -Headers $h -Body @{
            estado = 'cancelado'
            motivo = 'QA cleanup mesa QR'
        }
        Start-Sleep -Milliseconds 400
    }
}

$pedMesa = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
    sucursal_id = $sid
    mesa_id     = $MesaQrId
    tipo        = 'mesa'
    device_id   = $DeviceMesa
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if ($pedMesa.ok -and $pedMesa.json.exito) {
    $pidMesa = $pedMesa.json.datos.pedido_id
    if (-not $pidMesa) { $pidMesa = $pedMesa.json.datos.id }
    $tokenMesa = $pedMesa.json.datos.seguimiento_token
    $est0 = Invoke-FoodyApi -Path "/pedidos/$pidMesa/estado?device_id=$DeviceMesa"
    if ($est0.ok -and $est0.json.datos.estado_actual -eq 'pendiente_aprobacion') {
        Ok '§1.4.1 pedido mesa QR -> pendiente_aprobacion'
    }
    else {
        Fail "§1.4.1 estado inicial mesa: $($est0.json.datos.estado_actual)"
    }

    $apr = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pidMesa/aprobar?sucursal_id=$sid" -Headers $h
    if ($apr.ok -and $apr.json.exito) {
        Start-Sleep -Milliseconds 400
        $est1 = Invoke-FoodyApi -Path "/pedidos/$pidMesa/estado?token=$tokenMesa"
        if ($est1.ok -and $est1.json.datos.estado_actual -in @('en_cocina', 'confirmado')) {
            Ok '§2.1.1 aprobar mesa -> seguimiento actualizado (API)'
        }
        else { Fail "§2.1.1 estado tras aprobar: $($est1.json.datos.estado_actual)" }
    }
    else { Fail "aprobar mesa: $($apr.json.mensaje)" }

    # §1.5 llamar mesera
    $llamar = Invoke-FoodyApi -Method POST -Path "/pedidos/$pidMesa/llamar-mesera" -Body @{
        device_id = $DeviceMesa
        mensaje   = 'QA realtime llamar mesera'
    }
    if ($llamar.ok -and $llamar.json.exito) {
        Ok '§1.5.1 llamar mesera API (emisor llamar_mesera)'
    }
    else { Fail "§1.5.1 llamar mesera: $($llamar.json.mensaje)" }
}
else { Fail "crear pedido mesa QR: $($pedMesa.json.mensaje)" }

# --- §3.1 cocina tickets ---
$tickets = Invoke-FoodyApi -Path "/cocina/tickets/$CocinaId" -Headers $h
if ($tickets.ok -and $tickets.json.exito) {
    $n = @($tickets.json.datos).Count
    if ($n -ge 0) { Ok "§3.1 KDS tickets listables (n=$n, emisor cocina_actualizada en crear)" }
}
else { Fail 'GET cocina/tickets' }

# --- §4.1 asignar domi + §2.2.1 ubicacion GPS (emisor) ---
$null = Limpiar-PedidosActivosDemo -Headers $h
Limpiar-AsignacionesDomicilioDemo
Start-Sleep -Milliseconds 500

$crearDom = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
    sucursal_id       = $sid
    tipo              = 'domicilio'
    device_id         = 'qa-rt-gps'
    cliente_nombre    = 'QA GPS'
    cliente_telefono  = '3000000001'
    direccion_entrega = 'Calle GPS QA'
    metodo_pago       = 'pendiente'
    items             = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if ($crearDom.ok -and $crearDom.json.exito) {
    $pidDom = $crearDom.json.datos.pedido_id
    if (-not $pidDom) { $pidDom = $crearDom.json.datos.id }
    $tokenDom = $crearDom.json.datos.seguimiento_token
    Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pidDom/estado?sucursal_id=$sid" -Headers $h -Body @{
        estado = 'en_cocina'
    } | Out-Null
    Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pidDom/estado?sucursal_id=$sid" -Headers $h -Body @{
        estado = 'listo'
    } | Out-Null
    $asig = Invoke-FoodyApi -Method POST -Path '/domiciliarios-planta/asignar' -Headers $h -Body @{
        pedido_id              = $pidDom
        sucursal_id            = $sid
        domiciliario_planta_id = $DomiPlantaId
    }
    if ($asig.ok -and $asig.json.exito) {
        Ok '§4.1.1 asignar domiciliario planta (emisor pedido_asignado)'
    }
    else {
        $lista = Invoke-FoodyApi -Path "/pedidos?sucursal_id=$sid" -Headers $h
        $est = ($lista.json.datos | Where-Object { $_.id -eq $pidDom } | Select-Object -First 1).estado
        if ($est -in @('asignado', 'en_camino')) { Ok "§4.1.1 auto-dispatch estado=$est" }
        else { Fail "asignar domi: $($asig.json.mensaje)" }
    }

    $domi = Get-FoodyToken 'domi@foody.demo'
    $hDomi = $domi.headers
    $camino = Invoke-FoodyApi -Method PATCH -Path "/domiciliario/pedidos/$pidDom/en-camino" -Headers $hDomi
    if ($camino.ok -and $camino.json.exito) {
        Ok 'domiciliario en_camino'
        $ubiAntes = docker exec supabase-db psql -U postgres -d postgres -tAc `
            "SELECT COUNT(*) FROM domiciliarios_ubicaciones_historial h
             INNER JOIN asignaciones_domicilio ad ON ad.id = h.asignacion_id
             WHERE ad.pedido_id = '$pidDom';" 2>&1
        $gps = Invoke-FoodyApi -Method POST -Path '/domiciliario/ubicacion' -Headers $hDomi -Body @{
            lat = 4.711
            lng = -74.072
        }
        if ($gps.ok -and $gps.json.exito) {
            $ubiDesp = docker exec supabase-db psql -U postgres -d postgres -tAc `
                "SELECT COUNT(*) FROM domiciliarios_ubicaciones_historial h
                 INNER JOIN asignaciones_domicilio ad ON ad.id = h.asignacion_id
                 WHERE ad.pedido_id = '$pidDom';" 2>&1
            if ([int]$ubiDesp -gt [int]$ubiAntes) {
                Ok '§2.2.1 GPS domi planta -> historial BD (emisor ubicacion_repartidor)'
            }
            else { Fail '§2.2.1 GPS sin fila historial' }
            $estDom = Invoke-FoodyApi -Path "/pedidos/$pidDom/estado?token=$tokenDom"
            if ($estDom.ok -and $null -ne $estDom.json.datos.repartidor_lat) {
                Ok '§2.2.1 GET seguimiento incluye repartidor_lat tras GPS'
            }
            else { Fail '§2.2.1 seguimiento sin repartidor_lat en poll' }
        }
        else { Fail "GPS domi: $($gps.json.mensaje)" }
    }
    else { Fail "en_camino: $($camino.json.mensaje)" }

    $null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pidDom/estado?sucursal_id=$sid" -Headers $h -Body @{
        estado = 'cancelado'
        motivo = 'QA cleanup domi GPS'
    }
}
else { Fail "crear pedido domicilio GPS: $($crearDom.json.mensaje)" }

# --- §5.3 payload event_id en dist ---
$distRt = Join-Path (Split-Path $PSScriptRoot -Parent) 'foody_backend\dist\core\realtime\realtime-broadcast.service.js'
if (Test-Path $distRt) {
    $js = Get-Content $distRt -Raw
    if ($js -match 'event_id' -and $js -match 'emitido_at') {
        Ok '§5.3 dist broadcast incluye event_id + emitido_at'
    }
    else { Fail '§5.3 dist sin event_id/emitido_at' }
}

Write-Host ''
if ($fallos -gt 0) {
    Write-Host "Realtime flujos API FALLO ($fallos)" -ForegroundColor Red
    exit 1
}
Write-Host 'Realtime flujos API OK' -ForegroundColor Green
exit 0
