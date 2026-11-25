import { BadRequestException } from '@nestjs/common';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { PedidosCrearService } from './pedidos-crear.service';

describe('PedidosCrearService — pedido de mesa sin mesa', () => {
  const database = { consultarUno: jest.fn(), enTransaccion: jest.fn() };
  const service = new PedidosCrearService(
    database as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
  );

  const dto = {
    sucursal_id: '8c80be2a-c0d9-4f53-87f5-aac8b207d1da',
    device_id: 'qa-qr-sin-mesa',
    tipo: 'mesa',
    items: [
      {
        producto_id: 'c3a39ebf-35ae-4bb9-9ec3-f7f13172c0a9',
        cantidad: 1,
        precio: 8000,
      },
    ],
  } as CrearPedidoDto;

  beforeEach(() => {
    database.consultarUno.mockClear();
    database.enTransaccion.mockReset();
  });

  it('permite cotizar un encargo antes de elegir la fecha', async () => {
    database.enTransaccion.mockResolvedValue({ total: 8000 });
    await expect(
      service.crear(
        {
          ...dto,
          tipo: 'encargo',
          fecha_entrega_deseada: undefined,
        },
        { soloEstimar: true },
      ),
    ).resolves.toEqual({ total: 8000 });
  });

  it('exige fecha al crear el encargo, incluso si viene sin fecha', async () => {
    await expect(
      service.crear({
        ...dto,
        tipo: 'encargo',
        fecha_entrega_deseada: undefined,
      }),
    ).rejects.toMatchObject({
      response: { error: 'FECHA_ENCARGO_REQUERIDA' },
    });
    expect(database.enTransaccion).not.toHaveBeenCalled();
  });

  it.each([
    ['pedido público', {}],
    ['pedido de personal', { creadoPorStaff: true, usuarioId: 'staff' }],
    ['estimación del total', { soloEstimar: true }],
  ])('rechaza %s sin ejecutar consultas', async (_flujo, opciones) => {
    try {
      await service.crear(dto, opciones);
      throw new Error('Se esperaba rechazar el pedido de mesa sin mesa_id');
    } catch (error) {
      expect(error).toBeInstanceOf(BadRequestException);
      expect((error as BadRequestException).getResponse()).toMatchObject({
        error: 'MESA_REQUERIDA',
      });
    }

    expect(database.consultarUno).not.toHaveBeenCalled();
  });
});
