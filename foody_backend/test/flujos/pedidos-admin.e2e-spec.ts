import {
  api,
  assertApiViva,
  COCINA_ID,
  crearPedidoStaff,
  detallePedido,
  ensureCajaAbierta,
  itemBody,
  limpiarPedidosActivos,
  login,
  marcarItemsCocinaListos,
  mesaLibre,
  pedidoId,
  SID,
  setEstado,
  TokenBundle,
} from '../helpers/foody-e2e';
import { randomUUID } from 'crypto';

describe('E2E rutas administrativas de pedidos', () => {
  let admin: TokenBundle;
  let gerente: TokenBundle;
  let cajero: TokenBundle;
  let cocina: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
    gerente = await login('gerente@foody.demo');
    cajero = await login('cajero.test@foody.demo');
    cocina = await login('cocina@foody.demo');
  });

  beforeEach(async () => {
    await limpiarPedidosActivos(admin.auth);
  });

  afterEach(async () => {
    await limpiarPedidosActivos(admin.auth);
  });

  it('Admin puede consultar pedidos cerrados del día con un resultado paginable', async () => {
    const respuesta = await api()
      .get(`/api/v1/pedidos/cerrados-hoy?sucursal_id=${SID}&page=1&limit=10`)
      .set(admin.auth);

    expect(respuesta.status).toBe(200);
    expect(respuesta.body.exito).toBe(true);
    expect(respuesta.body.datos).toEqual(
      expect.objectContaining({
        items: expect.any(Array),
        page: expect.any(Number),
        limit: expect.any(Number),
        total: expect.any(Number),
      }),
    );
  });

  it('cajero etiqueta un comensal y la cuenta de mesa conserva la etiqueta', async () => {
    const mesaId = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesaId,
      tipo: 'mesa',
      metodo_pago: 'pendiente',
      device_id: `jest-comensal-${Date.now()}`,
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    const detalleInicial = await detallePedido(cajero.auth, id);
    const datosIniciales = detalleInicial.body.datos ?? {};
    const items = (datosIniciales.items_resumen ||
      datosIniciales.items ||
      datosIniciales.pedido?.items ||
      []) as Array<{ id?: string; item_id?: string }>;
    const itemId = items[0]?.item_id || items[0]?.id;
    expect(itemId).toBeTruthy();

    const etiqueta = 'Pedido familiar A';
    const actualizar = await api()
      .patch(
        `/api/v1/pedidos/${id}/items/${itemId}/comensal?sucursal_id=${SID}`,
      )
      .set(cajero.auth)
      .send({ comensal_etiqueta: etiqueta });
    expect(actualizar.status).toBe(200);
    expect(actualizar.body.datos?.comensal_etiqueta).toBe(etiqueta);

    const cuentaFinal = await api()
      .get(`/api/v1/pedidos/mesa/${mesaId}?sucursal_id=${SID}`)
      .set(cajero.auth);
    expect(cuentaFinal.body.exito).toBe(true);
    const pedidos = (cuentaFinal.body.datos?.pedidos || []) as Array<{
      id: string;
      items: Array<{ id: string; comensal_etiqueta?: string | null }>;
    }>;
    const pedidoFinal = pedidos.find((pedido) => pedido.id === id);
    expect(
      pedidoFinal?.items.find((item) => item.id === itemId)?.comensal_etiqueta,
    ).toBe(etiqueta);
  });

  it('el descuento aplicado sobrepago devuelve el excedente por Caja y concilia el pedido', async () => {
    await ensureCajaAbierta(cajero.auth);
    const mesaId = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesaId,
      tipo: 'mesa',
      metodo_pago: 'pendiente',
      device_id: `jest-descuento-refund-${Date.now()}`,
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    const total = Number(crear.body.datos?.total);
    expect(total).toBeGreaterThan(0);

    await marcarItemsCocinaListos(cocina.auth, id, cajero.auth);
    expect((await setEstado(cajero.auth, id, 'listo')).body.exito).toBe(true);
    expect((await setEstado(cajero.auth, id, 'pagando')).body.exito).toBe(true);

    const abono = total - 500;
    const cobrar = await api()
      .post(`/api/v1/pedidos/mesa/${mesaId}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({
        monto_parcial: abono,
        pagos: [{ metodo_pago: 'efectivo', monto: abono }],
      });
    expect(cobrar.body.exito).toBe(true);

    const descuento = await api()
      .post(`/api/v1/pedidos/${id}/descuento?sucursal_id=${SID}`)
      .set(admin.auth)
      .send({ monto: 1000, motivo: 'Ajuste de precio autorizado QA' });
    expect(descuento.status).toBe(201);
    expect(descuento.body.exito).toBe(true);
    expect(Number(descuento.body.datos?.total)).toBe(total - 1000);
    expect(descuento.body.datos?.estado).toBe('pagado');

    const detalle = await detallePedido(admin.auth, id);
    const datos = detalle.body.datos ?? {};
    expect(Number(datos.total)).toBe(total - 1000);
    expect(Number(datos.monto_pagado)).toBe(total - 1000);
    expect(Number(datos.devoluciones_caja_vinculadas)).toBe(500);
    expect(Number(datos.recaudo_neto_caja_vinculado)).toBe(total - 1000);
  });

  it('Admin y gerente pasan el permiso de descuento; caja lo recibe denegado', async () => {
    const id = randomUUID();
    const body = { monto: 500, motivo: 'Prueba RBAC sin pedido existente' };
    const adminPermitido = await api()
      .post(`/api/v1/pedidos/${id}/descuento?sucursal_id=${SID}`)
      .set(admin.auth)
      .send(body);
    const gerentePermitido = await api()
      .post(`/api/v1/pedidos/${id}/descuento?sucursal_id=${SID}`)
      .set(gerente.auth)
      .send(body);
    const cajeroDenegado = await api()
      .post(`/api/v1/pedidos/${id}/descuento?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send(body);

    expect(adminPermitido.status).toBe(404);
    expect(gerentePermitido.status).toBe(404);
    expect(cajeroDenegado.status).toBe(403);
  });

  it('cocina no puede cambiar estados ni agregar líneas por las rutas generales de pedidos', async () => {
    const id = randomUUID();
    const itemId = randomUUID();
    const [
      estado,
      agregarLinea,
      reemplazarLinea,
      actualizarLinea,
      eliminarLinea,
      asignarComensal,
    ] = await Promise.all([
      api()
        .patch(`/api/v1/pedidos/${id}/estado?sucursal_id=${SID}`)
        .set(cocina.auth)
        .send({
          estado: 'cancelado',
          motivo: 'Prueba RBAC sin pedido existente',
        }),
      api()
        .post(`/api/v1/pedidos/${id}/items?sucursal_id=${SID}`)
        .set(cocina.auth)
        .send({
          items: [{ producto_id: randomUUID(), cantidad: 1, precio: 8000 }],
        }),
      api()
        .post(
          `/api/v1/pedidos/${id}/items/${itemId}/reemplazar?sucursal_id=${SID}`,
        )
        .set(cocina.auth)
        .send({ producto_id: randomUUID(), motivo: 'Prueba RBAC' }),
      api()
        .patch(`/api/v1/pedidos/${id}/items/${itemId}?sucursal_id=${SID}`)
        .set(cocina.auth)
        .send({ observaciones: 'Prueba RBAC' }),
      api()
        .delete(`/api/v1/pedidos/${id}/items/${itemId}?sucursal_id=${SID}`)
        .set(cocina.auth)
        .send({ motivo: 'Prueba RBAC' }),
      api()
        .patch(
          `/api/v1/pedidos/${id}/items/${itemId}/comensal?sucursal_id=${SID}`,
        )
        .set(cocina.auth)
        .send({ comensal_etiqueta: 'Prueba RBAC' }),
    ]);

    expect([
      estado.status,
      agregarLinea.status,
      reemplazarLinea.status,
      actualizarLinea.status,
      eliminarLinea.status,
      asignarComensal.status,
    ]).toEqual([403, 403, 403, 403, 403, 403]);
  });

  it('cocina accede a su KDS pero no a pedidos generales ni a Caja', async () => {
    const [ticketsKds, pedidos, caja] = await Promise.all([
      api().get(`/api/v1/cocina/tickets/${COCINA_ID}`).set(cocina.auth),
      api().get(`/api/v1/pedidos?sucursal_id=${SID}`).set(cocina.auth),
      api().get(`/api/v1/caja/activa/${SID}`).set(cocina.auth),
    ]);

    expect(ticketsKds.status).toBe(200);
    expect(ticketsKds.body.exito).toBe(true);
    expect(pedidos.status).toBe(403);
    expect(caja.status).toBe(403);
  });

  it('cajero consulta pedidos y Caja pero no accede al KDS', async () => {
    const [pedidos, caja, ticketsKds] = await Promise.all([
      api().get(`/api/v1/pedidos?sucursal_id=${SID}`).set(cajero.auth),
      api().get(`/api/v1/caja/activa/${SID}`).set(cajero.auth),
      api().get(`/api/v1/cocina/tickets/${COCINA_ID}`).set(cajero.auth),
    ]);

    expect(pedidos.status).toBe(200);
    expect(pedidos.body.exito).toBe(true);
    expect(caja.status).not.toBe(403);
    expect(ticketsKds.status).toBe(403);
  });
});
