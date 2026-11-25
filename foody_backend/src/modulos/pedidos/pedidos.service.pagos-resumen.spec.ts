import { PedidosService } from './pedidos.service';

describe('PedidosService.obtenerDetalleAdmin pagos_resumen', () => {
  it('incluye medios pagados y propina aparte, filtrados por sucursal', async () => {
    const detalleQuery = jest.fn().mockResolvedValue({
      id: 'pedido-1',
      numero_pedido: 'P-0001',
      tipo: 'mesa',
      estado: 'pagado',
      total: '58000',
      monto_pagado: '58000',
      metodo_pago: 'efectivo',
      pagos_resumen: [
        { metodo_pago: 'efectivo', monto: 53000 },
        { metodo_pago: 'nequi', monto: 5000 },
      ],
      propina_recibida: '2000',
      created_at: '2026-11-25T12:00:00.000Z',
      estado_desde: '2026-11-25T12:00:00.000Z',
    });
    const database = {
      consultarUno: detalleQuery,
      consultar: jest.fn().mockResolvedValue([]),
    };
    const service = new PedidosService(
      database as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    const result = await service.obtenerDetalleAdmin('pedido-1', 'sucursal-1');

    expect(result).toMatchObject({
      total: '58000',
      pagos_resumen: [
        { metodo_pago: 'efectivo', monto: 53000 },
        { metodo_pago: 'nequi', monto: 5000 },
      ],
      propina_recibida: '2000',
    });
    expect(detalleQuery.mock.calls[0][0]).toContain(
      'WHERE pedido_id = p.id AND sucursal_id = p.sucursal_id',
    );
    expect(detalleQuery.mock.calls[0][1]).toEqual(['pedido-1', 'sucursal-1']);
  });
});
