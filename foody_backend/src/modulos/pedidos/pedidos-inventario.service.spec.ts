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
        pedidoItemId: 'pedido-item-1',
        productoId: 'producto-principal',
        cantidad: 2,
        precioVentaLinea: 0,
        extras: [
          { tipo: 'bebida', id: 'bebida-1', cantidad: 2 },
          { tipo: 'topping', id: 'topping-1', cantidad: 4 },
        ],
      },
      {
        pedidoItemId: 'pedido-item-1',
        productoId: 'producto-guarnicion',
        cantidad: 4,
        precioVentaLinea: 0,
        extras: [],
      },
    ]);
    expect(query).toHaveBeenCalledTimes(2);
  });

  it('conserva separadas dos líneas del mismo producto para asociar su consumo', async () => {
    const query = jest.fn(async (sql: string) => {
      if (sql.includes('FROM pedido_items pi')) {
        return {
          rows: [
            {
              item_id: 'item-1',
              producto_id: 'producto-1',
              cantidad: 1,
              precio_unitario: '5000',
            },
            {
              item_id: 'item-2',
              producto_id: 'producto-1',
              cantidad: 2,
              precio_unitario: '5000',
            },
          ],
        };
      }
      return { rows: [] };
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
        productoId: 'producto-1',
        pedidoItemId: 'item-1',
        cantidad: 1,
        precioVentaLinea: 5000,
        extras: [],
      },
      {
        productoId: 'producto-1',
        pedidoItemId: 'item-2',
        cantidad: 2,
        precioVentaLinea: 10000,
        extras: [],
      },
    ]);
    expect(query).toHaveBeenCalledTimes(7);
  });
});

describe('PedidosInventarioService.descontarStockPedido', () => {
  it('vincula cada movimiento al ítem que consumió el ingrediente', async () => {
    const movimientos = {
      aplicarMovimiento: jest.fn().mockResolvedValue({}),
    };
    const disponibilidad = {
      sincronizarPorIngredienteEnTransaccion: jest.fn().mockResolvedValue([]),
    };
    const service = new PedidosInventarioService(
      {} as never,
      disponibilidad as never,
      movimientos as never,
    );
    Object.defineProperty(service, 'expandirLineaCompleta', {
      value: jest
        .fn()
        .mockResolvedValue([{ ingrediente_id: 'ingrediente-1', cantidad: 2 }]),
    });
    Object.defineProperty(service, 'cargarStockIngredientes', {
      value: jest.fn().mockResolvedValue([
        {
          ingrediente_id: 'ingrediente-1',
          nombre: 'Harina',
          unidad_base: 'g',
          cantidad: 2,
          stock_actual: 10,
          stock_minimo: 0,
          costo_unitario_actual: 1,
          descontar_stock: true,
        },
      ]),
    });

    await service.descontarStockPedido(
      { query: jest.fn() } as unknown as PoolClient,
      'sucursal-1',
      'pedido-1',
      [
        {
          pedidoItemId: 'pedido-item-1',
          productoId: 'producto-1',
          cantidad: 1,
          precioVentaLinea: 5000,
        },
      ],
    );

    expect(movimientos.aplicarMovimiento).toHaveBeenCalledWith(
      expect.objectContaining({
        pedidoId: 'pedido-1',
        pedidoItemId: 'pedido-item-1',
        ingredienteId: 'ingrediente-1',
        tipo: 'venta',
      }),
    );
  });
});

describe('PedidosInventarioService.restaurarStockPedido', () => {
  it('repone el saldo neto de movimientos y registra una devolución idempotente', async () => {
    const movimientos = { aplicarMovimiento: jest.fn().mockResolvedValue({}) };
    const disponibilidad = {
      sincronizarPorIngredienteEnTransaccion: jest
        .fn()
        .mockResolvedValue([{ producto_id: 'producto-1', disponible: true }]),
    };
    const query = jest.fn(async (sql: string) => {
      if (sql.includes('GROUP BY ingrediente_id')) {
        return { rows: [{ ingrediente_id: 'ingrediente-1', cantidad: '3.5' }] };
      }
      if (sql.includes('FROM ingredientes') && sql.includes('FOR UPDATE')) {
        return { rows: [{ stock_actual: '4', stock_minimo: '1' }] };
      }
      throw new Error(`Consulta inesperada: ${sql}`);
    });
    const service = new PedidosInventarioService(
      {} as never,
      disponibilidad as never,
      movimientos as never,
    );

    const result = await service.restaurarStockPedido(
      { query } as unknown as PoolClient,
      'sucursal-1',
      'pedido-1',
    );

    expect(query.mock.calls[0][0]).toContain("tipo = 'devolucion'");
    expect(query.mock.calls[0][0]).toContain(
      'Devolución por ítem eliminado del pedido',
    );
    expect(movimientos.aplicarMovimiento).toHaveBeenCalledWith(
      expect.objectContaining({
        tipo: 'devolucion',
        cantidad: 3.5,
        stockAnterior: 4,
        stockPosterior: 7.5,
        pedidoId: 'pedido-1',
        pedidoItemId: null,
      }),
    );
    expect(result).toEqual([{ producto_id: 'producto-1', disponible: true }]);
  });

  it('no crea un movimiento cuando no queda consumo neto por devolver', async () => {
    const movimientos = { aplicarMovimiento: jest.fn() };
    const query = jest.fn().mockResolvedValue({ rows: [] });
    const service = new PedidosInventarioService(
      {} as never,
      { sincronizarPorIngredienteEnTransaccion: jest.fn() } as never,
      movimientos as never,
    );

    await service.restaurarStockPedido(
      { query } as unknown as PoolClient,
      'sucursal-1',
      'pedido-1',
    );

    expect(movimientos.aplicarMovimiento).not.toHaveBeenCalled();
  });
});
