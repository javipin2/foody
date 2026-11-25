import { PoolClient } from 'pg';
import { PedidosInventarioService } from './pedidos-inventario.service';

describe('PedidosInventarioService.registrarMermaPedidoCompleto', () => {
  it('no duplica la merma de líneas ya marcadas no_disponible en cocina', async () => {
    const query = jest.fn().mockResolvedValue({
      rows: [
        {
          producto_id: 'producto-nodisp',
          cantidad: '1',
          estado_cocina: 'no_disponible',
        },
        {
          producto_id: 'producto-pendiente',
          cantidad: '1',
          estado_cocina: 'pendiente',
        },
        {
          producto_id: 'producto-preparando',
          cantidad: '2',
          estado_cocina: 'preparando',
        },
      ],
    });
    const client = { query } as unknown as PoolClient;
    const service = new PedidosInventarioService(
      {} as never,
      {} as never,
      {} as never,
    );
    const registrarLinea = jest
      .spyOn(service, 'registrarMermaLineaProducto')
      .mockResolvedValue();

    await service.registrarMermaPedidoCompleto(
      client,
      'sucursal-1',
      'pedido-1',
      'Cancelación QA',
    );

    expect(
      registrarLinea.mock.calls.map(([, , , productoId]) => productoId),
    ).toEqual(['producto-pendiente', 'producto-preparando']);
    expect(registrarLinea).toHaveBeenCalledTimes(2);
  });
});
