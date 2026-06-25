# Compila APK/AAB por flavor (cliente | equipo).
# Uso: .\scripts\flutter-build-flavor.ps1 -Flavor cliente
#      .\scripts\flutter-build-flavor.ps1 -Flavor equipo -Format appbundle

param(
    [ValidateSet('cliente', 'equipo')]
    [string]$Flavor = 'cliente',

    [ValidateSet('apk', 'appbundle')]
    [string]$Format = 'apk'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$target = if ($Format -eq 'appbundle') { 'appbundle' } else { 'apk' }

$args = @(
    'build', $target,
    '--flavor', $Flavor,
    '--dart-define', "APP_FLAVOR=$Flavor",
    '--release'
)

Write-Host "flutter $($args -join ' ')" -ForegroundColor Cyan
& flutter @args

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($Format -eq 'appbundle') {
    $out = "build\app\outputs\bundle\${Flavor}Release\app-${Flavor}-release.aab"
} else {
    $out = "build\app\outputs\flutter-apk\app-${Flavor}-release.apk"
}

Write-Host ""
Write-Host "Listo: $out" -ForegroundColor Green
Write-Host "Package: app.foody.$Flavor" -ForegroundColor Green
