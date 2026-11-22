# Verifica Flutter UI (analyze + archivos criticos).
# Uso: .\scripts\verificar-flutter-ui.ps1

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent

Write-Host '=== Verificar Flutter UI ===' -ForegroundColor Cyan

Push-Location $raiz
try {
    $prevEa = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $salida = flutter analyze lib/features lib/core --no-fatal-infos 2>&1 | Out-String
    $ErrorActionPreference = $prevEa
    Write-Host $salida
    if ($salida -match '(?m)^\s*error -') {
        Write-Host 'flutter analyze: errores encontrados' -ForegroundColor Red
        exit 1
    }
    if ($salida -match '(?m)^\s*warning -') {
        Write-Host 'flutter analyze: warnings encontrados' -ForegroundColor Red
        exit 1
    }
    Write-Host 'flutter analyze lib/features lib/core: OK' -ForegroundColor Green
}
finally {
    Pop-Location
}

# Puerta API antes de QA manual UI
& "$PSScriptRoot\verificar-qa-manual.ps1" -SoloApi
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ''
Write-Host 'Flutter UI listo para QA manual:' -ForegroundColor Green
Write-Host '  Cliente:  .\scripts\flutter-run-flavor.ps1 -Flavor cliente -Device chrome -WebPort 8081'
Write-Host '  Staff:    .\scripts\flutter-run-flavor.ps1 -Flavor equipo -Device chrome -WebPort 8080'
Write-Host '  Checklist: docs\CHECKLIST_QA_ROLES.md'
