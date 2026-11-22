# Ejecuta Flutter con flavor Android + APP_FLAVOR Dart.
# Uso: .\scripts\flutter-run-flavor.ps1 -Flavor cliente
#      .\scripts\flutter-run-flavor.ps1 -Flavor equipo -Device chrome -WebPort 8080
# Web: equipo :8080 · cliente :8081/8082 (evita chocar con equipo).
# Si el puerto está ocupado por un flutter run viejo (dartvm), libera con -LiberarPuerto.

param(
    [ValidateSet('cliente', 'equipo')]
    [string]$Flavor = 'cliente',

    [string]$Device = '',

    [int]$WebPort = 8080,

    # Mata solo dartvm/flutter que escuche en WebPort (DX local; no es prod).
    [switch]$LiberarPuerto
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Test-PuertoEscucha([int]$Puerto) {
    $c = Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $c) { return $null }
    return [int]$c.OwningProcess
}

function Liberar-PuertoFlutter([int]$Puerto) {
    $procId = Test-PuertoEscucha $Puerto
    if (-not $procId) {
        Write-Host "Puerto $Puerto ya libre." -ForegroundColor Green
        return
    }
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue
    $cmd = "$($proc.CommandLine)"
    $esFlutterWeb = $cmd -match 'flutter_tools|dartvm' -and $cmd -match "web-port\s+$Puerto|--web-port\s+$Puerto|web-port=$Puerto"
    # Algunos launches solo muestran 'run' + chrome; aceptar dartvm con flutter_tools
    if (-not $esFlutterWeb) {
        $esFlutterWeb = ($proc.Name -match 'dart') -and ($cmd -match 'flutter_tools\.snapshot\s+run')
    }
    if (-not $esFlutterWeb) {
        throw "Puerto $Puerto ocupado por PID $procId ($($proc.Name)), no parece flutter run. Usa otro -WebPort o cierra ese proceso a mano."
    }
    Write-Host "Liberando puerto $Puerto (PID $procId, flutter/dartvm local)..." -ForegroundColor Yellow
    Stop-Process -Id $procId -Force
    Start-Sleep -Seconds 1
    if (Test-PuertoEscucha $Puerto) {
        throw "No se pudo liberar el puerto $Puerto."
    }
    Write-Host "Puerto $Puerto libre." -ForegroundColor Green
}

$args = @(
    'run',
    '--flavor', $Flavor,
    '--dart-define', "APP_FLAVOR=$Flavor",
    '-t', 'lib/main.dart'
)

$esWeb = $false
if ($Device -ne '') {
    $args += @('-d', $Device)
    if ($Device -match 'chrome|web-server|edge') {
        $esWeb = $true
        # Solo auto-desviar si alguien pide cliente en 8080 sin querer (equipo usa 8080).
        # Puerto 8081 (tunel cliente) se respeta tal cual.
        if ($WebPort -eq 8080 -and $Flavor -eq 'cliente') {
            $WebPort = 8081
        }
        $args += @('--web-port', "$WebPort")
    }
}

if ($esWeb) {
    $ocupante = Test-PuertoEscucha $WebPort
    if ($ocupante) {
        if ($LiberarPuerto) {
            Liberar-PuertoFlutter $WebPort
        } else {
            Write-Host @"
Puerto $WebPort ocupado (PID $ocupante). Suele ser un 'flutter run' anterior (dartvm) — solo afecta DEV local, no producción.

  .\scripts\flutter-run-flavor.ps1 -Flavor $Flavor -Device $Device -WebPort $WebPort -LiberarPuerto

O usa otro puerto, p. ej. -WebPort 8083
"@ -ForegroundColor Yellow
            throw "Puerto $WebPort en uso (errno 10048). Pasa -LiberarPuerto o cambia -WebPort."
        }
    }
}

Write-Host "flutter $($args -join ' ')" -ForegroundColor Cyan
& flutter @args
