# X-005: prueba de carga básica — N pedidos QR simultáneos contra POST /pedidos
# Uso: .\scripts\verificar-carga-qr.ps1 [-Pedidos 20] [-SucursalId <uuid>] [-MesaQrToken <token>]

param(
  [int]$Pedidos = 20,
  [string]$SucursalId = '',
  [string]$MesaQrToken = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\qa-helpers.ps1')
$base = $script:FoodyQaBase

function Get-Seed {
  $menu = Invoke-RestMethod -Uri "$base/menu/$($script:SucursalId)" -TimeoutSec 15
  if (-not $menu.exito) { throw $menu.mensaje }
  $prod = $menu.datos.categorias |
    ForEach-Object { $_.productos } |
    Where-Object { $_.disponible -eq $true } |
    Select-Object -First 1
  if (-not $prod) { throw 'Sin productos disponibles en menú seed' }
  return $prod
}

function Get-Mesa {
  if ($MesaQrToken) {
    $r = Invoke-RestMethod -Uri "$base/mesas/qr/$MesaQrToken" -TimeoutSec 10
    if (-not $r.exito) { throw $r.mensaje }
    return $r.datos
  }
  # ponytail: mesa demo seed (012_seed_demo.sql)
  return @{
    id     = '30000000-0000-4000-8000-000000000001'
    nombre = 'Mesa 1'
  }
}

Write-Host "=== Carga QR ($Pedidos pedidos) ===" -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }

if (-not $SucursalId) {
  $SucursalId = $script:FoodyQaSucursal
  Write-Host "Sucursal seed: $SucursalId" -ForegroundColor Gray
}
$script:SucursalId = $SucursalId

$mesa = Get-Mesa
$prod = Get-Seed
Write-Host "Mesa: $($mesa.nombre) | Producto: $($prod.nombre)" -ForegroundColor Gray

$postUri = "$base/pedidos"
$jobs = @()
$sw = [System.Diagnostics.Stopwatch]::StartNew()

for ($i = 1; $i -le $Pedidos; $i++) {
  $deviceId = "loadtest-qr-$i-$(Get-Random)"
  $body = @{
    sucursal_id = $SucursalId
    mesa_id     = $mesa.id
    device_id   = $deviceId
    tipo        = 'mesa'
    metodo_pago = 'pendiente'
    items       = @(
      @{
        producto_id = $prod.id
        cantidad    = 1
        precio      = [decimal]$prod.precio
      }
    )
    idempotency_key = [guid]::NewGuid().ToString()
  } | ConvertTo-Json -Depth 5

  $jobs += Start-Job -ScriptBlock {
    param($Uri, $Json)
    try {
      $r = Invoke-RestMethod -Uri $Uri -Method POST -Body $Json -ContentType 'application/json' -TimeoutSec 30
      return @{ ok = $r.exito; estado = $r.datos.estado; id = $r.datos.pedido_id }
    } catch {
      return @{ ok = $false; error = $_.Exception.Message }
    }
  } -ArgumentList $postUri, $body
}

$results = $jobs | Wait-Job | Receive-Job
$jobs | Remove-Job -Force
$sw.Stop()

$ok = @($results | Where-Object { $_.ok }).Count
$fail = $Pedidos - $ok
Write-Host ""
Write-Host "Completados: $ok / $Pedidos en $($sw.ElapsedMilliseconds) ms" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Yellow' })
if ($fail -gt 0) {
  $results | Where-Object { -not $_.ok } | Select-Object -First 3 | ForEach-Object {
    Write-Host "  Error: $($_.error)" -ForegroundColor Red
  }
}
Write-Host "Estados: $(($results | Group-Object estado | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ', ')" -ForegroundColor Gray

if ($ok -lt [math]::Floor($Pedidos * 0.9)) {
  throw "Menos del 90% exitoso - revisar API/BD"
}
Write-Host "Carga QR OK" -ForegroundColor Green
