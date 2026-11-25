import { DatabaseService } from '../../core/database/database.service';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';

describe('PedidosCuentaMesaService', () => {
  it('libera todos los miembros de una mesa agrupada al cerrar su último pedido', async () => {
    const client = {
      query: jest
        .fn()
        .mockResolvedValueOnce({ rows: [{ mesa_grupo_id: null }] })
        .mockResolvedValueOnce({
          rows: [{ id: 'mesa-principal' }, { id: 'mesa-secundaria' }],
        })
        .mockResolvedValueOnce({ rows: [{ n: 0 }] })
        .mockResolvedValueOnce({ rows: [] }),
    };
    const service = new PedidosCuentaMesaService({} as DatabaseService);

    await service.liberarMesaSiSinPedidosActivos(
      client as never,
      'mesa-principal',
      'sucursal-1',
    );

    expect(client.query.mock.calls[1][0]).toContain('ORDER BY id FOR UPDATE');
    expect(client.query.mock.calls[2][0]).toContain(
      'mesa_id = ANY($1::uuid[])',
    );
    expect(client.query.mock.calls[2][1]).toEqual([
      ['mesa-principal', 'mesa-secundaria'],
      'sucursal-1',
    ]);
    expect(client.query.mock.calls[3][0]).toContain(
      "estado_operativo IN ('ocupada', 'pagando')",
    );
    expect(client.query.mock.calls[3][1]).toEqual([
      ['mesa-principal', 'mesa-secundaria'],
      'sucursal-1',
    ]);
  });

  it('mantiene ocupado el grupo si aún hay un pedido activo en otro miembro', async () => {
    const client = {
      query: jest
        .fn()
        .mockResolvedValueOnce({ rows: [{ mesa_grupo_id: null }] })
        .mockResolvedValueOnce({
          rows: [{ id: 'mesa-principal' }, { id: 'mesa-secundaria' }],
        })
        .mockResolvedValueOnce({ rows: [{ n: 1 }] }),
    };
    const service = new PedidosCuentaMesaService({} as DatabaseService);

    await service.liberarMesaSiSinPedidosActivos(
      client as never,
      'mesa-principal',
      'sucursal-1',
    );

    expect(client.query).toHaveBeenCalledTimes(3);
  });

  it('lista cuenta y abonos del grupo al consultar una mesa secundaria', async () => {
    const consultar = jest
      .fn()
      .mockResolvedValueOnce([
        { id: 'mesa-principal', nombre: 'Mesa 1' },
        { id: 'mesa-secundaria', nombre: 'Mesa 2' },
      ])
      .mockResolvedValueOnce([
        {
          id: 'pedido-1',
          numero_pedido: 'P-1',
          tipo: 'mesa',
          estado: 'pagando',
          total: '20000',
          monto_pagado: '5000',
          created_at: new Date('2026-01-01T12:00:00Z'),
          cliente_nombre: null,
          observaciones: null,
          mesera_id: null,
          mesera_nombre: null,
          items: [],
        },
      ])
      .mockResolvedValueOnce([
        {
          id: 'abono-1',
          monto: '5000',
          propina: '0',
          metodo_pago: 'efectivo',
          numero_pedido: 'P-1',
          created_at: new Date('2026-01-01T12:01:00Z'),
          referencia: null,
          responsable_nombre: 'Caja',
        },
      ]);
    const consultarUno = jest.fn().mockResolvedValue({
      id: 'mesa-secundaria',
      nombre: 'Mesa 2',
      mesa_grupo_id: 'mesa-principal',
    });
    const database = { consultar, consultarUno } as unknown as DatabaseService;
    const service = new PedidosCuentaMesaService(database);

    const cuenta = await service.listarActivosPorMesa(
      'sucursal-1',
      'mesa-secundaria',
    );

    expect(cuenta.total_acumulado).toBe(15000);
    expect(cuenta.cuenta.cantidad_tickets).toBe(1);
    expect(cuenta.pedidos).toHaveLength(1);
    expect(cuenta.pagos_abonos).toHaveLength(1);
    expect(cuenta.pagos_abonos[0].numero_pedido).toBe('P-1');
    expect(consultar.mock.calls[1][0]).toContain('p.mesa_id = ANY($2::uuid[])');
    expect(consultar.mock.calls[1][1]).toEqual([
      'sucursal-1',
      ['mesa-principal', 'mesa-secundaria'],
    ]);
    expect(consultar.mock.calls[2][0]).toContain(
      'pp.mesa_id = ANY($1::uuid[])',
    );
    expect(consultar.mock.calls[2][0]).toContain(
      'p.sucursal_id = pp.sucursal_id',
    );
    expect(consultar.mock.calls[2][1]).toEqual([
      ['mesa-principal', 'mesa-secundaria'],
      'sucursal-1',
    ]);
  });
});
