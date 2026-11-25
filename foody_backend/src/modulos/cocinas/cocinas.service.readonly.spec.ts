import { CocinasService } from './cocinas.service';

describe('CocinasService.listarTickets', () => {
  it('lee tickets sin crear alertas de riesgo', async () => {
    const database = {
      consultarUno: jest.fn().mockResolvedValue({ id: 'cocina-1' }),
      consultar: jest.fn().mockResolvedValue([]),
    };
    const alertasRiesgo = {
      registrar: jest.fn(),
      registrarEnTransaccion: jest.fn(),
    };
    const service = new CocinasService(
      database as never,
      {} as never,
      {} as never,
      alertasRiesgo as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    await expect(
      service.listarTickets('cocina-1', 'sucursal-1'),
    ).resolves.toEqual([]);

    expect(database.consultarUno).toHaveBeenCalledTimes(1);
    expect(database.consultar).toHaveBeenCalledTimes(1);
    expect(alertasRiesgo.registrar).not.toHaveBeenCalled();
    expect(alertasRiesgo.registrarEnTransaccion).not.toHaveBeenCalled();
  });
});
