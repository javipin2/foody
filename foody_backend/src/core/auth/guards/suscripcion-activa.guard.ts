import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ForbiddenException,
} from '@nestjs/common';
import { JwtPayload } from '../jwt-payload';
import { SuscripcionesVencimientoService } from '../suscripciones-vencimiento.service';

@Injectable()
export class SuscripcionActivaGuard implements CanActivate {
  constructor(private readonly vencimiento: SuscripcionesVencimientoService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
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
      throw new ForbiddenException('Suscripción del restaurante no activa');
    }
    return true;
  }
}
