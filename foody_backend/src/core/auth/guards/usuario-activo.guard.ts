import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { JwtPayload } from '../jwt-payload';

@Injectable()
export class UsuarioActivoGuard implements CanActivate {
  constructor(private readonly database: DatabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<{ user?: JwtPayload }>();
    const usuario = request.user;
    if (!usuario?.sub) {
      throw new UnauthorizedException('Sesión inválida');
    }

    if (usuario.rol === 'domiciliario_independiente') {
      const dom = await this.database.consultarUno<{ estado_cuenta: string }>(
        `SELECT estado_cuenta FROM domiciliarios_independientes WHERE id = $1`,
        [usuario.sub],
      );
      if (dom?.estado_cuenta !== 'activo') {
        throw new UnauthorizedException('Domiciliario inactivo');
      }
      return true;
    }

    const fila = await this.database.consultarUno<{ activo: boolean }>(
      `SELECT activo FROM usuarios WHERE id = $1`,
      [usuario.sub],
    );
    if (!fila?.activo) {
      throw new UnauthorizedException('Usuario inactivo');
    }
    return true;
  }
}
