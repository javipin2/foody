import { PlanComercial } from '../../core/auth/plan-features.config';

export type PlanPago = Exclude<PlanComercial, 'gratis'>;

/** Precios mensuales en centavos COP (spec negocio). */
export const PRECIO_PLAN_CENTAVOS: Record<PlanPago, number> = {
  basico: 5_000_000,
  pro: 10_000_000,
  enterprise: 13_000_000,
};

export const PLANES_PAGO: PlanPago[] = ['basico', 'pro', 'enterprise'];

export function esPlanPago(plan: string): plan is PlanPago {
  return PLANES_PAGO.includes(plan as PlanPago);
}
