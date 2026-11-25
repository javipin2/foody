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
  PRODUCTO,
  setEstado,
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
    if (
      cocinas.body?.exito &&
      Array.isArray(cocinas.body.datos) &&
      cocinas.body.datos[0]?.id
    ) {
      cocinaId = cocinas.body.datos[0].id;
    }
  });

  beforeEach(async () => {
    await limpiarPedidosActivos(admin.auth);
    await ensureCajaAbierta(cajero.auth);
  });

  afterAll(async () => {
    // COC-NODISP-01 intentionally turns the menu product off. Restore the
    // canonical fixture so later E2E suites can create orders with the same SKU.
    if (!admin) return;
    const restaurar = await api()
      .patch(`/api/v1/productos/${PRODUCTO}/disponibilidad`)
      .set(admin.auth)
      .send({ disponible: true });
    if (!restaurar.body?.exito) {
      throw new Error(
        'No se pudo restaurar el producto demo al cerrar E2E cocina',
      );
    }
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

    const tickets = await api()
      .get(`/api/v1/cocina/tickets/${cocinaId}`)
      .set(cocina.auth);
    expect(tickets.body.exito).toBe(true);
    const ticket = (
      tickets.body.datos as Array<{
        pedido_id: string;
        items: Array<{ item_id?: string; id?: string }>;
      }>
    ).find((t) => t.pedido_id === id);
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
    expect(det.body.datos?.estado || det.body.datos?.pedido?.estado).toBe(
      'listo',
    );
  });

  it('rechaza listo global si una línea todavía está pendiente en Cocina', async () => {
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: `jest-kds-listo-incompleto-${Date.now()}`,
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);

    const listo = await setEstado(admin.auth, id, 'listo');
    expect(listo.status).toBe(400);
    expect(listo.body.mensaje).toMatch(/resolver todos sus ítems en Cocina/i);

    const detalle = await api()
      .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
      .set(admin.auth);
    expect(detalle.body.datos.estado).toBe('en_cocina');
  });

  it('COC-DISPATCH-INCOMPLETE-01: no asigna ni oferta un domicilio con Cocina pendiente', async () => {
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'domicilio',
      device_id: `jest-kds-dispatch-incompleto-${Date.now()}`,
      cliente_nombre: 'QA Cocina pendiente',
      cliente_telefono: '3000000099',
      direccion_entrega: 'Calle QA 100',
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);

    const enCocina = await setEstado(admin.auth, id, 'en_cocina');
    expect(enCocina.body.exito).toBe(true);

    const intentarListo = await setEstado(admin.auth, id, 'listo');
    expect(intentarListo.status).toBe(400);
    expect(intentarListo.body.mensaje).toMatch(
      /resolver todos sus ítems en Cocina/i,
    );

    const asignarPlanta = await api()
      .post('/api/v1/domiciliarios-planta/asignar')
      .set(admin.auth)
      .send({
        pedido_id: id,
        sucursal_id: SID,
        domiciliario_planta_id: '92000000-0000-4000-8000-000000000001',
      });
    expect(asignarPlanta.status).toBe(400);
    expect(asignarPlanta.body.message || asignarPlanta.body.mensaje).toMatch(
      /debe estar listo/i,
    );

    const ofertarIndependiente = await api()
      .post(`/api/v1/domiciliarios-planta/dispatch-independiente/${id}`)
      .query({ sucursal_id: SID })
      .set(admin.auth);
    expect(ofertarIndependiente.body.exito).toBe(true);
    expect(ofertarIndependiente.body.datos).toMatchObject({
      iniciado: false,
      motivo: 'PEDIDO_NO_LISTO',
    });

    const detalle = await api()
      .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
      .set(admin.auth);
    expect(detalle.body.datos.estado).toBe('en_cocina');
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

    const tickets = await api()
      .get(`/api/v1/cocina/tickets/${cocinaId}`)
      .set(cocina.auth);
    const ticket = (
      tickets.body.datos as Array<{
        pedido_id: string;
        items: Array<{ item_id?: string; id?: string }>;
      }>
    ).find((t) => t.pedido_id === id);
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

  it('COC-NODISP-DOM-01: no asigna ni oferta un domicilio con una línea no disponible', async () => {
    // The previous COC-NODISP case intentionally disables this canonical demo SKU.
    const habilitarProducto = await api()
      .patch(`/api/v1/productos/${PRODUCTO}/disponibilidad`)
      .set(admin.auth)
      .send({ disponible: true });
    expect(habilitarProducto.body.exito).toBe(true);

    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'domicilio',
      device_id: `jest-kds-domi-nodisp-${Date.now()}`,
      cliente_nombre: 'QA Domicilio',
      cliente_telefono: '3000000099',
      direccion_entrega: 'Calle QA 99',
      metodo_pago: 'pendiente',
      items: [itemBody(), itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    expect((await setEstado(admin.auth, id, 'en_cocina')).body.exito).toBe(
      true,
    );

    const tickets = await api()
      .get(`/api/v1/cocina/tickets/${cocinaId}`)
      .set(cocina.auth);
    const ticket = (
      tickets.body.datos as Array<{
        pedido_id: string;
        items: Array<{ item_id?: string; id?: string }>;
      }>
    ).find((t) => t.pedido_id === id);
    expect(ticket).toBeTruthy();
    const itemNoDisponible = ticket!.items[0].item_id || ticket!.items[0].id!;
    const itemListo = ticket!.items[1].item_id || ticket!.items[1].id!;

    const reportarFaltante = await api()
      .patch(`/api/v1/cocina/items/${itemNoDisponible}/estado`)
      .set(cocina.auth)
      .send({
        estado_cocina: 'no_disponible',
        motivo: 'QA verifica barrera de despacho',
      });
    expect(reportarFaltante.body.exito).toBe(true);
    const completarCocina = await api()
      .patch(`/api/v1/cocina/items/${itemListo}/estado`)
      .set(cocina.auth)
      .send({ estado_cocina: 'listo' });
    expect(completarCocina.body.exito).toBe(true);

    const detalle = await api()
      .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
      .set(cajero.auth);
    expect(
      detalle.body.datos?.estado || detalle.body.datos?.pedido?.estado,
    ).toBe('listo');

    const asignar = await api()
      .post('/api/v1/domiciliarios-planta/asignar')
      .set(admin.auth)
      .send({
        pedido_id: id,
        sucursal_id: SID,
        domiciliario_planta_id: '92000000-0000-4000-8000-000000000001',
      });
    expect(asignar.body.exito).toBe(false);
    expect(asignar.body.mensaje).toMatch(
      /no disponible|confirma el total|ajusta las líneas/i,
    );

    const ofertar = await api()
      .post(
        `/api/v1/domiciliarios-planta/dispatch-independiente/${id}?sucursal_id=${SID}`,
      )
      .set(admin.auth);
    expect(ofertar.body.exito).toBe(true);
    expect(ofertar.body.datos).toMatchObject({
      iniciado: false,
      motivo: 'PEDIDO_ITEMS_NO_DISPONIBLES',
    });
    expect(ofertar.body.datos.mensaje).toMatch(
      /no disponible|confirma el total|ajusta las líneas/i,
    );
  });

  it('COC-NODISP-DELETE-STOCK-01: eliminar una línea N/D no restaura stock ya registrado como merma', async () => {
    const habilitarProducto = await api()
      .patch(`/api/v1/productos/${PRODUCTO}/disponibilidad`)
      .set(admin.auth)
      .send({ disponible: true });
    expect(habilitarProducto.body.exito).toBe(true);

    const receta = await api()
      .get(`/api/v1/inventario/producto-ingredientes/${PRODUCTO}`)
      .set(admin.auth);
    const ingredientes = (receta.body.datos?.items || []) as Array<{
      ingrediente_id?: string;
    }>;
    const ingredienteId = ingredientes.find(
      (i) => i.ingrediente_id,
    )?.ingrediente_id;
    expect(ingredienteId).toBeTruthy();

    const stock = async () => {
      const inventario = await api()
        .get(`/api/v1/inventario/${SID}`)
        .set(admin.auth);
      const fila = (
        inventario.body.datos as Array<{
          id: string;
          stock_actual: string | number;
        }>
      ).find((i) => i.id === ingredienteId);
      expect(fila).toBeTruthy();
      return Number(fila!.stock_actual);
    };

    const pedido = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: `jest-kds-delete-nodisp-${Date.now()}`,
      metodo_pago: 'pendiente',
      items: [itemBody(), itemBody()],
    });
    expect(pedido.body.exito).toBe(true);
    const id = pedidoId(pedido);
    const stockTrasAlta = await stock();
    const detalleAntes = await api()
      .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
      .set(cajero.auth);
    const totalAntes = Number(detalleAntes.body.datos?.total);

    const tickets = await api()
      .get(`/api/v1/cocina/tickets/${cocinaId}`)
      .set(cocina.auth);
    const ticket = (
      tickets.body.datos as Array<{
        pedido_id: string;
        items: Array<{ item_id?: string; id?: string }>;
      }>
    ).find((t) => t.pedido_id === id);
    expect(ticket?.items.length).toBeGreaterThanOrEqual(2);
    const itemId = ticket!.items[0].item_id || ticket!.items[0].id!;

    const marcarNoDisponible = await api()
      .patch(`/api/v1/cocina/items/${itemId}/estado`)
      .set(cocina.auth)
      .send({
        estado_cocina: 'no_disponible',
        motivo: 'QA merma antes de borrar línea',
      });
    expect(marcarNoDisponible.body.exito).toBe(true);

    const eliminar = await api()
      .delete(`/api/v1/pedidos/${id}/items/${itemId}?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ motivo: 'QA elimina línea no servida' });
    expect(eliminar.body.exito).toBe(true);
    expect(await stock()).toBeCloseTo(stockTrasAlta, 4);

    const detalleDespues = await api()
      .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
      .set(cajero.auth);
    expect(Number(detalleDespues.body.datos?.total)).toBeLessThan(totalAntes);
    expect(detalleDespues.body.datos?.items_resumen).toHaveLength(1);
  });

  it('COC-CANCEL-NODISP-MERMA-01: cancelar pedido no duplica merma de línea N/D', async () => {
    const habilitarProducto = await api()
      .patch(`/api/v1/productos/${PRODUCTO}/disponibilidad`)
      .set(admin.auth)
      .send({ disponible: true });
    expect(habilitarProducto.body.exito).toBe(true);

    const pedido = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: `jest-kds-cancel-nodisp-${Date.now()}`,
      metodo_pago: 'pendiente',
      items: [itemBody(), itemBody()],
    });
    expect(pedido.body.exito).toBe(true);
    const id = pedidoId(pedido);
    const tickets = await api()
      .get(`/api/v1/cocina/tickets/${cocinaId}`)
      .set(cocina.auth);
    const ticket = (
      tickets.body.datos as Array<{
        pedido_id: string;
        items: Array<{ item_id?: string; id?: string }>;
      }>
    ).find((item) => item.pedido_id === id);
    expect(ticket?.items.length).toBeGreaterThanOrEqual(2);
    const itemId = ticket!.items[0].item_id || ticket!.items[0].id!;

    const noDisponible = await api()
      .patch(`/api/v1/cocina/items/${itemId}/estado`)
      .set(cocina.auth)
      .send({
        estado_cocina: 'no_disponible',
        motivo: 'QA cancelación sin duplicar merma',
      });
    expect(noDisponible.body.exito).toBe(true);

    const mermas = async () => {
      const response = await api()
        .get(`/api/v1/inventario/movimientos/${SID}?page=1&limit=100`)
        .set(admin.auth);
      expect(response.body.exito).toBe(true);
      return (
        response.body.datos.items as Array<{
          pedido_id: string;
          tipo: string;
        }>
      ).filter(
        (movimiento) =>
          movimiento.pedido_id === id && movimiento.tipo === 'merma',
      ).length;
    };
    const mermaPrevia = await mermas();
    expect(mermaPrevia).toBeGreaterThan(0);

    const cancelar = await setEstado(admin.auth, id, 'cancelado', {
      motivo: 'QA cancelar ticket con línea N/D',
    });
    expect(cancelar.body.exito).toBe(true);
    expect(await mermas()).toBe(mermaPrevia * 2);
  });
});
