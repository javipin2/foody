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
    inventario: 'gratis',
    costeo: 'gratis',
    cocina: 'gratis',
    domiciliarios: 'gratis',
    zonas_domicilio: 'gratis',
    reportes: 'gratis',
    analitica: 'pro',
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
    gratis: { max_sucursales: 1, max_usuarios_staff: 2, max_mesas: 2, max_productos: 5, max_ingredientes: 5 },
    basico: { max_sucursales: 1, max_usuarios_staff: 8, max_mesas: 30, max_productos: 200, max_ingredientes: 200 },
    pro: { max_sucursales: 3, max_usuarios_staff: 25, max_mesas: 100, max_productos: 9999, max_ingredientes: 9999 },
    enterprise: { max_sucursales: 99, max_usuarios_staff: 99, max_mesas: 9999, max_productos: 9999, max_ingredientes: 9999 },
};
//# sourceMappingURL=plan-features.config.js.map