import { DashboardService } from './dashboard.service';

describe('DashboardService.graficos', () => {
  it('construye una serie de siete días calendario incluyendo días sin ventas', async () => {
    const dias = Array.from({ length: 7 }, (_, i) => ({
      dia: `2026-11-${String(19 + i).padStart(2, '0')}`,
      pedidos: i === 6 ? '2' : '0',
      ventas: i === 6 ? '12000' : '0',
    }));
    const database = {
      consultar: jest
        .fn()
        .mockResolvedValueOnce(dias)
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([]),
    };
    const service = new DashboardService(
      database as never,
      {} as never,
      {} as never,
    );

    const resultado = await service.graficos('sucursal-1');

    expect(resultado.ventas_7_dias).toHaveLength(7);
    expect(resultado.ventas_7_dias.slice(0, 6).every((d) => d.ventas === 0)).toBe(true);
    const sql = database.consultar.mock.calls[0][0] as string;
    expect(sql).toContain('generate_series');
    expect(sql).toContain('LEFT JOIN ventas USING (dia)');
    expect(sql).toContain("AT TIME ZONE 'America/Bogota'");
  });
});

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
      ['sucursal-1'],
    );
    const sql = database.consultarUno.mock.calls[0][0] as string;
    expect(sql).toContain("interval '25 minutes'");
    expect(sql).toContain("'entregado'");
    expect(sql).toContain('COALESCE(monto_pagado, 0) < total - 0.01');
    expect(database.consultarUno.mock.calls[0][0]).toContain('LIMIT 8');
    expect(cache.set).toHaveBeenCalledWith(
      'dash:resumen:sucursal-1',
      expect.objectContaining({ domicilios_tardios: [demora] }),
      30_000,
    );
  });
});
