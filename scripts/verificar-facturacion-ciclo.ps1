# Prompt 19 — Facturacion electronica (DIAN/MATIAS): errores, cola, consistencia, anular.
# Nota: MATIAS/DIAN PAUSADOS — verifica capa interna (borrador/emitir/anular HTML).
# Uso: .\scripts\verificar-facturacion-ciclo.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar Facturacion ciclo (Prompt 19) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$h = $admin.headers
$hc = $cajero.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$Precio = 8000
$RestId = 'b0000000-0000-4000-8000-000000000001'
$script:fallos = 0
$planAntes = $null

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

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- 0) MATIAS / DIAN en repo ---' -ForegroundColor Yellow

$repo = Split-Path $PSScriptRoot
$hitsMatias = @(Select-String -Path (Join-Path $repo 'foody_backend\src\**\*.ts') -Pattern 'matias|MATIAS' -SimpleMatch:$false -ErrorAction SilentlyContinue)
$hitsMatias += @(Select-String -Path (Join-Path $repo 'docs\*.md') -Pattern 'MATIAS' -ErrorAction SilentlyContinue | Select-Object -First 5)
Assert-Ok -Cond ($hitsMatias.Count -eq 0) -Msg "Cero referencias MATIAS en src/docs (got=$($hitsMatias.Count))"

$estadosBd = Sql-Scalar "SELECT string_agg(DISTINCT estado, ',') FROM facturas;"
# constraint check
$chk = Sql-Scalar @"
SELECT pg_get_constraintdef(oid) FROM pg_constraint
WHERE conrelid = 'facturas'::regclass AND contype = 'c' AND conname LIKE '%estado%';
"@
Assert-Ok -Cond ($chk -match 'borrador' -and $chk -match 'emitida' -and $chk -match 'anulada') -Msg "Estados BD solo borrador|emitida|anulada"
Assert-Ok -Cond ($chk -notmatch 'aceptada_dian|rechazada|pendiente_dian') -Msg 'Sin estados DIAN en constraint'

$facDir = Join-Path $repo 'foody_backend\src\modulos\facturacion'
$colaHits = @()
if (Test-Path $facDir) {
    $colaHits = @(Get-ChildItem $facDir -Filter '*.ts' -Recurse | Select-String -Pattern 'HttpService|axios\.|BullModule|reintentar|cola_documentos' -ErrorAction SilentlyContinue)
}
Assert-Ok -Cond ($colaHits.Count -eq 0) -Msg "Sin cola/HTTP MATIAS en facturacion (hits=$($colaHits.Count))"

# Eleva plan temporalmente (modulo enterprise)
$planAntes = Sql-Scalar "SELECT plan FROM suscripciones_restaurante WHERE restaurante_id='$RestId' LIMIT 1;"
$null = Sql-Scalar "UPDATE suscripciones_restaurante SET plan='enterprise' WHERE restaurante_id='$RestId';"
# Re-login para JWT con plan fresco (si el guard lee BD en cada request, OK)
$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers

try {
$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Ensure-CajaAbierta -Headers $hc
$null = Ensure-HorariosDemoAbiertos

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- A) Config + errores locales (no MATIAS) ---' -ForegroundColor Yellow

$cfgGet = Invoke-FoodyApi -Path "/facturacion/config/$sid" -Headers $h
Assert-Ok -Cond ($cfgGet.ok -and $cfgGet.json.exito) -Msg "GET config facturacion ($($cfgGet.json.error))"

# Guardar config incompleta / completa
$null = Invoke-FoodyApi -Method POST -Path '/facturacion/config' -Headers $h -Body @{
    sucursal_id     = $sid
    nit             = '900123456'
    razon_social    = 'Foody QA SAS'
    regimen         = 'comun'
    aplica_iva      = $true
    porcentaje_iva  = 19
    prefijo_factura = 'FE'
}

$libres = Get-MesasLibres -Headers $hc
if ($libres.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres = Get-MesasLibres -Headers $hc
}
$Mesa = $libres[0].id

$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id              = $sid
    mesa_id                  = $Mesa
    tipo                     = 'mesa'
    device_id                = 'qa-fe-19'
    metodo_pago              = 'efectivo'
    requiere_factura         = $true
    nit_cliente              = '123456789'
    nombre_fiscal_cliente    = 'Cliente QA FE'
    email_cliente            = 'cliente.fe@qa.local'
    items                    = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond ($crear.ok -and $crear.json.exito) -Msg "Crear pedido con requiere_factura ($($crear.json.error))"
$pedId = $crear.json.datos.pedido_id
if (-not $pedId) { $pedId = $crear.json.datos.id }

$facId = Sql-Scalar "SELECT id::text FROM facturas WHERE pedido_id='$pedId' ORDER BY created_at DESC LIMIT 1;"
$estFac = Sql-Scalar "SELECT estado FROM facturas WHERE id='$facId';"
Assert-Ok -Cond ($null -ne $facId -and $estFac -eq 'borrador') -Msg "Borrador creado ($facId estado=$estFac)"

# Emitir ANTES de pagar -> PEDIDO_NO_FACTURABLE
$emitEarly = Invoke-FoodyApi -Method POST -Path "/facturacion/emitir/$pedId" -Headers $h -Body @{
    sucursal_id = $sid
}
Assert-Ok -Cond (-not ($emitEarly.ok -and $emitEarly.json.exito)) -Msg "Emitir sin pagar rechazado ($($emitEarly.json.error))"

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- B) Consistencia montos cobro <-> factura ---' -ForegroundColor Yellow

