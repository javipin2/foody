import { DatabaseService } from '../../core/database/database.service';
import { AnaliticaService } from './analitica.service';

describe('AnaliticaService caja: gastos contables vs movimientos', () => {
  it('no suma dos veces un gasto que existe en ambos libros', async () => {
    const database = {
      consultarUno: jest
        .fn()
        .mockResolvedValueOnce({
          ventas_caja: '1000',
          retiros: '0',
          gastos_mov: '100',
        })
        .mockResolvedValueOnce({ pendiente: '0', cantidad: '0' }),
      consultar: jest
        .fn()
        .mockResolvedValueOnce([
          { categoria: 'operativo', total: '100', cantidad: '1' },
        ])
        .mockResolvedValueOnce([]),
    };
    const service = new AnaliticaService(
      database as unknown as DatabaseService,
      {} as never,
    );
    jest
      .spyOn(service as never, 'ventasNetasPeriodo' as never)
      .mockResolvedValue(1000 as never);
    jest
      .spyOn(service as never, 'adjuntarComparativaKpis' as never)
      .mockImplementation(((_sid: unknown, _periodo: unknown, _anterior: unknown,
        _filtros: unknown, data: unknown) => data) as never);

    const result = await service.caja(
      'sucursal-1',
      { desde: '2026-11-01', hasta: '2026-11-23' } as never,
    );

    expect(result).toMatchObject({
      gastos_total: 100,
      gastos_movimientos_caja: 100,
      cuadre: {
        etiqueta_ventas_caja: 'Cobros netos asociados a pedidos',
        nota_periodo_caja:
          'Compara ventas de pedidos creados en el rango con cobros netos asociados a esos pedidos. Los movimientos vinculados usan la fecha del pedido, aunque el pago ocurra después del rango; por eso esta diferencia puede cambiar con cobros posteriores y no representa el descuadre físico de un turno.',
      },
    });

    const sqlMovimientos = database.consultarUno.mock.calls[0][0] as string;
    expect(sqlMovimientos).toContain('COALESCE(p.created_at, m.created_at)');

    const consultasFecha = database.consultar.mock.calls.map(
      ([sql]) => sql as string,
    );
    expect(consultasFecha[0]).toContain(
      "created_at >= ($2::date::timestamp AT TIME ZONE 'America/Bogota')",
    );
    expect(consultasFecha[0]).toContain(
      "created_at < (($3::date + interval '1 day')::timestamp AT TIME ZONE 'America/Bogota')",
    );
    expect(consultasFecha[1]).toContain(
      "cierre_at >= ($2::date::timestamp AT TIME ZONE 'America/Bogota')",
    );
    expect(consultasFecha[1]).toContain(
      "cierre_at < (($3::date + interval '1 day')::timestamp AT TIME ZONE 'America/Bogota')",
    );
  });
});
