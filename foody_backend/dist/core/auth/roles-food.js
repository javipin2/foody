"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ROL_GERENTE_CADENA = void 0;
exports.esAdminRestaurante = esAdminRestaurante;
exports.esRolCocina = esRolCocina;
exports.ROL_GERENTE_CADENA = 'gerente_cadena';
function esAdminRestaurante(rol) {
    return rol === 'admin' || rol === exports.ROL_GERENTE_CADENA;
}
function esRolCocina(rol) {
    return rol === 'cocina' || rol.startsWith('cocina_');
}
//# sourceMappingURL=roles-food.js.map