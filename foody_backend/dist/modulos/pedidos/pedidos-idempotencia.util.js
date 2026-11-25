"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.huellaIdempotenciaPedido = huellaIdempotenciaPedido;
const node_crypto_1 = require("node:crypto");
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
    const { idempotency_key: _clave, ...payload } = dto;
    return (0, node_crypto_1.createHash)('sha256')
        .update(JSON.stringify(ordenarJson(payload)))
        .digest('hex');
}
//# sourceMappingURL=pedidos-idempotencia.util.js.map