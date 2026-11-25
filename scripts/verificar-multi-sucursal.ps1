# Verifica multi-sucursal Fase 2: scope zonas, alertas, traslados
# Uso: .\scripts\verificar-multi-sucursal.ps1

$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:3001/api/v1'

function Login-Staff {
  param([string]$Email, [string]$Pass = '123456')
  $body = @{ email = $Email; contrasena = $Pass } | ConvertTo-Json
  $r = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -Body $body -ContentType 'application/json'
  if (-not $r.exito) { throw $r.mensaje }
  return $r.datos
}

function Get-ExpectStatus {
  param(
    [string]$Url,
    [hashtable]$Headers,
    [string]$Method = 'GET',
    [int[]]$OkCodes = @(200)
  )
  try {
    $params = @{
      Uri             = $Url
      Headers         = $Headers
      Method          = $Method
      UseBasicParsing = $true
      TimeoutSec      = 8
    }
    $resp = Invoke-WebRequest @params
    $code = [int]$resp.StatusCode
    if ($OkCodes -contains $code) {
      return $code
    }
    throw "Status inesperado $code en $Url"
  } catch {
    if ($_.Exception.Response) {
      $code = [int]$_.Exception.Response.StatusCode
      if ($OkCodes -contains $code) { return $code }
    }
    throw $_
  }
}

Write-Host "=== Verificar multi-sucursal (zonas / alertas / traslados) ===" -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }
Write-Host "OK salud" -ForegroundColor Green

$admin = Login-Staff 'admin@foody.demo'
$hAdmin = @{ Authorization = "Bearer $($admin.token)" }
$sidAdmin = $admin.usuario.sucursal_id

$sucursales = Invoke-RestMethod -Uri "$base/sucursales/mi-restaurante" -Headers $hAdmin
$lista = @($sucursales.datos)
$otraSid = ($lista | Where-Object { $_.id -ne $sidAdmin } | Select-Object -First 1).id
if (-not $otraSid) { $otraSid = $sidAdmin }

# Admin: zonas propia sede
$code = Get-ExpectStatus -Url "$base/zonas/$sidAdmin" -Headers $hAdmin -OkCodes @(200)
Write-Host "OK admin GET zonas propia ($code)" -ForegroundColor Green

# Admin: alertas propia sede
$code = Get-ExpectStatus -Url "$base/alertas/$sidAdmin" -Headers $hAdmin -OkCodes @(200)
Write-Host "OK admin GET alertas propia ($code)" -ForegroundColor Green

# Admin: traslados inventario
$code = Get-ExpectStatus -Url "$base/inventario/traslados?sucursal_id=$sidAdmin" -Headers $hAdmin -OkCodes @(200)
Write-Host "OK admin GET traslados ($code)" -ForegroundColor Green

$mesero = Login-Staff 'mesero@foody.com'
$hMesero = @{ Authorization = "Bearer $($mesero.token)" }
$sidMesero = $mesero.usuario.sucursal_id

# Mesero: zonas propia sede
$code = Get-ExpectStatus -Url "$base/zonas/$sidMesero" -Headers $hMesero -OkCodes @(200, 403)
if ($code -eq 200) {
  Write-Host "OK mesero GET zonas propia ($code)" -ForegroundColor Green
} else {
  Write-Host "AVISO mesero sin permiso zonas ($code) - revisar permisos demo" -ForegroundColor Yellow
}

# Mesero: otra sede debe prohibir (403) si es distinta
if ($otraSid -ne $sidMesero) {
  $code = Get-ExpectStatus -Url "$base/zonas/$otraSid" -Headers $hMesero -OkCodes @(403)
  Write-Host "OK mesero bloqueado en otra sede zonas ($code)" -ForegroundColor Green

  $code = Get-ExpectStatus -Url "$base/alertas/$otraSid" -Headers $hMesero -OkCodes @(403)
  Write-Host "OK mesero bloqueado en otra sede alertas ($code)" -ForegroundColor Green
} else {
  Write-Host "AVISO demo con una sola sucursal - no se probo bloqueo cross-sede" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Verificacion multi-sucursal OK" -ForegroundColor Green
exit 0
