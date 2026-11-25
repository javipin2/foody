import { ConflictException } from '@nestjs/common';
import { PoolClient } from 'pg';
import { CocinasService } from './cocinas.service';

describe('CocinasService — terminar cocina tras cobro excepcional', () => {
  const crearServicio = (montoPagado: string) => {
    const client = {
      query: jest
        .fn()
        .mockResolvedValueOnce({
          rows: [
            {
              pedido_id: 'pedido-1',
              estado: 'pagado',
              tipo: 'mesa',
              cocina_id: 'cocina-1',
              numero_pedido: 'P-001',
              total: '10000',
              monto_pagado: montoPagado,
              estado_cocina: 'preparando',
              producto_id: 'producto-1',
              cantidad: 1,
              stock_descontado: true,
              nombre_producto: 'Plato',
            },
          ],
        })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({
          rows: [{ pendientes: '0', en_proceso: '0' }],
        }),
    };
    const database = {
      enTransaccion: jest.fn(async (callback: (tx: PoolClient) => unknown) =>
        callback(client as unknown as PoolClient),
      ),
    };
    const estadoCommand = { aplicarEstadoEnTransaccion: jest.fn() };
    const realtime = {
      cocinaActualizada: jest.fn().mockResolvedValue(undefined),
    };
    const service = new CocinasService(
      database as never,
      realtime as never,
      {} as never,
      {} as never,
      {} as never,
      estadoCommand as never,
      {} as never,
      {} as never,
    );
    return { client, database, estadoCommand, service };
  };

  it('termina la línea y conserva pagado sin volver a mutar el estado global', async () => {
    const { client, estadoCommand, service } = crearServicio('10000');

    await expect(
      service.cambiarEstadoItem(
        'item-1',
        'sucursal-1',
        'listo',
        'usuario-cocina',
      ),
    ).resolves.toMatchObject({
      estado_cocina: 'listo',
      estado_pedido: 'pagado',
      pedido_id: 'pedido-1',
    });

    expect(client.query.mock.calls[1][0]).toContain(
      'UPDATE pedido_items SET estado_cocina',
    );
    expect(estadoCommand.aplicarEstadoEnTransaccion).not.toHaveBeenCalled();
  });

  it('rechaza finalizar una línea si el saldo no está completamente cubierto', async () => {
    const { client, service } = crearServicio('9999');

    await expect(
      service.cambiarEstadoItem(
        'item-1',
        'sucursal-1',
        'listo',
        'usuario-cocina',
      ),
    ).rejects.toBeInstanceOf(ConflictException);

    expect(client.query).toHaveBeenCalledTimes(1);
  });
});
