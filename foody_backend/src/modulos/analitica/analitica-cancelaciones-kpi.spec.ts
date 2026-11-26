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
          ventas_reconocidas: '66000',
          costo_ventas_reconocidas: '0',
          lineas_total: '9',
          lineas_con_costo: '9',
          cargo_domicilio_pedidos_cumplidos: '6000',
        })
        .mockResolvedValueOnce({ total: '48', cancelados: '39' })
        .mockResolvedValueOnce({
          efectivo: '42000',
          digital: '33000',
          recaudado_bruto: '75000',
          devoluciones: '3000',
        })
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
      recaudo_neto: 72000,
      pct_cancelacion: 81.3,
      pedidos_cancelados: 39,
      pedidos_total_cancelacion: 48,
      alertas_abiertas: 478,
    });

    const consultaRecaudo = database.consultarUno.mock.calls[3][0] as string;
    expect(consultaRecaudo).toContain('m.created_at >=');
    expect(consultaRecaudo).toContain(
      "m.created_at < (($3::date + interval '1 day')::timestamp AT TIME ZONE 'America/Bogota')",
    );
    expect(consultaRecaudo).not.toContain('p.created_at');
    expect(consultaRecaudo).toContain("m.tipo = 'devolucion'");

    const consultaCumplimiento = database.consultarUno.mock
      .calls[1][0] as string;
    expect(consultaCumplimiento).toContain("base.tipo = 'domicilio'");
    expect(consultaCumplimiento).toContain("h.estado_nuevo = 'entregado'");
    expect(consultaCumplimiento).toContain("h.estado_nuevo = 'pagado'");
    expect(consultaCumplimiento).toContain('p.iva_valor');
    expect(consultaCumplimiento).toContain('p.costo_domicilio');
    expect(result).toMatchObject({
      ventas_reconocidas: 66000,
      cargo_domicilio_pedidos_cumplidos: 6000,
      margen_bruto_estimado: 66000,
    });
  });
});
