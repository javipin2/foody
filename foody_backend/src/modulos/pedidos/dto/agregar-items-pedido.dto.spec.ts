import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { AgregarItemsPedidoDto } from './agregar-items-pedido.dto';

describe('AgregarItemsPedidoDto idempotency key', () => {
  it('accepts an optional key within the limit', async () => {
    const dto = plainToInstance(AgregarItemsPedidoDto, {
      idempotency_key: '8e60335c-cc34-49fa-a469-76822d35fb56',
      items: [],
    });
    expect(await validate(dto)).toHaveLength(0);
  });

  it('rejects a non-string or oversized key', async () => {
    for (const key of [4, 'x'.repeat(201)]) {
      const dto = plainToInstance(AgregarItemsPedidoDto, {
        idempotency_key: key,
      });
      expect((await validate(dto)).map((error) => error.property)).toContain(
        'idempotency_key',
      );
    }
  });
});
