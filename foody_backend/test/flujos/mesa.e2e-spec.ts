/**
 * Flujo crítico: mesa (staff) — crear → listo → pagando → bloquear entregado sin cobro → cobrar.
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

describe('E2E mesa', () => {
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

  it('ciclo mesa: cobro y bloqueo entregado sin pagar (R1)', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: 'jest-mesa-ciclo',
      metodo_pago: 'efectivo',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);

    await marcarItemsCocinaListos(cocina.auth, id, cajero.auth);
    // Si cocina ya dejó el pedido en listo, setEstado es no-op OK
    const aListo = await setEstado(cajero.auth, id, 'listo');
    if (!aListo.body.exito) {
      const det = await api()
        .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
        .set(cajero.auth);
      const est = det.body.datos?.estado || det.body.datos?.pedido?.estado;
      expect(est).toBe('listo');
    }
    expect((await setEstado(cajero.auth, id, 'pagando')).body.exito).toBe(true);

    const saltar = await setEstado(cajero.auth, id, 'entregado');
    expect(saltar.body.exito).toBeFalsy();

    const cobrar = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ metodo_pago: 'efectivo' });
    expect(cobrar.body.exito).toBe(true);
  });
});
