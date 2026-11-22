# Permisos por usuario (override del rol). Uso: .\scripts\verificar-usuario-permisos.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar usuario_permisos (checklist por usuario) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$h = $admin.headers
$sid = $script:FoodyQaSucursal
$script:fallos = 0

function Assert-Ok {
    param([bool]$Cond, [string]$Msg)
    if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
    else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

# Tabla existe
$tbl = docker exec supabase-db psql -U postgres -d postgres -t -A -c "SELECT to_regclass('public.usuario_permisos')" 2>$null
Assert-Ok -Cond (($tbl -as [string]).Trim() -eq 'usuario_permisos') -Msg "Tabla usuario_permisos existe"

$cat = Invoke-FoodyApi -Method GET -Path '/usuarios/catalogo-roles' -Headers $h
Assert-Ok -Cond ($cat.ok -and $cat.json.exito) -Msg 'GET catalogo-roles'
$disp = @($cat.json.datos.permisos_disponibles)
Assert-Ok -Cond ($disp.Count -ge 10) -Msg "permisos_disponibles ($($disp.Count))"
Assert-Ok -Cond ($disp -contains 'crear_pedido') -Msg 'catalogo incluye crear_pedido'

$email = "qa.perm.$([guid]::NewGuid().ToString('N').Substring(0,8))@foody.demo"
$crear = Invoke-FoodyApi -Method POST -Path '/usuarios' -Headers $h -Body @{
    sucursal_id = $sid
    nombre      = 'QA Permisos'
    email       = $email
    contrasena  = '123456'
    rol         = 'mesero'
    permisos    = @('ver_pedidos', 'crear_pedido', 'gestionar_mesas')
}
Assert-Ok -Cond ($crear.ok -and $crear.json.exito) -Msg "Crear mesero con permisos custom (status=$($crear.status))"
$uid = $crear.json.datos.id
$permsCrear = @($crear.json.datos.permisos)
Assert-Ok -Cond ($permsCrear -contains 'crear_pedido') -Msg 'Respuesta crear incluye crear_pedido'
Assert-Ok -Cond (-not ($permsCrear -contains 'aprobar_pedido_mesa')) -Msg 'Sin aprobar_pedido_mesa (no marcado)'

$getP = Invoke-FoodyApi -Method GET -Path "/usuarios/$uid/permisos?sucursal_id=$sid" -Headers $h
Assert-Ok -Cond ($getP.ok -and $getP.json.exito -and $getP.json.datos.personalizado -eq $true) -Msg 'GET permisos personalizado=true'

# Login del usuario nuevo y comprobar claim efectivo vía un endpoint con RolGuard
$loginU = Invoke-FoodyApi -Method POST -Path '/auth/login' -Body @{
    email      = $email
    contrasena = '123456'
}
Assert-Ok -Cond ($loginU.ok -and $loginU.json.exito) -Msg 'Login usuario custom'
$hu = @{ Authorization = "Bearer $($loginU.json.datos.token)" }
$loginPerms = @($loginU.json.datos.permisos)
Assert-Ok -Cond ($loginPerms -contains 'crear_pedido') -Msg 'JWT login tiene crear_pedido'
Assert-Ok -Cond (-not ($loginPerms -contains 'aprobar_pedido_mesa')) -Msg 'JWT login sin aprobar_pedido_mesa'

# Otro mesero seed sin custom no se ve afectado (plantilla)
$mesero = Get-FoodyToken 'mesero@foody.com'
$hm = $mesero.headers
# perfil o login ya trae permisos del rol
$loginM = Invoke-FoodyApi -Method POST -Path '/auth/login' -Body @{
    email      = 'mesero@foody.com'
    contrasena = $script:FoodyQaPass
}
$mp = @($loginM.json.datos.permisos)
Assert-Ok -Cond ($mp -contains 'aprobar_pedido_mesa' -or $mp -contains 'ver_pedidos') -Msg 'Mesero seed sigue con plantilla de rol'

# PATCH quitar crear_pedido
$patch = Invoke-FoodyApi -Method PATCH -Path "/usuarios/${uid}?sucursal_id=$sid" -Headers $h -Body @{
    permisos = @('ver_pedidos', 'gestionar_mesas')
}
Assert-Ok -Cond ($patch.ok -and $patch.json.exito) -Msg 'PATCH permisos'
$pp = @($patch.json.datos.permisos)
Assert-Ok -Cond (-not ($pp -contains 'crear_pedido')) -Msg 'Tras PATCH ya no tiene crear_pedido'

# Error: permiso inventado
$bad = Invoke-FoodyApi -Method PATCH -Path "/usuarios/${uid}?sucursal_id=$sid" -Headers $h -Body @{
    permisos = @('ver_pedidos', 'permiso_inventado_xyz')
}
Assert-Ok -Cond ((-not $bad.ok) -or (-not $bad.json.exito)) -Msg "Permiso inventado rechazado (status=$($bad.status))"

# Error: permiso de otro rol (caja en mesero)
$caja = Invoke-FoodyApi -Method PATCH -Path "/usuarios/${uid}?sucursal_id=$sid" -Headers $h -Body @{
    permisos = @('ver_pedidos', 'abrir_caja')
}
Assert-Ok -Cond ((-not $caja.ok) -or (-not $caja.json.exito)) -Msg "abrir_caja en mesero rechazado (status=$($caja.status))"

# Cleanup
$null = docker exec supabase-db psql -U postgres -d postgres -c "DELETE FROM usuario_permisos WHERE usuario_id = '$uid'; DELETE FROM usuarios WHERE id = '$uid';" 2>$null

Write-Host ''
if ($script:fallos -gt 0) {
    Write-Host "FALLOS: $($script:fallos)" -ForegroundColor Red
    exit 1
}
Write-Host 'usuario_permisos OK' -ForegroundColor Green
exit 0
