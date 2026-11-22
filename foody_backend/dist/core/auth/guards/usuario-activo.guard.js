"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UsuarioActivoGuard = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../database/database.service");
function tvDelJwt(usuario) {
    const n = Number(usuario.tv ?? 1);
    return Number.isFinite(n) && n > 0 ? n : 1;
}
let UsuarioActivoGuard = class UsuarioActivoGuard {
    database;
    constructor(database) {
        this.database = database;
    }
    async canActivate(context) {
        const request = context.switchToHttp().getRequest();
        const usuario = request.user;
        if (!usuario?.sub) {
            throw new common_1.UnauthorizedException('Sesión inválida');
        }
        if (usuario.rol === 'domiciliario_independiente') {
            const dom = await this.database.consultarUno(`SELECT estado_cuenta, COALESCE(token_version, 1) AS token_version
         FROM domiciliarios_independientes WHERE id = $1`, [usuario.sub]);
            if (dom?.estado_cuenta !== 'activo') {
                throw new common_1.UnauthorizedException('Domiciliario inactivo');
            }
            if (tvDelJwt(usuario) !== Number(dom.token_version)) {
                throw new common_1.UnauthorizedException({
                    error: 'SESION_REVOCADA',
                    message: 'Sesión cerrada o invalidada. Vuelve a iniciar sesión.',
                });
            }
            return true;
        }
        const fila = await this.database.consultarUno(`SELECT activo, COALESCE(token_version, 1) AS token_version
       FROM usuarios WHERE id = $1`, [usuario.sub]);
        if (!fila?.activo) {
            throw new common_1.UnauthorizedException('Usuario inactivo');
        }
        if (tvDelJwt(usuario) !== Number(fila.token_version)) {
            throw new common_1.UnauthorizedException({
                error: 'SESION_REVOCADA',
                message: 'Sesión cerrada o invalidada. Vuelve a iniciar sesión.',
            });
        }
        return true;
    }
};
exports.UsuarioActivoGuard = UsuarioActivoGuard;
exports.UsuarioActivoGuard = UsuarioActivoGuard = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], UsuarioActivoGuard);
//# sourceMappingURL=usuario-activo.guard.js.map