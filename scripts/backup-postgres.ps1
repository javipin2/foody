# Backup PostgreSQL Foody (dev Docker o conexion directa).
# Uso:
#   .\scripts\backup-postgres.ps1
#   .\scripts\backup-postgres.ps1 -Destino .\backups -RetencionDias 14
# VPS/Linux: scripts/backup-postgres.sh (cron + offsite). Doc: docs/BACKUPS_FOODY.md

param(
    [string]$Destino = '',
    [string]$Contenedor = 'supabase-db',
    [string]$Db = 'postgres',
    [string]$Usuario = 'postgres',
    [int]$RetencionDias = 14
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
if (-not $Destino) {
    $Destino = Join-Path $raiz 'backups'
}
if (-not (Test-Path $Destino)) {
    New-Item -ItemType Directory -Path $Destino | Out-Null
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$archivo = Join-Path $Destino "foody_db-$stamp.sql"

Write-Host "=== Backup PostgreSQL -> $archivo ===" -ForegroundColor Cyan

$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($docker) {
    $running = docker ps --filter "name=$Contenedor" --format '{{.Names}}' 2>$null
    if ($running -eq $Contenedor) {
        docker exec $Contenedor pg_dump -U $Usuario -d $Db --no-owner --no-acl -f "/tmp/foody_backup.sql"
        if ($LASTEXITCODE -ne 0) { throw 'pg_dump en contenedor fallo' }
        docker cp "${Contenedor}:/tmp/foody_backup.sql" $archivo
        if ($LASTEXITCODE -ne 0) { throw 'docker cp fallo' }
        $size = (Get-Item $archivo).Length
        Write-Host "OK backup ($size bytes)" -ForegroundColor Green
        if ($RetencionDias -gt 0) {
            Get-ChildItem $Destino -Filter 'foody_db-*.sql*' |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetencionDias) } |
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "Retencion: borrados dumps > $RetencionDias dias" -ForegroundColor DarkGray
        }
        exit 0
    }
}

# Fallback: pg_dump local
$pgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
if (-not $pgDump) {
    throw "No hay contenedor $Contenedor ni pg_dump en PATH"
}
if (-not $env:PGPASSWORD) { $env:PGPASSWORD = '' }
& pg_dump -h localhost -U $Usuario -d $Db --no-owner --no-acl -f $archivo
if ($LASTEXITCODE -ne 0) { throw 'pg_dump local fallo' }
Write-Host "OK backup local ($((Get-Item $archivo).Length) bytes)" -ForegroundColor Green
if ($RetencionDias -gt 0) {
    Get-ChildItem $Destino -Filter 'foody_db-*.sql*' |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetencionDias) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
