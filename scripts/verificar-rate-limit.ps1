# Foody — Verificación rápida de rate-limit (429)
# Requiere backend con RATE_LIMIT_FORZAR=1 para que el guard funcione en entorno desarrollo.

$ErrorActionPreference = "Stop"
$Base = "http://localhost:3000/api/v1"

$body = @{
  email      = "admin@foody.demo"
  contrasena = "wrongpass"
} | ConvertTo-Json -Compress -Depth 6

$hit = $false
$ultimoCodigo = $null
for ($i = 0; $i -lt 30; $i = $i + 1) {
  try {
    $headers = @{
      'x-forwarded-for' = '1.2.3.4'
    }
    Invoke-WebRequest -Method Post `
      -Uri ($Base + "/auth/login") `
      -ContentType "application/json" `
      -Headers $headers `
      -Body $body `
      -TimeoutSec 5 | Out-Null
  } catch {
    $code = 0
    $ultimoCodigo = $code
    if ($_.Exception.Response) {
      try {
        $code = [int]$_.Exception.Response.StatusCode.value__
      } catch { }
    }
    $ultimoCodigo = $code

    if ($code -eq 429) {
      Write-Host "HIT 429 at i=$i"
      $hit = $true
      break
    }
  }
  Start-Sleep -Milliseconds 50
}

if (-not $hit) {
  Write-Host "NO 429 (ultimo codigo=$ultimoCodigo)"
  exit 1
}

Write-Host "Verificacion rate-limit OK (429)"
exit 0

