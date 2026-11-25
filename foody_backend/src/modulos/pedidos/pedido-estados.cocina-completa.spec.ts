import {
  pedidoCocinaCompleta,
  puedeAvanzarCocinaPedidoPagado,
} from './pedido-estados';

describe('pedidoCocinaCompleta', () => {
  it('considera incompletos los estados nulos o desconocidos', async () => {
    const client = {
      query: jest.fn().mockResolvedValue({
        rows: [{ n: '2', incompletos: '1' }],
      }),
    };

    await expect(pedidoCocinaCompleta(client, 'pedido-1')).resolves.toBe(false);
    expect(client.query.mock.calls[0][0]).toContain('estado_cocina IS NULL');
  });

  it('acepta pedidos con todos sus ítems listos o no disponibles', async () => {
    const client = {
      query: jest.fn().mockResolvedValue({
        rows: [{ n: '2', incompletos: '0' }],
      }),
    };

    await expect(pedidoCocinaCompleta(client, 'pedido-1')).resolves.toBe(true);
  });

  it('no permite cerrar pedidos vacíos', async () => {
    const client = {
      query: jest.fn().mockResolvedValue({
        rows: [{ n: '0', incompletos: '0' }],
      }),
    };

    await expect(pedidoCocinaCompleta(client, 'pedido-1')).resolves.toBe(false);
  });
});

describe('puedeAvanzarCocinaPedidoPagado', () => {
  const base = {
    estadoPedido: 'pagado',
    total: 10000,
    montoPagado: 10000,
    estadoItem: 'preparando',
  };

  it.each(['preparando', 'listo', 'no_disponible'])(
    'permite avanzar una línea cobrada pendiente a %s',
    (nuevoEstadoItem) => {
      expect(puedeAvanzarCocinaPedidoPagado({ ...base, nuevoEstadoItem })).toBe(
        true,
      );
    },
  );

  it('no permite Cocina sobre pagos incompletos ni estados terminales', () => {
    expect(
      puedeAvanzarCocinaPedidoPagado({
        ...base,
        montoPagado: 9999,
        nuevoEstadoItem: 'listo',
      }),
    ).toBe(false);
    expect(
      puedeAvanzarCocinaPedidoPagado({
        ...base,
        estadoPedido: 'cancelado',
        nuevoEstadoItem: 'listo',
      }),
    ).toBe(false);
    expect(
      puedeAvanzarCocinaPedidoPagado({
        ...base,
        estadoItem: 'listo',
        nuevoEstadoItem: 'pendiente',
      }),
    ).toBe(false);
  });
});
