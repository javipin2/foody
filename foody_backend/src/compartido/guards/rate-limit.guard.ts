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
import { esProduccion } from '../../core/config/validar-config-produccion';
import { DatabaseService } from '../../core/database/database.service';

export const RATE_LIMIT_META = 'rate_limit';

export type RateLimitOptions = {
  /** Ventana en ms */
  ventanaMs: number;
  /** Máximo de peticiones por IP en la ventana */
  maximo: number;
};

export const RateLimitPublico = (maximo = 60, ventanaMs = 60_000) =>
  SetMetadata(RATE_LIMIT_META, {
    maximo,
    ventanaMs,
  } satisfies RateLimitOptions);

type Entrada = { cuenta: number; reinicio: number };

@Injectable()
export class RateLimitGuard implements CanActivate {
  private static readonly store = new Map<string, Entrada>();

  constructor(
    private readonly reflector: Reflector,
    private readonly database: DatabaseService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const opts = this.reflector.get<RateLimitOptions | undefined>(
      RATE_LIMIT_META,
      context.getHandler(),
    );
    if (!opts) return true;
    // ponytail: rate limit en prod; CI local hace decenas de logins/minuto.
    // RATE_LIMIT_FORZAR=1 fuerza el límite también en desarrollo (QA SEC-RLIMIT).
    const forzar = process.env.RATE_LIMIT_FORZAR === '1';
    if (!esProduccion() && !forzar) return true;

    const req = context.switchToHttp().getRequest<Request>();
    const ip =
      (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ||
      req.ip ||
      'unknown';
    const clave = `${ip}:${req.method}:${req.path}`;
    const ahora = Date.now();

    // Prod: rate-limit multi-réplica usando Postgres (no Map en memoria).
    // dev/CI: Map en memoria, salvo forzar para QA SEC-RLIMIT.
    if (esProduccion() || forzar) {
      let cuentaDB: number | null = null;
      try {
        const r = await this.database.consultarUno<{ cuenta: number }>(
          `INSERT INTO rate_limit_entries (clave, ventana_ms, reinicio_at, cuenta)
           VALUES (
             $1,
             $2,
             now() + ($2::text || ' milliseconds')::interval,
             1
           )
           ON CONFLICT (clave) DO UPDATE
             SET ventana_ms = EXCLUDED.ventana_ms,
                 reinicio_at = CASE
                   WHEN now() >= rate_limit_entries.reinicio_at
                     THEN now() + (EXCLUDED.ventana_ms::text || ' milliseconds')::interval
                   ELSE rate_limit_entries.reinicio_at
                 END,
                 cuenta = CASE
                   WHEN now() >= rate_limit_entries.reinicio_at
                     THEN 1
                   ELSE rate_limit_entries.cuenta + 1
                 END
           RETURNING cuenta`,
          [clave, opts.ventanaMs],
        );
        cuentaDB = Number(r?.cuenta ?? 1);
      } catch {
        // fallback (si falla BD) para no romper el servicio
      }

      // Fuera del catch: el 429 es una decisión del guard, no un fallo de BD.
      if (cuentaDB !== null) {
        if (cuentaDB > opts.maximo) {
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

    // Fallback (no prod / DB falló): rate limit en memoria.
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
