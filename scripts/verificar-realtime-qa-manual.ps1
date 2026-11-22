# QA manual Realtime - guia + modo asistido (2 pestanas)
# Uso:
#   .\scripts\verificar-realtime-qa-manual.ps1           # preflight API + guia
#   .\scripts\verificar-realtime-qa-manual.ps1 -Asistido # dispara acciones; tu confirmas en UI
#   .\scripts\verificar-realtime-qa-manual.ps1 -SoloPreflight

param(
    [switch]$Asistido,
    [switch]$SoloPreflight,
    [int]$PuertoCliente = 8080,
    [int]$PuertoAdmin = 8081
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\qa-helpers.ps1"

$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$MesaQrId = '30000000-0000-4000-8000-000000000001'

function Write-Paso {
    param([string]$Id, [string]$Titulo, [string[]]$Instrucciones)
    Write-Host ''
    Write-Host "=== $Id - $Titulo ===" -ForegroundColor Cyan
    foreach ($line in $Instrucciones) {
        Write-Host "  $line" -ForegroundColor White
    }
}

function Confirmar-Ui {
    param([string]$Pregunta)
    if (-not $Asistido) { return $false }
    $r = Read-Host "$Pregunta [s/n]"
    return ($r -match '^[sSyY]')
}

function Registrar-Resultado {
    param([string]$Id, [bool]$Ok)
    $script:resultados += [pscustomobject]@{ id = $Id; ok = $Ok }
    if ($Ok) { Write-Host "  -> $Id OK UI" -ForegroundColor Green }
    else { Write-Host "  -> $Id FALLO UI" -ForegroundColor Red; $script:fallosUi++ }
}

$fallosUi = 0
$resultados = @()

Write-Host '=== QA Realtime - manual / asistido ===' -ForegroundColor Cyan
Write-Host "Checklist: docs\CHECKLIST_QA_REALTIME.md" -ForegroundColor DarkGray
Write-Host ''

& "$PSScriptRoot\verificar-realtime-api.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host 'FALLO preflight API — corrige antes de QA UI' -ForegroundColor Red
    exit 1
}

if ($SoloPreflight) {
    Write-Host 'Preflight Realtime OK (--SoloPreflight)' -ForegroundColor Green
    exit 0
}

$baseCliente = "http://localhost:$PuertoCliente"
$baseAdmin = "http://localhost:$PuertoAdmin"

Write-Host ''
Write-Host '========== Preparacion (2 ventanas) ==========' -ForegroundColor Yellow
Write-Host "1. Cliente (puerto $PuertoCliente):" -ForegroundColor White
Write-Host "   .\scripts\flutter-run-flavor.ps1 -Flavor cliente -Device chrome -WebPort $PuertoCliente" -ForegroundColor DarkGray
Write-Host "2. Admin equipo (puerto $PuertoAdmin):" -ForegroundColor White
Write-Host "   .\scripts\flutter-run-flavor.ps1 -Flavor equipo -Device chrome -WebPort $PuertoAdmin" -ForegroundColor DarkGray
Write-Host '3. Login admin: admin@foody.demo / 123456' -ForegroundColor White
Write-Host "   Kanban:    ${baseAdmin}/admin/panel?seccion=pedidos" -ForegroundColor DarkGray
Write-Host "   Caja:      ${baseAdmin}/admin/panel?seccion=caja" -ForegroundColor DarkGray
Write-Host "   Mesero:    ${baseAdmin}/admin/mesero" -ForegroundColor DarkGray
Write-Host "   Domi:      ${baseAdmin}/admin/panel?seccion=domiciliarios" -ForegroundColor DarkGray
Write-Host "4. Cliente:   ${baseCliente}/cliente" -ForegroundColor White
Write-Host ''
if (-not $Asistido) {
    Write-Host 'Modo guia. Para disparar acciones API y confirmar en pantalla:' -ForegroundColor DarkYellow
    Write-Host '  .\scripts\verificar-realtime-qa-manual.ps1 -Asistido' -ForegroundColor DarkYellow
    exit 0
}

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$null = Ensure-CajaAbierta -Headers $h

