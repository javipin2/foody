"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.repartirCobroDomicilio = repartirCobroDomicilio;
exports.montoVentaCajaEntregaDomicilio = montoVentaCajaEntregaDomicilio;
function repartirCobroDomicilio(total, costoDomicilio, montoPagado) {
    const domicilio = Math.max(0, costoDomicilio);
    const saldo = Math.max(0, total - montoPagado);
    const productoTotal = Math.max(0, total - domicilio);
    const productoPendiente = Math.max(0, Math.min(saldo, productoTotal - montoPagado));
    const domicilioPendiente = Math.max(0, saldo - productoPendiente);
    return { saldo, productoPendiente, domicilioPendiente };
}
function montoVentaCajaEntregaDomicilio(total, costoDomicilio, montoPagado, domicilioIngresaACaja) {
    const { saldo, productoPendiente } = repartirCobroDomicilio(total, costoDomicilio, montoPagado);
    return domicilioIngresaACaja ? saldo : productoPendiente;
}
//# sourceMappingURL=cobro-domicilio.util.js.map