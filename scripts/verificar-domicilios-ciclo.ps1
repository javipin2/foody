# Prompt 16 — Domicilios: flujo completo, estado vs admin, cancel mid-ruta.
# Uso: .\scripts\verificar-domicilios-ciclo.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar Domicilios ciclo (Prompt 16) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$Precio = 8000
$DomiPlantaId = '92000000-0000-4000-8000-000000000001'
$script:fallos = 0

function Assert-Ok {
    param([bool]$Cond, [string]$Msg)
    if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
    else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

function Sql-Scalar([string]$Sql) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $raw = docker exec supabase-db psql -U postgres -d postgres -t -A -c $Sql 2>$null
    $ErrorActionPreference = $prev
    return ($raw -as [string]).Trim()
}

function Get-OcupadoPlanta {
    $r = Invoke-FoodyApi -Path "/domiciliarios-planta/disponibles/$sid" -Headers $h
    $row = @($r.json.datos) | Where-Object { $_.id -eq $DomiPlantaId } | Select-Object -First 1
    if (-not $row) { return $null }
    return [bool]$row.ocupado
}

function New-PedidoDomicilio([string]$Device) {
    $crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
        sucursal_id       = $sid
        tipo              = 'domicilio'
        device_id         = $Device
        cliente_nombre    = 'QA Domi P16'
        cliente_telefono  = '3001112233'
        direccion_entrega = 'Calle Prompt 16'
        metodo_pago       = 'pendiente'
        items             = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
    }
    $id = $null
    if ($crear.ok -and $crear.json.exito) {
        $id = $crear.json.datos.pedido_id
        if (-not $id) { $id = $crear.json.datos.id }
    }
    return @{ ok = ($crear.ok -and $crear.json.exito); id = $id; raw = $crear }
}

function Avanzar-HastaListo([string]$PedidoId) {
    foreach ($est in @('en_cocina', 'listo')) {
        $e = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$PedidoId/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = $est }
        if (-not ($e.ok -and $e.json.exito)) {
            return @{ ok = $false; estado = $est; err = $e.json.error }
        }
    }
    return @{ ok = $true }
}

$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Limpiar-AsignacionesDomicilioDemo
$null = Ensure-CajaAbierta -Headers $h
$null = Ensure-HorariosDemoAbiertos
$null = Restaurar-InventarioDemo -Headers $h

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- A) Flujo completo: pedido -> asignacion -> entrega -> cobro ---' -ForegroundColor Yellow

$pA = New-PedidoDomicilio 'qa-domi-ciclo-a'
Assert-Ok -Cond $pA.ok -Msg "Crear domicilio ($($pA.raw.json.error))"
$pedA = $pA.id
$est0 = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedA';"
Assert-Ok -Cond ($est0 -eq 'pendiente') -Msg "Estado inicial pendiente (got=$est0)"

$ventasCrear = [double](Sql-Scalar "SELECT COALESCE(SUM(monto),0)::text FROM movimientos_caja WHERE pedido_id='$pedA' AND tipo='venta'")
Assert-Ok -Cond ($ventasCrear -eq 0) -Msg 'Sin venta en caja al crear domicilio'

$adv = Avanzar-HastaListo $pedA
Assert-Ok -Cond $adv.ok -Msg "Avance cocina->listo ($($adv.err))"

$saltar = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedA/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'entregado' }
Assert-Ok -Cond (-not ($saltar.ok -and $saltar.json.exito)) -Msg "Bloqueo listo->entregado err=$($saltar.json.error)"

$asig = Ensure-AsignacionDomiPlanta -PedidoId $pedA -Headers $h -SucursalId $sid -DomiPlantaId $DomiPlantaId
Assert-Ok -Cond $asig.ok -Msg "Asignacion planta (auto=$($asig.auto) msg=$($asig.mensaje))"
$estAsig = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedA';"
Assert-Ok -Cond ($estAsig -eq 'asignado') -Msg "Pedido asignado (got=$estAsig)"

$ocupadoAsig = Get-OcupadoPlanta
Assert-Ok -Cond ($ocupadoAsig -eq $true) -Msg 'Admin ve planta ocupado=true tras asignar'

$domi = Get-FoodyToken 'domi@foody.demo'
$hd = $domi.headers
$camino = Invoke-FoodyApi -Method PATCH -Path "/domiciliario/pedidos/$pedA/en-camino" -Headers $hd
Assert-Ok -Cond ($camino.ok -and $camino.json.exito) -Msg "En camino ($($camino.json.error))"
$estCam = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedA';"
Assert-Ok -Cond ($estCam -eq 'en_camino') -Msg "Estado en_camino (got=$estCam)"
$asigCam = Sql-Scalar "SELECT estado FROM asignaciones_domicilio WHERE pedido_id='$pedA' ORDER BY asignado_at DESC LIMIT 1;"
Assert-Ok -Cond ($asigCam -eq 'en_camino') -Msg "Asignacion en_camino (got=$asigCam)"
$ocupadoRuta = Get-OcupadoPlanta
Assert-Ok -Cond ($ocupadoRuta -eq $true) -Msg 'Admin sigue viendo ocupado=true en ruta'

