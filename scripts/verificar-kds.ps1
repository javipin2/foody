# Prompt 12 — Cocina/KDS: tickets, estados item, cancelacion, prioridad, reimpresion.
# Uso: .\scripts\verificar-kds.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar KDS / Cocina (Prompt 12) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host "OK salud" -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$cocina = Get-FoodyToken 'cocina@foody.demo'
$h = $admin.headers
$hc = $cajero.headers
$hk = $cocina.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
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

$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Ensure-CajaAbierta -Headers $hc
$null = Ensure-HorariosDemoAbiertos
$null = Restaurar-InventarioDemo -Headers $h

$kdsCocinas = Invoke-FoodyApi -Path '/cocina/cocinas' -Headers $hk
Assert-Ok -Cond ($kdsCocinas.ok -and $kdsCocinas.json.exito) -Msg 'GET /cocina/cocinas'
$cocinaId = $null
if ($kdsCocinas.json.datos -and @($kdsCocinas.json.datos).Count -ge 1) {
    $cocinaId = @($kdsCocinas.json.datos)[0].id
}
if (-not $cocinaId) { $cocinaId = $cocina.json.datos.usuario.cocina_id }
if (-not $cocinaId) { $cocinaId = 'd0000000-0000-4000-8000-000000000001' }
Write-Host "Cocina KDS: $cocinaId" -ForegroundColor DarkGray

# Asegurar producto apunta a esta cocina
$null = Sql-Scalar "UPDATE productos SET cocina_id='$cocinaId' WHERE id='$Producto'"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- A) Pedido nuevo aparece en tickets ---' -ForegroundColor Yellow

$libres = Get-MesasLibres -Headers $hc
if ($libres.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres = Get-MesasLibres -Headers $hc
}
$Mesa = $libres[0].id

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa
    tipo        = 'mesa'
    device_id   = 'qa-kds-a'
    metodo_pago = 'efectivo'
    items       = @(
        @{ producto_id = $Producto; cantidad = 1; precio = $Precio }
        @{ producto_id = $Producto; cantidad = 1; precio = $Precio }
    )
}
Assert-Ok -Cond ($crear.ok -and $crear.json.exito) -Msg 'Crear pedido staff 2 items'
$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }

$copia1 = [int](Sql-Scalar "SELECT comanda_copia::text FROM pedidos WHERE id='$pedidoId'")
Assert-Ok -Cond ($copia1 -ge 1) -Msg "comanda_copia tras crear n=$copia1"

$tickets = Invoke-FoodyApi -Path "/cocina/tickets/$cocinaId" -Headers $hk
Assert-Ok -Cond ($tickets.ok -and $tickets.json.exito) -Msg 'GET /cocina/tickets'
$lista = @($tickets.json.datos)
$ticket = $lista | Where-Object { $_.pedido_id -eq $pedidoId } | Select-Object -First 1
Assert-Ok -Cond ([bool]$ticket) -Msg 'Pedido nuevo visible en KDS'
$items = @($ticket.items)
Assert-Ok -Cond ($items.Count -ge 2) -Msg "Ticket tiene $($items.Count) items"

# Orden FIFO backend: created_at ASC — el pedido recien creado debe estar en la lista
$idsOrden = @($lista | ForEach-Object { $_.pedido_id })
Assert-Ok -Cond ($idsOrden -contains $pedidoId) -Msg 'Pedido en listado ordenado por created_at ASC'

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- B) Transiciones estado_cocina ---' -ForegroundColor Yellow

$item1 = $items[0].item_id
$item2 = $items[1].item_id
if (-not $item1) { $item1 = $items[0].id }
if (-not $item2) { $item2 = $items[1].id }

$prep = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$item1/estado" -Headers $hk -Body @{
    estado_cocina = 'preparando'
}
Assert-Ok -Cond ($prep.ok -and $prep.json.exito) -Msg 'item1 pendiente->preparando'
Assert-Ok -Cond ($prep.json.datos.estado_pedido -eq 'en_cocina') -Msg "pedido sigue en_cocina got=$($prep.json.datos.estado_pedido)"

$listo1 = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$item1/estado" -Headers $hk -Body @{
    estado_cocina = 'listo'
}
Assert-Ok -Cond ($listo1.ok -and $listo1.json.exito) -Msg 'item1 preparando->listo'
# pedido aun no listo (falta item2)
$estPed = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedidoId'"
Assert-Ok -Cond ($estPed -eq 'en_cocina') -Msg "pedido parcial listo sigue en_cocina got=$estPed"

