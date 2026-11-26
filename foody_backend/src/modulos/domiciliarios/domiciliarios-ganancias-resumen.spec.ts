import { DatabaseService } from '../../core/database/database.service';
import { DomiciliariosIndependientesService } from './domiciliarios-independientes.service';
import { DispatchService } from './dispatch.service';

describe('resumen de ganancias independientes', () => {
  it('resume todo el periodo aunque la lista devuelva solo 100 filas', async () => {
    const filas = [
      {
        id: 'ganancia-reciente',
        valor_domicilio: '5000',
        comision_foody: '750',
        ganancia_domiciliario: '4250',
        pagado: false,
        created_at: new Date('2026-11-26T12:00:00Z'),
        pedido_id: 'pedido-reciente',
        numero_pedido: 'D-125',
        estado_asignacion: 'entregado',
        entregas_periodo: '125',
        total_ganancia_periodo: '531250',
        total_comision_periodo: '93750',
      },
    ];
    const consultar = jest.fn().mockResolvedValue(filas);
    const database = { consultar } as unknown as DatabaseService;
    const service = new DomiciliariosIndependientesService(
      database,
      {} as unknown as DispatchService,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    const resultado = await service.ganancias('dom-1', {
      desde: '2026-11-01',
      hasta: '2026-11-26',
    });

    expect(resultado.items).toHaveLength(1);
    expect(resultado.resumen).toEqual({
      entregas: 125,
      total_ganancia: 531250,
      total_comision: 93750,
    });
    const sql = consultar.mock.calls[0][0] as string;
    expect(sql).toContain('COUNT(*) OVER () AS entregas_periodo');
    expect(sql).toContain('SUM(g.ganancia_domiciliario) OVER ()');
    expect(sql).toContain('LIMIT 100');
    expect(consultar.mock.calls[0][1]).toEqual([
      'dom-1',
      '2026-11-01',
      '2026-11-26',
    ]);
  });

  it('devuelve resumen en cero si el periodo no tiene asignaciones', async () => {
    const consultar = jest.fn().mockResolvedValue([]);
    const service = new DomiciliariosIndependientesService(
      { consultar } as unknown as DatabaseService,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    await expect(service.ganancias('dom-1')).resolves.toEqual({
      items: [],
      resumen: { entregas: 0, total_ganancia: 0, total_comision: 0 },
    });
  });
});
