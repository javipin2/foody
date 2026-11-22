# Verifica SucursalScope: staff de una sede no puede operar otra (403).
# Uso: .\scripts\verificar-idor-scope.ps1

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

$sidPropia = $script:FoodyQaSucursal
$sidOtra = 'c0000000-0000-4000-8000-000000000002'
$hoy = (Get-Date).ToString('yyyy-MM-dd')

Write-Host '=== Verificar IDOR / SucursalScope ===' -ForegroundColor Cyan

$gerente = Get-FoodyToken 'gerente@foody.demo'
$hGerente = $gerente.headers

function Assert-403 {
    param(
        [string]$Nombre,
        [string]$Method,
        [string]$Path,
        [hashtable]$Headers,
        [object]$Body = $null
    )
    $r = Invoke-FoodyApi -Method $Method -Path $Path -Headers $Headers -Body $Body
    if ($r.status -eq 403) {
        Write-Host "OK  $Nombre -> 403" -ForegroundColor Green
        return
    }
    $msg = if ($r.json) { $r.json.mensaje } else { $r.error }
    throw "$Nombre debia devolver 403, obtuvo $($r.status): $msg"
}

# Gerente sede Centro: lectura operativa otra sede bloqueada
Assert-403 -Nombre 'reportes financiero otra sede' -Method GET `
    -Path "/reportes/financiero?sucursal_id=$sidOtra&desde=$hoy&hasta=$hoy" `
    -Headers $hGerente

Assert-403 -Nombre 'auditoria timeline otra sede' -Method GET `
    -Path "/auditoria/timeline?sucursal_id=$sidOtra&desde=$hoy&hasta=$hoy" `
    -Headers $hGerente

# Escritura otra sede bloqueada (aunque pueda leer inventario hermano)
Assert-403 -Nombre 'config domicilio caja otra sede' -Method PATCH `
    -Path "/domiciliarios-planta/config-domicilio-caja/$sidOtra" `
    -Headers $hGerente -Body @{ ingresa = $true }

# Domiciliario planta: sin permiso reportes
$domi = Get-FoodyToken 'domi@foody.demo'
Assert-403 -Nombre 'domi reportes otra sede' -Method GET `
    -Path "/reportes/financiero?sucursal_id=$sidOtra&desde=$hoy&hasta=$hoy" `
    -Headers $domi.headers

# Misma sede gerente: costeo permitido
$ok = Invoke-FoodyApi -Method GET -Path "/costeo/resumen/$sidPropia" -Headers $hGerente
if (-not ($ok.ok -and $ok.json.exito)) {
    throw "costeo propia sede fallo: $($ok.json.mensaje)"
}
Write-Host 'OK  gerente costeo propia sede -> 200' -ForegroundColor Green

# Admin corporativo puede leer otra sede del mismo restaurante
$admin = Get-FoodyToken 'admin@foody.demo'
$okAdmin = Invoke-FoodyApi -Method GET `
    -Path "/reportes/financiero?sucursal_id=$sidOtra&desde=$hoy&hasta=$hoy" `
    -Headers $admin.headers
if (-not ($okAdmin.ok -and $okAdmin.json.exito)) {
    throw "admin otra sede fallo: $($okAdmin.json.mensaje)"
}
Write-Host 'OK  admin reportes otra sede -> 200' -ForegroundColor Green

# RBAC-TENANT-01: cerrar caja de otra sede por UUID debe 403 (gerente sede Centro)
$sidNorte = 'c0000000-0000-4000-8000-000000000002'
$abrirNorte = Invoke-FoodyApi -Method POST -Path "/caja/abrir?sucursal_id=$sidNorte" `
    -Headers $admin.headers -Body @{
    sucursal_id   = $sidNorte
    monto_inicial = 50000
}
$cajaNorteId = $null
if ($abrirNorte.json -and $abrirNorte.json.exito) {
    $cajaNorteId = $abrirNorte.json.datos.id
    if (-not $cajaNorteId) { $cajaNorteId = $abrirNorte.json.datos.caja_id }
}
if (-not $cajaNorteId) {
    $activaNorte = Invoke-FoodyApi -Method GET -Path "/caja/activa/$sidNorte" -Headers $admin.headers
    if ($activaNorte.json -and $activaNorte.json.exito -and $activaNorte.json.datos) {
        $cajaNorteId = $activaNorte.json.datos.id
    }
}
if (-not $cajaNorteId) {
    throw "No se pudo obtener caja abierta en sede Norte ($sidNorte). abrir=$($abrirNorte.status)/$($abrirNorte.json.error) activa=$($activaNorte.status)"
}
Assert-403 -Nombre 'cerrar caja otra sede (RBAC-TENANT-01)' -Method POST `
    -Path '/caja/cerrar' `
    -Headers $hGerente `
    -Body @{
        caja_id             = $cajaNorteId
        monto_final_contado = 50000
    }

Write-Host 'IDOR scope: OK' -ForegroundColor Green