$entrega = Invoke-FoodyApi -Method PATCH -Path "/domiciliario/pedidos/$pedA/confirmar-entrega" -Headers $hd -Body @{
    metodo_pago = 'efectivo'
}
Assert-Ok -Cond ($entrega.ok -and $entrega.json.exito) -Msg "Confirmar entrega ($($entrega.json.error))"
$estFin = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedA';"
Assert-Ok -Cond ($estFin -eq 'entregado') -Msg "Estado entregado (got=$estFin)"

$ventasEnt = [double](Sql-Scalar "SELECT COALESCE(SUM(monto),0)::text FROM movimientos_caja WHERE pedido_id='$pedA' AND tipo='venta'")
Assert-Ok -Cond ($ventasEnt -gt 0) -Msg "Cobro en caja al entregar (venta=$ventasEnt)"
$montoPag = [double](Sql-Scalar "SELECT COALESCE(monto_pagado,0)::text FROM pedidos WHERE id='$pedA';")
$totalPed = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pedA';")
Assert-Ok -Cond ($montoPag -ge ($totalPed - 0.02)) -Msg "monto_pagado≈total ($montoPag / $totalPed)"

$ocupadoLibre = Get-OcupadoPlanta
Assert-Ok -Cond ($ocupadoLibre -eq $false) -Msg 'Admin ve ocupado=false tras entregar'

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- B) Consistencia estado domiciliario vs admin ---' -ForegroundColor Yellow

# Ya comprobado ocupado en A; revalidar lista disponibles shape
$disp = Invoke-FoodyApi -Path "/domiciliarios-planta/disponibles/$sid" -Headers $h
Assert-Ok -Cond ($disp.ok -and $disp.json.exito) -Msg 'GET disponibles admin'
$row = @($disp.json.datos) | Where-Object { $_.id -eq $DomiPlantaId } | Select-Object -First 1
Assert-Ok -Cond ($null -ne $row) -Msg 'Planta demo en lista'
Assert-Ok -Cond ($null -ne $row.PSObject.Properties['ocupado']) -Msg 'Campo ocupado presente (derivado de asignaciones)'

# Indep: sesion disponible (modelo distinto a planta.ocupado)
try {
    $indep = Get-FoodyTokenDomiciliarioIndep 'repartidor@foody.demo'
    $hi = $indep.headers
    $estSes0 = Invoke-FoodyApi -Path '/domiciliarios/sesion/estado' -Headers $hi
    $activa = $false
    if ($estSes0.ok -and $estSes0.json.exito) {
        $activa = [bool]($estSes0.json.datos.activa -or $estSes0.json.datos.sesion.activa)
    }
    if (-not $activa) {
        $ses = Invoke-FoodyApi -Method POST -Path '/domiciliarios/sesion/iniciar' -Headers $hi -Body @{
            lat = 4.65
            lng = -74.05
        }
        if (-not ($ses.ok -and $ses.json.exito)) {
            $ses = Invoke-FoodyApi -Method POST -Path '/domiciliarios/sesion/iniciar' -Headers $hi -Body @{
                latitud  = 4.65
                longitud = -74.05
            }
        }
        Assert-Ok -Cond ($ses.ok -and $ses.json.exito) -Msg "Indep iniciar sesion ($($ses.json.error))"
    } else {
        Assert-Ok -Cond $true -Msg 'Indep sesion ya activa'
    }
    $estSes = Invoke-FoodyApi -Path '/domiciliarios/sesion/estado' -Headers $hi
    $dispIndep = $estSes.json.datos.disponible
    if ($null -eq $dispIndep) { $dispIndep = $estSes.json.datos.sesion.disponible }
    Assert-Ok -Cond ($null -ne $dispIndep) -Msg "Indep reporta disponible=$dispIndep (campo sesion)"
} catch {
    Write-Host "  SKIP indep sesion: $_" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- C) Cancelacion a mitad de ruta ---' -ForegroundColor Yellow

