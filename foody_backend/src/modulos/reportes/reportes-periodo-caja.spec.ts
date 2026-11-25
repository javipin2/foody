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
        .mockResolvedValueOnce({ ventas_caja: '900', movimientos: '2' }),
      consultar: jest.fn().mockResolvedValue([]),
    };
    const service = new ReportesService(database as unknown as DatabaseService);

    const resultado = await service.financiero('sucursal-1', {
      desde: '2026-11-01',
      hasta: '2026-11-23',
    });

    expect(resultado.cuadre_caja).toMatchObject({
      etiqueta_ventas_caja: 'Movimientos netos de caja',
      nota_periodo_caja:
        'Para movimientos ligados a un pedido se usa la fecha de creación del pedido; para movimientos sin pedido, la fecha del movimiento.',
    });
    expect(resultado.cuadre_caja.nota_universos).toContain(
      'no representa necesariamente el efectivo recibido en el rango',
    );
    expect(database.consultarUno.mock.calls[1][0]).toContain('p.created_at');
  });
});
