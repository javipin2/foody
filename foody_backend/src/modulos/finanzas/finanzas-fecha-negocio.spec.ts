import { FinanzasService } from './finanzas.service';

describe('FinanzasService periodo predeterminado', () => {
  afterEach(() => jest.useRealTimers());

  it('resuelve el mes actual con el calendario de Bogotá y no con UTC', async () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-02-01T02:30:00.000Z'));
    const consultar = jest.fn().mockResolvedValue([]);
    const service = new FinanzasService({ consultar } as any);

    await service.listarGastos('sucursal-1');

    expect(consultar).toHaveBeenCalledWith(expect.any(String), [
      'sucursal-1',
      '2026-01-01',
      '2026-01-31',
    ]);
  });
});

describe('FinanzasService obligaciones de costos fijos', () => {
  it('muestra el saldo restante después de un abono parcial del mes', async () => {
    const consultar = jest.fn().mockImplementation((sql: string) => {
      if (sql.includes('costos_operativos_fijos')) {
        return [
          {
            id: 'fijo-1',
            concepto: 'Arriendo',
            monto_pendiente: '400.00',
            categoria: 'arriendo',
            dia_pago: 5,
          },
        ];
      }
      return [];
    });
    const consultarUno = jest.fn().mockImplementation((sql: string) => {
      if (sql.includes('AS mes_desde')) {
        return {
          mes_desde: '2026-11-01',
          mes_hasta: '2026-11-24',
          ant_desde: '2026-10-01',
          ant_hasta: '2026-10-31',
          dia_hoy: '24',
        };
      }
      if (sql.includes('FROM pedidos')) {
        return { ventas_netas: '0', pedidos: '0' };
      }
      if (sql.includes('FROM pedido_items')) {
        return { costo_ventas: '0', lineas_total: '0', lineas_con_costo: '0' };
      }
      return { total: '100' };
    });
    const service = new FinanzasService({ consultar, consultarUno } as any);

    const resumen = await service.resumen('sucursal-1');

    expect(resumen.pendientes.fijos).toEqual([
      expect.objectContaining({ concepto: 'Arriendo', monto: 400 }),
    ]);
    expect(resumen.pendientes.total_estimado).toBe(400);
    const sqlFijos = consultar.mock.calls.find(([sql]) =>
      sql.includes('costos_operativos_fijos'),
    )?.[0] as string;
    expect(sqlFijos).toContain('LEFT JOIN LATERAL');
    expect(sqlFijos).toContain('g.sucursal_id = cf.sucursal_id');
    expect(sqlFijos).toContain("g.origen = 'fijo'");
  });
});
