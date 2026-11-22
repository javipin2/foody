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
const core_1 = require("@nestjs/core");
const omitir_suscripcion_activa_decorator_1 = require("../../../compartido/decoradores/omitir-suscripcion-activa.decorator");
const suscripciones_vencimiento_service_1 = require("../suscripciones-vencimiento.service");
let SuscripcionActivaGuard = class SuscripcionActivaGuard {
    vencimiento;
    reflector;
    constructor(vencimiento, reflector) {
        this.vencimiento = vencimiento;
        this.reflector = reflector;
    }
    async canActivate(context) {
        const omitir = this.reflector.getAllAndOverride(omitir_suscripcion_activa_decorator_1.OMITIR_SUSCRIPCION_ACTIVA_KEY, [context.getHandler(), context.getClass()]);
        if (omitir)
            return true;
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
            throw new common_1.ForbiddenException({
                error: 'RESTAURANTE_BLOQUEADO',
                mensaje: 'Tu suscripción no está activa. Reactiva tu plan para usar el panel. Tus datos se conservan.',
                message: 'Tu suscripción no está activa. Reactiva tu plan para usar el panel. Tus datos se conservan.',
                estado,
            });
        }
        return true;
    }
};
exports.SuscripcionActivaGuard = SuscripcionActivaGuard;
exports.SuscripcionActivaGuard = SuscripcionActivaGuard = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [suscripciones_vencimiento_service_1.SuscripcionesVencimientoService,
        core_1.Reflector])
], SuscripcionActivaGuard);
//# sourceMappingURL=suscripcion-activa.guard.js.map