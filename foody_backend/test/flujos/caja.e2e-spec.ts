/**
 * Flujo crítico: caja — apertura, cobro genera venta, no reopen pagado (VIE-06).
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
});
