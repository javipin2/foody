# Verifica control financiero: costos fijos, nomina, P&L, 403 cajero, gasto manual no toca caja.
# Uso: .\scripts\verificar-finanzas.ps1
# Requiere: API :3000, migracion 080 aplicada, demo admin@foody.demo / cajero.

$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'

function Login-Staff {
  param([string]$Email, [string]$Pass = '123456')
  $body = @{ email = $Email; contrasena = $Pass } | ConvertTo-Json
  $r = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -Body $body -ContentType 'application/json'
  if (-not $r.exito) { throw $r.mensaje }
  return $r.datos
}

function Invoke-ApiJson {
  param(
    [string]$Method,
    [string]$Url,
    [hashtable]$Headers,
    [object]$Body = $null,
    [int[]]$OkCodes = @(200)
  )
  $params = @{
    Uri             = $Url
    Headers         = $Headers
    Method          = $Method
    UseBasicParsing = $true
    TimeoutSec      = 20
  }
  if ($null -ne $Body) {
    $params.Body = ($Body | ConvertTo-Json -Depth 6)
    $params.ContentType = 'application/json'
  }
  try {
    $resp = Invoke-WebRequest @params
    $code = [int]$resp.StatusCode
    if ($OkCodes -notcontains $code) {
      throw "Status inesperado $code en $Url"
    }
    $json = $null
    if ($resp.Content) {
      $json = $resp.Content | ConvertFrom-Json
    }
    return @{ code = $code; json = $json }
  } catch {
    if ($_.Exception.Response) {
      $code = [int]$_.Exception.Response.StatusCode
      if ($OkCodes -contains $code) {
        return @{ code = $code; json = $null }
      }
    }
    throw $_
  }
}

Write-Host '=== Verificar finanzas (control + rentabilidad) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }
Write-Host 'OK salud' -ForegroundColor Green

