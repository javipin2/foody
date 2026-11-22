/**
 * Estres Foody: N usuarios simultaneos × Q consultas cada uno (+ opcional escrituras).
 *
 * Uso:
 *   node scripts/estres-1000-usuarios.mjs
 *   node scripts/estres-1000-usuarios.mjs 1000 5
 *   node scripts/estres-1000-usuarios.mjs 1000 5 --writes=20
 *   node scripts/estres-1000-usuarios.mjs 500 3 http://localhost:3000/api/v1
 *
 * Flujo de cada consulta (lectura):
 *   Node fetch  →  NestJS (:3000)  →  pool pg  →  PostgreSQL (supabase-db / foody_postgres_dev)
 *   Algunas rutas usan MenuCacheService (memoria Nest) y no llegan a PG.
 */
const args = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const flags = Object.fromEntries(
  process.argv
    .slice(2)
    .filter((a) => a.startsWith('--'))
    .map((a) => {
      const [k, v] = a.replace(/^--/, '').split('=');
      return [k, v ?? 'true'];
    }),
);

const N = Math.max(1, Number(args[0]) || 1000);
const Q = Math.max(1, Number(args[1]) || 1);
const BASE = (args[2] || 'http://localhost:3000/api/v1').replace(/\/$/, '');
const SID = process.env.FOODY_SUCURSAL_ID || 'c0000000-0000-4000-8000-000000000001';
const WRITES = Math.max(0, Number(flags.writes || 0));

const READ_BUILDERS = [
  { name: 'salud', auth: false, url: () => `${BASE}/salud` },
  { name: 'menu', auth: false, url: () => `${BASE}/menu/${SID}` },
  { name: 'promociones', auth: false, url: () => `${BASE}/promociones?sucursal_id=${SID}` },
  {
    name: 'pedidos',
    auth: true,
    url: () => `${BASE}/pedidos?solo_activos=true&sucursal_id=${SID}&limit=20`,
  },
  {
    name: 'movimientos',
    auth: true,
    url: () => `${BASE}/inventario/movimientos/${SID}?page=1&limit=10`,
  },
];

function pct(sorted, p) {
  if (!sorted.length) return 0;
  const i = Math.min(sorted.length - 1, Math.floor((p / 100) * (sorted.length - 1)));
  return Math.round(sorted[i] * 10) / 10;
}

function summarize(label, results) {
  const ok = results.filter((r) => r.ok).length;
  const err = results.length - ok;
  const lats = results.map((r) => r.ms).sort((a, b) => a - b);
  const byName = {};
  for (const r of results) {
    byName[r.name] ??= { ok: 0, err: 0, ms: [] };
    if (r.ok) byName[r.name].ok++;
    else byName[r.name].err++;
    byName[r.name].ms.push(r.ms);
  }
  return { label, total: results.length, ok, err, lats, byName };
}

function printSummary(s, wallSec) {
  const rps = s.total / Math.max(0.001, wallSec);
  console.log(`\n--- ${s.label} ---`);
  console.log(
    `total=${s.total} ok=${s.ok} err=${s.err} (${((100 * s.err) / s.total).toFixed(2)}%) ` +
      `wall=${wallSec.toFixed(2)}s rps~${rps.toFixed(1)}`,
  );
  console.log(
    `p50=${pct(s.lats, 50)}ms p95=${pct(s.lats, 95)}ms p99=${pct(s.lats, 99)}ms ` +
      `max=${Math.round(s.lats[s.lats.length - 1] * 10) / 10}ms`,
  );
  console.log('por_endpoint:');
  for (const [name, v] of Object.entries(s.byName)) {
    const ms = v.ms.sort((a, b) => a - b);
    console.log(
      `  ${name.padEnd(14)} ok=${v.ok} err=${v.err} p50=${pct(ms, 50)}ms p95=${pct(ms, 95)}ms`,
    );
  }
}

