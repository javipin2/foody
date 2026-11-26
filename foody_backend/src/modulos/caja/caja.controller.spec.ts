import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
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
    [CajaController.prototype.abrir, 'abrir_caja'],
    [CajaController.prototype.cerrar, 'cerrar_caja'],
    [CajaController.prototype.retiro, 'hacer_retiro_parcial'],
  ])('deniega operaciones con permiso de solo lectura (%s)', (handler) => {
    expect(() =>
      guard.canActivate(contextoPara(handler, ['ver_caja'])),
    ).toThrow(ForbiddenException);
  });

  it.each([
    [CajaController.prototype.abrir, 'abrir_caja'],
    [CajaController.prototype.cerrar, 'cerrar_caja'],
    [CajaController.prototype.retiro, 'hacer_retiro_parcial'],
  ])(
    'permite la operación de caja con su permiso específico (%s)',
    (handler, permiso) => {
      expect(guard.canActivate(contextoPara(handler, [permiso]))).toBe(true);
    },
  );

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

describe('CajaController abrir — scope de escritura', () => {
  it('rechaza una sede hermana antes de invocar la apertura de caja', async () => {
    const SID_CENTRO = 'c0000000-0000-4000-8000-000000000001';
    const SID_NORTE = 'c0000000-0000-4000-8000-000000000002';
    const database = {
      consultarUno: jest.fn().mockResolvedValue({ id: SID_NORTE }),
    };
    const cajaService = { abrir: jest.fn() };
    const scope = new SucursalScopeService(database as never);
    const controller = new CajaController(cajaService as never, scope);
    const usuario = {
      sub: 'usuario-gerente',
      sucursal_id: SID_CENTRO,
      restaurante_id: 'restaurante-demo',
      rol: 'gerente',
    } as never;

    await expect(
      controller.abrir(
        { sucursal_id: SID_NORTE, monto_inicial: 10000 },
        usuario,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);

    expect(database.consultarUno).toHaveBeenCalledWith(
      expect.stringContaining('restaurante_id = $2 AND activa = true'),
      [SID_NORTE, 'restaurante-demo'],
    );
    expect(cajaService.abrir).not.toHaveBeenCalled();
  });
});
