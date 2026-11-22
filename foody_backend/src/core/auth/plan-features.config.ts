export type PlanComercial = 'gratis' | 'basico' | 'pro' | 'enterprise';

export type ModuloPlan =
  | 'inventario'
  | 'costeo'
  | 'cocina'
  | 'domiciliarios'
  | 'zonas_domicilio'
  | 'reportes'
  | 'analitica'
  | 'facturacion';

const PLAN_NIVEL: Record<PlanComercial, number> = {
  gratis: 0,
  basico: 1,
  pro: 2,
  enterprise: 3,
};

/** Plan mínimo requerido por módulo (borrador alineado a docs/PLANES_SUSCRIPCION.md). */
export const MODULO_PLAN_MINIMO: Record<ModuloPlan, PlanComercial> = {
  inventario: 'gratis',
  costeo: 'gratis',
  cocina: 'gratis',
  domiciliarios: 'gratis',
  zonas_domicilio: 'gratis',
  reportes: 'gratis',
  analitica: 'pro',
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
  {
    max_sucursales: number;
    max_usuarios_staff: number;
    max_mesas: number;
    max_productos: number;
    max_ingredientes: number;
  }
> = {
  gratis: { max_sucursales: 1, max_usuarios_staff: 2, max_mesas: 2, max_productos: 5, max_ingredientes: 5 },
  basico: { max_sucursales: 1, max_usuarios_staff: 8, max_mesas: 30, max_productos: 200, max_ingredientes: 200 },
  pro: { max_sucursales: 3, max_usuarios_staff: 25, max_mesas: 100, max_productos: 9999, max_ingredientes: 9999 },
  enterprise: { max_sucursales: 99, max_usuarios_staff: 99, max_mesas: 9999, max_productos: 9999, max_ingredientes: 9999 },
};
