"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ZONA_HORARIA_NEGOCIO = void 0;
exports.fechaHoyNegocio = fechaHoyNegocio;
exports.ZONA_HORARIA_NEGOCIO = 'America/Bogota';
function fechaHoyNegocio(ahora = new Date()) {
    return new Intl.DateTimeFormat('en-CA', {
        timeZone: exports.ZONA_HORARIA_NEGOCIO,
    }).format(ahora);
}
//# sourceMappingURL=fecha-negocio.util.js.map