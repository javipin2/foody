/**
 * Flujo crítico: QR cliente — menú público, pedido pendiente_aprobación, anti-tamper precio.
 */
import { Pool } from 'pg';
import {
  api,
  assertApiViva,
  COCINA_ID,
  detallePedido,
  E2E_HOST,
  ensureCajaAbierta,
  limpiarDispositivosClienteE2e,
  limpiarPedidosActivos,
  login,
  MESA_DEMO,
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
  let gerente: TokenBundle;
  let cocina: TokenBundle;
  let cajero: TokenBundle;
  const SID_NORTE = 'c0000000-0000-4000-8000-000000000002';

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
    gerente = await login('gerente@foody.demo');
    cocina = await login('cocina@foody.demo');
    cajero = await login('cajero.test@foody.demo');
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

  it('rechaza cotización pública obsoleta y crea solo tras reconfirmar el total', async () => {
    const databaseUrl = process.env.DATABASE_URL;
    const databaseName = databaseUrl
      ? decodeURIComponent(new URL(databaseUrl).pathname.replace(/^\//, ''))
      : '';
    const host = new URL(E2E_HOST);
    if (
      !['127.0.0.1', 'localhost'].includes(host.hostname) ||
      !['3001', '3002'].includes(host.port) ||
      process.env.FOODY_QA_SIN_EFECTOS !== '1' ||
      !/^foody_diseno_qa_codex_ledger[a-zA-Z0-9_]+$/.test(databaseName)
    ) {
      throw new Error(
        'La cotización pública E2E solo puede mutar precios en API :3001 y clon QA Foody aislado.',
      );
    }

    const database = new Pool({ connectionString: databaseUrl });
    let precioOriginal: string | null = null;
    try {
      const menu = await api().get(`/api/v1/menu/mesa/${QR_TOKEN}`);
      const mesaId = menu.body.datos?.mesa?.id || MESA_DEMO;
      const device = await registrarDispositivoCliente('jest-qr-precio-cambio');
      const cuerpo = {
        sucursal_id: SID,
        mesa_id: mesaId,
        device_id: device.deviceId,
        tipo: 'mesa',
        metodo_pago: 'pendiente',
        items: [{ producto_id: PRODUCTO, cantidad: 1, precio: PRECIO }],
      };
      const estimacionAnterior = await api()
        .post('/api/v1/pedidos/estimar')
        .set(device.headers)
        .send(cuerpo);
      expect(estimacionAnterior.body.exito).toBe(true);
      const totalAnterior = estimacionAnterior.body.datos.total as number;
      const producto = await database.query<{ precio: string }>(
        'SELECT precio::text FROM productos WHERE id = $1 AND sucursal_id = $2',
        [PRODUCTO, SID],
      );
      expect(producto.rowCount).toBe(1);
      precioOriginal = producto.rows[0].precio;
      const clave = randomUUID();

      await database.query(
        'UPDATE productos SET precio = $1 WHERE id = $2 AND sucursal_id = $3',
        [Number(precioOriginal) + 100, PRODUCTO, SID],
      );
      const obsoleto = await api()
        .post('/api/v1/pedidos')
        .set(device.headers)
        .send({
          ...cuerpo,
          qr_token: QR_TOKEN,
          total_esperado: totalAnterior,
          idempotency_key: clave,
        });
      expect(obsoleto.status).toBe(409);
      expect(obsoleto.body.error).toBe('TOTAL_PEDIDO_CAMBIO');
      expect(obsoleto.body.total_actual).not.toBe(totalAnterior);
      const pedidoFallido = await database.query<{ total: number }>(
        'SELECT COUNT(*)::int AS total FROM pedidos_idempotencia WHERE sucursal_id = $1 AND clave = $2',
        [SID, clave],
      );
      expect(pedidoFallido.rows[0].total).toBe(0);

      const estimacionActual = await api()
        .post('/api/v1/pedidos/estimar')
        .set(device.headers)
        .send(cuerpo);
      const confirmado = await api()
        .post('/api/v1/pedidos')
        .set(device.headers)
        .send({
          ...cuerpo,
          qr_token: QR_TOKEN,
          total_esperado: estimacionActual.body.datos.total,
          idempotency_key: clave,
        });
      expect(confirmado.status).toBe(201);
      expect(confirmado.body.datos.total).toBe(
        estimacionActual.body.datos.total,
      );
    } finally {
      if (precioOriginal != null) {
        await database.query(
          'UPDATE productos SET precio = $1 WHERE id = $2 AND sucursal_id = $3',
          [precioOriginal, PRODUCTO, SID],
        );
      }
      await database.end();
    }
  });

  it('Admin aprueba pedido QR, asigna mesera y lo envía a cocina', async () => {
    const menu = await api().get(`/api/v1/menu/mesa/${QR_TOKEN}`);
    expect(menu.body.exito).toBe(true);
    const mesaId = menu.body.datos?.mesa?.id || menu.body.datos?.id;
    expect(mesaId).toBeTruthy();

    const device = await registrarDispositivoCliente('jest-qr-aprobar');
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
    expect(crear.status).toBe(201);
    const id = pedidoId(crear);

    const meseras = await api()
      .get(`/api/v1/usuarios/meseros-activos?sucursal_id=${SID}`)
      .set(admin.auth);
    expect(meseras.body.exito).toBe(true);
    const meseraId = (meseras.body.datos as Array<{ id: string }>)[0]?.id;
    expect(meseraId).toBeTruthy();

    const aprobar = await api()
      .patch(`/api/v1/pedidos/${id}/aprobar?sucursal_id=${SID}`)
      .set(admin.auth)
      .send({ mesera_id: meseraId });
    expect(aprobar.status).toBe(200);
    expect(aprobar.body.datos?.estado).toBe('en_cocina');
    expect(aprobar.body.datos?.mesera_id).toBe(meseraId);

    const detalle = await detallePedido(admin.auth, id);
    expect(
      detalle.body.datos?.estado ?? detalle.body.datos?.pedido?.estado,
    ).toBe('en_cocina');
    const tickets = await api()
      .get(`/api/v1/cocina/tickets/${COCINA_ID}`)
      .set(cocina.auth);
    expect(tickets.body.exito).toBe(true);
    expect(
      (tickets.body.datos as Array<{ pedido_id: string }>).some(
        (ticket) => ticket.pedido_id === id,
      ),
    ).toBe(true);

    const repetir = await api()
      .patch(`/api/v1/pedidos/${id}/aprobar?sucursal_id=${SID}`)
      .set(admin.auth)
      .send({ mesera_id: meseraId });
    expect(repetir.body.exito).toBe(false);
  });

  it('gerente aprueba pedidos QR dentro de su sucursal', async () => {
    const menu = await api().get(`/api/v1/menu/mesa/${QR_TOKEN}`);
    expect(menu.body.exito).toBe(true);
    const mesaId = menu.body.datos?.mesa?.id || menu.body.datos?.id;
    expect(mesaId).toBeTruthy();

    const device = await registrarDispositivoCliente('jest-qr-gerente');
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
    expect(crear.status).toBe(201);
    const id = pedidoId(crear);

    const meseras = await api()
      .get(`/api/v1/usuarios/meseros-activos?sucursal_id=${SID}`)
      .set(admin.auth);
    expect(meseras.body.exito).toBe(true);
    const meseraId = (meseras.body.datos as Array<{ id: string }>)[0]?.id;
    expect(meseraId).toBeTruthy();

    const aprobar = await api()
      .patch(`/api/v1/pedidos/${id}/aprobar?sucursal_id=${SID}`)
      .set(gerente.auth)
      .send({ mesera_id: meseraId });
    expect(aprobar.status).toBe(200);
    expect(aprobar.body.datos?.estado).toBe('en_cocina');
  });

  it('Admin rechaza pedido QR y la mesa queda libre', async () => {
    const menu = await api().get(`/api/v1/menu/mesa/${QR_TOKEN}`);
    expect(menu.body.exito).toBe(true);
    const mesaId = menu.body.datos?.mesa?.id || menu.body.datos?.id;
    expect(mesaId).toBeTruthy();

    const device = await registrarDispositivoCliente('jest-qr-rechazar');
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
    expect(crear.status).toBe(201);
    const id = pedidoId(crear);

    const rechazar = await api()
      .patch(`/api/v1/pedidos/${id}/rechazar?sucursal_id=${SID}`)
      .set(admin.auth)
      .send({ motivo: 'Pedido QR de prueba rechazado' });
    expect(rechazar.status).toBe(200);
    expect(rechazar.body.datos?.estado).toBe('rechazado');

    const detalle = await detallePedido(admin.auth, id);
    expect(
      detalle.body.datos?.estado ?? detalle.body.datos?.pedido?.estado,
    ).toBe('rechazado');

    const mesa = await api().get(`/api/v1/mesas/${SID}`).set(admin.auth);
    expect(mesa.body.exito).toBe(true);
    const mesaFinal = (
      mesa.body.datos as Array<{ id: string; estado?: string }>
    ).find((m) => m.id === mesaId);
    expect(mesaFinal).toBeTruthy();
    expect(mesaFinal?.estado).not.toBe('ocupada');
  });

  it('mesero aprueba pedido QR, se asigna a sí misma y envía el ticket a KDS', async () => {
    const email = `mesero-qr-${randomUUID()}@qa.example`;
    const creadoUsuario = await api()
      .post('/api/v1/usuarios')
      .set(admin.auth)
      .send({
        nombre: 'Mesero QR E2E',
        email,
        contrasena: '123456',
        rol: 'mesero',
        sucursal_id: SID,
      });
    expect(creadoUsuario.body.exito).toBe(true);
    const usuarioId = creadoUsuario.body.datos?.id as string;
    expect(usuarioId).toBeTruthy();

    try {
      const mesero = await login(email);
      const menu = await api().get(`/api/v1/menu/mesa/${QR_TOKEN}`);
      expect(menu.body.exito).toBe(true);
      const mesaId = menu.body.datos?.mesa?.id || menu.body.datos?.id;
      expect(mesaId).toBeTruthy();

      const device = await registrarDispositivoCliente('jest-qr-mesero');
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
      expect(crear.status).toBe(201);
      const id = pedidoId(crear);

      const aprobar = await api()
        .patch(`/api/v1/pedidos/${id}/aprobar?sucursal_id=${SID}`)
        .set(mesero.auth)
        .send({});
      expect(aprobar.status).toBe(200);
      expect(aprobar.body.datos?.estado).toBe('en_cocina');
      expect(aprobar.body.datos?.mesera_id).toBe(usuarioId);

      const tickets = await api()
        .get(`/api/v1/cocina/tickets/${COCINA_ID}`)
        .set(cocina.auth);
      expect(tickets.body.exito).toBe(true);
      expect(
        (tickets.body.datos as Array<{ pedido_id: string }>).some(
          (ticket) => ticket.pedido_id === id,
        ),
      ).toBe(true);
    } finally {
      await limpiarPedidosActivos(admin.auth);
      await api()
        .patch(`/api/v1/usuarios/${usuarioId}/estado?sucursal_id=${SID}`)
        .set(admin.auth)
        .send({ activo: false });
    }
  });

  it('el rol cocina no puede aprobar ni rechazar pedidos QR', async () => {
    const cocina = await login('cocina@foody.demo');
    const id = randomUUID();
    const aprobar = await api()
      .patch(`/api/v1/pedidos/${id}/aprobar?sucursal_id=${SID}`)
      .set(cocina.auth)
      .send({ mesera_id: randomUUID() });
    const rechazar = await api()
      .patch(`/api/v1/pedidos/${id}/rechazar?sucursal_id=${SID}`)
      .set(cocina.auth)
      .send({ motivo: 'No autorizado' });
    const aprobarCajero = await api()
      .patch(`/api/v1/pedidos/${randomUUID()}/aprobar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ mesera_id: randomUUID() });

    expect(aprobar.status).toBe(403);
    expect(rechazar.status).toBe(403);
    expect(aprobarCajero.status).toBe(403);
  });

  it('aísla Mis pedidos por dispositivo y permite seguimiento solo con su token', async () => {
    const [deviceA, deviceB] = await Promise.all([
      registrarDispositivoCliente('jest-mios-a'),
      registrarDispositivoCliente('jest-mios-b'),
    ]);
    const crear = async (device: typeof deviceA, nombre: string) =>
      api()
        .post('/api/v1/pedidos')
        .set(device.headers)
        .send({
          sucursal_id: SID,
          device_id: device.deviceId,
          tipo: 'para_llevar',
          metodo_pago: 'pendiente',
          cliente_nombre: nombre,
          cliente_telefono: '3000000098',
          idempotency_key: randomUUID(),
          items: [{ producto_id: PRODUCTO, cantidad: 1, precio: PRECIO }],
        });

    const [pedidoA, pedidoB] = await Promise.all([
      crear(deviceA, 'QA dispositivo A'),
      crear(deviceB, 'QA dispositivo B'),
    ]);
    expect(pedidoA.status).toBe(201);
    expect(pedidoB.status).toBe(201);
    const pedidoIdB = pedidoB.body.datos.pedido_id;

    const miosA = await api()
      .get(
        `/api/v1/pedidos/mios?device_id=${encodeURIComponent(deviceA.deviceId)}`,
      )
      .set(deviceA.headers);
    expect(miosA.status).toBe(200);
    expect(miosA.body.datos.map((p: { id: string }) => p.id)).toContain(
      pedidoA.body.datos.pedido_id,
    );
    expect(miosA.body.datos.map((p: { id: string }) => p.id)).not.toContain(
      pedidoIdB,
    );

    const seguimientoAjeno = await api()
      .get(
        `/api/v1/pedidos/${pedidoIdB}/estado?device_id=${encodeURIComponent(deviceA.deviceId)}`,
      )
      .set(deviceA.headers);
    expect(seguimientoAjeno.status).toBe(403);
    expect(seguimientoAjeno.body.error).toBe('PROHIBIDO');

    const seguimientoConToken = await api().get(
      `/api/v1/pedidos/${pedidoIdB}/estado?token=${encodeURIComponent(pedidoB.body.datos.seguimiento_token)}`,
    );
    expect(seguimientoConToken.status).toBe(200);
    expect(seguimientoConToken.body.datos.pedido_id).toBe(pedidoIdB);

    const cancelarPedidoAjeno = await api()
      .post(`/api/v1/pedidos/${pedidoIdB}/cancelar`)
      .set(deviceA.headers)
      .send({ device_id: deviceA.deviceId, motivo: 'No es mi pedido' });
    expect(cancelarPedidoAjeno.status).toBe(404);

    const cancelarPedidoPropio = await api()
      .post(`/api/v1/pedidos/${pedidoA.body.datos.pedido_id}/cancelar`)
      .set(deviceA.headers)
      .send({
        device_id: deviceA.deviceId,
        motivo: 'El cliente cambió de opinión',
      });
    expect(cancelarPedidoPropio.status).toBe(201);
    expect(cancelarPedidoPropio.body.exito).toBe(true);
    expect(cancelarPedidoPropio.body.datos.estado).toBe('cancelado');
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
