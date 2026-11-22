# Prompt 15 — Meseros/mesas: asignacion, transferir, split post-cocina, carrera 2 meseros.
# Uso: .\scripts\verificar-meseros-mesas.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar Meseros/Mesas (Prompt 15) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$mesero = Get-FoodyToken 'mesero@foody.com'
$h = $admin.headers
$hm = $mesero.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$Precio = 8000
$script:fallos = 0
$Mesero2Email = 'mesero2.qa@foody.demo'
$Mesero2IdSeed = '91300000-0000-4000-8000-0000000000a2'

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

function Get-MeseroId([string]$Email) {
    return Sql-Scalar "SELECT id::text FROM usuarios WHERE email='$Email' LIMIT 1;"
}

# Seed mesero2 temporal (misma pass hash demo 123456)
$hash = Sql-Scalar "SELECT hash_contrasena FROM usuarios WHERE email='mesero@foody.com' LIMIT 1;"
$restId = Sql-Scalar "SELECT COALESCE(restaurante_id::text,'') FROM usuarios WHERE email='mesero@foody.com' LIMIT 1;"
$restSql = if ($restId) { "'$restId'::uuid" } else { 'NULL' }
$null = Sql-Scalar @"
INSERT INTO usuarios (id, sucursal_id, restaurante_id, nombre, email, rol, activo, hash_contrasena)
VALUES (
  '$Mesero2IdSeed', '$sid', $restSql, 'Mesero QA 2',
  '$Mesero2Email', 'mesero', true, '$hash'
)
ON CONFLICT (email) DO UPDATE SET
  hash_contrasena = EXCLUDED.hash_contrasena,
  activo = true,
  sucursal_id = EXCLUDED.sucursal_id,
  rol = 'mesero';
"@

$mesero2 = Get-FoodyToken $Mesero2Email
$hm2 = $mesero2.headers
$Mesero1Id = Get-MeseroId 'mesero@foody.com'
$Mesero2Id = Get-MeseroId $Mesero2Email
Assert-Ok -Cond ($Mesero1Id -and $Mesero2Id) -Msg "IDs mesero1/2 ($Mesero1Id / $Mesero2Id)"

$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Ensure-CajaAbierta -Headers $h
$null = Ensure-HorariosDemoAbiertos
$null = Restaurar-InventarioDemo -Headers $h

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- A) Asignacion de mesa / turno ---' -ForegroundColor Yellow

$libres = Get-MesasLibres -Headers $h
Assert-Ok -Cond ($libres.Count -ge 2) -Msg "Mesas libres >=2 (got=$($libres.Count))"
$MesaA = $libres[0].id
$MesaB = $libres[1].id

$turno = Invoke-FoodyApi -Method POST -Path '/mesas/asignar-turno' -Headers $h -Body @{
    sucursal_id  = $sid
    asignaciones = @(
        @{ mesa_id = $MesaA; mesera_asignada_id = $Mesero1Id }
    )
}
Assert-Ok -Cond ($turno.ok -and $turno.json.exito) -Msg "Asignar turno mesero1 ($($turno.json.error))"

$asig = Sql-Scalar "SELECT mesera_asignada_id::text FROM mesas WHERE id='$MesaA';"
Assert-Ok -Cond ($asig -eq $Mesero1Id) -Msg 'mesas.mesera_asignada_id = mesero1'

