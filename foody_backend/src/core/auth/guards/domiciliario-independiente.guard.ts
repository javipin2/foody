import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { JwtPayload } from '../jwt-payload';

@Injectable()
export class DomiciliarioIndependienteGuard implements CanActivate {
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
    if (!dom || dom.estado_cuenta !== 'activo') {
      throw new ForbiddenException('Cuenta de domiciliario no activa');
    }
    return true;
  }
}
