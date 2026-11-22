# P2-17 — catálogo roles, PATCH editar staff
# Uso: .\scripts\verificar-usuarios-editar.ps1

$ErrorActionPreference = 'Stop'
$base = 'http://localhost:3000/api/v1'
$sid = 'c0000000-0000-4000-8000-000000000001'

function Login-Staff {
  param([string]$Email, [string]$Pass = '123456')
  $body = @{ email = $Email; contrasena = $Pass } | ConvertTo-Json
  $r = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -Body $body -ContentType 'application/json'
  if (-not $r.exito) { throw $r.mensaje }
  return $r.datos
}

Write-Host '=== P2-17 usuarios: catalogo + PATCH editar ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 5
if (-not $salud.exito) { throw 'API no responde' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Login-Staff 'admin@foody.demo'
$h = @{ Authorization = "Bearer $($admin.token)" }

$cat = Invoke-RestMethod -Uri "$base/usuarios/catalogo-roles" -Headers $h
if (-not $cat.exito) { throw $cat.mensaje }
$roles = @($cat.datos.roles)
if ($roles.Count -lt 3) { throw 'Catálogo de roles incompleto' }
Write-Host "OK GET catalogo-roles ($($roles.Count) roles)" -ForegroundColor Green

$lista = Invoke-RestMethod -Uri "$base/usuarios?sucursal_id=$sid" -Headers $h
$staff = @($lista.datos | Where-Object { $_.rol -ne 'admin' })
if ($staff.Count -eq 0) {
  $crear = @{
    sucursal_id = $sid
    nombre      = 'QA Editar Temp'
    email       = "qa-editar-$(Get-Date -Format 'HHmmss')@foody.test"
    contrasena  = '123456'
    rol         = 'cajero'
  } | ConvertTo-Json
  $nuevo = Invoke-RestMethod -Uri "$base/usuarios" -Method POST -Headers $h -Body $crear -ContentType 'application/json'
  if (-not $nuevo.exito) { throw $nuevo.mensaje }
  $staff = @($nuevo.datos)
  Write-Host 'OK usuario temporal creado para prueba' -ForegroundColor Yellow
}

$u = $staff[0]
$uid = $u.id
$nombreOrig = $u.nombre
$rolOrig = $u.rol
$nuevoNombre = if ($nombreOrig -like '* QA') { $nombreOrig.TrimEnd(' QA') } else { "$nombreOrig QA" }
$nuevoRol = if ($rolOrig -eq 'mesero') { 'cajero' } else { 'mesero' }

$patchBody = @{
  nombre = $nuevoNombre
  rol    = $nuevoRol
} | ConvertTo-Json

$patchUri = "$base/usuarios/$($uid)?sucursal_id=$($sid)"
$edit = Invoke-RestMethod -Uri $patchUri -Method PATCH -Headers $h -Body $patchBody -ContentType 'application/json'
if (-not $edit.exito) { throw $edit.mensaje }
if ($edit.datos.rol -ne $nuevoRol) { throw 'Rol no actualizado' }
if ($edit.datos.nombre -ne $nuevoNombre) { throw 'Nombre no actualizado' }
if (-not $edit.datos.permisos) { throw 'Respuesta sin permisos del rol' }
Write-Host "OK PATCH editar ($nuevoRol, $($edit.datos.permisos.Count) permisos)" -ForegroundColor Green

$revert = @{
  nombre = $nombreOrig
  rol    = $rolOrig
} | ConvertTo-Json
Invoke-RestMethod -Uri "$base/usuarios/$($uid)?sucursal_id=$($sid)" -Method PATCH -Headers $h -Body $revert -ContentType 'application/json' | Out-Null
Write-Host 'OK revertido a estado original' -ForegroundColor Green

Write-Host '=== P2-17 usuarios editar: OK ===' -ForegroundColor Cyan
