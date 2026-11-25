/**
 * Cliente E2E contra API viva (demo seed).
 * Requiere: GET /api/v1/salud → exito, Postgres seed, horarios abiertos.
 */
import request from 'supertest';
import { randomBytes, randomUUID } from 'crypto';

/** Por seguridad, las E2E apuntan a una API QA aislada; nunca al piloto :3000 por omisión. */
export const E2E_HOST = process.env.E2E_HOST?.trim() || 'http://127.0.0.1:3001';
export const E2E_BASE = `${E2E_HOST}/api/v1`;
export const SID = 'c0000000-0000-4000-8000-000000000001';
export const PRODUCTO = 'f0000000-0000-4000-8000-000000000002';
export const PRECIO = 8000;
export const QR_TOKEN = 'demo-mesa-1';
export const MESA_DEMO = '30000000-0000-4000-8000-000000000001';
export const COCINA_ID = 'd0000000-0000-4000-8000-000000000001';
export const DOMI_PLANTA = '92000000-0000-4000-8000-000000000001';
export const PASS = '123456';

export type TokenBundle = { token: string; auth: { Authorization: string } };
export type DeviceCapability = {
  deviceId: string;
  capability: string;
  fcmToken: string;
  headers: { 'X-Foody-Device-Capability': string };
};
const dispositivosClienteE2e = new Map<string, string>();

export function api() {
  return request(E2E_HOST);
}

/** Crea en la BD QA un device invitado con la misma capability que exige Flutter. */
export async function registrarDispositivoCliente(
  prefijo = 'jest-cliente',
): Promise<DeviceCapability> {
  const deviceId = `${prefijo}-${randomUUID()}`;
  const capability = randomBytes(32).toString('hex');
  const fcmToken = randomBytes(32).toString('base64url');
  const headers = { 'X-Foody-Device-Capability': capability };
  const r = await api()
    .post('/api/v1/dispositivos/registrar')
    .set(headers)
    .send({ device_id: deviceId, fcm_token: fcmToken, plataforma: 'web' });
  if (!r.body?.exito || r.body?.datos?.registrado === false) {
    throw new Error(
      `Registro de device E2E falló: ${r.body?.mensaje || r.status}`,
    );
  }
  dispositivosClienteE2e.set(deviceId, fcmToken);
  return { deviceId, capability, fcmToken, headers };
}

/** Anonimiza los dispositivos sintéticos creados por la suite, sin borrar pedidos QA. */
export async function limpiarDispositivosClienteE2e(): Promise<void> {
  const entradas = [...dispositivosClienteE2e.entries()];
  for (const [deviceId, fcmToken] of entradas) {
    const r = await api()
      .delete(`/api/v1/dispositivos/anonimizar/${encodeURIComponent(deviceId)}`)
      .set('X-Foody-Fcm-Token', fcmToken);
    if (r.status !== 200 || r.body?.datos?.anonimizado !== true) {
      throw new Error(
        `No se pudo anonimizar device E2E ${deviceId}: ${r.body?.mensaje || r.status}`,
      );
    }
    dispositivosClienteE2e.delete(deviceId);
  }
}

export async function assertApiViva(): Promise<void> {
  const destino = new URL(E2E_HOST);
  const esQaLocal =
    ['127.0.0.1', 'localhost'].includes(destino.hostname) &&
    destino.port === '3001';
  if (!esQaLocal && process.env.FOODY_E2E_ALLOW_NON_QA !== '1') {
    throw new Error(
      `Destino E2E bloqueado (${E2E_HOST}). Usa la API QA local :3001; ` +
        'para otro destino aislado define FOODY_E2E_ALLOW_NON_QA=1 explícitamente.',
    );
  }
  const r = await api().get('/api/v1/salud').timeout(8000);
  if (r.status !== 200 || !r.body?.exito) {
    throw new Error(
      `API no viva en ${E2E_BASE}/salud (status=${r.status}). Arranca Nest + Docker.`,
    );
  }
}

export async function login(email: string): Promise<TokenBundle> {
  const r = await api()
    .post('/api/v1/auth/login')
    .send({ email, contrasena: PASS });
  if (!r.body?.exito || !r.body?.datos?.token) {
    throw new Error(`Login ${email}: ${r.body?.mensaje || r.status}`);
  }
  const token = r.body.datos.token as string;
  return { token, auth: { Authorization: `Bearer ${token}` } };
}

