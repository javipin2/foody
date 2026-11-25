# Prompt 17 — Clientes/QR/autoservicio: flujo, anti-tamper precios, QR/mesa reutilizada.
# Uso: .\scripts\verificar-qr-cliente.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar QR Cliente / Autoservicio (Prompt 17) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$MesaId = '30000000-0000-4000-8000-000000000001'
$QrToken = 'demo-mesa-1'
$PrecioCatalogo = 8000
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

$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Ensure-HorariosDemoAbiertos
$null = Restaurar-InventarioDemo -Headers $h
# Asegurar mesa activa + token demo
$null = Sql-Scalar @"
UPDATE mesas SET activa = true, estado_operativo = 'libre',
  qr_token = COALESCE(NULLIF(qr_token,''), '$QrToken')
WHERE id = '$MesaId';
UPDATE mesas SET qr_token = '$QrToken' WHERE id = '$MesaId' AND (qr_token IS NULL OR qr_token <> '$QrToken');
"@

# Precio real BD
$precioBd = [double](Sql-Scalar "SELECT precio::text FROM productos WHERE id='$Producto';")
if ($precioBd -gt 0) { $PrecioCatalogo = $precioBd }

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- A) Flujo QR sin JWT mesero (pedido publico) ---' -ForegroundColor Yellow

$menuQr = Invoke-FoodyApi -Path "/menu/mesa/$QrToken"
Assert-Ok -Cond ($menuQr.ok -and $menuQr.json.exito) -Msg "GET /menu/mesa/$QrToken publico"
$mesaMenu = $menuQr.json.datos.mesa
if (-not $mesaMenu) { $mesaMenu = $menuQr.json.datos }
$mesaIdMenu = $mesaMenu.id
if (-not $mesaIdMenu) { $mesaIdMenu = $MesaId }
Assert-Ok -Cond ($null -ne $mesaIdMenu) -Msg "Menu QR resuelve mesa ($mesaIdMenu)"

