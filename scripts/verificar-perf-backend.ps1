# Prompt 23 — Performance backend: latencia + carga concurrente (RunspacePool)
# Uso:
#   .\scripts\verificar-perf-backend.ps1
#   .\scripts\verificar-perf-backend.ps1 -SkipLoad
#   .\scripts\verificar-perf-backend.ps1 -Niveles 10,50,200

param(
  [string]$BaseUrl = 'http://127.0.0.1:3000/api/v1',
  [string]$SucursalId = 'c0000000-0000-4000-8000-000000000001',
  [int[]]$Niveles = @(10, 50, 200),
  [switch]$SkipLoad
)

$ErrorActionPreference = 'Stop'

function Measure-Http {
  param(
    [string]$Method = 'GET',
    [string]$Url,
    [hashtable]$Headers = @{},
    [int]$TimeoutSec = 30
  )
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    $params = @{
      Uri             = $Url
      Method          = $Method
      TimeoutSec      = $TimeoutSec
      UseBasicParsing = $true
      ErrorAction     = 'Stop'
    }
    if ($Headers.Count) { $params.Headers = $Headers }
    $r = Invoke-WebRequest @params
    $sw.Stop()
    return @{
      ok     = $true
      status = [int]$r.StatusCode
      ms     = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
    }
  }
  catch {
    $sw.Stop()
    $status = 0
    if ($_.Exception.Response) {
      $status = [int]$_.Exception.Response.StatusCode
    }
    return @{
      ok     = $false
      status = $status
      ms     = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
      error  = $_.Exception.Message
    }
  }
}

