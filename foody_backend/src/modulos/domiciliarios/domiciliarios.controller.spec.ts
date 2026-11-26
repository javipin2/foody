import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { DispatchService } from './dispatch.service';
import { DomiciliariosPlantaController } from './domiciliarios.controller';
import { DomiciliariosService } from './domiciliarios.service';

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
    'deniega liquidar cuando solo tiene %s',
    (permiso) => {
      expect(() =>
        guard.canActivate(contextoPara(liquidar, [permiso])),
      ).toThrow(ForbiddenException);
    },
  );

  it('permite liquidar cuando tiene permisos de domiciliarios y Caja', () => {
    expect(
      guard.canActivate(
        contextoPara(liquidar, ['gestionar_domiciliarios', 'gestionar_caja']),
      ),
    ).toBe(true);
  });

  it.each(['gestionar_domiciliarios', 'ver_caja'])(
    'conserva semántica OR para resúmenes con permiso %s',
    (permiso) => {
      expect(
        guard.canActivate(
          contextoPara(
            DomiciliariosPlantaController.prototype.resumenLiquidacion,
            [permiso],
          ),
        ),
      ).toBe(true);
    },
  );
});

describe('Scope de mutaciones de despacho de domiciliarios', () => {
  const database = {
    consultarUno: jest.fn().mockResolvedValue({ id: 'sucursal-b' }),
  };
  const domiciliarios = {
    asignarPlanta: jest.fn(),
    reasignarPlanta: jest.fn(),
  } as unknown as DomiciliariosService;
  const dispatch = {
    iniciarBusquedaIndependientes: jest.fn(),
  } as unknown as DispatchService;
  const scope = new SucursalScopeService(database as never);
  const controller = new DomiciliariosPlantaController(
    domiciliarios,
    dispatch,
    scope,
  );
  const gerente: JwtPayload = {
    sub: 'gerente-1',
    email: 'gerente@test.invalid',
    restaurante_id: 'restaurante-1',
    sucursal_id: 'sucursal-a',
    rol: 'gerente',
    permisos: ['gestionar_domiciliarios'],
  };
  const dto = {
    pedido_id: 'c0000000-0000-4000-8000-000000000003',
    sucursal_id: 'sucursal-b',
    domiciliario_planta_id: 'c0000000-0000-4000-8000-000000000004',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    database.consultarUno.mockResolvedValue({ id: 'sucursal-b' });
  });

  it.each(['asignar', 'reasignar', 'dispatch independiente'])(
    'rechaza %s antes de invocar el servicio en una sede hermana',
    async (operacion) => {
      let resultado: Promise<unknown>;
      if (operacion === 'asignar') {
        resultado = controller.asignar(dto, gerente);
      } else if (operacion === 'reasignar') {
        resultado = controller.reasignar(dto, gerente);
      } else {
        resultado = controller.dispatchIndependiente(
          dto.pedido_id,
          gerente,
          dto.sucursal_id,
        );
      }

      await expect(resultado).rejects.toBeInstanceOf(ForbiddenException);
      expect(domiciliarios.asignarPlanta).not.toHaveBeenCalled();
      expect(domiciliarios.reasignarPlanta).not.toHaveBeenCalled();
      expect(dispatch.iniciarBusquedaIndependientes).not.toHaveBeenCalled();
    },
  );
});