async function login() {
  const r = await fetch(`${BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'admin@foody.demo', contrasena: '123456' }),
  });
  const j = await r.json();
  if (!j.exito) throw new Error(`login: ${j.mensaje || r.status}`);
  return j.datos.token;
}

async function doFetch(name, url, token, auth) {
  const t0 = performance.now();
  try {
    const headers = {};
    if (auth && token) headers.Authorization = `Bearer ${token}`;
    const r = await fetch(url, { headers, signal: AbortSignal.timeout(90000) });
    const ms = performance.now() - t0;
    let ok = r.ok;
    try {
      const j = await r.json();
      if (typeof j.exito === 'boolean') ok = j.exito;
    } catch {
      /* ignore */
    }
    return { name, ok, ms, status: r.status };
  } catch (e) {
    return { name, ok: false, ms: performance.now() - t0, status: 0, err: String(e.message || e) };
  }
}

async function userSession(userIndex, token) {
  const out = [];
  for (let q = 0; q < Q; q++) {
    const ep = READ_BUILDERS[(userIndex + q) % READ_BUILDERS.length];
    out.push(await doFetch(ep.name, ep.url(), token, ep.auth));
  }
  return out;
}

async function pickProducto() {
  const r = await fetch(`${BASE}/menu/${SID}`);
  const j = await r.json();
  if (!j.exito) throw new Error('menu para write');
  for (const cat of j.datos.categorias || []) {
    for (const p of cat.productos || []) {
      if (p.disponible !== false && p.id != null && p.precio != null) {
        return { id: p.id, precio: Number(p.precio) };
      }
    }
  }
  throw new Error('sin producto disponible');
}

async function writePedido(_token, producto, i) {
  const t0 = performance.now();
  try {
    // Misma forma que verificar-carga-qr.ps1 (pedido publico mesa; precio obligatorio en DTO)
    const body = {
      sucursal_id: SID,
      mesa_id: '30000000-0000-4000-8000-000000000001',
      device_id: `estres-node-${i}-${Date.now()}`,
      tipo: 'mesa',
      metodo_pago: 'pendiente',
      items: [
        {
          producto_id: producto.id,
          cantidad: 1,
          precio: producto.precio,
        },
      ],
      idempotency_key: crypto.randomUUID(),
    };
    const r = await fetch(`${BASE}/pedidos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(90000),
    });
    const ms = performance.now() - t0;
    const j = await r.json().catch(() => ({}));
    return {
      name: 'POST_pedidos',
      ok: !!j.exito,
      ms,
      status: r.status,
      err: j.exito ? undefined : j.mensaje || j.error || JSON.stringify(j).slice(0, 120),
    };
  } catch (e) {
    return {
      name: 'POST_pedidos',
      ok: false,
      ms: performance.now() - t0,
      status: 0,
      err: String(e.message || e),
    };
  }
}

async function main() {
  console.log('=== Estres Foody (ruta de componentes) ===');
  console.log(`usuarios=${N}  consultas_por_usuario=${Q}  total_lecturas=${N * Q}`);
  console.log(`writes_paralelos=${WRITES}`);
  console.log(`Base: ${BASE}`);
  console.log('');
  console.log('Cadena de cada request:');
  console.log('  [1] Node scripts/estres-*.mjs  (cliente HTTP, esta PC)');
  console.log('  [2] NestJS foody_backend :3000  (node dist/main.js)');
  console.log('  [3] Pool pg (DB_POOL_MAX, default 10) → PostgreSQL Docker');
  console.log('      contenedores tipicos: supabase-db / foody_postgres_dev');
  console.log('  [4] /menu puede servirse desde MenuCacheService (RAM Nest, TTL 5 min)');
  console.log('  NO pasa por: Flutter, Cloudflare, FCM, impresora Python');
  console.log('');

  const salud = await fetch(`${BASE}/salud`).then((r) => r.json());
  if (!salud.exito) throw new Error('API /salud no responde');
  console.log('OK warmup /salud');

  const token = await login();
  console.log('OK login admin@foody.demo');

  // --- Lecturas N×Q en paralelo (todos los usuarios arrancan juntos) ---
  console.log(`\nLanzando ${N} usuarios × ${Q} consultas (Promise.all)...`);
  const tRead = performance.now();
  const nested = await Promise.all(Array.from({ length: N }, (_, i) => userSession(i, token)));
  const wallRead = (performance.now() - tRead) / 1000;
  const flat = nested.flat();
  const sumRead = summarize(`LECTURAS ${N}x${Q}`, flat);
  printSummary(sumRead, wallRead);

  // --- Escrituras opcionales ---
  let sumWrite = null;
  let wallWrite = 0;
  if (WRITES > 0) {
    console.log(`\nLanzando ${WRITES} POST /pedidos en paralelo...`);
    const producto = await pickProducto();
    const tW = performance.now();
    const writes = await Promise.all(
      Array.from({ length: WRITES }, (_, i) => writePedido(token, producto, i)),
    );
    wallWrite = (performance.now() - tW) / 1000;
    sumWrite = summarize(`WRITES POST /pedidos x${WRITES}`, writes);
    printSummary(sumWrite, wallWrite);
    const sample = writes.filter((w) => !w.ok).slice(0, 3);
    for (const e of sample) console.log(`  fail: ${e.err || e.status}`);
  }

  const post = await fetch(`${BASE}/salud`)
    .then((r) => r.json())
    .catch(() => null);
  console.log(`\npost_estres_salud: ${post?.exito === true ? 'OK' : 'FALLO'}`);

  const p95 = pct(sumRead.lats, 95);
  const errPct = (100 * sumRead.err) / sumRead.total;
  if (errPct > 5 || p95 > 5000) {
    console.log('VEREDICTO lecturas: SATURADO (err>5% o p95>5s)');
    process.exitCode = 2;
  } else if (p95 > 1500) {
    console.log('VEREDICTO lecturas: AGUANTA PERO LENTO (p95>1.5s)');
  } else {
    console.log('VEREDICTO lecturas: OK (p95<=1.5s, err<=5%)');
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
