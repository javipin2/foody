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
exports.SuperAdminGuard = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../database/database.service");
let SuperAdminGuard = class SuperAdminGuard {
    database;
    constructor(database) {
        this.database = database;
    }
    async canActivate(context) {
        const request = context.switchToHttp().getRequest();
        const token = request.user;
        if (!token?.sub) {
            throw new common_1.UnauthorizedException('Sesión inválida');
        }
        const fila = await this.database.consultarUno(`SELECT rol, restaurante_id, sucursal_id, activo
       FROM usuarios
       WHERE id = $1`, [token.sub]);
        if (!fila?.activo) {
            throw new common_1.UnauthorizedException('Usuario inactivo');
        }
        if (fila.rol !== 'super_admin') {
            throw new common_1.ForbiddenException({
                error: 'SUPER_ADMIN_REQUERIDO',
                message: 'Solo super administrador',
            });
        }
        if (fila.restaurante_id != null || fila.sucursal_id != null) {
            throw new common_1.ForbiddenException({
                error: 'SUPER_ADMIN_SIN_TENANT',
                message: 'El super administrador no puede tener restaurante ni sucursal asignados',
            });
        }
        request.user = {
            ...token,
            rol: fila.rol,
            restaurante_id: null,
            sucursal_id: null,
        };
        return true;
    }
};
exports.SuperAdminGuard = SuperAdminGuard;
exports.SuperAdminGuard = SuperAdminGuard = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], SuperAdminGuard);
//# sourceMappingURL=super-admin.guard.js.map