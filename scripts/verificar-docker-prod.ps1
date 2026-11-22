# Valida docker-compose.prod.yml sin VPS (build + config + health)
# Uso: .\scripts\verificar-docker-prod.ps1
#        .\scripts\verificar-docker-prod.ps1 -Levantar   # up -d y prueba /health

param(
    [switch]$Levantar
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$compose = Join-Path $raiz 'docker-compose.prod.yml'

Write-Host '=== Verificar Docker produccion (P3-06) ===' -ForegroundColor Cyan

if (-not (Test-Path $compose)) {
    Write-Host "FALLO: no existe $compose" -ForegroundColor Red
    exit 1
}
Write-Host 'OK docker-compose.prod.yml existe' -ForegroundColor Green

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'FALLO: Docker no responde' -ForegroundColor Red
    exit 1
}
Write-Host 'OK Docker activo' -ForegroundColor Green

Push-Location $raiz
try {
    $prevEa = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    docker compose -f docker-compose.prod.yml config 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'docker compose config fallo' }
    Write-Host 'OK docker compose config valido' -ForegroundColor Green

    Write-Host 'Compilando imagen backend (puede tardar 2-5 min)...' -ForegroundColor DarkGray
    docker compose -f docker-compose.prod.yml build backend 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'docker compose build fallo' }
    Write-Host 'OK imagen backend construida' -ForegroundColor Green

    $ErrorActionPreference = $prevEa

    if (-not $Levantar) {
        Write-Host ''
        Write-Host 'Docker prod OK (solo build). Usa -Levantar para probar contenedor.' -ForegroundColor Green
        exit 0
    }

    # Levantar contenedor (requiere foody_backend/.env con DATABASE_URL valido)
    $envFile = Join-Path $raiz 'foody_backend\.env'
    if (-not (Test-Path $envFile)) {
        Write-Host 'AVISO: foody_backend/.env no existe - copia desde .env.example' -ForegroundColor Yellow
    }

    docker compose -f docker-compose.prod.yml up -d backend
    if ($LASTEXITCODE -ne 0) { throw 'docker compose up fallo' }

    $ok = $false
    for ($i = 0; $i -lt 24; $i++) {
        Start-Sleep -Seconds 5
        try {
            $h = Invoke-RestMethod -Uri 'http://localhost:3000/api/v1/health' -TimeoutSec 5
            if ($h.exito -and $h.datos.base_datos) {
                Write-Host "OK contenedor /health estado=$($h.datos.estado)" -ForegroundColor Green
                $ok = $true
                break
            }
        }
        catch { }
    }

    docker compose -f docker-compose.prod.yml stop backend | Out-Null

    if (-not $ok) {
        Write-Host 'FALLO: contenedor no respondio /health en 2 min' -ForegroundColor Red
        exit 1
    }

    Write-Host 'Docker prod OK (build + up + health)' -ForegroundColor Green
    exit 0
}
finally {
    Pop-Location
}
