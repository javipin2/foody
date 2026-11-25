import { PoolClient } from 'pg';
import { PedidosSoporteService } from './pedidos-soporte.service';

describe('PedidosSoporteService.generarNumeroPedido', () => {
  it('bloquea la secuencia del tenant/año y limita el conteo al año Bogotá', async () => {
    const consultas: { sql: string; parametros?: unknown[] }[] = [];
    const client = {
      query: jest.fn(async (sql: string, parametros?: unknown[]) => {
        consultas.push({ sql, parametros });
        return { rows: sql.includes('COUNT(*)') ? [{ n: 41 }] : [{}] };
      }),
    } as unknown as PoolClient;
    const service = new PedidosSoporteService(
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );
    const anioBogota = Number(
      new Intl.DateTimeFormat('en', {
        timeZone: 'America/Bogota',
        year: 'numeric',
      }).format(new Date()),
    );

    const numero = await service.generarNumeroPedido(client, 'sucursal-qa');

    expect(numero).toBe(`FDY-${anioBogota}-0042`);
    expect(consultas).toHaveLength(2);
    expect(consultas[0].sql).toContain('pg_advisory_xact_lock');
    expect(consultas[0].parametros?.[0]).toBe(
      `foody:pedido-numero:sucursal-qa:${anioBogota}`,
    );
    expect(consultas[1].sql).toContain("'America/Bogota'");
    expect(consultas[1].sql).not.toContain('EXTRACT(YEAR');
  });
});
