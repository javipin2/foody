import { PoolClient } from 'pg';
import { StockMovimientoService } from './stock-movimiento.service';

describe('StockMovimientoService', () => {
  it('guarda la línea de pedido que originó el movimiento de inventario', async () => {
    const query = jest.fn().mockResolvedValue({ rows: [] });
    const service = new StockMovimientoService();

    await service.aplicarMovimiento({
      client: { query } as unknown as PoolClient,
      sucursalId: 'sucursal-1',
      ingredienteId: 'ingrediente-1',
      pedidoId: 'pedido-1',
      pedidoItemId: 'pedido-item-1',
      tipo: 'venta',
      cantidad: 2,
      stockAnterior: 10,
      stockPosterior: 8,
      motivo: 'Venta pedido',
    });

    expect(query).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining('pedido_item_id'),
      [
        'sucursal-1',
        'ingrediente-1',
        'pedido-1',
        'pedido-item-1',
        'venta',
        2,
        10,
        8,
        'Venta pedido',
        null,
        null,
      ],
    );
  });
});
