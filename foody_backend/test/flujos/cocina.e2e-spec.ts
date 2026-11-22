/**
 * Flujo crítico: cocina/KDS — tickets, transiciones ítem, COC-NODISP-01.
 */
import {
  api,
  assertApiViva,
  COCINA_ID,
  crearPedidoStaff,
  ensureCajaAbierta,
  itemBody,
  limpiarPedidosActivos,
  login,
  mesaLibre,
  pedidoId,
  SID,
  TokenBundle,
} from '../helpers/foody-e2e';

describe('E2E cocina KDS', () => {
  let admin: TokenBundle;
  let cajero: TokenBundle;
  let cocina: TokenBundle;
  let cocinaId = COCINA_ID;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
    cajero = await login('cajero.test@foody.demo');
    cocina = await login('cocina@foody.demo');
    const cocinas = await api().get('/api/v1/cocina/cocinas').set(cocina.auth);
    if (cocinas.body?.exito && Array.isArray(cocinas.body.datos) && cocinas.body.datos[0]?.id) {
      cocinaId = cocinas.body.datos[0].id;
    }
  });

  beforeEach(async () => {
    await limpiarPedidosActivos(admin.auth);
    await ensureCajaAbierta(cajero.auth);
  });

  it('pedido aparece en tickets y llega a listo cuando todos los ítems listos', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: 'jest-kds-happy',
      metodo_pago: 'efectivo',
      items: [itemBody(), itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);

    const tickets = await api().get(`/api/v1/cocina/tickets/${cocinaId}`).set(cocina.auth);
    expect(tickets.body.exito).toBe(true);
    const ticket = (tickets.body.datos as Array<{ pedido_id: string; items: Array<{ item_id?: string; id?: string }> }>).find(
      (t) => t.pedido_id === id,
    );
    expect(ticket).toBeTruthy();
    const items = ticket!.items;
    expect(items.length).toBeGreaterThanOrEqual(2);

    const id1 = items[0].item_id || items[0].id!;
    const id2 = items[1].item_id || items[1].id!;

    for (const itemId of [id1, id2]) {
      await api()
        .patch(`/api/v1/cocina/items/${itemId}/estado`)
        .set(cocina.auth)
        .send({ estado_cocina: 'preparando' });
      const listo = await api()
        .patch(`/api/v1/cocina/items/${itemId}/estado`)
        .set(cocina.auth)
        .send({ estado_cocina: 'listo' });
      expect(listo.body.exito).toBe(true);
    }

    const det = await api()
      .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
      .set(cajero.auth);
    expect(det.body.datos?.estado || det.body.datos?.pedido?.estado).toBe('listo');
  });

  it('COC-NODISP-01: ítem no_disponible cuenta resuelto y pedido llega a listo', async () => {
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: 'jest-kds-nodisp',
      metodo_pago: 'pendiente',
      items: [itemBody(), itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);

    const tickets = await api().get(`/api/v1/cocina/tickets/${cocinaId}`).set(cocina.auth);
    const ticket = (tickets.body.datos as Array<{ pedido_id: string; items: Array<{ item_id?: string; id?: string }> }>).find(
      (t) => t.pedido_id === id,
    );
    expect(ticket).toBeTruthy();
    const ic1 = ticket!.items[0].item_id || ticket!.items[0].id!;
    const ic2 = ticket!.items[1].item_id || ticket!.items[1].id!;

    await api()
      .patch(`/api/v1/cocina/items/${ic1}/estado`)
      .set(cocina.auth)
      .send({ estado_cocina: 'no_disponible', motivo: 'jest sin insumos' });
    await api()
      .patch(`/api/v1/cocina/items/${ic2}/estado`)
      .set(cocina.auth)
      .send({ estado_cocina: 'listo' });

    const det = await api()
      .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
      .set(cajero.auth);
    const estado = det.body.datos?.estado || det.body.datos?.pedido?.estado;
    expect(estado).toBe('listo');
  });
});
