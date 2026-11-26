import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { PagosRecurrentesService } from './pagos-recurrentes.service';
import { PagosService } from './pagos.service';
import { WompiService } from './wompi.service';

describe('PagosService webhook transacción recurrente', () => {
  it('asocia y aprueba por reference cuando Wompi no envía payment_link_id ni sku', async () => {
    const pago = {
      id: 'pago-1',
      restaurante_id: 'restaurante-1',
      plan: 'pro' as const,
    };
    const database = {
      consultarUno: jest
        .fn()
        .mockResolvedValueOnce(pago)
        .mockResolvedValueOnce(null),
      consultar: jest.fn().mockResolvedValue(undefined),
      enTransaccion: jest.fn(async (callback: (client: unknown) => unknown) =>
        callback({ query: jest.fn().mockResolvedValue({ rows: [] }) }),
      ),
    };
    const wompi = { validarFirmaEvento: jest.fn().mockReturnValue(true) };
    const recurrentes = {
      registrarFuenteDesdeTransaccion: jest.fn().mockResolvedValue(undefined),
    };
    const realtime = {
      suscripcionActualizada: jest.fn().mockResolvedValue(undefined),
    };
    const service = new PagosService(
      database as unknown as DatabaseService,
      wompi as unknown as WompiService,
      {} as ConfigService,
      recurrentes as unknown as PagosRecurrentesService,
      realtime as unknown as RealtimeBroadcastService,
    );

    const result = await service.procesarWebhookWompi({
      event: 'transaction.updated',
      timestamp: 1,
      signature: { properties: [], checksum: 'firma' },
      environment: 'test',
      data: {
        transaction: {
          id: 'wompi-tx-1',
          status: 'APPROVED',
          reference: 'fdy_recurring_123',
          payment_link_id: null,
          sku: null,
          payment_method_type: 'CARD',
          payment_source_id: null,
        },
      },
    });

    expect(result).toEqual({ procesado: true });
    expect(database.consultarUno).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining(
        "WHERE referencia_interna = $1 AND estado = 'pendiente'",
      ),
      ['fdy_recurring_123'],
    );
    expect(database.enTransaccion).toHaveBeenCalledTimes(1);
    expect(realtime.suscripcionActualizada).toHaveBeenCalledWith(
      'restaurante-1',
      { plan: 'pro', pago_id: 'pago-1' },
    );
  });
});