$listo2 = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$item2/estado" -Headers $hk -Body @{
    estado_cocina = 'listo'
}
Assert-Ok -Cond ($listo2.ok -and $listo2.json.exito) -Msg 'item2 -> listo'
$estPed2 = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedidoId'"
Assert-Ok -Cond ($estPed2 -eq 'listo') -Msg "todos listos -> pedido listo got=$estPed2"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- C) Cancelacion item en preparacion ---' -ForegroundColor Yellow

# C1: cocina NO tiene DELETE — solo no_disponible
$crearC = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-kds-cancel'
    metodo_pago = 'pendiente'
    items       = @(
        @{ producto_id = $Producto; cantidad = 1; precio = $Precio }
        @{ producto_id = $Producto; cantidad = 1; precio = $Precio }
    )
}
$pc = $crearC.json.datos.pedido_id
if (-not $pc) { $pc = $crearC.json.datos.id }
$tickC = Invoke-FoodyApi -Path "/cocina/tickets/$cocinaId" -Headers $hk
$tC = @($tickC.json.datos) | Where-Object { $_.pedido_id -eq $pc } | Select-Object -First 1
$ic = @($tC.items)
$ic1 = $ic[0].item_id; if (-not $ic1) { $ic1 = $ic[0].id }
$ic2 = $ic[1].item_id; if (-not $ic2) { $ic2 = $ic[1].id }

$null = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$ic1/estado" -Headers $hk -Body @{ estado_cocina = 'preparando' }

# DELETE desde cocina path no existe
$delCocina = Invoke-FoodyApi -Method DELETE -Path "/cocina/items/$ic1" -Headers $hk
Assert-Ok -Cond (-not ($delCocina.ok -and $delCocina.json.exito)) -Msg "Cocina sin DELETE item status=$($delCocina.status)"

# no_disponible desde cocina
$nodisp = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$ic1/estado" -Headers $hk -Body @{
    estado_cocina = 'no_disponible'
    motivo        = 'QA sin insumos'
}
Assert-Ok -Cond ($nodisp.ok -and $nodisp.json.exito) -Msg 'Cocina marca no_disponible'
$alertaNd = Sql-Scalar "SELECT COUNT(*)::text FROM alertas_riesgo WHERE sucursal_id='$sid' AND tipo='item_no_disponible_cocina' AND created_at > now() - interval '5 minutes'"
Assert-Ok -Cond ([int]$alertaNd -ge 1) -Msg "Alerta item_no_disponible_cocina n=$alertaNd"

# Marcar segundo listo: con un no_disponible, pedido NO debe llegar a listo (hallazgo COC-NODISP-01)
$null = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$ic2/estado" -Headers $hk -Body @{ estado_cocina = 'listo' }
$estNd = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pc'"
Assert-Ok -Cond ($estNd -ne 'listo') -Msg "COC-NODISP-01 pedido con no_disponible no llega a listo got=$estNd"

# C2: staff DELETE item en preparando → desaparece del KDS
$crearD = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-kds-del'
    metodo_pago = 'pendiente'
    items       = @(
        @{ producto_id = $Producto; cantidad = 1; precio = $Precio }
        @{ producto_id = $Producto; cantidad = 1; precio = $Precio }
    )
}
$pd = $crearD.json.datos.pedido_id
if (-not $pd) { $pd = $crearD.json.datos.id }
$tickD = Invoke-FoodyApi -Path "/cocina/tickets/$cocinaId" -Headers $hk
$tD = @($tickD.json.datos) | Where-Object { $_.pedido_id -eq $pd } | Select-Object -First 1
$idDel = @($tD.items)[0].item_id
if (-not $idDel) { $idDel = @($tD.items)[0].id }
$null = Sql-Scalar "UPDATE pedido_items SET estado_cocina='preparando' WHERE id='$idDel'"
$delStaff = Invoke-FoodyApi -Method DELETE -Path "/pedidos/$pd/items/$idDel`?sucursal_id=$sid" -Headers $hc -Body @{
    motivo = 'QA cancel post-prep'
}
Assert-Ok -Cond ($delStaff.ok -and $delStaff.json.exito) -Msg 'Staff DELETE item en preparando permitido'
$tickD2 = Invoke-FoodyApi -Path "/cocina/tickets/$cocinaId" -Headers $hk
$tD2 = @($tickD2.json.datos) | Where-Object { $_.pedido_id -eq $pd } | Select-Object -First 1
$queda = @($tD2.items) | Where-Object { ($_.item_id -eq $idDel) -or ($_.id -eq $idDel) }
Assert-Ok -Cond ($queda.Count -eq 0) -Msg 'Item eliminado desaparece del ticket KDS'
$alertaDel = Sql-Scalar "SELECT COUNT(*)::text FROM alertas_riesgo WHERE sucursal_id='$sid' AND tipo='item_eliminado_post_cocina' AND created_at > now() - interval '5 minutes'"
Assert-Ok -Cond ([int]$alertaDel -ge 1) -Msg "Alerta item_eliminado_post_cocina n=$alertaDel"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- D) Prioridad [URGENTE] ---' -ForegroundColor Yellow

