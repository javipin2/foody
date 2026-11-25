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
  let cocina: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
    domi = await login('domi@foody.demo');
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
});
