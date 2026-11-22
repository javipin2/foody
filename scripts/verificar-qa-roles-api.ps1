# QA por rol — capa API (CHECKLIST_QA_ROLES.md seccion 3)
# Complementa UI manual; no sustituye prueba visual Flutter.
# Uso: .\scripts\verificar-qa-roles-api.ps1

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$MesaQr = '30000000-0000-4000-8000-000000000001'
$MesaDemo = '7170df60-ca76-4049-9248-8c6f1f799a42'
$CocinaId = 'd0000000-0000-4000-8000-000000000001'

$fallos = 0
$resultados = @()

function Ok-Rol {
    param([string]$Rol, [string]$Paso)
    Write-Host "  OK  [$Rol] $Paso" -ForegroundColor Green
    $script:resultados += [pscustomobject]@{ rol = $Rol; paso = $Paso; ok = $true }
}

function Fail-Rol {
    param([string]$Rol, [string]$Paso, [string]$Detalle = '')
    Write-Host "  FALLO  [$Rol] $Paso $Detalle" -ForegroundColor Red
    $script:fallos++
    $script:resultados += [pscustomobject]@{ rol = $Rol; paso = $Paso; ok = $false; detalle = $Detalle }
}

function Login-Rol {
    param([string]$Email)
    try {
        return Get-FoodyToken $Email
    }
    catch {
        return $null
    }
}

Write-Host '=== QA roles API (checklist sec3) ===' -ForegroundColor Cyan

Ensure-HorariosDemoAbiertos

# --- 3.1 Cliente ---
$ciudades = Invoke-FoodyApi -Path '/ciudades'
if ($ciudades.ok -and $ciudades.json.exito -and @($ciudades.json.datos).Count -gt 0) {
    Ok-Rol 'Cliente' 'GET /ciudades'
}
else { Fail-Rol 'Cliente' 'GET /ciudades' }

$menu = Invoke-FoodyApi -Path "/menu/$sid"
if ($menu.ok -and $menu.json.exito -and $menu.json.datos.categorias) {
    Ok-Rol 'Cliente' 'GET /menu/:sucursal'
}
else { Fail-Rol 'Cliente' 'GET /menu/:sucursal' }

$devCli = 'qa-roles-cliente'
$pedCli = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = $devCli
    cliente_nombre = 'QA Roles'
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if ($pedCli.ok -and $pedCli.json.exito) {
    Ok-Rol 'Cliente' 'POST /pedidos para_llevar'
    $pidCli = $pedCli.json.datos.pedido_id
    if (-not $pidCli) { $pidCli = $pedCli.json.datos.id }
    $tokenCli = $pedCli.json.datos.seguimiento_token
    $estCli = Invoke-FoodyApi -Path "/pedidos/$pidCli/estado?device_id=$devCli"
    if ($estCli.ok -and $estCli.json.exito) {
        Ok-Rol 'Cliente' 'GET seguimiento device_id'
    }
    else { Fail-Rol 'Cliente' 'GET seguimiento' }
    if ($tokenCli) { Ok-Rol 'Cliente' 'seguimiento_token en respuesta' }
}
else { Fail-Rol 'Cliente' 'POST /pedidos' $pedCli.json.mensaje }

$domZona = Invoke-FoodyApi -Path "/zonas/cotizar-domicilio?sucursal_id=$sid&lat=10.483&lng=-73.263"
if ($domZona.ok -and $domZona.json.exito) {
    Ok-Rol 'Cliente' 'GET cotizar-domicilio'
}
else { Fail-Rol 'Cliente' 'cotizar domicilio' }

# --- 3.2 Mesa QR ---
$devMesa = 'qa-roles-mesa-qr'
$pedMesa = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
    sucursal_id = $sid
    mesa_id     = $MesaQr
    tipo        = 'mesa'
    device_id   = $devMesa
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
}
if ($pedMesa.ok -and $pedMesa.json.exito) {
    $pidMesa = $pedMesa.json.datos.pedido_id
    if (-not $pidMesa) { $pidMesa = $pedMesa.json.datos.id }
    $estMesa = Invoke-FoodyApi -Path "/pedidos/$pidMesa/estado?device_id=$devMesa"
    if ($estMesa.ok -and $estMesa.json.datos.estado_actual -eq 'pendiente_aprobacion') {
        Ok-Rol 'Mesa QR' 'pedido pendiente_aprobacion'
    }
    else { Fail-Rol 'Mesa QR' 'estado inicial' }
    $meseroApr = Login-Rol 'mesero@foody.com'
    if ($meseroApr) {
        # Admin sin mesera_id es rechazado a propósito; el flujo real es mesero (o admin+mesera_id).
        $apr = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pidMesa/aprobar?sucursal_id=$sid" -Headers $meseroApr.headers
        if ($apr.ok -and $apr.json.exito) {
            Ok-Rol 'Mesa QR' 'aprobar -> cocina (API)'
        }
        else {
            Fail-Rol 'Mesa QR' 'aprobar pedido' "$($apr.json.mensaje)"
        }
    }
    else { Fail-Rol 'Mesa QR' 'login mesero para aprobar' }
}
else { Fail-Rol 'Mesa QR' 'POST pedido mesa' }

