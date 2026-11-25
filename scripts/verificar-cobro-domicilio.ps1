# Check runnable del reparto producto/domicilio (repartirCobroDomicilio).
# Verifica que la caja reciba solo el producto y el domicilio quede aparte.
# Requiere haber compilado el backend (dist/).

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$util = Join-Path $repo 'foody_backend\dist\modulos\domiciliarios\cobro-domicilio.util.js'

if (-not (Test-Path $util)) {
  Write-Error "No existe $util. Compila el backend: (cd foody_backend; npm run build)"
}

$utilJson = ($util -replace '\\', '/')
$node = @"
const { repartirCobroDomicilio, montoVentaCajaEntregaDomicilio } = require('$utilJson');
function eq(nombre, got, esp) {
  const ok = JSON.stringify(got) === JSON.stringify(esp);
  console.log((ok ? 'OK  ' : 'FAIL') + ' ' + nombre + ' -> ' + JSON.stringify(got));
  if (!ok) { console.error('  esperado ' + JSON.stringify(esp)); process.exitCode = 1; }
}
// Pedido 20k + domicilio 5k, nada pagado: caja=20k producto, 5k domicilio.
eq('nada pagado', repartirCobroDomicilio(25000, 5000, 0),
   { saldo: 25000, productoTotal: 20000, productoPendiente: 20000, domicilioPendiente: 5000 });
// Producto ya pagado online (20k): solo queda el domicilio.
eq('producto pagado', repartirCobroDomicilio(25000, 5000, 20000),
   { saldo: 5000, productoTotal: 20000, productoPendiente: 0, domicilioPendiente: 5000 });
// Pago parcial 10k: producto pendiente 10k, domicilio 5k.
eq('pago parcial', repartirCobroDomicilio(25000, 5000, 10000),
   { saldo: 15000, productoTotal: 20000, productoPendiente: 10000, domicilioPendiente: 5000 });
// Sin domicilio: todo es producto.
eq('sin domicilio', repartirCobroDomicilio(20000, 0, 0),
   { saldo: 20000, productoTotal: 20000, productoPendiente: 20000, domicilioPendiente: 0 });
// Kanban entregado: domicilio fuera de caja -> solo producto pendiente.
eq('monto caja sin domi en caja', montoVentaCajaEntregaDomicilio(25000, 5000, 0, false), 20000);
eq('monto caja domi en caja', montoVentaCajaEntregaDomicilio(25000, 5000, 0, true), 25000);
eq('monto caja producto ya pagado', montoVentaCajaEntregaDomicilio(25000, 5000, 20000, false), 0);
"@

$node | node -
if ($LASTEXITCODE -ne 0) { Write-Error 'Checks de reparto FALLARON' }
Write-Host 'Reparto producto/domicilio: OK' -ForegroundColor Green
