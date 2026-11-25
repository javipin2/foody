import { DatabaseService } from '../../core/database/database.service';
import { AnaliticaService } from './analitica.service';

describe('AnaliticaService KPI de cancelaciones', () => {
  it('expone el numerador y denominador usados por el porcentaje', async () => {
    const database = {
      consultarUno: jest
        .fn()
        .mockResolvedValueOnce({
          ventas_netas: '72000',
          pedidos: '9',
          ticket_promedio: '8000',
        })
        .mockResolvedValueOnce({
          ingreso: '72000',
          costo: '0',
          lineas_total: '9',
          lineas_con_costo: '9',
        })
        .mockResolvedValueOnce({ total: '48', cancelados: '39' })
        .mockResolvedValueOnce({ efectivo: '72000', digital: '0' })
        .mockResolvedValueOnce({ abiertas: '478' }),
    };
    const service = new AnaliticaService(
      database as unknown as DatabaseService,
      {} as never,
    );

    const result = await (service as any).kpisPeriodo(
      'sucursal-1',
      '2026-11-10',
      '2026-11-16',
    );

    expect(result).toMatchObject({
      pedidos: 9,
      pct_cancelacion: 81.3,
      pedidos_cancelados: 39,
      pedidos_total_cancelacion: 48,
      alertas_abiertas: 478,
    });
  });
});