# --- 3.3 Admin ---
$admin = Login-Rol 'admin@foody.demo'
if (-not $admin) { Fail-Rol 'Admin' 'login'; exit 1 }
$h = $admin.headers
Ok-Rol 'Admin' 'login'

foreach ($pair in @(
        @{ Path = "/pedidos?sucursal_id=$sid"; Nombre = 'pedidos' }
        @{ Path = "/mesas/$sid"; Nombre = 'mesas' }
        @{ Path = "/caja/activa/$sid"; Nombre = 'caja activa' }
        @{ Path = "/productos/sucursal/$sid"; Nombre = 'productos' }
        @{ Path = "/inventario/$sid"; Nombre = 'inventario' }
        @{ Path = "/alertas/$sid"; Nombre = 'alertas' }
        @{ Path = '/reportes/financiero?sucursal_id=' + $sid; Nombre = 'reportes' }
    )) {
    $r = Invoke-FoodyApi -Path $pair.Path -Headers $h
    if ($r.ok -and $r.json.exito) { Ok-Rol 'Admin' $pair.Nombre }
    else { Fail-Rol 'Admin' $pair.Nombre }
}

$dash = Invoke-FoodyApi -Path "/dashboard/resumen?sucursal_id=$sid" -Headers $h
if ($dash.ok -and $dash.json.exito) { Ok-Rol 'Admin' 'dashboard resumen' }
else { Fail-Rol 'Admin' 'dashboard' }

# --- 3.4 Cajero ---
$cajero = Login-Rol 'cajero.test@foody.demo'
if ($cajero) {
    Ok-Rol 'Cajero' 'login'
    $hc = $cajero.headers
    if (Ensure-CajaAbierta -Headers $hc) {
        Ok-Rol 'Cajero' 'caja abierta o abrir turno'
        $pedCaj = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
            sucursal_id = $sid
            tipo        = 'para_llevar'
            device_id   = 'qa-roles-cajero'
            metodo_pago = 'pendiente'
            items       = @(@{ producto_id = $Producto; cantidad = 1; precio = 8000 })
        }
        if ($pedCaj.ok -and $pedCaj.json.exito) { Ok-Rol 'Cajero' 'crear pedido staff' }
        else { Fail-Rol 'Cajero' 'crear pedido' }
    }
    else { Fail-Rol 'Cajero' 'abrir caja' }
}
else { Fail-Rol 'Cajero' 'login cajero.test@foody.demo' }

# --- 3.5 Mesero ---
$mesero = Login-Rol 'mesero@foody.com'
if ($mesero) {
    Ok-Rol 'Mesero' 'login'
    $hm = $mesero.headers
    $mesasM = Invoke-FoodyApi -Path "/mesas/$sid" -Headers $hm
    if ($mesasM.ok -and $mesasM.json.exito) { Ok-Rol 'Mesero' 'grid mesas' }
    else { Fail-Rol 'Mesero' 'listar mesas' }
}
else { Fail-Rol 'Mesero' 'login mesero@foody.com' }

# --- 3.6 Cocina ---
$cocina = Login-Rol 'cocina@foody.demo'
if ($cocina) {
    Ok-Rol 'Cocina' 'login'
    $hk = $cocina.headers
    $cocinas = Invoke-FoodyApi -Path '/cocina/cocinas' -Headers $hk
    if ($cocinas.ok -and $cocinas.json.exito) { Ok-Rol 'Cocina' 'listar cocinas' }
    else { Fail-Rol 'Cocina' 'cocinas' }
    $tickets = Invoke-FoodyApi -Path "/cocina/tickets/$CocinaId" -Headers $hk
    if ($tickets.ok -and $tickets.json.exito) { Ok-Rol 'Cocina' 'KDS tickets' }
    else { Fail-Rol 'Cocina' 'tickets' }
}
else { Fail-Rol 'Cocina' 'login' }

# --- 3.7 Domiciliario planta ---
$domi = Login-Rol 'domi@foody.demo'
if ($domi) {
    Ok-Rol 'Domi planta' 'login'
    $hd = $domi.headers
    $asig = Invoke-FoodyApi -Path '/domiciliario/pedidos-asignados' -Headers $hd
    if ($asig.ok -and $asig.json.exito) { Ok-Rol 'Domi planta' 'pedidos asignados' }
    else { Fail-Rol 'Domi planta' 'pedidos-asignados' }
}
else { Fail-Rol 'Domi planta' 'login' }