$prio = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$idDel/prioridad" -Headers $hk -Body @{ urgente = $true }
# item ya borrado — debe fallar; probar con item vivo
$itemVivo = Sql-Scalar "SELECT id::text FROM pedido_items WHERE pedido_id='$pd' LIMIT 1"
$prio2 = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$itemVivo/prioridad" -Headers $hk -Body @{ urgente = $true }
Assert-Ok -Cond ($prio2.ok -and $prio2.json.exito) -Msg 'PATCH /cocina/items/:id/prioridad'
$obs = Sql-Scalar "SELECT observaciones FROM pedido_items WHERE id='$itemVivo'"
Assert-Ok -Cond ($obs -match '\[URGENTE\]') -Msg "Observaciones con [URGENTE] got=$obs"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- E) Reimpresion comanda ---' -ForegroundColor Yellow

$copiaAntes = [int](Sql-Scalar "SELECT comanda_copia::text FROM pedidos WHERE id='$pd'")
$jobsAntes = [int](Sql-Scalar "SELECT COUNT(*)::text FROM impresion_cocina_jobs WHERE pedido_id='$pd'")
# editar cantidad dispara reimprimir + encolar
$patch = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pd/items/$itemVivo`?sucursal_id=$sid" -Headers $hc -Body @{
    cantidad = 2
}
Assert-Ok -Cond ($patch.ok -and $patch.json.exito) -Msg 'PATCH item dispara edicion'
$reimp = $patch.json.datos.reimprimir -eq $true
Assert-Ok -Cond $reimp -Msg 'API responde reimprimir=true'
Start-Sleep -Milliseconds 400
$copiaDespues = [int](Sql-Scalar "SELECT comanda_copia::text FROM pedidos WHERE id='$pd'")
$jobsDespues = [int](Sql-Scalar "SELECT COUNT(*)::text FROM impresion_cocina_jobs WHERE pedido_id='$pd'")
Assert-Ok -Cond ($copiaDespues -gt $copiaAntes) -Msg "comanda_copia incrementa $copiaAntes->$copiaDespues"
Assert-Ok -Cond ($jobsDespues -gt $jobsAntes) -Msg "job impresion encolado $jobsAntes->$jobsDespues"

# No hay endpoint dedicado reimprimir
$reimpEp = Invoke-FoodyApi -Method POST -Path "/impresion/reimprimir" -Headers $h -Body @{ pedido_id = $pd }
Assert-Ok -Cond (-not ($reimpEp.ok -and $reimpEp.json.exito)) -Msg "Sin POST /impresion/reimprimir status=$($reimpEp.status)"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- F) Sin maquina de estados item ---' -ForegroundColor Yellow
# salto pendiente -> listo directo permitido
$crearF = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    tipo        = 'para_llevar'
    device_id   = 'qa-kds-jump'
    metodo_pago = 'pendiente'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
$pf = $crearF.json.datos.pedido_id
if (-not $pf) { $pf = $crearF.json.datos.id }
$itf = Sql-Scalar "SELECT id::text FROM pedido_items WHERE pedido_id='$pf' LIMIT 1"
$jump = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$itf/estado" -Headers $hk -Body @{ estado_cocina = 'listo' }
Assert-Ok -Cond ($jump.ok -and $jump.json.exito) -Msg 'COC-FSM-01 salto pendiente->listo permitido sin validar origen'

$null = Limpiar-PedidosActivosDemo -Headers $h

Write-Host ''
if ($script:fallos -gt 0) {
    Write-Host "Verificacion KDS FALLO: $($script:fallos) asserts" -ForegroundColor Red
    exit 1
}
Write-Host 'Verificacion KDS OK' -ForegroundColor Green
exit 0
