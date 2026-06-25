import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISOS_KEY } from '../../../compartido/decoradores/permisos.decorator';
import { JwtPayload } from '../jwt-payload';

@Injectable()
export class RolGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const permisosRequeridos = this.reflector.getAllAndOverride<string[]>(
      PERMISOS_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!permisosRequeridos?.length) return true;

    const request = context.switchToHttp().getRequest<{ user?: JwtPayload }>();
    const usuario = request.user;
    if (!usuario) return false;

    const tiene = permisosRequeridos.some((p) => usuario.permisos.includes(p));
    if (!tiene) {
      throw new ForbiddenException('No tienes permiso para esta acción');
    }
    return true;
  }
}
