# Compat: redirige a la fuente única config/foody-entorno.env
# Uso: .\scripts\sincronizar-url-tunel.ps1   →  sincronizar-entorno -Modo tunel

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'sincronizar-entorno.ps1') -Modo tunel
