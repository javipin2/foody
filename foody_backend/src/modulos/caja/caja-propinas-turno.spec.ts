import { CajaService } from './caja.service';

describe('CajaService cerrar — propinas atribuidas al turno de pago', () => {
  it('suma propinas de pagos recibidos desde la apertura y no altera el cuadre', async () => {
    const queries: string[] = [];
    const query = jest.fn(async (sql: string) => {
      queries.push(sql);
      if (sql.includes('FROM cajas') && sql.includes('FOR UPDATE')) {
        return {
          rows: [
            {
              id: 'caja-1',
              sucursal_id: 'sucursal-1',
              estado: 'abierta',
              monto_inicial: '50000',
            },
          ],
        };
      }
      if (sql.includes('COUNT(*)')) return { rows: [{ n: '0' }] };
      if (sql.includes('FROM movimientos_caja')) {
        return { rows: [{ total: '50000' }] };
      }
      if (sql.includes('FROM pagos_pedido')) {
        return { rows: [{ total: '12000' }] };
      }
      return { rows: [] };
    });
    const client = { query };
    const database = {
      enTransaccion: jest.fn((callback: (tx: typeof client) => unknown) =>
        callback(client),
      ),
    };
    const service = new CajaService(
      database as never,
      { registrarEnTransaccion: jest.fn() } as never,
      { cajaMovimiento: jest.fn() } as never,
      { expirarQrPendientesAlCierreEnTransaccion: jest.fn() } as never,
      {} as never,
      { registrarEnTransaccion: jest.fn() } as never,
      { resolverEscritura: jest.fn() } as never,
    );

    const result = await service.cerrar(
      { caja_id: 'caja-1', monto_final_contado: 50000 },
      { sub: 'usuario-1' } as never,
    );

    const propinasSql = queries.find((sql) =>
      sql.includes('FROM pagos_pedido'),
    );
    expect(propinasSql).toContain('SUM(pp.propina)');
    expect(propinasSql).toContain('pp.created_at >= c.apertura_at');
    expect(propinasSql).toContain('pp.created_at <= NOW()');
    expect(result.propinas_turno).toBe(12000);
    expect(result.monto_final_sistema).toBe(50000);
    expect(result.diferencia).toBe(0);

    const saldoSql = queries.find((sql) =>
      sql.includes('FROM movimientos_caja'),
    );
    expect(saldoSql).toContain("tipo = 'apertura' THEN monto");
    expect(saldoSql).toContain("metodo_pago = 'efectivo' THEN monto");
    expect(saldoSql).toContain(
      "tipo = 'devolucion' AND metodo_pago = 'efectivo'",
    );
    expect(saldoSql).toContain("tipo IN ('retiro', 'gasto') THEN -monto");
    expect(saldoSql).not.toContain(
      "tipo IN ('retiro', 'gasto', 'devolucion') THEN -monto",
    );
  });
});