export async function loginDomiciliarioIndependiente(
  email = 'repartidor@foody.demo',
): Promise<TokenBundle> {
  const r = await api()
    .post('/api/v1/auth/login-domiciliario')
    .send({ email, contrasena: PASS });
  if (!r.body?.exito || !r.body?.datos?.token) {
    throw new Error(
      `Login domiciliario independiente ${email}: ${r.body?.mensaje || r.status}`,
    );
  }
  const token = r.body.datos.token as string;
  return { token, auth: { Authorization: `Bearer ${token}` } };
}

export async function limpiarPedidosActivos(
  auth: TokenBundle['auth'],
): Promise<number> {
  const lista = await api().get(`/api/v1/pedidos?sucursal_id=${SID}`).set(auth);
  if (!lista.body?.exito) return 0;
  const abiertos = (
    lista.body.datos as Array<{ id: string; estado: string }>
  ).filter(
    (p) =>
      !['cancelado', 'rechazado', 'pagado', 'entregado'].includes(p.estado),
  );
  let n = 0;
  for (const p of abiertos) {
    const r = await api()
      .patch(`/api/v1/pedidos/${p.id}/estado?sucursal_id=${SID}`)
      .set(auth)
      .send({ estado: 'cancelado', motivo: 'QA e2e jest cleanup' });
    if (r.body?.exito) n++;
  }
  return n;
}

export async function ensureCajaAbierta(
  auth: TokenBundle['auth'],
): Promise<boolean> {
  const activa = await api().get(`/api/v1/caja/activa/${SID}`).set(auth);
  if (activa.body?.exito && activa.body?.datos) return true;
  const abrir = await api()
    .post(`/api/v1/caja/abrir?sucursal_id=${SID}`)
    .set(auth)
    .send({ sucursal_id: SID, monto_inicial: 50000 });
  return Boolean(abrir.body?.exito) || abrir.body?.error === 'CAJA_YA_ABIERTA';
}

export async function mesaLibre(auth: TokenBundle['auth']): Promise<string> {
  const mesas = await api().get(`/api/v1/mesas/${SID}`).set(auth);
  if (!mesas.body?.exito) throw new Error('GET mesas fallo');
  const libre = (
    mesas.body.datos as Array<{ id: string; pedido_id?: string }>
  ).find((m) => !m.pedido_id);
  if (!libre) throw new Error('Sin mesa libre tras cleanup');
  return libre.id;
}

export function itemBody(cantidad = 1) {
  return { producto_id: PRODUCTO, cantidad, precio: PRECIO };
}

export async function crearPedidoStaff(
  auth: TokenBundle['auth'],
  body: Record<string, unknown>,
) {
  return api().post('/api/v1/pedidos/staff').set(auth).send(body);
}

export function pedidoId(res: {
  body: { datos?: { pedido_id?: string; id?: string } };
}): string {
  const id = res.body?.datos?.pedido_id || res.body?.datos?.id;
  if (!id) throw new Error('Sin pedido_id en respuesta');
  return id;
}

export async function setEstado(
  auth: TokenBundle['auth'],
  id: string,
  estado: string,
  extra: Record<string, unknown> = {},
) {
  return api()
    .patch(`/api/v1/pedidos/${id}/estado?sucursal_id=${SID}`)
    .set(auth)
    .send({ estado, ...extra });
}

export async function detallePedido(auth: TokenBundle['auth'], id: string) {
  return api()
    .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
    .set(auth);
}

/** VIE-05 C: marca ítems listo a nivel cocina (requerido para cobro→pagado). */
export async function marcarItemsCocinaListos(
  authCocina: TokenBundle['auth'],
  pedidoIdStr: string,
  authStaff: TokenBundle['auth'],
): Promise<void> {
  const det = await detallePedido(authStaff, pedidoIdStr);
  const datos = det.body?.datos ?? {};
  const items = (datos.items_resumen ||
    datos.items ||
    datos.pedido?.items ||
    []) as Array<{
    id?: string;
    item_id?: string;
    estado_cocina?: string;
  }>;
  if (!items.length) {
    throw new Error(`Sin items_resumen en detalle pedido ${pedidoIdStr}`);
  }
  for (const it of items) {
    const itemId = it.item_id || it.id;
    if (!itemId) continue;
    if (['listo', 'no_disponible'].includes(it.estado_cocina || '')) continue;
    const r = await api()
      .patch(`/api/v1/cocina/items/${itemId}/estado`)
      .set(authCocina)
      .send({ estado_cocina: 'listo' });
    if (!r.body?.exito) {
      throw new Error(
        `marcar listo ${itemId}: ${r.body?.mensaje || r.body?.error || r.status}`,
      );
    }
  }
}
