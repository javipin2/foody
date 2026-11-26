/**
 * Flujo crítico: domicilio — listo→entregado bloqueado; entrega con domi + cobro.
 */
import {
  api,
  assertApiViva,
  crearPedidoStaff,
  ensureCajaAbierta,
  itemBody,
  limpiarPedidosActivos,
  login,
  loginDomiciliarioIndependiente,
  marcarItemsCocinaListos,
  pedidoId,
  setEstado,
  SID,
  DOMI_PLANTA,
  TokenBundle,
} from '../helpers/foody-e2e';

describe('E2E domicilio', () => {
  let admin: TokenBundle;
  let domi: TokenBundle;
  let independiente: TokenBundle;
  let cocina: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
    domi = await login('domi@foody.demo');
    independiente = await loginDomiciliarioIndependiente();
    cocina = await login('cocina@foody.demo');
  });

  beforeEach(async () => {
    await limpiarPedidosActivos(admin.auth);
    await ensureCajaAbierta(admin.auth);
  });

  it('bloquea listo→entregado sin asignación (P0.2)', async () => {
    const crear = await crearPedidoStaff(admin.auth, {
      sucursal_id: SID,
      tipo: 'domicilio',
      device_id: 'jest-domi-bloqueo',
      cliente_nombre: 'Jest Domi',
      cliente_telefono: '3000000001',
      direccion_entrega: 'Calle Jest 1',
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);

    expect((await setEstado(admin.auth, id, 'en_cocina')).body.exito).toBe(
      true,
    );
    await marcarItemsCocinaListos(cocina.auth, id, admin.auth);
    expect((await setEstado(admin.auth, id, 'listo')).body.exito).toBe(true);

    const saltar = await setEstado(admin.auth, id, 'entregado');
    expect(saltar.body.exito).toBeFalsy();
  });

  it('flujo completo: asignar → en camino → confirmar entrega', async () => {
    const crear = await crearPedidoStaff(admin.auth, {
      sucursal_id: SID,
      tipo: 'domicilio',
      device_id: 'jest-domi-full',
      cliente_nombre: 'Jest Domi Full',
      cliente_telefono: '3000000002',
      direccion_entrega: 'Calle Jest 2',
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);

    expect((await setEstado(admin.auth, id, 'en_cocina')).body.exito).toBe(
      true,
    );
    await marcarItemsCocinaListos(cocina.auth, id, admin.auth);
    expect((await setEstado(admin.auth, id, 'listo')).body.exito).toBe(true);

    // Auto-dispatch puede dejar asignado; si no, asignar manual.
    const lista = await api()
      .get(`/api/v1/pedidos?sucursal_id=${SID}`)
      .set(admin.auth);
    const ped = (
      lista.body.datos as Array<{ id: string; estado: string }>
    ).find((p) => p.id === id);
    if (ped && ped.estado === 'listo') {
      const asig = await api()
        .post('/api/v1/domiciliarios-planta/asignar')
        .set(admin.auth)
        .send({
          pedido_id: id,
          sucursal_id: SID,
          domiciliario_planta_id: DOMI_PLANTA,
        });
      expect(asig.body.exito).toBe(true);
    }

    const camino = await api()
      .patch(`/api/v1/domiciliario/pedidos/${id}/en-camino`)
      .set(domi.auth);
    expect(camino.body.exito).toBe(true);

    const entrega = await api()
      .patch(`/api/v1/domiciliario/pedidos/${id}/confirmar-entrega`)
      .set(domi.auth)
      .send({ metodo_pago: 'efectivo' });
    expect(entrega.body.exito).toBe(true);
    expect(entrega.body.datos?.estado).toBe('entregado');
  });

  it('concilia abono previo y métodos distintos para producto/domicilio en planta', async () => {
    const cliente = `Jest Domi Mixto ${Date.now()}`;
    const crear = await crearPedidoStaff(admin.auth, {
      sucursal_id: SID,
      tipo: 'domicilio',
      device_id: `jest-domi-mixto-abono-${Date.now()}`,
      cliente_nombre: cliente,
      cliente_telefono: '3000000091',
      direccion_entrega: 'Calle Jest Mixto 91',
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    const total = Number(crear.body.datos?.total);
    const costoDomicilio = Number(crear.body.datos?.costo_domicilio ?? 0);
    const abono = 2000;
    expect(total).toBeGreaterThan(abono);

    expect((await setEstado(admin.auth, id, 'en_cocina')).body.exito).toBe(
      true,
    );
    await marcarItemsCocinaListos(cocina.auth, id, admin.auth);
    expect((await setEstado(admin.auth, id, 'listo')).body.exito).toBe(true);

    const lista = await api()
      .get(`/api/v1/pedidos?sucursal_id=${SID}`)
      .set(admin.auth);
    const pedido = (
      lista.body.datos as Array<{ id: string; estado: string }>
    ).find((item) => item.id === id);
    if (pedido?.estado === 'listo') {
      const asignar = await api()
        .post('/api/v1/domiciliarios-planta/asignar')
        .set(admin.auth)
        .send({
          pedido_id: id,
          sucursal_id: SID,
          domiciliario_planta_id: DOMI_PLANTA,
        });
      expect(asignar.body.exito).toBe(true);
    }

    const enCamino = await api()
      .patch(`/api/v1/domiciliario/pedidos/${id}/en-camino`)
      .set(domi.auth);
    expect(enCamino.body.exito).toBe(true);

    const prepago = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(admin.auth)
      .send({
        monto_parcial: abono,
        pagos: [{ metodo_pago: 'transferencia', monto: abono }],
        idempotency_key: `jest-domi-mixto-${id}`,
      });
    expect(prepago.body).toMatchObject({
      exito: true,
      datos: { total_cobrado: abono, parcial: true },
    });

    const entrega = await api()
      .patch(`/api/v1/domiciliario/pedidos/${id}/confirmar-entrega`)
      .set(domi.auth)
      .send({ metodo_pago: 'efectivo', metodo_pago_domicilio: 'nequi' });
    expect(entrega.body).toMatchObject({
      exito: true,
      datos: { pedido_id: id, estado: 'entregado' },
    });

    const detalle = await api()
      .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
      .set(admin.auth);
    expect(detalle.body.datos.estado).toBe('entregado');
    expect(Number(detalle.body.datos.monto_pagado)).toBeCloseTo(total, 2);

    const configDomicilio = await api()
      .get(`/api/v1/domiciliarios-planta/domicilios/${SID}`)
      .set(admin.auth);
    expect(configDomicilio.body.exito).toBe(true);
    const domicilioEnCaja = Boolean(
      configDomicilio.body.datos.domicilio_ingresa_a_caja,
    );

    const caja = await api().get(`/api/v1/caja/activa/${SID}`).set(admin.auth);
    expect(caja.body.exito).toBe(true);
    const movimientos = await api()
      .get(`/api/v1/caja/${caja.body.datos.id}/movimientos?page=1&limit=100`)
      .set(admin.auth);
    const ventas = (
      movimientos.body.datos.items as Array<Record<string, unknown>>
    ).filter((mov) => mov.pedido_id === id && mov.tipo === 'venta');
    const porMetodo = new Map<string, number>();
    for (const venta of ventas) {
      const metodo = String(venta.metodo_pago);
      porMetodo.set(metodo, (porMetodo.get(metodo) ?? 0) + Number(venta.monto));
    }
    expect(porMetodo.get('transferencia')).toBeCloseTo(abono, 2);
    expect(porMetodo.get('efectivo')).toBeCloseTo(
      total - costoDomicilio - abono,
      2,
    );
    expect(porMetodo.get('nequi') ?? 0).toBeCloseTo(
      domicilioEnCaja ? costoDomicilio : 0,
      2,
    );
    expect(
      [...porMetodo.values()].reduce((sum, monto) => sum + monto, 0),
    ).toBeCloseTo(total - (domicilioEnCaja ? 0 : costoDomicilio), 2);
  });

  it('cierre manual Admin convierte Pendiente en venta de efectivo', async () => {
    const crear = await crearPedidoStaff(admin.auth, {
      sucursal_id: SID,
      tipo: 'domicilio',
      device_id: `jest-domi-manual-${Date.now()}`,
      cliente_nombre: 'Jest Domi Manual',
      cliente_telefono: '3000000004',
      direccion_entrega: 'Calle Jest 4',
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    const total = Number(crear.body.datos?.total);
    expect(total).toBeGreaterThan(0);

    expect((await setEstado(admin.auth, id, 'en_cocina')).body.exito).toBe(
      true,
    );
    await marcarItemsCocinaListos(cocina.auth, id, admin.auth);
    expect((await setEstado(admin.auth, id, 'listo')).body.exito).toBe(true);

    const lista = await api()
      .get(`/api/v1/pedidos?sucursal_id=${SID}`)
      .set(admin.auth);
    const pedido = (
      lista.body.datos as Array<{ id: string; estado: string }>
    ).find((p) => p.id === id);
    if (pedido?.estado === 'listo') {
      const asignar = await api()
        .post('/api/v1/domiciliarios-planta/asignar')
        .set(admin.auth)
        .send({
          pedido_id: id,
          sucursal_id: SID,
          domiciliario_planta_id: DOMI_PLANTA,
        });
      expect(asignar.body.exito).toBe(true);
    }

    const enCamino = await api()
      .patch(`/api/v1/domiciliario/pedidos/${id}/en-camino`)
      .set(domi.auth);
    expect(enCamino.body.exito).toBe(true);
    const entregaManual = await setEstado(admin.auth, id, 'entregado');
    expect(entregaManual.body.exito).toBe(true);

    const detalle = await api()
      .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
      .set(admin.auth);
    expect(detalle.body.exito).toBe(true);
    expect(detalle.body.datos.estado).toBe('entregado');
    expect(detalle.body.datos.metodo_pago).toBe('efectivo');
    expect(Number(detalle.body.datos.monto_pagado)).toBeCloseTo(total, 2);

    const caja = await api().get(`/api/v1/caja/activa/${SID}`).set(admin.auth);
    expect(caja.body.exito).toBe(true);
    const movimientos = await api()
      .get(`/api/v1/caja/${caja.body.datos.id}/movimientos?page=1&limit=100`)
      .set(admin.auth);
    expect(movimientos.body.exito).toBe(true);
    const movimientoVenta = (
      movimientos.body.datos.items as Array<Record<string, unknown>>
    ).find((m) => m.pedido_id === id && m.tipo === 'venta');
    expect(movimientoVenta).toBeTruthy();
    expect(movimientoVenta?.metodo_pago).toBe('efectivo');
    expect(Number(movimientoVenta?.monto)).toBeGreaterThan(0);
    const pagosResumen = detalle.body.datos.pagos_resumen as Array<{
      monto: number;
      metodo_pago: string;
    }>;
    expect(pagosResumen).toEqual([
      { metodo_pago: 'efectivo', monto: Number(movimientoVenta?.monto) },
    ]);
  });

  it('rechaza Pendiente al confirmar entrega con domiciliario', async () => {
    const crear = await crearPedidoStaff(admin.auth, {
      sucursal_id: SID,
      tipo: 'domicilio',
      device_id: `jest-domi-pago-pendiente-${Date.now()}`,
      cliente_nombre: 'Jest Domi Pendiente',
      cliente_telefono: '3000000003',
      direccion_entrega: 'Calle Jest 3',
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    if (!crear.body.exito) {
      throw new Error(
        `Crear domicilio QA (${crear.status}): ${JSON.stringify({ error: crear.body.error, message: crear.body.message, mensaje: crear.body.mensaje })}`,
      );
    }
    const id = pedidoId(crear);

    expect((await setEstado(admin.auth, id, 'en_cocina')).body.exito).toBe(
      true,
    );
    await marcarItemsCocinaListos(cocina.auth, id, admin.auth);
    expect((await setEstado(admin.auth, id, 'listo')).body.exito).toBe(true);

    const lista = await api()
      .get(`/api/v1/pedidos?sucursal_id=${SID}`)
      .set(admin.auth);
    const pedido = (
      lista.body.datos as Array<{ id: string; estado: string }>
    ).find((p) => p.id === id);
    if (pedido?.estado === 'listo') {
      const asignar = await api()
        .post('/api/v1/domiciliarios-planta/asignar')
        .set(admin.auth)
        .send({
          pedido_id: id,
          sucursal_id: SID,
          domiciliario_planta_id: DOMI_PLANTA,
        });
      expect(asignar.body.exito).toBe(true);
    }

    const enCamino = await api()
      .patch(`/api/v1/domiciliario/pedidos/${id}/en-camino`)
      .set(domi.auth);
    expect(enCamino.body.exito).toBe(true);

    const pendiente = await api()
      .patch(`/api/v1/domiciliario/pedidos/${id}/confirmar-entrega`)
      .set(domi.auth)
      .send({ metodo_pago: 'pendiente' });
    expect(pendiente.status).toBe(400);
    expect(pendiente.body.error).toBe('COBRO_REQUERIDO');

    const cancelar = await setEstado(admin.auth, id, 'cancelado', {
      motivo: 'QA E2E: cleanup tras rechazar pago pendiente',
    });
    expect(cancelar.body.exito).toBe(true);
  });

  it('cancela un pedido de independiente y refresca su sesión disponible', async () => {
    const crear = await crearPedidoStaff(admin.auth, {
      sucursal_id: SID,
      tipo: 'domicilio',
      device_id: `jest-domi-indep-cancel-${Date.now()}`,
      cliente_nombre: 'Jest Independiente Cancelado',
      cliente_telefono: '3000000089',
      direccion_entrega: 'Calle QA Independiente 9',
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    expect((await setEstado(admin.auth, id, 'en_cocina')).body.exito).toBe(
      true,
    );
    await marcarItemsCocinaListos(cocina.auth, id, admin.auth);
    expect((await setEstado(admin.auth, id, 'listo')).body.exito).toBe(true);

    const sesion = await api()
      .post('/api/v1/domiciliarios/sesion/iniciar')
      .set(independiente.auth)
      .send({ lat: 10.4641, lng: -73.2525 });
    expect(sesion.body.exito).toBe(true);

    const dispatch = await api()
      .post(
        `/api/v1/domiciliarios-planta/dispatch-independiente/${id}?sucursal_id=${SID}`,
      )
      .set(admin.auth);
    expect(dispatch.body.exito).toBe(true);
    const ofertas = await api()
      .get('/api/v1/domiciliarios/ofertas-activas')
      .set(independiente.auth);
    expect(ofertas.body.exito).toBe(true);
    const oferta = (
      ofertas.body.datos as Array<{ oferta_id: string; pedido_id: string }>
    ).find((item) => item.pedido_id === id);
    expect(oferta).toBeTruthy();

    const aceptar = await api()
      .post(`/api/v1/domiciliarios/ofertas/${oferta!.oferta_id}/responder`)
      .set(independiente.auth)
      .send({ respuesta: 'aceptada' });
    expect(aceptar.body.exito).toBe(true);

    const cancelado = await setEstado(admin.auth, id, 'cancelado', {
      motivo: 'QA E2E: cancelar asignación independiente',
    });
    expect(cancelado.body.exito).toBe(true);

    const estadoSesion = await api()
      .get('/api/v1/domiciliarios/sesion/estado')
      .set(independiente.auth);
    expect(estadoSesion.body.datos).toMatchObject({
      activa: true,
      disponible: true,
    });
    const activos = await api()
      .get('/api/v1/domiciliarios/pedidos-activos')
      .set(independiente.auth);
    expect(activos.body.exito).toBe(true);
    expect(
      (activos.body.datos as Array<{ id: string }>).some((p) => p.id === id),
    ).toBe(false);
  });

  it('completa entrega de independiente y concilia pedido, caja y ganancias', async () => {
    const partesFecha = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'America/Bogota',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(new Date());
    const fecha = (tipo: string) =>
      partesFecha.find((parte) => parte.type === tipo)?.value ?? '';
    const hoyBogota = `${fecha('year')}-${fecha('month')}-${fecha('day')}`;
    const queryPeriodo = `sucursal_id=${SID}&desde=${hoyBogota}&hasta=${hoyBogota}`;
    const [reporteAntes, analiticaAntes] = await Promise.all([
      api().get(`/api/v1/reportes/financiero?${queryPeriodo}`).set(admin.auth),
      api().get(`/api/v1/analitica/caja?${queryPeriodo}`).set(admin.auth),
    ]);
    expect(reporteAntes.body.exito).toBe(true);
    expect(analiticaAntes.body.exito).toBe(true);

    const crear = await crearPedidoStaff(admin.auth, {
      sucursal_id: SID,
      tipo: 'domicilio',
      device_id: `jest-domi-indep-entrega-${Date.now()}`,
      cliente_nombre: 'Jest Independiente Entrega',
      cliente_telefono: '3000000090',
      direccion_entrega: 'Calle QA Independiente 10',
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    const total = Number(crear.body.datos?.total);
    const costoDomicilio = Number(crear.body.datos?.costo_domicilio ?? 0);
    expect(total).toBeGreaterThan(0);

    expect((await setEstado(admin.auth, id, 'en_cocina')).body.exito).toBe(
      true,
    );
    await marcarItemsCocinaListos(cocina.auth, id, admin.auth);
    expect((await setEstado(admin.auth, id, 'listo')).body.exito).toBe(true);

    const sesion = await api()
      .post('/api/v1/domiciliarios/sesion/iniciar')
      .set(independiente.auth)
      .send({ lat: 10.4641, lng: -73.2525 });
    expect(sesion.body.exito).toBe(true);
    const dispatch = await api()
      .post(
        `/api/v1/domiciliarios-planta/dispatch-independiente/${id}?sucursal_id=${SID}`,
      )
      .set(admin.auth);
    expect(dispatch.body.exito).toBe(true);

    const ofertas = await api()
      .get('/api/v1/domiciliarios/ofertas-activas')
      .set(independiente.auth);
    const oferta = (
      ofertas.body.datos as Array<{ oferta_id: string; pedido_id: string }>
    ).find((item) => item.pedido_id === id);
    expect(oferta).toBeTruthy();
    const aceptar = await api()
      .post(`/api/v1/domiciliarios/ofertas/${oferta!.oferta_id}/responder`)
      .set(independiente.auth)
      .send({ respuesta: 'aceptada' });
    expect(aceptar.body.exito).toBe(true);

    const enCamino = await api()
      .patch(`/api/v1/domiciliarios/pedidos/${id}/en-camino`)
      .set(independiente.auth);
    expect(enCamino.body.exito).toBe(true);
    const entrega = await api()
      .patch(`/api/v1/domiciliarios/pedidos/${id}/confirmar-entrega`)
      .set(independiente.auth)
      .send({
        metodo_pago: 'efectivo',
        metodo_pago_domicilio: 'transferencia',
      });
    expect(entrega.body).toMatchObject({
      exito: true,
      datos: { pedido_id: id, estado: 'entregado' },
    });

    const detalle = await api()
      .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
      .set(admin.auth);
    expect(detalle.body.datos).toMatchObject({ id, estado: 'entregado' });
    expect(Number(detalle.body.datos.monto_pagado)).toBeCloseTo(total, 2);

    const caja = await api().get(`/api/v1/caja/activa/${SID}`).set(admin.auth);
    expect(caja.body.exito).toBe(true);
    const movimientos = await api()
      .get(`/api/v1/caja/${caja.body.datos.id}/movimientos?page=1&limit=100`)
      .set(admin.auth);
    const ventas = (
      movimientos.body.datos.items as Array<Record<string, unknown>>
    ).filter((mov) => mov.pedido_id === id && mov.tipo === 'venta');
    const totalEnCaja = ventas.reduce(
      (sum, mov) => sum + Number(mov.monto ?? 0),
      0,
    );
    expect(totalEnCaja).toBeGreaterThanOrEqual(total - costoDomicilio - 0.02);
    expect(totalEnCaja).toBeLessThanOrEqual(total + 0.02);
    expect(ventas.some((mov) => mov.metodo_pago === 'efectivo')).toBe(true);

    const [reporteDespues, analiticaDespues] = await Promise.all([
      api().get(`/api/v1/reportes/financiero?${queryPeriodo}`).set(admin.auth),
      api().get(`/api/v1/analitica/caja?${queryPeriodo}`).set(admin.auth),
    ]);
    expect(reporteDespues.body.exito).toBe(true);
    expect(analiticaDespues.body.exito).toBe(true);
    expect(
      Number(reporteDespues.body.datos.resumen.ventas_total) -
        Number(reporteAntes.body.datos.resumen.ventas_total),
    ).toBeCloseTo(total, 2);
    expect(
      Number(reporteDespues.body.datos.cuadre_caja.ventas_movimientos_caja) -
        Number(reporteAntes.body.datos.cuadre_caja.ventas_movimientos_caja),
    ).toBeCloseTo(totalEnCaja, 2);
    expect(
      Number(reporteDespues.body.datos.recaudo_periodo.total_neto) -
        Number(reporteAntes.body.datos.recaudo_periodo.total_neto),
    ).toBeCloseTo(totalEnCaja, 2);
    expect(
      Number(analiticaDespues.body.datos.cuadre.ventas_pedidos) -
        Number(analiticaAntes.body.datos.cuadre.ventas_pedidos),
    ).toBeCloseTo(total, 2);
    expect(
      Number(analiticaDespues.body.datos.cuadre.ventas_movimientos_caja) -
        Number(analiticaAntes.body.datos.cuadre.ventas_movimientos_caja),
    ).toBeCloseTo(totalEnCaja, 2);
    expect(
      Number(reporteDespues.body.datos.cuadre_caja.diferencia) -
        Number(reporteAntes.body.datos.cuadre_caja.diferencia),
    ).toBeCloseTo(total - totalEnCaja, 2);

    if (costoDomicilio > 0) {
      const ganancias = await api()
        .get('/api/v1/domiciliarios/ganancias')
        .set(independiente.auth);
      const ganancia = (
        ganancias.body.datos.items as Array<Record<string, unknown>>
      ).find((item) => item.pedido_id === id);
      expect(ganancia).toMatchObject({
        pagado: false,
        estado_asignacion: 'entregado',
      });
      expect(Number(ganancia?.valor_domicilio)).toBeCloseTo(costoDomicilio, 2);
    }

    const estadoSesion = await api()
      .get('/api/v1/domiciliarios/sesion/estado')
      .set(independiente.auth);
    expect(estadoSesion.body.datos).toMatchObject({
      activa: true,
      disponible: true,
    });
  });
});
