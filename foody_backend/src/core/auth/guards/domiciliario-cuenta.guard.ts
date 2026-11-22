import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { JwtPayload } from '../jwt-payload';

/** Domiciliario independiente con cuenta pendiente de verificación o activa. */
@Injectable()
export class DomiciliarioCuentaGuard implements CanActivate {
  constructor(private readonly database: DatabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<{ user?: JwtPayload }>();
    const usuario = request.user;
    if (!usuario?.sub) {
      throw new UnauthorizedException('Sesión inválida');
    }
    if (usuario.rol !== 'domiciliario_independiente') {
      throw new ForbiddenException('Acceso solo para domiciliarios independientes');
    }

    const dom = await this.database.consultarUno<{ estado_cuenta: string }>(
      `SELECT estado_cuenta FROM domiciliarios_independientes WHERE id = $1`,
      [usuario.sub],
    );
    if (!dom) {
      throw new ForbiddenException('Cuenta no encontrada');
    }
    if (!['pendiente_verificacion', 'activo'].includes(dom.estado_cuenta)) {
      throw new ForbiddenException(
        'Tu cuenta está suspendida o bloqueada. Contacta a soporte Foody.',
      );
    }
    return true;
  }
}