$col = (docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='gastos' AND column_name='origen'" 2>&1).ToString().Trim()
if ($col -ne '1') {
  Write-Host 'Aplicando migracion 080_finanzas_control.sql...' -ForegroundColor Yellow
  & "$PSScriptRoot\aplicar-migracion-supabase.ps1" 080_finanzas_control.sql
}

$admin = Login-Staff 'admin@foody.demo'
$hAdmin = @{ Authorization = "Bearer $($admin.token)" }
$sid = $admin.usuario.sucursal_id
if (-not $sid) { throw 'Admin sin sucursal_id' }

$cajaAntes = Invoke-RestMethod -Uri "$base/caja/activa/$sid" -Headers $hAdmin -TimeoutSec 10
$saldoAntes = $null
$cajaAbierta = $false
if ($cajaAntes.exito -and $cajaAntes.datos -and $cajaAntes.datos.id) {
  $cajaAbierta = $true
  $saldoAntes = [double]$cajaAntes.datos.saldo_sistema
  Write-Host "Caja abierta, saldo_sistema=$saldoAntes" -ForegroundColor DarkGray
} else {
  $abrir = Invoke-ApiJson -Method POST -Url "$base/caja/abrir" -Headers $hAdmin -Body @{
    sucursal_id   = $sid
    monto_inicial = 100000
  } -OkCodes @(200, 201)
  if ($abrir.json.exito -and $abrir.json.datos.id) {
    $cajaAbierta = $true
    $cajaAntes = $abrir.json
    $saldoAntes = [double]$abrir.json.datos.saldo_sistema
    Write-Host "OK abri caja para prueba arqueo, saldo=$saldoAntes" -ForegroundColor DarkGray
  }
}

$conceptoFijo = "QA-Arriendo-$(Get-Random -Maximum 99999)"
$r = Invoke-ApiJson -Method POST -Url "$base/finanzas/costos-fijos" -Headers $hAdmin -Body @{
  sucursal_id   = $sid
  concepto      = $conceptoFijo
  monto_mensual = 1500000
  categoria     = 'arriendo'
} -OkCodes @(200, 201)
if (-not $r.json.exito) { throw "Crear costo fijo fallo: $($r.json.mensaje)" }
$fijoId = $r.json.datos.id
Write-Host "OK crear costo fijo $fijoId" -ForegroundColor Green

$r = Invoke-ApiJson -Method POST -Url "$base/finanzas/costos-fijos/$fijoId/pagar?sucursal_id=$sid" -Headers $hAdmin -Body @{
  monto = 1500000
} -OkCodes @(200, 201)
if (-not $r.json.exito) { throw "Pagar fijo fallo: $($r.json.mensaje)" }
if ($r.json.datos.origen -ne 'fijo') { throw 'origen esperado fijo' }
Write-Host 'OK pagar costo fijo (origen=fijo, sin caja_id)' -ForegroundColor Green

$nombreEmp = "QA-Juan-$(Get-Random -Maximum 99999)"
$r = Invoke-ApiJson -Method POST -Url "$base/finanzas/empleados" -Headers $hAdmin -Body @{
  sucursal_id     = $sid
  nombre          = $nombreEmp
  cargo           = 'mesero'
  sueldo_base     = 800000
  frecuencia_pago = 'quincenal'
} -OkCodes @(200, 201)
if (-not $r.json.exito) { throw "Crear empleado fallo: $($r.json.mensaje)" }
$empId = $r.json.datos.id
Write-Host "OK crear empleado $empId" -ForegroundColor Green

$r = Invoke-ApiJson -Method POST -Url "$base/finanzas/empleados/$empId/pagar?sucursal_id=$sid" -Headers $hAdmin -Body @{
  monto = 800000
} -OkCodes @(200, 201)
if (-not $r.json.exito) { throw "Pagar empleado fallo: $($r.json.mensaje)" }
if ($r.json.datos.origen -ne 'nomina') { throw 'origen esperado nomina' }
Write-Host 'OK pagar empleado (origen=nomina)' -ForegroundColor Green

$r = Invoke-ApiJson -Method POST -Url "$base/finanzas/gastos" -Headers $hAdmin -Body @{
  sucursal_id = $sid
  concepto    = "QA-Transferencia-$(Get-Random -Maximum 99999)"
  monto       = 50000
  categoria   = 'otros'
} -OkCodes @(200, 201)
if (-not $r.json.exito) { throw "Gasto manual fallo: $($r.json.mensaje)" }
if ($r.json.datos.origen -ne 'manual') { throw 'origen esperado manual' }
Write-Host 'OK gasto manual' -ForegroundColor Green

if ($cajaAbierta) {
  $cajaDespues = Invoke-RestMethod -Uri "$base/caja/activa/$sid" -Headers $hAdmin -TimeoutSec 10
  $saldoDespues = [double]$cajaDespues.datos.saldo_sistema
  if ($saldoDespues -ne $saldoAntes) {
    throw "FAIL: gasto manual altero saldo_sistema ($saldoAntes -> $saldoDespues)"
  }
  Write-Host "OK saldo_sistema intacto tras gasto manual ($saldoDespues)" -ForegroundColor Green
} else {
  Write-Host 'AVISO: sin caja abierta - no se verifico arqueo' -ForegroundColor Yellow
}

$rentUrl = "$base/analitica/rentabilidad?sucursal_id=$sid" + '&preset=mes'
$rent = Invoke-RestMethod -Uri $rentUrl -Headers $hAdmin -TimeoutSec 30
if (-not $rent.exito) { throw "Rentabilidad fallo: $($rent.mensaje)" }
$d = $rent.datos
$esperadoNeta = [math]::Round([double]$d.utilidad_bruta - [double]$d.total_gastos, 2)
$neta = [math]::Round([double]$d.utilidad_neta, 2)
if ([math]::Abs($esperadoNeta - $neta) -gt 0.02) {
  throw "FAIL: utilidad_neta=$neta no cuadra con bruta-gastos=$esperadoNeta"
}
Write-Host "OK rentabilidad: ventas=$($d.ventas_netas) cogs=$($d.costo_ventas) gastos=$($d.total_gastos) neta=$neta es_rentable=$($d.es_rentable)" -ForegroundColor Green
if (-not $d.consejos) { throw 'FAIL: rentabilidad sin consejos' }
Write-Host "OK consejos rentabilidad ($($d.consejos.Count))" -ForegroundColor Green

$hoy = Get-Date -Format 'yyyy-MM-dd'
$desde = Get-Date -Format 'yyyy-MM-01'

$resumen = Invoke-RestMethod -Uri "$base/finanzas/resumen/$sid" -Headers $hAdmin -TimeoutSec 30
if (-not $resumen.exito) { throw "Resumen finanzas fallo: $($resumen.mensaje)" }
$rd = $resumen.datos
if ($null -eq $rd.mes_actual) { throw 'FAIL: resumen sin mes_actual' }
if ($null -eq $rd.pendientes) { throw 'FAIL: resumen sin pendientes' }
if (-not $rd.consejos) { throw 'FAIL: resumen sin consejos' }
Write-Host "OK resumen: neta=$($rd.mes_actual.utilidad_neta) pend=$($rd.pendientes.cantidad) delta=$($rd.delta_utilidad_pct)%" -ForegroundColor Green

# Pago con monto editable
$r = Invoke-ApiJson -Method POST -Url "$base/finanzas/costos-fijos/$fijoId/pagar?sucursal_id=$sid" -Headers $hAdmin -Body @{
  monto = 50000
  periodo_desde = $desde
  periodo_hasta = $hoy
} -OkCodes @(200, 201)
if (-not $r.json.exito) { throw "Pagar monto editable fallo: $($r.json.mensaje)" }
if ([double]$r.json.datos.monto -ne 50000) { throw 'FAIL: monto editable no aplicado' }
Write-Host 'OK pagar fijo con monto editable + periodo' -ForegroundColor Green

$libroUrl = "$base/finanzas/gastos/${sid}?desde=$desde" + '&hasta=' + $hoy
$libro = Invoke-RestMethod -Uri $libroUrl -Headers $hAdmin
if (-not $libro.exito) { throw $libro.mensaje }
$n = @($libro.datos).Count
if ($n -lt 3) { throw "Libro de egresos demasiado corto ($n)" }
Write-Host "OK libro egresos ($n) filas" -ForegroundColor Green

$cajeroEmails = @('cajero.test@foody.demo', 'mesero@foody.com')
$cajero = $null
foreach ($em in $cajeroEmails) {
  try {
    $cajero = Login-Staff $em
    break
  } catch {
    $cajero = $null
  }
}
if (-not $cajero) { throw 'No se pudo login rol sin ver_finanzas (cajero/mesero)' }
$hCajero = @{ Authorization = "Bearer $($cajero.token)" }
$code = (Invoke-ApiJson -Method GET -Url "$base/finanzas/empleados/$sid" -Headers $hCajero -OkCodes @(403)).code
Write-Host "OK cajero bloqueado en finanzas ($code)" -ForegroundColor Green

$rentCajeroUrl = "$base/analitica/rentabilidad?sucursal_id=$sid" + '&preset=mes'
$code = (Invoke-ApiJson -Method GET -Url $rentCajeroUrl -Headers $hCajero -OkCodes @(403)).code
Write-Host "OK cajero bloqueado en rentabilidad ($code)" -ForegroundColor Green

$null = Invoke-ApiJson -Method DELETE -Url "$base/finanzas/costos-fijos/${fijoId}?sucursal_id=$sid" -Headers $hAdmin -OkCodes @(200)
$null = Invoke-ApiJson -Method PATCH -Url "$base/finanzas/empleados/${empId}?sucursal_id=$sid" -Headers $hAdmin -Body @{ activo = $false } -OkCodes @(200)

Write-Host ''
Write-Host 'Verificacion finanzas OK' -ForegroundColor Green
exit 0
