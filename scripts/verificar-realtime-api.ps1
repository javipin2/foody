# Verificacion Realtime con API viva (emisores + coherencia de negocio)
# Uso: .\scripts\verificar-realtime-api.ps1

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\qa-helpers.ps1"

$fallos = 0
function Ok($msg) { Write-Host "OK $msg" -ForegroundColor Green }
function Fail($msg) {
    Write-Host "FALLO $msg" -ForegroundColor Red
    $script:fallos++
}

Write-Host '=== Verificar Realtime API (coherencia) ===' -ForegroundColor Cyan
Ensure-HorariosDemoAbiertos

# 1. Estatico + salud
& "$PSScriptRoot\verificar-realtime.ps1"
if ($LASTEXITCODE -ne 0) { $fallos++ }

$rt = Invoke-FoodyApi -Path '/health/realtime'
if ($rt.ok -and $rt.json.datos.conectado) {
    Ok 'Realtime WS conectado'
}
else {
    Fail "Realtime desconectado: $($rt.json.datos.detalle)"
}

# 2. Dist backend cargado (metodos RT-8)
$distRt = Join-Path $raiz 'foody_backend\dist\core\realtime\realtime-broadcast.service.js'
if (Test-Path $distRt) {
    $js = Get-Content $distRt -Raw
    if ($js -match 'ubicacionRepartidor' -and $js -match 'event_id') {
        Ok 'dist incluye RT-8 (ubicacionRepartidor + event_id)'
    }
    else {
        Fail 'dist sin RT-8 — ejecuta: cd foody_backend; npm run build; reinicia API'
    }
}
else {
    Fail 'dist no compilado'
}

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal

# 3. Caja: retiro emite movimiento coherente
if (Ensure-CajaAbierta -Headers $h) {
    $activa = Invoke-FoodyApi -Path "/caja/activa/$sid" -Headers $h
    $cajaId = $activa.json.datos.id
    $antes = Invoke-FoodyApi -Path "/caja/$cajaId/movimientos" -Headers $h
    $nAntes = @($antes.json.datos).Count

    $ret = Invoke-FoodyApi -Method POST -Path '/caja/retiro-parcial' -Headers $h -Body @{
        caja_id     = $cajaId
        monto       = 1
        descripcion = 'QA realtime retiro'
    }
    if ($ret.ok -and $ret.json.exito) {
        Start-Sleep -Milliseconds 400
        $despues = Invoke-FoodyApi -Path "/caja/$cajaId/movimientos" -Headers $h
        if (@($despues.json.datos).Count -gt $nAntes) {
            Ok 'retiro-parcial agrega movimiento en BD'
        }
        else {
            Fail 'retiro-parcial no reflejado en movimientos'
        }
    }
    else {
        Fail "retiro-parcial API: $($ret.json.mensaje)"
    }
}
else {
    Fail 'no se pudo abrir caja demo'
}

# 4. Topping disponibilidad (emisor catalogo_disponibilidad)
$toppings = Invoke-FoodyApi -Path "/toppings/$sid" -Headers $h
if (-not ($toppings.ok -and $toppings.json.exito)) {
    Fail 'listar toppings'
}
else {
    $top = @($toppings.json.datos) | Select-Object -First 1
    if ($top) {
        $tid = $top.id
        $patch = Invoke-FoodyApi -Method PATCH -Path "/toppings/$tid" -Headers $h -Body @{
            disponible = $false
        }
        if ($patch.ok -and $patch.json.exito) {
            Ok 'PATCH topping disponible=false'
            $rev = Invoke-FoodyApi -Method PATCH -Path "/toppings/$tid" -Headers $h -Body @{
                disponible = $true
            }
            if ($rev.ok -and $rev.json.exito) {
                Ok 'PATCH topping disponible=true (restaurado)'
            }
            else {
                Fail 'revertir topping'
            }
        }
        else {
            Fail 'PATCH topping disponible'
        }
    }
    else {
        Write-Host 'AVISO sin toppings en demo — omitido' -ForegroundColor Yellow
    }
}

