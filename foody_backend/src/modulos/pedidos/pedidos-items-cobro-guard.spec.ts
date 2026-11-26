import { PoolClient } from 'pg';
import { PedidosItemsService } from './pedidos-items.service';

function crearServicio(resultados: unknown[]) {
  const client = {
    query: jest.fn().mockResolvedValue({ rows: [] }),
  };
  const database = {
    enTransaccion: jest.fn(async (fn: (c: PoolClient) => unknown) =>
      fn(client as unknown as PoolClient),
    ),
  };
  const soporte = {
    consultarUnoCliente: jest.fn(async () => resultados.shift() ?? null),
  };
  const servicio = new PedidosItemsService(
    database as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    soporte as never,
    {} as never,
    {} as never,
    {} as never,
  );
  return { servicio, client };
}

const pedido = {
  id: 'pedido-1',
  estado: 'en_cocina',
  tipo: 'mesa',
  mesa_id: 'mesa-1',
  stock_descontado: true,
  subtotal: '20000',
  total: '20000',
  monto_pagado: '5000',
  costo_domicilio: '0',
  descuento: '0',
  numero_pedido: 'M-1',
  promocion_id: null,
};

const item = {
  id: 'item-1',
  producto_id: 'producto-1',
  cantidad: 1,
  precio_unitario: '10000',
  costo_unitario: '3000',
  estado_cocina: 'pendiente',
  cocina_id: 'cocina-1',
  observaciones: null,
  nombre_producto: 'Arepa',
};

describe('protección de cobros asignados a líneas de pedido', () => {
  it('no elimina una línea cobrada aunque el total restante cubra el abono', async () => {
    const { servicio, client } = crearServicio([
      pedido,
      item,
      { estado_cobro: 'cobrado', tiene_pago_asociado: true },
    ]);

    await expect(
      servicio.eliminarItemPedido(
        'pedido-1',
        'item-1',
        'sucursal-1',
        'usuario-1',
      ),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        error: 'ITEM_REQUIERE_AJUSTE_COBRO',
      }),
    });
    expect(client.query).not.toHaveBeenCalled();
  });

  it('bloquea cambios de cantidad/opciones si la línea ya tiene un pago asociado', async () => {
    const { servicio, client } = crearServicio([
      pedido,
      item,
      { estado_cobro: 'pendiente', tiene_pago_asociado: true },
    ]);

    await expect(
      servicio.actualizarItemPedido(
        'pedido-1',
        'item-1',
        'sucursal-1',
        'usuario-1',
        { cantidad: 2 },
      ),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        error: 'ITEM_REQUIERE_AJUSTE_COBRO',
      }),
    });
    expect(client.query).not.toHaveBeenCalledWith(
      expect.stringContaining('UPDATE pedido_items SET'),
      expect.anything(),
    );
  });

  it('bloquea cambiar toppings después del descuento para no dejar stock sin conciliar', async () => {
    const { servicio, client } = crearServicio([
      pedido,
      item,
      { estado_cobro: 'pendiente', tiene_pago_asociado: false },
    ]);
    client.query.mockResolvedValueOnce({
      rows: [{ topping_id: 'topping-anterior' }],
    });

    await expect(
      servicio.actualizarItemPedido(
        'pedido-1',
        'item-1',
        'sucursal-1',
        'usuario-1',
        { toppings: [{ topping_id: 'topping-nuevo' }] },
      ),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        error: 'ITEM_TOPPINGS_REQUIERE_AJUSTE_STOCK',
      }),
    });
    expect(client.query).toHaveBeenCalledTimes(1);
    expect(client.query).not.toHaveBeenCalledWith(
      expect.stringContaining('UPDATE pedido_items SET'),
      expect.anything(),
    );
  });

  it('bloquea reducir cantidad después del descuento si no existe consumo por línea', async () => {
    const { servicio, client } = crearServicio([
      pedido,
      item,
      { estado_cobro: 'pendiente', tiene_pago_asociado: false },
    ]);

    await expect(
      servicio.actualizarItemPedido(
        'pedido-1',
        'item-1',
        'sucursal-1',
        'usuario-1',
        { cantidad: 0 },
      ),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        error: 'ITEM_REQUIERE_AJUSTE_STOCK',
      }),
    });
    expect(client.query).not.toHaveBeenCalledWith(
      expect.stringContaining('UPDATE pedido_items SET'),
      expect.anything(),
    );
  });

  it('bloquea eliminar una línea pendiente cuyo stock ya fue descontado', async () => {
    const { servicio, client } = crearServicio([
      pedido,
      item,
      { estado_cobro: 'pendiente', tiene_pago_asociado: false },
    ]);
    client.query.mockImplementation(async (sql: string) =>
      sql.includes('COUNT(*)') ? { rows: [{ n: '2' }] } : { rows: [] },
    );

    await expect(
      servicio.eliminarItemPedido(
        'pedido-1',
        'item-1',
        'sucursal-1',
        'usuario-1',
      ),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        error: 'ITEM_REQUIERE_AJUSTE_STOCK',
      }),
    });
    expect(client.query).not.toHaveBeenCalledWith(
      expect.stringContaining('DELETE FROM pedido_items'),
      expect.anything(),
    );
  });
});
