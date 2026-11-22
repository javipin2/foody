import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { OMITIR_SUSCRIPCION_ACTIVA_KEY } from '../../../compartido/decoradores/omitir-suscripcion-activa.decorator';
import { JwtPayload } from '../jwt-payload';
import { SuscripcionesVencimientoService } from '../suscripciones-vencimiento.service';

/**
 * Bloquea operación de restaurante si la suscripción no está en `activa` o `prueba`.
 *
 * Bypass automático: `super_admin`, `domiciliario_independiente`.
 * Exclusiones explícitas: decorador `@OmitirSuscripcionActiva()` (pagos, perfil/FCM).
 * No aplica en `/super/*` ni rutas públicas sin JWT.
 */
@Injectable()
export class SuscripcionActivaGuard implements CanActivate {
  constructor(
    private readonly vencimiento: SuscripcionesVencimientoService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const omitir = this.reflector.getAllAndOverride<boolean>(
      OMITIR_SUSCRIPCION_ACTIVA_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (omitir) return true;

    const request = context.switchToHttp().getRequest<{ user?: JwtPayload }>();
    const usuario = request.user;
    if (!usuario) return false;

    if (usuario.rol === 'super_admin') return true;
    if (usuario.rol === 'domiciliario_independiente') return true;
    if (!usuario.restaurante_id) {
      throw new ForbiddenException('Usuario sin restaurante asignado');
    }

    const estado = await this.vencimiento.asegurarEstadoVigente(
      usuario.restaurante_id,
    );
    if (!['activa', 'prueba'].includes(estado)) {
      throw new ForbiddenException({
        error: 'RESTAURANTE_BLOQUEADO',
        mensaje:
          'Tu suscripción no está activa. Reactiva tu plan para usar el panel. Tus datos se conservan.',
        message:
          'Tu suscripción no está activa. Reactiva tu plan para usar el panel. Tus datos se conservan.',
        estado,
      });
    }
    return true;
  }
}
