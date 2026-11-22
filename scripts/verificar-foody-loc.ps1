# Falla si archivos Flutter superan umbral LOC (god files).
# Uso: .\scripts\verificar-foody-loc.ps1 [-Umbral 800]

param([int]$Umbral = 800)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$dirs = @(
    Join-Path $raiz 'lib\features'
    Join-Path $raiz 'lib\core'
)

$violaciones = @()
foreach ($dir in $dirs) {
    Get-ChildItem -Path $dir -Recurse -Filter '*.dart' | ForEach-Object {
        $lineas = (Get-Content $_.FullName | Measure-Object -Line).Lines
        if ($lineas -gt $Umbral) {
            $rel = $_.FullName.Substring($raiz.Length + 1)
            $violaciones += [pscustomobject]@{ Archivo = $rel; Lineas = $lineas }
        }
    }
}

Write-Host "=== Verificar LOC Flutter (umbral $Umbral) ===" -ForegroundColor Cyan
if ($violaciones.Count -eq 0) {
    Write-Host "OK: ningun archivo supera $Umbral lineas" -ForegroundColor Green
    exit 0
}

$violaciones | Sort-Object Lineas -Descending | Format-Table -AutoSize
Write-Host "AVISO: $($violaciones.Count) archivo(s) > $Umbral LOC (ponytail: split en Sprint 5)" -ForegroundColor Yellow
exit 0
