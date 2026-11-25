import { ExecutionContext, HttpException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { DatabaseService } from '../../core/database/database.service';
import { RateLimitGuard, RATE_LIMIT_META } from './rate-limit.guard';

describe('RateLimitGuard', () => {
  const entornoOriginal = process.env.ENTORNO;
  const forzarOriginal = process.env.RATE_LIMIT_FORZAR;
  const opciones = { maximo: 2, ventanaMs: 60_000 };
  let reflector: jest.Mocked<Reflector>;
  let database: { consultarUno: jest.Mock };
  let guard: RateLimitGuard;
  let context: ExecutionContext;

  beforeEach(() => {
    process.env.ENTORNO = 'produccion';
    delete process.env.RATE_LIMIT_FORZAR;
    reflector = {
      get: jest.fn().mockReturnValue(opciones),
    } as unknown as jest.Mocked<Reflector>;
    database = { consultarUno: jest.fn() };
    guard = new RateLimitGuard(
      reflector,
      database as unknown as DatabaseService,
    );
    const request = {
      headers: {
        'x-forwarded-for': `198.51.100.${Math.floor(Math.random() * 200) + 1}`,
      },
      method: 'POST',
      path: `/test/${Math.random()}`,
      ip: '127.0.0.1',
    };
    context = {
      getHandler: () => jest.fn(),
      switchToHttp: () => ({ getRequest: () => request }),
    } as unknown as ExecutionContext;
  });

  afterAll(() => {
    if (entornoOriginal === undefined) delete process.env.ENTORNO;
    else process.env.ENTORNO = entornoOriginal;
    if (forzarOriginal === undefined) delete process.env.RATE_LIMIT_FORZAR;
    else process.env.RATE_LIMIT_FORZAR = forzarOriginal;
  });

  it('rechaza con 429 cuando Postgres informa que se excedió el límite', async () => {
    database.consultarUno.mockResolvedValue({ cuenta: 3 });

    await expect(guard.canActivate(context)).rejects.toMatchObject({
      status: 429,
    });
    expect(database.consultarUno).toHaveBeenCalledTimes(1);
    expect(reflector.get).toHaveBeenCalledWith(
      RATE_LIMIT_META,
      expect.any(Function),
    );
  });

  it('permite la petición cuando Postgres la mantiene dentro del límite', async () => {
    database.consultarUno.mockResolvedValue({ cuenta: 2 });

    await expect(guard.canActivate(context)).resolves.toBe(true);
  });

  it('usa el fallback local solo cuando falla la consulta de Postgres', async () => {
    database.consultarUno.mockRejectedValue(new Error('DB unavailable'));

    await expect(guard.canActivate(context)).resolves.toBe(true);
  });
});
