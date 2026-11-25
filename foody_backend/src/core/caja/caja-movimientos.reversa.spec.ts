import { PoolClient } from 'pg';
import { CajaMovimientosService } from './caja-movimientos.service';

describe('CajaMovimientosService.revertirVentasPedido', () => {
  const reversar = async (
    saldos: Array<{ caja_id: string; metodo_pago: string; neto: string }>,
  ) => {
    const inserts: unknown[][] = [];
    const query = jest.fn(async (sql: string, values?: unknown[]) => {
      if (sql.includes('GROUP BY caja_id')) return { rows: saldos };
      if (sql.includes('INSERT INTO movimientos_caja'))
        inserts.push(values ?? []);
      return { rows: [], rowCount: 1 };
    });
    const client = { query } as unknown as PoolClient;
    const result = await new CajaMovimientosService().revertirVentasPedido(
      client,
      'pedido-1',
      'sucursal-1',
      'usuario-1',
      'Cancelación QA',
    );
    return { result, inserts };
  };

  it('revierte cada medio y cada caja de origen del pedido', async () => {
    const { result, inserts } = await reversar([
      { caja_id: 'caja-a', metodo_pago: 'efectivo', neto: '40.00' },
      { caja_id: 'caja-b', metodo_pago: 'tarjeta', neto: '60.00' },
    ]);

    expect(result).toEqual({ movimientos: 2, monto_total: 100 });
    expect(inserts.map((fila) => [fila[0], fila[3], fila[4], fila[5]])).toEqual(
      [
        ['caja-a', 'devolucion', 40, 'efectivo'],
        ['caja-b', 'devolucion', 60, 'tarjeta'],
      ],
    );
  });

  it('resta reembolsos previos y conserva exactamente el saldo neto', async () => {
    const { result, inserts } = await reversar([
      { caja_id: 'caja-a', metodo_pago: 'efectivo', neto: '30.00' },
      { caja_id: 'caja-a', metodo_pago: 'tarjeta', neto: '60.00' },
    ]);

    expect(result).toEqual({ movimientos: 2, monto_total: 90 });
    expect(inserts.map((fila) => [fila[4], fila[5]])).toEqual([
      [30, 'efectivo'],
      [60, 'tarjeta'],
    ]);
  });

  it('no registra reversa si el pedido ya no tiene saldo cobrado', async () => {
    const { result, inserts } = await reversar([
      { caja_id: 'caja-a', metodo_pago: 'efectivo', neto: '0.00' },
    ]);

    expect(result).toEqual({ movimientos: 0, monto_total: 0 });
    expect(inserts).toHaveLength(0);
  });
});
