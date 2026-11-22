# Prompt 27 — Fuzz testing de inputs Foody (ASCII-only PS)
# Inputs invalidos / largos / especiales / tipos incorrectos.
# Criterio: no tumbar API; no filtrar stack trace al cliente.
# Uso: .\scripts\verificar-fuzz-inputs.ps1

param(
  [string]$BaseUrl = 'http://127.0.0.1:3000/api/v1',
  [string]$Sucursal = 'c0000000-0000-4000-8000-000000000001'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\qa-helpers.ps1')
$script:FoodyQaBase = $BaseUrl
$script:FoodyQaSucursal = $Sucursal

$Fallos = 0
$Avisos = 0
$Hallazgos = New-Object System.Collections.Generic.List[string]
$Resultados = New-Object System.Collections.Generic.List[object]

function Note([string]$Msg, [string]$Level = 'OK') {
  $color = switch ($Level) {
    'OK' { 'Green' }
    'AVISO' { 'Yellow'; $script:Avisos++ }
    'FALLO' { 'Red'; $script:Fallos++ }
    default { 'Gray' }
  }
  Write-Host "  [$Level] $Msg" -ForegroundColor $color
  $Hallazgos.Add("$Level|$Msg")
}

function Test-StackLeak([string]$Body) {
  if ([string]::IsNullOrEmpty($Body)) { return $false }
  $patterns = @(
    '(?m)^\s*at\s+\w+',
    'node_modules[/\\]',
    'foody_backend[/\\]',
    '\.ts:\d+',
    '\.js:\d+:\d+',
    'QueryFailedError',
    'NestFactory',
    'ExceptionHandler',
    'C:\\Users\\',
    '/Users/',
    '"stack"\s*:',
    'InternalServerErrorException'
  )
  foreach ($p in $patterns) {
    if ($Body -match $p) { return $true }
  }
  return $false
}

function Invoke-Fuzz {
  param(
    [string]$Name,
    [string]$Method = 'GET',
    [string]$Path,
    [hashtable]$Headers = @{},
    [AllowNull()]
    [object]$Body = $null,
    [string]$ContentType = 'application/json'
  )
  $uri = if ($Path.StartsWith('http')) { $Path } else { "$BaseUrl$Path" }
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $status = 0
  $raw = ''
  $connOk = $true
  try {
    # curl.exe lee body de errores mejor que StreamReader de WebException en PS5
    $tmpOut = [IO.Path]::GetTempFileName()
    $tmpErr = [IO.Path]::GetTempFileName()
    $curlArgs = @('-sS', '-o', $tmpOut, '-w', '%{http_code}', '-X', $Method, '--max-time', '60', $uri)
    foreach ($k in $Headers.Keys) {
      $curlArgs += @('-H', ('{0}: {1}' -f $k, $Headers[$k]))
    }
    if ($null -ne $Body -and "$Body" -ne '') {
      $curlArgs += @('-H', "Content-Type: $ContentType", '--data-binary', $Body)
    }
    $codeStr = & curl.exe @curlArgs 2>$tmpErr
    $status = 0
    [void][int]::TryParse("$codeStr".Trim(), [ref]$status)
    if (Test-Path $tmpOut) { $raw = [IO.File]::ReadAllText($tmpOut) } else { $raw = '' }
    Remove-Item $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue
    if ($status -eq 0 -and [string]::IsNullOrEmpty($raw)) {
      $connOk = $false
      $raw = 'curl sin status'
    }
  }
  catch {
    $connOk = $false
    $raw = $_.Exception.Message
  }
  $sw.Stop()

  $leak = Test-StackLeak $raw
  $hasExito = $raw -match '"exito"\s*:'
  $is500 = $status -ge 500
  $ms = $sw.ElapsedMilliseconds
  $level = 'OK'
  $note = "$Name -> HTTP $status (${ms}ms)"

  if (-not $connOk) {
    $level = 'FALLO'
    $note = "$Name -> SIN RESPUESTA: $raw"
  }
  elseif ($leak) {
    $level = 'FALLO'
    $note = "$Name -> STACK/TRACE expuesto (HTTP $status)"
  }
  elseif ($is500) {
    $level = 'AVISO'
    $errCode = ''
    if ($raw -match '"error"\s*:\s*"([^"]+)"') { $errCode = $Matches[1] }
    $note = "$Name -> HTTP 5xx sin stack (error=$errCode) envelope=$hasExito len=$($raw.Length)"
  }
  elseif ($status -eq 0) {
    $level = 'FALLO'
    $note = "$Name -> status 0"
  }
  elseif ($Name -match 'overflow|5k|20k|notas 20k|nombre 5k' -and $status -ge 200 -and $status -lt 300) {
    $level = 'AVISO'
    $note = "$Name -> HTTP $status ACEPTO payload enorme (sin limite aparente)"
  }

  Note $note $level
  $snip = if ($raw.Length -gt 180) { $raw.Substring(0, 180) + '...' } else { $raw }
  $Resultados.Add([pscustomobject]@{
      name      = $Name
      method    = $Method
      path      = $Path
      status    = $status
      ms        = $ms
      leak      = $leak
      conn_ok   = $connOk
      is_5xx    = $is500
      has_exito = $hasExito
      body_snip = $snip
    })
}

function J($obj) { return ($obj | ConvertTo-Json -Depth 8 -Compress) }

Write-Host '=== Foody FUZZ INPUTS (Prompt 27) ===' -ForegroundColor Cyan

$salud0 = Invoke-FoodyApi -Path '/salud'
if (-not ($salud0.ok -and $salud0.json.exito)) { throw 'API caida antes de fuzz' }
Note 'API /salud pre-fuzz OK'

$admin = Get-FoodyToken 'admin@foody.demo'
$token = $admin.token
$auth = @{ Authorization = "Bearer $token" }

$long5k = 'A' * 5000
$long20k = 'X' * 20000
$xss = '<script>alert(1)</script>'
$sql = "'; DROP TABLE pedidos;--"
$emoji = 'BURGER!' * 100
$unicode = 'cn-test-ar' + [char]0x202E + 'rtl'
$uuidBad = 'not-a-uuid'
$uuidFake = '00000000-0000-0000-0000-000000000099'

Write-Host ''
Write-Host '=== A) Auth / public ===' -ForegroundColor Cyan

Invoke-Fuzz -Name 'login email vacio' -Method POST -Path '/auth/login' -Body (J @{ email = ''; contrasena = '' })
Invoke-Fuzz -Name 'login email 5k' -Method POST -Path '/auth/login' -Body (J @{ email = $long5k; contrasena = 'x' })
Invoke-Fuzz -Name 'login tipos wrong' -Method POST -Path '/auth/login' -Body '{"email":123,"contrasena":["a"]}'
Invoke-Fuzz -Name 'login XSS email' -Method POST -Path '/auth/login' -Body (J @{ email = $xss; contrasena = $sql })
Invoke-Fuzz -Name 'login body no-JSON' -Method POST -Path '/auth/login' -Body '<<<not-json>>>'
Invoke-Fuzz -Name 'login Content-Type text' -Method POST -Path '/auth/login' -Body 'email=a&contrasena=b' -ContentType 'text/plain'
Invoke-Fuzz -Name 'login-google token basura' -Method POST -Path '/auth/login-google' -Body (J @{ id_token = $long5k })
Invoke-Fuzz -Name 'registro-restaurante overflow' -Method POST -Path '/auth/registro-restaurante' -Body (J @{
    nombre_restaurante = $long5k
    email              = 'fuzz@test.invalid'
    contrasena         = $long5k
    ciudad_id          = $uuidBad
  })

Write-Host ''
Write-Host '=== B) Paths / query ===' -ForegroundColor Cyan

Invoke-Fuzz -Name 'menu UUID basura' -Method GET -Path "/menu/$uuidBad"
Invoke-Fuzz -Name 'menu path traversal' -Method GET -Path '/menu/../../etc/passwd'
Invoke-Fuzz -Name 'menu XSS path' -Method GET -Path ('/menu/' + [uri]::EscapeDataString($xss))
Invoke-Fuzz -Name 'ciudades q 2k' -Method GET -Path ('/ciudades?q=' + [uri]::EscapeDataString($long5k.Substring(0, 2000)))
Invoke-Fuzz -Name 'geografia q SQL' -Method GET -Path ('/geografia/buscar?q=' + [uri]::EscapeDataString($sql))
Invoke-Fuzz -Name 'menu mesa token raro' -Method GET -Path ('/menu/mesa/' + [uri]::EscapeDataString($emoji.Substring(0, [Math]::Min(40, $emoji.Length))))
$saludJunk = '/salud?' + [uri]::EscapeDataString('x') + '=1' + '&' + 'y=' + [uri]::EscapeDataString('{"a":1}')
Invoke-Fuzz -Name 'salud query junk' -Method GET -Path $saludJunk

Write-Host ''
Write-Host '=== C) Pedidos public ===' -ForegroundColor Cyan

Invoke-Fuzz -Name 'POST pedidos vacio' -Method POST -Path '/pedidos' -Body '{}'
Invoke-Fuzz -Name 'POST pedidos tipos' -Method POST -Path '/pedidos' -Body '{"sucursal_id":1,"items":"no-array","tipo":true}'
Invoke-Fuzz -Name 'POST pedidos items XSS' -Method POST -Path '/pedidos' -Body (J @{
    sucursal_id       = $Sucursal
    tipo              = 'para_llevar'
    items             = @(@{ producto_id = $uuidFake; cantidad = -1; notas = $xss })
    cliente_nombre    = $sql
    idempotency_key   = $long5k.Substring(0, 200)
  })
Invoke-Fuzz -Name 'POST pedidos notas 20k' -Method POST -Path '/pedidos' -Body (J @{
    sucursal_id = $Sucursal
    tipo        = 'para_llevar'
    items       = @(@{ producto_id = $uuidFake; cantidad = 1; notas = $long20k })
  })
Invoke-Fuzz -Name 'GET pedidos/mios device junk' -Method GET -Path ('/pedidos/mios?device_id=' + [uri]::EscapeDataString($sql))
Invoke-Fuzz -Name 'GET estado UUID bad' -Method GET -Path "/pedidos/$uuidBad/estado"

Write-Host ''
Write-Host '=== D) Staff auth — lecturas ===' -ForegroundColor Cyan

Invoke-Fuzz -Name 'pedidos sucursal bad' -Method GET -Path "/pedidos?sucursal_id=$uuidBad" -Headers $auth
Invoke-Fuzz -Name 'pedidos sucursal SQL' -Method GET -Path ('/pedidos?sucursal_id=' + [uri]::EscapeDataString($sql)) -Headers $auth
Invoke-Fuzz -Name 'dashboard suc bad' -Method GET -Path "/dashboard/$uuidBad" -Headers $auth
Invoke-Fuzz -Name 'reportes fechas basura' -Method GET -Path "/reportes/financiero?sucursal_id=$Sucursal&desde=9999-99-99&hasta=nope" -Headers $auth
Invoke-Fuzz -Name 'inventario suc XSS' -Method GET -Path ('/inventario/ingredientes?sucursal_id=' + [uri]::EscapeDataString($xss)) -Headers $auth
Invoke-Fuzz -Name 'usuarios page -1' -Method GET -Path '/usuarios?page=-1&limit=999999' -Headers $auth
Invoke-Fuzz -Name 'analitica canal junk' -Method GET -Path "/analitica/resumen?sucursal_id=$Sucursal&desde=2020-01-01&hasta=2030-01-01&canal=@@@" -Headers $auth

Write-Host ''
Write-Host '=== E) Staff auth — mutaciones ===' -ForegroundColor Cyan

Invoke-Fuzz -Name 'PATCH estado tipos' -Method PATCH -Path "/pedidos/$uuidFake/estado?sucursal_id=$Sucursal" -Headers $auth -Body '{"estado":123,"motivo":true}'
Invoke-Fuzz -Name 'PATCH estado emoji' -Method PATCH -Path "/pedidos/$uuidFake/estado?sucursal_id=$Sucursal" -Headers $auth -Body (J @{ estado = $emoji; motivo = $unicode })
Invoke-Fuzz -Name 'POST caja abrir tipos' -Method POST -Path '/caja/abrir' -Headers $auth -Body '{"sucursal_id":1,"monto_inicial":"mil","arqueo_ciego":"si"}'
Invoke-Fuzz -Name 'POST caja abrir monto neg' -Method POST -Path '/caja/abrir' -Headers $auth -Body (J @{ sucursal_id = $Sucursal; monto_inicial = -999999999 })
Invoke-Fuzz -Name 'PATCH mesa nombre 5k' -Method PATCH -Path "/mesas/$uuidFake" -Headers $auth -Body (J @{ sucursal_id = $Sucursal; nombre = $long5k; capacidad = -5 })
# (evitar POST crear mesa 5k en cada run — FUZZ-LEN-01 ya evidenciado en sesion previa)
Invoke-Fuzz -Name 'PATCH stock tipos' -Method PATCH -Path "/inventario/ingredientes/$uuidFake" -Headers $auth -Body (J @{
    sucursal_id = $Sucursal; stock_nuevo = 'mucho'; motivo_ajuste = $sql
  })
Invoke-Fuzz -Name 'POST productos overflow' -Method POST -Path '/catalogo/productos' -Headers $auth -Body (J @{
    sucursal_id = $Sucursal; nombre = $long5k; precio = 'abc'; categoria_id = $uuidBad
  })
Invoke-Fuzz -Name 'POST promo XSS' -Method POST -Path '/promociones' -Headers $auth -Body (J @{
    sucursal_id = $Sucursal; codigo = $xss; nombre = $sql; tipo = 'porcentaje'; valor = 99999
  })
Invoke-Fuzz -Name 'POST usuarios email XSS' -Method POST -Path '/usuarios' -Headers $auth -Body (J @{
    email = $xss; nombre = 'fuzz'; rol = 'admin'; sucursal_id = $Sucursal; contrasena = '1'
  })
Invoke-Fuzz -Name 'POST zonas poligono junk' -Method POST -Path '/zonas' -Headers $auth -Body (J @{
    sucursal_id = $Sucursal; nombre = 'fuzz'; costo = 'x'; poligono = $long5k
  })
Invoke-Fuzz -Name 'POST finanzas gasto' -Method POST -Path '/finanzas/gastos' -Headers $auth -Body (J @{
    sucursal_id = $Sucursal; monto = 'NaN'; concepto = $long5k; fecha = 'ayer'
  })
Invoke-Fuzz -Name 'DELETE anonimizar device' -Method DELETE -Path ('/dispositivos/anonimizar/' + [uri]::EscapeDataString($sql))

Write-Host ''
Write-Host '=== F) Payloads extremos / parser ===' -ForegroundColor Cyan

Invoke-Fuzz -Name 'POST JSON array root' -Method POST -Path '/auth/login' -Body '[{"email":"a"}]'
Invoke-Fuzz -Name 'POST nested depth' -Method POST -Path '/auth/login' -Body '{"email":{"a":{"b":{"c":{"d":1}}}},"contrasena":null}'
Invoke-Fuzz -Name 'Bearer basura' -Method GET -Path '/auth/perfil' -Headers @{ Authorization = ("Bearer " + $long5k.Substring(0, 2000)) }
Invoke-Fuzz -Name 'Bearer SQL' -Method GET -Path "/pedidos?sucursal_id=$Sucursal" -Headers @{ Authorization = "Bearer $sql" }
$loginHuge = '{"email":"' + $long20k + '@x.com","contrasena":"y"}'
Invoke-Fuzz -Name 'login email 20k' -Method POST -Path '/auth/login' -Body $loginHuge

Write-Host ''
Write-Host '=== G) Post-fuzz salud ===' -ForegroundColor Cyan
Start-Sleep -Milliseconds 400
$salud1 = Invoke-FoodyApi -Path '/salud'
if ($salud1.ok -and $salud1.json.exito -and $salud1.json.datos.base_datos) {
  Note 'API /salud post-fuzz OK (BD viva)'
}
else {
  Note 'API /salud post-fuzz FALLO o BD caida' 'FALLO'
}

$n = $Resultados.Count
$leaks = @($Resultados | Where-Object { $_.leak }).Count
$five = @($Resultados | Where-Object { $_.is_5xx }).Count
$down = @($Resultados | Where-Object { -not $_.conn_ok }).Count
$ok4 = @($Resultados | Where-Object { $_.status -ge 400 -and $_.status -lt 500 }).Count
$ok2 = @($Resultados | Where-Object { $_.status -ge 200 -and $_.status -lt 300 }).Count

Write-Host ''
Write-Host '--- Resumen ---' -ForegroundColor Cyan
Write-Host "  casos=$n  2xx=$ok2  4xx=$ok4  5xx=$five  leaks=$leaks  down=$down"

$out = Join-Path $PSScriptRoot '_tmp_fuzz_inputs.json'
$payload = [ordered]@{
  fecha     = (Get-Date).ToString('o')
  fallos    = $Fallos
  avisos    = $Avisos
  casos     = $n
  ok2xx     = $ok2
  ok4xx     = $ok4
  xx5       = $five
  leaks     = $leaks
  down      = $down
  hallazgos = [string[]]@($Hallazgos)
}
# detalle separado (evitar hashtable anidado raro en ConvertTo-Json PS5)
$payload['detalle'] = @($Resultados | ForEach-Object {
    [ordered]@{
      name = $_.name; method = $_.method; path = $_.path; status = [int]$_.status
      ms = [int]$_.ms; leak = [bool]$_.leak; conn_ok = [bool]$_.conn_ok
      is_5xx = [bool]$_.is_5xx; body_snip = [string]$_.body_snip
    }
  })
($payload | ConvertTo-Json -Depth 6) | Set-Content -Path $out -Encoding UTF8
Write-Host ''
Write-Host "JSON: $out"
# Nota: mesas con nombre enorme pueden quedar de runs previos (FUZZ-LEN-01); limpiar a mano si hace falta.

if ($Fallos -gt 0) {
  Write-Host ''
  Write-Host "Verificacion fuzz FALLO (fallos=$Fallos avisos=$Avisos)" -ForegroundColor Red
  exit 1
}
Write-Host ''
Write-Host "Verificacion fuzz OK (avisos=$Avisos)" -ForegroundColor Green
exit 0
