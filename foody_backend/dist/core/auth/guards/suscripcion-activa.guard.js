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
exports.SuscripcionActivaGuard = void 0;
const common_1 = require("@nestjs/common");
const suscripciones_vencimiento_service_1 = require("../suscripciones-vencimiento.service");
let SuscripcionActivaGuard = class SuscripcionActivaGuard {
    vencimiento;
    constructor(vencimiento) {
        this.vencimiento = vencimiento;
    }
    async canActivate(context) {
        const request = context.switchToHttp().getRequest();
        const usuario = request.user;
        if (!usuario)
            return false;
        if (usuario.rol === 'super_admin')
            return true;
        if (usuario.rol === 'domiciliario_independiente')
            return true;
        if (!usuario.restaurante_id) {
            throw new common_1.ForbiddenException('Usuario sin restaurante asignado');
        }
        const estado = await this.vencimiento.asegurarEstadoVigente(usuario.restaurante_id);
        if (!['activa', 'prueba'].includes(estado)) {
            throw new common_1.ForbiddenException('Suscripción del restaurante no activa');
        }
        return true;
    }
};
exports.SuscripcionActivaGuard = SuscripcionActivaGuard;
exports.SuscripcionActivaGuard = SuscripcionActivaGuard = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [suscripciones_vencimiento_service_1.SuscripcionesVencimientoService])
], SuscripcionActivaGuard);
//# sourceMappingURL=suscripcion-activa.guard.js.map