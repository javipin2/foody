import { DatabaseService } from '../../core/database/database.service';
import { ReportesService } from './reportes.service';

describe('ReportesService — atribución de fechas de caja', () => {
  it('resuelve hoy por el calendario de Bogotá, no por la fecha UTC siguiente', () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-11-25T04:30:00.000Z'));
    try {
      const service = new ReportesService({} as DatabaseService);

      expect(service.resolverRango()).toEqual({
        desde: '2026-11-18',
        hasta: '2026-11-24',
      });
    } finally {
      jest.useRealTimers();
    }
  });

  it('explica qué fecha asigna los movimientos al rango del reporte', async () => {
    const database = {
      consultarUno: jest
        .fn()
        .mockResolvedValueOnce({
          ventas_total: '1200',
          subtotal: '1200',
          costo_domicilio: '0',
          descuentos: '0',
          pedidos: '1',
          ticket_promedio: '1200',
        })
        .mockResolvedValueOnce({ ventas_caja: '900', movimientos: '2' })
        .mockResolvedValueOnce({ total_neto: '950', movimientos_venta: '2' }),
      consultar: jest.fn().mockResolvedValue([]),
    };
    const service = new ReportesService(database as unknown as DatabaseService);

    const resultado = await service.financiero('sucursal-1', {
      desde: '2026-11-01',
      hasta: '2026-11-23',
    });

    expect(resultado.cuadre_caja).toMatchObject({
      etiqueta_ventas_pedidos: 'Valor total de pedidos creados en el rango',
      etiqueta_ventas_caja: 'Cobros netos asociados a pedidos',
      nota_periodo_caja:
        'Los movimientos ligados a pedidos se atribuyen por fecha de creación del pedido, aunque el cobro ocurra después del rango; los movimientos sin pedido usan su propia fecha.',
    });
    expect(resultado.cuadre_caja.nota_universos).toContain(
      'No representa el efectivo recibido en el rango ni el descuadre físico de un turno.',
    );
    expect(database.consultarUno.mock.calls[1][0]).toContain('p.created_at');
    expect(resultado.recaudo_periodo).toMatchObject({
      total_neto: 950,
      movimientos_venta: 2,
      etiqueta: 'Recaudo neto por fecha de movimiento',
    });
    expect(database.consultarUno.mock.calls[2][0]).toContain(
      'm.created_at >= ($2::date::timestamp AT TIME ZONE',
    );
  });

  it('desglosa el cargo de domicilio por tipo sin cambiar el total de pedidos', async () => {
    const database = {
      consultarUno: jest
        .fn()
        .mockResolvedValueOnce({
          ventas_total: '30000',
          subtotal: '25000',
          costo_domicilio: '5000',
          descuentos: '0',
          pedidos: '2',
          ticket_promedio: '15000',
        })
        .mockResolvedValueOnce({ ventas_caja: '0', movimientos: '0' })
        .mockResolvedValueOnce({ total_neto: '0', movimientos_venta: '0' }),
      consultar: jest
        .fn()
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([
          {
            tipo: 'domicilio',
            pedidos: '2',
            ventas: '30000',
            costo_domicilio: '5000',
          },
        ]),
    };
    const service = new ReportesService(database as unknown as DatabaseService);

    const resultado = await service.financiero('sucursal-1', {
      desde: '2026-11-01',
      hasta: '2026-11-23',
    });

    expect(resultado.por_tipo).toEqual([
      {
        tipo: 'domicilio',
        pedidos: 2,
        ventas: 30000,
        costo_domicilio: 5000,
      },
    ]);
    expect(database.consultar.mock.calls[1][0]).toContain(
      'SUM(costo_domicilio)',
    );
    expect(resultado.resumen.ventas_total).toBe(30000);
  });

  it('desglosa el domicilio en la serie diaria de pedidos', async () => {
    const database = {
      consultar: jest
        .fn()
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([
          {
            dia: '2026-11-23',
            pedidos: '1',
            ventas: '15000',
            costo_domicilio: '5000',
          },
        ]),
    };
    const service = new ReportesService(database as unknown as DatabaseService);

    const resultado = await service.pedidos('sucursal-1', {
      desde: '2026-11-23',
      hasta: '2026-11-23',
    });

    expect(resultado.por_dia).toEqual([
      {
        dia: '2026-11-23',
        pedidos: 1,
        ventas: 15000,
        costo_domicilio: 5000,
      },
    ]);
    expect(database.consultar.mock.calls[1][0]).toContain(
      'SUM(costo_domicilio)',
    );
  });
});
