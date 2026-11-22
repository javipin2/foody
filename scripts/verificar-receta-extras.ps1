# Smoke: recetas en bebidas/toppings (costeo + configurar)
# Uso: .\scripts\verificar-receta-extras.ps1

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'scripts\lib\qa-helpers.ps1')

$ok = 0
$fail = 0
function Pass([string]$m) { $script:ok++; Write-Host "OK  $m" -ForegroundColor Green }
function Fail([string]$m) { $script:fail++; Write-Host "FAIL $m" -ForegroundColor Red }

$auth = Get-FoodyToken -Email 'admin@foody.demo'
$h = $auth.headers
$sid = $script:FoodyQaSucursal

$salud = Invoke-FoodyApi -Path '/salud'
if ($salud.ok -and $salud.json.exito) { Pass 'API salud' } else { Fail 'API salud'; exit 1 }

$resumen = Invoke-FoodyApi -Path "/costeo/resumen/$sid" -Headers $h
if (-not ($resumen.ok -and $resumen.json.exito)) {
  Fail "resumen costeo: $($resumen.error)"
  exit 1
}
$datos = $resumen.json.datos
if ($null -eq $datos.bebidas) { Fail 'resumen sin campo bebidas' } else { Pass "resumen bebidas ($($datos.bebidas.Count))" }
if ($null -eq $datos.toppings) { Fail 'resumen sin campo toppings' } else { Pass "resumen toppings ($($datos.toppings.Count))" }

$bebidas = Invoke-FoodyApi -Path "/bebidas/$sid" -Headers $h
if (-not ($bebidas.ok -and $bebidas.json.exito)) {
  Fail "listar bebidas status=$($bebidas.status) $($bebidas.error)"
  exit 1
}
$beb = @($bebidas.json.datos) | Select-Object -First 1
if (-not $beb) {
  Fail 'no hay bebidas demo para probar'
  exit 1
}
Pass "bebida demo: $($beb.nombre)"

$ings = Invoke-FoodyApi -Path "/inventario/$sid" -Headers $h
if (-not ($ings.ok -and $ings.json.exito)) {
  Fail "listar inventario"
  exit 1
}
$ing = @($ings.json.datos) | Where-Object { $_.activo -ne $false } | Select-Object -First 1
if (-not $ing) {
  Fail 'no hay insumos'
  exit 1
}
Pass "insumo: $($ing.nombre) ($($ing.unidad_base))"

$body = @{
  producto_id  = $beb.id
  tipo_entidad = 'bebida'
  margen_error = 0.05
  items        = @(
    @{
      tipo_item      = 'ingrediente'
      ingrediente_id = $ing.id
      cantidad       = 0.05
      unidad         = $ing.unidad_base
    }
  )
}
$cfg = Invoke-FoodyApi -Method POST -Path '/inventario/producto-ingredientes' -Headers $h -Body $body
if ($cfg.ok -and $cfg.json.exito) {
  Pass "configurar receta bebida $($beb.nombre) costo=$($cfg.json.datos.costo_calculado)"
} else {
  Fail "configurar receta: $($cfg.json.mensaje) $($cfg.json.error) $($cfg.error)"
}

$get = Invoke-FoodyApi -Path "/inventario/producto-ingredientes/$($beb.id)?tipo_entidad=bebida" -Headers $h
if ($get.ok -and $get.json.exito -and $get.json.datos.receta_id) {
  Pass 'GET receta bebida'
} else {
  Fail 'GET receta bebida'
}

$imp = Invoke-FoodyApi -Path "/costeo/productos/$($beb.id)/impacto-stock?sucursal_id=$sid&tipo_entidad=bebida" -Headers $h
if ($imp.ok -and $imp.json.exito -and $imp.json.datos.tiene_receta) {
  Pass "impacto stock bebida (ings=$($imp.json.datos.ingredientes.Count))"
} else {
  Fail "impacto stock bebida"
}

Write-Host ""
Write-Host "Resultado: $ok OK / $fail FAIL" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Yellow' })
exit $(if ($fail -eq 0) { 0 } else { 1 })
