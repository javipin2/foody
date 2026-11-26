import { ConflictException } from '@nestjs/common';
import { PoolClient } from 'pg';
import { CocinasService } from './cocinas.service';

describe('CocinasService — tareas de combo en KDS', () => {
  const construir = (estadoLinea = 'preparando') => {
    const client = {
      query: jest
        .fn()
        .mockResolvedValueOnce({
          rows: [
            {
              tarea_id: 'tarea-1',
              pedido_item_id: 'linea-combo-1',
              pedido_id: 'pedido-1',
              cocina_id: 'cocina-2',
              numero_pedido: 'P-001',
              tipo: 'mesa',
              estado_pedido: 'en_cocina',
              estado_tarea: 'preparando',
              estado_linea: estadoLinea,
              total: '25000',
              monto_pagado: '0',
            },
          ],
        })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ estado: 'listo' }] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({
          rows: [{ pendientes: '0', en_proceso: '1' }],
        }),
    };
    const database = {
      enTransaccion: jest.fn(async (callback: (tx: PoolClient) => unknown) =>
        callback(client as unknown as PoolClient),
      ),
    };
    const realtime = {
      cocinaActualizada: jest.fn().mockResolvedValue(undefined),
      pedidoActualizado: jest.fn().mockResolvedValue(undefined),
    };
    const estadoCommand = { aplicarEstadoEnTransaccion: jest.fn() };
    const pedidosSoporte = { emitirSeguimientoPedido: jest.fn() };
    const dispatch = {};
    const service = new CocinasService(
      database as never,
      realtime as never,
      {} as never,
      {} as never,
      dispatch as never,
      estadoCommand as never,
      pedidosSoporte as never,
      {} as never,
    );
    return { client, database, realtime, estadoCommand, service };
  };

  it('actualiza la tarea y agrega cocina en su única línea cobrable', async () => {
    const { client, realtime, estadoCommand, service } = construir();

    await expect(
      service.cambiarEstadoTareaCombo(
        'tarea-1',
        'sucursal-1',
        'listo',
        'usuario-1',
      ),
    ).resolves.toMatchObject({
      tarea_id: 'tarea-1',
      pedido_item_id: 'linea-combo-1',
      estado_cocina: 'listo',
      estado_linea: 'listo',
      pedido_id: 'pedido-1',
    });

    expect(client.query.mock.calls[0][0]).toContain('FOR UPDATE OF p, pi, t');
    expect(client.query.mock.calls[1][0]).toContain(
      'UPDATE pedido_combo_tareas_cocina',
    );
    expect(client.query.mock.calls[3][0]).toContain(
      'UPDATE pedido_items SET estado_cocina',
    );
    expect(estadoCommand.aplicarEstadoEnTransaccion).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        pedidoId: 'pedido-1',
        nuevoEstado: 'listo',
      }),
    );
    expect(realtime.cocinaActualizada).toHaveBeenCalledWith(
      'cocina-2',
      expect.objectContaining({
        tarea_combo_id: 'tarea-1',
        item_id: 'linea-combo-1',
      }),
    );
  });

  it('no permite cerrar un componente como no disponible por el flujo normal', async () => {
    const { database, service } = construir();

    await expect(
      service.cambiarEstadoTareaCombo(
        'tarea-1',
        'sucursal-1',
        'no_disponible',
        'usuario-1',
      ),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(database.enTransaccion).not.toHaveBeenCalled();
  });

  it('pausa tareas hermanas y persiste una sola decisión del cliente', async () => {
    const client = {
      query: jest
        .fn()
        .mockResolvedValueOnce({
          rows: [
            {
              tarea_id: 'tarea-1',
              pedido_item_id: 'linea-combo-1',
              pedido_id: 'pedido-1',
              numero_pedido: 'P-001',
              cocina_id: 'cocina-1',
              estado_tarea: 'pendiente',
              estado_linea: 'preparando',
              tipo_item: 'producto',
              componente_id: 'producto-faltante',
              nombre_snapshot: 'Papas',
              cantidad: '1',
              precio_unitario_snapshot: '4000',
              costo_unitario_snapshot: '1800',
              producto_padre_id: null,
              producto_padre_nombre_snapshot: null,
              componente_indice: 1,
              estado_pedido: 'en_cocina',
              total: '25000',
              monto_pagado: '0',
            },
          ],
        })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ id: 'decision-1' }] })
        .mockResolvedValueOnce({ rows: [{ estado: 'preparando' }] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({
          rows: [{ cocina_id: 'cocina-1' }, { cocina_id: 'cocina-2' }],
        }),
    };
    const database = {
      enTransaccion: jest.fn(async (callback: (tx: PoolClient) => unknown) =>
        callback(client as unknown as PoolClient),
      ),
    };
    const realtime = {
      cocinaActualizada: jest.fn().mockResolvedValue(undefined),
      pedidoActualizado: jest.fn().mockResolvedValue(undefined),
    };
    const service = new CocinasService(
      database as never,
      realtime as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    await expect(
      service.marcarTareaComboNoDisponible(
        'tarea-1',
        'sucursal-1',
        'usuario-1',
        'Se agotaron las papas',
      ),
    ).resolves.toMatchObject({
      decision_id: 'decision-1',
      estado_linea: 'preparando',
      idempotente: false,
    });

    expect(client.query.mock.calls[2][0]).toContain(
      "'pausada_decision_cliente'",
    );
    expect(client.query.mock.calls[3][0]).toContain(
      'INSERT INTO pedido_combo_decisiones_cliente',
    );
    expect(client.query.mock.calls[3][0]).toContain(
      "'precio_unitario', $9::numeric",
    );
    expect(client.query.mock.calls[5][0]).toContain(
      'UPDATE pedido_items SET estado_cocina',
    );
    expect(realtime.cocinaActualizada).toHaveBeenCalledTimes(2);
    expect(realtime.pedidoActualizado).toHaveBeenCalledWith(
      expect.objectContaining({
        pedido_id: 'pedido-1',
        numero_pedido: 'P-001',
        estado: 'en_cocina',
      }),
    );
  });

  it('no permite abrir dos decisiones pendientes para el mismo combo', async () => {
    const client = {
      query: jest
        .fn()
        .mockResolvedValueOnce({
          rows: [
            {
              tarea_id: 'tarea-2',
              pedido_item_id: 'linea-combo-1',
              pedido_id: 'pedido-1',
              cocina_id: 'cocina-2',
              estado_tarea: 'pendiente',
              estado_linea: 'preparando',
              estado_pedido: 'en_cocina',
              total: '25000',
              monto_pagado: '0',
            },
          ],
        })
        .mockResolvedValueOnce({
          rows: [{ id: 'decision-1', tarea_no_disponible_id: 'tarea-1' }],
        }),
    };
    const database = {
      enTransaccion: jest.fn(async (callback: (tx: PoolClient) => unknown) =>
        callback(client as unknown as PoolClient),
      ),
    };
    const service = new CocinasService(
      database as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    await expect(
      service.marcarTareaComboNoDisponible(
        'tarea-2',
        'sucursal-1',
        'usuario-2',
        'Se agotó',
      ),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(client.query).toHaveBeenCalledTimes(2);
  });
});
