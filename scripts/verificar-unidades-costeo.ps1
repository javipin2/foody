# Conversión g↔kg / ml↔L en subrecetas (costeo + stock).
# Uso: .\scripts\verificar-unidades-costeo.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar unidades costeo (g/kg, ml/L) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal
$script:fallos = 0

function Assert-Ok([bool]$Cond, [string]$Msg) {
    if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
    else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

# 1) Selfcheck util (si dist existe)
$self = Join-Path $PSScriptRoot '..\foody_backend\dist\modulos\costeo\unidad-costeo.util.selfcheck.js'
if (Test-Path $self) {
    node $self
    Assert-Ok ($LASTEXITCODE -eq 0) 'selfcheck unidad-costeo.util'
} else {
    Write-Host '  NOTE sin dist selfcheck — se valida vía API' -ForegroundColor Yellow
}

# 2) Crear insumo en kg
$nombreKg = "QA Azucar kg $(Get-Random)"
$crearIng = Invoke-FoodyApi -Method POST -Path '/inventario' -Headers $h -Body @{
    sucursal_id     = $sid
    nombre          = $nombreKg
    unidad_base     = 'kg'
    precio_compra   = 4000
    peso_bruto      = 1
    peso_neto       = 1
    stock_actual    = 10
    stock_minimo    = 0.5
    descontar_stock = $true
}
Assert-Ok ($crearIng.ok -and $crearIng.json.exito) "Crear insumo kg status=$($crearIng.status) msg=$($crearIng.json.mensaje)"
$ingId = $crearIng.json.datos.id

# 3) Subreceta con línea en g (compatible con kg)
$nombreSr = "QA Jarabe g $(Get-Random)"
$crearSr = Invoke-FoodyApi -Method POST -Path '/costeo/subrecetas' -Headers $h -Body @{
    sucursal_id         = $sid
    nombre              = $nombreSr
    cantidad_resultado  = 1000
    unidad_resultado    = 'ml'
    margen_error        = 0.05
    usa_produccion_lote = $false
    items               = @(
        @{
            tipo_item      = 'ingrediente'
            ingrediente_id = $ingId
            cantidad       = 250
            unidad         = 'g'
        }
    )
}
Assert-Ok ($crearSr.ok -and $crearSr.json.exito) "Subreceta con 250g de insumo kg status=$($crearSr.status) err=$($crearSr.json.error)"
$srId = $crearSr.json.datos.receta_id
if (-not $srId) { $srId = $crearSr.json.datos.id }

# 4) Detalle: unidad de línea preservada + costo convierte g→kg
if ($srId) {
    $det = Invoke-FoodyApi -Path "/costeo/subrecetas/detalle/${srId}?sucursal_id=$sid" -Headers $h
    Assert-Ok ($det.ok -and $det.json.exito) "Detalle subreceta status=$($det.status)"
    $item = @($det.json.datos.items) | Select-Object -First 1
    Assert-Ok ($item.unidad -eq 'g') "Línea guardada en g (got=$($item.unidad))"
    $costoTotal = [decimal]$det.json.datos.costo.costo_total
    # 250g = 0.25 kg * 4000 $/kg = 1000; + margen 5% → 1050
    Assert-Ok ($costoTotal -ge 900 -and $costoTotal -le 1200) "Costo lote ~1050 con conversión (got=$costoTotal)"
} else {
    Assert-Ok $false 'sin receta_id en create'
}

# 5) Incompatible: und vs kg → 400
$bad = Invoke-FoodyApi -Method POST -Path '/costeo/subrecetas' -Headers $h -Body @{
    sucursal_id        = $sid
    nombre             = "QA Bad und $(Get-Random)"
    cantidad_resultado = 1
    unidad_resultado   = 'und'
    items              = @(
        @{
            tipo_item      = 'ingrediente'
            ingrediente_id = $ingId
            cantidad       = 1
            unidad         = 'und'
        }
    )
}
Assert-Ok (-not $bad.ok -or -not $bad.json.exito) "und vs kg rechazado status=$($bad.status) err=$($bad.json.error)"

# 6) Insumo L + línea ml
$nombreL = "QA Agua L $(Get-Random)"
$crearL = Invoke-FoodyApi -Method POST -Path '/inventario' -Headers $h -Body @{
    sucursal_id     = $sid
    nombre          = $nombreL
    unidad_base     = 'L'
    precio_compra   = 2000
    peso_bruto      = 1
    peso_neto       = 1
    stock_actual    = 5
    descontar_stock = $true
}
Assert-Ok ($crearL.ok -and $crearL.json.exito) "Crear insumo L status=$($crearL.status)"
$ingL = $crearL.json.datos.id

$srMl = Invoke-FoodyApi -Method POST -Path '/costeo/subrecetas' -Headers $h -Body @{
    sucursal_id        = $sid
    nombre             = "QA Limonada ml $(Get-Random)"
    cantidad_resultado = 1000
    unidad_resultado   = 'ml'
    items              = @(
        @{
            tipo_item      = 'ingrediente'
            ingrediente_id = $ingL
            cantidad       = 500
            unidad         = 'ml'
        }
    )
}
Assert-Ok ($srMl.ok -and $srMl.json.exito) "Subreceta 500ml de insumo L status=$($srMl.status) err=$($srMl.json.error)"

if ($script:fallos -gt 0) {
    Write-Host "Verificacion unidades FALLO: $($script:fallos) asserts" -ForegroundColor Red
    exit 1
}
Write-Host 'Verificacion unidades-costeo OK' -ForegroundColor Green
