/**
 * Flujo crítico: QR cliente — menú público, pedido pendiente_aprobación, anti-tamper precio.
 */
import {
  api,
  assertApiViva,
  detallePedido,
  limpiarDispositivosClienteE2e,
  limpiarPedidosActivos,
  login,
  PRECIO,
  PRODUCTO,
  QR_TOKEN,
  registrarDispositivoCliente,
  SID,
  TokenBundle,
} from '../helpers/foody-e2e';
import { randomUUID } from 'crypto';

describe('E2E QR cliente', () => {
  let admin: TokenBundle;
  const SID_NORTE = 'c0000000-0000-4000-8000-000000000002';

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
  });

  beforeEach(async () => {
    await limpiarPedidosActivos(admin.auth);
  });

  afterEach(async () => {
    await limpiarPedidosActivos(admin.auth);
    await limpiarDispositivosClienteE2e();
  });

  it('GET /menu/mesa/:token + POST /pedidos → pendiente_aprobacion', async () => {
    const menu = await api().get(`/api/v1/menu/mesa/${QR_TOKEN}`);
    expect(menu.body.exito).toBe(true);
    const mesaId =
      menu.body.datos?.mesa?.id ||
      menu.body.datos?.id ||
      '30000000-0000-4000-8000-000000000001';

    const device = await registrarDispositivoCliente('jest-qr');
    const crear = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send({
        sucursal_id: SID,
        mesa_id: mesaId,
        device_id: device.deviceId,
        tipo: 'mesa',
        metodo_pago: 'pendiente',
        idempotency_key: randomUUID(),
        items: [{ producto_id: PRODUCTO, cantidad: 1, precio: PRECIO }],
      });
    expect(crear.body.exito).toBe(true);
    const estado = crear.body.datos?.estado;
    expect(estado).toBe('pendiente_aprobacion');
  });

  it('requiere contacto telefónico para domicilio público y conserva nombre opcional', async () => {
    const device = await registrarDispositivoCliente('jest-domi-contacto');
    const base = {
      sucursal_id: SID,
      device_id: device.deviceId,
      tipo: 'domicilio',
      direccion_entrega: 'Calle QA 123',
      metodo_pago: 'pendiente',
      items: [{ producto_id: PRODUCTO, cantidad: 1, precio: PRECIO }],
    };

    const sinTelefono = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send({ ...base, idempotency_key: randomUUID() });
    expect(sinTelefono.status).toBe(400);
    expect(sinTelefono.body.exito).toBe(false);

    const telefono = '+57 (300) 123-4567';
    const creado = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send({
        ...base,
        cliente_telefono: telefono,
        idempotency_key: randomUUID(),
      });
    expect(creado.body.exito).toBe(true);

    const detalle = await detallePedido(
      admin.auth,
      creado.body.datos.pedido_id,
    );
    const datos = detalle.body.datos ?? {};
    expect(datos.cliente_telefono ?? datos.pedido?.cliente_telefono).toBe(
      telefono,
    );
    expect(
      datos.cliente_nombre ?? datos.pedido?.cliente_nombre ?? null,
    ).toBeNull();
  });

  it('acota idempotencia a sucursal y rechaza payload distinto', async () => {
    const menu = await api().get(`/api/v1/menu/mesa/${QR_TOKEN}`);
    const mesaId =
      menu.body.datos?.mesa?.id ||
      menu.body.datos?.id ||
      '30000000-0000-4000-8000-000000000001';
    const clave = randomUUID();
    const device = await registrarDispositivoCliente('jest-qr-idempotencia');
    const payload = {
      sucursal_id: SID,
      mesa_id: mesaId,
      device_id: device.deviceId,
      tipo: 'mesa',
      metodo_pago: 'pendiente',
      idempotency_key: clave,
      items: [{ producto_id: PRODUCTO, cantidad: 1, precio: PRECIO }],
    };

    const original = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send(payload);
    expect(original.body.exito).toBe(true);
    const pedidoId = original.body.datos.pedido_id;

    const replay = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send(payload);
    expect(replay.body.exito).toBe(true);
    expect(replay.body.datos.pedido_id).toBe(pedidoId);
    expect(replay.body.datos.idempotente).toBe(true);

    const modificado = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send({
        ...payload,
        items: [{ producto_id: PRODUCTO, cantidad: 2, precio: PRECIO }],
      });
    expect(modificado.status).toBe(409);
    expect(modificado.body.error).toBe('IDEMPOTENCY_KEY_REUSED');

    const otraSucursal = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send({ ...payload, sucursal_id: SID_NORTE });
    expect(otraSucursal.status).toBe(400);
    expect(otraSucursal.body.exito).toBe(false);
    expect(otraSucursal.body.datos?.pedido_id).not.toBe(pedidoId);
    expect(otraSucursal.body.datos?.seguimiento_token).toBeUndefined();
  });

  it('anti-tamper: precio cliente inflado no se acepta como total catálogo', async () => {
    const menu = await api().get(`/api/v1/menu/mesa/${QR_TOKEN}`);
    const mesaId =
      menu.body.datos?.mesa?.id ||
      menu.body.datos?.id ||
      '30000000-0000-4000-8000-000000000001';

    const device = await registrarDispositivoCliente('jest-qr-tamper');
    const crear = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send({
        sucursal_id: SID,
        mesa_id: mesaId,
        device_id: device.deviceId,
        tipo: 'mesa',
        metodo_pago: 'pendiente',
        idempotency_key: randomUUID(),
        items: [{ producto_id: PRODUCTO, cantidad: 1, precio: 1 }],
      });
    // Backend recalcula desde BD: o rechaza o crea con precio catálogo (no 1).
    if (crear.body.exito) {
      const total = Number(crear.body.datos?.total ?? 0);
      expect(total).toBeGreaterThan(1);
    } else {
      expect(crear.body.exito).toBe(false);
    }
  });
});
