# Prueba de estres Foody (API local / tunel).
# Mide latencia y errores bajo concurrencia creciente (lecturas + login).
#
# Uso:
#   .\scripts\estres-api-foody.ps1
#   .\scripts\estres-api-foody.ps1 -MaxConcurrencia 40 -Repeticiones 25
#   .\scripts\estres-api-foody.ps1 -BaseUrl http://localhost:3000/api/v1

param(
    [string]$BaseUrl = 'http://localhost:3000/api/v1',
    [string]$SucursalId = 'c0000000-0000-4000-8000-000000000001',
    [int]$MaxConcurrencia = 40,
    [int]$Repeticiones = 25,
    [switch]$IncluirEscritura
)

$ErrorActionPreference = 'Stop'

function Percentil([double[]]$vals, [double]$p) {
    if ($vals.Count -eq 0) { return 0 }
    $s = $vals | Sort-Object
    $idx = [Math]::Min($s.Count - 1, [Math]::Floor(($p / 100.0) * ($s.Count - 1)))
    return [Math]::Round($s[$idx], 1)
}

function Invoke-EstresOleada {
    param(
        [int]$Workers,
        [int]$PorWorker,
        [string]$Token,
        [string]$Base,
        [string]$Sid
    )

    $pool = [runspacefactory]::CreateRunspacePool(1, [Math]::Max(1, $Workers))
    $pool.Open()
    $jobs = @()
    $script = {
        param($Base, $Token, $Sid, $N)
        $lat = New-Object System.Collections.Generic.List[double]
        $ok = 0; $err = 0
        $endpoints = @(
            @{ Method = 'GET'; Path = '/salud'; Auth = $false },
            @{ Method = 'GET'; Path = "/menu/$Sid"; Auth = $false },
            @{ Method = 'GET'; Path = "/promociones?sucursal_id=$Sid"; Auth = $false },
            @{ Method = 'GET'; Path = "/pedidos?solo_activos=true&sucursal_id=$Sid&limit=50"; Auth = $true },
            @{ Method = 'GET'; Path = "/inventario/movimientos/${Sid}?page=1&limit=20"; Auth = $true }
        )
        for ($i = 0; $i -lt $N; $i++) {
            $ep = $endpoints[$i % $endpoints.Count]
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $headers = @{}
                if ($ep.Auth -and $Token) { $headers['Authorization'] = "Bearer $Token" }
                $null = Invoke-RestMethod -Uri ($Base + $ep.Path) -Method $ep.Method `
                    -Headers $headers -TimeoutSec 30
                $sw.Stop()
                $lat.Add([double]$sw.Elapsed.TotalMilliseconds)
                $ok++
            }
            catch {
                $sw.Stop()
                $lat.Add([double]$sw.Elapsed.TotalMilliseconds)
                $err++
            }
        }
        return @{ ok = $ok; err = $err; lat = $lat.ToArray() }
    }

    $swAll = [System.Diagnostics.Stopwatch]::StartNew()
    for ($w = 0; $w -lt $Workers; $w++) {
        $ps = [powershell]::Create().AddScript($script).AddArgument($Base).AddArgument($Token).AddArgument($Sid).AddArgument($PorWorker)
        $ps.RunspacePool = $pool
        $jobs += @{ ps = $ps; handle = $ps.BeginInvoke() }
    }
    $results = @()
    foreach ($j in $jobs) {
        $results += $j.ps.EndInvoke($j.handle)
        $j.ps.Dispose()
    }
    $swAll.Stop()
    $pool.Close()
    $pool.Dispose()

    $allLat = @()
    $okT = 0; $errT = 0
    foreach ($r in $results) {
        $okT += $r.ok
        $errT += $r.err
        if ($r.lat) { $allLat += @($r.lat) }
    }
    $total = $okT + $errT
    $secs = [Math]::Max(0.001, $swAll.Elapsed.TotalSeconds)
    return [pscustomobject]@{
        workers     = $Workers
        total       = $total
        ok          = $okT
        err         = $errT
        error_pct   = if ($total -eq 0) { 0 } else { [Math]::Round(100.0 * $errT / $total, 2) }
        rps         = [Math]::Round($total / $secs, 1)
        p50_ms      = Percentil $allLat 50
        p95_ms      = Percentil $allLat 95
        p99_ms      = Percentil $allLat 99
        max_ms      = if ($allLat.Count) { [Math]::Round(($allLat | Measure-Object -Maximum).Maximum, 1) } else { 0 }
        duracion_s  = [Math]::Round($secs, 2)
    }
}

Write-Host '=== Estres API Foody ===' -ForegroundColor Cyan
Write-Host "Base: $BaseUrl | sucursal=$SucursalId | maxWorkers=$MaxConcurrencia x $Repeticiones req" -ForegroundColor DarkGray

$salud = Invoke-RestMethod -Uri "$BaseUrl/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API /salud no responde' }
Write-Host 'OK salud (warmup)' -ForegroundColor Green

$loginBody = @{ email = 'admin@foody.demo'; contrasena = '123456' } | ConvertTo-Json
$login = Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method POST -Body $loginBody -ContentType 'application/json' -TimeoutSec 15
if (-not $login.exito) { throw "Login fallo: $($login.mensaje)" }
$token = $login.datos.token
Write-Host 'OK login admin@foody.demo' -ForegroundColor Green

$niveles = @(1, 5, 10, 20, 30, 40, 60, 80)
$niveles = $niveles | Where-Object { $_ -le $MaxConcurrencia } | Select-Object -Unique

$tabla = @()
foreach ($n in $niveles) {
    Write-Host ''
    Write-Host "--- Oleada: $n workers x $Repeticiones = $($n * $Repeticiones) req ---" -ForegroundColor Yellow
    Start-Sleep -Milliseconds 500
    $row = Invoke-EstresOleada -Workers $n -PorWorker $Repeticiones -Token $token -Base $BaseUrl -Sid $SucursalId
    $tabla += $row
    $color = if ($row.error_pct -gt 5) { 'Red' } elseif ($row.p95_ms -gt 2000) { 'Yellow' } else { 'Green' }
    Write-Host ("  RPS={0}  p50={1}ms  p95={2}ms  p99={3}ms  max={4}ms  err={5}% ({6}/{7})  t={8}s" -f `
        $row.rps, $row.p50_ms, $row.p95_ms, $row.p99_ms, $row.max_ms, $row.error_pct, $row.err, $row.total, $row.duracion_s) -ForegroundColor $color
}

Write-Host ''
Write-Host '=== Resumen lecturas ===' -ForegroundColor Cyan
$tabla | Format-Table workers, total, ok, err, error_pct, rps, p50_ms, p95_ms, p99_ms, max_ms, duracion_s -AutoSize

$critico = $tabla | Where-Object { $_.error_pct -gt 5 -or $_.p95_ms -gt 3000 } | Select-Object -First 1
$aceptable = ($tabla | Where-Object { $_.error_pct -le 2 -and $_.p95_ms -le 1500 } | Sort-Object workers -Descending | Select-Object -First 1)

Write-Host '=== Interpretacion (este entorno) ===' -ForegroundColor Cyan
if ($aceptable) {
    Write-Host "Soporta ~$($aceptable.workers) clientes concurrentes de lectura con p95<=1.5s y errores<=2% (RPS~$($aceptable.rps))." -ForegroundColor Green
} else {
    Write-Host 'Ninguna oleada cumplio p95<=1.5s y err<=2%. Entorno saturado o API lenta.' -ForegroundColor Yellow
}
if ($critico) {
    Write-Host "A partir de ~$($critico.workers) workers: degradacion (err=$($critico.error_pct)% p95=$($critico.p95_ms)ms)." -ForegroundColor Yellow
} else {
    Write-Host "Hasta $MaxConcurrencia workers no hubo degradacion critica (err>5% o p95>3s)." -ForegroundColor Green
}

if ($IncluirEscritura) {
    Write-Host ''
    Write-Host '=== Escritura: carga QR (script dedicado) ===' -ForegroundColor Cyan
    $qrScript = Join-Path $PSScriptRoot 'verificar-carga-qr.ps1'
    if (Test-Path $qrScript) {
        & $qrScript -Pedidos 15 -SucursalId $SucursalId
    } else {
        Write-Host 'No existe verificar-carga-qr.ps1' -ForegroundColor Yellow
    }
}

try {
    $post = Invoke-RestMethod -Uri "$BaseUrl/salud" -TimeoutSec 5
    Write-Host "Post-estres /salud exito=$($post.exito) bd=$($post.datos.base_datos)" -ForegroundColor $(if ($post.exito) { 'Green' } else { 'Red' })
} catch {
    Write-Host "Post-estres /salud FALLO: $_" -ForegroundColor Red
}

$outDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'backups'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outFile = Join-Path $outDir "estres-api-$stamp.json"
@{
    fecha = (Get-Date).ToString('o')
    base = $BaseUrl
    max_concurrencia = $MaxConcurrencia
    repeticiones = $Repeticiones
    oleadas = $tabla
    soporta_workers = if ($aceptable) { $aceptable.workers } else { $null }
    critico_desde = if ($critico) { $critico.workers } else { $null }
} | ConvertTo-Json -Depth 5 | Set-Content -Path $outFile -Encoding UTF8
Write-Host "Resultados: $outFile" -ForegroundColor DarkGray
