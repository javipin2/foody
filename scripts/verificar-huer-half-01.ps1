# Foody — HUER-HALF-01: DIAN pausado no debe mostrar claim legal (Resolución DIAN) en PDF/HTML
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verificar-huer-half-01.ps1

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar HUER-HALF-01 (DIAN pausado sin Resolución DIAN) ===' -ForegroundColor Cyan

$salud = Invoke-FoodyApi -Path '/salud' -Headers (Get-FoodyToken 'admin@foody.demo').headers
if (-not ($salud.ok -and $salud.json.exito)) { throw 'API /salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

# Subir plan temporalmente (facturacion está gated por plan en QA).
$RestId = 'b0000000-0000-4000-8000-000000000001'

function Sql-Scalar([string]$Sql) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $raw = docker exec supabase-db psql -U postgres -d postgres -t -A -c $Sql 2>$null
  $ErrorActionPreference = $prev
  return ($raw -as [string]).Trim()
}

$planAntes = Sql-Scalar "SELECT plan FROM suscripciones_restaurante WHERE restaurante_id='$RestId' LIMIT 1;"
$null = Sql-Scalar "UPDATE suscripciones_restaurante SET plan='enterprise' WHERE restaurante_id='$RestId';"

try {
  $admin = Get-FoodyToken 'admin@foody.demo'
  $h = $admin.headers
  $sid = $script:FoodyQaSucursal

  $lista = Invoke-FoodyApi -Path "/facturacion/facturas/$sid" -Headers $h
  if (-not ($lista.ok -and $lista.json.exito)) { throw "GET facturas fallo: $($lista.json.mensaje)" }

  $datos = @($lista.json.datos)
  if ($datos.Count -eq 0) {
    Write-Host 'No hay facturas para la sede de QA; saltando verificación.' -ForegroundColor Yellow
    exit 0
  }

  $fac = $datos[0]
  $facId = [string]$fac.id
  Write-Host ("Usando factura: " + $facId) -ForegroundColor DarkGray

  $pdf = Invoke-FoodyApi -Path "/facturacion/facturas/$facId/pdf?sucursal_id=$sid" -Headers $h
  if (-not ($pdf.ok -and $pdf.json.exito)) { throw "GET pdf fallo: $($pdf.json.mensaje)" }

  $html = ''
  if ($pdf.json.datos.html) { $html = [string]$pdf.json.datos.html }
  elseif ($pdf.json.datos.contenido) { $html = [string]$pdf.json.datos.contenido }
  elseif ($pdf.json.datos -is [string]) { $html = [string]$pdf.json.datos }

  if ($html.Length -lt 80) { throw 'HTML/PDF vacío o demasiado corto' }

  $hasResol = ($html -match 'Resoluci[oó]n DIAN')
  # Nota: el contenido puede llegar con mojibake en Windows PowerShell.
  # Verificamos por frases robustas sin depender de tildes.
  $hasPaused = ($html -match 'DIAN') -and ($html -match 'pausad') -and ($html -match 'CUFE/XML')
  $hasFoody = ($html -match 'Generado por Foody')

  if ($hasPaused -and -not $hasResol -and $hasFoody) {
    Write-Host 'Verificacion HUER-HALF-01 OK (exit 0)' -ForegroundColor Green
    exit 0
  }

  Write-Host 'Verificacion HUER-HALF-01 FALLO (exit 1)' -ForegroundColor Red
  Write-Host ("hasPaused=" + $hasPaused + " hasResol=" + $hasResol + " hasFoody=" + $hasFoody) -ForegroundColor Red
  $idx = $html.IndexOf('DIAN')
  if ($idx -ge 0) {
    $len = [Math]::Min(250, $html.Length - $idx)
    Write-Host ("DIAN snippet: " + $html.Substring($idx, $len)) -ForegroundColor DarkYellow
  }
  exit 1
} finally {
  if ($planAntes) {
    $null = Sql-Scalar "UPDATE suscripciones_restaurante SET plan='$planAntes' WHERE restaurante_id='$RestId';"
    Write-Host ("Plan restaurado: " + $planAntes) -ForegroundColor DarkGray
  }
}