$deviceA = "qa-qr-cli-a-$(Get-Random)"
$crearA = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
    sucursal_id     = $sid
    mesa_id         = $mesaIdMenu
    device_id       = $deviceA
    tipo            = 'mesa'
    metodo_pago     = 'pendiente'
    idempotency_key = [guid]::NewGuid().ToString()
    items           = @(@{ producto_id = $Producto; cantidad = 1; precio = $PrecioCatalogo })
}
Assert-Ok -Cond ($crearA.ok -and $crearA.json.exito) -Msg "POST /pedidos publico ($($crearA.json.error))"
$pedA = $crearA.json.datos.pedido_id
if (-not $pedA) { $pedA = $crearA.json.datos.id }
$estA = $crearA.json.datos.estado
if (-not $estA) { $estA = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedA';" }
Assert-Ok -Cond ($estA -eq 'pendiente_aprobacion') -Msg "Estado pendiente_aprobacion (got=$estA)"

$stockFlag = Sql-Scalar "SELECT stock_descontado::text FROM pedidos WHERE id='$pedA';"
Assert-Ok -Cond ("$stockFlag" -eq 'f' -or "$stockFlag" -eq 'false' -or "$stockFlag" -eq 'False') `
    -Msg "Sin descuento stock hasta aprobar (stock_descontado=$stockFlag)"

# Sin JWT no puede aprobar
$aprAnon = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedA/aprobar?sucursal_id=$sid" -Body @{
    mesera_id = 'a70e5bd3-a027-4038-86dc-c8f86f683fbd'
}
Assert-Ok -Cond (-not ($aprAnon.ok -and $aprAnon.json.exito)) -Msg "Aprobar sin JWT rechazado (err=$($aprAnon.json.error))"

# Autoservicio: no hay auto-aprobacion — pedido sigue pendiente
Start-Sleep -Milliseconds 300
$estStill = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedA';"
Assert-Ok -Cond ($estStill -eq 'pendiente_aprobacion') -Msg 'Sin autoservicio: sigue pendiente_aprobacion'

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- B) Anti-manipulacion precios / productos ---' -ForegroundColor Yellow

$precioFalso = 1
$deviceB = "qa-qr-tamper-$(Get-Random)"
$crearFake = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
    sucursal_id     = $sid
    mesa_id         = $mesaIdMenu
    device_id       = $deviceB
    tipo            = 'mesa'
    metodo_pago     = 'pendiente'
    idempotency_key = [guid]::NewGuid().ToString()
    items           = @(@{ producto_id = $Producto; cantidad = 1; precio = $precioFalso })
}
Assert-Ok -Cond ($crearFake.ok -and $crearFake.json.exito) -Msg "Pedido con precio falso aceptado (body ignorado)"
$pedFake = $crearFake.json.datos.pedido_id
if (-not $pedFake) { $pedFake = $crearFake.json.datos.id }
$pu = [double](Sql-Scalar "SELECT precio_unitario::text FROM pedido_items WHERE pedido_id='$pedFake' LIMIT 1;")
$totalFake = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pedFake';")
Assert-Ok -Cond ($pu -eq $PrecioCatalogo) -Msg "precio_unitario BD=$pu (no $precioFalso)"
Assert-Ok -Cond ($totalFake -ge $PrecioCatalogo) -Msg "total>=catalogo ($totalFake / $PrecioCatalogo)"

# Producto inexistente / otra sucursal
$crearBad = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
    sucursal_id     = $sid
    mesa_id         = $mesaIdMenu
    device_id       = "qa-qr-badprod-$(Get-Random)"
    tipo            = 'mesa'
    metodo_pago     = 'pendiente'
    idempotency_key = [guid]::NewGuid().ToString()
    items           = @(@{ producto_id = '00000000-0000-4000-8000-000000000099'; cantidad = 1; precio = 999 })
}
Assert-Ok -Cond (-not ($crearBad.ok -and $crearBad.json.exito)) -Msg "Producto ajeno/inexistente rechazado ($($crearBad.json.error))"

# Producto no disponible
$null = Sql-Scalar "UPDATE productos SET disponible = false WHERE id='$Producto';"
$crearOff = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
    sucursal_id     = $sid
    mesa_id         = $mesaIdMenu
    device_id       = "qa-qr-off-$(Get-Random)"
    tipo            = 'mesa'
    metodo_pago     = 'pendiente'
    idempotency_key = [guid]::NewGuid().ToString()
    items           = @(@{ producto_id = $Producto; cantidad = 1; precio = $PrecioCatalogo })
}
Assert-Ok -Cond (-not ($crearOff.ok -and $crearOff.json.exito)) -Msg "Producto indisponible rechazado ($($crearOff.json.error))"
$null = Sql-Scalar "UPDATE productos SET disponible = true WHERE id='$Producto';"

# Cliente no puede PATCH estado a en_cocina
$bypass = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedFake/estado?sucursal_id=$sid" -Body @{
    estado = 'en_cocina'
}
Assert-Ok -Cond (-not ($bypass.ok -and $bypass.json.exito)) -Msg "Cliente no fuerza en_cocina (err=$($bypass.json.error))"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- C) QR permanente / mesa reutilizada / 2 clientes ---' -ForegroundColor Yellow

# Token sigue resolviendo tras liberar mesa operativa
$null = Sql-Scalar "UPDATE mesas SET estado_operativo='libre' WHERE id='$mesaIdMenu';"
$menu2 = Invoke-FoodyApi -Path "/menu/mesa/$QrToken"
Assert-Ok -Cond ($menu2.ok -and $menu2.json.exito) -Msg 'QR token sigue valido tras mesa libre'

# Segundo cliente misma mesa (otro device)
$deviceC = "qa-qr-cli-c-$(Get-Random)"
$crearC = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
    sucursal_id     = $sid
    mesa_id         = $mesaIdMenu
    device_id       = $deviceC
    tipo            = 'mesa'
    metodo_pago     = 'pendiente'
    idempotency_key = [guid]::NewGuid().ToString()
    items           = @(@{ producto_id = $Producto; cantidad = 1; precio = $PrecioCatalogo })
}
Assert-Ok -Cond ($crearC.ok -and $crearC.json.exito) -Msg "2do cliente mismo QR crea pedido ($($crearC.json.error))"
$pedC = $crearC.json.datos.pedido_id
if (-not $pedC) { $pedC = $crearC.json.datos.id }
$nPend = [int](Sql-Scalar @"
SELECT COUNT(*)::text FROM pedidos
WHERE mesa_id='$mesaIdMenu' AND estado='pendiente_aprobacion'
  AND id IN ('$pedA','$pedFake','$pedC');
"@)
Assert-Ok -Cond ($nPend -ge 2) -Msg "Varios pendiente_aprobacion coexisten (n=$nPend)"

# Mesa inactiva invalida menu QR
$null = Sql-Scalar "UPDATE mesas SET activa = false WHERE id='$mesaIdMenu';"
$menuDead = Invoke-FoodyApi -Path "/menu/mesa/$QrToken"
Assert-Ok -Cond (-not ($menuDead.ok -and $menuDead.json.exito)) -Msg "Mesa inactiva: menu QR falla ($($menuDead.json.error))"
$null = Sql-Scalar "UPDATE mesas SET activa = true WHERE id='$mesaIdMenu';"

# Token inventado
$menuBogus = Invoke-FoodyApi -Path '/menu/mesa/token-inexistente-qa-17'
Assert-Ok -Cond (-not ($menuBogus.ok -and $menuBogus.json.exito)) -Msg "Token inventado rechazado ($($menuBogus.status))"

# Expiracion dura: solo al cierre caja >30min (F-09) — probe codigo + forzar edad
$pedExp = $pedA
$null = Sql-Scalar "UPDATE pedidos SET created_at = NOW() - INTERVAL '35 minutes' WHERE id='$pedExp';"
$edad = Sql-Scalar "SELECT EXTRACT(EPOCH FROM (NOW() - created_at))/60::int FROM pedidos WHERE id='$pedExp';"
Assert-Ok -Cond ([double]$edad -ge 30) -Msg "Pedido envejecido >30min (edad_min~$edad) - pendiente hasta cierre caja"
$estExp = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedExp';"
Assert-Ok -Cond ($estExp -eq 'pendiente_aprobacion') -Msg 'Sin auto-rechazo continuo (sigue pendiente)'

# QR-MESA-ID-01: pedido de mesa sin mesa_id debe rechazarse
$devSin = 'qa-qr-sinmesa-' + [string](Get-Random)
$sinMesa = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
    sucursal_id     = $sid
    device_id       = $devSin
    tipo            = 'mesa'
    metodo_pago     = 'pendiente'
    idempotency_key = [guid]::NewGuid().ToString()
    items           = @(@{ producto_id = $Producto; cantidad = 1; precio = $PrecioCatalogo })
}
if ($sinMesa.ok -and $sinMesa.json.exito) {
    $pedSin = $sinMesa.json.datos.pedido_id
    if (-not $pedSin) { $pedSin = $sinMesa.json.datos.id }
    Assert-Ok -Cond $false -Msg 'QR-MESA-ID-01: tipo mesa sin mesa_id fue aceptado (regresión)'
    $null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedSin/estado?sucursal_id=$sid" -Headers $h -Body @{
        estado = 'cancelado'
        motivo = 'QA cleanup de regresión mesa sin ID'
    }
} else {
    $codigoSin = [string]$sinMesa.json.error
    Assert-Ok -Cond ($sinMesa.status -ge 400 -and ($codigoSin -eq 'MESA_REQUERIDA' -or $codigoSin -eq 'SOLICITUD_INVALIDA')) -Msg "tipo mesa sin mesa_id rechazado ($codigoSin)"
}

# Cleanup pendientes QR
$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Sql-Scalar "UPDATE mesas SET activa=true, estado_operativo='libre' WHERE id='$MesaId';"
$null = Sql-Scalar "UPDATE productos SET disponible=true WHERE id='$Producto';"

Write-Host ''
if ($script:fallos -eq 0) {
    Write-Host 'Verificacion qr-cliente OK' -ForegroundColor Green
    exit 0
}
Write-Host "$($script:fallos) fallos" -ForegroundColor Red
exit 1
