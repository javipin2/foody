# Ajusta impresora demo para modo archivo (QA sin hardware).
$ErrorActionPreference = 'Stop'
$sql = Join-Path $PSScriptRoot 'reparar-impresora-demo.sql'
Get-Content $sql -Raw | docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 | Out-Null
Write-Host 'OK impresora demo -> modo archivo (ip_local NULL)' -ForegroundColor Green
