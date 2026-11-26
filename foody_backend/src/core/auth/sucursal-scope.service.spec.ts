import { ForbiddenException } from '@nestjs/common';
import { JwtPayload } from './jwt-payload';
import { SucursalScopeService } from './sucursal-scope.service';

describe('SucursalScopeService — aislamiento operativo', () => {
  const database = { consultarUno: jest.fn() };
  const service = new SucursalScopeService(database as never);
  const usuario: JwtPayload = {
    sub: 'usuario-1',
    email: 'admin@test.invalid',
    restaurante_id: 'restaurante-1',
    sucursal_id: 'sucursal-a',
    rol: 'admin',
    permisos: [],
  };

  beforeEach(() => database.consultarUno.mockReset());

  it('permite operar la sucursal asignada validando pertenencia activa', async () => {
    database.consultarUno.mockResolvedValue({ id: 'sucursal-a' });

    await expect(
      service.resolverEscritura(usuario, 'sucursal-a'),
    ).resolves.toBe('sucursal-a');
    expect(database.consultarUno).toHaveBeenCalledWith(
      expect.stringContaining('restaurante_id = $2 AND activa = true'),
      ['sucursal-a', 'restaurante-1'],
    );
  });

  it('rechaza lectura y escritura de una sucursal hermana para usuario operativo', async () => {
    database.consultarUno.mockResolvedValue({ id: 'sucursal-b' });

    await expect(
      service.resolverLecturaOperativa(usuario, 'sucursal-b'),
    ).rejects.toBeInstanceOf(ForbiddenException);
    await expect(
      service.resolverEscritura(usuario, 'sucursal-b'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('no permite que permiso de domiciliarios amplíe escritura a otra sede', async () => {
    database.consultarUno.mockResolvedValue({ id: 'sucursal-b' });
    const gerenteDomiciliarios: JwtPayload = {
      ...usuario,
      rol: 'gerente',
      permisos: ['gestionar_domiciliarios'],
    };

    await expect(
      service.resolverEscritura(gerenteDomiciliarios, 'sucursal-b'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('rechaza IDs de otra empresa o sucursales inactivas', async () => {
    database.consultarUno.mockResolvedValue(null);

    await expect(
      service.resolverLecturaOperativa(usuario, 'otra-empresa'),
    ).rejects.toBeInstanceOf(ForbiddenException);
    await expect(
      service.resolverEscritura(usuario, 'sucursal-inactiva'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('permite sede hermana solo a un usuario corporativo del mismo restaurante', async () => {
    database.consultarUno.mockResolvedValue({ id: 'sucursal-b' });
    const corporativo = {
      ...usuario,
      permisos: ['gestionar_sucursales'],
    } as JwtPayload;

    await expect(
      service.resolverLecturaOperativa(corporativo, 'sucursal-b'),
    ).resolves.toBe('sucursal-b');
    await expect(
      service.resolverEscritura(corporativo, 'sucursal-b'),
    ).resolves.toBe('sucursal-b');
  });
});