# --- 3.8 Repartidor independiente ---
$rep = Get-FoodyTokenDomiciliarioIndep 'repartidor@foody.demo'
if ($rep) {
    Ok-Rol 'Repartidor indep' 'login-domiciliario'
    $hr = $rep.headers
    $ofertas = Invoke-FoodyApi -Path '/domiciliarios/ofertas-activas' -Headers $hr
    if ($ofertas.ok -and $ofertas.json.exito) { Ok-Rol 'Repartidor indep' 'ofertas activas' }
    else { Fail-Rol 'Repartidor indep' 'ofertas' }
    $ses = Invoke-FoodyApi -Path '/domiciliarios/sesion/estado' -Headers $hr
    if ($ses.ok -and $ses.json.exito) { Ok-Rol 'Repartidor indep' 'sesion estado' }
    else { Fail-Rol 'Repartidor indep' 'sesion estado' }
}
else { Fail-Rol 'Repartidor indep' 'login' }

# --- 3.9 Super admin ---
$super = Login-Rol 'super@foody.demo'
if ($super) {
    Ok-Rol 'Super admin' 'login'
    $hs = $super.headers
    $stats = Invoke-FoodyApi -Path '/super/estadisticas' -Headers $hs
    if ($stats.ok -and $stats.json.exito) { Ok-Rol 'Super admin' 'estadisticas' }
    else { Fail-Rol 'Super admin' 'estadisticas' }
    $clave = 'ampliacion_radio_km'
    $cfgGet = Invoke-FoodyApi -Path '/super/configuracion' -Headers $hs
    if ($cfgGet.ok -and $cfgGet.json.exito) { Ok-Rol 'Super admin' 'GET config global' }
    else { Fail-Rol 'Super admin' 'GET config' }
    $cfg = Invoke-FoodyApi -Method PATCH -Path "/super/configuracion/$clave" -Headers $hs -Body @{
        valor = '5'
    }
    if ($cfg.ok -and $cfg.json.exito) { Ok-Rol 'Super admin' 'PATCH config global' }
    else { Fail-Rol 'Super admin' 'PATCH config' }
}
else { Fail-Rol 'Super admin' 'login' }

# --- Gerente sede (062: sin alcance corporativo) + consolidado via admin ---
$gerente = Login-Rol 'gerente@foody.demo'
if ($gerente) {
    Ok-Rol 'Gerente sede' 'login'
    $hg = $gerente.headers
    $pedG = Invoke-FoodyApi -Path "/pedidos?sucursal_id=$sid" -Headers $hg
    if ($pedG.ok -and $pedG.json.exito) { Ok-Rol 'Gerente sede' 'pedidos sucursal' }
    else { Fail-Rol 'Gerente sede' 'pedidos' }
    $consG = Invoke-FoodyApi -Path '/dashboard/consolidado' -Headers $hg
    if (-not $consG.ok -and $consG.status -eq 403) {
        Ok-Rol 'Gerente sede' 'consolidado bloqueado (esperado sede)'
    }
    else { Fail-Rol 'Gerente sede' 'consolidado deberia 403' }
}
else { Write-Host '  AVISO gerente@foody.demo no disponible (migr. 062)' -ForegroundColor Yellow }

$consAdmin = Invoke-FoodyApi -Path '/dashboard/consolidado' -Headers $h
if ($consAdmin.ok -and $consAdmin.json.exito) { Ok-Rol 'Admin corporativo' 'dashboard consolidado' }
else { Fail-Rol 'Admin corporativo' 'consolidado' }

# --- Resumen sesion ---
$fecha = Get-Date -Format 'yyyy-MM-dd'
$sesionDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'docs\qa-sesiones'
if (-not (Test-Path $sesionDir)) { New-Item -ItemType Directory -Path $sesionDir | Out-Null }
$sesionFile = Join-Path $sesionDir "$fecha-roles-api.md"
$okN = @($resultados | Where-Object { $_.ok }).Count
$lineas = @(
    "# QA roles API - $fecha",
    '',
    "Pasos OK: $okN / $($resultados.Count)",
    '',
    '| Rol | Paso | OK |',
    '|-----|------|-----|'
)
foreach ($r in $resultados) {
    $mark = if ($r.ok) { 'si' } else { 'no' }
    $lineas += "| $($r.rol) | $($r.paso) | $mark |"
}
$lineas | Set-Content -Path $sesionFile -Encoding UTF8

Write-Host ''
Write-Host "Resumen: docs\qa-sesiones\$fecha-roles-api.md" -ForegroundColor DarkGray
if ($fallos -gt 0) {
    Write-Host "QA roles API FALLO ($fallos pasos)" -ForegroundColor Red
    exit 1
}
Write-Host 'QA roles API OK' -ForegroundColor Green
exit 0
