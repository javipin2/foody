import { PoolClient } from 'pg';
import { BadRequestException } from '@nestjs/common';
import { PedidosEstadoCommandService } from './pedidos-estado-command.service';

describe('PedidosEstadoCommandService', () => {
  const service = new PedidosEstadoCommandService();

  function params(origen: 'kanban' | 'cocina' = 'kanban') {
    return {
      pedidoId: 'pedido-1',
      sucursalId: 'sucursal-1',
      nuevoEstado: 'listo',
      origen,
      estadoAnterior: 'en_cocina',
      tipo: 'domicilio',
    } as const;
  }

  it('rechaza Kanban listo si quedan ítems pendientes o nulos', async () => {
    const client = {
      query: jest.fn().mockResolvedValue({
        rows: [{ n: '2', incompletos: '1' }],
      }),
    } as unknown as PoolClient;

    await expect(
      service.aplicarEstadoEnTransaccion(client, params()),
    ).rejects.toMatchObject({
      response: {
        error: 'COCINA_INCOMPLETA_PARA_LISTO',
      },
    });
    expect(client.query).toHaveBeenCalledTimes(1);
  });

  it('permite marcar listo después de resolver todos los ítems', async () => {
    const query = jest
      .fn()
      .mockResolvedValueOnce({
        rows: [{ n: '2', incompletos: '0' }],
      })
      .mockResolvedValue({ rows: [] });
    const client = { query } as unknown as PoolClient;

    await expect(
      service.aplicarEstadoEnTransaccion(client, params()),
    ).resolves.toMatchObject({
      aplicado: true,
      anterior: 'en_cocina',
      nuevo: 'listo',
    });
    expect(query).toHaveBeenCalledTimes(3);
    expect(query.mock.calls[1][0]).toContain('UPDATE pedidos SET estado');
  });

  it('aplica la barrera también a un cambio automático de Cocina', async () => {
    const client = {
      query: jest.fn().mockResolvedValue({
        rows: [{ n: '0', incompletos: '0' }],
      }),
    } as unknown as PoolClient;

    try {
      await service.aplicarEstadoEnTransaccion(client, params('cocina'));
      fail('Se esperaba una transición rechazada para un pedido vacío');
    } catch (error) {
      expect(error).toBeInstanceOf(BadRequestException);
      expect((error as BadRequestException).getResponse()).toMatchObject({
        error: 'COCINA_INCOMPLETA_PARA_LISTO',
      });
    }
    expect(client.query).toHaveBeenCalledTimes(1);
  });
});