# --- 1.1.1 Kanban: nuevo pedido ---
Write-Paso '1.1.1' 'pedido_actualizado -> Kanban' @(
    "Abre Kanban: ${baseAdmin}/admin/panel?seccion=pedidos"
    'El script creara un pedido mostrador; debe aparecer tarjeta sin F5 en menos de 3 s.'
)
$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-ui-kanban'
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if (-not ($crear.ok -and $crear.json.exito)) {
    Write-Host "FALLO crear pedido: $($crear.json.mensaje)" -ForegroundColor Red
    exit 1
}
$pidKanban = $crear.json.datos.pedido_id
if (-not $pidKanban) { $pidKanban = $crear.json.datos.id }
Registrar-Resultado '1.1.1' (Confirmar-Ui 'Viste la tarjeta nueva en el Kanban?')

# --- 1.1.2 Kanban: cambio estado ---
Write-Paso '1.1.2' 'Kanban segunda pestana / columna' @(
    'Con el mismo Kanban (u otra pestana admin en Pedidos), observa el cambio de columna.'
)
$mov = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pidKanban/estado?sucursal_id=$sid" -Headers $h -Body @{
    estado = 'en_cocina'
}
if (-not ($mov.ok -and $mov.json.exito)) {
    Write-Host "FALLO cambiar estado: $($mov.json.mensaje)" -ForegroundColor Red
}
else {
    Registrar-Resultado '1.1.2' (Confirmar-Ui 'El pedido se movio a En cocina sin F5?')
}

# --- 1.3.3 Caja: retiro en otra pestana ---
Write-Paso '1.3.3' 'caja_movimiento retiro' @(
    "Abre Caja en DOS pestanas: ${baseAdmin}/admin/panel?seccion=caja"
    'El script registrara un retiro de $1; ambas deben mostrar movimiento/saldo nuevo.'
)
$activa = Invoke-FoodyApi -Path "/caja/activa/$sid" -Headers $h
$cajaId = $activa.json.datos.id
$ret = Invoke-FoodyApi -Method POST -Path '/caja/retiro-parcial' -Headers $h -Body @{
    caja_id     = $cajaId
    monto       = 1
    descripcion = 'QA UI realtime retiro'
}
if ($ret.ok -and $ret.json.exito) {
    Registrar-Resultado '1.3.3' (Confirmar-Ui 'Ambas pestanas Caja actualizaron retiro?')
}
else {
    Registrar-Resultado '1.3.3' $false
}

# --- 1.2.1 / 1.4.1 Mesas: QR pendiente ---
Write-Paso '1.2.1+1.4.1' 'mesas + QR urgente' @(
    "Abre grid mesero: ${baseAdmin}/admin/mesero"
    'El script creara pedido mesa QR (pendiente_aprobacion); mesa naranja o SnackBar.'
)
foreach ($m in @((Invoke-FoodyApi -Path "/mesas/$sid" -Headers $h).json.datos | Where-Object { $_.id -eq $MesaQrId })) {
    if ($m.pedido_id) {
        $null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$($m.pedido_id)/estado?sucursal_id=$sid" -Headers $h -Body @{
            estado = 'cancelado'; motivo = 'QA UI cleanup mesa'
        }
        Start-Sleep -Milliseconds 500
    }
}
$devMesa = 'qa-ui-mesa-qr'
$pedMesa = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
    sucursal_id = $sid
    mesa_id     = $MesaQrId
    tipo        = 'mesa'
    device_id   = $devMesa
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if ($pedMesa.ok -and $pedMesa.json.exito) {
    $pidMesa = $pedMesa.json.datos.pedido_id
    if (-not $pidMesa) { $pidMesa = $pedMesa.json.datos.id }
    $tokenMesa = $pedMesa.json.datos.seguimiento_token
    $ok141 = Confirmar-Ui 'Grid mesero mostro QR pendiente (color/SnackBar)?'
    Registrar-Resultado '1.4.1' $ok141
    Registrar-Resultado '1.2.1' $ok141
}
else {
    Registrar-Resultado '1.4.1' $false
    Registrar-Resultado '1.2.1' $false
    $pidMesa = $null
    $tokenMesa = $null
}

