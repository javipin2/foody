import { PlanComercial } from '../../core/auth/plan-features.config';
export type PlanPago = Exclude<PlanComercial, 'gratis'>;
export declare const PRECIO_PLAN_CENTAVOS: Record<PlanPago, number>;
export declare const PLANES_PAGO: PlanPago[];
export declare function esPlanPago(plan: string): plan is PlanPago;
