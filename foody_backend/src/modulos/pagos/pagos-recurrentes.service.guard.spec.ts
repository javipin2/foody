import { DatabaseService } from '../../core/database/database.service';
import { PagosRecurrentesService } from './pagos-recurrentes.service';
import { WompiService } from './wompi.service';

describe('PagosRecurrentesService reserva de renovación', () => {
  const crearDependencias = (resultadosQuery: unknown[]) => {
    const client = {
      query: jest.fn(async () => resultadosQuery.shift() ?? { rows: [] }),
    };
    const database = {
      consultarUno: jest
        .fn()
        .mockResolvedValueOnce({ plan: 'pro', estado: 'activa' })
        .mockResolvedValueOnce({
          id: 'fuente-1',
          restaurante_id: 'restaurante-1',
          wompi_payment_source_id: 'source-1',
          customer_email: 'admin@example.test',
        }),
      consultar: jest.fn().mockResolvedValue([]),
      enTransaccion: jest.fn(async (callback) => callback(client as never)),
    };
    const wompi = {
      estaConfigurado: jest.fn().mockReturnValue(true),
      generarReferenciaInterna: jest.fn().mockReturnValue('fdy_ref_1'),
      crearTransaccionRecurrente: jest.fn().mockResolvedValue({
        id: 'wompi-tx-1',
        status: 'PENDING',
        reference: 'fdy_ref_1',
      }),
    };
    const service = new PagosRecurrentesService(
      database as unknown as DatabaseService,
      wompi as unknown as WompiService,
    );
    return { client, database, service, wompi };
  };

  it('no hace un segundo cobro si ya hay un pago reciente pendiente', async () => {
    const { client, service, wompi } = crearDependencias([
      { rows: [{ restaurante_id: 'restaurante-1' }] },
      { rows: [{ id: 'pago-pendiente' }] },
    ]);

    const result = await service.intentarCobroRenovacion(
      'restaurante-1',
      'pro',
    );

    expect(result).toEqual({
      iniciado: false,
      motivo: 'pago_reciente_existente',
    });
    expect(client.query).toHaveBeenCalledTimes(2);
    expect(wompi.crearTransaccionRecurrente).not.toHaveBeenCalled();
  });

  it('no hace el cobro si la fuente registra un intento dentro de 20 horas', async () => {
    const { client, service, wompi } = crearDependencias([
      { rows: [{ restaurante_id: 'restaurante-1' }] },
      { rows: [] },
      { rows: [] },
    ]);

    const result = await service.intentarCobroRenovacion(
      'restaurante-1',
      'pro',
    );

    expect(result).toEqual({ iniciado: false, motivo: 'intento_reciente' });
    expect(client.query).toHaveBeenCalledTimes(3);
    expect(wompi.crearTransaccionRecurrente).not.toHaveBeenCalled();
  });

  it('reserva y crea un solo intento antes de llamar a Wompi', async () => {
    const { client, database, service, wompi } = crearDependencias([
      { rows: [{ restaurante_id: 'restaurante-1' }] },
      { rows: [] },
      { rows: [{ id: 'fuente-1' }] },
      { rows: [{ id: 'pago-nuevo' }] },
    ]);

    const result = await service.intentarCobroRenovacion(
      'restaurante-1',
      'pro',
    );

    expect(result).toMatchObject({
      iniciado: true,
      pago_id: 'pago-nuevo',
      motivo: 'cobro_pendiente_webhook',
    });
    expect(database.enTransaccion).toHaveBeenCalledTimes(1);
    expect(client.query).toHaveBeenCalledTimes(4);
    expect(wompi.crearTransaccionRecurrente).toHaveBeenCalledTimes(1);
  });
});