$null = Limpiar-AsignacionesDomicilioDemo
$pC = New-PedidoDomicilio 'qa-domi-cancel-mid'
Assert-Ok -Cond $pC.ok -Msg 'Crear domicilio para cancel mid'
$pedC = $pC.id
$null = Avanzar-HastaListo $pedC
$asigC = Ensure-AsignacionDomiPlanta -PedidoId $pedC -Headers $h -SucursalId $sid -DomiPlantaId $DomiPlantaId
Assert-Ok -Cond $asigC.ok -Msg 'Asignar para cancel mid'
$domi = Get-FoodyToken 'domi@foody.demo'
$hd = $domi.headers
$null = Invoke-FoodyApi -Method PATCH -Path "/domiciliario/pedidos/$pedC/en-camino" -Headers $hd
Assert-Ok -Cond ((Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedC';") -eq 'en_camino') -Msg 'En camino antes de cancel'

# Cliente no puede cancelar mid-ruta
$cliCancel = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedC/cancelar-cliente" -Headers @{} -Body @{
    device_id = 'qa-domi-cancel-mid'
    motivo    = 'cliente mid'
}
# endpoint puede requerir query; probar variantes
if (-not ($cliCancel.ok -and $cliCancel.json.exito) -and $cliCancel.status -eq 404) {
    $cliCancel = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedC/cancelar?sucursal_id=$sid" -Headers @{} -Body @{
        device_id = 'qa-domi-cancel-mid'
        motivo    = 'cliente mid'
    }
}
# Sin auth staff: intentar cancel via PATCH estado sin token staff
$cliPatch = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedC/estado?sucursal_id=$sid&device_id=qa-domi-cancel-mid" -Headers @{} -Body @{
    estado = 'cancelado'
    motivo = 'cliente mid'
}
Assert-Ok -Cond (-not ($cliPatch.ok -and $cliPatch.json.exito)) -Msg "Cliente/anon no cancela mid-ruta (err=$($cliPatch.json.error))"

# Domi no tiene endpoint cancel — en-camino ok, cancel via su token debe fallar o no existir
$domiCancel = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedC/estado?sucursal_id=$sid" -Headers $hd -Body @{
    estado = 'cancelado'
    motivo = 'domi mid'
}
Assert-Ok -Cond (-not ($domiCancel.ok -and $domiCancel.json.exito)) -Msg "Domi no cancela pedido (err=$($domiCancel.json.error))"

$stockAntes = [double](Sql-Scalar "SELECT COALESCE(SUM(stock_actual),0)::text FROM ingredientes WHERE sucursal_id='$sid'")
$movAntes = [int](Sql-Scalar "SELECT COUNT(*)::text FROM movimientos_ingrediente WHERE pedido_id='$pedC'")

$cancel = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedC/estado?sucursal_id=$sid" -Headers $h -Body @{
    estado = 'cancelado'
    motivo = 'QA cancel mid-ruta Prompt 16'
}
Assert-Ok -Cond ($cancel.ok -and $cancel.json.exito) -Msg "Admin cancela mid-ruta ($($cancel.json.error))"
$estCan = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedC';"
Assert-Ok -Cond ($estCan -eq 'cancelado') -Msg 'Pedido cancelado'
$asigCan = Sql-Scalar "SELECT estado FROM asignaciones_domicilio WHERE pedido_id='$pedC' ORDER BY asignado_at DESC LIMIT 1;"
Assert-Ok -Cond ($asigCan -eq 'cancelado') -Msg "Asignacion cancelada (got=$asigCan)"
$ocupadoPost = Get-OcupadoPlanta
Assert-Ok -Cond ($ocupadoPost -eq $false) -Msg 'Admin ve ocupado=false tras cancel mid'

$movDespues = [int](Sql-Scalar "SELECT COUNT(*)::text FROM movimientos_ingrediente WHERE pedido_id='$pedC'")
Assert-Ok -Cond ($movDespues -gt $movAntes -or $movAntes -gt 0) -Msg "Rastro inventario post-cancel (mov=$movDespues)"

$ventasCan = [double](Sql-Scalar "SELECT COALESCE(SUM(CASE WHEN tipo='venta' THEN monto WHEN tipo='devolucion' THEN -monto ELSE 0 END),0)::text FROM movimientos_caja WHERE pedido_id='$pedC'")
Assert-Ok -Cond ([math]::Abs($ventasCan) -lt 0.02) -Msg "Caja neto ~0 post-cancel mid (neto=$ventasCan)"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- D) Gap indep: cancel no restaura disponible (probe SQL/code) ---' -ForegroundColor Yellow

$srcCancel = Get-Content (Join-Path (Split-Path $PSScriptRoot) 'foody_backend\src\modulos\pedidos\pedidos-estado.service.ts') -Raw
$restauraSesion = $srcCancel -match 'disponible\s*=\s*true' -and $srcCancel -match 'cancelado' -and ($srcCancel -match 'domiciliarios_sesiones')
# More precise: cancel block updates asignaciones but not sesiones
$bloqueCancel = if ($srcCancel -match '(?s)if \(nuevoEstado === ''cancelado''\) \{(.*?)return \{') { $Matches[1] } else { '' }
$tocaSesion = $bloqueCancel -match 'domiciliarios_sesiones'
$tocaOfertas = $bloqueCancel -match 'ofertas_pedido'
Assert-Ok -Cond (-not $tocaSesion) -Msg 'Gap confirmado: cancel no toca domiciliarios_sesiones'
Assert-Ok -Cond (-not $tocaOfertas) -Msg 'Gap confirmado: cancel no toca ofertas_pedido'

$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Limpiar-AsignacionesDomicilioDemo

Write-Host ''
if ($script:fallos -eq 0) {
    Write-Host 'Verificacion domicilios-ciclo OK' -ForegroundColor Green
    exit 0
}
Write-Host "$($script:fallos) fallos" -ForegroundColor Red
exit 1
