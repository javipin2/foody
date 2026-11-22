# CAJ-TURNO-01, ANA-FILT-PROD-01, ANA-ESTADOS-01, COC-REIMP-01
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"
$fallos = 0
function Assert-Ok([bool]$Cond, [string]$Msg) {
  if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
  else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

Write-Host '=== Lote turno / analitica lineas / reimprimir ===' -ForegroundColor Cyan
$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
Assert-Ok ([bool]$salud.exito) 'GET /salud'

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal
$hasta = (Get-Date).ToString('yyyy-MM-dd')
$desde = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')

# CAJ-TURNO
$caja = Invoke-FoodyApi -Path "/caja/activa/$sid" -Headers $h
Assert-Ok ($caja.ok -and $caja.json.exito) 'GET caja/activa'
if ($caja.json.datos) {
  $horas = [double]$caja.json.datos.horas_abierta
  Assert-Ok ($horas -ge 0) "horas_abierta=$horas"
}

# ANA-ESTADOS: cancelado sin incluir_cancelados no suma ventas netas
$soloCancel = Invoke-FoodyApi -Path "/analitica/resumen?sucursal_id=$sid&desde=$desde&hasta=$hasta&estados=cancelado" -Headers $h
$vCancel = 0
if ($soloCancel.ok -and $soloCancel.json.datos.kpis) {
  $vCancel = [double]$soloCancel.json.datos.kpis.ventas_netas
}
Assert-Ok ($soloCancel.ok -and $soloCancel.json.exito -and $vCancel -eq 0) "estados=cancelado sin incluir → ventas=$vCancel (0)"

$pagado = Invoke-FoodyApi -Path "/analitica/resumen?sucursal_id=$sid&desde=$desde&hasta=$hasta&estados=pagado" -Headers $h
$mix = Invoke-FoodyApi -Path "/analitica/resumen?sucursal_id=$sid&desde=$desde&hasta=$hasta&estados=pagado,cancelado" -Headers $h
$vPag = [double]$pagado.json.datos.kpis.ventas_netas
$vMix = [double]$mix.json.datos.kpis.ventas_netas
Assert-Ok ([math]::Abs($vPag - $vMix) -lt 0.02) "pagado+cancelado == pagado ($vMix vs $vPag)"

# ANA-FILT-PROD (mismo criterio que verificar-reportes)
$prodId = 'f0000000-0000-4000-8000-000000000002'
$anP = Invoke-FoodyApi -Path "/analitica/resumen?sucursal_id=$sid&desde=$desde&hasta=$hasta&producto_ids=$prodId" -Headers $h
$vP = [double]$anP.json.datos.kpis.ventas_netas
$sqlP = docker exec supabase-db psql -U postgres -d postgres -t -A -c @"
SELECT COALESCE(SUM(
  pi.cantidad * pi.precio_unitario
  + COALESCE((SELECT SUM(pit.precio_topping) FROM pedido_item_toppings pit WHERE pit.pedido_item_id = pi.id), 0) * pi.cantidad
  + COALESCE((SELECT SUM(pib.precio_bebida * pib.cantidad) FROM pedido_item_bebidas pib WHERE pib.pedido_item_id = pi.id), 0)
),0)::text
FROM pedido_items pi
JOIN pedidos p ON p.id = pi.pedido_id
WHERE p.sucursal_id='$sid'
  AND p.created_at >= '$desde'::timestamptz
  AND p.created_at < ('$hasta'::date + interval '1 day')
  AND p.estado NOT IN ('cancelado','rechazado')
  AND pi.producto_id='$prodId';
"@
$sqlPn = [double](([string]$sqlP).Trim())
Assert-Ok ($anP.ok -and ([math]::Abs($vP - $sqlPn) -lt 0.02)) "filtro producto lineas API=$vP BD=$sqlPn"

# COC-REIMP
$pedidoId = docker exec supabase-db psql -U postgres -d postgres -t -A -c "SELECT p.id::text FROM pedidos p JOIN pedido_items pi ON pi.pedido_id=p.id WHERE p.sucursal_id='$sid' AND pi.cocina_id IS NOT NULL LIMIT 1"
$pedidoId = ([string]$pedidoId).Trim()
if ($pedidoId) {
  $reimp = Invoke-FoodyApi -Method POST -Path '/impresion/reimprimir' -Headers $h -Body @{
    pedido_id   = $pedidoId
    sucursal_id = $sid
  }
  Assert-Ok ($reimp.ok -and $reimp.json.exito -and $reimp.json.datos.encolado) "POST reimprimir pedido=$pedidoId"
} else {
  Write-Host '  SKIP sin pedido con cocina' -ForegroundColor Yellow
}

$fake = Invoke-FoodyApi -Method POST -Path '/impresion/reimprimir' -Headers $h -Body @{
  pedido_id   = '00000000-0000-4000-8000-000000000099'
  sucursal_id = $sid
}
Assert-Ok (-not $fake.ok -or $fake.status -ge 400) "reimprimir pedido inexistente rechazado ($($fake.status))"

if ($fallos -gt 0) { Write-Host "FAIL=$fallos" -ForegroundColor Red; exit 1 }
Write-Host 'OK verificar-lote-turno-ana-reimp' -ForegroundColor Green
exit 0
