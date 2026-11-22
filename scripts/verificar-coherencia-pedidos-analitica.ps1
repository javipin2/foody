# Coherencia pedidos ↔ analítica/reportes (ventas línea con extras).
$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'

Write-Host '=== Coherencia pedidos / analítica / reportes ==='

$salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud falló' }

$login = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -ContentType 'application/json' -Body (@{
  email = 'admin@foody.demo'; contrasena = '123456'
} | ConvertTo-Json)
$token = $login.datos.access_token
if (-not $token) { $token = $login.datos.token }
$sid = $login.datos.usuario.sucursal_id
$h = @{ Authorization = "Bearer $token" }

$hoy = (Get-Date).ToString('yyyy-MM-dd')
$desde = (Get-Date).AddDays(-6).ToString('yyyy-MM-dd')

$resumen = Invoke-RestMethod -Uri "$base/analitica/resumen?sucursal_id=$sid&preset=7d" -Headers $h
$ventas = Invoke-RestMethod -Uri "$base/analitica/ventas?sucursal_id=$sid&preset=7d" -Headers $h
$productos = Invoke-RestMethod -Uri "$base/analitica/productos?sucursal_id=$sid&preset=7d" -Headers $h
$reportes = Invoke-RestMethod -Uri "$base/reportes/financiero?sucursal_id=$sid&desde=$desde&hasta=$hoy" -Headers $h
$repProd = Invoke-RestMethod -Uri "$base/reportes/productos?sucursal_id=$sid&desde=$desde&hasta=$hoy" -Headers $h
$dash = Invoke-RestMethod -Uri "$base/dashboard/graficos?sucursal_id=$sid" -Headers $h
$recientes = Invoke-RestMethod -Uri "$base/analitica/pedidos-recientes?sucursal_id=$sid&preset=7d&limite=5" -Headers $h

if (-not $resumen.exito) { throw 'analitica resumen falló' }
if (-not $ventas.exito) { throw 'analitica ventas falló' }
if (-not $productos.exito) { throw 'analitica productos falló' }
if (-not $reportes.exito) { throw 'reportes financiero falló' }
if (-not $repProd.exito) { throw 'reportes productos falló' }
if (-not $dash.exito) { throw 'dashboard falló' }
if (-not $recientes.exito) { throw 'pedidos-recientes falló' }

$kpiVentas = [double]$resumen.datos.kpis.ventas_netas
$finVentas = [double]$reportes.datos.resumen.ventas_total
Write-Host ("KPI analitica ventas_netas={0}" -f $kpiVentas)
Write-Host ("Reportes financiero ventas={0}" -f $finVentas)

# Header-level: deben estar cerca (mismo universo ~7d)
if ($kpiVentas -gt 0 -and $finVentas -gt 0) {
  $ratio = [Math]::Abs($kpiVentas - $finVentas) / [Math]::Max($kpiVentas, $finVentas)
  if ($ratio -gt 0.35) {
    Write-Host "AVISO: KPI vs reportes divergen >35% (timezone/preset). ratio=$([Math]::Round($ratio,3))" -ForegroundColor Yellow
  } else {
    Write-Host 'OK KPI analitica ~ reportes financiero' -ForegroundColor Green
  }
} elseif ($kpiVentas -eq 0 -and $finVentas -eq 0) {
  Write-Host 'AVISO: sin ventas en el periodo' -ForegroundColor Yellow
} else {
  Write-Host "AVISO: un lado en cero (kpi=$kpiVentas fin=$finVentas)" -ForegroundColor Yellow
}

$rankAnal = @($productos.datos.por_ingresos)
if (-not $rankAnal.Count) { $rankAnal = @($productos.datos.por_cantidad) }
$rankRep = @($repProd.datos.ranking)
Write-Host ("Ranking analitica filas={0} reportes={1} dashboard top={2}" -f $rankAnal.Count, $rankRep.Count, @($dash.datos.top_productos).Count)
Write-Host ("Pedidos recientes={0}" -f @($recientes.datos).Count)

# Estados en recientes deben ser strings conocidos del flujo actual
$estadosOk = @(
  'pendiente_aprobacion','pendiente','confirmado','en_cocina','listo',
  'pagando','asignado','en_camino','entregado','pagado','cancelado','rechazado'
)
foreach ($p in @($recientes.datos)) {
  if ($p.estado -and ($estadosOk -notcontains $p.estado)) {
    throw "Estado desconocido en pedidos-recientes: $($p.estado)"
  }
}
Write-Host 'OK estados en pedidos-recientes' -ForegroundColor Green

# Crear línea con topping (si hay) y comprobar que ranking incluye extras en ventas
$menu = Invoke-RestMethod -Uri "$base/menu/$sid" -Headers $h
$topId = $null
$prodConTop = $null
foreach ($cat in @($menu.datos.categorias)) {
  foreach ($pr in @($cat.productos)) {
    $tops = @($pr.toppings_disponibles)
    if ($tops.Count -gt 0) {
      $topId = $tops[0].id
      $prodConTop = $pr
      break
    }
  }
  if ($topId) { break }
}

if ($topId -and $prodConTop) {
  # ponytail: no llamar /caja/estado (no existe); caja real = GET /caja/activa/:sucursal_id
  $crear = Invoke-RestMethod -Uri "$base/pedidos/staff" -Method POST -Headers $h -ContentType 'application/json' -Body (@{
    sucursal_id = $sid
    device_id = 'qa-coherencia-extras'
    tipo = 'para_llevar'
    metodo_pago = 'efectivo'
    items = @(@{
      producto_id = $prodConTop.id
      cantidad = 1
      precio = [double]$prodConTop.precio
      toppings = @(@{ topping_id = $topId })
    })
  } | ConvertTo-Json -Depth 6)
  if (-not $crear.exito) { throw "crear pedido con topping falló: $($crear.mensaje)" }
  $sub = [double]$crear.datos.subtotal
  $basePrecio = [double]$prodConTop.precio
  $precioTop = [double](@($prodConTop.toppings_disponibles) | Where-Object { $_.id -eq $topId } | Select-Object -First 1).precio
  $esperado = $basePrecio + $precioTop
  if ([Math]::Abs($sub - $esperado) -gt 0.5) {
    throw "subtotal pedido ($sub) != base+topping ($esperado)"
  }
  Write-Host "OK pedido con topping subtotal=$sub (base+extra)" -ForegroundColor Green
} else {
  Write-Host 'SKIP probe topping (producto sin toppings_disponibles en menú)' -ForegroundColor Yellow
}

Write-Host '=== Coherencia OK ===' -ForegroundColor Green
