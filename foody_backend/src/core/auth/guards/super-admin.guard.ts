import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { JwtPayload } from '../jwt-payload';

/**
 * Rutas `/super/*`: solo usuarios de plataforma sin tenant (restaurante/sucursal).
 * Revalida rol y alcance en BD (no confía solo en el JWT).
 */
@Injectable()
export class SuperAdminGuard implements CanActivate {
  constructor(private readonly database: DatabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<{ user?: JwtPayload }>();
    const token = request.user;
    if (!token?.sub) {
      throw new UnauthorizedException('Sesión inválida');
    }

    const fila = await this.database.consultarUno<{
      rol: string;
      restaurante_id: string | null;
      sucursal_id: string | null;
      activo: boolean;
    }>(
      `SELECT rol, restaurante_id, sucursal_id, activo
       FROM usuarios
       WHERE id = $1`,
      [token.sub],
    );

    if (!fila?.activo) {
      throw new UnauthorizedException('Usuario inactivo');
    }
    if (fila.rol !== 'super_admin') {
      throw new ForbiddenException({
        error: 'SUPER_ADMIN_REQUERIDO',
        message: 'Solo super administrador',
      });
    }
    if (fila.restaurante_id != null || fila.sucursal_id != null) {
      throw new ForbiddenException({
        error: 'SUPER_ADMIN_SIN_TENANT',
        message:
          'El super administrador no puede tener restaurante ni sucursal asignados',
      });
    }

    request.user = {
      ...token,
      rol: fila.rol,
      restaurante_id: null,
      sucursal_id: null,
    };
    return true;
  }
}
