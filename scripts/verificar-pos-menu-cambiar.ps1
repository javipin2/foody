# Verificar menú POS completo + cambiar producto (agregar→quitar).
$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'

Write-Host '=== Verificar POS menú / cambiar producto ==='

$salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud falló' }
Write-Host 'OK salud' -ForegroundColor Green

$login = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -ContentType 'application/json' -Body (@{
  email = 'admin@foody.demo'
  contrasena = '123456'
} | ConvertTo-Json) -TimeoutSec 15
$token = $login.datos.access_token
if (-not $token) { $token = $login.datos.token }
if (-not $token) { throw 'Sin token' }
$sid = $login.datos.usuario.sucursal_id
if (-not $sid) { $sid = $login.datos.sucursal_id }
$h = @{ Authorization = "Bearer $token" }

$menu = Invoke-RestMethod -Uri "$base/menu/$sid" -Headers $h -TimeoutSec 20
if (-not $menu.exito) { throw 'Menu falló' }
$cats = @($menu.datos.categorias)
$bebCat = $cats | Where-Object { $_.nombre -match 'Bebida' } | Select-Object -First 1
$prodsBeb = @()
if ($bebCat) { $prodsBeb = @($bebCat.productos) }
Write-Host ("Categorías: {0}" -f $cats.Count)
Write-Host ("Bebidas categoría productos: {0}" -f $prodsBeb.Count)

# Si falta producto bebida, crearlo vía API (idempotente por nombre)
if ($prodsBeb.Count -eq 0 -and $bebCat) {
  Write-Host 'Creando producto Gaseosa 400ml en categoría Bebidas...' -ForegroundColor Yellow
  $cocinas = Invoke-RestMethod -Uri "$base/cocinas/$sid" -Headers $h -TimeoutSec 15
  $cocinaId = @($cocinas.datos)[0].id
  $crear = Invoke-RestMethod -Uri "$base/productos" -Method POST -Headers $h -ContentType 'application/json' -Body (@{
    sucursal_id = $sid
    categoria_id = $bebCat.id
    cocina_id = $cocinaId
    nombre = 'Gaseosa 400ml'
    descripcion = 'Bebida lista para vender sola o en combo'
    precio = 4000
  } | ConvertTo-Json) -TimeoutSec 20
  if (-not $crear.exito) { throw "Crear producto bebida falló: $($crear.mensaje)" }
  $menu = Invoke-RestMethod -Uri "$base/menu/$sid" -Headers $h -TimeoutSec 20
  $bebCat = @($menu.datos.categorias) | Where-Object { $_.nombre -match 'Bebida' } | Select-Object -First 1
  $prodsBeb = @($bebCat.productos)
}
if ($prodsBeb.Count -lt 1) { throw 'Categoría Bebidas sigue sin productos' }
Write-Host 'OK menú tiene bebidas vendibles' -ForegroundColor Green

$combos = @($menu.datos.combos)
Write-Host ("Combos: {0}" -f $combos.Count)
if ($combos.Count -gt 0) {
  $c0 = $combos[0]
  $tipos = @($c0.items | ForEach-Object { $_.tipo_item })
  Write-Host ("Combo demo items tipos: {0}" -f ($tipos -join ','))
}

# Pedido activo con 1+ ítems → agregar producto → quitar el primero (simula cambiar)
$activos = Invoke-RestMethod -Uri "$base/pedidos?sucursal_id=$sid&solo_activos=true" -Headers $h -TimeoutSec 20
$lista = @($activos.datos)
$pedido = $null
foreach ($p in $lista) {
  $items = @($p.items_resumen)
  if ($items.Count -ge 1 -and $items[0].item_id) { $pedido = $p; break }
}
if (-not $pedido) { throw 'No hay pedido activo con items_resumen' }

$itemViejo = @($pedido.items_resumen)[0]
$prodNuevo = $prodsBeb[0]
Write-Host ("Cambiando item {0} → {1}" -f $itemViejo.item_id, $prodNuevo.nombre)

$add = Invoke-RestMethod -Uri "$base/pedidos/$($pedido.id)/items?sucursal_id=$sid" -Method POST -Headers $h -ContentType 'application/json' -Body (@{
  items = @(@{
    producto_id = $prodNuevo.id
    cantidad = 1
    precio = [double]$prodNuevo.precio
  })
} | ConvertTo-Json -Depth 5) -TimeoutSec 20
if (-not $add.exito) { throw "Agregar item falló: $($add.mensaje)" }
Write-Host 'OK agregar producto nuevo' -ForegroundColor Green

$del = Invoke-RestMethod -Uri "$base/pedidos/$($pedido.id)/items/$($itemViejo.item_id)?sucursal_id=$sid" -Method DELETE -Headers $h -ContentType 'application/json' -Body (@{ motivo = 'Cambio de producto' } | ConvertTo-Json) -TimeoutSec 20
if (-not $del.exito) { throw "Eliminar item viejo falló: $($del.mensaje)" }
Write-Host 'OK quitar producto anterior (cambiar producto)' -ForegroundColor Green

# Combo con topping extra (si hay combo)
if ($combos.Count -gt 0) {
  $topId = $null
  foreach ($cat in @($menu.datos.categorias)) {
    foreach ($pr in @($cat.productos)) {
      $tops = @($pr.toppings_disponibles)
      if ($tops.Count -gt 0) { $topId = $tops[0].id; break }
    }
    if ($topId) { break }
  }
  if ($topId) {
    $addCombo = Invoke-RestMethod -Uri "$base/pedidos/$($pedido.id)/items?sucursal_id=$sid" -Method POST -Headers $h -ContentType 'application/json' -Body (@{
      combos = @(@{
        combo_id = $combos[0].id
        cantidad = 1
        precio = [double]$combos[0].precio_fijo
        toppings = @(@{ topping_id = $topId })
      })
    } | ConvertTo-Json -Depth 6) -TimeoutSec 20
    if (-not $addCombo.exito) { throw "Combo+topping falló: $($addCombo.mensaje)" }
    Write-Host 'OK combo con topping extra' -ForegroundColor Green
  } else {
    Write-Host 'SKIP combo+topping (sin toppings en menú)' -ForegroundColor Yellow
  }
}

Write-Host '=== TODO OK ===' -ForegroundColor Green
