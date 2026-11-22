# Compat: modo local desde la misma fuente
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'sincronizar-entorno.ps1') -Modo local
