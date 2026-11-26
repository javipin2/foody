import { DatabaseService } from '../../core/database/database.service';
import { AnaliticaService } from './analitica.service';

describe('AnaliticaService inventario: stock devuelto', () => {
  it('expone las devoluciones aparte del consumo y las valora al costo actual', async () => {
    const database = {
      consultarUno: jest.fn().mockResolvedValue({
        consumo_unidades: '4',
        consumo_valor: '12000',
        stock_devuelto_valor: '3000',
        merma_valor: '500',
        ajuste_neto: '0',
        diferencia_conteo: '0',
        valor_inventario_actual: '100000',
      }),
      consultar: jest
        .fn()
        .mockResolvedValueOnce([
          {
            ingrediente_id: 'ingrediente-1',
            nombre: 'Harina',
            unidades: '4',
            valor: '12000',
          },
        ])
        .mockResolvedValueOnce([]),
    };
    const service = new AnaliticaService(
      database as unknown as DatabaseService,
      {} as never,
    );
    jest
      .spyOn(service as never, 'adjuntarComparativaKpis' as never)
      .mockImplementation(
        ((
          _sid: unknown,
          _periodo: unknown,
          _anterior: unknown,
          _filtros: unknown,
          data: unknown,
        ) => data) as never,
      );

    const result = await service.inventario('sucursal-1', {
      desde: '2026-11-01',
      hasta: '2026-11-26',
    } as never);

    expect(result.resumen).toMatchObject({
      consumo_unidades: 4,
      consumo_valor: 12000,
      stock_devuelto_valor: 3000,
    });
    const sqlResumen = database.consultarUno.mock.calls[0][0] as string;
    expect(sqlResumen).toContain("m.tipo = 'devolucion'");
    expect(sqlResumen).toContain('AS stock_devuelto_valor');
    expect(sqlResumen).toContain("FILTER (WHERE m.tipo = 'venta')");
  });
});
