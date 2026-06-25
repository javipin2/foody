import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';

export const RATE_LIMIT_META = 'rate_limit';

export type RateLimitOptions = {
  /** Ventana en ms */
  ventanaMs: number;
  /** Máximo de peticiones por IP en la ventana */
  maximo: number;
};

export const RateLimitPublico = (maximo = 60, ventanaMs = 60_000) =>
  SetMetadata(RATE_LIMIT_META, { maximo, ventanaMs } satisfies RateLimitOptions);

type Entrada = { cuenta: number; reinicio: number };

@Injectable()
export class RateLimitGuard implements CanActivate {
  private static readonly store = new Map<string, Entrada>();

  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const opts = this.reflector.get<RateLimitOptions | undefined>(
      RATE_LIMIT_META,
      context.getHandler(),
    );
    if (!opts) return true;

    const req = context.switchToHttp().getRequest<Request>();
    const ip =
      (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ||
      req.ip ||
      'unknown';
    const clave = `${ip}:${req.method}:${req.path}`;
    const ahora = Date.now();

    let entrada = RateLimitGuard.store.get(clave);
    if (!entrada || ahora >= entrada.reinicio) {
      entrada = { cuenta: 0, reinicio: ahora + opts.ventanaMs };
      RateLimitGuard.store.set(clave, entrada);
    }

    entrada.cuenta += 1;
    if (entrada.cuenta > opts.maximo) {
      throw new HttpException(
        {
          error: 'RATE_LIMIT',
          message: 'Demasiadas peticiones. Intenta de nuevo en un momento.',
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    return true;
  }
}
