export type PlanComercial = 'gratis' | 'basico' | 'pro' | 'enterprise';
export type ModuloPlan = 'inventario' | 'costeo' | 'cocina' | 'domiciliarios' | 'zonas_domicilio' | 'reportes' | 'analitica' | 'facturacion';
export declare const MODULO_PLAN_MINIMO: Record<ModuloPlan, PlanComercial>;
export declare function normalizarPlan(plan: string | null | undefined): PlanComercial;
export declare function planIncluyeModulo(plan: string | null | undefined, modulo: ModuloPlan): boolean;
export declare function modulosDelPlan(plan: string | null | undefined): ModuloPlan[];
export declare const LIMITES_POR_PLAN: Record<PlanComercial, {
    max_sucursales: number;
    max_usuarios_staff: number;
    max_mesas: number;
    max_productos: number;
    max_ingredientes: number;
}>;
