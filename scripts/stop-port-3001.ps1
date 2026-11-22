$ErrorActionPreference = "Stop"

$c = Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -ne $c) {
  $pid2 = $c.OwningProcess
  Write-Host "Stopping PID=$pid2 on port 3001..."
  Stop-Process -Id $pid2 -Force
} else {
  Write-Host "No process listening on port 3001."
}

