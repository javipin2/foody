# Programa backup diario de Postgres en Windows (Task Scheduler).
# Uso (PowerShell como Admin recomendado):
#   .\scripts\programar-backup-windows.ps1
#   .\scripts\programar-backup-windows.ps1 -Hora '03:00' -RetencionDias 14
# Quitar: Unregister-ScheduledTask -TaskName 'FoodyBackupPostgres' -Confirm:$false

param(
  [string]$Hora = '03:00',
  [int]$RetencionDias = 14,
  [string]$NombreTarea = 'FoodyBackupPostgres'
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$scriptBackup = Join-Path $PSScriptRoot 'backup-postgres.ps1'
if (-not (Test-Path $scriptBackup)) { throw "Falta $scriptBackup" }

$destino = Join-Path $raiz 'backups'
$arg = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptBackup`" -Destino `"$destino`" -RetencionDias $RetencionDias"

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg -WorkingDirectory $raiz
$trigger = New-ScheduledTaskTrigger -Daily -At $Hora
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $NombreTarea -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "OK tarea '$NombreTarea' diaria a las $Hora" -ForegroundColor Green
Write-Host "  Script: $scriptBackup"
Write-Host "  Destino: $destino (retencion $RetencionDias dias)"
Write-Host "  Doc VPS cron: docs/BACKUPS_FOODY.md"
