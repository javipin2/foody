import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtPayload } from './jwt-payload';

describe('AuthService realtimeCanales', () => {
  const usuarioBase = {
    id: 'usuario-1',
    nombre: 'Admin de prueba',
    email: 'admin@test.invalid',
    rol: 'admin',
    sucursal_id: 'sucursal-1',
    restaurante_id: 'restaurante-1',
    activo: true,
    hash_contrasena: null,
    cocina_id: null,
  };

  function crearServicio({
    usuario = usuarioBase,
    permisosRol = ['ver_cocina'],
    cocinaExiste = true,
    sucursalValida = true,
  }: {
    usuario?: typeof usuarioBase;
    permisosRol?: string[];
    cocinaExiste?: boolean;
    sucursalValida?: boolean;
  } = {}) {
    const database = {
      consultarUno: jest.fn(async (sql: string) => {
        if (sql.includes('FROM usuarios WHERE id = $1')) return usuario;
        if (sql.includes('FROM sucursales s')) {
          return sucursalValida ? { id: 'sucursal-2' } : null;
        }
        if (sql.includes('FROM cocinas')) {
          return cocinaExiste ? { id: 'cocina-1' } : null;
        }
        return null;
      }),
      consultar: jest.fn(async (sql: string) => {
        if (sql.includes('FROM usuario_permisos')) return [];
        if (sql.includes('FROM roles_permisos')) {
          return permisosRol.map((permiso) => ({ permiso }));
        }
        return [];
      }),
    };
    const realtime = {
      topicSucursal: (id: string) => `sucursal_${id}_firma`,
      topicRestaurante: (id: string) => `restaurante_${id}_firma`,
      topicCocina: (id: string) => `cocina_${id}_firma`,
    };
    const service = new AuthService(
      database as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      realtime as never,
    );
    return { service, database };
  }

  const jwt = (overrides: Partial<JwtPayload> = {}): JwtPayload => ({
    sub: usuarioBase.id,
    email: usuarioBase.email,
    rol: usuarioBase.rol,
    sucursal_id: usuarioBase.sucursal_id,
    restaurante_id: usuarioBase.restaurante_id,
    permisos: ['ver_cocina'],
    ...overrides,
  });

  it('firma la cocina solicitada a admin con permiso y alcance de sucursal', async () => {
    const { service, database } = crearServicio();

    const result = await service.realtimeCanales(jwt(), undefined, 'cocina-1');

    expect(result.realtime_canales.cocina).toBe('cocina_cocina-1_firma');
    expect(database.consultarUno).toHaveBeenCalledWith(
      expect.stringContaining('FROM cocinas'),
      ['cocina-1', 'sucursal-1'],
    );
  });

  it('rechaza emitir firma sin permiso ver_cocina', async () => {
    const { service } = crearServicio({ permisosRol: ['ver_pedidos'] });

    await expect(
      service.realtimeCanales(jwt(), undefined, 'cocina-1'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('rechaza una cocina que no pertenece a la sucursal autorizada', async () => {
    const { service } = crearServicio({ cocinaExiste: false });

    await expect(
      service.realtimeCanales(jwt(), undefined, 'cocina-1'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('rechaza el cambio a una sucursal ajena antes de firmar la cocina', async () => {
    const { service } = crearServicio({ sucursalValida: false });

    await expect(
      service.realtimeCanales(jwt(), 'sucursal-2', 'cocina-1'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('mantiene al rol cocina limitado a su estación asignada', async () => {
    const usuario = {
      ...usuarioBase,
      rol: 'cocina',
      cocina_id: 'cocina-1',
    };
    const { service } = crearServicio({ usuario });

    await expect(
      service.realtimeCanales(jwt({ rol: 'cocina' }), undefined, 'cocina-2'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
