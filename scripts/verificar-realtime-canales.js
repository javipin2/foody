/**
 * Contrato Realtime + RT-SEC-01 (topics staff HMAC).
 *
 * - Staff: topics `tipo_{id}_{firma16}` (misma lógica que realtime-topics.ts)
 * - Público: `sucursal_{id}_catalogo` y `pedido_{id}_{token}`
 * - Anon en `sucursal_{id}` plano NO debe recibir eventos (backend ya no emite ahí)
 *
 * Uso: node scripts/verificar-realtime-canales.js
 */
const path = require('path');
const crypto = require('crypto');
const backendDir = path.join(__dirname, '..', 'foody_backend');
const dep = (m) => require(path.join(backendDir, 'node_modules', m));

dep('dotenv').config({ path: path.join(backendDir, '.env') });
const { createClient } = dep('@supabase/supabase-js');
const WebSocket = dep('ws');

const URL = process.env.SUPABASE_URL;
const SERVICE = process.env.SUPABASE_SERVICE_KEY;
const ANON = process.env.SUPABASE_ANON_KEY;
const PEPPER =
  (process.env.REALTIME_CANAL_PEPPER || process.env.JWT_SECRET || '').trim() ||
  'foody_jwt_secret_cambiar';

if (!URL || !SERVICE || !ANON) {
  console.error('FALTAN SUPABASE_URL / SUPABASE_SERVICE_KEY / SUPABASE_ANON_KEY en foody_backend/.env');
  process.exit(2);
}

function firma(tipo, id) {
  return crypto.createHmac('sha256', PEPPER).update(`${tipo}:${id}`).digest('hex').slice(0, 16);
}
function topicStaff(tipo, id) {
  return `${tipo}_${id}_${firma(tipo, id)}`;
}

const SUC = '00000000-0000-0000-0000-0000000000aa';
const PEDIDO = '00000000-0000-0000-0000-0000000000bb';
const TOKEN = 'tok-verificacion';
const COCINA = '00000000-0000-0000-0000-0000000000cc';
const REST = '00000000-0000-0000-0000-0000000000dd';
const USUARIO = '00000000-0000-0000-0000-0000000000ee';
const DOMI = '00000000-0000-0000-0000-0000000000ff';

const SUC_STAFF = topicStaff('sucursal', SUC);
const COC_STAFF = topicStaff('cocina', COCINA);
const REST_STAFF = topicStaff('restaurante', REST);
const DOM_PLANTA = topicStaff('domiciliario', USUARIO);
const DOM_INDEP = topicStaff('domiciliario_indep', DOMI);

const CASOS = [
  ['pedido_actualizado', SUC_STAFF, SUC_STAFF, 'Kanban staff'],
  ['mesas_actualizadas', SUC_STAFF, SUC_STAFF, 'Grid mesas'],
  ['caja_movimiento', SUC_STAFF, SUC_STAFF, 'Caja admin'],
  ['alerta_nueva', SUC_STAFF, SUC_STAFF, 'Alertas'],
  ['qr_aprobacion_urgente', SUC_STAFF, SUC_STAFF, 'Grid mesero'],
  ['llamar_mesera', SUC_STAFF, SUC_STAFF, 'Grid mesero'],
  ['catalogo_disponibilidad', SUC_STAFF, SUC_STAFF, 'Staff catalogo dual'],
  ['catalogo_disponibilidad', `sucursal_${SUC}_catalogo`, `sucursal_${SUC}_catalogo`, 'Menu cliente publico'],
  ['estado_actualizado', `pedido_${PEDIDO}_${TOKEN}`, `pedido_${PEDIDO}_${TOKEN}`, 'Seguimiento'],
  ['ubicacion_repartidor', `pedido_${PEDIDO}_${TOKEN}`, `pedido_${PEDIDO}_${TOKEN}`, 'GPS'],
  ['cocina_actualizada', COC_STAFF, COC_STAFF, 'KDS'],
  ['suscripcion_actualizada', REST_STAFF, REST_STAFF, 'Panel'],
  ['pedido_asignado', DOM_PLANTA, DOM_PLANTA, 'Domi planta'],
  ['pedido_desasignado', DOM_PLANTA, DOM_PLANTA, 'Domi planta'],
  ['oferta_nueva', DOM_INDEP, DOM_INDEP, 'Domi indep'],
  ['oferta_expirada', DOM_INDEP, DOM_INDEP, 'Domi indep'],
].map(([evento, emite, escucha, consumidor]) => ({ evento, emite, escucha, consumidor }));

