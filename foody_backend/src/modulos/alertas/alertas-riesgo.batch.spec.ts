import { AlertasRiesgoService } from './alertas-riesgo.service';

describe('AlertasRiesgoService.registrarVariasEnTransaccion', () => {
  it('reutiliza una transacción para el lote y cuenta sólo inserciones nuevas', async () => {
    const client = {} as never;
    const database = {
      enTransaccion: jest.fn(async (callback: (tx: never) => Promise<number>) =>
        callback(client),
      ),
    };
    const service = new AlertasRiesgoService(
      database as never,
      {} as never,
      {} as never,
      {} as never,
    );
    const registrar = jest
      .spyOn(service, 'registrarEnTransaccion')
      .mockResolvedValueOnce(true)
      .mockResolvedValueOnce(false);

    await expect(
      service.registrarVariasEnTransaccion([
        {
          sucursalId: 'sucursal-1',
          tipo: 'demora_cocina',
          nivel: 'medio',
          descripcion: 'Pedido P-1 con ítems >20 min en cocina',
        },
        {
          sucursalId: 'sucursal-1',
          tipo: 'demora_cocina',
          nivel: 'medio',
          descripcion: 'Pedido P-2 con ítems >20 min en cocina',
        },
      ]),
    ).resolves.toBe(1);

    expect(database.enTransaccion).toHaveBeenCalledTimes(1);
    expect(registrar).toHaveBeenCalledTimes(2);
  });
});
