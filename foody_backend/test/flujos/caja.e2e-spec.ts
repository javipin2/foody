/**
 * Flujo crítico: caja — apertura, cobro genera venta, no reopen pagado (VIE-06).
 */
import {
  api,
  assertApiViva,
  crearPedidoStaff,
  ensureCajaAbierta,
  detallePedido,
  itemBody,
  limpiarPedidosActivos,
  login,
  marcarItemsCocinaListos,
  mesaLibre,
  pedidoId,
  setEstado,
  SID,
  TokenBundle,
} from '../helpers/foody-e2e';

describe('E2E caja', () => {
  let admin: TokenBundle;
  let cajero: TokenBundle;
  let cocina: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
    cajero = await login('cajero.test@foody.demo');
    cocina = await login('cocina@foody.demo');
  });

  beforeEach(async () => {
    await limpiarPedidosActivos(admin.auth);
    await ensureCajaAbierta(cajero.auth);
  });

  it('caja activa + cobro mesa → pedido pagado', async () => {
    const caja = await api().get(`/api/v1/caja/activa/${SID}`).set(cajero.auth);
    expect(caja.body.exito).toBe(true);
    expect(caja.body.datos?.id).toBeTruthy();

    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: 'jest-caja-cobro',
      metodo_pago: 'efectivo',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);

    await marcarItemsCocinaListos(cocina.auth, id, cajero.auth);
    expect((await setEstado(cajero.auth, id, 'listo')).body.exito).toBe(true);
    expect((await setEstado(cajero.auth, id, 'pagando')).body.exito).toBe(true);

    const cobrar = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ metodo_pago: 'efectivo' });
    expect(cobrar.body.exito).toBe(true);

    const det = await api()
      .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
      .set(cajero.auth);
    const estado = det.body.datos?.estado || det.body.datos?.pedido?.estado;
    expect(estado).toBe('pagado');
  });

  it('consulta el movimiento de un pedido aunque su caja ya cerró', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: `jest-caja-pedido-historico-${Date.now()}`,
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);

    await marcarItemsCocinaListos(cocina.auth, id, cajero.auth);
    expect((await setEstado(cajero.auth, id, 'listo')).body.exito).toBe(true);
    expect((await setEstado(cajero.auth, id, 'pagando')).body.exito).toBe(true);
    expect(
      (
        await api()
          .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
          .set(cajero.auth)
          .send({ metodo_pago: 'efectivo' })
      ).body.exito,
    ).toBe(true);

    const caja = await api().get(`/api/v1/caja/activa/${SID}`).set(cajero.auth);
    const cierre = await api()
      .post('/api/v1/caja/cerrar')
      .set(cajero.auth)
      .send({
        caja_id: caja.body.datos.id,
        monto_final_contado: Number(caja.body.datos.saldo_sistema),
      });
    expect(cierre.body.exito).toBe(true);

    const historial = await api()
      .get(
        `/api/v1/caja/pedidos/${id}/movimientos?page=1&limit=20&sucursal_id=${SID}`,
      )
      .set(admin.auth);
    expect(historial.body.exito).toBe(true);
    expect(historial.body.datos.items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          pedido_id: id,
          tipo: 'venta',
          caja_estado: 'cerrada',
        }),
      ]),
    );
  });

  it('cancelar pedido con abono mixto revierte cada método y conserva el neto', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: `jest-caja-reversa-mixta-${Date.now()}`,
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    const total = Number(crear.body.datos?.total);
    const abonoMixto = Math.min(total - 0.01, 5000);
    const efectivo = Math.round(abonoMixto * 0.6 * 100) / 100;
    const tarjeta = abonoMixto - efectivo;

    await marcarItemsCocinaListos(cocina.auth, id, cajero.auth);
    expect((await setEstado(cajero.auth, id, 'listo')).body.exito).toBe(true);
    expect((await setEstado(cajero.auth, id, 'pagando')).body.exito).toBe(true);
    const cobrar = await api()
      .post(`/api/v1/pedidos/mesa/${mesa}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({
        monto_parcial: abonoMixto,
        pagos: [
          { metodo_pago: 'efectivo', monto: efectivo },
          { metodo_pago: 'tarjeta', monto: tarjeta },
        ],
      });
    expect(cobrar.body.exito).toBe(true);
    expect(Number(cobrar.body.datos?.total_cobrado)).toBeCloseTo(abonoMixto, 2);
    const detalleAntesDeCancelar = await detallePedido(cajero.auth, id);
    expect(detalleAntesDeCancelar.body.datos.estado).toBe('pagando');

    const cancelar = await setEstado(admin.auth, id, 'cancelado', {
      motivo: 'QA reversa medio mixto',
    });
    if (!cancelar.body.exito) {
      throw new Error(
        `Cancelación mixta (${cancelar.status}): ${JSON.stringify(cancelar.body)}`,
      );
    }
    expect(cancelar.body.exito).toBe(true);
    expect(
      Number(cancelar.body.datos?.caja?.devolucion_automatica),
    ).toBeCloseTo(abonoMixto, 2);

    const caja = await api().get(`/api/v1/caja/activa/${SID}`).set(admin.auth);
    const movimientos = await api()
      .get(`/api/v1/caja/${caja.body.datos.id}/movimientos?page=1&limit=100`)
      .set(admin.auth);
    const delPedido = (
      movimientos.body.datos.items as Array<Record<string, unknown>>
    ).filter((movimiento) => movimiento.pedido_id === id);
    expect(
      delPedido
        .filter((movimiento) => movimiento.tipo === 'venta')
        .map((movimiento) => [movimiento.metodo_pago, Number(movimiento.monto)])
        .sort((a, b) => String(a[0]).localeCompare(String(b[0]))),
    ).toEqual(
      [
        ['efectivo', efectivo],
        ['tarjeta', tarjeta],
      ].sort((a, b) => String(a[0]).localeCompare(String(b[0]))),
    );
    expect(
      delPedido
        .filter((movimiento) => movimiento.tipo === 'devolucion')
        .map((movimiento) => [movimiento.metodo_pago, Number(movimiento.monto)])
        .sort((a, b) => String(a[0]).localeCompare(String(b[0]))),
    ).toEqual(
      [
        ['efectivo', efectivo],
        ['tarjeta', tarjeta],
      ].sort((a, b) => String(a[0]).localeCompare(String(b[0]))),
    );
  });

  it('cuenta mesa con varios tickets concilia cada pedido con Caja', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crearTickets = async (sufijo: string) => {
      const crear = await crearPedidoStaff(cajero.auth, {
        sucursal_id: SID,
        mesa_id: mesa,
        tipo: 'mesa',
        device_id: `jest-mesa-varios-${sufijo}-${Date.now()}`,
        metodo_pago: 'pendiente',
        items: [itemBody()],
      });
      expect(crear.body.exito).toBe(true);
      const id = pedidoId(crear);
      const total = Number(crear.body.datos?.total);
      expect(total).toBeGreaterThan(0);
      await marcarItemsCocinaListos(cocina.auth, id, cajero.auth);
      expect((await setEstado(cajero.auth, id, 'listo')).body.exito).toBe(true);
      expect((await setEstado(cajero.auth, id, 'pagando')).body.exito).toBe(
        true,
      );
      return { id, total };
    };

    const tickets = [await crearTickets('a'), await crearTickets('b')];
    const cobrar = await api()
      .post(`/api/v1/pedidos/mesa/${mesa}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({
        pagos: tickets.map((ticket, index) => ({
          metodo_pago: index === 0 ? 'efectivo' : 'tarjeta',
          monto: ticket.total,
        })),
      });
    expect(cobrar.body.exito).toBe(true);
    expect(Number(cobrar.body.datos?.total_cobrado)).toBeCloseTo(
      tickets.reduce((total, ticket) => total + ticket.total, 0),
      2,
    );

    const caja = await api().get(`/api/v1/caja/activa/${SID}`).set(admin.auth);
    expect(caja.body.exito).toBe(true);
    const movimientos = await api()
      .get(`/api/v1/caja/${caja.body.datos.id}/movimientos?page=1&limit=100`)
      .set(admin.auth);
    expect(movimientos.body.exito).toBe(true);
    const items = movimientos.body.datos.items as Array<
      Record<string, unknown>
    >;
    for (const ticket of tickets) {
      const venta = items.find(
        (movimiento) =>
          movimiento.pedido_id === ticket.id && movimiento.tipo === 'venta',
      );
      expect(venta).toBeTruthy();
      expect(Number(venta?.monto)).toBeCloseTo(ticket.total, 2);
      expect(venta?.metodo_pago).toBe(
        ticket === tickets[0] ? 'efectivo' : 'tarjeta',
      );
    }
  });

  it('FIN-SPLIT-01: split por ítem respeta el saldo de cada ticket tras abono', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crearTicket = async (sufijo: string) => {
      const crear = await crearPedidoStaff(cajero.auth, {
        sucursal_id: SID,
        mesa_id: mesa,
        tipo: 'mesa',
        device_id: `jest-split-saldo-${sufijo}-${Date.now()}`,
        metodo_pago: 'pendiente',
        items: [itemBody()],
      });
      expect(crear.body.exito).toBe(true);
      return { id: pedidoId(crear), total: Number(crear.body.datos?.total) };
    };
    const primero = await crearTicket('a');
    const segundo = await crearTicket('b');
    await marcarItemsCocinaListos(cocina.auth, primero.id, cajero.auth);
    await marcarItemsCocinaListos(cocina.auth, segundo.id, cajero.auth);

    const cuenta = await api()
      .get(`/api/v1/pedidos/mesa/${mesa}?sucursal_id=${SID}`)
      .set(cajero.auth);
    expect(cuenta.body.exito).toBe(true);
    const pedidos = cuenta.body.datos.pedidos as Array<{
      id: string;
      items: Array<{ id: string; estado_cobro: string }>;
    }>;
    const itemPrimero = pedidos.find((pedido) => pedido.id === primero.id)
      ?.items[0];
    const itemSegundo = pedidos.find((pedido) => pedido.id === segundo.id)
      ?.items[0];
    expect(itemPrimero?.id).toBeTruthy();
    expect(itemSegundo?.id).toBeTruthy();

    const abono = await api()
      .post(`/api/v1/pedidos/mesa/${mesa}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ monto_parcial: 4000, metodo_pago: 'efectivo' });
    expect(abono.body.exito).toBe(true);
    const saldoAntesRechazo = Number(abono.body.datos.saldo_restante);

    const caja = await api().get(`/api/v1/caja/activa/${SID}`).set(admin.auth);
    const movimientosAntes = await api()
      .get(`/api/v1/caja/${caja.body.datos.id}/movimientos?page=1&limit=100`)
      .set(admin.auth);
    const totalMovimientosAntes = (
      movimientosAntes.body.datos.items as Array<Record<string, unknown>>
    ).length;

    const exceso = await api()
      .post(`/api/v1/pedidos/mesa/${mesa}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({
        item_ids: [itemPrimero!.id, itemSegundo!.id],
        metodo_pago: 'efectivo',
      });
    expect(exceso.body.exito).toBe(false);
    expect(exceso.body.error).toBe('ITEMS_EXCEDEN_SALDO');

    const movimientosTrasRechazo = await api()
      .get(`/api/v1/caja/${caja.body.datos.id}/movimientos?page=1&limit=100`)
      .set(admin.auth);
    expect(
      (movimientosTrasRechazo.body.datos.items as Array<unknown>).length,
    ).toBe(totalMovimientosAntes);

    // El segundo ticket conserva saldo completo: cobrar ese ítem es válido.
    const splitSegundo = await api()
      .post(`/api/v1/pedidos/mesa/${mesa}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ item_ids: [itemSegundo!.id], metodo_pago: 'tarjeta' });
    expect(splitSegundo.body.exito).toBe(true);
    expect(Number(splitSegundo.body.datos.total_cobrado)).toBeCloseTo(
      segundo.total,
      2,
    );

    // El primer ticket quedó con 4.000 COP pendientes tras el abono.
    const cierre = await api()
      .post(`/api/v1/pedidos/mesa/${mesa}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ monto_parcial: primero.total - 4000, metodo_pago: 'efectivo' });
    expect(cierre.body.exito).toBe(true);
    expect(Number(cierre.body.datos.saldo_restante)).toBeCloseTo(0, 2);
    expect(saldoAntesRechazo).toBeCloseTo(
      primero.total + segundo.total - 4000,
      2,
    );
  });

  it('VIE-06: no reabrir pedido pagado', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: 'jest-caja-reopen',
      metodo_pago: 'efectivo',
      items: [itemBody()],
    });
    const id = pedidoId(crear);
    await marcarItemsCocinaListos(cocina.auth, id, cajero.auth);
    await setEstado(cajero.auth, id, 'listo');
    await setEstado(cajero.auth, id, 'pagando');
    await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ metodo_pago: 'efectivo' });

    const reopen = await setEstado(cajero.auth, id, 'en_cocina');
    expect(reopen.body.exito).toBeFalsy();
  });

  it('FIN-REC-OPEN-01: pedido cobrado concilia tickets, caja y Analítica', async () => {
    const partes = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'America/Bogota',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(new Date());
    const componente = (tipo: string) =>
      partes.find((parte) => parte.type === tipo)?.value ?? '';
    const hoyBogota = `${componente('year')}-${componente('month')}-${componente('day')}`;
    const query = `sucursal_id=${SID}&desde=${hoyBogota}&hasta=${hoyBogota}`;

    const reporteAntes = await api()
      .get(`/api/v1/reportes/financiero?${query}`)
      .set(admin.auth);
    const analiticaAntes = await api()
      .get(`/api/v1/analitica/caja?${query}`)
      .set(admin.auth);
    expect(reporteAntes.body.exito).toBe(true);
    expect(analiticaAntes.body.exito).toBe(true);

    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: `jest-fin-rec-${Date.now()}`,
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    const total = Number(crear.body.datos?.total);
    expect(total).toBeGreaterThan(0);

    await marcarItemsCocinaListos(cocina.auth, id, cajero.auth);
    expect((await setEstado(cajero.auth, id, 'listo')).body.exito).toBe(true);
    expect((await setEstado(cajero.auth, id, 'pagando')).body.exito).toBe(true);
    const cobrar = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ metodo_pago: 'efectivo' });
    expect(cobrar.body.exito).toBe(true);

    const [reporteDespues, analiticaDespues] = await Promise.all([
      api().get(`/api/v1/reportes/financiero?${query}`).set(admin.auth),
      api().get(`/api/v1/analitica/caja?${query}`).set(admin.auth),
    ]);
    expect(reporteDespues.body.exito).toBe(true);
    expect(analiticaDespues.body.exito).toBe(true);

    const ventasTickets =
      Number(reporteDespues.body.datos.resumen.ventas_total) -
      Number(reporteAntes.body.datos.resumen.ventas_total);
    const ventasCajaReporte =
      Number(reporteDespues.body.datos.cuadre_caja.ventas_movimientos_caja) -
      Number(reporteAntes.body.datos.cuadre_caja.ventas_movimientos_caja);
    const ventasCajaAnalitica =
      Number(analiticaDespues.body.datos.cuadre.ventas_movimientos_caja) -
      Number(analiticaAntes.body.datos.cuadre.ventas_movimientos_caja);

    expect(ventasTickets).toBeCloseTo(total, 2);
    expect(ventasCajaReporte).toBeCloseTo(total, 2);
    expect(ventasCajaAnalitica).toBeCloseTo(total, 2);
    expect(
      Number(reporteDespues.body.datos.cuadre_caja.diferencia) -
        Number(reporteAntes.body.datos.cuadre_caja.diferencia),
    ).toBeCloseTo(0, 2);
    expect(
      Number(analiticaDespues.body.datos.cuadre.diferencia) -
        Number(analiticaAntes.body.datos.cuadre.diferencia),
    ).toBeCloseTo(0, 2);
  });
});