$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedId/estado?sucursal_id=$sid" -Headers $h -Body @{ estado = 'listo' }
$cobrar = Invoke-FoodyApi -Method POST -Path "/pedidos/$pedId/cobrar?sucursal_id=$sid" -Headers $hc -Body @{
    metodo_pago = 'efectivo'
}
Assert-Ok -Cond ($cobrar.ok -and $cobrar.json.exito) -Msg "Cobrar pedido ($($cobrar.json.error))"

$totalPed = [double](Sql-Scalar "SELECT total::text FROM pedidos WHERE id='$pedId';")
$totalFacAntes = [double](Sql-Scalar "SELECT total::text FROM facturas WHERE id='$facId';")
# Sync al emitir debe alinear
$emit = Invoke-FoodyApi -Method POST -Path "/facturacion/emitir/$pedId" -Headers $h -Body @{
    sucursal_id = $sid
}
Assert-Ok -Cond ($emit.ok -and $emit.json.exito) -Msg "Emitir local ($($emit.json.error))"
$estEmit = Sql-Scalar "SELECT estado FROM facturas WHERE id='$facId';"
$numFac = Sql-Scalar "SELECT numero_factura FROM facturas WHERE id='$facId';"
$totalFac = [double](Sql-Scalar "SELECT total::text FROM facturas WHERE id='$facId';")
$ivaFac = [double](Sql-Scalar "SELECT iva::text FROM facturas WHERE id='$facId';")
$subFac = [double](Sql-Scalar "SELECT subtotal::text FROM facturas WHERE id='$facId';")
Assert-Ok -Cond ($estEmit -eq 'emitida') -Msg "Estado emitida (got=$estEmit)"
Assert-Ok -Cond ($numFac -match '^FE-') -Msg "Numero local $numFac"
Assert-Ok -Cond ([math]::Abs($totalFac - $totalPed) -lt 0.02) -Msg "total factura=$totalFac == pedido=$totalPed"
Assert-Ok -Cond ([math]::Abs(($subFac + $ivaFac) - $totalFac) -lt 0.05) -Msg "subtotal+iva≈total ($subFac+$ivaFac)"

# Sin lineas de items en factura (agregado)
$colsItem = Sql-Scalar "SELECT COUNT(*)::text FROM information_schema.tables WHERE table_name='factura_items';"
Assert-Ok -Cond ($colsItem -eq '0') -Msg 'Sin tabla factura_items (solo agregados)'

# HTML informativo
$pdf = Invoke-FoodyApi -Path "/facturacion/facturas/${facId}/pdf?sucursal_id=$sid" -Headers $h
Assert-Ok -Cond ($pdf.ok -and $pdf.json.exito) -Msg "Vista HTML/pdf ($($pdf.json.error))"
$html = ''
if ($pdf.json.datos.html) { $html = [string]$pdf.json.datos.html }
elseif ($pdf.json.datos.contenido) { $html = [string]$pdf.json.datos.contenido }
elseif ($pdf.json.datos -is [string]) { $html = [string]$pdf.json.datos }
Assert-Ok -Cond ($html -match 'informativo|DIAN|proveedor' -or $html.Length -gt 50) -Msg 'HTML menciona informativo/DIAN o tiene cuerpo'

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- C) Anular post-facturado + cancel pedido ---' -ForegroundColor Yellow

$anular = Invoke-FoodyApi -Method POST -Path "/facturacion/anular/$facId" -Headers $h -Body @{
    sucursal_id = $sid
    motivo      = 'QA Prompt 19 anular'
}
Assert-Ok -Cond ($anular.ok -and $anular.json.exito) -Msg "Anular factura ($($anular.json.error))"
$estAnul = Sql-Scalar "SELECT estado FROM facturas WHERE id='$facId';"
Assert-Ok -Cond ($estAnul -eq 'anulada') -Msg "Factura anulada (got=$estAnul)"
$nota = ''
if ($anular.json.datos.nota) { $nota = [string]$anular.json.datos.nota }
Assert-Ok -Cond ($nota -match 'Nota credito|DIAN|pendiente') -Msg "Stub nota credito DIAN ($nota)"

$estPed = Sql-Scalar "SELECT estado FROM pedidos WHERE id='$pedId';"
Assert-Ok -Cond ($estPed -eq 'pagado') -Msg "Anular factura NO cambia pedido (sigue $estPed)"

# Cancelar pedido pagado: FSM bloquea
$cancelPed = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedId/estado?sucursal_id=$sid" -Headers $h -Body @{
    estado = 'cancelado'
    motivo = 'QA post factura'
}
Assert-Ok -Cond (-not ($cancelPed.ok -and $cancelPed.json.exito)) -Msg "Cancelar pagado bloqueado ($($cancelPed.json.error))"

# Sin endpoint reintentar
$retry = Invoke-FoodyApi -Method POST -Path "/facturacion/reintentar/$facId" -Headers $h -Body @{ sucursal_id = $sid }
Assert-Ok -Cond (-not ($retry.ok -and $retry.json.exito)) -Msg "Sin endpoint reintentar (status=$($retry.status))"

} finally {
    if ($planAntes) {
        $null = Sql-Scalar "UPDATE suscripciones_restaurante SET plan='$planAntes' WHERE restaurante_id='$RestId';"
        Write-Host "Plan restaurado: $planAntes" -ForegroundColor DarkGray
    }
    $null = Limpiar-PedidosActivosDemo -Headers $h
}

Write-Host ''
if ($script:fallos -eq 0) {
    Write-Host 'Verificacion facturacion-ciclo OK (capa local; DIAN/MATIAS pausados)' -ForegroundColor Green
    exit 0
}
Write-Host "$($script:fallos) fallos" -ForegroundColor Red
exit 1
