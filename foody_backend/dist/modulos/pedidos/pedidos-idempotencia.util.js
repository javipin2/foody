"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validarTotalEsperadoPedido = validarTotalEsperadoPedido;
exports.huellaIdempotenciaPedido = huellaIdempotenciaPedido;
const node_crypto_1 = require("node:crypto");
const common_1 = require("@nestjs/common");
function validarTotalEsperadoPedido(esperado, actual, contexto) {
    if (esperado === undefined) {
        throw new common_1.BadRequestException({
            error: 'TOTAL_ESPERADO_REQUERIDO',
            message: 'Actualiza la pantalla de caja para confirmar el precio antes de cobrar',
        });
    }
    if (Math.abs(Math.round((esperado - actual) * 100)) <= 1)
        return;
    throw new common_1.ConflictException({
        error: 'TOTAL_PEDIDO_CAMBIO',
        message: 'El total cambió desde la última cotización',
        total_esperado: esperado,
        total_actual: actual,
        subtotal: contexto.subtotal,
        costo_domicilio: contexto.costoDomicilio,
        descuento: contexto.descuento,
    });
}
function ordenarJson(valor) {
    if (Array.isArray(valor))
        return valor.map(ordenarJson);
    if (valor !== null && typeof valor === 'object') {
        return Object.fromEntries(Object.entries(valor)
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([clave, dato]) => [clave, ordenarJson(dato)]));
    }
    return valor;
}
function huellaIdempotenciaPedido(dto) {
    const { idempotency_key: _clave, total_esperado: _total, ...payload } = dto;
    return (0, node_crypto_1.createHash)('sha256')
        .update(JSON.stringify(ordenarJson(payload)))
        .digest('hex');
}
//# sourceMappingURL=pedidos-idempotencia.util.js.map