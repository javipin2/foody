import { BadRequestException } from '@nestjs/common';
import { PedidosEstadoService } from './pedidos-estado.service';
import { PedidosSoporteService } from './pedidos-soporte.service';

describe('PedidosEstadoService — cancelación de cliente con transición concurrente', () => {
  it('conserva el límite de dos minutos solo para el estado legacy confirmado', () => {
    const soporte = Object.create(
      PedidosSoporteService.prototype,
    ) as PedidosSoporteService;
    const creadoHaceDiezMinutos = new Date(Date.now() - 10 * 60 * 1000);

    expect(() =>
      soporte.validarCancelacionCliente(
        { estado: 'pendiente', created_at: creadoHaceDiezMinutos },
        'Cambio de opinión',
      ),
    ).not.toThrow();
    expect(() =>
      soporte.validarCancelacionCliente(
        { estado: 'confirmado', created_at: creadoHaceDiezMinutos },
        'Cambio de opinión',
      ),
    ).toThrow(BadRequestException);
  });

  it('vuelve a validar la regla del cliente sobre el estado bloqueado de la fila', async () => {
    const pedidoEnCocina = {
      id: 'pedido-1',
      sucursal_id: 'sucursal-1',
      estado: 'en_cocina',
      created_at: new Date(),
      tipo: 'domicilio',
      mesa_id: null,
      stock_descontado: true,
      total: '12000',
      costo_domicilio: '0',
      monto_pagado: '0',
      metodo_pago: 'pendiente',
      numero_pedido: 'F-1',
      mesera_id: null,
    };
    const client = { query: jest.fn() };
    const database = {
      consultarUno: jest.fn().mockResolvedValue({
        id: 'pedido-1',
        sucursal_id: 'sucursal-1',
        estado: 'pendiente',
        created_at: new Date(),
      }),
      enTransaccion: jest.fn((fn) => fn(client)),
    };
    const soporte = Object.create(
      PedidosSoporteService.prototype,
    ) as PedidosSoporteService;
    jest
      .spyOn(soporte, 'consultarUnoCliente')
      .mockResolvedValue(pedidoEnCocina as never);
    const service = new PedidosEstadoService(
      database as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      soporte,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    await expect(
      service.cancelarPorCliente('pedido-1', 'device-1', 'Cambio de opinión'),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(database.enTransaccion).toHaveBeenCalledTimes(1);
    expect(soporte.consultarUnoCliente).toHaveBeenCalledWith(
      client,
      expect.stringContaining('FOR UPDATE'),
      ['pedido-1', 'sucursal-1'],
    );
    expect(client.query).not.toHaveBeenCalled();
  });
});
