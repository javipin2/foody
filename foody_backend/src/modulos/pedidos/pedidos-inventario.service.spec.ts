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

describe('PedidosInventarioService.lineasDesdePedido', () => {
  it('reconstruye stock desde el snapshot vendido y conserva extras incluidos', async () => {
    const query = jest.fn(async (sql: string) => {
      if (sql.includes('FROM pedido_items pi')) {
        return {
          rows: [
            {
              item_id: 'pedido-item-1',
              producto_id: 'producto-principal',
              cantidad: 2,
              precio_unitario: '15000',
            },
          ],
        };
      }
      if (sql.includes('FROM pedido_combo_selecciones')) {
        return {
          rows: [
            {
              combo_id: 'combo-1',
              componentes_snapshot: [
                {
                  tipo_item: 'producto',
                  item_id: 'producto-principal',
                  nombre: 'Hamburguesa',
                  cantidad: 1,
                },
                {
                  tipo_item: 'producto',
                  item_id: 'producto-guarnicion',
                  nombre: 'Papas',
                  cantidad: 2,
                },
                {
                  tipo_item: 'bebida',
                  item_id: 'bebida-1',
                  nombre: 'Gaseosa',
                  cantidad: 1,
                },
                {
                  tipo_item: 'topping',
                  item_id: 'topping-1',
                  nombre: 'Queso',
                  cantidad: 2,
                },
              ],
            },
          ],
        };
      }
      throw new Error(`Consulta inesperada: ${sql}`);
    });
    const service = new PedidosInventarioService(
      {} as never,
      {} as never,
      {} as never,
    );

    const lineas = await service.lineasDesdePedido(
      { query } as unknown as PoolClient,
      'pedido-1',
      'sucursal-1',
    );

    expect(lineas).toEqual([
      {
        productoId: 'producto-principal',
        cantidad: 2,
        precioVentaLinea: 0,
        extras: [
          { tipo: 'bebida', id: 'bebida-1', cantidad: 2 },
          { tipo: 'topping', id: 'topping-1', cantidad: 4 },
        ],
      },
      {
        productoId: 'producto-guarnicion',
        cantidad: 4,
        precioVentaLinea: 0,
        extras: [],
      },
    ]);
    expect(query).toHaveBeenCalledTimes(2);
  });
});
