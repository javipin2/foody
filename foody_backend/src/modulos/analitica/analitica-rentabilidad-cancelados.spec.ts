import { DatabaseService } from '../../core/database/database.service';
import { AnaliticaService } from './analitica.service';

describe('AnaliticaService rentabilidad: estados de pedidos', () => {
  const crearServicio = () => {
    const database = {
      consultarUno: jest
        .fn()
        .mockResolvedValueOnce({ costo_ventas: '100', ingreso_lineas: '500' })
        .mockResolvedValueOnce({ total: '0' }),
      consultar: jest.fn().mockResolvedValue([]),
    };
    const service = new AnaliticaService(
      database as unknown as DatabaseService,
      {} as never,
    );
    jest.spyOn(service as never, 'kpisPeriodo' as never).mockResolvedValue({
      ventas_netas: 500,
      cobertura_costo_pct: 100,
    } as never);
    return { database, service };
  };

  it('excluye cancelados/rechazados por defecto en el costo de ventas', async () => {
    const { database, service } = crearServicio();
    const result = await service.rentabilidad('sucursal-1', {
      desde: '2026-11-01',
      hasta: '2026-11-24',
      label: 'Periodo',
    });

    expect(database.consultarUno.mock.calls[0][0]).toContain(
      "p.estado NOT IN ('cancelado', 'rechazado')",
    );
    expect(result).toMatchObject({
      ventas_netas: 500,
      costo_ventas: 100,
      utilidad_bruta: 400,
      utilidad_neta: 400,
    });
  });

  it('respeta el filtro explícito de estados sin añadir exclusiones contradictorias', async () => {
    const { database, service } = crearServicio();
    await service.rentabilidad(
      'sucursal-1',
      { desde: '2026-11-01', hasta: '2026-11-24', label: 'Periodo' },
      { estados: ['cancelado'] } as never,
    );

    const consultaCogs = database.consultarUno.mock.calls[0][0] as string;
    expect(consultaCogs).toContain('p.estado = ANY(');
    expect(consultaCogs).not.toContain(
      "p.estado NOT IN ('cancelado', 'rechazado')",
    );
  });
});