# 5. Cancelar pedido con domiciliario desasigna (API coherente)
$null = Limpiar-PedidosActivosDemo -Headers $h
# Liberar domiciliario demo si quedo pedido activo de QA anterior
$activos = Invoke-FoodyApi -Path "/pedidos?sucursal_id=$sid" -Headers $h
foreach ($p in @($activos.json.datos | Where-Object {
        $_.tipo -eq 'domicilio' -and $_.estado -notin @('cancelado', 'rechazado', 'pagado', 'entregado')
    })) {
    $null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$($p.id)/estado?sucursal_id=$sid" -Headers $h -Body @{
        estado = 'cancelado'
        motivo = 'QA cleanup domicilio'
    }
}
Start-Sleep -Seconds 1
Limpiar-AsignacionesDomicilioDemo
Start-Sleep -Milliseconds 500
$DomiPlantaId = '92000000-0000-4000-8000-000000000001'
$Producto = 'f0000000-0000-4000-8000-000000000002'

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
    sucursal_id       = $sid
    tipo              = 'domicilio'
    device_id         = 'qa-rt-domi'
    cliente_nombre    = 'QA RT'
    cliente_telefono  = '3000000000'
    direccion_entrega = 'Calle QA Realtime 1'
    metodo_pago       = 'pendiente'
    items             = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if ($crear.ok -and $crear.json.exito) {
    $pedidoId = $crear.json.datos.pedido_id
    if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }
    Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{
        estado = 'en_cocina'
    } | Out-Null
    Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{
        estado = 'listo'
    } | Out-Null
    $lista = Invoke-FoodyApi -Path "/pedidos?sucursal_id=$sid" -Headers $h
    $estadoPed = ($lista.json.datos | Where-Object { $_.id -eq $pedidoId } | Select-Object -First 1).estado
    if ($estadoPed -eq 'listo') {
        $asig = Invoke-FoodyApi -Method POST -Path '/domiciliarios-planta/asignar' -Headers $h -Body @{
            pedido_id              = $pedidoId
            sucursal_id            = $sid
            domiciliario_planta_id = $DomiPlantaId
        }
        if (-not ($asig.ok -and $asig.json.exito)) {
            Fail "asignar domiciliario: $($asig.json.error) $($asig.json.mensaje)"
            $asig = $null
        }
    }
    elseif ($estadoPed -in @('asignado', 'en_camino')) {
        Ok "auto-dispatch dejo pedido en $estadoPed"
        $asig = @{ ok = $true; json = @{ exito = $true } }
    }
    else {
        Fail "pedido no listo ni asignado tras cocina: estado=$estadoPed"
        $asig = $null
    }
    if ($asig -and $asig.ok -and $asig.json.exito) {
        $cancel = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{
            estado = 'cancelado'
            motivo = 'QA realtime desasignar'
        }
        if ($cancel.ok -and $cancel.json.exito) {
            $asigDb = docker exec supabase-db psql -U postgres -d postgres -tAc `
                "SELECT estado FROM asignaciones_domicilio WHERE pedido_id='$pedidoId' ORDER BY asignado_at DESC LIMIT 1;" 2>&1
            if ($asigDb -match 'cancelado') {
                Ok 'cancelar pedido cancela asignacion domicilio (BD)'
            }
            elseif ([string]::IsNullOrWhiteSpace($asigDb)) {
                Ok 'cancelar pedido elimino asignacion activa (sin fila)'
            }
            else {
                Fail "asignacion no cancelada: $asigDb"
            }
        }
        else {
            Fail "cancelar pedido domicilio: $($cancel.json.error) $($cancel.json.mensaje)"
        }
    }
}
else {
    Fail "crear pedido domicilio QA: $($crear.json.error) $($crear.json.mensaje)"
}

# 6. Migraciones BD (055 cancelado domi, 067 seguimiento_token)
$chk055 = docker exec supabase-db psql -U postgres -d postgres -tAc `
    "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'asignaciones_domicilio_estado_check';" 2>&1
if ($chk055 -match 'cancelado') {
    Ok 'migracion 055: estado cancelado en asignaciones_domicilio'
}
else {
    Fail "migracion 055 no aplicada: $chk055"
}

$col067 = docker exec supabase-db psql -U postgres -d postgres -tAc `
    "SELECT 1 FROM information_schema.columns WHERE table_name='pedidos' AND column_name='seguimiento_token';" 2>&1
if ($col067 -match '1') {
    Ok 'migracion 067: columna seguimiento_token'
}
else {
    Fail 'migracion 067 no aplicada (seguimiento_token)'
}

# 7. Seguimiento pedido: auth device_id / token (RT-9)
$DeviceRt = 'qa-rt-seguimiento-device'
$crearCliente = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
    sucursal_id       = $sid
    tipo              = 'para_llevar'
    device_id         = $DeviceRt
    cliente_nombre    = 'QA Seguimiento'
    metodo_pago       = 'pendiente'
    items             = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if ($crearCliente.ok -and $crearCliente.json.exito) {
    $pidSeg = $crearCliente.json.datos.pedido_id
    if (-not $pidSeg) { $pidSeg = $crearCliente.json.datos.id }
    $tokenSeg = $crearCliente.json.datos.seguimiento_token
    if ($tokenSeg) {
        Ok 'POST /pedidos devuelve seguimiento_token'
    }
    else {
        Fail 'POST /pedidos sin seguimiento_token'
    }

    $sinAuth = Invoke-FoodyApi -Path "/pedidos/$pidSeg/estado"
    if (-not $sinAuth.ok -and $sinAuth.status -eq 403) {
        Ok 'GET estado sin auth -> 403'
    }
    else {
        Fail "GET estado sin auth deberia 403 (status=$($sinAuth.status))"
    }

    $conDevice = Invoke-FoodyApi -Path "/pedidos/$pidSeg/estado?device_id=$DeviceRt"
    if ($conDevice.ok -and $conDevice.json.exito) {
        Ok 'GET estado con device_id autorizado'
    }
    else {
        Fail "GET estado device_id: $($conDevice.json.mensaje)"
    }

    $tokenMal = Invoke-FoodyApi -Path "/pedidos/$pidSeg/estado?token=00000000-0000-4000-8000-000000000099"
    if (-not $tokenMal.ok -and $tokenMal.status -eq 403) {
        Ok 'GET estado token invalido -> 403'
    }
    else {
        Fail 'GET estado token invalido deberia 403'
    }

    $tokenOk = Invoke-FoodyApi -Path "/pedidos/$pidSeg/estado?token=$tokenSeg"
    if ($tokenOk.ok -and $tokenOk.json.exito) {
        Ok 'GET estado con token valido'
    }
    else {
        Fail "GET estado token valido: $($tokenOk.json.mensaje)"
    }
}
else {
    Fail "crear pedido cliente QA seguimiento: $($crearCliente.json.mensaje)"
}

# 8. Flujos checklist §1-4 (emisores por dominio)
& "$PSScriptRoot\verificar-realtime-flujos-api.ps1"
if ($LASTEXITCODE -ne 0) { $fallos++ }

Write-Host ''
if ($fallos -gt 0) {
    Write-Host "Realtime API FALLO ($fallos)" -ForegroundColor Red
    exit 1
}
Write-Host 'Realtime API OK (coherencia verificada)' -ForegroundColor Green
exit 0
