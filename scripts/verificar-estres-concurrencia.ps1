# Prompt 26 — Estres y concurrencia Foody
# Multi-tenant paralelo + races (pedido/inventario/caja) + sostenido vs pico.
# Uso:
#   .\scripts\verificar-estres-concurrencia.ps1
#   .\scripts\verificar-estres-concurrencia.ps1 -SkipLoad

param(
  [string]$BaseUrl = 'http://127.0.0.1:3000/api/v1',
  [string]$SucursalA = 'c0000000-0000-4000-8000-000000000001',
  [string]$SucursalB = 'c0000000-0000-4000-8000-000000000002',
  [switch]$SkipLoad
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\qa-helpers.ps1')
$script:FoodyQaBase = $BaseUrl
$script:FoodyQaSucursal = $SucursalA

$Fallos = 0
$Avisos = 0
$Hallazgos = New-Object System.Collections.Generic.List[string]

function Note([string]$Msg, [string]$Level = 'OK') {
  $color = switch ($Level) {
    'OK' { 'Green' }
    'AVISO' { 'Yellow'; $script:Avisos++ }
    'FALLO' { 'Red'; $script:Fallos++ }
    default { 'Gray' }
  }
  Write-Host "  [$Level] $Msg" -ForegroundColor $color
  $Hallazgos.Add("$Level|$Msg")
}

function Invoke-ParallelGet {
  param([string[]]$Urls, [hashtable]$Headers = @{}, [int]$PoolSize = 20)
  $pool = [RunspaceFactory]::CreateRunspacePool(1, [Math]::Min($PoolSize, $Urls.Count))
  $pool.Open()
  $pipes = @()
  foreach ($u in $Urls) {
    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript({
        param($Url, $H)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
          $p = @{ Uri = $Url; TimeoutSec = 45; UseBasicParsing = $true }
          if ($H.Count) { $p.Headers = $H }
          $r = Invoke-WebRequest @p
          $sw.Stop()
          return @{ ok = $true; status = [int]$r.StatusCode; ms = $sw.ElapsedMilliseconds }
        }
        catch {
          $sw.Stop()
          $st = 0
          if ($_.Exception.Response) { $st = [int]$_.Exception.Response.StatusCode }
          return @{ ok = $false; status = $st; ms = $sw.ElapsedMilliseconds }
        }
      }).AddArgument($u).AddArgument($Headers)
    $pipes += @{ ps = $ps; h = $ps.BeginInvoke() }
  }
  $out = foreach ($p in $pipes) {
    $r = $p.ps.EndInvoke($p.h)
    $p.ps.Dispose()
    $r
  }
  $pool.Close(); $pool.Dispose()
  return $out
}

Write-Host '=== Foody ESTRES / CONCURRENCIA (Prompt 26) ===' -ForegroundColor Cyan
$salud = Invoke-FoodyApi -Path '/salud'
if (-not ($salud.ok -and $salud.json.exito)) { throw 'API caida' }
Note 'API /salud OK'

$admin = Get-FoodyToken 'admin@foody.demo'
$hA = $admin.headers

# Producto seed para pedidos
$menu = Invoke-RestMethod -Uri "$BaseUrl/menu/$SucursalA" -TimeoutSec 20
$prod = $menu.datos.categorias | ForEach-Object { $_.productos } | Where-Object { $_.disponible } | Select-Object -First 1
if (-not $prod) { throw 'Sin producto demo' }
$prodId = $prod.id
$prodPrecio = [decimal]$prod.precio
Note "Producto race: $($prod.nombre) ($prodId)"

