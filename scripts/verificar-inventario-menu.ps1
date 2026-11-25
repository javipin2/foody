# Verifica P1.1: ajuste stock -> productos.disponible en menu
# Uso: .\scripts\verificar-inventario-menu.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"
Assert-FoodyQaDisposable

$fallos = 0
function Assert($c, $m) { if (-not (Assert-Qa $c $m)) { $script:fallos++ } }

Write-Host '=== Verificar inventario -> menu (P1.1) ===' -ForegroundColor Cyan

$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers

try {
$menuAntes = Invoke-FoodyApi -Path "/menu/$sid"
Assert ($menuAntes.ok -and $menuAntes.json.exito) 'GET menu sucursal'
$prodAntes = @(Get-ProductosMenuFlat $menuAntes.json | Where-Object { $_.id -eq $Producto })[0]
Assert ($null -ne $prodAntes) 'Producto demo en menu'
$disponibleAntes = [bool]$prodAntes.disponible

$receta = Invoke-FoodyApi -Path "/inventario/producto-ingredientes/$Producto" -Headers $h
Assert ($receta.ok -and $receta.json.exito) "Receta producto ($($receta.json.mensaje))"
$itemsReceta = @($receta.json.datos.items | Where-Object { $_.ingrediente_id })
if ($itemsReceta.Count -eq 0) {
    Write-Host '  SKIP  Sin ingredientes directos en receta demo' -ForegroundColor Yellow
    exit 0
}
$ingId = $itemsReceta[0].ingrediente_id

$det = Invoke-FoodyApi -Path "/inventario/$sid" -Headers $h
$listaIng = @($det.json.datos)
$ingRow = @($listaIng | Where-Object { $_.id -eq $ingId })[0]
Assert ($null -ne $ingRow) 'Ingrediente en inventario'
$stockOriginal = [decimal]$ingRow.stock_actual

$ajuste = Invoke-FoodyApi -Method PATCH -Path "/inventario/$ingId" -Headers $h -Body @{
    stock_nuevo   = 0
    motivo_ajuste = 'QA verificar-inventario-menu'
}
if (-not ($ajuste.ok -and $ajuste.json.exito)) {
    Write-Host "  DEBUG ajuste status=$($ajuste.status) err=$($ajuste.json.error) msg=$($ajuste.json.mensaje)" -ForegroundColor DarkYellow
}
Assert ($ajuste.ok -and $ajuste.json.exito) 'Ajuste stock a 0'

Start-Sleep -Seconds 1
$menuDespues = Invoke-FoodyApi -Path "/menu/$sid"
$enMenuDespues = @(Get-ProductosMenuFlat $menuDespues.json | Where-Object { $_.id -eq $Producto })
$catalogoDespues = Get-ProductoCatalogo -Headers $h -ProductoId $Producto
Assert ($enMenuDespues.Count -eq 0 -and $catalogoDespues.disponible -eq $false) 'Producto no disponible tras agotar ingrediente'

$null = Invoke-FoodyApi -Method PATCH -Path "/inventario/$ingId" -Headers $h -Body @{
    stock_nuevo   = [double]$stockOriginal
    motivo_ajuste = 'QA restaurar stock'
}
Start-Sleep -Seconds 1
$menuRest = Invoke-FoodyApi -Path "/menu/$sid"
$enMenuRest = @(Get-ProductosMenuFlat $menuRest.json | Where-Object { $_.id -eq $Producto })
$catalogoRest = Get-ProductoCatalogo -Headers $h -ProductoId $Producto
if ($disponibleAntes) {
    Assert ($enMenuRest.Count -gt 0 -and $catalogoRest.disponible -eq $true) 'Producto disponible tras restaurar stock'
}
}
finally {
    Restaurar-InventarioDemo -Headers $h
}

Write-Host ''
if ($fallos -eq 0) {
    Write-Host 'Verificacion inventario-menu OK' -ForegroundColor Green
    exit 0
}
Write-Host "$fallos fallos" -ForegroundColor Red
exit 1
