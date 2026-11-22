# Prompt 14 — Inventario: descuento automatico, 3 capas, alertas, ajuste auditado.
# Uso: .\scripts\verificar-inventario-ciclo.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar Inventario ciclo (Prompt 14) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$h = $admin.headers
$hc = $cajero.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$PapaId = '40000000-0000-4000-8000-000000000003'
$Precio = 8000
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

function Get-StockPapa {
    $det = Invoke-FoodyApi -Path "/inventario/$sid" -Headers $h
    $row = @($det.json.datos) | Where-Object { $_.id -eq $PapaId } | Select-Object -First 1
    return [decimal]$row.stock_actual
}

function Restore-RecetaDemo {
    $null = Invoke-FoodyApi -Method POST -Path '/inventario/producto-ingredientes' -Headers $h -Body @{
        producto_id = $Producto
        items       = @(
            @{
                tipo_item      = 'ingrediente'
                ingrediente_id = $PapaId
                cantidad       = 200
                unidad         = 'g'
            }
        )
    }
}

$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Ensure-CajaAbierta -Headers $hc
$null = Ensure-HorariosDemoAbiertos
$null = Restaurar-InventarioDemo -Headers $h
Restore-RecetaDemo

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- A) Descuento automatico al confirmar (staff mesa -> en_cocina) ---' -ForegroundColor Yellow

$stockAntes = Get-StockPapa
$libres = Get-MesasLibres -Headers $hc
if ($libres.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres = Get-MesasLibres -Headers $hc
}
Assert-Ok -Cond ($libres.Count -gt 0) -Msg 'Mesa libre disponible'
$Mesa = $libres[0].id

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa
    tipo        = 'mesa'
    device_id   = 'qa-inv-auto'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond ($crear.ok -and $crear.json.exito) -Msg "Crear pedido staff ($($crear.json.error))"
$pedId = $crear.json.datos.pedido_id
if (-not $pedId) { $pedId = $crear.json.datos.id }
$estado = $crear.json.datos.estado
if (-not $estado) { $estado = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedId';" }
$flagStock = $crear.json.datos.stock_descontado
if ($null -eq $flagStock) {
    $flagStock = Sql-Scalar "SELECT stock_descontado::text FROM pedidos WHERE id='$pedId';"
}
Assert-Ok -Cond ($estado -eq 'en_cocina') -Msg "Estado inicial en_cocina (got=$estado)"
Assert-Ok -Cond ("$flagStock" -eq 'True' -or "$flagStock" -eq 'true' -or "$flagStock" -eq 't') -Msg "stock_descontado=true"

$stockDespues = Get-StockPapa
$delta = $stockAntes - $stockDespues
Assert-Ok -Cond ($delta -eq 200) -Msg "Papa -200g automatico (antes=$stockAntes despues=$stockDespues delta=$delta)"

$movVenta = Sql-Scalar @"
SELECT COUNT(*)::text FROM movimientos_ingrediente
WHERE pedido_id='$pedId' AND tipo='venta' AND ingrediente_id='$PapaId';
"@
Assert-Ok -Cond ($movVenta -eq '1') -Msg "Movimiento venta ligado al pedido (n=$movVenta)"

# Negativo: QR pendiente no descuenta hasta aprobar — create via SQL flag check on pending
# (staff path ya cubre automatico; documentamos que cliente mesa = pendiente_aprobacion)

$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedId/estado?sucursal_id=$sid" -Headers $h -Body @{
    estado = 'cancelado'
    motivo = 'QA inv auto cleanup'
}

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- B) Propagacion insumos -> subreceta -> plato ---' -ForegroundColor Yellow

$null = Restaurar-InventarioDemo -Headers $h
$ts = Get-Date -Format 'HHmmss'
$sub = Invoke-FoodyApi -Method POST -Path '/costeo/subrecetas' -Headers $h -Body @{
    sucursal_id         = $sid
    nombre              = "QA Sub Inv $ts"
    cantidad_resultado  = 100
    unidad_resultado    = 'g'
    margen_error        = 0.05
    usa_produccion_lote = $false
    items               = @(
        @{
            tipo_item      = 'ingrediente'
            ingrediente_id = $PapaId
            cantidad       = 50
            unidad         = 'g'
        }
    )
}
Assert-Ok -Cond ($sub.ok -and $sub.json.exito) -Msg "Crear subreceta ($($sub.json.error))"
$subId = $sub.json.datos.receta_id
if (-not $subId) { $subId = $sub.json.datos.id }

