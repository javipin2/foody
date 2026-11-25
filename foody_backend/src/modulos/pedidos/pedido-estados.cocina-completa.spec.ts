import { pedidoCocinaCompleta } from './pedido-estados';

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
