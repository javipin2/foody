import { ForbiddenException, Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import {
  LIMITES_POR_PLAN,
  ModuloPlan,
  modulosDelPlan,
  normalizarPlan,
  planIncluyeModulo,
} from './plan-features.config';

@Injectable()
export class PlanFeaturesService {
  constructor(private readonly database: DatabaseService) {}

  async obtenerPlanRestaurante(
    restauranteId: string | null | undefined,
  ): Promise<string> {
    if (!restauranteId) return 'basico';
    const fila = await this.database.consultarUno<{ plan: string }>(
      `SELECT plan FROM suscripciones_restaurante
       WHERE restaurante_id = $1
       LIMIT 1`,
      [restauranteId],
    );
    return normalizarPlan(fila?.plan);
  }

  modulosDelPlan(plan: string | null | undefined): ModuloPlan[] {
    return modulosDelPlan(plan);
  }

  incluyeModulo(plan: string | null | undefined, modulo: ModuloPlan): boolean {
    return planIncluyeModulo(plan, modulo);
  }

  async assertLimiteSucursales(restauranteId: string): Promise<void> {
    const plan = normalizarPlan(await this.obtenerPlanRestaurante(restauranteId));
    const limite = LIMITES_POR_PLAN[plan].max_sucursales;
    const fila = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total FROM sucursales
       WHERE restaurante_id = $1 AND activa = true`,
      [restauranteId],
    );
    const actual = Number(fila?.total ?? 0);
    if (actual >= limite) {
      throw new ForbiddenException({
        error: 'PLAN_LIMITE_EXCEDIDO',
        message: `Tu plan «${plan}» permite hasta ${limite} sucursal(es). Actualiza el plan para crear más.`,
        limite,
        actual,
      });
    }
  }

  async assertLimiteUsuariosStaff(restauranteId: string): Promise<void> {
    const plan = normalizarPlan(await this.obtenerPlanRestaurante(restauranteId));
    const limite = LIMITES_POR_PLAN[plan].max_usuarios_staff;
    const fila = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total FROM usuarios
       WHERE restaurante_id = $1 AND activo = true
         AND rol NOT IN ('super_admin', 'domiciliario_independiente')`,
      [restauranteId],
    );
    const actual = Number(fila?.total ?? 0);
    if (actual >= limite) {
      throw new ForbiddenException({
        error: 'PLAN_LIMITE_EXCEDIDO',
        message: `Tu plan «${plan}» permite hasta ${limite} usuarios staff. Actualiza el plan para invitar más.`,
        limite,
        actual,
      });
    }
  }
}