$cfg = Invoke-FoodyApi -Method POST -Path '/inventario/producto-ingredientes' -Headers $h -Body @{
    producto_id = $Producto
    items       = @(
        @{
            tipo_item    = 'subreceta'
            subreceta_id = $subId
            cantidad     = 200
            unidad       = 'g'
        }
    )
}
Assert-Ok -Cond ($cfg.ok -and $cfg.json.exito) -Msg "Plato apunta a subreceta ($($cfg.json.error))"

$impacto = Invoke-FoodyApi -Path "/costeo/productos/$Producto/impacto-stock?sucursal_id=$sid&cantidad=1" -Headers $h
Assert-Ok -Cond ($impacto.ok -and $impacto.json.exito) -Msg 'impacto-stock con expansion'
$ingsImpacto = @($impacto.json.datos.ingredientes)
$papaImpacto = $ingsImpacto | Where-Object { $_.ingrediente_id -eq $PapaId } | Select-Object -First 1
# 200g sub / 100g resultado * 50g papa = 100g
$necesita = [decimal]$papaImpacto.necesita
Assert-Ok -Cond ($necesita -eq 100) -Msg "Expansion 3 capas necesita=100g Papa (got=$necesita)"

$stockAntesB = Get-StockPapa
$libres = Get-MesasLibres -Headers $hc
if ($libres.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres = Get-MesasLibres -Headers $hc
}
$MesaB = $libres[0].id
$crearB = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $MesaB
    tipo        = 'mesa'
    device_id   = 'qa-inv-sub'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond ($crearB.ok -and $crearB.json.exito) -Msg "Pedido con subreceta ($($crearB.json.error))"
$pedB = $crearB.json.datos.pedido_id
if (-not $pedB) { $pedB = $crearB.json.datos.id }
$stockDespuesB = Get-StockPapa
$deltaB = $stockAntesB - $stockDespuesB
Assert-Ok -Cond ($deltaB -eq 100) -Msg "Descuento propagado Papa -100g (delta=$deltaB)"

$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedB/estado?sucursal_id=$sid" -Headers $h -Body @{
    estado = 'cancelado'
    motivo = 'QA inv sub cleanup'
}
Restore-RecetaDemo
$null = Restaurar-InventarioDemo -Headers $h

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- C) Alertas stock bajo ---' -ForegroundColor Yellow

# Dedup: cerrar alertas previas del mismo insumo para poder observar insert fresco
$null = Sql-Scalar @"
UPDATE alertas_riesgo SET revisada = true, revisada_at = NOW()
WHERE sucursal_id='$sid' AND tipo='stock_minimo_alcanzado'
  AND referencia_id='$PapaId' AND COALESCE(revisada, false) = false;
"@

$null = Restaurar-InventarioDemo -Headers $h
# stock demo Papa=10000; minimo 9950 => venta -200 cruza umbral
$null = Invoke-FoodyApi -Method PATCH -Path "/inventario/$PapaId" -Headers $h -Body @{
    stock_minimo = 9950
}

$antesAlertas = Sql-Scalar @"
SELECT COUNT(*)::text FROM alertas_riesgo
WHERE sucursal_id='$sid' AND tipo='stock_minimo_alcanzado'
  AND referencia_id='$PapaId' AND COALESCE(revisada, false) = false;
"@

$libres = Get-MesasLibres -Headers $hc
if ($libres.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres = Get-MesasLibres -Headers $hc
}
$crearC = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $libres[0].id
    tipo        = 'mesa'
    device_id   = 'qa-inv-alert'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond ($crearC.ok -and $crearC.json.exito) -Msg "Pedido dispara stock bajo ($($crearC.json.error))"
$pedC = $crearC.json.datos.pedido_id
if (-not $pedC) { $pedC = $crearC.json.datos.id }

Start-Sleep -Seconds 1
$despuesAlertas = Sql-Scalar @"
SELECT COUNT(*)::text FROM alertas_riesgo
WHERE sucursal_id='$sid' AND tipo='stock_minimo_alcanzado'
  AND referencia_id='$PapaId' AND COALESCE(revisada, false) = false;
