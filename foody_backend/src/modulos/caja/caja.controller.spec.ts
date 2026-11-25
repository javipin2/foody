import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { CajaController } from './caja.controller';

function contextoPara(handler: Function, permisos: string[]): ExecutionContext {
  return {
    getHandler: () => handler,
    getClass: () => CajaController,
    switchToHttp: () => ({ getRequest: () => ({ user: { permisos } }) }),
  } as unknown as ExecutionContext;
}

describe('Permisos de escritura de Caja', () => {
  const guard = new RolGuard(new Reflector());

  it.each([
    CajaController.prototype.crearFiado,
    CajaController.prototype.pagarFiado,
    CajaController.prototype.devolucion,
    CajaController.prototype.gasto,
  ])('deniega escritura a un permiso de solo lectura (%s)', (handler) => {
    expect(() =>
      guard.canActivate(contextoPara(handler, ['ver_caja'])),
    ).toThrow(ForbiddenException);
  });

  it.each([
    CajaController.prototype.crearFiado,
    CajaController.prototype.pagarFiado,
    CajaController.prototype.devolucion,
    CajaController.prototype.gasto,
  ])('permite escritura con gestionar_caja (%s)', (handler) => {
    expect(
      guard.canActivate(contextoPara(handler, ['ver_caja', 'gestionar_caja'])),
    ).toBe(true);
  });
});
