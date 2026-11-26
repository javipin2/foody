import { PoolClient } from 'pg';
import { PedidosInventarioService } from './pedidos-inventario.service';

describe('PedidosInventarioService.crearTareasCombo', () => {
  const crearServicio = () =>
    new PedidosInventarioService({} as never, {} as never, {} as never);

  it('crea una tarea por componente y conserva su estación y snapshots', async () => {
    const query = jest.fn().mockResolvedValue({ rows: [] });
    const service = crearServicio();

    await service.crearTareasCombo(
      { query } as unknown as PoolClient,
      'sucursal-1',
      'pedido-1',
      'pedido-item-1',
      [
        {
          tipo_item: 'producto',
          item_id: 'producto-1',
          nombre: 'Picada',
          cantidad: 1,
          costo_unitario: 5000,
          precio_unitario: 12000,
          cocina_id: 'cocina-1',
        },
        {
          tipo_item: 'bebida',
          item_id: 'bebida-1',
          nombre: 'Limonada',
          cantidad: 2,
          costo_unitario: 1000,
          precio_unitario: 3000,
          cocina_id: 'cocina-2',
        },
        {
          tipo_item: 'topping',
          item_id: 'topping-1',
          nombre: 'Queso extra',
          cantidad: 1,
          costo_unitario: 500,
          precio_unitario: 1000,
          cocina_id: 'cocina-1',
          producto_padre_id: 'producto-1',
          producto_padre_nombre_snapshot: 'Picada',
        },
      ],
    );

    expect(query).toHaveBeenCalledTimes(3);
    expect(query.mock.calls[0][1]).toEqual([
      'pedido-1',
      'pedido-item-1',
      'pedido-item-1',
      'sucursal-1',
      'cocina-1',
      0,
      'producto',
      'producto-1',
      'Picada',
      1,
      12000,
      5000,
      null,
      null,
    ]);
    expect(query.mock.calls[1][1]).toEqual([
      'pedido-1',
      'pedido-item-1',
      'pedido-item-1',
      'sucursal-1',
      'cocina-2',
      1,
      'bebida',
      'bebida-1',
      'Limonada',
      2,
      3000,
      1000,
      null,
      null,
    ]);
    expect(query.mock.calls[2][1]).toEqual([
      'pedido-1',
      'pedido-item-1',
      'pedido-item-1',
      'sucursal-1',
      'cocina-1',
      2,
      'topping',
      'topping-1',
      'Queso extra',
      1,
      1000,
      500,
      'producto-1',
      'Picada',
    ]);
  });

  it('rechaza un componente sin cocina antes de insertarlo', async () => {
    const query = jest.fn().mockResolvedValue({ rows: [] });
    const service = crearServicio();

    await expect(
      service.crearTareasCombo(
        { query } as unknown as PoolClient,
        'sucursal-1',
        'pedido-1',
        'pedido-item-1',
        [
          {
            tipo_item: 'producto',
            item_id: 'producto-1',
            nombre: 'Producto sin estación',
            cantidad: 1,
            costo_unitario: 0,
            precio_unitario: 5000,
            cocina_id: null,
          },
        ],
      ),
    ).rejects.toMatchObject({
      response: { error: 'COMBO_COMPONENTE_SIN_COCINA' },
    });
    expect(query).not.toHaveBeenCalled();
  });
});

