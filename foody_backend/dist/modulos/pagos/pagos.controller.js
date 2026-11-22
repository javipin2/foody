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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PagosController = void 0;
const common_1 = require("@nestjs/common");
const omitir_suscripcion_activa_decorator_1 = require("../../compartido/decoradores/omitir-suscripcion-activa.decorator");
const rate_limit_guard_1 = require("../../compartido/guards/rate-limit.guard");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const retorno_app_query_dto_1 = require("./dto/retorno-app-query.dto");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const checkout_plan_dto_1 = require("./dto/checkout-plan.dto");
const sincronizar_pago_dto_1 = require("./dto/sincronizar-pago.dto");
const pagos_service_1 = require("./pagos.service");
let PagosController = class PagosController {
    pagosService;
    constructor(pagosService) {
        this.pagosService = pagosService;
    }
    checkout(usuario, dto) {
        return this.pagosService.crearCheckout(usuario, dto);
    }
    estado(usuario) {
        if (!usuario.restaurante_id) {
            return { suscripcion: null, ultimo_pago: null };
        }
        return this.pagosService.estadoRestaurante(usuario.restaurante_id);
    }
    sincronizar(usuario, dto) {
        if (!usuario.restaurante_id) {
            throw new common_1.ForbiddenException('Sin restaurante asociado');
        }
        return this.pagosService.sincronizarPago(usuario.restaurante_id, dto);
    }
    renovar(usuario) {
        return this.pagosService.renovar(usuario);
    }
    retornoApp(query, res) {
        const html = this.pagosService.htmlRetornoApp(query.pago_id);
        res.status(200).type('html').send(html);
    }
    webhookWompi(evento, checksum) {
        return this.pagosService.procesarWebhookWompi(evento, checksum);
    }
};
exports.PagosController = PagosController;
__decorate([
    (0, common_1.Post)('checkout'),
    (0, omitir_suscripcion_activa_decorator_1.OmitirSuscripcionActiva)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        checkout_plan_dto_1.CheckoutPlanDto]),
    __metadata("design:returntype", void 0)
], PagosController.prototype, "checkout", null);
__decorate([
    (0, common_1.Get)('estado'),
    (0, omitir_suscripcion_activa_decorator_1.OmitirSuscripcionActiva)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], PagosController.prototype, "estado", null);
__decorate([
    (0, common_1.Post)('sincronizar'),
    (0, omitir_suscripcion_activa_decorator_1.OmitirSuscripcionActiva)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        sincronizar_pago_dto_1.SincronizarPagoDto]),
    __metadata("design:returntype", void 0)
], PagosController.prototype, "sincronizar", null);
__decorate([
    (0, common_1.Post)('renovar'),
    (0, omitir_suscripcion_activa_decorator_1.OmitirSuscripcionActiva)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], PagosController.prototype, "renovar", null);
__decorate([
    (0, common_1.Get)('retorno-app'),
    (0, rate_limit_guard_1.RateLimitPublico)(60, 60_000),
    (0, common_1.Header)('Cache-Control', 'no-store'),
    __param(0, (0, common_1.Query)()),
    __param(1, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [retorno_app_query_dto_1.RetornoAppQueryDto, Object]),
    __metadata("design:returntype", void 0)
], PagosController.prototype, "retornoApp", null);
__decorate([
    (0, common_1.Post)('webhook-wompi'),
    (0, rate_limit_guard_1.RateLimitPublico)(120, 60_000),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Headers)('x-event-checksum')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], PagosController.prototype, "webhookWompi", null);
exports.PagosController = PagosController = __decorate([
    (0, common_1.Controller)('pagos'),
    __metadata("design:paramtypes", [pagos_service_1.PagosService])
], PagosController);
//# sourceMappingURL=pagos.controller.js.map