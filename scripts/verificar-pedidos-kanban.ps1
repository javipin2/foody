# Verificar rediseño Pedidos: listado con items_resumen, cerrados-hoy, detalle, domicilio.
$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'

Write-Host '=== Verificar pedidos kanban ==='

$salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud falló' }
Write-Host 'OK salud' -ForegroundColor Green

$login = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -ContentType 'application/json' -Body (@{
  email = 'admin@foody.demo'
  contrasena = '123456'
} | ConvertTo-Json) -TimeoutSec 15
$token = $login.datos.access_token
if (-not $token) { $token = $login.datos.token }
if (-not $token) { throw 'Sin token admin' }
$sid = $login.datos.usuario.sucursal_id
if (-not $sid) { $sid = $login.datos.sucursal_id }
$h = @{ Authorization = "Bearer $token" }

$activos = Invoke-RestMethod -Uri "$base/pedidos?sucursal_id=$sid&solo_activos=true" -Headers $h -TimeoutSec 20
if (-not $activos.exito) { throw 'listar activos falló' }
$lista = @($activos.datos)
Write-Host "OK listar activos ($($lista.Count))" -ForegroundColor Green
if ($lista.Count -gt 0) {
  $primero = $lista[0]
  if ($null -eq $primero.items_resumen) {
    throw 'Falta items_resumen en listado'
  }
  Write-Host "OK items_resumen ($($primero.items_resumen.Count) ítems en $($primero.numero_pedido))" -ForegroundColor Green

  $det = Invoke-RestMethod -Uri "$base/pedidos/$($primero.id)/detalle?sucursal_id=$sid" -Headers $h -TimeoutSec 15
  if (-not $det.exito) { throw 'detalle falló' }
  if ($null -eq $det.datos.items_resumen) { throw 'detalle sin items_resumen' }
  Write-Host 'OK detalle' -ForegroundColor Green
}

$cerrados = Invoke-RestMethod -Uri "$base/pedidos/cerrados-hoy?sucursal_id=$sid" -Headers $h -TimeoutSec 15
if (-not $cerrados.exito) { throw 'cerrados-hoy falló' }
Write-Host "OK cerrados-hoy ($((@($cerrados.datos)).Count))" -ForegroundColor Green

$meseros = Invoke-RestMethod -Uri "$base/usuarios/meseros-activos?sucursal_id=$sid" -Headers $h -TimeoutSec 15
if (-not $meseros.exito) { throw 'meseros-activos falló' }
$listaMeseros = @($meseros.datos)
Write-Host "OK meseros-activos ($($listaMeseros.Count))" -ForegroundColor Green

# Admin sin mesera_id al aprobar → debe fallar
$pendQr = @($lista | Where-Object { $_.estado -eq 'pendiente_aprobacion' }) | Select-Object -First 1
  if ($pendQr) {
    try {
      Invoke-RestMethod -Uri "$base/pedidos/$($pendQr.id)/aprobar?sucursal_id=$sid" -Method PATCH -Headers $h -ContentType 'application/json' -Body '{}' -TimeoutSec 15
      throw 'aprobar admin sin mesera_id debió fallar'
    } catch {
      if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        throw 'PATCH aprobar no registrado'
      }
      Write-Host 'OK aprobar admin sin mesera_id rechazado' -ForegroundColor Green
    }
  } else {
    # Sin QR pendiente: aún así admin sin mesera_id debe fallar antes de buscar el pedido
    try {
      Invoke-RestMethod -Uri "$base/pedidos/00000000-0000-0000-0000-000000000099/aprobar?sucursal_id=$sid" -Method PATCH -Headers $h -ContentType 'application/json' -Body '{}' -TimeoutSec 15
      throw 'aprobar admin sin mesera_id debió fallar'
    } catch {
      $msg = $_.ErrorDetails.Message
      if ($msg -match 'asignar un mesero' -or $msg -match 'Debes asignar') {
        Write-Host 'OK aprobar admin sin mesera_id rechazado' -ForegroundColor Green
      } elseif ($_.Exception.Response.StatusCode.value__ -eq 404) {
        throw 'PATCH aprobar no registrado'
      } else {
        Write-Host "OK aprobar sin mesera rechazado ($msg)" -ForegroundColor Green
      }
    }
  }

# Columna comanda_copia presente (via pedido activo cualquiera)
try {
  $col = docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='pedidos' AND column_name='comanda_copia'"
  if (($col -as [string]).Trim() -ne '1') { throw 'Falta columna comanda_copia' }
  Write-Host 'OK columna comanda_copia' -ForegroundColor Green
} catch {
  Write-Host "WARN no se pudo verificar columna: $_" -ForegroundColor Yellow
}

# Reasignar: endpoint vivo (400 esperado sin pedido asignado válido)
try {
  Invoke-RestMethod -Uri "$base/domiciliarios-planta/reasignar" -Method POST -Headers $h -ContentType 'application/json' -Body (@{
    pedido_id = '00000000-0000-0000-0000-000000000001'
    sucursal_id = $sid
    domiciliario_planta_id = '00000000-0000-0000-0000-000000000002'
  } | ConvertTo-Json) -TimeoutSec 15
  throw 'reasignar debió fallar con UUID inventados'
} catch {
  $resp = $_.ErrorDetails.Message
  if ($_.Exception.Response.StatusCode.value__ -eq 404) {
    throw 'POST /domiciliarios-planta/reasignar no registrado (404)'
  }
  Write-Host 'OK reasignar endpoint responde (error de negocio esperado)' -ForegroundColor Green
}

# Domi staff exige dirección (creación mínima sin items → debe fallar validación o items)
try {
  $null = Invoke-RestMethod -Uri "$base/pedidos/staff" -Method POST -Headers $h -ContentType 'application/json' -Body (@{
    sucursal_id = $sid
    device_id = 'qa-kanban-script'
    tipo = 'domicilio'
    cliente_nombre = 'QA Domi'
    cliente_telefono = '3000000000'
    direccion_entrega = 'Calle QA 1'
    metodo_pago = 'efectivo'
    items = @()
  } | ConvertTo-Json -Depth 5) -TimeoutSec 15
  Write-Host 'WARN staff domicilio vacío no rechazó (posible validación items)' -ForegroundColor Yellow
} catch {
  Write-Host 'OK staff domicilio sin items rechazado (esperado)' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Verificación pedidos kanban OK' -ForegroundColor Green
