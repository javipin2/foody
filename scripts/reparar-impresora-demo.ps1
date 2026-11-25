# Ajusta impresora demo para modo archivo (QA sin hardware).
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"
Assert-FoodyQaDisposable
$sql = Join-Path $PSScriptRoot 'reparar-impresora-demo.sql'
Get-Content $sql -Raw | docker exec -i $script:FoodyQaDbContainer psql -U postgres -d $script:FoodyQaDatabase -v ON_ERROR_STOP=1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar la impresora demo dentro del clon QA.' }
Write-Host 'OK impresora demo -> modo archivo (ip_local NULL)' -ForegroundColor Green
