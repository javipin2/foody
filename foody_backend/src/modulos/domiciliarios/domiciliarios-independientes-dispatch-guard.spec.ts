import { BadRequestException } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { DomiciliariosIndependientesService } from './domiciliarios-independientes.service';
import { DispatchService } from './dispatch.service';

describe('aceptación de oferta independiente', () => {
  it.each(['asignado', 'en_camino'])(
    'bloquea el cierre de sesión con asignación %s',
    async (estado) => {
      const queries: string[] = [];
      const query = jest.fn(async (sql: string) => {
        queries.push(sql);
        if (sql.includes('FROM domiciliarios_independientes')) {
          return { rows: [{ id: 'dom-1' }] };
        }
        if (sql.includes('FROM asignaciones_domicilio')) {
          return { rows: [{ id: 'asignacion-1', estado }] };
        }
        return { rows: [] };
      });
      const client = { query };
      const database = {
        enTransaccion: jest.fn((fn: (tx: never) => unknown) =>
          fn(client as never),
        ),
      };
      const service = new DomiciliariosIndependientesService(
        database as unknown as DatabaseService,
        {} as never,
        {} as never,
        {} as never,
        {} as never,
        {} as never,
        {} as never,
      );

      await expect(service.cerrarSesion('dom-1')).rejects.toThrow(
        'Completa o cancela la entrega activa antes de cerrar tu turno',
      );
      expect(
        queries.some((sql) => sql.includes('UPDATE domiciliarios_sesiones')),
      ).toBe(false);
      expect(database.enTransaccion).toHaveBeenCalledTimes(1);
    },
  );

  it('cierra el turno sin entregas activas', async () => {
    const queries: string[] = [];
    const query = jest.fn(async (sql: string) => {
      queries.push(sql);
      if (sql.includes('FROM domiciliarios_independientes')) {
        return { rows: [{ id: 'dom-1' }] };
      }
      return { rows: [] };
    });
    const client = { query };
    const database = {
      enTransaccion: jest.fn((fn: (tx: never) => unknown) =>
        fn(client as never),
      ),
    };
    const service = new DomiciliariosIndependientesService(
      database as unknown as DatabaseService,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    await expect(service.cerrarSesion('dom-1')).resolves.toEqual({ ok: true });
    expect(
      queries.some((sql) => sql.includes('UPDATE domiciliarios_sesiones')),
    ).toBe(true);
  });

  it('cancela ofertas activas hermanas al confirmar una asignación', async () => {
    const queries: Array<{ sql: string; params: unknown[] }> = [];
    const query = jest.fn(async (sql: string, params: unknown[] = []) => {
      queries.push({ sql, params });
      if (
        sql.includes('FROM ofertas_pedido') &&
        sql.includes('WHERE id = $1')
      ) {
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
      if (sql.includes('FROM domiciliarios_independientes')) {
        return { rows: [{ id: 'dom-1' }] };
      }
      if (sql.includes('FROM domiciliarios_sesiones')) {
        return { rows: [{ id: 'sesion-1' }] };
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
    const bloqueoSesion = queries.find(
      ({ sql }) =>
        sql.includes('FROM domiciliarios_independientes') &&
        sql.includes('FOR UPDATE'),
    );
    expect(bloqueoSesion).toBeDefined();
    expect(
      queries.some(({ sql }) =>
        sql.includes('SET total_entregas = total_entregas + 1'),
      ),
    ).toBe(false);
  });

  it('no acepta una oferta si la sesión ya no está disponible', async () => {
    const query = jest.fn(async (sql: string) => {
      if (
        sql.includes('FROM ofertas_pedido') &&
        sql.includes('WHERE id = $1')
      ) {
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
      if (sql.includes('FROM respuestas_oferta')) {
        return { rows: [{ id: 'respuesta-1', respuesta: 'no_vio' }] };
      }
      if (sql.includes('FROM pedidos') && sql.includes('FOR UPDATE')) {
        return {
          rows: [{ id: 'pedido-1', estado: 'listo', costo_domicilio: '5000' }],
        };
      }
      if (sql.includes('FROM domiciliarios_independientes')) {
        return { rows: [{ id: 'dom-1' }] };
      }
      if (sql.includes('FROM domiciliarios_sesiones')) return { rows: [] };
      return { rows: [] };
    });
    const client = { query };
    const database = {
      enTransaccion: (fn: (tx: never) => unknown) => fn(client as never),
    };
    const service = new DomiciliariosIndependientesService(
      database as unknown as DatabaseService,
      {} as never,
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
    ).rejects.toThrow('Activa tu disponibilidad antes de aceptar otro pedido');
    expect(
      query.mock.calls.some(([sql]) =>
        sql.includes('INSERT INTO asignaciones_domicilio'),
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

  it('separa el saldo de productos y domicilio al cobrar contraentrega', async () => {
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
              numero_pedido: 'D-002',
              total: '10500',
              costo_domicilio: '2500',
              monto_pagado: '2000',
              metodo_pago: null,
            },
          ],
        };
      }
      if (sql.includes('FROM sucursales WHERE id = $1')) {
        return { rows: [{ domicilio_ingresa_a_caja: true }] };
      }
      return { rows: [] };
    });
    const client = { query };
    const database = {
      enTransaccion: jest.fn((fn: (tx: never) => unknown) =>
        fn(client as never),
      ),
    };
    const registrarVentaEnCaja = jest.fn();
    const service = new DomiciliariosIndependientesService(
      database as unknown as DatabaseService,
      {} as never,
      { evaluarDemoraEntrega: jest.fn() } as never,
      { pedidoActualizado: jest.fn(), cajaMovimiento: jest.fn() } as never,
      { registrarVentaEnCaja } as never,
      { aplicarEstadoEnTransaccion: jest.fn() } as never,
      {} as never,
    );

    await expect(
      service.confirmarEntrega('pedido-1', 'dom-1', {
        metodo_pago: 'efectivo',
        metodo_pago_domicilio: 'transferencia',
      } as never),
    ).resolves.toMatchObject({ pedido_id: 'pedido-1', estado: 'entregado' });

    const pagos = queries.filter(({ sql }) =>
      sql.includes('INSERT INTO pagos_pedido'),
    );
    expect(pagos.map(({ params }) => params)).toEqual([
      [
        'sucursal-1',
        'pedido-1',
        6000,
        'efectivo',
        'Cobro producto contra entrega (independiente)',
      ],
      [
        'sucursal-1',
        'pedido-1',
        2500,
        'transferencia',
        'Cobro domicilio contra entrega (independiente)',
      ],
    ]);
    expect(registrarVentaEnCaja.mock.calls.map((call) => call[3])).toEqual([
      6000, 2500,
    ]);
    expect(
      queries.find(({ sql }) => sql.includes('SET monto_pagado = $2'))?.params,
    ).toEqual(['pedido-1', 10500, 'efectivo']);
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
          { id: 'oferta-1', pedido_id: 'pedido-1', sucursal_id: 'sucursal-1' },
        ],
      })
      .mockResolvedValueOnce({
        rows: [{ id: 'pedido-1', estado: 'listo', costo_domicilio: '5000' }],
      })
      .mockResolvedValueOnce({
        rows: [
          {
            id: 'oferta-1',
            estado: 'activa',
            expira_at: new Date(Date.now() + 60_000),
          },
        ],
      })
      .mockResolvedValueOnce({
        rows: [{ id: 'respuesta-1', respuesta: 'no_vio' }],
      })
      .mockResolvedValueOnce({ rows: [{ id: 'dom-1' }] })
      .mockResolvedValueOnce({ rows: [{ id: 'sesion-1' }] })
      .mockResolvedValueOnce({ rows: [] });
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
    expect(query).toHaveBeenCalledTimes(7);
    const sqls = query.mock.calls.map(([sql]) => sql);
    expect(
      sqls.findIndex(
        (sql) => sql.includes('FROM pedidos') && sql.includes('FOR UPDATE'),
      ),
    ).toBeLessThan(
      sqls.findIndex(
        (sql) =>
          sql.includes('FROM ofertas_pedido') && sql.includes('FOR UPDATE'),
      ),
    );
  });
});
