import { NotFoundException } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { CajaService } from './caja.service';

describe('CajaService.listarMovimientosPedido', () => {
  const database = {
    consultarUno: jest.fn(),
    consultar: jest.fn(),
  };
  const service = new CajaService(
    database as unknown as DatabaseService,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
  );

  beforeEach(() => jest.clearAllMocks());

  it('lista movimientos paginados y acotados a la sucursal del usuario', async () => {
    database.consultarUno
      .mockResolvedValueOnce({ id: 'pedido-1' })
      .mockResolvedValueOnce({ count: 1 });
    database.consultar.mockResolvedValueOnce([
      { id: 'mov-1', pedido_id: 'pedido-1', caja_estado: 'cerrada' },
    ]);

    const result = await service.listarMovimientosPedido(
      'pedido-1',
      'sucursal-1',
      2,
      10,
    );

    expect(database.consultarUno).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining('WHERE id = $1 AND sucursal_id = $2'),
      ['pedido-1', 'sucursal-1'],
    );
    expect(database.consultar).toHaveBeenCalledWith(
      expect.stringContaining('m.pedido_id = $1 AND m.sucursal_id = $2'),
      ['pedido-1', 'sucursal-1', 10, 10],
    );
    expect(result).toEqual({
      items: [{ id: 'mov-1', pedido_id: 'pedido-1', caja_estado: 'cerrada' }],
      total: 1,
      page: 2,
      limit: 10,
      totalPages: 1,
    });
  });

  it('no revela movimientos ni existencia de pedidos de otra sucursal', async () => {
    database.consultarUno.mockResolvedValueOnce(null);

    await expect(
      service.listarMovimientosPedido('pedido-ajeno', 'sucursal-1'),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(database.consultar).not.toHaveBeenCalled();
  });
});
