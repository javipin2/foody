# Mide CPU/RAM del host + contenedores Docker durante un comando.
# Uso: .\scripts\medir-capacidad-estres.ps1 -Comando 'node scripts/estres-1000-usuarios.mjs 1000 5 --writes=20'

param(
    [Parameter(Mandatory = $true)]
    [string]$Comando,
    [int]$IntervaloMs = 800
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
Set-Location $raiz

function Sample-Host {
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMb = [math]::Round($os.TotalVisibleMemorySize / 1024, 0)
    $freeMb = [math]::Round($os.FreePhysicalMemory / 1024, 0)
    $usedPct = [math]::Round(100 * (1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize), 1)
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
    if ($null -eq $cpu) { $cpu = -1 }
    return [pscustomobject]@{
        t        = Get-Date
        cpu_pct  = [math]::Round([double]$cpu, 1)
        ram_used_pct = $usedPct
        ram_free_mb  = $freeMb
        ram_total_mb = $totalMb
    }
}

function Sample-Docker {
    $lines = docker stats --no-stream --format "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}" 2>$null
    $out = @()
    foreach ($l in @($lines)) {
        if (-not $l) { continue }
        $p = $l -split '\|'
        if ($p.Count -lt 4) { continue }
        $name = $p[0]
        if ($name -notmatch 'supabase|foody|postgres') { continue }
        $out += [pscustomobject]@{
            name = $name
            cpu  = $p[1]
            mem  = $p[2]
            mem_pct = $p[3]
        }
    }
    return $out
}

Write-Host '=== Medicion capacidad + estres ===' -ForegroundColor Cyan
Write-Host "Comando: $Comando" -ForegroundColor DarkGray

$before = Sample-Host
$dockerBefore = Sample-Docker
Write-Host ("Antes: CPU={0}% RAM_usada={1}% libre={2}MB / {3}MB" -f $before.cpu_pct, $before.ram_used_pct, $before.ram_free_mb, $before.ram_total_mb)

$samples = New-Object System.Collections.Generic.List[object]
$job = Start-Job -ScriptBlock {
    param($cmd, $cwd)
    Set-Location $cwd
    $out = Invoke-Expression $cmd 2>&1 | Out-String
    return $out
} -ArgumentList $Comando, $raiz

while ($job.State -eq 'Running') {
    Start-Sleep -Milliseconds $IntervaloMs
    try {
        $h = Sample-Host
        $samples.Add($h) | Out-Null
        Write-Host ("  sample CPU={0}% RAM={1}% free={2}MB" -f $h.cpu_pct, $h.ram_used_pct, $h.ram_free_mb) -ForegroundColor DarkGray
    } catch { }
}

$result = Receive-Job $job -Wait -AutoRemoveJob
$after = Sample-Host
$dockerAfter = Sample-Docker

Write-Host ''
Write-Host '=== Salida estres ===' -ForegroundColor Cyan
Write-Host $result

Write-Host '=== Capacidad host ===' -ForegroundColor Cyan
if ($samples.Count -gt 0) {
    $cpuMax = ($samples | Measure-Object -Property cpu_pct -Maximum).Maximum
    $cpuAvg = [math]::Round(($samples | Measure-Object -Property cpu_pct -Average).Average, 1)
    $ramMax = ($samples | Measure-Object -Property ram_used_pct -Maximum).Maximum
    $freeMin = ($samples | Measure-Object -Property ram_free_mb -Minimum).Minimum
    Write-Host ("Durante: CPU avg={0}% max={1}% | RAM usada max={2}% | RAM libre min={3}MB" -f $cpuAvg, $cpuMax, $ramMax, $freeMin)
}
Write-Host ("Despues: CPU={0}% RAM_usada={1}% libre={2}MB" -f $after.cpu_pct, $after.ram_used_pct, $after.ram_free_mb)

Write-Host ''
Write-Host '=== Docker (containers Foody/Supabase) DESPUES ===' -ForegroundColor Cyan
$dockerAfter | Format-Table name, cpu, mem, mem_pct -AutoSize
if (-not $dockerAfter -or $dockerAfter.Count -eq 0) {
    Write-Host '(docker stats no disponible o sin contenedores)' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Componentes bajo carga:' -ForegroundColor Cyan
Write-Host '  - Cliente: proceso Node (este script)'
Write-Host '  - API: proceso node dist/main.js (NestJS) puerto 3000'
Write-Host '  - BD: contenedor PostgreSQL (supabase-db)'
Write-Host '  - Pool Nest: DB_POOL_MAX (default 10 conexiones al PG)'
