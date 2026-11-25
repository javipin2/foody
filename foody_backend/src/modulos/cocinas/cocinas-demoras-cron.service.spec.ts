import { CocinasDemorasCronService } from './cocinas-demoras-cron.service';

describe('CocinasDemorasCronService', () => {
  it('registra las demoras detectadas en lote y limita cada ciclo', async () => {
    const filas = [
      {
        pedido_id: 'pedido-1',
        sucursal_id: 'sucursal-1',
        numero_pedido: 'P-001',
      },
    ];
    const database = { consultar: jest.fn().mockResolvedValue(filas) };
    const alertas = {
      registrarVariasEnTransaccion: jest.fn().mockResolvedValue(1),
    };
    const cron = new CocinasDemorasCronService(
      database as never,
      alertas as never,
    );

    await expect(cron.ejecutar()).resolves.toBe(1);

    expect(database.consultar).toHaveBeenCalledWith(
      expect.stringContaining('LIMIT $1'),
      [200],
    );
    expect(alertas.registrarVariasEnTransaccion).toHaveBeenCalledWith([
      {
        sucursalId: 'sucursal-1',
        tipo: 'demora_cocina',
        nivel: 'medio',
        descripcion: 'Pedido P-001 con ítems >20 min en cocina',
        referenciaId: 'pedido-1',
        referenciaTipo: 'pedido',
        deduplicar: true,
      },
    ]);
  });

  it('no abre transacción cuando no hay pedidos atrasados nuevos', async () => {
    const database = { consultar: jest.fn().mockResolvedValue([]) };
    const alertas = { registrarVariasEnTransaccion: jest.fn() };
    const cron = new CocinasDemorasCronService(
      database as never,
      alertas as never,
    );

    await expect(cron.ejecutar()).resolves.toBe(0);
    expect(alertas.registrarVariasEnTransaccion).not.toHaveBeenCalled();
  });
});
