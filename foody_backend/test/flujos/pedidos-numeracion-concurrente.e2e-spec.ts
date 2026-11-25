import { randomUUID } from 'crypto';
import {
  api,
  assertApiViva,
  limpiarDispositivosClienteE2e,
  limpiarPedidosActivos,
  login,
  PRECIO,
  PRODUCTO,
  registrarDispositivoCliente,
  SID,
  TokenBundle,
} from '../helpers/foody-e2e';

describe('E2E numeración concurrente de pedidos', () => {
  let admin: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
  });

  beforeEach(async () => {
    await limpiarPedidosActivos(admin.auth);
  });

  afterAll(async () => {
    if (admin) {
      await limpiarPedidosActivos(admin.auth);
      await limpiarDispositivosClienteE2e();
    }
  });

  it('asigna números distintos al crear varios pedidos públicos simultáneos', async () => {
    const devices = await Promise.all(
      Array.from({ length: 4 }, () =>
        registrarDispositivoCliente('jest-numero'),
      ),
    );
    const respuestas = await Promise.all(
      devices.map((device) =>
        api()
          .post('/api/v1/pedidos')
          .set(device.headers)
          .send({
            sucursal_id: SID,
            device_id: device.deviceId,
            tipo: 'para_llevar',
            metodo_pago: 'pendiente',
            idempotency_key: randomUUID(),
            items: [{ producto_id: PRODUCTO, cantidad: 1, precio: PRECIO }],
          }),
      ),
    );

    for (const respuesta of respuestas) {
      expect(respuesta.status).toBe(201);
      expect(respuesta.body.exito).toBe(true);
    }

    const numeros = respuestas.map((respuesta) =>
      String(respuesta.body.datos.numero_pedido),
    );
    expect(new Set(numeros).size).toBe(respuestas.length);
  });
});
