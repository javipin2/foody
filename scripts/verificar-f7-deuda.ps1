# F7 — Deuda media (parcial): UUID->400, liberarCanal RT, KDS prioridad API
# Uso: .\scripts\verificar-f7-deuda.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar F7 deuda media (parcial) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$script:fallos = 0

function Assert-Ok {
    param([bool]$Cond, [string]$Msg)
    if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
    else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

Write-Host ''
Write-Host '--- A FUZZ-500 UUID basura -> 400 (no 500) ---' -ForegroundColor Yellow
$bad = 'no-es-uuid'
$rMenu = Invoke-FoodyApi -Method GET -Path "/menu/$bad"
Assert-Ok -Cond ($rMenu.status -eq 400) -Msg "GET /menu/$bad -> $($rMenu.status) (esperado 400)"

$rCaja = Invoke-FoodyApi -Method GET -Path "/caja/activa/$bad" -Headers $h
Assert-Ok -Cond ($rCaja.status -eq 400) -Msg "GET /caja/activa/$bad -> $($rCaja.status) (esperado 400)"

$rPed = Invoke-FoodyApi -Method GET -Path "/pedidos/$bad/detalle" -Headers $h
Assert-Ok -Cond ($rPed.status -eq 400) -Msg "GET /pedidos/$bad/detalle -> $($rPed.status) (esperado 400)"

Write-Host ''
Write-Host '--- B RT-LEAK liberarCanal en pantallas calientes ---' -ForegroundColor Yellow
$rtRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'lib'
$rtFiles = @(
    'admin/presentation/widgets/mesas_grid_widget.dart',
    'admin/presentation/widgets/pedidos_kanban_widget.dart',
    'alertas/presentation/alertas_admin_screen.dart',
    'caja/presentation/caja_admin_screen.dart',
    'domiciliarios/presentation/domiciliarios_admin_screen.dart',
    'menu/presentation/menu_screen_foody.dart',
    'mesa/presentation/mesa_pedidos_sheet.dart',
    'pedidos/presentation/pedido_cajero_screen.dart',
    'pedidos/presentation/seguimiento_pedido_screen.dart'
)
$rtOk = 0
foreach ($rel in $rtFiles) {
    $p = Join-Path $rtRoot "features/$rel"
    if ((Test-Path $p) -and (Select-String -Path $p -Pattern 'FoodyRealtime\.liberarCanal' -Quiet)) {
        $rtOk++
    } else {
        Write-Host "  FALLO  falta liberarCanal: $rel" -ForegroundColor Red
        $script:fallos++
    }
}
Assert-Ok -Cond ($rtOk -eq $rtFiles.Count) -Msg "liberarCanal en $rtOk/$($rtFiles.Count) pantallas"

$helper = Join-Path $rtRoot 'core/realtime/foody_realtime.dart'
Assert-Ok -Cond ((Test-Path $helper) -and (Select-String -Path $helper -Pattern 'static Future<void> liberarCanal' -Quiet)) -Msg 'FoodyRealtime.liberarCanal helper'

Write-Host ''
Write-Host '--- C COC-UI-PRIO KDS + API prioridad ---' -ForegroundColor Yellow
$repo = Join-Path $rtRoot 'features/cocinas/data/cocinas_repository.dart'
$kds = Join-Path $rtRoot 'features/cocinas/presentation/kds_screen.dart'
Assert-Ok -Cond (Select-String -Path $repo -Pattern 'marcarPrioridadItem' -Quiet) -Msg 'CocinasRepository.marcarPrioridadItem'
Assert-Ok -Cond (Select-String -Path $kds -Pattern '_togglePrioridad' -Quiet) -Msg 'KDS _togglePrioridad'

$cocinas = Invoke-FoodyApi -Method GET -Path '/cocina/cocinas' -Headers $h
$lista = @()
if ($cocinas.ok -and $cocinas.json.datos) {
    if ($cocinas.json.datos -is [System.Array]) { $lista = @($cocinas.json.datos) }
    else { $lista = @($cocinas.json.datos) }
}
Assert-Ok -Cond ($lista.Count -ge 1) -Msg "cocinas KDS count=$($lista.Count)"

if ($lista.Count -ge 1) {
    $cid = $lista[0].id
    if (-not $cid) { $cid = $lista[0].cocina_id }
    $tickets = Invoke-FoodyApi -Method GET -Path "/cocina/tickets/$cid" -Headers $h
    $tList = @()
    if ($tickets.ok -and $tickets.json.datos) {
        if ($tickets.json.datos -is [System.Array]) { $tList = @($tickets.json.datos) }
        else { $tList = @($tickets.json.datos) }
    }
    $itemId = $null
    foreach ($t in $tList) {
        $items = @($t.items)
        foreach ($it in $items) {
            if ($it.item_id) { $itemId = [string]$it.item_id; break }
            if ($it.id) { $itemId = [string]$it.id; break }
        }
        if ($itemId) { break }
    }
    if ($itemId) {
        $rPrio = Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$itemId/prioridad" -Headers $h -Body @{ urgente = $true }
        Assert-Ok -Cond ($rPrio.status -lt 500 -and $rPrio.status -ne 0) -Msg "PATCH prioridad item -> $($rPrio.status)"
        [void](Invoke-FoodyApi -Method PATCH -Path "/cocina/items/$itemId/prioridad" -Headers $h -Body @{ urgente = $false })
    } else {
        Write-Host '  AVISO  sin items en tickets - API prio no ejercitada (codigo si cableado)' -ForegroundColor DarkYellow
    }
}

Write-Host ''
Write-Host '--- D AQ-CYCLE-01 sin forwardRef pedidos/domiciliarios ---' -ForegroundColor Yellow
$backend = Join-Path (Split-Path $PSScriptRoot -Parent) 'foody_backend\src\modulos'
$pedMod = Join-Path $backend 'pedidos\pedidos.module.ts'
$domMod = Join-Path $backend 'domiciliarios\domiciliarios.module.ts'
$hooks = Join-Path $backend 'pedidos\pedidos-dispatch-hooks.service.ts'
Assert-Ok -Cond ((Test-Path $hooks) -and (Select-String -Path $hooks -Pattern 'PedidosDispatchHooksService' -Quiet)) -Msg 'PedidosDispatchHooksService existe'
Assert-Ok -Cond (-not (Select-String -Path $pedMod -Pattern 'DomiciliariosModule' -Quiet)) -Msg 'PedidosModule NO importa DomiciliariosModule'
Assert-Ok -Cond (-not (Select-String -Path $pedMod -Pattern 'forwardRef' -Quiet)) -Msg 'PedidosModule sin forwardRef'
Assert-Ok -Cond ((Select-String -Path $domMod -Pattern 'PedidosModule' -Quiet) -and -not (Select-String -Path $domMod -Pattern 'forwardRef' -Quiet)) -Msg 'DomiciliariosModule importa PedidosModule one-way'

Write-Host ''
Write-Host '--- E Abiertos (no bloquean F7 parcial) ---' -ForegroundColor DarkYellow
Write-Host '  AQ-DUP-01 stock PedidosInventario vs InventarioService - MULTI_DAY diferido'

Write-Host ''
if ($script:fallos -gt 0) {
    Write-Host "F7 deuda PARCIAL con $script:fallos fallos" -ForegroundColor Red
    exit 1
}
Write-Host 'F7 deuda parcial OK (AQ-DUP abierto; AQ-CYCLE cerrado)' -ForegroundColor Green
exit 0
