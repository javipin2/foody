/**
 * Flujo crítico: QR cliente — menú público, pedido pendiente_aprobación, anti-tamper precio.
 */
import {
  api,
  assertApiViva,
  limpiarPedidosActivos,
  login,
  PRECIO,
  PRODUCTO,
  QR_TOKEN,
  SID,
  TokenBundle,
} from '../helpers/foody-e2e';
import { randomUUID } from 'crypto';

describe('E2E QR cliente', () => {
  let admin: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
  });

  beforeEach(async () => {
    await limpiarPedidosActivos(admin.auth);
  });

  it('GET /menu/mesa/:token + POST /pedidos → pendiente_aprobacion', async () => {
    const menu = await api().get(`/api/v1/menu/mesa/${QR_TOKEN}`);
    expect(menu.body.exito).toBe(true);
    const mesaId =
      menu.body.datos?.mesa?.id || menu.body.datos?.id || '30000000-0000-4000-8000-000000000001';

    const crear = await api()
      .post('/api/v1/pedidos')
      .send({
        sucursal_id: SID,
        mesa_id: mesaId,
        device_id: `jest-qr-${Date.now()}`,
        tipo: 'mesa',
        metodo_pago: 'pendiente',
        idempotency_key: randomUUID(),
        items: [{ producto_id: PRODUCTO, cantidad: 1, precio: PRECIO }],
      });
    expect(crear.body.exito).toBe(true);
    const estado = crear.body.datos?.estado;
    expect(estado).toBe('pendiente_aprobacion');
  });

  it('anti-tamper: precio cliente inflado no se acepta como total catálogo', async () => {
    const menu = await api().get(`/api/v1/menu/mesa/${QR_TOKEN}`);
    const mesaId =
      menu.body.datos?.mesa?.id || menu.body.datos?.id || '30000000-0000-4000-8000-000000000001';

    const crear = await api()
      .post('/api/v1/pedidos')
      .send({
        sucursal_id: SID,
        mesa_id: mesaId,
        device_id: `jest-qr-tamper-${Date.now()}`,
        tipo: 'mesa',
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
