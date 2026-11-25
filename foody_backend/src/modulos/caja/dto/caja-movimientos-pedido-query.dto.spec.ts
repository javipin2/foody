import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CajaMovimientosPedidoQueryDto } from './caja-movimientos-pedido-query.dto';

describe('CajaMovimientosPedidoQueryDto', () => {
  it('acepta sede UUID con paginación y transforma page/limit', async () => {
    const dto = plainToInstance(CajaMovimientosPedidoQueryDto, {
      page: '2',
      limit: '20',
      sucursal_id: 'c0000000-0000-4000-8000-000000000001',
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
    expect(dto.page).toBe(2);
    expect(dto.limit).toBe(20);
  });

  it('rechaza una sede que no tenga formato UUID', async () => {
    const dto = plainToInstance(CajaMovimientosPedidoQueryDto, {
      sucursal_id: 'sucursal-1',
    });

    const errores = await validate(dto);
    expect(errores.map((error) => error.property)).toContain('sucursal_id');
  });
});