const opciones = {
  auth: { persistSession: false, autoRefreshToken: false },
  realtime: { transport: WebSocket },
};

const suscribir = (cliente, topic, evento, onEvento) =>
  new Promise((resolve, reject) => {
    const temporizador = setTimeout(
      () => reject(new Error(`Timeout suscribiendo a ${topic}`)),
      10000,
    );
    const ch = cliente
      .channel(topic, { config: { broadcast: { ack: false, self: false } } })
      .on('broadcast', { event: evento }, onEvento)
      .subscribe((estado, err) => {
        if (estado === 'SUBSCRIBED') {
          clearTimeout(temporizador);
          resolve(ch);
        }
        if (estado === 'CHANNEL_ERROR' || estado === 'TIMED_OUT') {
          clearTimeout(temporizador);
          reject(err ?? new Error(estado));
        }
      });
  });

(async () => {
  const emisor = createClient(URL, SERVICE, opciones);
  const oyente = createClient(URL, ANON, opciones);
  const fallos = [];

  console.log('=== Contrato Realtime + RT-SEC (HMAC staff) ===\n');
  console.log(`topic staff ejemplo: ${SUC_STAFF}\n`);

  for (const caso of CASOS) {
    let recibido = false;
    const chOyente = await suscribir(oyente, caso.escucha, caso.evento, () => {
      recibido = true;
    });
    const chEmisor = await suscribir(emisor, caso.emite, '__noop__', () => {});

    await chEmisor.send({
      type: 'broadcast',
      event: caso.evento,
      payload: { event_id: `verif-${Date.now()}`, sucursal_id: SUC },
    });
    await new Promise((r) => setTimeout(r, 1500));

    if (!recibido) {
      fallos.push(caso);
      console.log(`FALLO ${caso.evento}`);
      console.log(`      emite  : ${caso.emite}`);
      console.log(`      escucha: ${caso.escucha}`);
    } else {
      console.log(`OK    ${caso.evento.padEnd(24)} ${caso.consumidor}`);
    }

    await oyente.removeChannel(chOyente);
    await emisor.removeChannel(chEmisor);
  }

  // RT-SEC: emitir en topic firmado; anon en topic PLANO no debe oír.
  console.log('\n--- RT-SEC: anon en sucursal_{uuid} plano ---');
  let leak = false;
  const chLeak = await suscribir(oyente, `sucursal_${SUC}`, 'caja_movimiento', () => {
    leak = true;
  });
  const chStaff = await suscribir(emisor, SUC_STAFF, '__noop__', () => {});
  await chStaff.send({
    type: 'broadcast',
    event: 'caja_movimiento',
    payload: { event_id: `sec-${Date.now()}`, sucursal_id: SUC },
  });
  await new Promise((r) => setTimeout(r, 1500));
  await oyente.removeChannel(chLeak);
  await emisor.removeChannel(chStaff);

  if (leak) {
    console.log('FALLO RT-SEC: anon recibió caja en topic plano');
    fallos.push({ evento: 'rt-sec-leak' });
  } else {
    console.log('OK    anon NO recibe caja en sucursal_{uuid} plano');
  }

  console.log(
    fallos.length > 0
      ? `\nFALLO: ${fallos.length} caso(s)`
      : `\nOK: ${CASOS.length} rutas + RT-SEC leak cerrado`,
  );
  process.exit(fallos.length > 0 ? 1 : 0);
})().catch((e) => {
  console.error('ERROR:', e.message);
  process.exit(2);
});