describe('PedidosInventarioService combo stock snapshot', () => {
  it('guarda ingredientes/cantidades por índice de componente y costo snapshot', async () => {
    const query = jest.fn(async (_sql: string, _values: unknown[]) => ({
      rows: [],
    }));
    const costeo = {
      expandirIngredientesProducto: jest
        .fn()
        .mockResolvedValue([{ ingrediente_id: 'ing-1', cantidad: 0.2 }]),
      expandirIngredientesExtra: jest
        .fn()
        .mockResolvedValue([{ ingrediente_id: 'ing-1', cantidad: 0.1 }]),
    };
    const service = new PedidosInventarioService(
      costeo as never,
      {} as never,
      {} as never,
    );

    const acceso = service as never as {
      expandirLineaConComponentes: (...args: unknown[]) => Promise<{
        componentes: {
          indice: number;
          componenteId: string;
          ingredientes: { ingrediente_id: string; cantidad: number }[];
        }[];
      }>;
      registrarSnapshotStockCombo: (...args: unknown[]) => Promise<void>;
    };
    const componentes = await acceso.expandirLineaConComponentes(
      { query } as unknown as PoolClient,
      'sucursal-1',
      {
        pedidoItemId: 'item-1',
        productoId: 'plato-1',
        cantidad: 1,
        precioVentaLinea: 15000,
        comboComponenteIndice: 0,
        comboComponenteId: 'plato-1',
        extras: [
          {
            tipo: 'topping',
            id: 'top-1',
            cantidad: 1,
            comboComponenteIndice: 2,
            comboComponenteId: 'top-1',
          },
        ],
      },
      false,
    );

    await acceso.registrarSnapshotStockCombo(
      { query } as unknown as PoolClient,
      'sucursal-1',
      'pedido-1',
      {
        pedidoItemId: 'item-1',
        productoId: 'plato-1',
        cantidad: 1,
        precioVentaLinea: 15000,
        comboComponenteIndice: 0,
        comboComponenteId: 'plato-1',
        extras: [
          {
            tipo: 'topping',
            id: 'top-1',
            cantidad: 1,
            comboComponenteIndice: 2,
            comboComponenteId: 'top-1',
          },
        ],
      },
      componentes.componentes,
      [
        {
          ingrediente_id: 'ing-1',
          nombre: 'Queso',
          unidad_base: 'kg',
          cantidad: 0.3,
          stock_actual: 10,
          stock_minimo: 1,
          costo_unitario_actual: 4000,
          descontar_stock: true,
        },
      ],
    );

    expect(query).toHaveBeenCalledTimes(2);
    expect(query.mock.calls.map(([, values]) => values)).toEqual([
      ['pedido-1', 'item-1', 'item-1', 0, 'plato-1', 'ing-1', 0.2, 4000],
      ['pedido-1', 'item-1', 'item-1', 2, 'top-1', 'ing-1', 0.1, 4000],
    ]);
  });

  it('devuelve desde el ledger y no repite una devolución ya conciliada', async () => {
    let devuelto = false;
    const query = jest.fn(async (sql: string) => {
      if (sql.includes('FROM pedido_combo_stock_ledger')) {
        return {
          rows: devuelto
            ? []
            : [
                {
                  ingrediente_id: 'ing-1',
                  cantidad: '2.5',
                  costo_unitario_snapshot: '4000',
                },
              ],
        };
      }
      if (sql.includes('FROM ingredientes') && sql.includes('FOR UPDATE')) {
        return { rows: [{ stock_actual: '3' }] };
      }
      if (sql.includes('INSERT INTO pedido_combo_stock_ledger')) {
        devuelto = true;
      }
      return { rows: [] };
    });
    const movimientos = { aplicarMovimiento: jest.fn().mockResolvedValue({}) };
    const disponibilidad = {
      sincronizarPorIngredienteEnTransaccion: jest.fn().mockResolvedValue([]),
    };
    const service = new PedidosInventarioService(
      {} as never,
      disponibilidad as never,
      movimientos as never,
    );
    const client = { query } as unknown as PoolClient;
    const params = {
      sucursalId: 'sucursal-1',
      pedidoId: 'pedido-1',
      pedidoItemIdOriginal: 'item-1',
      decisionId: 'decision-1',
      componenteIndice: 2,
      componenteId: 'topping-1',
      tipoItem: 'topping' as const,
      cantidad: 1,
      evento: 'devolucion' as const,
      motivo: 'Combo cancelado por cliente',
      usuarioId: 'usuario-1',
    };

    await service.ajustarStockComponenteCombo(client, params);
    await service.ajustarStockComponenteCombo(client, params);

    expect(movimientos.aplicarMovimiento).toHaveBeenCalledTimes(1);
    expect(movimientos.aplicarMovimiento).toHaveBeenCalledWith(
      expect.objectContaining({
        tipo: 'devolucion',
        cantidad: 2.5,
        stockAnterior: 3,
        stockPosterior: 5.5,
        pedidoId: 'pedido-1',
        pedidoItemId: 'item-1',
      }),
    );
    expect(query).toHaveBeenCalledTimes(4);
  });
});

describe('PedidosInventarioService.lineasDesdePedido', () => {
  it('devuelve el stock del topping al plato padre del snapshot', async () => {
    const query = jest
      .fn()
      .mockResolvedValueOnce({
        rows: [
          {
            item_id: 'item-1',
            producto_id: 'plato-1',
            cantidad: 1,
            precio_unitario: '30000',
          },
        ],
      })
      .mockResolvedValueOnce({
        rows: [
          {
            combo_id: 'combo-1',
            componentes_snapshot: [
              {
                tipo_item: 'producto',
                item_id: 'plato-1',
                cantidad: 1,
              },
              {
                tipo_item: 'producto',
                item_id: 'plato-2',
                cantidad: 2,
              },
              {
                tipo_item: 'topping',
                item_id: 'queso',
                cantidad: 1,
                producto_padre_id: 'plato-2',
              },
              {
                tipo_item: 'bebida',
                item_id: 'limonada',
                cantidad: 1,
              },
            ],
          },
        ],
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
        productoId: 'plato-1',
        pedidoItemId: 'item-1',
        cantidad: 1,
        precioVentaLinea: 0,
        extras: [
          {
            tipo: 'bebida',
            id: 'limonada',
            cantidad: 1,
            comboComponenteIndice: 3,
            comboComponenteId: 'limonada',
          },
        ],
        comboComponenteIndice: 0,
        comboComponenteId: 'plato-1',
      },
      {
        productoId: 'plato-2',
        pedidoItemId: 'item-1',
        cantidad: 2,
        precioVentaLinea: 0,
        extras: [
          {
            tipo: 'topping',
            id: 'queso',
            cantidad: 1,
            comboComponenteIndice: 2,
            comboComponenteId: 'queso',
          },
        ],
        comboComponenteIndice: 1,
        comboComponenteId: 'plato-2',
      },
    ]);
  });
});

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
          {
            tipo: 'bebida',
            id: 'bebida-1',
            cantidad: 2,
            comboComponenteIndice: 2,
            comboComponenteId: 'bebida-1',
          },
          {
            tipo: 'topping',
            id: 'topping-1',
            cantidad: 4,
            comboComponenteIndice: 3,
            comboComponenteId: 'topping-1',
          },
        ],
        comboComponenteIndice: 0,
        comboComponenteId: 'producto-principal',
      },
      {
        pedidoItemId: 'pedido-item-1',
        productoId: 'producto-guarnicion',
        cantidad: 4,
        precioVentaLinea: 0,
        extras: [],
        comboComponenteIndice: 1,
        comboComponenteId: 'producto-guarnicion',
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
    Object.defineProperty(service, 'expandirLineaConComponentes', {
      value: jest.fn().mockResolvedValue({
        expandidos: [{ ingrediente_id: 'ingrediente-1', cantidad: 2 }],
        componentes: [],
      }),
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
    expect(query.mock.calls[0][0]).toContain("tipo = 'merma'");
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
