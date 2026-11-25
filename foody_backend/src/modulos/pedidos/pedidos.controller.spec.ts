import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { PedidosController } from './pedidos.controller';

function contextoPara(
  handler: Function,
  permisos: string[],
): ExecutionContext {
  return {
    getHandler: () => handler,
    getClass: () => PedidosController,
    switchToHttp: () => ({
      getRequest: () => ({ user: { permisos } }),
    }),
  } as unknown as ExecutionContext;
}

describe('Permisos de transición de pedido', () => {
  const guard = new RolGuard(new Reflector());

  it('no permite mutar el estado a un usuario con solo lectura', () => {
    expect(() =>
      guard.canActivate(
        contextoPara(PedidosController.prototype.cambiarEstado, [
          'ver_pedidos',
        ]),
      ),
    ).toThrow(ForbiddenException);
  });

  it('permite la transición al rol operativo con crear_pedido', () => {
    expect(
      guard.canActivate(
        contextoPara(PedidosController.prototype.cambiarEstado, [
          'ver_pedidos',
          'crear_pedido',
        ]),
      ),
    ).toBe(true);
  });

  it.each([
    PedidosController.prototype.cobrarPedido,
    PedidosController.prototype.cobrarMesa,
  ])('no permite a mesero cobrar mediante %s', (handler) => {
    expect(() =>
      guard.canActivate(
        contextoPara(handler, [
          'ver_pedidos',
          'crear_pedido',
          'gestionar_mesas',
        ]),
      ),
    ).toThrow(ForbiddenException);
  });

  it.each([
    PedidosController.prototype.cobrarPedido,
    PedidosController.prototype.cobrarMesa,
  ])('permite al cajero cobrar mediante %s', (handler) => {
    expect(
      guard.canActivate(contextoPara(handler, ['cobrar_pedido'])),
    ).toBe(true);
  });
});
