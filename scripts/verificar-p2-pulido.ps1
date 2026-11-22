# Verifica P2-18/19/20: copiar menú, cancelar traslado, config super-admin
# Uso: .\scripts\verificar-p2-pulido.ps1
# Requiere: API en :3000, Postgres/Supabase local, seed demo

$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'

function Login-Staff {
  param([string]$Email, [string]$Pass = '123456')
  $body = @{ email = $Email; contrasena = $Pass } | ConvertTo-Json
  $r = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -Body $body -ContentType 'application/json'
  if (-not $r.exito) { throw $r.mensaje }
  return $r.datos
}

function Invoke-Api {
  param(
    [string]$Method,
    [string]$Path,
    [hashtable]$Headers,
    $Body = $null
  )
  $params = @{
    Uri             = "$base$Path"
    Method          = $Method
    Headers         = $Headers
    UseBasicParsing = $true
    TimeoutSec      = 15
  }
  if ($null -ne $Body) {
    $params.Body = ($Body | ConvertTo-Json)
    $params.ContentType = 'application/json'
  }
  try {
    $resp = Invoke-WebRequest @params
    return @{ Code = [int]$resp.StatusCode; Raw = $resp.Content }
  } catch {
    if ($_.Exception.Response) {
      $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $raw = $reader.ReadToEnd()
      return @{
        Code = [int]$_.Exception.Response.StatusCode
        Raw  = $raw
      }
    }
    throw $_
  }
}

Write-Host "=== Verificar P2 pulido (menú / traslados / super config) ===" -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }
Write-Host "OK salud" -ForegroundColor Green

# --- Ruta cancelar debe existir (400/404 negocio, no 404 ruta) ---
$admin = Login-Staff 'admin@foody.demo'
$hAdmin = @{ Authorization = "Bearer $($admin.token)" }
$sidAdmin = $admin.usuario.sucursal_id

$probe = Invoke-Api -Method POST -Path '/inventario/traslados/00000000-0000-0000-0000-000000000099/cancelar' -Headers $hAdmin
if ($probe.Code -eq 404 -and $probe.Raw -match 'Ruta no encontrada|Cannot POST') {
  throw "Ruta POST /inventario/traslados/:id/cancelar NO registrada - reinicia backend con dist actual"
}
if ($probe.Code -notin 404, 400, 403) {
  throw "Cancelar traslado respondió $($probe.Code) inesperado: $($probe.Raw)"
}
Write-Host "OK ruta cancelar traslado registrada (HTTP $($probe.Code))" -ForegroundColor Green

# --- Copiar menú ---
$sucursales = Invoke-RestMethod -Uri "$base/sucursales/mi-restaurante" -Headers $hAdmin
$lista = @($sucursales.datos)
$origen = ($lista | Where-Object { $_.id -ne $sidAdmin } | Select-Object -First 1)
if (-not $origen) {
  Write-Host "AVISO: una sola sucursal demo - omitiendo copiar menu" -ForegroundColor Yellow
} else {
  $antes = Invoke-RestMethod -Uri "$base/productos/sucursal/$sidAdmin" -Headers $hAdmin
  $nAntes = @($antes.datos).Count
  $copia = Invoke-RestMethod -Uri "$base/categorias/sucursal/$sidAdmin/copiar-desde/$($origen.id)" -Method POST -Headers $hAdmin
  if (-not $copia.exito) { throw "Copiar menu fallo: $($copia.mensaje)" }
  $d = $copia.datos
  if ([int]$d.productos_nuevos -eq 0) {
    $copiaRev = Invoke-RestMethod -Uri "$base/categorias/sucursal/$($origen.id)/copiar-desde/$sidAdmin" -Method POST -Headers $hAdmin
    if ($copiaRev.exito -and [int]$copiaRev.datos.productos_nuevos -gt 0) {
      $d = $copiaRev.datos
      Write-Host "OK copiar menu (sentido inverso) productos_nuevos=$($d.productos_nuevos)" -ForegroundColor Green
    }
  }
  Write-Host "OK copiar menu origen=$($origen.nombre) productos_nuevos=$($d.productos_nuevos) categorias=$($d.categorias)" -ForegroundColor Green
  $despues = Invoke-RestMethod -Uri "$base/productos/sucursal/$sidAdmin" -Headers $hAdmin
  $nDespues = @($despues.datos).Count
  if ($nDespues -lt $nAntes) {
    throw "Productos destino bajaron ($nAntes a $nDespues)"
  }
  Write-Host "OK productos destino $nAntes a $nDespues" -ForegroundColor Green
}

