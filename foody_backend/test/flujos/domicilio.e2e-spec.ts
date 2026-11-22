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
  pedidoId,
  setEstado,
  SID,
  DOMI_PLANTA,
  TokenBundle,
} from '../helpers/foody-e2e';

describe('E2E domicilio', () => {
  let admin: TokenBundle;
  let domi: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
    domi = await login('domi@foody.demo');
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

    expect((await setEstado(admin.auth, id, 'en_cocina')).body.exito).toBe(true);
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

    expect((await setEstado(admin.auth, id, 'en_cocina')).body.exito).toBe(true);
    expect((await setEstado(admin.auth, id, 'listo')).body.exito).toBe(true);

    // Auto-dispatch puede dejar asignado; si no, asignar manual.
    const lista = await api().get(`/api/v1/pedidos?sucursal_id=${SID}`).set(admin.auth);
    const ped = (lista.body.datos as Array<{ id: string; estado: string }>).find((p) => p.id === id);
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
});
