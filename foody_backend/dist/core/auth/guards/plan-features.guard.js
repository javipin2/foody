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
exports.PlanFeaturesGuard = void 0;
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
const requiere_modulo_decorator_1 = require("../../../compartido/decoradores/requiere-modulo.decorator");
const plan_features_config_1 = require("../plan-features.config");
const plan_features_service_1 = require("../plan-features.service");
function normalizarPlanDesdeJwt(plan) {
    return (0, plan_features_config_1.normalizarPlan)(plan);
}
let PlanFeaturesGuard = class PlanFeaturesGuard {
    reflector;
    planFeatures;
    constructor(reflector, planFeatures) {
        this.reflector = reflector;
        this.planFeatures = planFeatures;
    }
    async canActivate(context) {
        const modulo = this.reflector.getAllAndOverride(requiere_modulo_decorator_1.MODULO_PLAN_KEY, [context.getHandler(), context.getClass()]);
        if (!modulo)
            return true;
        const request = context.switchToHttp().getRequest();
        const usuario = request.user;
        if (!usuario)
            return false;
        if (usuario.rol === 'super_admin')
            return true;
        if (usuario.rol === 'domiciliario_independiente')
            return true;
        const plan = usuario.restaurante_id
            ? await this.planFeatures.obtenerPlanRestaurante(usuario.restaurante_id)
            : normalizarPlanDesdeJwt(usuario.plan);
        if (this.planFeatures.incluyeModulo(plan, modulo))
            return true;
        throw new common_1.ForbiddenException({
            error: 'PLAN_NO_INCLUYE_MODULO',
            message: `Tu plan (${plan}) no incluye el módulo «${modulo}». Actualiza a un plan superior.`,
            modulo,
            plan,
        });
    }
};
exports.PlanFeaturesGuard = PlanFeaturesGuard;
exports.PlanFeaturesGuard = PlanFeaturesGuard = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [core_1.Reflector,
        plan_features_service_1.PlanFeaturesService])
], PlanFeaturesGuard);
//# sourceMappingURL=plan-features.guard.js.map