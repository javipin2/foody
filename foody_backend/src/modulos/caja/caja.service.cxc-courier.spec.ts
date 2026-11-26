import { DatabaseService } from '../../core/database/database.service';
import { CajaService } from './caja.service';

describe('cuentas por cobrar de domiciliarios', () => {
  it('rechaza el cobro desde Caja general para exigir la liquidación especializada', async () => {
    const query = jest.fn().mockResolvedValue({
      rows: [
        {
          id: 'cuenta-1',
          pedido_id: 'pedido-1',
          monto: '8000',
          estado: 'pendiente',
          domiciliario_planta_id: 'domi-1',
        },
      ],
    });
    const database = {
      enTransaccion: (callback: (client: unknown) => Promise<unknown>) =>
        callback({ query }),
    };
    const service = new CajaService(
      database as unknown as DatabaseService,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    await expect(
      service.pagarCuentaPorCobrar(
        'cuenta-1',
        'sucursal-1',
        'usuario-1',
        'efectivo',
      ),
    ).rejects.toMatchObject({
      response: {
        error: 'LIQUIDACION_DOMICILIARIO_REQUERIDA',
      },
    });

    expect(query).toHaveBeenCalledTimes(1);
    expect(query.mock.calls[0][0]).toContain('domiciliario_planta_id');
  });
});
