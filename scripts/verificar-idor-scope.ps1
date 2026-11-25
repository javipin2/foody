# Verifica SucursalScope: staff de una sede no puede operar otra (403).
# Uso: .\scripts\verificar-idor-scope.ps1

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

$sidPropia = $script:FoodyQaSucursal
$sidOtra = 'c0000000-0000-4000-8000-000000000002'
$hoy = (Get-Date).ToString('yyyy-MM-dd')

Write-Host '=== Verificar IDOR / SucursalScope ===' -ForegroundColor Cyan

$tenantBEmail = $env:FOODY_QA_CROSS_TENANT_ADMIN
$tenantBRama = $env:FOODY_QA_CROSS_TENANT_BRANCH
if (($tenantBEmail -and -not $tenantBRama) -or (-not $tenantBEmail -and $tenantBRama)) {
    throw 'Cross-tenant requiere FOODY_QA_CROSS_TENANT_ADMIN y FOODY_QA_CROSS_TENANT_BRANCH juntos.'
}
if ($tenantBEmail -and $tenantBRama) {
    if ($script:FoodyQaDatabase -notmatch '^foody_diseno_qa_codex_rbac_[a-zA-Z0-9_]+$') {
        throw "Cross-tenant bloqueado: la base '$script:FoodyQaDatabase' no parece un clon RBAC desechable."
    }
    if ($tenantBRama -notmatch '^[0-9a-fA-F-]{36}$') { throw 'FOODY_QA_CROSS_TENANT_BRANCH debe ser un UUID.' }
    if ($tenantBEmail -notmatch '^[a-zA-Z0-9._+-]+@qa\.example$') { throw 'El admin sintético cross-tenant debe usar un correo @qa.example.' }
    $mismoTenant = docker exec $script:FoodyQaDbContainer psql -U postgres -d $script:FoodyQaDatabase -tAc `
        "SELECT CASE WHEN u.restaurante_id = s.restaurante_id THEN 'same' ELSE 'cross' END FROM usuarios u JOIN sucursales s ON s.id='$tenantBRama' WHERE u.email='admin@foody.demo';"
    if ($LASTEXITCODE -ne 0 -or $mismoTenant.Trim() -ne 'cross') {
        throw "Cross-tenant bloqueado: la sucursal no es de un restaurante distinto al admin principal (resultado='$mismoTenant')."
    }
}

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

# La denegacion debe ocurrir antes de cualquier efecto: confirmar que la misma
# caja sigue abierta tras el 403 (el helper bloquea destinos distintos a QA :3001).
$cajaDespues = Invoke-FoodyApi -Method GET `
    -Path "/caja/activa/$sidNorte" `
    -Headers $admin.headers
if (-not ($cajaDespues.ok -and $cajaDespues.json.exito) -or
    $cajaDespues.json.datos.id -ne $cajaNorteId -or
    $cajaDespues.json.datos.estado -ne 'abierta') {
    throw "RBAC-TENANT-01: el rechazo altero la caja. status=$($cajaDespues.status), id=$($cajaDespues.json.datos.id), estado=$($cajaDespues.json.datos.estado)"
}
Write-Host 'OK  caja ajena permanece abierta tras el 403' -ForegroundColor Green

# Modo optativo cross-tenant. Requiere un clon desechable; el admin sintético
# se crea dentro de ese clon y evita mutaciones en la QA persistente.
if ($tenantBEmail -and $tenantBRama) {
    $emailSql = $tenantBEmail.Replace("'", "''")
    $sembrarAdminB = "INSERT INTO usuarios(id,sucursal_id,restaurante_id,nombre,email,rol,activo,hash_contrasena,proveedor_auth,email_verificado,token_version) SELECT gen_random_uuid(),s.id,s.restaurante_id,'Admin QA sintético B','$emailSql','admin',true,a.hash_contrasena,'correo',true,1 FROM sucursales s CROSS JOIN usuarios a WHERE s.id='$tenantBRama' AND a.email='admin@foody.demo' AND NOT EXISTS (SELECT 1 FROM usuarios WHERE email='$emailSql');"
    $seedAdmin = docker exec $script:FoodyQaDbContainer psql -U postgres -d $script:FoodyQaDatabase -v ON_ERROR_STOP=1 -tAc $sembrarAdminB
    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudo crear admin sintético B dentro del clon QA.'
    }

    $tenantB = Get-FoodyToken $tenantBEmail
    $abrirTenantB = Invoke-FoodyApi -Method POST -Path "/caja/abrir?sucursal_id=$tenantBRama" `
        -Headers $tenantB.headers -Body @{ sucursal_id = $tenantBRama; monto_inicial = 50000 }
    $cajaTenantBId = $null
    if ($abrirTenantB.json -and $abrirTenantB.json.exito) {
        $cajaTenantBId = $abrirTenantB.json.datos.id
        if (-not $cajaTenantBId) { $cajaTenantBId = $abrirTenantB.json.datos.caja_id }
    }
    if (-not $cajaTenantBId) {
        $activaTenantB = Invoke-FoodyApi -Method GET -Path "/caja/activa/$tenantBRama" -Headers $tenantB.headers
        if ($activaTenantB.json -and $activaTenantB.json.exito -and $activaTenantB.json.datos) {
            $cajaTenantBId = $activaTenantB.json.datos.id
        }
    }
    if (-not $cajaTenantBId) {
        throw "No se pudo abrir caja sintética tenant B: HTTP $($abrirTenantB.status) $($abrirTenantB.json.mensaje)"
    }

    Assert-403 -Nombre 'cerrar caja de otro tenant (RBAC-TENANT-01)' -Method POST `
        -Path '/caja/cerrar' -Headers $admin.headers -Body @{
            caja_id = $cajaTenantBId
            monto_final_contado = 50000
        }

    $cajaTenantBDespues = Invoke-FoodyApi -Method GET -Path "/caja/activa/$tenantBRama" -Headers $tenantB.headers
    if (-not ($cajaTenantBDespues.ok -and $cajaTenantBDespues.json.exito) -or
        $cajaTenantBDespues.json.datos.id -ne $cajaTenantBId -or
        $cajaTenantBDespues.json.datos.estado -ne 'abierta') {
        throw "RBAC-TENANT-01 cross-tenant: la caja cambió tras el 403. status=$($cajaTenantBDespues.status), estado=$($cajaTenantBDespues.json.datos.estado)"
    }
    Write-Host 'OK  caja de otro tenant permanece abierta tras el 403' -ForegroundColor Green
}

Write-Host 'IDOR scope: OK' -ForegroundColor Green