# --- 2.1.1 Seguimiento cliente ---
if ($pidMesa -and $tokenMesa) {
    Write-Paso '2.1.1' 'estado_actualizado -> seguimiento' @(
        "Abre seguimiento: ${baseCliente}/pedidos/${pidMesa}/seguimiento?token=${tokenMesa}"
        'El script aprobara el pedido; la pantalla debe pasar a en cocina sin F5.'
    )
    $apr = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pidMesa/aprobar?sucursal_id=$sid" -Headers $h
    if ($apr.ok -and $apr.json.exito) {
        Registrar-Resultado '2.1.1' (Confirmar-Ui 'Seguimiento cliente actualizo estado?')
    }
    else {
        Registrar-Resultado '2.1.1' $false
    }
}

# --- 1.5.1 Llamar mesera ---
if ($pidMesa) {
    Write-Paso '1.5.1' 'llamar_mesera' @(
        'Con grid mesero aun abierto, el script llama mesera desde API cliente.'
        'Esperado: SnackBar turquesa en grid en menos de 3 s.'
    )
    Start-Sleep -Seconds 2
    $ll = Invoke-FoodyApi -Method POST -Path "/pedidos/$pidMesa/llamar-mesera" -Body @{
        device_id = $devMesa
        mensaje   = 'QA UI llamar mesera'
    }
    if ($ll.ok -and $ll.json.exito) {
        Registrar-Resultado '1.5.1' (Confirmar-Ui 'Viste SnackBar llamar mesera en grid?')
    }
    else {
        Write-Host "  AVISO llamar mesera: $($ll.json.error) $($ll.json.mensaje)" -ForegroundColor Yellow
        Registrar-Resultado '1.5.1' $false
    }
}

# --- 5.2 Coalesce: kanban + domi admin ---
Write-Paso '5.2' 'coalesce sucursal_actualizada' @(
    "Abre Kanban Y Domiciliarios: ${baseAdmin}/admin/panel?seccion=pedidos + ?seccion=domiciliarios"
    'El script creara pedido domicilio; ambos paneles deben refrescar tras un burst.'
)
$crearDom = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
    sucursal_id       = $sid
    tipo              = 'domicilio'
    device_id         = 'qa-ui-coalesce'
    cliente_nombre    = 'QA Coalesce'
    cliente_telefono  = '3000000099'
    direccion_entrega = 'Calle coalesce'
    metodo_pago       = 'pendiente'
    items             = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if ($crearDom.ok -and $crearDom.json.exito) {
    $ok52 = Confirmar-Ui 'Kanban Y domiciliarios admin actualizaron sin F5?'
    Registrar-Resultado '5.2' $ok52
    Registrar-Resultado '1.1.3' $ok52
}
else {
    Registrar-Resultado '5.2' $false
}

# --- Fase 2: mas checklist UI (misma sesion) ---
Write-Host ''
Write-Host '========== Fase 2 (opcional misma sesion) ==========' -ForegroundColor Yellow

# 1.3.1 Caja abierta visible
Write-Paso '1.3.1' 'caja_movimiento apertura' @(
    "Caja admin: ${baseAdmin}/admin/panel?seccion=caja"
    'La caja demo ya esta abierta; otra pestana debe mostrar turno activo.'
)
Registrar-Resultado '1.3.1' (Confirmar-Ui 'Panel Caja muestra turno abierto (sin F5)?')

