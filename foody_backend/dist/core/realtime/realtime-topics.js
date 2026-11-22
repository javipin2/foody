"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.pepperRealtime = pepperRealtime;
exports.firmaCanal = firmaCanal;
exports.topicStaff = topicStaff;
exports.topicCatalogoPublico = topicCatalogoPublico;
exports.esTopicPublico = esTopicPublico;
const crypto_1 = require("crypto");
function pepperRealtime(env) {
    return (env.get('REALTIME_CANAL_PEPPER')?.trim() ||
        env.get('JWT_SECRET')?.trim() ||
        'foody_jwt_secret_cambiar');
}
function firmaCanal(pepper, tipo, id) {
    return (0, crypto_1.createHmac)('sha256', pepper)
        .update(`${tipo}:${id}`)
        .digest('hex')
        .slice(0, 16);
}
function topicStaff(pepper, tipo, id) {
    return `${tipo}_${id}_${firmaCanal(pepper, tipo, id)}`;
}
function topicCatalogoPublico(sucursalId) {
    return `sucursal_${sucursalId}_catalogo`;
}
function esTopicPublico(nombre) {
    return (nombre === 'foody_health_check' ||
        nombre.endsWith('_catalogo') ||
        nombre.startsWith('pedido_'));
}
//# sourceMappingURL=realtime-topics.js.map