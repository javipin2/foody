<#!
.SYNOPSIS
Mide lecturas GET pequeñas de Foody en localhost y por Cloudflare Tunnel.
.DESCRIPTION
Solo ejecuta GET a /salud y /menu/:sucursal. No inicia sesión, no escribe datos,
no crea sesiones ni hace cambios en el proyecto. La concurrencia máxima por defecto
es 5. Usar contra el PC que sirve Foody solo en horas de prueba.
#>
param(
  [string[]]$BaseUrls = @(
    'http://127.0.0.1:3000/api/v1',
    'https://api.foodyy.store/api/v1'
  ),
  [string]$SucursalId = 'c0000000-0000-4000-8000-000000000001',
  [int[]]$Concurrencias = @(1, 3, 5),
  [int]$Repeticiones = 2,
  [int]$TimeoutSec = 6
)

$ErrorActionPreference = 'Stop'
if ($Repeticiones -lt 1) { throw 'Repeticiones debe ser al menos 1.' }
if ($Concurrencias.Count -eq 0 -or ($Concurrencias | Where-Object { $_ -lt 1 -or $_ -gt 5 })) {
  throw 'Concurrencias debe contener valores entre 1 y 5 para proteger el entorno local.'
}

function Invoke-GetSample {
  param([string]$Url, [int]$Timeout)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    $r = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $Timeout -UseBasicParsing
    $sw.Stop()
    $bytes = 0
    if ($r.RawContentLength) { $bytes = [int]$r.RawContentLength }
    return [pscustomobject]@{ ok = $true; status = [int]$r.StatusCode; ms = [double]$sw.Elapsed.TotalMilliseconds; bytes = $bytes; error = $null }
  }
  catch {
    $sw.Stop()
    $status = 0
    if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
    return [pscustomobject]@{ ok = $false; status = $status; ms = [double]$sw.Elapsed.TotalMilliseconds; bytes = 0; error = $_.Exception.Message }
  }
}

function Invoke-ParallelGet {
  param([string]$Url, [int]$Count, [int]$Timeout)
  $pool = [RunspaceFactory]::CreateRunspacePool(1, $Count)
  $pool.Open()
  $jobs = @()
  try {
    for ($i = 0; $i -lt $Count; $i++) {
      $ps = [PowerShell]::Create()
      $ps.RunspacePool = $pool
      [void]$ps.AddScript({
        param($TargetUrl, $Limit)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
          $r = Invoke-WebRequest -Uri $TargetUrl -Method Get -TimeoutSec $Limit -UseBasicParsing
          $sw.Stop()
          $n = 0
          if ($r.RawContentLength) { $n = [int]$r.RawContentLength }
          [pscustomobject]@{ ok = $true; status = [int]$r.StatusCode; ms = [double]$sw.Elapsed.TotalMilliseconds; bytes = $n; error = $null }
        }
        catch {
          $sw.Stop()
          $status = 0
          if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
          [pscustomobject]@{ ok = $false; status = $status; ms = [double]$sw.Elapsed.TotalMilliseconds; bytes = 0; error = $_.Exception.Message }
        }
      }).AddArgument($Url).AddArgument($Timeout)
      $jobs += [pscustomobject]@{ shell = $ps; handle = $ps.BeginInvoke() }
    }
    foreach ($job in $jobs) {
      $result = $job.shell.EndInvoke($job.handle)
      foreach ($item in $result) { $item }
    }
  }
  finally {
    foreach ($job in $jobs) { $job.shell.Dispose() }
    $pool.Close()
    $pool.Dispose()
  }
}

$routes = @(
  @{ name = 'salud'; path = '/salud' },
  @{ name = 'menu'; path = "/menu/$SucursalId" }
)
$results = @()
Write-Host 'Foody GET latency check (read-only, max concurrency 5)' -ForegroundColor Cyan
Write-Host "Sucursal=$SucursalId Repeticiones=$Repeticiones"

foreach ($base in $BaseUrls) {
  $hostFailed = $false
  foreach ($route in $routes) {
    if ($hostFailed) {
      Write-Host "omitido $($route.name): se detuvo este host tras una falla previa." -ForegroundColor Yellow
      continue
    }
    $url = $base.TrimEnd('/') + $route.path
    $warm = Invoke-GetSample -Url $url -Timeout $TimeoutSec
    Write-Host ("warmup {0,-6} {1} {2} ms HTTP {3}" -f $route.name, $base, [math]::Round($warm.ms, 1), $warm.status)
    if (-not $warm.ok) {
      Write-Host "  omitido: la comprobación inicial falló ($($warm.error)); no se envían más solicitudes a esta ruta." -ForegroundColor Yellow
      $hostFailed = $true
      $results += [pscustomobject]@{
        base = $base; endpoint = $route.name; concurrency = 0; requests = 1
        ok = 0; failed = 1; p50_ms = [math]::Round($warm.ms, 1)
        p95_ms = [math]::Round($warm.ms, 1); avg_ms = [math]::Round($warm.ms, 1)
        response_bytes_avg = 0
      }
      continue
    }
    foreach ($n in $Concurrencias) {
      $samples = @()
      for ($rep = 0; $rep -lt $Repeticiones; $rep++) {
        $samples += @(Invoke-ParallelGet -Url $url -Count $n -Timeout $TimeoutSec)
      }
      $times = @($samples | ForEach-Object { [double]$_.ms } | Sort-Object)
      $ok = @($samples | Where-Object ok).Count
      $p50 = $times[[math]::Floor(($times.Count - 1) * 0.50)]
      $p95 = $times[[math]::Floor(($times.Count - 1) * 0.95)]
      $avg = ($times | Measure-Object -Average).Average
      $bytes = @($samples | Where-Object ok | ForEach-Object bytes | Measure-Object -Average).Average
      $row = [pscustomobject]@{
        base = $base; endpoint = $route.name; concurrency = $n; requests = $samples.Count
        ok = $ok; failed = ($samples.Count - $ok); p50_ms = [math]::Round($p50, 1)
        p95_ms = [math]::Round($p95, 1); avg_ms = [math]::Round($avg, 1)
        response_bytes_avg = [math]::Round($bytes, 0)
      }
      $results += $row
      Write-Host ("  {0,-6} conc={1} ok={2}/{3} p50={4}ms p95={5}ms avg={6}ms bytes~{7}" -f $row.endpoint, $n, $row.ok, $row.requests, $row.p50_ms, $row.p95_ms, $row.avg_ms, $row.response_bytes_avg)
      if ($row.failed -gt 0) {
        Write-Host '  se detienen más solicitudes a este host tras el timeout/error.' -ForegroundColor Yellow
        $hostFailed = $true
        break
      }
    }
  }
}

Write-Host "Completed $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
$results | Format-Table -AutoSize