# 1.3.2 Cobro pedido -> movimiento caja
Write-Paso '1.3.2' 'caja_movimiento venta' @(
    "Mantén Caja abierta: ${baseAdmin}/admin/panel?seccion=caja"
    'El script cobrara un pedido mostrador; debe aparecer movimiento de venta.'
)
$crearVenta = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-ui-caja-venta'
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if ($crearVenta.ok -and $crearVenta.json.exito) {
    $pidVenta = $crearVenta.json.datos.pedido_id
    if (-not $pidVenta) { $pidVenta = $crearVenta.json.datos.id }
    $null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pidVenta/estado?sucursal_id=$sid" -Headers $h -Body @{
        estado = 'listo'
    }
    $cobro = Invoke-FoodyApi -Method POST -Path "/pedidos/$pidVenta/cobrar?sucursal_id=$sid" -Headers $h -Body @{
        metodo_pago = 'efectivo'
    }
    if ($cobro.ok -and $cobro.json.exito) {
        Registrar-Resultado '1.3.2' (Confirmar-Ui 'Viste movimiento de cobro en Caja?')
    }
    else {
        Write-Host "  AVISO cobro: $($cobro.json.mensaje)" -ForegroundColor Yellow
        Registrar-Resultado '1.3.2' $false
    }
}
else {
    Registrar-Resultado '1.3.2' $false
}

# 2.1.2 Seguimiento: pedido listo
if ($pidMesa -and $tokenMesa) {
    Write-Paso '2.1.2' 'estado_actualizado listo' @(
        "Seguimiento: ${baseCliente}/pedidos/${pidMesa}/seguimiento?token=${tokenMesa}"
        'El script marcara el pedido como listo; la pantalla debe actualizar.'
    )
    $listo = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pidMesa/estado?sucursal_id=$sid" -Headers $h -Body @{
        estado = 'listo'
    }
    if ($listo.ok -and $listo.json.exito) {
        Registrar-Resultado '2.1.2' (Confirmar-Ui 'Seguimiento muestra estado listo sin F5?')
    }
    else {
        Registrar-Resultado '2.1.2' $false
    }
}

# 3.1 KDS ticket nuevo
$CocinaId = 'd0000000-0000-4000-8000-000000000001'
Write-Paso '3.1' 'cocina_actualizada -> KDS' @(
    "Abre KDS: ${baseAdmin}/admin/cocina"
    'El script enviara un pedido a en_cocina; debe aparecer ticket sin F5.'
)
$ticketsAntes = @((Invoke-FoodyApi -Path "/cocina/tickets/$CocinaId" -Headers $h).json.datos).Count
$crearKds = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-ui-kds'
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if ($crearKds.ok -and $crearKds.json.exito) {
    $pidKds = $crearKds.json.datos.pedido_id
    if (-not $pidKds) { $pidKds = $crearKds.json.datos.id }
    $null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pidKds/estado?sucursal_id=$sid" -Headers $h -Body @{
        estado = 'en_cocina'
    }
    Start-Sleep -Milliseconds 500
    $ticketsDesp = @((Invoke-FoodyApi -Path "/cocina/tickets/$CocinaId" -Headers $h).json.datos).Count
    if ($ticketsDesp -ge $ticketsAntes) {
        Registrar-Resultado '3.1' (Confirmar-Ui 'Viste ticket nuevo en KDS sin F5?')
    }
    else {
        Registrar-Resultado '3.1' $false
    }
}
else {
    Registrar-Resultado '3.1' $false
}

# 1.6.1 Menu cliente: producto agotado
Write-Paso '1.6.1' 'catalogo_disponibilidad menu' @(
    "Menu cliente abierto: ${baseCliente}/cliente (sucursal demo)"
    'El script agotara el producto demo; debe dejar de mostrarse o marcarse no disponible.'
)
$off = Invoke-FoodyApi -Method PATCH -Path "/productos/$Producto/disponibilidad" -Headers $h -Body @{
    disponible = $false
}
if ($off.ok -and $off.json.exito) {
    $ok161 = Confirmar-Ui 'El producto demo ya no esta disponible en el menu?'
    Registrar-Resultado '1.6.1' $ok161
    $null = Invoke-FoodyApi -Method PATCH -Path "/productos/$Producto/disponibilidad" -Headers $h -Body @{
        disponible = $true
    }
}
else {
    Registrar-Resultado '1.6.1' $false
}

