"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PLANES_PAGO = exports.PRECIO_PLAN_CENTAVOS = void 0;
exports.esPlanPago = esPlanPago;
exports.PRECIO_PLAN_CENTAVOS = {
    basico: 5_000_000,
    pro: 10_000_000,
    enterprise: 13_000_000,
};
exports.PLANES_PAGO = ['basico', 'pro', 'enterprise'];
function esPlanPago(plan) {
    return exports.PLANES_PAGO.includes(plan);
}
//# sourceMappingURL=pagos-planes.config.js.map