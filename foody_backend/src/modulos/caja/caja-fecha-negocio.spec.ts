import { CajaService } from './caja.service';

describe('CajaService fecha calendario del gasto', () => {
  it('registra la fecha local de Bogotá sin depender de CURRENT_DATE de PostgreSQL', async () => {
    const query = jest.fn().mockResolvedValue(undefined);
    const client = { query };
    const database = {
      consultarUno: jest.fn().mockResolvedValue({ id: 'caja-1' }),
      enTransaccion: jest.fn(async (callback: (client: any) => unknown) =>
        callback(client),
      ),
    };
    const movimientos = { insertar: jest.fn().mockResolvedValue(undefined) };
    const realtime = { cajaMovimiento: jest.fn() };
    const service = new CajaService(
      database as any,
      {} as any,
      realtime as any,
      {} as any,
      movimientos as any,
      {} as any,
      {} as any,
    );

    await service.registrarGasto(
      {
        caja_id: 'caja-1',
        concepto: 'Prueba sintética',
        monto: 100,
      },
      'usuario-1',
      'sucursal-1',
    );

    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("(now() AT TIME ZONE 'America/Bogota')::date"),
      expect.any(Array),
    );
    expect(movimientos.insertar).toHaveBeenCalledTimes(1);
  });
});
