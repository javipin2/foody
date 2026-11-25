import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { DomiciliariosPlantaController } from './domiciliarios.controller';

function contextoPara(handler: Function, permisos: string[]): ExecutionContext {
  return {
    getHandler: () => handler,
    getClass: () => DomiciliariosPlantaController,
    switchToHttp: () => ({ getRequest: () => ({ user: { permisos } }) }),
  } as unknown as ExecutionContext;
}

describe('Permisos de liquidación de domiciliario de planta', () => {
  const guard = new RolGuard(new Reflector());
  const liquidar = DomiciliariosPlantaController.prototype.liquidar;

  it('no permite liquidar con permiso de solo lectura de Caja', () => {
    expect(() =>
      guard.canActivate(contextoPara(liquidar, ['ver_caja'])),
    ).toThrow(ForbiddenException);
  });

  it.each(['gestionar_caja', 'gestionar_domiciliarios'])(
    'permite liquidar a un rol autorizado con %s',
    (permiso) => {
      expect(guard.canActivate(contextoPara(liquidar, [permiso]))).toBe(true);
    },
  );
});
