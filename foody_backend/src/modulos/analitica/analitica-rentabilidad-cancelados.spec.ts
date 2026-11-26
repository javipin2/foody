import { DatabaseService } from '../../core/database/database.service';
import { AnaliticaService } from './analitica.service';

describe('AnaliticaService rentabilidad: estados de pedidos', () => {
  const crearServicio = () => {
    const database = {
      consultarUno: jest.fn().mockResolvedValueOnce({ total: '0' }),
      consultar: jest.fn().mockResolvedValue([]),
    };
    const service = new AnaliticaService(
      database as unknown as DatabaseService,
      {} as never,
    );
    jest.spyOn(service as never, 'kpisPeriodo' as never).mockResolvedValue({
      ventas_netas: 500,
      valor_pedidos: 500,
      ventas_reconocidas: 450,
      costo_ventas_reconocidas: 100,
      cargo_domicilio_pedidos_cumplidos: 20,
      cobertura_costo_pct: 100,
    } as never);
    return { database, service };
  };

  it('calcula rentabilidad con ventas cumplidas sin mezclar el domicilio', async () => {
    const { database, service } = crearServicio();
    const result = await service.rentabilidad('sucursal-1', {
      preset: 'personalizado',
      desde: '2026-11-01',
      hasta: '2026-11-24',
      label: 'Periodo',
    });

    expect(result).toMatchObject({
      ventas_netas: 450,
      valor_pedidos: 500,
      cargo_domicilio_pedidos_cumplidos: 20,
      costo_ventas: 100,
      utilidad_bruta: 350,
      utilidad_neta: 350,
    });
    expect(database.consultarUno).toHaveBeenCalledTimes(1);
  });

  it('pasa los filtros a la métrica de ventas cumplidas', async () => {
    const { service } = crearServicio();
    await service.rentabilidad(
      'sucursal-1',
      {
        preset: 'personalizado',
        desde: '2026-11-01',
        hasta: '2026-11-24',
        label: 'Periodo',
      },
      { estados: ['cancelado'] } as never,
    );

    expect(service['kpisPeriodo']).toHaveBeenCalledWith(
      'sucursal-1',
      '2026-11-01',
      '2026-11-24',
      { estados: ['cancelado'] },
    );
  });

  it('compara utilidad usando la misma base de ventas cumplidas del período previo', async () => {
    const { service } = crearServicio();
    const kpisSpy = jest.spyOn(service as never, 'kpisPeriodo' as never);
    kpisSpy
      .mockResolvedValueOnce({
        ventas_netas: 500,
        valor_pedidos: 500,
        ventas_reconocidas: 450,
        costo_ventas_reconocidas: 100,
        cargo_domicilio_pedidos_cumplidos: 20,
        cobertura_costo_pct: 100,
      } as never)
      .mockResolvedValueOnce({
        ventas_netas: 400,
        valor_pedidos: 400,
        ventas_reconocidas: 360,
        costo_ventas_reconocidas: 80,
        cargo_domicilio_pedidos_cumplidos: 0,
        cobertura_costo_pct: 100,
      } as never);
    await service.rentabilidad(
      'sucursal-1',
      {
        preset: 'personalizado',
        desde: '2026-11-20',
        hasta: '2026-11-24',
        label: 'Actual',
      },
      { productoIds: ['producto-1'] },
      { desde: '2026-11-15', hasta: '2026-11-19' },
    );

    expect(kpisSpy).toHaveBeenNthCalledWith(
      2,
      'sucursal-1',
      '2026-11-15',
      '2026-11-19',
      { productoIds: ['producto-1'] },
    );
  });
});
