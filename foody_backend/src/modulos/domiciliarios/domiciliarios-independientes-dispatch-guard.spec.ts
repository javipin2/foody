import { BadRequestException } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { DomiciliariosIndependientesService } from './domiciliarios-independientes.service';
import { DispatchService } from './dispatch.service';

describe('aceptación de oferta independiente', () => {
  it('cancela ofertas activas hermanas al confirmar una asignación', async () => {
    const queries: Array<{ sql: string; params: unknown[] }> = [];
    const query = jest.fn(async (sql: string, params: unknown[] = []) => {
      queries.push({ sql, params });
      if (sql.includes('FROM ofertas_pedido WHERE id = $1 FOR UPDATE')) {
        return {
          rows: [
            {
              id: 'oferta-1',
              pedido_id: 'pedido-1',
              sucursal_id: 'sucursal-1',
              estado: 'activa',
              expira_at: new Date(Date.now() + 60_000),
            },
          ],
        };
      }
      if (
        sql.includes('FROM respuestas_oferta') &&
        sql.includes('FOR UPDATE')
      ) {
        return { rows: [{ id: 'respuesta-1', respuesta: 'no_vio' }] };
      }
      if (sql.includes('FROM pedidos') && sql.includes('FOR UPDATE')) {
        return {
          rows: [{ id: 'pedido-1', estado: 'listo', costo_domicilio: '5000' }],
        };
      }
      if (sql.includes('INSERT INTO asignaciones_domicilio')) {
        return { rows: [{ id: 'asignacion-1' }] };
      }
      return { rows: [] };
    });
    const client = { query };
    const database = {
      enTransaccion: (fn: (tx: never) => unknown) => fn(client as never),
    };
    const dispatch = {
      validarPedidoParaDespacho: jest.fn().mockResolvedValue({ valido: true }),
      calcularGanancias: jest
        .fn()
        .mockReturnValue({ comision: 750, ganancia: 4250 }),
    };
    const service = new DomiciliariosIndependientesService(
      database as unknown as DatabaseService,
      dispatch as unknown as DispatchService,
      {} as never,
      {} as never,
      {} as never,
      { aplicarEstadoEnTransaccion: jest.fn() } as never,
      {} as never,
    );

    const resultado = await service.responderOferta('oferta-1', 'dom-1', {
      respuesta: 'aceptada',
    } as never);

    expect(resultado).toMatchObject({
      respuesta: 'aceptada',
      pedido_id: 'pedido-1',
    });
    const cancelarHermanas = queries.find(({ sql }) =>
      sql.includes('WITH canceladas AS'),
    );
    expect(cancelarHermanas?.params).toEqual(['pedido-1', 'oferta-1']);
    expect(
      queries.some(({ sql }) =>
        sql.includes('SET total_entregas = total_entregas + 1'),
      ),
    ).toBe(false);
  });

  it('cuenta la entrega independiente solo al confirmarla', async () => {
    const queries: Array<{ sql: string; params: unknown[] }> = [];
    const query = jest.fn(async (sql: string, params: unknown[] = []) => {
      queries.push({ sql, params });
      if (
        sql.includes('FROM asignaciones_domicilio') &&
        sql.includes("estado = 'en_camino' FOR UPDATE")
      ) {
        return { rows: [{ id: 'asignacion-1' }] };
      }
      if (sql.includes('FROM pedidos WHERE id = $1 FOR UPDATE')) {
        return {
          rows: [
            {
              sucursal_id: 'sucursal-1',
              numero_pedido: 'D-001',
              total: '5000',
              costo_domicilio: '0',
              monto_pagado: '5000',
              metodo_pago: 'efectivo',
            },
          ],
        };
      }
      if (sql.includes('FROM sucursales WHERE id = $1')) {
        return { rows: [{ domicilio_ingresa_a_caja: false }] };
      }
      return { rows: [] };
    });
    const client = { query };
    const database = {
      enTransaccion: jest.fn((fn: (tx: never) => unknown) =>
        fn(client as never),
      ),
    };
    const pedidosEstadoCommand = { aplicarEstadoEnTransaccion: jest.fn() };
    const service = new DomiciliariosIndependientesService(
      database as unknown as DatabaseService,
      {} as never,
      { evaluarDemoraEntrega: jest.fn() } as never,
      { pedidoActualizado: jest.fn(), cajaMovimiento: jest.fn() } as never,
      {} as never,
      pedidosEstadoCommand as never,
      {} as never,
    );

    await expect(
      service.confirmarEntrega('pedido-1', 'dom-1'),
    ).resolves.toMatchObject({ pedido_id: 'pedido-1', estado: 'entregado' });

    const contador = queries.find(({ sql }) =>
      sql.includes('SET total_entregas = total_entregas + 1'),
    );
    expect(contador?.params).toEqual(['dom-1']);
    expect(pedidosEstadoCommand.aplicarEstadoEnTransaccion).toHaveBeenCalled();
  });

  it('no lista ofertas de pedidos ya asignados o que dejaron de estar listos', async () => {
    let consulta = '';
    const database = {
      consultar: jest.fn(async (sql: string) => {
        consulta = sql;
        return [];
      }),
    };
    const dispatch = {
      calcularGanancias: jest.fn(),
    };
    const service = new DomiciliariosIndependientesService(
      database as unknown as DatabaseService,
      dispatch as unknown as DispatchService,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    await service.ofertasActivas('dom-1');

    expect(consulta).toContain("p.estado = 'listo'");
    expect(consulta).toContain("ad.estado IN ('asignado', 'en_camino')");
  });

  it('no asigna una oferta si el pedido tiene productos no disponibles', async () => {
    const query = jest
      .fn()
      .mockResolvedValueOnce({
        rows: [
          {
            id: 'oferta-1',
            pedido_id: 'pedido-1',
            sucursal_id: 'sucursal-1',
            estado: 'activa',
            expira_at: new Date(Date.now() + 60_000),
          },
        ],
      })
      .mockResolvedValueOnce({
        rows: [{ id: 'respuesta-1', respuesta: 'no_vio' }],
      })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({
        rows: [{ id: 'pedido-1', estado: 'listo', costo_domicilio: '5000' }],
      });
    const client = { query };
    const database = {
      enTransaccion: jest.fn((fn: (tx: never) => unknown) =>
        fn(client as never),
      ),
    };
    const dispatch = {
      validarPedidoParaDespacho: jest.fn().mockResolvedValue({
        valido: false,
        motivo: 'PEDIDO_ITEMS_NO_DISPONIBLES',
        mensaje: 'Revisa los productos antes del despacho.',
      }),
    };
    const service = new DomiciliariosIndependientesService(
      database as unknown as DatabaseService,
      dispatch as unknown as DispatchService,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );
    await expect(
      service.responderOferta('oferta-1', 'dom-1', {
        respuesta: 'aceptada',
      } as never),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(dispatch.validarPedidoParaDespacho).toHaveBeenCalledWith(
      'pedido-1',
      'sucursal-1',
      client,
    );
    expect(query).toHaveBeenCalledTimes(4);
  });
});
