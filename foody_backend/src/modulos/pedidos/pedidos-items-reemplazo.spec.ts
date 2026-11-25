import { createHash } from 'node:crypto';
import { PoolClient } from 'pg';
import { PedidosItemsService } from './pedidos-items.service';
import { DatabaseService } from '../../core/database/database.service';

describe('reemplazo transaccional de ítem de pedido', () => {
  const dto = {
    idempotency_key: 'replace-req-1',
    items: [{ producto_id: 'producto-2', cantidad: 1 }],
    motivo: 'Cambio de producto',
  } as never;

  function crearServicio(
    resultadosPrevios: unknown[] = [
      { id: 'pedido-1' },
      null,
      { estado_cobro: 'pendiente', tiene_pago_asociado: false },
      { monto_pagado: '0' },
    ],
  ) {
    const client = { query: jest.fn().mockResolvedValue({ rows: [] }) };
    const database = {
      enTransaccion: jest.fn(async (fn: (c: PoolClient) => unknown) =>
        fn(client as unknown as PoolClient),
      ),
    };
    const soporte = {
      consultarUnoCliente: jest.fn(
        async () => resultadosPrevios.shift() ?? null,
      ),
      notificarPedidoRealtime: jest.fn(),
      notificarCatalogoDisponibilidad: jest.fn(),
      notificarCocinasPorPedido: jest.fn(),
    };
    const servicio = new PedidosItemsService(
      database as unknown as DatabaseService,
      {} as never,
      { mesasActualizadas: jest.fn() } as never,
      {} as never,
      {} as never,
      soporte as never,
      {} as never,
      {} as never,
      {} as never,
    );
    return { client, database, soporte, servicio };
  }

  it('agrega y elimina con la misma transacción y publica después el estado final', async () => {
    const { client, database, soporte, servicio } = crearServicio();
    jest.spyOn(servicio, 'agregarItems').mockResolvedValue({
      pedido_id: 'pedido-1',
      numero_pedido: 'P-1',
      subtotal: 12000,
      delta_subtotal: 5000,
      total: 12000,
      estado: 'en_cocina',
      mesa_id: 'mesa-1',
      catalogo_cambios: [],
    });
    jest.spyOn(servicio, 'eliminarItemPedido').mockResolvedValue({
      pedido_id: 'pedido-1',
      item_id: 'item-1',
      estado: 'en_cocina',
      numero_pedido: 'P-1',
      subtotal: 11000,
      total: 11000,
      cocina_id: 'cocina-1',
      mesa_id: 'mesa-1',
    });

    const resultado = await servicio.reemplazarItemPedido(
      'pedido-1',
      'item-1',
      'sucursal-1',
      'usuario-1',
      dto,
      { creadoPorStaff: true, usuarioId: 'usuario-1', rol: 'admin' },
    );

    expect(database.enTransaccion).toHaveBeenCalledTimes(1);
    expect(servicio.agregarItems).toHaveBeenCalledWith(
      'pedido-1',
      'sucursal-1',
      expect.objectContaining({ items: dto.items }),
      expect.any(Object),
      client,
      false,
    );
    expect(servicio.eliminarItemPedido).toHaveBeenCalledWith(
      'pedido-1',
      'item-1',
      'sucursal-1',
      'usuario-1',
      'Cambio de producto',
      client,
      false,
      true,
    );
    expect(client.query).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO pedidos_items_idempotencia'),
      expect.arrayContaining(['pedido-1', 'replace-req-1']),
    );
    expect(resultado).toMatchObject({ subtotal: 11000, total: 11000 });
    expect(soporte.notificarPedidoRealtime).toHaveBeenCalledWith(
      'sucursal-1',
      'pedido-1',
      'en_cocina',
      'P-1',
    );
  });

  it('no deja continuar cuando el nuevo total exige reembolso', async () => {
    const { servicio, soporte } = crearServicio();
    jest.spyOn(servicio, 'agregarItems').mockResolvedValue({
      pedido_id: 'pedido-1',
      numero_pedido: 'P-1',
      subtotal: 12000,
      delta_subtotal: 5000,
      total: 12000,
      estado: 'en_cocina',
      mesa_id: null,
    });
    jest.spyOn(servicio, 'eliminarItemPedido').mockResolvedValue({
      pedido_id: 'pedido-1',
      item_id: 'item-1',
      estado: 'en_cocina',
      numero_pedido: 'P-1',
      subtotal: 9000,
      total: 9000,
      cocina_id: null,
      mesa_id: null,
    });
    // El cuarto valor de soporte es el saldo ya abonado.
    const consultar = jest.spyOn(soporte, 'consultarUnoCliente');
    consultar.mockImplementation(async () => {
      if (consultar.mock.calls.length === 1) return { id: 'pedido-1' };
      if (consultar.mock.calls.length === 2) return null;
      if (consultar.mock.calls.length === 3) {
        return { estado_cobro: 'pendiente', tiene_pago_asociado: false };
      }
      return { monto_pagado: '10000' };
    });

    await expect(
      servicio.reemplazarItemPedido(
        'pedido-1',
        'item-1',
        'sucursal-1',
        'usuario-1',
        dto,
      ),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        error: 'REEMPLAZO_REQUIERE_REEMBOLSO',
      }),
    });
  });

  it('reintento con la misma clave devuelve el resultado sin mutar otra vez', async () => {
    const resultadoPrevio = {
      pedido_id: 'pedido-1',
      numero_pedido: 'P-1',
      subtotal: 11000,
      delta_subtotal: 5000,
      total: 11000,
      estado: 'en_cocina',
      mesa_id: 'mesa-1',
    };
    const huella = createHash('sha256')
      .update(
        JSON.stringify({
          itemId: 'item-1',
          items: dto.items,
          combos: [],
          motivo: 'Cambio de producto',
        }),
      )
      .digest('hex');
    const { servicio, client } = crearServicio([
      { id: 'pedido-1' },
      { resultado: resultadoPrevio, huella },
    ]);
    const agregar = jest.spyOn(servicio, 'agregarItems');
    const eliminar = jest.spyOn(servicio, 'eliminarItemPedido');

    const resultado = await servicio.reemplazarItemPedido(
      'pedido-1',
      'item-1',
      'sucursal-1',
      'usuario-1',
      dto,
    );

    expect(resultado).toMatchObject({ ...resultadoPrevio, idempotente: true });
    expect(agregar).not.toHaveBeenCalled();
    expect(eliminar).not.toHaveBeenCalled();
    expect(client.query).not.toHaveBeenCalled();
  });

  it('bloquea el reemplazo si la línea original ya fue cobrada', async () => {
    const { servicio } = crearServicio([
      { id: 'pedido-1' },
      null,
      { estado_cobro: 'cobrado', tiene_pago_asociado: true },
    ]);
    const agregar = jest.spyOn(servicio, 'agregarItems');
    const eliminar = jest.spyOn(servicio, 'eliminarItemPedido');

    await expect(
      servicio.reemplazarItemPedido(
        'pedido-1',
        'item-1',
        'sucursal-1',
        'usuario-1',
        dto,
      ),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        error: 'ITEM_REQUIERE_AJUSTE_COBRO',
      }),
    });
    expect(agregar).not.toHaveBeenCalled();
    expect(eliminar).not.toHaveBeenCalled();
  });

  it('propaga el fallo al quitar la línea y no publica éxito', async () => {
    const { servicio, soporte, client } = crearServicio();
    jest.spyOn(servicio, 'agregarItems').mockResolvedValue({
      pedido_id: 'pedido-1',
      numero_pedido: 'P-1',
      subtotal: 12000,
      delta_subtotal: 5000,
      total: 12000,
      estado: 'en_cocina',
      mesa_id: null,
    });
    jest
      .spyOn(servicio, 'eliminarItemPedido')
      .mockRejectedValue(new Error('No se pudo retirar la línea anterior'));

    await expect(
      servicio.reemplazarItemPedido(
        'pedido-1',
        'item-1',
        'sucursal-1',
        'usuario-1',
        dto,
      ),
    ).rejects.toThrow('No se pudo retirar la línea anterior');
    expect(client.query).not.toHaveBeenCalled();
    expect(soporte.notificarPedidoRealtime).not.toHaveBeenCalled();
    expect(soporte.notificarCatalogoDisponibilidad).not.toHaveBeenCalled();
  });
});