function Invoke-LoadRS {
  param(
    [string]$Url,
    [hashtable]$Headers = @{},
    [int]$N,
    [string]$Label,
    [int]$PoolSize = 50
  )
  Write-Host "`n--- Carga $Label : $N concurrentes (pool=$PoolSize) ---" -ForegroundColor Cyan
  $session = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  $maxPool = [Math]::Min($PoolSize, $N)
  $pool = [RunspaceFactory]::CreateRunspacePool(1, $maxPool, $session, $Host)
  $pool.Open()
  $swAll = [Diagnostics.Stopwatch]::StartNew()
  $pipes = @()
  for ($i = 0; $i -lt $N; $i++) {
    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript({
        param($U, $H)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
          $p = @{ Uri = $U; TimeoutSec = 60; UseBasicParsing = $true }
          if ($H -and $H.Count) { $p.Headers = $H }
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
      }).AddArgument($Url).AddArgument($Headers)
    $pipes += [pscustomobject]@{ ps = $ps; handle = $ps.BeginInvoke() }
  }
  $results = foreach ($p in $pipes) {
    $out = $p.ps.EndInvoke($p.handle)
    $p.ps.Dispose()
    $out
  }
  $swAll.Stop()
  $pool.Close()
  $pool.Dispose()

  $ok = @($results | Where-Object { $_.ok }).Count
  $ms = @($results | ForEach-Object { [double]$_.ms } | Sort-Object)
  $p50 = $ms[[math]::Floor(($ms.Count - 1) * 0.5)]
  $p95 = $ms[[math]::Floor(($ms.Count - 1) * 0.95)]
  $avg = ($ms | Measure-Object -Average).Average
  $wall = $swAll.ElapsedMilliseconds
  $rps = if ($wall -gt 0) { [math]::Round($N / ($wall / 1000.0), 1) } else { 0 }

  $row = [pscustomobject]@{
    label   = $Label
    n       = $N
    ok      = $ok
    fail    = ($N - $ok)
    wall_ms = $wall
    rps     = $rps
    min_ms  = $ms[0]
    avg_ms  = [math]::Round($avg, 1)
    p50_ms  = $p50
    p95_ms  = $p95
    max_ms  = $ms[-1]
  }
  Write-Host ("  ok={0} fail={1} wall={2}ms rps={3} p50={4} p95={5} max={6}" -f `
      $row.ok, $row.fail, $row.wall_ms, $row.rps, $row.p50_ms, $row.p95_ms, $row.max_ms)
  return $row
}

Write-Host '=== Foody PERF backend (Prompt 23) ===' -ForegroundColor Cyan
Write-Host "Base=$BaseUrl Sucursal=$SucursalId"

$salud = Measure-Http -Url "$BaseUrl/salud"
if (-not $salud.ok) { throw "API caida: $($salud.error)" }
Write-Host "OK /salud $($salud.ms) ms"

$loginBody = '{"email":"admin@foody.demo","contrasena":"123456"}'
$loginSw = [System.Diagnostics.Stopwatch]::StartNew()
$login = Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method POST -Body $loginBody -ContentType 'application/json' -TimeoutSec 15
$loginSw.Stop()
if (-not $login.exito) { throw 'Login admin fallo' }
$token = $login.datos.token
$auth = @{ Authorization = "Bearer $token" }
Write-Host ("OK login {0} ms" -f [math]::Round($loginSw.Elapsed.TotalMilliseconds, 1))

Write-Host "`n=== Latencia single (3 muestras, mediana) ===" -ForegroundColor Cyan

function Median-Ms {
  param([scriptblock]$Fn, [int]$Times = 3)
  $vals = @()
  for ($i = 0; $i -lt $Times; $i++) { $vals += & $Fn }
  $sorted = $vals | Sort-Object
  return $sorted[[math]::Floor(($sorted.Count - 1) / 2)]
}

$m1 = Measure-Http -Url "$BaseUrl/menu/$SucursalId"
$m2 = Measure-Http -Url "$BaseUrl/menu/$SucursalId"
$m3 = Measure-Http -Url "$BaseUrl/menu/$SucursalId"
Write-Host ("Menu samples: {0} / {1} / {2} ms (cache hit esperado en 2-3)" -f $m1.ms, $m2.ms, $m3.ms)

$endpoints = @(
  @{ name = 'GET /salud'; url = "$BaseUrl/salud"; auth = $false; cache = 'n/a' }
  @{ name = 'GET /ciudades'; url = "$BaseUrl/ciudades"; auth = $false; cache = 'NO' }
  @{ name = 'GET /ciudades/valledupar/restaurantes'; url = "$BaseUrl/ciudades/valledupar/restaurantes"; auth = $false; cache = 'NO' }
  @{ name = 'GET /menu/:sucursal'; url = "$BaseUrl/menu/$SucursalId"; auth = $false; cache = 'SI MenuCache' }
  @{ name = 'GET /dashboard/resumen'; url = "$BaseUrl/dashboard/resumen?sucursal_id=$SucursalId"; auth = $true; cache = 'NO' }
  @{ name = 'GET /dashboard/graficos'; url = "$BaseUrl/dashboard/graficos?sucursal_id=$SucursalId"; auth = $true; cache = 'NO' }
  @{ name = 'GET /reportes/financiero'; url = "$BaseUrl/reportes/financiero?sucursal_id=$SucursalId&desde=2025-01-01&hasta=2026-12-31"; auth = $true; cache = 'NO' }
  @{ name = 'GET /analitica/resumen'; url = "$BaseUrl/analitica/resumen?sucursal_id=$SucursalId&preset=hoy"; auth = $true; cache = 'NO' }
)

$rows = @()
foreach ($ep in $endpoints) {
  $h = if ($ep.auth) { $auth } else { @{} }
  $med = Median-Ms -Fn { (Measure-Http -Url $ep.url -Headers $h).ms }
  $sample = Measure-Http -Url $ep.url -Headers $h
  $okLabel = if ($sample.ok) { 'OK' } else { "FAIL $($sample.status)" }
  Write-Host ("  {0,-45} med={1,7} ms  {2}  cache={3}" -f $ep.name, $med, $okLabel, $ep.cache)
  $rows += [pscustomobject]@{
    endpoint = $ep.name
    med_ms   = $med
    status   = $sample.status
    cache    = $ep.cache
    ok       = $sample.ok
  }
}

$loadRows = @()
if (-not $SkipLoad) {
  Write-Host "`n=== Carga concurrente (RunspacePool) ===" -ForegroundColor Cyan
  foreach ($n in $Niveles) {
    $poolSize = if ($n -ge 200) { 80 } elseif ($n -ge 50) { $n } else { $n }
    $loadRows += Invoke-LoadRS -Url "$BaseUrl/salud" -Headers @{} -N $n -Label 'salud' -PoolSize $poolSize
    $loadRows += Invoke-LoadRS -Url "$BaseUrl/menu/$SucursalId" -Headers @{} -N $n -Label 'menu' -PoolSize $poolSize
    $loadRows += Invoke-LoadRS -Url "$BaseUrl/dashboard/resumen?sucursal_id=$SucursalId" -Headers $auth -N $n -Label 'dashboard_resumen' -PoolSize $poolSize
  }
  Write-Host "`n=== Resumen carga ===" -ForegroundColor Cyan
  $loadRows | Format-Table -AutoSize | Out-String | Write-Host
}

$out = @{
  fecha           = (Get-Date).ToString('o')
  base            = $BaseUrl
  sucursal        = $SucursalId
  latencia        = $rows
  menu_samples_ms = @($m1.ms, $m2.ms, $m3.ms)
  carga           = $loadRows
  metodo_carga    = 'RunspacePool'
}
$jsonPath = Join-Path $PSScriptRoot '_tmp_perf_backend.json'
$out | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding utf8
Write-Host "JSON: $jsonPath"

$fallosLat = @($rows | Where-Object { -not $_.ok }).Count
$fallosLoad = @($loadRows | Where-Object { $_.fail -gt 0 }).Count
if ($fallosLat -gt 0 -or $fallosLoad -gt 0) {
  Write-Host "PERF con fallos lat=$fallosLat load_niveles_con_fail=$fallosLoad" -ForegroundColor Yellow
  exit 1
}
Write-Host 'Verificacion PERF backend OK' -ForegroundColor Green
exit 0
