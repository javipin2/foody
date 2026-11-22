# Instala/actualiza Ponytail para Cursor (regla .cursor/rules/ponytail.mdc)
# Fuente: https://github.com/DietrichGebert/ponytail
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Dest = Join-Path $Root ".cursor\rules\ponytail.mdc"
$Url = "https://raw.githubusercontent.com/DietrichGebert/ponytail/main/.cursor/rules/ponytail.mdc"

Write-Host "Descargando Ponytail desde $Url ..."
Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
Write-Host "Instalado: $Dest"
Write-Host "Reinicia el chat de Cursor o abre un agente nuevo para aplicar la regla."