# --- Traslado crear + cancelar + stock ---
$ingredientesOrigen = Invoke-RestMethod -Uri "$base/inventario/$sidAdmin" -Headers $hAdmin
$ingredientesDest = Invoke-RestMethod -Uri "$base/inventario/$($origen.id)" -Headers $hAdmin
$nombresDest = @{}
foreach ($i in @($ingredientesDest.datos)) {
  $nombresDest[("$($i.nombre)").ToLower()] = $true
}
$ins = @($ingredientesOrigen.datos) | Where-Object {
  $_.descontar_stock -ne $false -and
  [double]$_.stock_actual -ge 2 -and
  $nombresDest.ContainsKey(("$($_.nombre)").ToLower())
} | Select-Object -First 1
if (-not $ins -and $origen) {
  $nombreTest = "Verificacion P2 traslado"
  $payloadBase = @{
    nombre          = $nombreTest
    unidad_base     = 'kg'
    stock_actual    = 10
    stock_minimo    = 1
    precio_compra   = 1000
    peso_bruto      = 1
    peso_neto       = 1
    descontar_stock = $true
  }
  foreach ($sid in @($sidAdmin, $origen.id)) {
    $bodyIng = $payloadBase.Clone()
    $bodyIng.sucursal_id = $sid
    try {
      Invoke-RestMethod -Uri "$base/inventario" -Method POST -Headers $hAdmin -Body ($bodyIng | ConvertTo-Json) -ContentType 'application/json' | Out-Null
    } catch {
      # ya existe en sede
    }
  }
  $ingredientesOrigen = Invoke-RestMethod -Uri "$base/inventario/$sidAdmin" -Headers $hAdmin
  $ins = @($ingredientesOrigen.datos) | Where-Object {
    ("$($_.nombre)").ToLower() -eq $nombreTest.ToLower() -and [double]$_.stock_actual -ge 2
  } | Select-Object -First 1
}
if (-not $ins -or -not $origen) {
  Write-Host "AVISO: sin insumo con stock en ambas sedes - omitiendo flujo traslado/cancelar" -ForegroundColor Yellow
} else {
  $stockIni = [double]$ins.stock_actual
  $destinoId = $origen.id
  $bodyTraslado = @{
    sucursal_origen_id  = $sidAdmin
    sucursal_destino_id = $destinoId
    ingrediente_id      = $ins.id
    cantidad            = 1
    motivo              = 'verificacion-p2-pulido'
  }
  $crear = Invoke-RestMethod -Uri "$base/inventario/traslados" -Method POST -Headers $hAdmin -Body ($bodyTraslado | ConvertTo-Json) -ContentType 'application/json'
  if (-not $crear.exito) { throw "Crear traslado: $($crear.mensaje)" }
  $tid = $crear.datos.traslado_id
  Write-Host "OK traslado creado $tid" -ForegroundColor Green

  $traslados = Invoke-RestMethod -Uri "$base/inventario/traslados?sucursal_id=$sidAdmin" -Headers $hAdmin
  $fila = @($traslados.datos) | Where-Object { $_.id -eq $tid } | Select-Object -First 1
  if (-not $fila) { throw 'Traslado no aparece en listado' }
  if (-not $fila.usuario_nombre) {
    Write-Host "AVISO: usuario_nombre vacio en listado (revisar JOIN usuarios)" -ForegroundColor Yellow
  } else {
    Write-Host "OK listado traslados incluye usuario_nombre=$($fila.usuario_nombre)" -ForegroundColor Green
  }

  $stockTrasCrear = Invoke-RestMethod -Uri "$base/inventario/$sidAdmin" -Headers $hAdmin
  $ins2 = @($stockTrasCrear.datos) | Where-Object { $_.id -eq $ins.id } | Select-Object -First 1
  $stockMedio = [double]$ins2.stock_actual
  if ($stockMedio -gt ($stockIni - 0.99)) {
    throw "Stock no bajo tras crear traslado ($stockIni a $stockMedio)"
  }
  Write-Host "OK stock bajo tras envio ($stockIni a $stockMedio)" -ForegroundColor Green

  $cancel = Invoke-RestMethod -Uri "$base/inventario/traslados/$tid/cancelar" -Method POST -Headers $hAdmin
  if (-not $cancel.exito) { throw "Cancelar traslado: $($cancel.mensaje)" }
  if ($cancel.datos.estado -ne 'cancelado') { throw "Estado esperado cancelado, got $($cancel.datos.estado)" }
  Write-Host "OK traslado cancelado" -ForegroundColor Green

  $stockFinal = Invoke-RestMethod -Uri "$base/inventario/$sidAdmin" -Headers $hAdmin
  $ins3 = @($stockFinal.datos) | Where-Object { $_.id -eq $ins.id } | Select-Object -First 1
  $stockFin = [double]$ins3.stock_actual
  if ([math]::Abs($stockFin - $stockIni) -gt 0.01) {
    throw "Stock no restaurado tras cancelar ($stockIni a $stockFin)"
  }
  Write-Host "OK stock restaurado ($stockIni a $stockFin)" -ForegroundColor Green
}

# --- Super admin config ---
$super = Login-Staff 'super@foody.demo'
$hSuper = @{ Authorization = "Bearer $($super.token)" }
$configs = Invoke-RestMethod -Uri "$base/super/configuracion" -Headers $hSuper
if (-not $configs.exito -or -not $configs.datos) { throw 'GET super/configuracion falló' }
$clave = $configs.datos[0].clave
$valor = $configs.datos[0].valor
$patch = Invoke-RestMethod -Uri "$base/super/configuracion/$clave" -Method PATCH -Headers $hSuper -Body (@{ valor = $valor } | ConvertTo-Json) -ContentType 'application/json'
if (-not $patch.exito) { throw "PATCH super/configuracion: $($patch.mensaje)" }
Write-Host "OK PATCH super/configuracion/$clave" -ForegroundColor Green

Write-Host ""
Write-Host "Verificacion P2 pulido OK" -ForegroundColor Green
