/**
 * Flujo crítico: QR cliente — menú público, pedido pendiente_aprobación, anti-tamper precio.
 */
import {
  api,
  assertApiViva,
  detallePedido,
  ensureCajaAbierta,
  limpiarDispositivosClienteE2e,
  limpiarPedidosActivos,
  login,
  pedidoId,
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
    const estimar = await api()
      .post('/api/v1/pedidos/estimar')
      .set(device.headers)
      .send({
        sucursal_id: SID,
        mesa_id: mesaId,
        device_id: device.deviceId,
        tipo: 'mesa',
        metodo_pago: 'pendiente',
        items: [{ producto_id: PRODUCTO, cantidad: 1, precio: PRECIO }],
      });
    expect(estimar.body.exito).toBe(true);

    const crear = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send({
        sucursal_id: SID,
        mesa_id: mesaId,
        device_id: device.deviceId,
        tipo: 'mesa',
        qr_token: QR_TOKEN,
        metodo_pago: 'pendiente',
        idempotency_key: randomUUID(),
        items: [{ producto_id: PRODUCTO, cantidad: 1, precio: PRECIO }],
      });
    expect(crear.body.exito).toBe(true);
    const estado = crear.body.datos?.estado;
    expect(estado).toBe('pendiente_aprobacion');
  });

  it('rechaza un mesa_id que no corresponde al QR escaneado', async () => {
    const menu = await api().get(`/api/v1/menu/mesa/${QR_TOKEN}`);
    expect(menu.body.exito).toBe(true);
    const mesaQrId = menu.body.datos?.mesa?.id || menu.body.datos?.id;
    expect(mesaQrId).toBeTruthy();

    const mesas = await api().get(`/api/v1/mesas/${SID}`).set(admin.auth);
    expect(mesas.body.exito).toBe(true);
    const otraMesa = (mesas.body.datos as Array<{ id: string }>).find(
      (mesa) => mesa.id !== mesaQrId,
    );
    expect(otraMesa).toBeTruthy();

    const device = await registrarDispositivoCliente('jest-qr-mesa-alterada');
    const crear = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send({
        sucursal_id: SID,
        mesa_id: otraMesa!.id,
        device_id: device.deviceId,
        tipo: 'mesa',
        qr_token: QR_TOKEN,
        metodo_pago: 'pendiente',
        idempotency_key: randomUUID(),
        items: [{ producto_id: PRODUCTO, cantidad: 1, precio: PRECIO }],
      });

    expect(crear.status).toBe(400);
    expect(crear.body.error).toBe('QR_MESA_NO_COINCIDE');
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

  it('el checkout público no puede declarar pagos ni anticipar el recaudo en Caja', async () => {
    await ensureCajaAbierta(admin.auth);
    const device = await registrarDispositivoCliente('jest-cliente-sin-cobro');
    const base = {
      sucursal_id: SID,
      device_id: device.deviceId,
      tipo: 'para_llevar',
      metodo_pago: 'efectivo',
      propina: 2500,
      cliente_nombre: 'QA Propina sugerida',
      cliente_telefono: '3000000088',
      items: [{ producto_id: PRODUCTO, cantidad: 1, precio: PRECIO }],
    };

    const intentoDePago = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send({
        ...base,
        pagos: [{ metodo_pago: 'efectivo', monto: PRECIO }],
        idempotency_key: randomUUID(),
      });
    expect(intentoDePago.status).toBe(400);
    expect(intentoDePago.body.error).toBe('PAGO_CLIENTE_NO_CONFIRMADO');

    const crear = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send({ ...base, idempotency_key: randomUUID() });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    const detalle = await detallePedido(admin.auth, id);
    const pedido = detalle.body.datos?.pedido ?? detalle.body.datos;
    expect(pedido.estado).toBe('pendiente');
    expect(Number(pedido.monto_pagado ?? 0)).toBe(0);

    const movimientos = await api()
      .get(`/api/v1/caja/pedidos/${id}/movimientos?sucursal_id=${SID}`)
      .set(admin.auth);
    expect(movimientos.body.exito).toBe(true);
    expect(movimientos.body.datos?.items ?? []).toHaveLength(0);
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
      qr_token: QR_TOKEN,
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
        qr_token: QR_TOKEN,
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