# ---------------------------------------------------------------------------
# A) Multi-restaurante / multi-usuario simultaneo (lecturas)
# ---------------------------------------------------------------------------
Write-Host "`n=== A) Multi-tenant paralelo (lecturas) ===" -ForegroundColor Cyan
$urls = @()
1..15 | ForEach-Object {
  $urls += "$BaseUrl/menu/$SucursalA"
  $urls += "$BaseUrl/menu/$SucursalB"
  $urls += "$BaseUrl/salud"
  $urls += "$BaseUrl/ciudades"
}
$sw = [Diagnostics.Stopwatch]::StartNew()
$multi = Invoke-ParallelGet -Urls $urls -PoolSize 40
$sw.Stop()
$okM = @($multi | Where-Object { $_.ok }).Count
Note ("Multi-tenant GET n={0} ok={1} fail={2} wall={3}ms" -f $urls.Count, $okM, ($urls.Count - $okM), $sw.ElapsedMilliseconds) `
  ($(if ($okM -eq $urls.Count) { 'OK' } else { 'FALLO' }))

# Admin A lee propia + intento Norte (admin demo suele ser corporativo → 200)
$rA = Invoke-FoodyApi -Path "/dashboard/resumen?sucursal_id=$SucursalA" -Headers $hA
$rB = Invoke-FoodyApi -Path "/dashboard/resumen?sucursal_id=$SucursalB" -Headers $hA
Note ("dashboard Centro=$($rA.status) Norte=$($rB.status) (admin cadena puede ver ambas)") 'OK'

# ---------------------------------------------------------------------------
# B) Races — mismo registro
# ---------------------------------------------------------------------------
Write-Host "`n=== B) Races mismo registro ===" -ForegroundColor Cyan

