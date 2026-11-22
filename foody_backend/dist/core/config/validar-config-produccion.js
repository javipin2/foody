"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validarConfigProduccion = validarConfigProduccion;
exports.esProduccion = esProduccion;
const JWT_DEFAULT = 'foody_jwt_secret_cambiar';
function validarConfigProduccion() {
    const entorno = (process.env.ENTORNO ?? 'desarrollo').toLowerCase();
    if (entorno !== 'produccion' && entorno !== 'production')
        return;
    const jwt = process.env.JWT_SECRET?.trim();
    if (!jwt || jwt === JWT_DEFAULT || jwt === 'foody_jwt_secret_cambiar_en_produccion') {
        throw new Error('JWT_SECRET debe estar definido y ser distinto del valor por defecto (ENTORNO=produccion)');
    }
    if (jwt.length < 32) {
        throw new Error('JWT_SECRET en produccion debe tener al menos 32 caracteres');
    }
    const exp = (process.env.JWT_EXPIRACION ?? '7d').trim().toLowerCase();
    const expOk = /^\d+m$/.test(exp) ||
        /^\d+h$/.test(exp) ||
        exp === '1d' ||
        exp === '24h';
    if (!expOk) {
        throw new Error('JWT_EXPIRACION en produccion debe ser corto (ej. 1h, 2h, 15m, 1d). Flutter renueva con /auth/refresh');
    }
    const cors = process.env.CORS_ORIGEN?.trim();
    if (!cors || cors === '*') {
        throw new Error('CORS_ORIGEN debe listar orígenes explícitos (no *) en produccion');
    }
    const poolMax = Number(process.env.DB_POOL_MAX);
    if (!Number.isFinite(poolMax) || poolMax <= 0) {
        throw new Error('DB_POOL_MAX debe estar definida y ser numérica en produccion');
    }
    if (poolMax < 25) {
        throw new Error('DB_POOL_MAX en produccion debe ser >= 25 (AQ-SCALE-01 / PERF-POOL)');
    }
}
function esProduccion() {
    const e = (process.env.ENTORNO ?? 'desarrollo').toLowerCase();
    return e === 'produccion' || e === 'production';
}
//# sourceMappingURL=validar-config-produccion.js.map