# 4.1.1 Domiciliario planta: asignacion en panel admin
Write-Paso '4.1.1' 'pedido_asignado domi planta' @(
    "Domiciliarios admin: ${baseAdmin}/admin/panel?seccion=domiciliarios"
    'El script asignara domiciliario a un pedido listo.'
)
$null = Limpiar-AsignacionesDomicilioDemo
$crearDomAsig = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
    sucursal_id       = $sid
    tipo              = 'domicilio'
    device_id         = 'qa-ui-domi-asig'
    cliente_nombre    = 'QA Domi UI'
    cliente_telefono  = '3000000088'
    direccion_entrega = 'Calle domi QA'
    metodo_pago       = 'pendiente'
    items             = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if ($crearDomAsig.ok -and $crearDomAsig.json.exito) {
    $pidDomUi = $crearDomAsig.json.datos.pedido_id
    if (-not $pidDomUi) { $pidDomUi = $crearDomAsig.json.datos.id }
    $null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pidDomUi/estado?sucursal_id=$sid" -Headers $h -Body @{
        estado = 'en_cocina'
    }
    $null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pidDomUi/estado?sucursal_id=$sid" -Headers $h -Body @{
        estado = 'listo'
    }
    $asigUi = Invoke-FoodyApi -Method POST -Path '/domiciliarios-planta/asignar' -Headers $h -Body @{
        pedido_id              = $pidDomUi
        sucursal_id            = $sid
        domiciliario_planta_id = '92000000-0000-4000-8000-000000000001'
    }
    if ($asigUi.ok -and $asigUi.json.exito) {
        Registrar-Resultado '4.1.1' (Confirmar-Ui 'Panel domiciliarios muestra pedido asignado sin F5?')
    }
    else {
        $estDom = (Invoke-FoodyApi -Path "/pedidos?sucursal_id=$sid" -Headers $h).json.datos |
            Where-Object { $_.id -eq $pidDomUi } | Select-Object -First 1
        if ($estDom.estado -in @('asignado', 'en_camino')) {
            Registrar-Resultado '4.1.1' (Confirmar-Ui 'Panel domiciliarios actualizo (auto-dispatch)?')
        }
        else {
            Registrar-Resultado '4.1.1' $false
        }
    }
}
else {
    Registrar-Resultado '4.1.1' $false
}

# --- Resumen sesion ---
$fecha = Get-Date -Format 'yyyy-MM-dd'
$sesionDir = Join-Path $raiz 'docs\qa-sesiones'
if (-not (Test-Path $sesionDir)) { New-Item -ItemType Directory -Path $sesionDir | Out-Null }
$sesionFile = Join-Path $sesionDir "$fecha-realtime.md"
$lineas = @(
    "# Sesion QA Realtime - $fecha",
    '',
    '| Paso | UI OK |',
    '|------|-------|'
)
foreach ($r in $resultados) {
    $mark = if ($r.ok) { 'si' } else { 'no' }
    $lineas += "| $($r.id) | $mark |"
}
$lineas += ''
$lineas += "Automatizado: verificar-realtime-api.ps1 OK"
$lineas += "Puertos: cliente :$PuertoCliente, admin :$PuertoAdmin"
$lineas | Set-Content -Path $sesionFile -Encoding UTF8

Write-Host ''
Write-Host "Resumen guardado: docs\qa-sesiones\$fecha-realtime.md" -ForegroundColor DarkGray
if ($fallosUi -gt 0) {
    Write-Host "QA UI Realtime: $fallosUi paso(s) fallaron" -ForegroundColor Red
    exit 1
}
Write-Host 'QA UI Realtime: todos los pasos confirmados' -ForegroundColor Green
exit 0
