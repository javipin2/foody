"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LIMITES_POR_PLAN = exports.MODULO_PLAN_MINIMO = void 0;
exports.normalizarPlan = normalizarPlan;
exports.planIncluyeModulo = planIncluyeModulo;
exports.modulosDelPlan = modulosDelPlan;
const PLAN_NIVEL = {
    gratis: 0,
    basico: 1,
    pro: 2,
    enterprise: 3,
};
exports.MODULO_PLAN_MINIMO = {
    inventario: 'pro',
    costeo: 'pro',
    cocina: 'pro',
    domiciliarios: 'pro',
    zonas_domicilio: 'pro',
    reportes: 'pro',
    facturacion: 'enterprise',
};
function normalizarPlan(plan) {
    if (plan === 'gratis')
        return 'gratis';
    if (plan === 'pro' || plan === 'enterprise')
        return plan;
    return 'basico';
}
function planIncluyeModulo(plan, modulo) {
    const p = normalizarPlan(plan);
    return PLAN_NIVEL[p] >= PLAN_NIVEL[exports.MODULO_PLAN_MINIMO[modulo]];
}
function modulosDelPlan(plan) {
    return Object.keys(exports.MODULO_PLAN_MINIMO).filter((m) => planIncluyeModulo(plan, m));
}
exports.LIMITES_POR_PLAN = {
    gratis: { max_sucursales: 1, max_usuarios_staff: 3 },
    basico: { max_sucursales: 1, max_usuarios_staff: 8 },
    pro: { max_sucursales: 3, max_usuarios_staff: 25 },
    enterprise: { max_sucursales: 99, max_usuarios_staff: 99 },
};
//# sourceMappingURL=plan-features.config.js.map