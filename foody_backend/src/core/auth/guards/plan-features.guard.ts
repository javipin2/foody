import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { MODULO_PLAN_KEY } from '../../../compartido/decoradores/requiere-modulo.decorator';
import { ModuloPlan, normalizarPlan } from '../plan-features.config';
import { PlanFeaturesService } from '../plan-features.service';
import { JwtPayload } from '../jwt-payload';

function normalizarPlanDesdeJwt(plan?: string) {
  return normalizarPlan(plan);
}

@Injectable()
export class PlanFeaturesGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly planFeatures: PlanFeaturesService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const modulo = this.reflector.getAllAndOverride<ModuloPlan | undefined>(
      MODULO_PLAN_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!modulo) return true;

    const request = context.switchToHttp().getRequest<{ user?: JwtPayload }>();
    const usuario = request.user;
    if (!usuario) return false;

    if (usuario.rol === 'super_admin') return true;
    if (usuario.rol === 'domiciliario_independiente') return true;

    // Siempre leer plan en BD: el JWT puede quedar en «gratis» tras upgrade Wompi sin re-login.
    const plan = usuario.restaurante_id
      ? await this.planFeatures.obtenerPlanRestaurante(usuario.restaurante_id)
      : normalizarPlanDesdeJwt(usuario.plan);

    if (this.planFeatures.incluyeModulo(plan, modulo)) return true;

    throw new ForbiddenException({
      error: 'PLAN_NO_INCLUYE_MODULO',
      message: `Tu plan (${plan}) no incluye el módulo «${modulo}». Actualiza a un plan superior.`,
      modulo,
      plan,
    });
  }
}
