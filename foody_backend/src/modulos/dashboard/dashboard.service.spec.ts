import { DashboardService } from './dashboard.service';

describe('DashboardService.resumen domicilios tardíos', () => {
  it('devuelve retrasos calculados server-side y limitados por sucursal', async () => {
    const demora = {
      numero: 'P-ANTIGUO',
      detalle: 'En camino · Ana',
      minutos: 52,
      severidad: 0,
    };
    const database = {
      consultarUno: jest.fn().mockResolvedValue({
        ventas_hoy: '0',
        pedidos_activos: '1',
        pedidos_pendientes_qr: '0',
        pedidos_completados_hoy: '0',
        alertas_pendientes: '0',
        domicilios_tardios: [demora],
      }),
    };
    const cache = {
      get: jest.fn().mockResolvedValue(null),
      set: jest.fn().mockResolvedValue(undefined),
    };
    const service = new DashboardService(
      database as never,
      {} as never,
      cache as never,
    );

    const resumen = await service.resumen('sucursal-1');

    expect(resumen.domicilios_tardios).toEqual([demora]);
    expect(database.consultarUno).toHaveBeenCalledWith(
      expect.stringContaining("p.tipo = 'domicilio'"),
      ['sucursal-1', expect.any(Array)],
    );
    expect(database.consultarUno.mock.calls[0][0]).toContain(
      "interval '25 minutes'",
    );
    expect(database.consultarUno.mock.calls[0][0]).toContain('LIMIT 8');
    expect(cache.set).toHaveBeenCalledWith(
      'dash:resumen:sucursal-1',
      expect.objectContaining({ domicilios_tardios: [demora] }),
      30_000,
    );
  });
});
