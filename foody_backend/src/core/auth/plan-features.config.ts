export type PlanComercial = 'gratis' | 'basico' | 'pro' | 'enterprise';

export type ModuloPlan =
  | 'inventario'
  | 'costeo'
  | 'cocina'
  | 'domiciliarios'
  | 'zonas_domicilio'
  | 'reportes'
  | 'facturacion';

const PLAN_NIVEL: Record<PlanComercial, number> = {
  gratis: 0,
  basico: 1,
  pro: 2,
  enterprise: 3,
};

/** Plan mínimo requerido por módulo (borrador alineado a docs/PLANES_SUSCRIPCION.md). */
export const MODULO_PLAN_MINIMO: Record<ModuloPlan, PlanComercial> = {
  inventario: 'pro',
  costeo: 'pro',
  cocina: 'pro',
  domiciliarios: 'pro',
  zonas_domicilio: 'pro',
  reportes: 'pro',
  facturacion: 'enterprise',
};

export function normalizarPlan(plan: string | null | undefined): PlanComercial {
  if (plan === 'gratis') return 'gratis';
  if (plan === 'pro' || plan === 'enterprise') return plan;
  return 'basico';
}

export function planIncluyeModulo(
  plan: string | null | undefined,
  modulo: ModuloPlan,
): boolean {
  const p = normalizarPlan(plan);
  return PLAN_NIVEL[p] >= PLAN_NIVEL[MODULO_PLAN_MINIMO[modulo]];
}

export function modulosDelPlan(plan: string | null | undefined): ModuloPlan[] {
  return (Object.keys(MODULO_PLAN_MINIMO) as ModuloPlan[]).filter((m) =>
    planIncluyeModulo(plan, m),
  );
}

/** Límites numéricos por plan (Sprint 8). */
export const LIMITES_POR_PLAN: Record<
  PlanComercial,
  { max_sucursales: number; max_usuarios_staff: number }
> = {
  gratis: { max_sucursales: 1, max_usuarios_staff: 3 },
  basico: { max_sucursales: 1, max_usuarios_staff: 8 },
  pro: { max_sucursales: 3, max_usuarios_staff: 25 },
  enterprise: { max_sucursales: 99, max_usuarios_staff: 99 },
};
