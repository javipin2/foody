import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CrearPedidoDto } from './crear-pedido.dto';

const base = {
  sucursal_id: '8c80be2a-c0d9-4f53-87f5-aac8b207d1da',
  device_id: 'audit-device',
  tipo: 'domicilio',
  cliente_telefono: '3000000000',
  items: [
    {
      producto_id: 'c3a39ebf-35ae-4bb9-9ec3-f7f13172c0a9',
      cantidad: 1,
      precio: 12000,
    },
  ],
};

describe('CrearPedidoDto delivery address', () => {
  async function errors(input: Record<string, unknown>) {
    return validate(plainToInstance(CrearPedidoDto, input));
  }

  it('requires an address for delivery orders', async () => {
    const result = await errors(base);
    expect(result.map((error) => error.property)).toContain(
      'direccion_entrega',
    );
  });

  it('accepts a manually entered address without coordinates', async () => {
    expect(
      await errors({ ...base, direccion_entrega: 'Calle 10 # 5-20' }),
    ).toHaveLength(0);
  });

  it('does not require an address for pickup', async () => {
    expect(await errors({ ...base, tipo: 'para_llevar' })).toHaveLength(0);
  });

  it('rejects a whitespace-only address', async () => {
    const result = await errors({ ...base, direccion_entrega: '   ' });
    expect(result.map((error) => error.property)).toContain(
      'direccion_entrega',
    );
  });
});

describe('CrearPedidoDto delivery contact', () => {
  async function errors(input: Record<string, unknown>) {
    return validate(plainToInstance(CrearPedidoDto, input));
  }

  it('requires a contact phone for delivery but keeps customer name optional', async () => {
    const result = await errors({
      ...base,
      direccion_entrega: 'Calle 10 # 5-20',
      cliente_telefono: undefined,
    });
    expect(result.map((error) => error.property)).toContain('cliente_telefono');
  });

  it('rejects blank and malformed delivery phone numbers', async () => {
    for (const phone of ['   ', '1234', 'abcdegh']) {
      const result = await errors({
        ...base,
        direccion_entrega: 'Calle 10 # 5-20',
        cliente_telefono: phone,
      });
      expect(result.map((error) => error.property)).toContain(
        'cliente_telefono',
      );
    }
  });

  it('accepts formatted international phone numbers for delivery', async () => {
    expect(
      await errors({
        ...base,
        cliente_telefono: '+57 (300) 123-4567',
        direccion_entrega: 'Calle 10 # 5-20',
      }),
    ).toHaveLength(0);
  });

  it('keeps customer phone optional for pickup orders', async () => {
    expect(
      await errors({
        ...base,
        tipo: 'para_llevar',
        cliente_telefono: undefined,
      }),
    ).toHaveLength(0);
  });
});
