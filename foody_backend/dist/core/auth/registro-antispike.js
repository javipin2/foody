"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.registroSelfServiceAbierto = registroSelfServiceAbierto;
exports.registroCupoDiario = registroCupoDiario;
exports.registroMaxPorMinuto = registroMaxPorMinuto;
exports.bcryptRoundsRegistro = bcryptRoundsRegistro;
function registroSelfServiceAbierto() {
    const v = (process.env.REGISTRO_RESTAURANTE_ABIERTO ?? '1').trim().toLowerCase();
    return !(v === '0' || v === 'false' || v === 'off' || v === 'no');
}
function registroCupoDiario() {
    const n = Number(process.env.REGISTRO_CUPO_DIARIO ?? '0');
    if (!Number.isFinite(n) || n < 0)
        return 0;
    return Math.floor(n);
}
function registroMaxPorMinuto() {
    const n = Number(process.env.REGISTRO_MAX_POR_MINUTO ?? '0');
    if (!Number.isFinite(n) || n < 0)
        return 0;
    return Math.floor(n);
}
function bcryptRoundsRegistro() {
    const n = Number(process.env.BCRYPT_ROUNDS ?? '10');
    if (!Number.isFinite(n))
        return 10;
    return Math.min(12, Math.max(8, Math.floor(n)));
}
//# sourceMappingURL=registro-antispike.js.map