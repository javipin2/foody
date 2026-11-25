import { DatabaseService } from '../../core/database/database.service';
import { AnaliticaService } from './analitica.service';

describe('AnaliticaService — filtro por producto', () => {
  it('suma solo las líneas del producto filtrado, no el total del ticket', async () => {
    const database = {
      consultarUno: jest.fn().mockResolvedValue({
        ventas_netas: '25000',
        pedidos: '1',
        ticket_promedio: '25000',
      }),
    };
    const service = new AnaliticaService(
      database as unknown as DatabaseService,
      {} as never,
    );

    await (service as any).consultarVentasKpi(
      'sucursal-1',
      '2026-11-01',
      '2026-11-25',
      { productoIds: ['producto-1'] },
    );

    const [sql, params] = database.consultarUno.mock.calls[0] as [
      string,
      unknown[],
    ];
    expect(sql).toContain('FROM pedido_items pi');
    expect(sql).toContain('pi.producto_id = ANY($4::uuid[])');
    expect(sql).not.toContain('SUM(total)');
    expect(params).toEqual([
      'sucursal-1',
      '2026-11-01',
      '2026-11-25',
      ['producto-1'],
      ['producto-1'],
    ]);
  });
});
