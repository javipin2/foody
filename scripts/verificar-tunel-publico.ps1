$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
Set-Location $raiz
. (Join-Path $PSScriptRoot '_foody-entorno.ps1')

$rutas = @(
  @{ Nombre = 'Cliente'; Url = "$FoodyUrlApp/" },
  @{ Nombre = 'Equipo'; Url = "$FoodyUrlEquipo/admin/login" },
  @{ Nombre = 'API'; Url = "$FoodyUrlApi/api/v1/salud" }
)
$fallos = @()

foreach ($ruta in $rutas) {
  $verificado = $false
  $detalle = 'sin respuesta HTTP'
  for ($intento = 1; $intento -le 3; $intento++) {
    try {
      $respuesta = Invoke-WebRequest -Uri $ruta.Url -UseBasicParsing -TimeoutSec 12
      if ([int]$respuesta.StatusCode -eq 200) {
        $verificado = $true
        break
      }
      $detalle = "HTTP $([int]$respuesta.StatusCode)"
    } catch {
      $respuesta = $_.Exception.Response
      $status = if ($respuesta) { [int]$respuesta.StatusCode } else { 0 }
      $body = $_.ErrorDetails.Message
      $codigoTunnel = if ($body -match 'error code:\s*(\d+)') { $Matches[1] } else { $null }
      $detalle = if ($codigoTunnel) { "HTTP $status (Cloudflare $codigoTunnel)" } elseif ($status) { "HTTP $status" } else { $_.Exception.Message }
      if ($status -eq 530 -and $codigoTunnel -eq '1033') { break }
    }
    if ($intento -lt 3) { Start-Sleep -Seconds 2 }
  }

  if ($verificado) {
    Write-Host "OK Tunnel $($ruta.Nombre) $($ruta.Url)" -ForegroundColor Green
  } else {
    Write-Host "FAIL Tunnel $($ruta.Nombre): $detalle" -ForegroundColor Red
    $fallos += $ruta.Nombre
  }
}

if ($fallos.Count -gt 0) {
  Write-Host 'cloudflared puede existir como proceso sin estar publicando estas rutas.' -ForegroundColor Yellow
  Write-Host 'Reinicia el conector con scripts\iniciar1\iniciar-cloudflare-tunnel.ps1 y vuelve a verificar.' -ForegroundColor Yellow
  exit 1
}
