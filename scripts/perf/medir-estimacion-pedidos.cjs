#!/usr/bin/env node
'use strict';

const { randomBytes, randomUUID } = require('node:crypto');

const base = new URL(
  process.env.FOODY_PERF_API_BASE || 'http://127.0.0.1:3001/api/v1',
);
const sucursalId =
  process.env.FOODY_PERF_SUCURSAL_ID ||
  'c0000000-0000-4000-8000-000000000001';
const productoId =
  process.env.FOODY_PERF_PRODUCTO_ID ||
  'f0000000-0000-4000-8000-000000000002';
const toppingId =
  process.env.FOODY_PERF_TOPPING_ID ||
  '20000000-0000-4000-8000-000000000001';
const bebidaId =
  process.env.FOODY_PERF_BEBIDA_ID ||
  '10000000-0000-4000-8000-000000000001';
const repeticiones = Number(process.env.FOODY_PERF_REPETICIONES || 12);

if (
  !['127.0.0.1', 'localhost'].includes(base.hostname) ||
  base.port !== '3001' ||
  base.pathname.replace(/\/$/, '') !== '/api/v1'
) {
  throw new Error(
    'Bloqueado: este benchmark solo puede llamar una API QA local en :3001/api/v1.',
  );
}
if (!Number.isInteger(repeticiones) || repeticiones < 2 || repeticiones > 20) {
  throw new Error('FOODY_PERF_REPETICIONES debe estar entre 2 y 20.');
}

const deviceId = `perf-qa-${randomUUID()}`;
const capability = randomBytes(32).toString('hex');
const fcmToken = randomBytes(32).toString('base64url');
const authHeaders = {
  'content-type': 'application/json',
  'X-Foody-Device-Capability': capability,
};

function endpoint(path) {
  const url = new URL(base);
  url.pathname = `${base.pathname.replace(/\/$/, '')}/${path.replace(/^\/+/, '')}`;
  return url;
}

async function request(path, { method = 'POST', body, headers = {} } = {}) {
  const response = await fetch(endpoint(path), {
    method,
    headers: { ...authHeaders, ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(10_000),
  });
  const data = await response.json();
  if (!response.ok || data?.exito !== true) {
    throw new Error(`HTTP ${response.status}: ${data?.error || data?.mensaje || 'falló la solicitud'}`);
  }
  return data.datos;
}

function percentil(muestras, p) {
  const ordenadas = [...muestras].sort((a, b) => a - b);
  return Math.round(
    ordenadas[Math.min(ordenadas.length - 1, Math.ceil(p * ordenadas.length) - 1)] *
      100,
  ) / 100;
}

async function medirLineas(cantidad) {
  const muestras = [];
  let subtotal;
  for (let indice = 0; indice < repeticiones; indice += 1) {
    const items = Array.from({ length: cantidad }, () => ({
      producto_id: productoId,
      cantidad: 1,
      precio: 8000,
      toppings: [{ topping_id: toppingId }],
      bebidas: [{ bebida_id: bebidaId, cantidad: 1 }],
    }));
    const inicio = performance.now();
    const datos = await request('/pedidos/estimar', {
      body: {
        sucursal_id: sucursalId,
        device_id: deviceId,
        tipo: 'para_llevar',
        metodo_pago: 'pendiente',
        items,
      },
    });
    muestras.push(performance.now() - inicio);
    if (!datos) throw new Error('La estimación no devolvió datos.');
    const subtotalActual = Number(datos.subtotal);
    if (!Number.isFinite(subtotalActual)) {
      throw new Error('La estimación no devolvió un subtotal numérico.');
    }
    if (subtotal !== undefined && Math.abs(subtotalActual - subtotal) > 0.01) {
      throw new Error('El subtotal cambió entre muestras con el mismo catálogo.');
    }
    subtotal = subtotalActual;
  }
  return {
    lineas: cantidad,
    muestras: muestras.length,
    subtotal,
    p50_ms: percentil(muestras, 0.5),
    p95_ms: percentil(muestras, 0.95),
    max_ms: Math.round(Math.max(...muestras) * 100) / 100,
  };
}

async function main() {
  const salud = await fetch(endpoint('salud'), {
    signal: AbortSignal.timeout(8_000),
  });
  if (!salud.ok || (await salud.json())?.exito !== true) {
    throw new Error('La API QA local no pasó el chequeo de salud.');
  }

  await request('/dispositivos/registrar', {
    body: {
      device_id: deviceId,
      fcm_token: fcmToken,
      plataforma: 'web',
    },
  });

  try {
    const resultados = [];
    for (const cantidad of [1, 30]) {
      resultados.push(await medirLineas(cantidad));
    }
    const subtotalLineal =
      Math.abs(resultados[1].subtotal - resultados[0].subtotal * 30) <= 0.01;
    if (!subtotalLineal) {
      throw new Error('El subtotal de 30 líneas no conserva la suma lineal esperada.');
    }
    console.log(
      JSON.stringify(
        {
          alcance: 'POST /pedidos/estimar contra QA local; sin crear pedidos',
          nota: 'Latencia local de una instancia; no es prueba de capacidad ni incluye Cloudflare Tunnel.',
          subtotal_lineal_verificado: subtotalLineal,
          resultados,
        },
        null,
        2,
      ),
    );
  } finally {
    await request(
      `/dispositivos/anonimizar/${encodeURIComponent(deviceId)}`,
      {
        method: 'DELETE',
        headers: { 'X-Foody-Fcm-Token': fcmToken },
      },
    );
    console.log('Dispositivo QA temporal anonimizado.');
  }
}

main().catch((error) => {
  console.error(`Benchmark detenido: ${error.message}`);
  process.exitCode = 1;
});
