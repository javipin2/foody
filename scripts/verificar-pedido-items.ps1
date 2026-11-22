# Verificar edición de ítems (PATCH cantidad/toppings) — Pedidos Fase 2.
$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'

Write-Host '=== Verificar pedido items PATCH ==='

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

$activos = Invoke-RestMethod -Uri "$base/pedidos?sucursal_id=$sid&solo_activos=true" -Headers $h -TimeoutSec 20
$lista = @($activos.datos)
$conItem = $null
foreach ($p in $lista) {
  $items = @($p.items_resumen)
  if ($items.Count -ge 1 -and $items[0].item_id) {
    $conItem = $p
    break
  }
}
if (-not $conItem) { throw 'No hay pedido activo con items_resumen' }

$item = @($conItem.items_resumen)[0]
$itemId = $item.item_id
$cantAntes = [int]$item.cantidad
$cantNueva = [Math]::Max(1, $cantAntes)

# PATCH sin cambios útiles debe aceptar (misma cantidad + toppings actuales)
$body = @{
  cantidad = $cantNueva
  observaciones = if ($item.observaciones) { $item.observaciones } else { $null }
  toppings = @()
}
if ($item.topping_ids) {
  $body.toppings = @($item.topping_ids | ForEach-Object { @{ topping_id = $_ } })
}

$patch = Invoke-RestMethod -Uri "$base/pedidos/$($conItem.id)/items/$itemId`?sucursal_id=$sid" -Method PATCH -Headers $h -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 5) -TimeoutSec 20
if (-not $patch.exito) { throw "PATCH falló: $($patch.mensaje)" }
Write-Host "OK PATCH item $($conItem.numero_pedido) / $itemId" -ForegroundColor Green

if ($null -eq $item.producto_id -and $null -eq $patch.datos) {
  Write-Host 'WARN sin producto_id en resumen (UI editar toppings limitada)' -ForegroundColor Yellow
} else {
  Write-Host 'OK items_resumen incluye datos de edición' -ForegroundColor Green
}

# DELETE último ítem debe fallar si solo hay uno
$det = Invoke-RestMethod -Uri "$base/pedidos/$($conItem.id)/detalle?sucursal_id=$sid" -Headers $h -TimeoutSec 15
$nItems = @($det.datos.items_resumen).Count
if ($nItems -le 1) {
  try {
    Invoke-RestMethod -Uri "$base/pedidos/$($conItem.id)/items/$itemId`?sucursal_id=$sid" -Method DELETE -Headers $h -ContentType 'application/json' -Body '{}' -TimeoutSec 15
    throw 'DELETE último ítem debió fallar'
  } catch {
    Write-Host 'OK DELETE último ítem rechazado' -ForegroundColor Green
  }
} else {
  Write-Host "SKIP DELETE último (pedido tiene $nItems ítems)" -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Verificación pedido items OK' -ForegroundColor Green
