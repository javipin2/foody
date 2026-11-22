# Usado por iniciar-foody-subdominios.bat — exit 0 si /salud OK
$ErrorActionPreference = 'Stop'
try {
  $s = Invoke-RestMethod 'http://localhost:3000/api/v1/salud' -TimeoutSec 5
  if (-not $s.exito) { exit 1 }
  exit 0
} catch {
  exit 1
}
