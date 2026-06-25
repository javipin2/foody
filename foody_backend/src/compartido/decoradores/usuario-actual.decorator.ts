import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { JwtPayload } from '../../core/auth/jwt-payload';

export const UsuarioActual = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): JwtPayload => {
    const request = ctx.switchToHttp().getRequest<{ user: JwtPayload }>();
    return request.user;
  },
);
