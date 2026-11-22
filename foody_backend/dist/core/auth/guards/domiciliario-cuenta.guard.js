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
exports.DomiciliarioCuentaGuard = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../database/database.service");
let DomiciliarioCuentaGuard = class DomiciliarioCuentaGuard {
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
        if (usuario.rol !== 'domiciliario_independiente') {
            throw new common_1.ForbiddenException('Acceso solo para domiciliarios independientes');
        }
        const dom = await this.database.consultarUno(`SELECT estado_cuenta FROM domiciliarios_independientes WHERE id = $1`, [usuario.sub]);
        if (!dom) {
            throw new common_1.ForbiddenException('Cuenta no encontrada');
        }
        if (!['pendiente_verificacion', 'activo'].includes(dom.estado_cuenta)) {
            throw new common_1.ForbiddenException('Tu cuenta está suspendida o bloqueada. Contacta a soporte Foody.');
        }
        return true;
    }
};
exports.DomiciliarioCuentaGuard = DomiciliarioCuentaGuard;
exports.DomiciliarioCuentaGuard = DomiciliarioCuentaGuard = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], DomiciliarioCuentaGuard);
//# sourceMappingURL=domiciliario-cuenta.guard.js.map