# Foody — HUER-REPO-03: editar costo fijo
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verificar-huer-repo-03.ps1
#
# Nota: en Windows PowerShell hay casos donde `Invoke-WebRequest/Invoke-RestMethod` terminan enviando un JSON
# que Express rechaza (400) aunque el endpoint sea válido. Para evitar falsos negativos, aquí hacemos el
# `PATCH` con `node fetch`, que sí reproduce correctamente el request.

$ErrorActionPreference = "Continue"

Write-Host "=== Verificar HUER-REPO-03 (editar costo fijo) ==="

node -e @"
(async () => {
  const BASE = 'http://localhost:3000/api/v1';
  const SUCURSAL = 'c0000000-0000-4000-8000-000000000001';
  const PASS = '123456';

  function assert(cond, msg) {
    if (!cond) { console.log('FALLO', msg); process.exitCode = 1; }
    else { console.log('OK   ', msg); }
  }

  const salud = await fetch(BASE + '/salud');
  const saludJ = await salud.json();
  assert(saludJ && saludJ.exito === true, 'API /salud');

  const login = await fetch(BASE + '/auth/login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'admin@foody.demo', contrasena: PASS }),
  });
  const loginJ = await login.json();
  assert(loginJ && loginJ.exito === true, 'login admin demo');
  const token = loginJ.datos.token;
  const auth = { Authorization: 'Bearer ' + token };

  const listRes = await fetch(BASE + '/finanzas/costos-fijos/' + SUCURSAL, { headers: auth });
  const listJ = await listRes.json();
  assert(listJ && listJ.exito === true, 'GET /finanzas/costos-fijos');
  const items = listJ.datos || [];
  assert(items.length > 0, 'hay costos fijos (n=' + items.length + ')');
  if (!items.length) process.exit(0);

  const fijo = items[0];
  const id = fijo.id;
  const montoOriginal = Number(fijo.monto_mensual);
  const montoNuevo = montoOriginal + 1;

  const patchRes = await fetch(BASE + '/finanzas/costos-fijos/' + id + '?sucursal_id=' + SUCURSAL, {
    method: 'PATCH',
    headers: { ...auth, 'content-type': 'application/json' },
    body: JSON.stringify({ monto_mensual: montoNuevo }),
  });
  const patchJ = await patchRes.json();
  assert(patchRes.status === 200 && patchJ.exito === true, 'PATCH monto_mensual');

  const list2Res = await fetch(BASE + '/finanzas/costos-fijos/' + SUCURSAL, { headers: auth });
  const list2J = await list2Res.json();
  const f2 = (list2J.datos || []).find(x => x.id === id);
  assert(!!f2, 're-listado encuentra mismo id');
  if (f2) assert(Math.abs(Number(f2.monto_mensual) - montoNuevo) < 0.0001, 'monto se actualizo');

  const revertRes = await fetch(BASE + '/finanzas/costos-fijos/' + id + '?sucursal_id=' + SUCURSAL, {
    method: 'PATCH',
    headers: { ...auth, 'content-type': 'application/json' },
    body: JSON.stringify({ monto_mensual: montoOriginal }),
  });
  const revertJ = await revertRes.json();
  assert(revertRes.status === 200 && revertJ.exito === true, 'revert PATCH monto_mensual');

  const failed = process.exitCode && process.exitCode !== 0;
  if (!failed) {
    console.log('\\nVerificacion HUER-REPO-03 OK (exit 0)');
    process.exit(0);
  } else {
    console.log('\\nVerificacion HUER-REPO-03 FALLO (exit 1)');
    process.exit(1);
  }
})();
"@


