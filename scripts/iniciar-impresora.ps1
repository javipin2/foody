# Inicia el agente Python de impresión (modo archivo — sin impresora física)
# Uso: .\scripts\iniciar-impresora.ps1
$ErrorActionPreference = 'Stop'
$dir = Join-Path (Split-Path $PSScriptRoot -Parent) 'foody_python_printer'
Set-Location $dir

Write-Host 'Instalando dependencias Python...' -ForegroundColor Cyan
python -m pip install -r requirements.txt -q

$env:FOODY_PRINTER_MODE = 'archivo'
Write-Host 'Foody Printer (modo archivo) en ws://127.0.0.1:8765' -ForegroundColor Green
Write-Host 'Tickets en foody_python_printer\tickets\' -ForegroundColor DarkGray
python main.py
