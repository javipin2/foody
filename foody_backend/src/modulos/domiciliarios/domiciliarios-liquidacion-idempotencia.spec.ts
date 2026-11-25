import { BadRequestException } from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { DomiciliariosService } from './domiciliarios.service';

describe('Liquidación domiciliario de planta', () => {
  it('conserva el primer método real del pedido y limita el update por sucursal', async () => {
    const client = {
      query: jest
        .fn()
        .mockResolvedValueOnce({
          rows: [{ id: 'cxc-1', pedido_id: 'pedido-1', monto: '6000' }],
        })
        .mockResolvedValue({ rows: [] }),
    };
    const database = {
      enTransaccion: jest.fn((fn: (tx: PoolClient) => Promise<unknown>) =>
        fn(client as unknown as PoolClient),
      ),
    };
    const cajaAuditoria = { registrarVentaEnCaja: jest.fn() };
    const service = new DomiciliariosService(
      database as unknown as DatabaseService,
      {} as never,
      {} as never,
      cajaAuditoria as never,
      {} as never,
      {} as never,
      {} as never,
    );

    await service.liquidarDomiciliario('sucursal-qa', 'domi-qa', 'usuario-qa');

    const updatePedido = client.query.mock.calls.find(([sql]) =>
      String(sql).includes('UPDATE pedidos'),
    );
    expect(updatePedido?.[0]).toMatch(/pp\.sucursal_id = pedidos\.sucursal_id/i);
    expect(updatePedido?.[0]).toMatch(/ORDER BY pp\.created_at ASC, pp\.id ASC/i);
    expect(updatePedido?.[1]).toEqual(['pedido-1', 'sucursal-qa']);
    expect(cajaAuditoria.registrarVentaEnCaja).toHaveBeenCalledWith(
      expect.anything(),
      'sucursal-qa',
      'pedido-1',
      6000,
      'efectivo',
      expect.objectContaining({ exigirCaja: true }),
    );
  });

  it('rechaza reintentos cuando ya no hay CxC pendientes y no duplica el recaudo', async () => {
    const client = {
      query: jest.fn().mockResolvedValue({ rows: [] }),
    };
    const database = {
      enTransaccion: jest.fn((fn: (tx: PoolClient) => Promise<unknown>) =>
        fn(client as unknown as PoolClient),
      ),
    };
    const cajaAuditoria = { registrarVentaEnCaja: jest.fn() };
    const service = new DomiciliariosService(
      database as unknown as DatabaseService,
      {} as never,
      {} as never,
      cajaAuditoria as never,
      {} as never,
      {} as never,
      {} as never,
    );

    for (let intento = 0; intento < 2; intento++) {
      const error = await service
        .liquidarDomiciliario('sucursal-qa', 'domi-qa', 'usuario-qa')
        .catch((e: unknown) => e);
      expect(error).toBeInstanceOf(BadRequestException);
      expect((error as BadRequestException).getResponse()).toMatchObject({
        error: 'SIN_CUENTAS_PENDIENTES',
      });
    }

    expect(client.query).toHaveBeenCalledTimes(2);
    expect(client.query.mock.calls[0]?.[0]).toMatch(/estado\s*=\s*'pendiente'[\s\S]*FOR UPDATE/i);
    expect(client.query.mock.calls[1]?.[0]).toMatch(/estado\s*=\s*'pendiente'[\s\S]*FOR UPDATE/i);
    expect(cajaAuditoria.registrarVentaEnCaja).not.toHaveBeenCalled();
  });
});