# B1) Idempotency create pedido
$key = [guid]::NewGuid().ToString()
$bodyPedido = {
  param($Key)
  @{
    sucursal_id     = $SucursalA
    device_id       = "conc-idem-$Key"
    tipo            = 'para_llevar'
    metodo_pago     = 'efectivo'
    items           = @(@{ producto_id = $prodId; cantidad = 1; precio = $prodPrecio })
    idempotency_key = $Key
  }
}
$jobsIdem = @()
1..2 | ForEach-Object {
  $jobsIdem += Start-Job -ScriptBlock {
    param($Base, $Body)
    try {
      $r = Invoke-RestMethod -Uri "$Base/pedidos" -Method POST -Body ($Body | ConvertTo-Json -Depth 6 -Compress) `
        -ContentType 'application/json' -TimeoutSec 40
      return @{ ok = [bool]$r.exito; id = $r.datos.pedido_id; err = $r.error }
    }
    catch { return @{ ok = $false; err = $_.Exception.Message } }
  } -ArgumentList $BaseUrl, (& $bodyPedido $key)
}
$resIdem = $jobsIdem | Wait-Job | Receive-Job
$jobsIdem | Remove-Job -Force
$idsIdem = @($resIdem | Where-Object { $_.ok -and $_.id } | ForEach-Object { $_.id } | Select-Object -Unique)
Note ("Idempotency 2x misma key → pedidos unicos={0} (esperado 1)" -f $idsIdem.Count) `
  ($(if ($idsIdem.Count -eq 1) { 'OK' } else { 'FALLO' }))

# B2) Doble PATCH estado concurrente (crear pedido fresco)
$crear = Invoke-FoodyApi -Method POST -Path '/pedidos' -Body @{
  sucursal_id     = $SucursalA
  device_id       = "conc-estado-$(Get-Random)"
  tipo            = 'para_llevar'
  metodo_pago     = 'efectivo'
  items           = @(@{ producto_id = $prodId; cantidad = 1; precio = $prodPrecio })
  idempotency_key = [guid]::NewGuid().ToString()
}
if (-not ($crear.ok -and $crear.json.exito)) {
  Note "No se pudo crear pedido para race estado: $($crear.json.mensaje)" 'AVISO'
}
else {
  $pedidoRaceId = $crear.json.datos.pedido_id
  $est0 = $crear.json.datos.estado
  Note "Pedido race estado id=$pedidoRaceId estado_inicial=$est0" 'OK'
  $token = $admin.token
  # Race: dos confirmaciones a en_cocina (transicion valida desde pendiente)
  $jobsEst = @()
  1..2 | ForEach-Object {
    $jobsEst += Start-Job -ScriptBlock {
      param($Base, $Token, $PedidoId, $Sid)
      try {
        $headers = @{ Authorization = "Bearer $Token"; 'Content-Type' = 'application/json' }
        $body = '{"estado":"en_cocina"}'
        $r = Invoke-WebRequest -Uri "$Base/pedidos/$PedidoId/estado?sucursal_id=$Sid" `
          -Method PATCH -Headers $headers -Body $body -TimeoutSec 40 -UseBasicParsing
        $j = $r.Content | ConvertFrom-Json
        return @{ ok = $j.exito; status = [int]$r.StatusCode; msg = $j.mensaje; err = $j.error }
      }
      catch {
        $st = 0; $err = $null
        if ($_.Exception.Response) {
          $st = [int]$_.Exception.Response.StatusCode
          try {
            $reader = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
            $raw = $reader.ReadToEnd(); $reader.Close()
            $j = $raw | ConvertFrom-Json
            $err = $j.error
          } catch {}
        }
        return @{ ok = $false; status = $st; err = $err; msg = $_.Exception.Message }
      }
    } -ArgumentList $BaseUrl, $token, $pedidoRaceId, $SucursalA
  }
  $resEst = $jobsEst | Wait-Job | Receive-Job
  $jobsEst | Remove-Job -Force
  $okEst = @($resEst | Where-Object { $_.ok }).Count
  $failEst = @($resEst | Where-Object { -not $_.ok }).Count
  # FOR UPDATE + if (anterior===nuevo) return OK → segundo es no-op idempotente (no 400)
  Note ("Doble en_cocina concurrente: ok=$okEst fail=$failEst (esperado ok=1|2; fail solo si error real)" ) `
    ($(if ($okEst -ge 1 -and ($okEst + $failEst) -eq 2 -and $failEst -le 1) { 'OK' } else { 'FALLO' }))
  $det = Invoke-FoodyApi -Path "/pedidos/$pedidoRaceId`?sucursal_id=$SucursalA" -Headers $hA
  if ($det.ok -and $det.json.exito) {
    Note "Estado final pedido=$($det.json.datos.estado)" 'OK'
    # limpiar
    $null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoRaceId/estado?sucursal_id=$SucursalA" -Headers $hA -Body @{
      estado = 'cancelado'; motivo = 'limpieza conc Prompt 26'
    }
  }
}

# B3) Doble abrir caja concurrente (TOCTOU)
$cajaAct = Invoke-FoodyApi -Path "/caja/activa/$SucursalA" -Headers $hA
$habiaCaja = $cajaAct.ok -and $cajaAct.json.exito -and $cajaAct.json.datos
if ($habiaCaja) {
  Note 'Caja ya abierta: race abrir omitida (no cerrar turno demo automaticamente)' 'AVISO'
}
else {
  $token = $admin.token
  $jobsCaja = @()
  1..2 | ForEach-Object {
    $jobsCaja += Start-Job -ScriptBlock {
      param($Base, $Token, $Sid)
      try {
        $headers = @{ Authorization = "Bearer $Token"; 'Content-Type' = 'application/json' }
        $body = (@{ sucursal_id = $Sid; monto_inicial = 10000 } | ConvertTo-Json -Compress)
        $r = Invoke-WebRequest -Uri "$Base/caja/abrir" -Method POST -Headers $headers -Body $body -TimeoutSec 40 -UseBasicParsing
        $j = $r.Content | ConvertFrom-Json
        return @{ ok = $j.exito; status = [int]$r.StatusCode; id = $j.datos.id; err = $j.error }
      }
      catch {
        $st = 0; $err = $_.Exception.Message; $body = $null
        if ($_.Exception.Response) {
          $st = [int]$_.Exception.Response.StatusCode
          try {
            $reader = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
            $raw = $reader.ReadToEnd(); $reader.Close()
            $body = $raw | ConvertFrom-Json
            $err = $body.error
          }
          catch {}
        }
        return @{ ok = $false; status = $st; err = $err }
      }
    } -ArgumentList $BaseUrl, $token, $SucursalA
  }
  $resCaja = $jobsCaja | Wait-Job | Receive-Job
  $jobsCaja | Remove-Job -Force
  $okCaja = @($resCaja | Where-Object { $_.ok }).Count
  $yaAbierta = @($resCaja | Where-Object { $_.err -eq 'CAJA_YA_ABIERTA' -or $_.status -eq 400 }).Count
  Note ("Doble abrir caja: ok=$okCaja rechazos=$yaAbierta (esperado ok<=1)" ) `
    ($(if ($okCaja -le 1) { 'OK' } else { 'FALLO' }))
  if ($okCaja -gt 1) {
    Note 'CONC-CAJA-01: TOCTOU — dos cajas abiertas bajo carrera' 'FALLO'
  }
  # Contar abiertas en BD via API
  $act = Invoke-FoodyApi -Path "/caja/activa/$SucursalA" -Headers $hA
  if ($act.ok -and $act.json.datos) {
    Note "Caja activa id=$($act.json.datos.id)" 'OK'
  }
}

# B4) Inventario — dos PATCH stock_nuevo concurrentes (last-write / serializacion)
$ings = Invoke-FoodyApi -Path "/inventario/$SucursalA" -Headers $hA
if ($ings.ok -and $ings.json.exito -and @($ings.json.datos).Count -gt 0) {
  $ing = @($ings.json.datos)[0]
  $ingId = $ing.id
  $stock0 = [double]$ing.stock_actual
  $token = $admin.token
  $targetA = $stock0 + 1
  $targetB = $stock0 + 2
  $jobsInv = @()
  foreach ($target in @($targetA, $targetB)) {
    $jobsInv += Start-Job -ScriptBlock {
      param($Base, $Token, $IngId, $Nuevo)
      try {
        $headers = @{ Authorization = "Bearer $Token"; 'Content-Type' = 'application/json' }
        $body = (@{ stock_nuevo = $Nuevo; motivo_ajuste = "conc-race-$Nuevo" } | ConvertTo-Json -Compress)
        $r = Invoke-WebRequest -Uri "$Base/inventario/$IngId" -Method PATCH -Headers $headers -Body $body -TimeoutSec 40 -UseBasicParsing
        $j = $r.Content | ConvertFrom-Json
        return @{ ok = $j.exito; status = [int]$r.StatusCode; err = $j.error }
      }
      catch {
        $st = 0
        if ($_.Exception.Response) { $st = [int]$_.Exception.Response.StatusCode }
        return @{ ok = $false; status = $st; err = $_.Exception.Message }
      }
    } -ArgumentList $BaseUrl, $token, $ingId, $target
  }
  $resInv = $jobsInv | Wait-Job | Receive-Job
  $jobsInv | Remove-Job -Force
  $okInv = @($resInv | Where-Object { $_.ok }).Count
  $ings2 = Invoke-FoodyApi -Path "/inventario/$SucursalA" -Headers $hA
  $ing2 = @($ings2.json.datos) | Where-Object { $_.id -eq $ingId } | Select-Object -First 1
  $stock1 = if ($ing2) { [double]$ing2.stock_actual } else { $stock0 }
  Note ("Inventario 2 PATCH concurrentes: ok_http=$okInv stock $stock0 -> $stock1 (targets +1/+2; final debe ser uno de ellos)" ) 'OK'
  if ($okInv -eq 2 -and $stock1 -ne $targetA -and $stock1 -ne $targetB) {
    Note 'Stock final no coincide con ninguno de los targets (corrupcion?)' 'FALLO'
  }
  elseif ($okInv -eq 2) {
    Note 'Serializacion: last-writer-wins o FOR UPDATE; sin valor intermedio corrupto' 'OK'
  }
}
else {
  Note 'Sin insumos para race inventario' 'AVISO'
}

# ---------------------------------------------------------------------------
# C) Sostenido vs pico
# ---------------------------------------------------------------------------
if (-not $SkipLoad) {
  Write-Host "`n=== C) Carga sostenida vs pico ===" -ForegroundColor Cyan

  # Sostenido: 8 workers × 20 req = 160, ritmo serializado por worker
  $sustUrls = @()
  1..160 | ForEach-Object { $sustUrls += "$BaseUrl/salud" }
  # En oleadas de 8
  $swS = [Diagnostics.Stopwatch]::StartNew()
  $okS = 0; $failS = 0; $latS = New-Object System.Collections.Generic.List[double]
  for ($batch = 0; $batch -lt 20; $batch++) {
    $slice = $sustUrls[($batch * 8)..(($batch * 8) + 7)]
    $res = Invoke-ParallelGet -Urls $slice -PoolSize 8
    foreach ($r in $res) {
      if ($r.ok) { $okS++ } else { $failS++ }
      $latS.Add([double]$r.ms)
    }
    Start-Sleep -Milliseconds 50
  }
  $swS.Stop()
  $arrS = $latS.ToArray() | Sort-Object
  $p50s = $arrS[[math]::Floor(($arrS.Count - 1) * 0.5)]
  $p95s = $arrS[[math]::Floor(($arrS.Count - 1) * 0.95)]
  $rpsS = [math]::Round(160 / ($swS.Elapsed.TotalSeconds), 1)
  Note ("Sostenido 160 GET /salud: ok=$okS fail=$failS wall=$($swS.ElapsedMilliseconds)ms rps=$rpsS p50=$p50s p95=$p95s") `
    ($(if ($failS -eq 0) { 'OK' } else { 'AVISO' }))

  # Pico (viernes noche proxy): 80 concurrent menu+salud
  $burst = @()
  1..40 | ForEach-Object { $burst += "$BaseUrl/menu/$SucursalA"; $burst += "$BaseUrl/salud" }
  $swB = [Diagnostics.Stopwatch]::StartNew()
  $resB = Invoke-ParallelGet -Urls $burst -PoolSize 80
  $swB.Stop()
  $okB = @($resB | Where-Object { $_.ok }).Count
  $failB = $burst.Count - $okB
  $latB = @($resB | ForEach-Object { [double]$_.ms } | Sort-Object)
  $p50b = $latB[[math]::Floor(($latB.Count - 1) * 0.5)]
  $p95b = $latB[[math]::Floor(($latB.Count - 1) * 0.95)]
  $rpsB = [math]::Round($burst.Count / ($swB.Elapsed.TotalSeconds), 1)
  Note ("Pico 80 conc (menu+salud) n=80: ok=$okB fail=$failB wall=$($swB.ElapsedMilliseconds)ms rps=$rpsB p50=$p50b p95=$p95b") `
    ($(if ($failB -eq 0) { 'OK' } else { 'AVISO' }))
  if ($p95b -gt ($p95s * 3) -and $p95b -gt 500) {
    Note 'Pico degrada p95 >3x vs sostenido (esperado Nest single + pool)' 'AVISO'
  }
}

# JSON salida
$outPath = Join-Path $PSScriptRoot '_tmp_estres_concurrencia.json'
@{
  fecha     = (Get-Date).ToString('o')
  hallazgos = @($Hallazgos)
  fallos    = $Fallos
  avisos    = $Avisos
} | ConvertTo-Json -Depth 4 | Set-Content $outPath -Encoding utf8
Write-Host "`nJSON: $outPath"

Write-Host ''
if ($Fallos -gt 0) {
  Write-Host "Verificacion estres/concurrencia FALLO fallos=$Fallos avisos=$Avisos" -ForegroundColor Red
  exit 1
}
Write-Host "Verificacion estres/concurrencia OK (avisos=$Avisos)" -ForegroundColor Green
exit 0
