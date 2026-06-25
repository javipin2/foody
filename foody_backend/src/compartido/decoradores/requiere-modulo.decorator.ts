import { SetMetadata } from '@nestjs/common';
import { ModuloPlan } from '../../core/auth/plan-features.config';

export const MODULO_PLAN_KEY = 'modulo_plan';

export const RequiereModulo = (modulo: ModuloPlan) =>
  SetMetadata(MODULO_PLAN_KEY, modulo);
