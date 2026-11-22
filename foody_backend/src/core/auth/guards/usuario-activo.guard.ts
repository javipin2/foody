import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { JwtPayload } from '../jwt-payload';

/** Versión de sesión en JWT sin claim → legacy (migración 084). */
function tvDelJwt(usuario: JwtPayload): number {
  const n = Number(usuario.tv ?? 1);
  return Number.isFinite(n) && n > 0 ? n : 1;
}

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
      const dom = await this.database.consultarUno<{
        estado_cuenta: string;
        token_version: number;
      }>(
        `SELECT estado_cuenta, COALESCE(token_version, 1) AS token_version
         FROM domiciliarios_independientes WHERE id = $1`,
        [usuario.sub],
      );
      if (dom?.estado_cuenta !== 'activo') {
        throw new UnauthorizedException('Domiciliario inactivo');
      }
      if (tvDelJwt(usuario) !== Number(dom.token_version)) {
        throw new UnauthorizedException({
          error: 'SESION_REVOCADA',
          message: 'Sesión cerrada o invalidada. Vuelve a iniciar sesión.',
        });
      }
      return true;
    }

    const fila = await this.database.consultarUno<{
      activo: boolean;
      token_version: number;
    }>(
      `SELECT activo, COALESCE(token_version, 1) AS token_version
       FROM usuarios WHERE id = $1`,
      [usuario.sub],
    );
    if (!fila?.activo) {
      throw new UnauthorizedException('Usuario inactivo');
    }
    if (tvDelJwt(usuario) !== Number(fila.token_version)) {
      throw new UnauthorizedException({
        error: 'SESION_REVOCADA',
        message: 'Sesión cerrada o invalidada. Vuelve a iniciar sesión.',
      });
    }
    return true;
  }
}