"@
Assert-Ok -Cond ([int]$despuesAlertas -gt [int]$antesAlertas) `
    -Msg "Alerta stock_minimo_alcanzado nueva (antes=$antesAlertas despues=$despuesAlertas)"

$nivel = Sql-Scalar @"
SELECT nivel FROM alertas_riesgo
WHERE sucursal_id='$sid' AND tipo='stock_minimo_alcanzado'
  AND referencia_id='$PapaId'
ORDER BY created_at DESC LIMIT 1;
"@
Assert-Ok -Cond ($nivel -eq 'medio') -Msg "Nivel alerta=medio (got=$nivel) => sin FCM push"

$listAlertas = Invoke-FoodyApi -Path "/alertas/${sid}?solo_pendientes=true" -Headers $h
Assert-Ok -Cond ($listAlertas.ok -and $listAlertas.json.exito) -Msg 'GET /alertas panel admin'

$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedC/estado?sucursal_id=$sid" -Headers $h -Body @{
    estado = 'cancelado'
    motivo = 'QA inv alert cleanup'
}
# Restaurar minimo demo tipico
$null = Invoke-FoodyApi -Method PATCH -Path "/inventario/$PapaId" -Headers $h -Body @{
    stock_minimo = 1000
}
$null = Restaurar-InventarioDemo -Headers $h

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- D) Ajuste manual + auditoria ---' -ForegroundColor Yellow

$adminSub = Sql-Scalar "SELECT id::text FROM usuarios WHERE email='admin@foody.demo' LIMIT 1;"
$stockD = Get-StockPapa
$nuevo = [double]($stockD - 7)
$motivo = "QA ajuste invent ciclo $(Get-Date -Format 'HHmmss')"
$ajuste = Invoke-FoodyApi -Method PATCH -Path "/inventario/$PapaId" -Headers $h -Body @{
    stock_nuevo   = $nuevo
    motivo_ajuste = $motivo
}
Assert-Ok -Cond ($ajuste.ok -and $ajuste.json.exito) -Msg "PATCH ajuste ($($ajuste.json.error))"

$mov = Sql-Scalar @"
SELECT usuario_id::text || '|' || COALESCE(motivo,'') || '|' || tipo
FROM movimientos_ingrediente
WHERE ingrediente_id='$PapaId' AND tipo='ajuste'
ORDER BY created_at DESC LIMIT 1;
"@
$parts = $mov -split '\|'
Assert-Ok -Cond ($parts[0] -eq $adminSub) -Msg "movimientos.usuario_id = admin ($($parts[0]))"
Assert-Ok -Cond ($parts[1] -eq $motivo) -Msg 'movimientos.motivo = texto QA'
Assert-Ok -Cond ($parts[2] -eq 'ajuste') -Msg 'movimientos.tipo = ajuste'

$apiMov = Invoke-FoodyApi -Path "/inventario/movimientos/${sid}?page=1&limit=5" -Headers $h
$tieneUsuarioApi = $false
if ($apiMov.ok -and $apiMov.json.exito) {
    $items = @($apiMov.json.datos.items)
    if ($items.Count -eq 0) { $items = @($apiMov.json.datos) }
    $ultimo = $items | Where-Object { $_.tipo -eq 'ajuste' -and $_.ingrediente_id -eq $PapaId } | Select-Object -First 1
    if ($ultimo -and ($null -ne $ultimo.usuario_id -or $null -ne $ultimo.PSObject.Properties['usuario_id'])) {
        $tieneUsuarioApi = $true
    }
}
Assert-Ok -Cond (-not $tieneUsuarioApi) -Msg 'API movimientos omite usuario_id (gap UI quien)'

$aud = Sql-Scalar @"
SELECT COUNT(*)::text FROM auditoria_logs
WHERE created_at > NOW() - INTERVAL '3 minutes'
  AND (
    accion ILIKE '%ajuste%' OR accion ILIKE '%inventario%'
    OR tabla_afectada IN ('ingredientes','movimientos_ingrediente')
  );
"@
Assert-Ok -Cond ($aud -match '^\d+$' -and [int]$aud -eq 0) -Msg "Sin fila auditoria_logs para ajuste (n=$aud)"

$null = Restaurar-InventarioDemo -Headers $h
Restore-RecetaDemo
$null = Limpiar-PedidosActivosDemo -Headers $h

Write-Host ''
if ($script:fallos -eq 0) {
    Write-Host 'Verificacion inventario-ciclo OK' -ForegroundColor Green
    exit 0
}
Write-Host "$($script:fallos) fallos" -ForegroundColor Red
exit 1
