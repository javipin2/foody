# Ejecuta Flutter con flavor Android + APP_FLAVOR Dart.
# Uso: .\scripts\flutter-run-flavor.ps1 -Flavor cliente
#      .\scripts\flutter-run-flavor.ps1 -Flavor equipo

param(
    [ValidateSet('cliente', 'equipo')]
    [string]$Flavor = 'cliente',

    [string]$Device = '',

    [int]$WebPort = 8080
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$args = @(
    'run',
    '--flavor', $Flavor,
    '--dart-define', "APP_FLAVOR=$Flavor",
    '-t', 'lib/main.dart'
)

if ($Device -ne '') {
    $args += @('-d', $Device)
    if ($Device -match 'chrome|web-server|edge') {
        $args += @('--web-port', "$WebPort")
    }
}

Write-Host "flutter $($args -join ' ')" -ForegroundColor Cyan
& flutter @args