# Mesero2 no puede tomar mesa de mesero1
$crearAlien = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hm2 -Body @{
    sucursal_id = $sid
    mesa_id     = $MesaA
    tipo        = 'mesa'
    device_id   = 'qa-mesero2-alien'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond (-not ($crearAlien.ok -and $crearAlien.json.exito)) -Msg "Mesero2 bloqueado en mesa ajena err=$($crearAlien.json.error)"
Assert-Ok -Cond ($crearAlien.json.error -eq 'MESA_ASIGNADA_OTRA_MESERA' -or "$($crearAlien.json.mensaje)" -match 'otra mesera') `
    -Msg "Codigo MESA_ASIGNADA_OTRA_MESERA (got=$($crearAlien.json.error))"

# Mesero1 si puede
$crear1 = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hm -Body @{
    sucursal_id = $sid
    mesa_id     = $MesaA
    tipo        = 'mesa'
    device_id   = 'qa-mesero1-ok'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond ($crear1.ok -and $crear1.json.exito) -Msg "Mesero1 crea pedido ($($crear1.json.error))"
$pedA = $crear1.json.datos.pedido_id
if (-not $pedA) { $pedA = $crear1.json.datos.id }
$meseraPed = Sql-Scalar "SELECT mesera_id::text FROM pedidos WHERE id='$pedA';"
Assert-Ok -Cond ($meseraPed -eq $Mesero1Id) -Msg 'pedidos.mesera_id = mesero1'
$opA = Sql-Scalar "SELECT estado_operativo FROM mesas WHERE id='$MesaA';"
Assert-Ok -Cond ($opA -eq 'ocupada') -Msg 'Mesa origen ocupada'

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- B) Cambio de mesa con pedido en curso ---' -ForegroundColor Yellow

$xfer = Invoke-FoodyApi -Method POST -Path '/mesas/transferir' -Headers $h -Body @{
    sucursal_id     = $sid
    pedido_id       = $pedA
    mesa_origen_id  = $MesaA
    mesa_destino_id = $MesaB
    motivo          = 'QA Prompt 15 transfer'
}
Assert-Ok -Cond ($xfer.ok -and $xfer.json.exito) -Msg "Transferir en_cocina ($($xfer.json.error))"

$mesaPed = Sql-Scalar "SELECT mesa_id::text FROM pedidos WHERE id='$pedA';"
Assert-Ok -Cond ($mesaPed -eq $MesaB) -Msg 'Mismo pedido_id ahora en mesa destino'
$opDest = Sql-Scalar "SELECT estado_operativo FROM mesas WHERE id='$MesaB';"
$opOrig = Sql-Scalar "SELECT estado_operativo FROM mesas WHERE id='$MesaA';"
Assert-Ok -Cond ($opDest -eq 'ocupada') -Msg 'Destino ocupada'
Assert-Ok -Cond ($opOrig -eq 'libre') -Msg 'Origen libre tras transfer'
$hist = Sql-Scalar "SELECT COUNT(*)::text FROM transferencias_mesa WHERE pedido_id='$pedA';"
Assert-Ok -Cond ([int]$hist -ge 1) -Msg "Historial transferencias_mesa (n=$hist)"

# Transfer a mesa ocupada debe fallar
$crearOcc = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
    sucursal_id = $sid
    mesa_id     = $MesaA
    tipo        = 'mesa'
    device_id   = 'qa-ocupa-origen'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$pedOcc = $crearOcc.json.datos.pedido_id
if (-not $pedOcc) { $pedOcc = $crearOcc.json.datos.id }
$xferBad = Invoke-FoodyApi -Method POST -Path '/mesas/transferir' -Headers $h -Body @{
    sucursal_id     = $sid
    pedido_id       = $pedA
    mesa_origen_id  = $MesaB
    mesa_destino_id = $MesaA
    motivo          = 'QA destino ocupada'
}
Assert-Ok -Cond (-not ($xferBad.ok -and $xferBad.json.exito)) -Msg "Destino ocupada rechazado err=$($xferBad.json.error)"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- C) Division de cuenta post-cocina (split cobro, no pedido hijo) ---' -ForegroundColor Yellow

$null = Limpiar-PedidosActivosDemo -Headers $h
$libres = Get-MesasLibres -Headers $h
$MesaC = $libres[0].id

$crearC = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $h -Body @{
    sucursal_id = $sid
    mesa_id     = $MesaC
    tipo        = 'mesa'
    device_id   = 'qa-split-postcocina'
    metodo_pago = 'efectivo'
    items       = @(
        @{ producto_id = $Producto; cantidad = 1; precio = $Precio }
        @{ producto_id = $Producto; cantidad = 1; precio = $Precio }
    )
}
Assert-Ok -Cond ($crearC.ok -and $crearC.json.exito) -Msg "Pedido 2 items cocina ($($crearC.json.error))"
$pedC = $crearC.json.datos.pedido_id
if (-not $pedC) { $pedC = $crearC.json.datos.id }

# Ya en_cocina al crear staff — "despues de enviar a cocina"
$estadoC = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedC';"
Assert-Ok -Cond ($estadoC -eq 'en_cocina') -Msg "Estado en_cocina post-envio (got=$estadoC)"

$items = Invoke-FoodyApi -Path "/pedidos/mesa/${MesaC}?sucursal_id=$sid" -Headers $h
$itemIds = @()
foreach ($p in @($items.json.datos.pedidos)) {
    foreach ($it in @($p.items)) { $itemIds += $it.id }
}
if ($itemIds.Count -lt 2) {
    $raw = Sql-Scalar "SELECT string_agg(id::text, ',') FROM pedido_items WHERE pedido_id='$pedC';"
    $itemIds = @($raw -split ',' | Where-Object { $_ })
}
Assert-Ok -Cond ($itemIds.Count -ge 2) -Msg "Items para split (n=$($itemIds.Count))"

# Cobrar solo 1 item (split) mientras pedido sigue en cocina/listo path
$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedC/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'listo' }

$split = Invoke-FoodyApi -Method POST -Path "/pedidos/mesa/${MesaC}/cobrar?sucursal_id=$sid" -Headers $h -Body @{
    item_ids    = @($itemIds[0])
    metodo_pago = 'efectivo'
}
Assert-Ok -Cond ($split.ok -and $split.json.exito) -Msg "Split cobro 1 item post-cocina ($($split.json.error))"
$estadoTras = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedC';"
Assert-Ok -Cond ($estadoTras -eq 'pagando') -Msg "Pedido queda pagando (got=$estadoTras)"
$opPag = Sql-Scalar "SELECT estado_operativo FROM mesas WHERE id='$MesaC';"
Assert-Ok -Cond ($opPag -eq 'pagando') -Msg "Mesa estado_operativo=pagando (got=$opPag)"

# Seguir agregando tras split parcial (mismo pedido — no hijo)
$addPost = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedC/items?sucursal_id=$sid" -Headers $h -Body @{
    items = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond ($addPost.ok -and $addPost.json.exito) -Msg "Agregar item tras split parcial ($($addPost.json.error))"

# Gap: no hay endpoint dividir/mover items a pedido hijo
$hijo404 = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedC/dividir?sucursal_id=$sid" -Headers $h -Body @{ item_ids = @($itemIds[1]) }
Assert-Ok -Cond (-not ($hijo404.ok -and $hijo404.json.exito)) -Msg "Sin endpoint dividir-pedido (status=$($hijo404.status))"

# Cerrar saldo restante
$infoRest = Invoke-FoodyApi -Path "/pedidos/mesa/${MesaC}?sucursal_id=$sid" -Headers $h
$saldo = [double]$infoRest.json.datos.total_acumulado
if ($saldo -gt 0.01) {
    $cierre = Invoke-FoodyApi -Method POST -Path "/pedidos/mesa/${MesaC}/cobrar?sucursal_id=$sid" -Headers $h -Body @{
        metodo_pago = 'tarjeta'
    }
    Assert-Ok -Cond ($cierre.ok -and $cierre.json.exito) -Msg "Cerrar saldo restante ($($cierre.json.error))"
}

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- D) Carrera: dos meseros / edicion concurrente ---' -ForegroundColor Yellow

$null = Limpiar-PedidosActivosDemo -Headers $h
$libres = Get-MesasLibres -Headers $h
$MesaD = $libres[0].id
$null = Invoke-FoodyApi -Method POST -Path '/mesas/asignar-turno' -Headers $h -Body @{
    sucursal_id  = $sid
    asignaciones = @(@{ mesa_id = $MesaD; mesera_asignada_id = $Mesero1Id })
}

$crearD = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hm -Body @{
    sucursal_id = $sid
    mesa_id     = $MesaD
    tipo        = 'mesa'
    device_id   = 'qa-race'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$pedD = $crearD.json.datos.pedido_id
if (-not $pedD) { $pedD = $crearD.json.datos.id }
Assert-Ok -Cond ($null -ne $pedD) -Msg 'Pedido race creado'

# D1: mesero2 no edita mesa ajena
$addAlien = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedD/items?sucursal_id=$sid" -Headers $hm2 -Body @{
    items = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond (-not ($addAlien.ok -and $addAlien.json.exito)) -Msg "Mesero2 no agrega en mesa ajena err=$($addAlien.json.error)"

# D2: dos POST concurrentes del mismo mesero (FOR UPDATE serializa)
$totalAntes = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pedD';")
$jobScript = {
    param($Base, $Token, $PedId, $Sid, $Prod, $Precio, $Tag)
    $headers = @{ Authorization = "Bearer $Token"; 'Content-Type' = 'application/json' }
    $body = (@{ items = @(@{ producto_id = $Prod; cantidad = 1; precio = $Precio }) } | ConvertTo-Json -Depth 5 -Compress)
    try {
        $r = Invoke-WebRequest -Uri "$Base/pedidos/$PedId/items?sucursal_id=$Sid" -Method POST -Headers $headers -Body $body -UseBasicParsing -TimeoutSec 30
        return @{ ok = $true; status = [int]$r.StatusCode; tag = $Tag; body = $r.Content }
    } catch {
        $st = 0
        if ($_.Exception.Response) { $st = [int]$_.Exception.Response.StatusCode }
        return @{ ok = $false; status = $st; tag = $Tag; err = $_.Exception.Message }
    }
}
$j1 = Start-Job -ScriptBlock $jobScript -ArgumentList $script:FoodyQaBase, $mesero.token, $pedD, $sid, $Producto, $Precio, 'A'
$j2 = Start-Job -ScriptBlock $jobScript -ArgumentList $script:FoodyQaBase, $mesero.token, $pedD, $sid, $Producto, $Precio, 'B'
$null = Wait-Job $j1, $j2 -Timeout 40
$r1 = Receive-Job $j1; $r2 = Receive-Job $j2
Remove-Job $j1, $j2 -Force -ErrorAction SilentlyContinue

$okCount = @($r1, $r2 | Where-Object { $_.ok }).Count
Assert-Ok -Cond ($okCount -eq 2) -Msg "Ambos adds concurrentes OK serializados (ok=$okCount)"

$totalDespues = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pedD';")
$nItems = [int](Sql-Scalar "SELECT COUNT(*)::text FROM pedido_items WHERE pedido_id='$pedD';")
# 1 inicial + 2 adds = 3
Assert-Ok -Cond ($nItems -eq 3) -Msg "Sin perdida de items concurrentes (n=$nItems)"
$esperado = $totalAntes + (2 * $Precio)
# totales pueden incluir IVA — comparar delta items
Assert-Ok -Cond ($totalDespues -gt $totalAntes) -Msg "Total subio tras race (antes=$totalAntes despues=$totalDespues)"

# D3: sin columna version (optimistic) — documentado via SQL
$tieneVersion = Sql-Scalar "SELECT COUNT(*)::text FROM information_schema.columns WHERE table_name='pedidos' AND column_name='version';"
Assert-Ok -Cond ($tieneVersion -eq '0') -Msg 'Sin optimistic locking (columna version ausente) — solo FOR UPDATE'

# Cleanup
$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Sql-Scalar "UPDATE mesas SET mesera_asignada_id=NULL, mesera_asignada_at=NULL WHERE sucursal_id='$sid';"
$null = Sql-Scalar "UPDATE usuarios SET activo=false WHERE email='$Mesero2Email';"

Write-Host ''
if ($script:fallos -eq 0) {
    Write-Host 'Verificacion meseros-mesas OK' -ForegroundColor Green
    exit 0
}
Write-Host "$($script:fallos) fallos" -ForegroundColor Red
exit 1
